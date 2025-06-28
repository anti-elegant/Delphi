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
final class PredictionService {

  // MARK: - Properties
  private let modelContext: ModelContext

  // MARK: - Initialization
  init(modelContext: ModelContext) {
    self.modelContext = modelContext
    setupNotificationObservers()
  }

  private func setupNotificationObservers() {
    NotificationCenter.default.addObserver(
      forName: .scheduleNotificationsForExistingPredictions,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { await self?.scheduleNotificationsForExistingPredictions() }
    }
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

    do {
      modelContext.insert(prediction)
      try modelContext.save()

      // Schedule notification if enabled
      if SettingsStore.shared.remindersEnabled {
        try? await NotificationService.shared.scheduleReminderForPrediction(
          prediction
        )
      }
    } catch {
      throw PredictionServiceError.saveFailed(error)
    }
  }

  // MARK: - Read Operations
  func fetchAllPredictions() async throws -> [Prediction] {
    do {
      let descriptor = FetchDescriptor<Prediction>(
        sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
      )
      return try modelContext.fetch(descriptor)
    } catch {
      throw PredictionServiceError.fetchFailed(error)
    }
  }

  func fetchPendingPredictions() async throws -> [Prediction] {
    do {
      let descriptor = FetchDescriptor<Prediction>(
        predicate: #Predicate { $0.isPending == true },
        sortBy: [SortDescriptor(\.dueDate, order: .forward)]
      )
      return try modelContext.fetch(descriptor)
    } catch {
      throw PredictionServiceError.fetchFailed(error)
    }
  }

  func fetchOverduePredictions() async throws -> [Prediction] {
    do {
      let now = Date()
      let descriptor = FetchDescriptor<Prediction>(
        predicate: #Predicate { prediction in
          prediction.dueDate < now && !prediction.isResolved
        },
        sortBy: [SortDescriptor(\.dueDate, order: .reverse)]
      )
      return try modelContext.fetch(descriptor)
    } catch {
      throw PredictionServiceError.fetchFailed(error)
    }
  }

  func fetchPredictionsForAnalytics() async throws -> [Prediction] {
    do {
      let descriptor = FetchDescriptor<Prediction>(
        predicate: #Predicate { $0.isResolved == true }
      )
      return try modelContext.fetch(descriptor)
    } catch {
      throw PredictionServiceError.fetchFailed(error)
    }
  }

  func fetchPrediction(by id: UUID) async throws -> Prediction? {
    do {
      let descriptor = FetchDescriptor<Prediction>(
        predicate: #Predicate { $0.id == id }
      )
      let predictions = try modelContext.fetch(descriptor)
      return predictions.first
    } catch {
      throw PredictionServiceError.fetchFailed(error)
    }
  }

  func fetchModifiedSince(_ date: Date?) async throws -> [Prediction] {
    let predicate: Predicate<Prediction>
    if let syncDate = date {
      predicate = #Predicate { $0.lastModified > syncDate }
    } else {
      predicate = #Predicate { _ in true }
    }

    do {
      let descriptor = FetchDescriptor<Prediction>(
        predicate: predicate,
        sortBy: [SortDescriptor(\.lastModified, order: .forward)]
      )
      return try modelContext.fetch(descriptor)
    } catch {
      throw PredictionServiceError.fetchFailed(error)
    }
  }

  // MARK: - Update Operations
  func updatePrediction(_ prediction: Prediction) async throws {
    prediction.lastModified = Date()

    do {
      try modelContext.save()
    } catch {
      throw PredictionServiceError.saveFailed(error)
    }
  }

  func resolvePrediction(_ prediction: Prediction, actualOutcome: String)
    async throws
  {
    prediction.resolve(with: actualOutcome)

    do {
      try modelContext.save()

      // Cancel notifications for resolved prediction
      NotificationService.shared.cancelNotificationsForPrediction(prediction)
    } catch {
      throw PredictionServiceError.saveFailed(error)
    }
  }

  // MARK: - Delete Operations
  func deletePrediction(_ prediction: Prediction) async throws {
    // Cancel any notifications for this prediction
    NotificationService.shared.cancelNotificationsForPrediction(prediction)

    do {
      modelContext.delete(prediction)
      try modelContext.save()
    } catch {
      throw PredictionServiceError.deleteFailed(error)
    }
  }

  func deleteAllPredictions() async throws {
    do {
      let predictions = try await fetchAllPredictions()

      for prediction in predictions {
        NotificationService.shared.cancelNotificationsForPrediction(prediction)
        modelContext.delete(prediction)
      }

      try modelContext.save()
    } catch {
      throw PredictionServiceError.deleteFailed(error)
    }
  }

  // MARK: - Analytics Operations
  func calculateAccuracy() async throws -> Double {
    let resolvedPredictions = try await fetchPredictionsForAnalytics()
    guard !resolvedPredictions.isEmpty else { return 0.0 }

    let correctCount = resolvedPredictions.filter { prediction in
      switch prediction.selectedType {
      case .boolean: return prediction.actualOutcome == prediction.booleanValue
      case .numeric:
        return prediction.actualOutcome == prediction.estimatedValue
      }
    }.count

    return Double(correctCount) / Double(resolvedPredictions.count)
  }

  func calculateCorrelation(for factor: String) async throws -> Double {
    let resolvedPredictions = try await fetchPredictionsForAnalytics()
    guard !resolvedPredictions.isEmpty else { return 0.0 }

    let correctPredictions = resolvedPredictions.filter { prediction in
      switch prediction.selectedType {
      case .boolean: return prediction.actualOutcome == prediction.booleanValue
      case .numeric:
        return prediction.actualOutcome == prediction.estimatedValue
      }
    }

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
    default: return 0.0
    }
  }

  // MARK: - Private Helper Methods
  private func calculatePressureCorrelation(
    _ correct: [Prediction],
    total: [Prediction]
  ) -> Double {
    let lowPressureCorrect = correct.filter { $0.pressureLevel == "Low" }.count
    let lowPressureTotal = total.filter { $0.pressureLevel == "Low" }.count
    guard lowPressureTotal > 0 else { return 0.0 }
    return Double(lowPressureCorrect) / Double(lowPressureTotal)
  }

  private func calculateMoodCorrelation(
    _ correct: [Prediction],
    total: [Prediction]
  ) -> Double {
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
    let withMedicineCorrect = correct.filter { $0.takesMedicine == "Yes" }.count
    let withMedicineTotal = total.filter { $0.takesMedicine == "Yes" }.count
    guard withMedicineTotal > 0 else { return 0.0 }
    return Double(withMedicineCorrect) / Double(withMedicineTotal)
  }

  // MARK: - Notification Management
  private func scheduleNotificationsForExistingPredictions() async {
    guard SettingsStore.shared.remindersEnabled else { return }

    do {
      let pendingPredictions = try await fetchPendingPredictions()
      for prediction in pendingPredictions {
        try? await NotificationService.shared.scheduleReminderForPrediction(
          prediction
        )
      }
    } catch {
      print(
        "Failed to schedule notifications for existing predictions: \(error)"
      )
    }
  }
}
