import Foundation
import SwiftUI

// MARK: - Analytics Metric Model
struct AnalyticsMetric: Identifiable, Codable, Hashable, Sendable {
  let id: String
  let icon: String
  let title: String
  var value: String
  let unit: String
  private var _percentage: Double = 0.0
  var percentage: Double {
    get { _percentage }
    set {
      _percentage = Swift.max(
        0.0,
        Swift.min(1.0, newValue.isFinite ? newValue : 0.0)
      )
    }
  }
  let description: String
  var isLocked: Bool
  var lastModified: Date
  var needsCloudKitSync: Bool

  init(
    id: String? = nil,
    icon: String,
    title: String,
    value: String = "",
    unit: String = "",
    percentage: Double = 0.0,
    description: String,
    isLocked: Bool = false,
    lastModified: Date = Date(),
    needsCloudKitSync: Bool = true
  ) {
    self.id = id ?? title.lowercased().replacingOccurrences(of: " ", with: "_")
    self.icon = icon
    self.title = title
    self.value = value
    self.unit = unit
    self._percentage = Swift.max(
      0.0,
      Swift.min(1.0, percentage.isFinite ? percentage : 0.0)
    )
    self.description = description
    self.isLocked = isLocked
    self.lastModified = lastModified
    self.needsCloudKitSync = needsCloudKitSync
  }

  enum CodingKeys: String, CodingKey {
    case id, icon, title, value, unit
    case _percentage = "percentage"
    case description, isLocked, lastModified, needsCloudKitSync
  }

  func markAsSynced() -> AnalyticsMetric {
    var updated = self
    updated.needsCloudKitSync = false
    return updated
  }

  func withChanges(
    value: String? = nil,
    percentage: Double? = nil,
    isLocked: Bool? = nil
  ) -> AnalyticsMetric {
    var updated = self
    if let newValue = value { updated.value = newValue }
    if let newPercentage = percentage { updated.percentage = newPercentage }
    if let newIsLocked = isLocked { updated.isLocked = newIsLocked }
    updated.lastModified = Date()
    updated.needsCloudKitSync = true
    return updated
  }
}

// MARK: - Analytics Store Error Types
enum AnalyticsStoreError: LocalizedError, Sendable {
  case metricNotFound(String)
  case persistenceFailed

  var errorDescription: String? {
    switch self {
    case .metricNotFound(let title):
      return "Metric '\(title)' not found"
    case .persistenceFailed:
      return "Failed to save analytics data"
    }
  }
}

// MARK: - Analytics Store Keys
private enum AnalyticsStoreKeys {
  static let analyticsMetrics = "analyticsMetrics"
}

// MARK: - Analytics Store
@MainActor
final class AnalyticsStore: ObservableObject, Syncable {
  static let shared = AnalyticsStore()

  // MARK: - Published Properties
  @Published private(set) var analyticsMetrics: [AnalyticsMetric] = []
  @Published private(set) var lastError: AnalyticsStoreError?

  // MARK: - Initialization
  private init() {
    loadMetrics()
  }

  // MARK: - Public Interface
  func updateMetric(title: String, value: String, percentage: Double) {
    guard let index = analyticsMetrics.firstIndex(where: { $0.title == title })
    else {
      lastError = .metricNotFound(title)
      return
    }

    let validPercentage = Swift.max(
      0.0,
      Swift.min(1.0, percentage.isFinite ? percentage : 0.0)
    )
    let updatedMetric = analyticsMetrics[index].withChanges(
      value: value,
      percentage: validPercentage
    )

    analyticsMetrics[index] = updatedMetric
    lastError = nil

    saveMetrics()
    trackChange(
      id: updatedMetric.id,
      recordType: "AnalyticsMetric",
      changeType: .updated
    )
  }

  func unlockMetric(title: String) {
    guard let index = analyticsMetrics.firstIndex(where: { $0.title == title })
    else {
      lastError = .metricNotFound(title)
      return
    }

    let unlockedMetric = analyticsMetrics[index].withChanges(isLocked: false)
    analyticsMetrics[index] = unlockedMetric
    lastError = nil

    saveMetrics()
    trackChange(
      id: unlockedMetric.id,
      recordType: "AnalyticsMetric",
      changeType: .updated
    )
  }

  func resetToDefaults() {
    // Track deletions for all existing metrics
    for metric in analyticsMetrics {
      CloudKitSyncService.shared.trackDeletion(
        id: metric.id,
        recordType: "AnalyticsMetric"
      )
    }

    analyticsMetrics = []
    lastError = nil
    saveMetrics()
  }

  func deleteMetric(withId id: String) {
    guard let index = analyticsMetrics.firstIndex(where: { $0.id == id }) else {
      lastError = .metricNotFound(id)
      return
    }

    let metric = analyticsMetrics[index]
    analyticsMetrics.remove(at: index)
    lastError = nil

    saveMetrics()
    CloudKitSyncService.shared.trackDeletion(
      id: metric.id,
      recordType: "AnalyticsMetric"
    )
  }

  func seedMetrics(_ metrics: [AnalyticsMetric]) {
    analyticsMetrics = metrics
    saveMetrics()

    // Track all seeded metrics as new
    for metric in metrics {
      trackChange(
        id: metric.id,
        recordType: "AnalyticsMetric",
        changeType: .created
      )
    }
  }

  // MARK: - CloudKit Sync Support
  func getMetricsNeedingSync() -> [AnalyticsMetric] {
    return analyticsMetrics.filter { $0.needsCloudKitSync }
  }

  func markMetricsAsSynced(_ syncedIds: [String]) {
    for id in syncedIds {
      if let index = analyticsMetrics.firstIndex(where: { $0.id == id }) {
        analyticsMetrics[index] = analyticsMetrics[index].markAsSynced()
      }
    }
    saveMetrics()
  }

  func applyServerChanges(
    _ serverMetrics: [AnalyticsMetric],
    conflictResolution: ConflictResolutionStrategy = .newerWins
  ) {
    for serverMetric in serverMetrics {
      if let localIndex = analyticsMetrics.firstIndex(where: {
        $0.id == serverMetric.id
      }) {
        let localMetric = analyticsMetrics[localIndex]
        let resolvedMetric: AnalyticsMetric

        switch conflictResolution {
        case .newerWins:
          resolvedMetric =
            serverMetric.lastModified > localMetric.lastModified
            ? serverMetric : localMetric
        case .serverWins:
          resolvedMetric = serverMetric
        case .clientWins:
          resolvedMetric = localMetric
        }

        analyticsMetrics[localIndex] = resolvedMetric.markAsSynced()
      } else {
        // New metric from server
        analyticsMetrics.append(serverMetric.markAsSynced())
      }
    }
    saveMetrics()
  }

  // MARK: - Persistence
  private func loadMetrics() {
    guard
      let data = UserDefaults.standard.data(
        forKey: AnalyticsStoreKeys.analyticsMetrics
      ),
      let metrics = try? JSONDecoder().decode(
        [AnalyticsMetric].self,
        from: data
      )
    else {
      return
    }
    analyticsMetrics = metrics
  }

  private func saveMetrics() {
    guard let data = try? JSONEncoder().encode(analyticsMetrics) else {
      lastError = .persistenceFailed
      return
    }
    UserDefaults.standard.set(data, forKey: AnalyticsStoreKeys.analyticsMetrics)
  }
}

// MARK: - Conflict Resolution Strategy (imported from CloudKitSyncService)
// This enum is defined in CloudKitSyncService.swift to avoid duplication
