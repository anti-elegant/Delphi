import Foundation
import SwiftData

// MARK: - Local Prediction Repository
final class LocalPredictionRepository: PredictionRepositoryProtocol {
  private let modelContext: ModelContext
  
  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }
  
  // Convenience initializer for dependency injection
  convenience init() {
    // This will be injected by the DI container with the actual context
    fatalError("LocalPredictionRepository requires a ModelContext. Use init(modelContext:) instead.")
  }
  
  // MARK: - Create
  func save(_ prediction: Prediction) async throws {
    let dataModel = PredictionDataModel.from(domain: prediction)
    
    do {
      modelContext.insert(dataModel)
      try modelContext.save()
    } catch {
      throw PredictionRepositoryError.saveFailed(error)
    }
  }
  
  // MARK: - Read
  func getAll() async throws -> [Prediction] {
    do {
      let descriptor = PredictionDataModel.allPredictions()
      let dataModels = try modelContext.fetch(descriptor)
      return dataModels.compactMap { $0.toDomain() }
    } catch {
      throw PredictionRepositoryError.fetchFailed(error)
    }
  }
  
  func getById(_ id: UUID) async throws -> Prediction? {
    do {
      let descriptor = PredictionDataModel.predictionById(id)
      let dataModels = try modelContext.fetch(descriptor)
      return dataModels.first?.toDomain()
    } catch {
      throw PredictionRepositoryError.fetchFailed(error)
    }
  }
  
  func getByStatus(_ status: PredictionStatus) async throws -> [Prediction] {
    do {
      let descriptor: FetchDescriptor<PredictionDataModel>
      
      switch status {
      case .pending:
        descriptor = PredictionDataModel.pendingPredictions()
      case .overdue:
        descriptor = PredictionDataModel.overduePredictions()
      case .resolved:
        descriptor = PredictionDataModel.resolvedPredictions()
      }
      
      let dataModels = try modelContext.fetch(descriptor)
      return dataModels.compactMap { $0.toDomain() }
    } catch {
      throw PredictionRepositoryError.fetchFailed(error)
    }
  }
  
  func getPending() async throws -> [Prediction] {
    try await getByStatus(.pending)
  }
  
  func getOverdue() async throws -> [Prediction] {
    try await getByStatus(.overdue)
  }
  
  func getResolved() async throws -> [Prediction] {
    try await getByStatus(.resolved)
  }
  
  // MARK: - Update
  func update(_ prediction: Prediction) async throws {
    do {
      // Find existing data model
      let descriptor = PredictionDataModel.predictionById(prediction.id)
      let existingDataModels = try modelContext.fetch(descriptor)
      
      guard let existingDataModel = existingDataModels.first else {
        throw PredictionRepositoryError.predictionNotFound(prediction.id)
      }
      
      // Update properties
      existingDataModel.title = prediction.title
      existingDataModel.predictionDescription = prediction.description
      existingDataModel.type = prediction.type.rawValue
      existingDataModel.confidence = prediction.confidence
      existingDataModel.expectedValue = prediction.expectedValue
      existingDataModel.evidence = prediction.evidence
      existingDataModel.dueDate = prediction.dueDate
      existingDataModel.resolvedAt = prediction.resolvedAt
      existingDataModel.actualValue = prediction.actualValue
      
      try modelContext.save()
    } catch let error as PredictionRepositoryError {
      throw error
    } catch {
      throw PredictionRepositoryError.updateFailed(error)
    }
  }
  
  func resolve(_ id: UUID, actualValue: String, resolvedAt: Date) async throws {
    do {
      let descriptor = PredictionDataModel.predictionById(id)
      let dataModels = try modelContext.fetch(descriptor)
      
      guard let dataModel = dataModels.first else {
        throw PredictionRepositoryError.predictionNotFound(id)
      }
      
      // Check if already resolved
      if dataModel.resolvedAt != nil {
        throw PredictionRepositoryError.alreadyResolved(id)
      }
      
      dataModel.actualValue = actualValue
      dataModel.resolvedAt = resolvedAt
      
      try modelContext.save()
    } catch let error as PredictionRepositoryError {
      throw error
    } catch {
      throw PredictionRepositoryError.updateFailed(error)
    }
  }
  
  // MARK: - Delete
  func delete(_ id: UUID) async throws {
    do {
      let descriptor = PredictionDataModel.predictionById(id)
      let dataModels = try modelContext.fetch(descriptor)
      
      guard let dataModel = dataModels.first else {
        throw PredictionRepositoryError.predictionNotFound(id)
      }
      
      modelContext.delete(dataModel)
      try modelContext.save()
    } catch let error as PredictionRepositoryError {
      throw error
    } catch {
      throw PredictionRepositoryError.deleteFailed(error)
    }
  }
  
  func deleteAll() async throws {
    do {
      let descriptor = PredictionDataModel.allPredictions()
      let allDataModels = try modelContext.fetch(descriptor)
      
      for dataModel in allDataModels {
        modelContext.delete(dataModel)
      }
      
      try modelContext.save()
    } catch {
      throw PredictionRepositoryError.deleteFailed(error)
    }
  }
  
  // MARK: - Analytics Support
  func getResolvedCount() async throws -> Int {
    do {
      let resolvedPredictions = try await getResolved()
      return resolvedPredictions.count
    } catch {
      throw PredictionRepositoryError.fetchFailed(error)
    }
  }
  
  func getCorrectCount() async throws -> Int {
    do {
      let resolvedPredictions = try await getResolved()
      let correctPredictions = resolvedPredictions.filter { $0.isCorrect == true }
      return correctPredictions.count
    } catch {
      throw PredictionRepositoryError.fetchFailed(error)
    }
  }
  
  func calculateAccuracy() async throws -> AccuracyMetric {
    do {
      let resolvedPredictions = try await getResolved()
      return AccuracyMetric.calculate(from: resolvedPredictions)
    } catch {
      throw PredictionRepositoryError.fetchFailed(error)
    }
  }
}

// MARK: - Repository Factory
extension LocalPredictionRepository {
  static func create(with modelContext: ModelContext) -> LocalPredictionRepository {
    LocalPredictionRepository(modelContext: modelContext)
  }
}

// MARK: - Extended Repository Support
extension LocalPredictionRepository: PredictionRepositoryProtocol_Extended {
  func getWithOptions(_ options: PredictionQueryOptions) async throws -> [Prediction] {
    do {
      let allPredictions = try await getAll()
      
      // Apply sorting
      let sortedPredictions = sortPredictions(allPredictions, options: options)
      
      // Apply pagination if specified
      var result = sortedPredictions
      if let offset = options.offset {
        result = Array(result.dropFirst(offset))
      }
      if let limit = options.limit {
        result = Array(result.prefix(limit))
      }
      
      return result
    } catch {
      throw PredictionRepositoryError.fetchFailed(error)
    }
  }
  
  func search(query: String) async throws -> [Prediction] {
    do {
      let allPredictions = try await getAll()
      let searchQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
      
      guard !searchQuery.isEmpty else {
        return allPredictions
      }
      
      return allPredictions.filter { prediction in
        prediction.title.lowercased().contains(searchQuery) ||
        prediction.description.lowercased().contains(searchQuery) ||
        prediction.expectedValue.lowercased().contains(searchQuery) ||
        prediction.evidence.contains { $0.lowercased().contains(searchQuery) }
      }
    } catch {
      throw PredictionRepositoryError.fetchFailed(error)
    }
  }
  
  func getStatistics() async throws -> PredictionStatistics {
    do {
      let allPredictions = try await getAll()
      let pendingPredictions = try await getPending()
      let overduePredictions = try await getOverdue()
      let resolvedPredictions = try await getResolved()
      let accuracyMetric = try await calculateAccuracy()
      
      let averageConfidence = allPredictions.isEmpty ? 0.0 : 
        allPredictions.map { $0.confidence }.reduce(0, +) / Double(allPredictions.count)
      
      return PredictionStatistics(
        totalCount: allPredictions.count,
        pendingCount: pendingPredictions.count,
        overdueCount: overduePredictions.count,
        resolvedCount: resolvedPredictions.count,
        averageConfidence: averageConfidence,
        accuracyMetric: accuracyMetric
      )
    } catch {
      throw PredictionRepositoryError.fetchFailed(error)
    }
  }
  
  private func sortPredictions(_ predictions: [Prediction], options: PredictionQueryOptions) -> [Prediction] {
    return predictions.sorted { lhs, rhs in
      let comparison: Bool
      
      switch options.sortBy {
      case .createdDate:
        comparison = lhs.createdAt < rhs.createdAt
      case .dueDate:
        comparison = lhs.dueDate < rhs.dueDate
      case .resolvedDate:
        let lhsResolved = lhs.resolvedAt ?? Date.distantPast
        let rhsResolved = rhs.resolvedAt ?? Date.distantPast
        comparison = lhsResolved < rhsResolved
      case .confidence:
        comparison = lhs.confidence < rhs.confidence
      case .title:
        comparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
      }
      
      return options.order == .ascending ? comparison : !comparison
    }
  }
}
