import Foundation

// MARK: - Get Predictions Use Case
protocol GetPredictionsUseCase {
  func execute() async throws -> [Prediction]
  func executeByStatus(_ status: PredictionStatus) async throws -> [Prediction]
  func executePending() async throws -> [Prediction]
  func executeOverdue() async throws -> [Prediction]
  func executeResolved() async throws -> [Prediction]
  func executeById(_ id: UUID) async throws -> Prediction?
}

// MARK: - Get Predictions Error
enum GetPredictionsError: LocalizedError {
  case fetchFailed(Error)
  case predictionNotFound(UUID)
  
  var errorDescription: String? {
    switch self {
    case .fetchFailed(let error):
      return "Failed to fetch predictions: \(error.localizedDescription)"
    case .predictionNotFound(let id):
      return "Prediction with ID \(id) not found"
    }
  }
}

// MARK: - Default Implementation
final class DefaultGetPredictionsUseCase: GetPredictionsUseCase {
  private let repository: PredictionRepositoryProtocol
  
  init(repository: PredictionRepositoryProtocol) {
    self.repository = repository
  }
  
  func execute() async throws -> [Prediction] {
    do {
      return try await repository.getAll()
    } catch {
      throw GetPredictionsError.fetchFailed(error)
    }
  }
  
  func executeByStatus(_ status: PredictionStatus) async throws -> [Prediction] {
    do {
      return try await repository.getByStatus(status)
    } catch {
      throw GetPredictionsError.fetchFailed(error)
    }
  }
  
  func executePending() async throws -> [Prediction] {
    do {
      return try await repository.getPending()
    } catch {
      throw GetPredictionsError.fetchFailed(error)
    }
  }
  
  func executeOverdue() async throws -> [Prediction] {
    do {
      return try await repository.getOverdue()
    } catch {
      throw GetPredictionsError.fetchFailed(error)
    }
  }
  
  func executeResolved() async throws -> [Prediction] {
    do {
      return try await repository.getResolved()
    } catch {
      throw GetPredictionsError.fetchFailed(error)
    }
  }
  
  func executeById(_ id: UUID) async throws -> Prediction? {
    do {
      return try await repository.getById(id)
    } catch {
      throw GetPredictionsError.fetchFailed(error)
    }
  }
}

// MARK: - Get Predictions with Sorting
struct GetPredictionsWithOptionsRequest {
  let status: PredictionStatus?
  let sortBy: SortOption
  let sortOrder: SortOrder
  let limit: Int?
  
  enum SortOption {
    case createdDate
    case dueDate
    case confidence
    case title
  }
  
  enum SortOrder {
    case ascending
    case descending
  }
  
  static let defaultRequest = GetPredictionsWithOptionsRequest(
    status: nil,
    sortBy: .createdDate,
    sortOrder: .descending,
    limit: nil
  )
}

// MARK: - Extended Get Predictions Use Case
protocol GetPredictionsUseCase_Extended: GetPredictionsUseCase {
  func executeWithOptions(_ request: GetPredictionsWithOptionsRequest) async throws -> [Prediction]
  func executeSearch(query: String) async throws -> [Prediction]
}

// MARK: - Extended Default Implementation
extension DefaultGetPredictionsUseCase: GetPredictionsUseCase_Extended {
  func executeWithOptions(_ request: GetPredictionsWithOptionsRequest) async throws -> [Prediction] {
    do {
      var predictions: [Prediction]
      
      if let status = request.status {
        predictions = try await repository.getByStatus(status)
      } else {
        predictions = try await repository.getAll()
      }
      
      // Apply sorting
      predictions = sortPredictions(predictions, by: request.sortBy, order: request.sortOrder)
      
      // Apply limit if specified
      if let limit = request.limit {
        predictions = Array(predictions.prefix(limit))
      }
      
      return predictions
    } catch {
      throw GetPredictionsError.fetchFailed(error)
    }
  }
  
  func executeSearch(query: String) async throws -> [Prediction] {
    do {
      let allPredictions = try await repository.getAll()
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
      throw GetPredictionsError.fetchFailed(error)
    }
  }
  
  private func sortPredictions(
    _ predictions: [Prediction],
    by sortOption: GetPredictionsWithOptionsRequest.SortOption,
    order: GetPredictionsWithOptionsRequest.SortOrder
  ) -> [Prediction] {
    let sorted = predictions.sorted { lhs, rhs in
      let result: Bool
      switch sortOption {
      case .createdDate:
        result = lhs.createdAt < rhs.createdAt
      case .dueDate:
        result = lhs.dueDate < rhs.dueDate
      case .confidence:
        result = lhs.confidence < rhs.confidence
      case .title:
        result = lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
      }
      
      return order == .ascending ? result : !result
    }
    
    return sorted
  }
}
