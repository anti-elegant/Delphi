import Foundation
import SwiftData

// MARK: - Prediction Service Error Types
enum PredictionServiceError: LocalizedError {
  case contextNotAvailable
  case saveFailed(Error)
  case fetchFailed(Error)
  case deleteFailed(Error)
  case predictionNotFound

  var errorDescription: String? {
    switch self {
    case .contextNotAvailable:
      return "Model context is not available"
    case .saveFailed(let error):
      return "Failed to save prediction: \(error.localizedDescription)"
    case .fetchFailed(let error):
      return "Failed to fetch predictions: \(error.localizedDescription)"
    case .deleteFailed(let error):
      return "Failed to delete prediction: \(error.localizedDescription)"
    case .predictionNotFound:
      return "Prediction not found"
    }
  }
}

// MARK: - Prediction Service
@MainActor
final class PredictionService: ObservableObject {

  // MARK: - Properties
  private let modelContext: ModelContext
  @Published private(set) var isLoading = false
  @Published private(set) var lastError: PredictionServiceError?

  // MARK: - Initialization
  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }

  // MARK: - Create Operations
  func createPrediction(
    eventName: String,
    eventDescription: String,
    confidenceLevel: Double,
    estimatedValue: String,
    booleanValue: String,
    pressureLevel: String,
    currentMood: String,
    takesMedicine: String,
    evidenceList: [String],
    selectedType: EventType,
    dueDate: Date
  ) async throws {
    isLoading = true
    defer { isLoading = false }

    do {
      let prediction = Prediction(
        eventName: eventName,
        eventDescription: eventDescription,
        confidenceLevel: confidenceLevel,
        estimatedValue: estimatedValue,
        booleanValue: booleanValue,
        pressureLevel: pressureLevel,
        currentMood: currentMood,
        takesMedicine: takesMedicine,
        evidenceList: evidenceList,
        selectedType: selectedType,
        dueDate: dueDate
      )

      modelContext.insert(prediction)
      try modelContext.save()
      lastError = nil
    } catch {
      lastError = .saveFailed(error)
      throw lastError!
    }
  }

  // MARK: - Read Operations
  func fetchAllPredictions() async throws -> [Prediction] {
    isLoading = true
    defer { isLoading = false }

    do {
      let descriptor = FetchDescriptor<Prediction>(
        sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
      )
      let predictions = try modelContext.fetch(descriptor)
      lastError = nil
      return predictions
    } catch {
      lastError = .fetchFailed(error)
      throw lastError!
    }
  }

  func fetchPendingPredictions() async throws -> [Prediction] {
    isLoading = true
    defer { isLoading = false }

    do {
      let descriptor = FetchDescriptor<Prediction>(
        predicate: #Predicate { $0.isPending == true },
        sortBy: [SortDescriptor(\.dueDate, order: .forward)]
      )
      let predictions = try modelContext.fetch(descriptor)
      lastError = nil
      return predictions
    } catch {
      lastError = .fetchFailed(error)
      throw lastError!
    }
  }

  func fetchOverduePredictions() async throws -> [Prediction] {
    isLoading = true
    defer { isLoading = false }

    do {
      let now = Date()
      let descriptor = FetchDescriptor<Prediction>(
        predicate: #Predicate { prediction in
          prediction.dueDate < now && !prediction.isResolved
        },
        sortBy: [SortDescriptor(\.dueDate, order: .reverse)]
      )
      let predictions = try modelContext.fetch(descriptor)
      lastError = nil
      return predictions
    } catch {
      lastError = .fetchFailed(error)
      throw lastError!
    }
  }

  func fetchPredictionsForAnalytics() async throws -> [Prediction] {
    isLoading = true
    defer { isLoading = false }

    do {
      let descriptor = FetchDescriptor<Prediction>(
        predicate: #Predicate { $0.isResolved == true }
      )
      let predictions = try modelContext.fetch(descriptor)
      lastError = nil
      return predictions
    } catch {
      lastError = .fetchFailed(error)
      throw lastError!
    }
  }

  // MARK: - Update Operations
  func updatePrediction(_ prediction: Prediction) async throws {
    isLoading = true
    defer { isLoading = false }

    do {
      try modelContext.save()
      lastError = nil
    } catch {
      lastError = .saveFailed(error)
      throw lastError!
    }
  }

  func resolvePrediction(_ prediction: Prediction, actualOutcome: String)
    async throws
  {
    isLoading = true
    defer { isLoading = false }

    do {
      prediction.isResolved = true
      prediction.actualOutcome = actualOutcome
      prediction.resolutionDate = Date()
      prediction.isPending = false
      try modelContext.save()
      lastError = nil
    } catch {
      lastError = .saveFailed(error)
      throw lastError!
    }
  }

  // MARK: - Delete Operations
  func deletePrediction(_ prediction: Prediction) async throws {
    isLoading = true
    defer { isLoading = false }

    do {
      modelContext.delete(prediction)
      try modelContext.save()
      lastError = nil
    } catch {
      lastError = .deleteFailed(error)
      throw lastError!
    }
  }

  func deleteAllPredictions() async throws {
    isLoading = true
    defer { isLoading = false }

    do {
      let predictions = try await fetchAllPredictions()
      for prediction in predictions {
        modelContext.delete(prediction)
      }
      try modelContext.save()
      lastError = nil
    } catch {
      lastError = .deleteFailed(error)
      throw lastError!
    }
  }

  // MARK: - Analytics Operations
  func calculateAccuracy() async throws -> Double {
    let resolvedPredictions = try await fetchPredictionsForAnalytics()

    guard !resolvedPredictions.isEmpty else {
      return 0.0
    }

    let correctCount = resolvedPredictions.filter { prediction in
      // Compare actual outcome with predicted value
      switch prediction.selectedType {
      case .boolean:
        return prediction.actualOutcome == prediction.booleanValue
      case .numeric:
        // For numeric predictions, implement tolerance-based comparison
        return prediction.actualOutcome == prediction.estimatedValue
      }
    }.count

    return Double(correctCount) / Double(resolvedPredictions.count)
  }

  func calculateCorrelation(for factor: String) async throws -> Double {
    let resolvedPredictions = try await fetchPredictionsForAnalytics()

    guard !resolvedPredictions.isEmpty else {
      return 0.0
    }

    // This is a simplified correlation calculation
    // In a real implementation, you'd use proper statistical methods
    let correctPredictions = resolvedPredictions.filter { prediction in
      switch prediction.selectedType {
      case .boolean:
        return prediction.actualOutcome == prediction.booleanValue
      case .numeric:
        return prediction.actualOutcome == prediction.estimatedValue
      }
    }

    // Calculate correlation based on the factor
    switch factor.lowercased() {
    case "pressure":
      return calculatePressureCorrelation(
        correctPredictions,
        total: resolvedPredictions
      )
    case "mood":
      return calculateMoodCorrelation(
        correctPredictions,
        total: resolvedPredictions
      )
    case "medicine":
      return calculateMedicineCorrelation(
        correctPredictions,
        total: resolvedPredictions
      )
    default:
      return 0.0
    }
  }

  // MARK: - Private Helper Methods
  private func calculatePressureCorrelation(
    _ correct: [Prediction],
    total: [Prediction]
  ) -> Double {
    // Simplified calculation - in reality would use Pearson correlation
    let lowPressureCorrect = correct.filter { $0.pressureLevel == "Low" }.count
    let lowPressureTotal = total.filter { $0.pressureLevel == "Low" }.count

    guard lowPressureTotal > 0 else { return 0.0 }
    return Double(lowPressureCorrect) / Double(lowPressureTotal)
  }

  private func calculateMoodCorrelation(
    _ correct: [Prediction],
    total: [Prediction]
  ) -> Double {
    // Simplified calculation
    let goodMoodCorrect = correct.filter {
      $0.currentMood == "Good" || $0.currentMood == "Excellent"
    }.count
    let goodMoodTotal = total.filter {
      $0.currentMood == "Good" || $0.currentMood == "Excellent"
    }.count

    guard goodMoodTotal > 0 else { return 0.0 }
    return Double(goodMoodCorrect) / Double(goodMoodTotal)
  }

  private func calculateMedicineCorrelation(
    _ correct: [Prediction],
    total: [Prediction]
  ) -> Double {
    // Simplified calculation
    let withMedicineCorrect = correct.filter { $0.takesMedicine == "Yes" }.count
    let withMedicineTotal = total.filter { $0.takesMedicine == "Yes" }.count

    guard withMedicineTotal > 0 else { return 0.0 }
    return Double(withMedicineCorrect) / Double(withMedicineTotal)
  }
}
