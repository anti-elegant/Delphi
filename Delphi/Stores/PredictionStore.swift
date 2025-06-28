import Foundation
import SwiftData
import SwiftUI

// MARK: - Prediction Store Error Types
enum PredictionStoreError: LocalizedError, Sendable {
  case predictionNotFound(String)
  case serviceFailed(Error)
  case modelContextNotAvailable

  var errorDescription: String? {
    switch self {
    case .predictionNotFound(let id):
      return "Prediction '\(id)' not found"
    case .serviceFailed(let error):
      return "Service operation failed: \(error.localizedDescription)"
    case .modelContextNotAvailable:
      return "Model context is not available"
    }
  }
}

// MARK: - Prediction Store
@MainActor
final class PredictionStore: ObservableObject, Syncable {
  static let shared = PredictionStore()

  // MARK: - Published Properties
  @Published private(set) var predictions: [Prediction] = []
  @Published private(set) var isLoading = false
  @Published private(set) var lastError: PredictionStoreError?
  @Published private(set) var hasPendingChanges = false

  // MARK: - Private Properties
  private var predictionService: PredictionService?

  // MARK: - Internal Properties (for CloudKit sync access)
  internal var modelContext: ModelContext?

  // MARK: - Initialization
  private init() {
    // Service will be initialized when model context is set
  }

  // MARK: - Configuration
  func setModelContext(_ context: ModelContext) {
    self.modelContext = context
    self.predictionService = PredictionService(modelContext: context)

    // Load initial data
    Task {
      await refreshPredictions()
    }
  }

  // MARK: - Public Interface - CRUD Operations
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
  ) async {
    guard let service = predictionService else {
      lastError = .modelContextNotAvailable
      return
    }

    isLoading = true
    defer { isLoading = false }

    do {
      try await service.createPrediction(
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

      await refreshPredictions()
      lastError = nil
      markForSync()
    } catch {
      lastError = .serviceFailed(error)
    }
  }

  func updatePrediction(_ prediction: Prediction) async {
    guard let service = predictionService else {
      lastError = .modelContextNotAvailable
      return
    }

    isLoading = true
    defer { isLoading = false }

    do {
      try await service.updatePrediction(prediction)
      await refreshPredictions()
      lastError = nil
      trackChange(
        id: prediction.id.uuidString,
        recordType: "Prediction",
        changeType: .updated
      )
    } catch {
      lastError = .serviceFailed(error)
    }
  }

  func resolvePrediction(_ prediction: Prediction, actualOutcome: String) async
  {
    guard let service = predictionService else {
      lastError = .modelContextNotAvailable
      return
    }

    isLoading = true
    defer { isLoading = false }

    do {
      try await service.resolvePrediction(
        prediction,
        actualOutcome: actualOutcome
      )
      await refreshPredictions()
      lastError = nil
      trackChange(
        id: prediction.id.uuidString,
        recordType: "Prediction",
        changeType: .updated
      )
    } catch {
      lastError = .serviceFailed(error)
    }
  }

  func deletePrediction(_ prediction: Prediction) async {
    guard let service = predictionService else {
      lastError = .modelContextNotAvailable
      return
    }

    isLoading = true
    defer { isLoading = false }

    do {
      try await service.deletePrediction(prediction)
      await refreshPredictions()
      lastError = nil
      CloudKitSyncService.shared.trackDeletion(
        id: prediction.id.uuidString,
        recordType: "Prediction"
      )
    } catch {
      lastError = .serviceFailed(error)
    }
  }

  func deleteAllPredictions() async {
    guard let service = predictionService else {
      lastError = .modelContextNotAvailable
      return
    }

    isLoading = true
    defer { isLoading = false }

    do {
      // Track deletions for all predictions before deleting
      for prediction in predictions {
        CloudKitSyncService.shared.trackDeletion(
          id: prediction.id.uuidString,
          recordType: "Prediction"
        )
      }

      try await service.deleteAllPredictions()
      predictions = []
      lastError = nil
    } catch {
      lastError = .serviceFailed(error)
    }
  }

  // MARK: - Public Interface - Data Access
  func refreshPredictions() async {
    guard let service = predictionService else {
      lastError = .modelContextNotAvailable
      return
    }

    do {
      let fetchedPredictions = try await service.fetchAllPredictions()
      predictions = fetchedPredictions
      lastError = nil
    } catch {
      lastError = .serviceFailed(error)
    }
  }

  func fetchPendingPredictions() async -> [Prediction] {
    guard let service = predictionService else {
      lastError = .modelContextNotAvailable
      return []
    }

    do {
      let pendingPredictions = try await service.fetchPendingPredictions()
      lastError = nil
      return pendingPredictions
    } catch {
      lastError = .serviceFailed(error)
      return []
    }
  }

  func fetchOverduePredictions() async -> [Prediction] {
    guard let service = predictionService else {
      lastError = .modelContextNotAvailable
      return []
    }

    do {
      let overduePredictions = try await service.fetchOverduePredictions()
      lastError = nil
      return overduePredictions
    } catch {
      lastError = .serviceFailed(error)
      return []
    }
  }

  func fetchPredictionsForAnalytics() async -> [Prediction] {
    guard let service = predictionService else {
      lastError = .modelContextNotAvailable
      return []
    }

    do {
      let analyticsPredictions =
        try await service.fetchPredictionsForAnalytics()
      lastError = nil
      return analyticsPredictions
    } catch {
      lastError = .serviceFailed(error)
      return []
    }
  }

  func findPrediction(by id: UUID) async -> Prediction? {
    guard let service = predictionService else {
      lastError = .modelContextNotAvailable
      return nil
    }

    do {
      let prediction = try await service.fetchPrediction(by: id)
      lastError = nil
      return prediction
    } catch {
      lastError = .serviceFailed(error)
      return nil
    }
  }

  // MARK: - Analytics Delegate
  func calculateAccuracy() async -> Double {
    guard let service = predictionService else {
      lastError = .modelContextNotAvailable
      return 0.0
    }

    do {
      let accuracy = try await service.calculateAccuracy()
      lastError = nil
      return accuracy
    } catch {
      lastError = .serviceFailed(error)
      return 0.0
    }
  }

  func calculateCorrelation(for factor: String) async -> Double {
    guard let service = predictionService else {
      lastError = .modelContextNotAvailable
      return 0.0
    }

    do {
      let correlation = try await service.calculateCorrelation(for: factor)
      lastError = nil
      return correlation
    } catch {
      lastError = .serviceFailed(error)
      return 0.0
    }
  }

  // MARK: - CloudKit Sync Support
  func fetchModifiedSince(_ date: Date?) async -> [Prediction] {
    guard let service = predictionService else {
      lastError = .modelContextNotAvailable
      return []
    }

    do {
      let modifiedPredictions = try await service.fetchModifiedSince(date)
      lastError = nil
      return modifiedPredictions
    } catch {
      lastError = .serviceFailed(error)
      return []
    }
  }

  // MARK: - Private Helpers
  private func markForSync() {
    hasPendingChanges = true

    // Auto-trigger sync if enabled
    if SettingsStore.shared.syncWithiCloud {
      CloudKitSyncService.shared.markDataChanged()
    }
  }
}
