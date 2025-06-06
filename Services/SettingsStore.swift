import Combine
import SwiftUI

// MARK: - Settings Keys
private enum SettingsKeys {
  static let significanceLevel = "significanceLevel"
  static let acceptanceAreaDisplay = "acceptanceAreaDisplay"
  static let syncWithiCloud = "syncWithiCloud"
  static let connectToHealth = "connectToHealth"
  static let remindersEnabled = "remindersEnabled"
}

// MARK: - Settings Store
@MainActor
final class SettingsStore: ObservableObject {
  static let shared = SettingsStore()

  // MARK: - Published Properties with AppStorage
  @AppStorage(SettingsKeys.significanceLevel)
  var significanceLevel: Double = 0.05

  @AppStorage(SettingsKeys.acceptanceAreaDisplay)
  var acceptanceAreaDisplay: String = "Hide"

  @AppStorage(SettingsKeys.syncWithiCloud)
  var syncWithiCloud: Bool = false

  @AppStorage(SettingsKeys.connectToHealth)
  var connectToHealth: Bool = false

  @AppStorage(SettingsKeys.remindersEnabled)
  var remindersEnabled: Bool = true

  // MARK: - Constants
  let significanceLevels = [0.01, 0.05, 0.10]

  // MARK: - Computed Properties
  var shouldShowAcceptanceArea: Bool {
    acceptanceAreaDisplay == "Show"
  }

  // MARK: - Initialization
  private init() {
    // AppStorage handles initialization automatically
    // This ensures the singleton pattern
  }

  // MARK: - Business Logic
  func calculateAcceptanceArea(for value: Double) -> (
    lower: Double, upper: Double
  ) {
    // Convert significance level to confidence interval
    // For example: 0.05 significance = 95% confidence interval
    let confidenceLevel = 1.0 - significanceLevel

    // Use confidence level for margin calculation
    // Higher confidence level = tighter acceptance area (more precise)
    let marginOfError = (1.0 - confidenceLevel) * 5  // This gives us a reasonable range

    let lower = value * (1.0 - marginOfError)
    let upper = value * (1.0 + marginOfError)

    return (lower: lower, upper: upper)
  }

  // MARK: - Data Management
  func resetToDefaults() {
    significanceLevel = 0.05
    acceptanceAreaDisplay = "Hide"
    syncWithiCloud = false
    connectToHealth = false
    remindersEnabled = true
  }

  func exportSettings() -> [String: Any] {
    return [
      SettingsKeys.significanceLevel: significanceLevel,
      SettingsKeys.acceptanceAreaDisplay: acceptanceAreaDisplay,
      SettingsKeys.syncWithiCloud: syncWithiCloud,
      SettingsKeys.connectToHealth: connectToHealth,
      SettingsKeys.remindersEnabled: remindersEnabled,
    ]
  }
}
