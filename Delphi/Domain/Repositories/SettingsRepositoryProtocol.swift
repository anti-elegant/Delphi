import Foundation

// MARK: - Settings Repository Protocol
protocol SettingsRepositoryProtocol {
  
  // MARK: - Read
  func getSettings() async throws -> Settings
  func isRemindersEnabled() async throws -> Bool
  func isAnalyticsEnabled() async throws -> Bool
  
  // MARK: - Update
  func updateSettings(_ settings: Settings) async throws
  func setRemindersEnabled(_ enabled: Bool) async throws
  func setAnalyticsEnabled(_ enabled: Bool) async throws
  
  // MARK: - Reset
  func resetToDefaults() async throws
  
  // MARK: - Export
  func exportSettingsData() async throws -> [String: Any]
}

// MARK: - Settings Repository Error Types
enum SettingsRepositoryError: LocalizedError {
  case loadFailed(Error)
  case saveFailed(Error)
  case invalidData
  case exportFailed(Error)
  
  var errorDescription: String? {
    switch self {
    case .loadFailed(let error):
      return "Failed to load settings: \(error.localizedDescription)"
    case .saveFailed(let error):
      return "Failed to save settings: \(error.localizedDescription)"
    case .invalidData:
      return "Invalid settings data"
    case .exportFailed(let error):
      return "Failed to export settings: \(error.localizedDescription)"
    }
  }
}

// MARK: - Settings Change Notification
struct SettingsChange {
  let oldSettings: Settings
  let newSettings: Settings
  let changedAt: Date
  
  var hasRemindersChanged: Bool {
    oldSettings.remindersEnabled != newSettings.remindersEnabled
  }
  
  var hasAnalyticsChanged: Bool {
    oldSettings.analyticsEnabled != newSettings.analyticsEnabled
  }
}

// MARK: - Extended Settings Repository Protocol
protocol SettingsRepositoryProtocol_Extended: SettingsRepositoryProtocol {
  func observeSettings() -> AsyncStream<Settings>
  func observeSettingsChanges() -> AsyncStream<SettingsChange>
}
