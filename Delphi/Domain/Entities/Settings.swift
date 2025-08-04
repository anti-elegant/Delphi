import Foundation

// MARK: - Settings Domain Entity
struct Settings {
  // MARK: - Core Settings
  let remindersEnabled: Bool
  let analyticsEnabled: Bool
  
  // MARK: - Reminder Settings
  let reminderInterval: ReminderInterval
  let reminderTime: Date? // Time of day for daily reminders
  let overdueReminderEnabled: Bool
  
  // MARK: - Export Settings
  let exportFormat: ExportFormat
  let includeContextInExport: Bool
  let autoBackupEnabled: Bool
  let backupFrequency: BackupFrequency
  
  // MARK: - Context Tracking Settings
  let contextTrackingEnabled: Bool
  let trackMood: Bool
  let trackPressure: Bool
  let trackSleep: Bool
  let trackStress: Bool
  let trackEnvironment: Bool
  let trackTiming: Bool
  
  // MARK: - Display Settings
  let defaultTimeframe: DefaultTimeframe
  let showConfidenceInList: Bool
  let groupPredictionsByType: Bool
  let showAccuracyTrends: Bool
  
  // MARK: - Data Management Settings
  let requireConfirmationForDataClear: Bool
  let autoResolveOverduePredictions: Bool
  let autoResolveAfterDays: Int
  
  // MARK: - Computed Properties
  var shouldShowNotifications: Bool {
    remindersEnabled
  }
  
  var shouldShowAnalytics: Bool {
    analyticsEnabled
  }
  
  var shouldTrackAnyContext: Bool {
    contextTrackingEnabled && (trackMood || trackPressure || trackSleep || trackStress || trackEnvironment || trackTiming)
  }
  
  var effectiveReminderTime: Date? {
    remindersEnabled ? reminderTime : nil
  }
}

// MARK: - Supporting Enums

// MARK: - Reminder Interval
enum ReminderInterval: String, CaseIterable, Codable, Sendable {
  case disabled = "disabled"
  case daily = "daily"
  case weekly = "weekly"
  case biweekly = "biweekly"
  case monthly = "monthly"
  
  var displayName: String {
    switch self {
    case .disabled: return "Disabled"
    case .daily: return "Daily"
    case .weekly: return "Weekly"
    case .biweekly: return "Bi-weekly"
    case .monthly: return "Monthly"
    }
  }
  
  var description: String {
    switch self {
    case .disabled: return "No reminders"
    case .daily: return "Remind me every day"
    case .weekly: return "Remind me weekly"
    case .biweekly: return "Remind me every two weeks"
    case .monthly: return "Remind me monthly"
    }
  }
}

// MARK: - Export Format
enum ExportFormat: String, CaseIterable, Codable, Sendable {
  case json = "json"
  case csv = "csv"
  case text = "text"
  
  var displayName: String {
    switch self {
    case .json: return "JSON"
    case .csv: return "CSV"
    case .text: return "Plain Text"
    }
  }
  
  var fileExtension: String {
    switch self {
    case .json: return "json"
    case .csv: return "csv"
    case .text: return "txt"
    }
  }
}

// MARK: - Backup Frequency
enum BackupFrequency: String, CaseIterable, Codable, Sendable {
  case never = "never"
  case daily = "daily"
  case weekly = "weekly"
  case monthly = "monthly"
  
  var displayName: String {
    switch self {
    case .never: return "Never"
    case .daily: return "Daily"
    case .weekly: return "Weekly"
    case .monthly: return "Monthly"
    }
  }
}

// MARK: - Default Timeframe
enum DefaultTimeframe: String, CaseIterable, Codable, Sendable {
  case week = "week"
  case month = "month"
  case quarter = "quarter"
  case year = "year"
  case all = "all"
  
  var displayName: String {
    switch self {
    case .week: return "This Week"
    case .month: return "This Month"
    case .quarter: return "This Quarter"
    case .year: return "This Year"
    case .all: return "All Time"
    }
  }
  
  var days: Int? {
    switch self {
    case .week: return 7
    case .month: return 30
    case .quarter: return 90
    case .year: return 365
    case .all: return nil
    }
  }
}

// MARK: - Default Settings
extension Settings {
  static let defaultSettings = Settings(
    remindersEnabled: false,
    analyticsEnabled: true,
    reminderInterval: .weekly,
    reminderTime: nil,
    overdueReminderEnabled: true,
    exportFormat: .json,
    includeContextInExport: true,
    autoBackupEnabled: false,
    backupFrequency: .weekly,
    contextTrackingEnabled: true,
    trackMood: true,
    trackPressure: false,
    trackSleep: true,
    trackStress: true,
    trackEnvironment: false,
    trackTiming: true,
    defaultTimeframe: .month,
    showConfidenceInList: true,
    groupPredictionsByType: true,
    showAccuracyTrends: true,
    requireConfirmationForDataClear: true,
    autoResolveOverduePredictions: false,
    autoResolveAfterDays: 30
  )
}

// MARK: - Protocol Conformances
extension Settings: Equatable {}

extension Settings: Codable {}

// MARK: - Update Methods
extension Settings {
  func withReminders(_ enabled: Bool) -> Settings {
    Settings(
      remindersEnabled: enabled,
      analyticsEnabled: self.analyticsEnabled,
      reminderInterval: self.reminderInterval,
      reminderTime: self.reminderTime,
      overdueReminderEnabled: self.overdueReminderEnabled,
      exportFormat: self.exportFormat,
      includeContextInExport: self.includeContextInExport,
      autoBackupEnabled: self.autoBackupEnabled,
      backupFrequency: self.backupFrequency,
      contextTrackingEnabled: self.contextTrackingEnabled,
      trackMood: self.trackMood,
      trackPressure: self.trackPressure,
      trackSleep: self.trackSleep,
      trackStress: self.trackStress,
      trackEnvironment: self.trackEnvironment,
      trackTiming: self.trackTiming,
      defaultTimeframe: self.defaultTimeframe,
      showConfidenceInList: self.showConfidenceInList,
      groupPredictionsByType: self.groupPredictionsByType,
      showAccuracyTrends: self.showAccuracyTrends,
      requireConfirmationForDataClear: self.requireConfirmationForDataClear,
      autoResolveOverduePredictions: self.autoResolveOverduePredictions,
      autoResolveAfterDays: self.autoResolveAfterDays
    )
  }
  
  func withAnalytics(_ enabled: Bool) -> Settings {
    Settings(
      remindersEnabled: self.remindersEnabled,
      analyticsEnabled: enabled,
      reminderInterval: self.reminderInterval,
      reminderTime: self.reminderTime,
      overdueReminderEnabled: self.overdueReminderEnabled,
      exportFormat: self.exportFormat,
      includeContextInExport: self.includeContextInExport,
      autoBackupEnabled: self.autoBackupEnabled,
      backupFrequency: self.backupFrequency,
      contextTrackingEnabled: self.contextTrackingEnabled,
      trackMood: self.trackMood,
      trackPressure: self.trackPressure,
      trackSleep: self.trackSleep,
      trackStress: self.trackStress,
      trackEnvironment: self.trackEnvironment,
      trackTiming: self.trackTiming,
      defaultTimeframe: self.defaultTimeframe,
      showConfidenceInList: self.showConfidenceInList,
      groupPredictionsByType: self.groupPredictionsByType,
      showAccuracyTrends: self.showAccuracyTrends,
      requireConfirmationForDataClear: self.requireConfirmationForDataClear,
      autoResolveOverduePredictions: self.autoResolveOverduePredictions,
      autoResolveAfterDays: self.autoResolveAfterDays
    )
  }
  
  func withReminderInterval(_ interval: ReminderInterval) -> Settings {
    Settings(
      remindersEnabled: self.remindersEnabled,
      analyticsEnabled: self.analyticsEnabled,
      reminderInterval: interval,
      reminderTime: self.reminderTime,
      overdueReminderEnabled: self.overdueReminderEnabled,
      exportFormat: self.exportFormat,
      includeContextInExport: self.includeContextInExport,
      autoBackupEnabled: self.autoBackupEnabled,
      backupFrequency: self.backupFrequency,
      contextTrackingEnabled: self.contextTrackingEnabled,
      trackMood: self.trackMood,
      trackPressure: self.trackPressure,
      trackSleep: self.trackSleep,
      trackStress: self.trackStress,
      trackEnvironment: self.trackEnvironment,
      trackTiming: self.trackTiming,
      defaultTimeframe: self.defaultTimeframe,
      showConfidenceInList: self.showConfidenceInList,
      groupPredictionsByType: self.groupPredictionsByType,
      showAccuracyTrends: self.showAccuracyTrends,
      requireConfirmationForDataClear: self.requireConfirmationForDataClear,
      autoResolveOverduePredictions: self.autoResolveOverduePredictions,
      autoResolveAfterDays: self.autoResolveAfterDays
    )
  }
  
  func withContextTracking(_ enabled: Bool) -> Settings {
    Settings(
      remindersEnabled: self.remindersEnabled,
      analyticsEnabled: self.analyticsEnabled,
      reminderInterval: self.reminderInterval,
      reminderTime: self.reminderTime,
      overdueReminderEnabled: self.overdueReminderEnabled,
      exportFormat: self.exportFormat,
      includeContextInExport: self.includeContextInExport,
      autoBackupEnabled: self.autoBackupEnabled,
      backupFrequency: self.backupFrequency,
      contextTrackingEnabled: enabled,
      trackMood: self.trackMood,
      trackPressure: self.trackPressure,
      trackSleep: self.trackSleep,
      trackStress: self.trackStress,
      trackEnvironment: self.trackEnvironment,
      trackTiming: self.trackTiming,
      defaultTimeframe: self.defaultTimeframe,
      showConfidenceInList: self.showConfidenceInList,
      groupPredictionsByType: self.groupPredictionsByType,
      showAccuracyTrends: self.showAccuracyTrends,
      requireConfirmationForDataClear: self.requireConfirmationForDataClear,
      autoResolveOverduePredictions: self.autoResolveOverduePredictions,
      autoResolveAfterDays: self.autoResolveAfterDays
    )
  }
  
  func withExportFormat(_ format: ExportFormat) -> Settings {
    Settings(
      remindersEnabled: self.remindersEnabled,
      analyticsEnabled: self.analyticsEnabled,
      reminderInterval: self.reminderInterval,
      reminderTime: self.reminderTime,
      overdueReminderEnabled: self.overdueReminderEnabled,
      exportFormat: format,
      includeContextInExport: self.includeContextInExport,
      autoBackupEnabled: self.autoBackupEnabled,
      backupFrequency: self.backupFrequency,
      contextTrackingEnabled: self.contextTrackingEnabled,
      trackMood: self.trackMood,
      trackPressure: self.trackPressure,
      trackSleep: self.trackSleep,
      trackStress: self.trackStress,
      trackEnvironment: self.trackEnvironment,
      trackTiming: self.trackTiming,
      defaultTimeframe: self.defaultTimeframe,
      showConfidenceInList: self.showConfidenceInList,
      groupPredictionsByType: self.groupPredictionsByType,
      showAccuracyTrends: self.showAccuracyTrends,
      requireConfirmationForDataClear: self.requireConfirmationForDataClear,
      autoResolveOverduePredictions: self.autoResolveOverduePredictions,
      autoResolveAfterDays: self.autoResolveAfterDays
    )
  }
  
  func resetToDefaults() -> Settings {
    Settings.defaultSettings
  }
}

// MARK: - Validation
extension Settings {
  enum ValidationError: LocalizedError {
    case invalidAutoResolveAfterDays
    case invalidReminderTime
    
    var errorDescription: String? {
      switch self {
      case .invalidAutoResolveAfterDays:
        return "Auto resolve after days must be between 1 and 365"
      case .invalidReminderTime:
        return "Reminder time must be a valid time"
      }
    }
  }
  
  func validate() throws {
    guard autoResolveAfterDays >= 1 && autoResolveAfterDays <= 365 else {
      throw ValidationError.invalidAutoResolveAfterDays
    }
  }
}

// MARK: - Export Data
extension Settings {
  func exportData() -> [String: Any] {
    [
      "remindersEnabled": remindersEnabled,
      "analyticsEnabled": analyticsEnabled,
      "reminderInterval": reminderInterval.rawValue,
      "overdueReminderEnabled": overdueReminderEnabled,
      "exportFormat": exportFormat.rawValue,
      "includeContextInExport": includeContextInExport,
      "autoBackupEnabled": autoBackupEnabled,
      "backupFrequency": backupFrequency.rawValue,
      "contextTrackingEnabled": contextTrackingEnabled,
      "trackMood": trackMood,
      "trackPressure": trackPressure,
      "trackSleep": trackSleep,
      "trackStress": trackStress,
      "trackEnvironment": trackEnvironment,
      "trackTiming": trackTiming,
      "defaultTimeframe": defaultTimeframe.rawValue,
      "showConfidenceInList": showConfidenceInList,
      "groupPredictionsByType": groupPredictionsByType,
      "showAccuracyTrends": showAccuracyTrends,
      "requireConfirmationForDataClear": requireConfirmationForDataClear,
      "autoResolveOverduePredictions": autoResolveOverduePredictions,
      "autoResolveAfterDays": autoResolveAfterDays,
      "exportedAt": Date().timeIntervalSince1970
    ]
  }
}

// MARK: - Extensions for Identifiable
extension ReminderInterval: Identifiable { var id: String { rawValue } }
extension ExportFormat: Identifiable { var id: String { rawValue } }
extension BackupFrequency: Identifiable { var id: String { rawValue } }
extension DefaultTimeframe: Identifiable { var id: String { rawValue } }
