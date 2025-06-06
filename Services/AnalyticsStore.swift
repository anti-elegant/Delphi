import Foundation
import SwiftUI

// MARK: - Analytics Metric Model
struct AnalyticsMetric: Identifiable, Codable, Hashable {
  let id = UUID()
  let icon: String
  let title: String
  let value: String
  let unit: String
  let percentage: Double
  let description: String
  let isLocked: Bool

  init(
    icon: String,
    title: String,
    value: String = "",
    unit: String = "",
    percentage: Double = 0.0,
    description: String,
    isLocked: Bool = false
  ) {
    self.icon = icon
    self.title = title
    self.value = value
    self.unit = unit
    self.percentage = percentage
    self.description = description
    self.isLocked = isLocked
  }

  enum CodingKeys: String, CodingKey {
    case icon, title, value, unit, percentage, description, isLocked
  }
}

// MARK: - Analytics Store Error Types
enum AnalyticsStoreError: LocalizedError {
  case encodingFailed
  case decodingFailed
  case metricNotFound(String)

  var errorDescription: String? {
    switch self {
    case .encodingFailed:
      return "Failed to encode analytics metrics"
    case .decodingFailed:
      return "Failed to decode analytics metrics"
    case .metricNotFound(let title):
      return "Metric '\(title)' not found"
    }
  }
}

// MARK: - Analytics Store Keys
private enum AnalyticsStoreKeys {
  static let analyticsMetrics = "analyticsMetrics"
}

// MARK: - Analytics Store
@MainActor
final class AnalyticsStore: ObservableObject {
  static let shared = AnalyticsStore()

  // MARK: - Published Properties
  @Published private(set) var analyticsMetrics: [AnalyticsMetric]
  @Published private(set) var isLoading = false
  @Published private(set) var lastError: AnalyticsStoreError?

  // MARK: - Initialization
  private init() {
    self.analyticsMetrics = []
    loadMetrics()
  }

  // MARK: - Public Interface
  func updateMetric(title: String, value: String, percentage: Double) {
    guard let index = analyticsMetrics.firstIndex(where: { $0.title == title })
    else {
      lastError = .metricNotFound(title)
      return
    }

    let updatedMetric = AnalyticsMetric(
      icon: analyticsMetrics[index].icon,
      title: analyticsMetrics[index].title,
      value: value,
      unit: analyticsMetrics[index].unit,
      percentage: percentage,
      description: analyticsMetrics[index].description,
      isLocked: analyticsMetrics[index].isLocked
    )

    analyticsMetrics[index] = updatedMetric
    saveMetrics()
  }

  func unlockMetric(title: String) {
    guard let index = analyticsMetrics.firstIndex(where: { $0.title == title })
    else {
      lastError = .metricNotFound(title)
      return
    }

    let unlockedMetric = AnalyticsMetric(
      icon: analyticsMetrics[index].icon,
      title: analyticsMetrics[index].title,
      value: analyticsMetrics[index].value,
      unit: analyticsMetrics[index].unit,
      percentage: analyticsMetrics[index].percentage,
      description: analyticsMetrics[index].description,
      isLocked: false
    )

    analyticsMetrics[index] = unlockedMetric
    saveMetrics()
  }

  func resetToDefaults() {
    analyticsMetrics = Self.defaultMetrics()
    saveMetrics()
  }

  // MARK: - Private Methods
  private func loadMetrics() {
    isLoading = true
    defer { isLoading = false }

    guard
      let data = UserDefaults.standard.data(
        forKey: AnalyticsStoreKeys.analyticsMetrics
      )
    else {
      analyticsMetrics = Self.defaultMetrics()
      return
    }

    do {
      analyticsMetrics = try JSONDecoder().decode(
        [AnalyticsMetric].self,
        from: data
      )
      lastError = nil
    } catch {
      lastError = .decodingFailed
      analyticsMetrics = Self.defaultMetrics()
    }
  }

  private func saveMetrics() {
    do {
      let data = try JSONEncoder().encode(analyticsMetrics)
      UserDefaults.standard.set(
        data,
        forKey: AnalyticsStoreKeys.analyticsMetrics
      )
      lastError = nil
    } catch {
      lastError = .encodingFailed
    }
  }

  private static func defaultMetrics() -> [AnalyticsMetric] {
    return [
      AnalyticsMetric(
        icon: "target",
        title: "Accuracy",
        value: "73.2%",
        unit: "",
        percentage: 0.732,
        description:
          "Accuracy measures how often your predictions turn out to be correct. This score is calculated based on the percentage of your predictions that have been validated as accurate over time. A higher accuracy score indicates better predictive skills and more reliable forecasting abilities."
      ),
      AnalyticsMetric(
        icon: "gauge.with.needle",
        title: "Pressure",
        value: "0.34",
        unit: "PCC",
        percentage: 0.34,
        description:
          "Pressure represents the correlation between external stress factors and your prediction accuracy. The Pearson Correlation Coefficient (PCC) measures how environmental pressures, deadlines, or high-stakes situations affect your forecasting performance. Lower values suggest better resilience under pressure."
      ),
      AnalyticsMetric(
        icon: "apple.meditate.circle",
        title: "Mood",
        value: "0.67",
        unit: "PCC",
        percentage: 0.67,
        description:
          "Mood correlation shows how your emotional state influences prediction accuracy. This metric tracks the relationship between your reported mood levels and the quality of your forecasts. Understanding this correlation helps identify optimal mental states for making important predictions.",
        isLocked: true
      ),
      AnalyticsMetric(
        icon: "pills.circle",
        title: "Medicine",
        value: "0.88",
        unit: "PCC",
        percentage: 0.88,
        description:
          "Medicine correlation measures how medical factors such as medication timing, health status, or physical wellness affect your cognitive prediction abilities. This high correlation suggests that your physical health significantly impacts your forecasting accuracy and decision-making clarity."
      ),
    ]
  }
}
