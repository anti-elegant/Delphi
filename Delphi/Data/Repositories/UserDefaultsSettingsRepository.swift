import Foundation

// MARK: - UserDefaults Settings Repository
final class UserDefaultsSettingsRepository: SettingsRepositoryProtocol {
  
  // MARK: - Keys
  private enum Keys {
    // Core Settings
    static let remindersEnabled = "settings.remindersEnabled"
    static let analyticsEnabled = "settings.analyticsEnabled"
    
    // Reminder Settings
    static let reminderInterval = "settings.reminderInterval"
    static let reminderTime = "settings.reminderTime"
    static let overdueReminderEnabled = "settings.overdueReminderEnabled"
    
    // Export Settings
    static let exportFormat = "settings.exportFormat"
    static let includeContextInExport = "settings.includeContextInExport"
    static let autoBackupEnabled = "settings.autoBackupEnabled"
    static let backupFrequency = "settings.backupFrequency"
    
    // Context Tracking Settings
    static let contextTrackingEnabled = "settings.contextTrackingEnabled"
    static let trackMood = "settings.trackMood"
    static let trackPressure = "settings.trackPressure"
    static let trackSleep = "settings.trackSleep"
    static let trackStress = "settings.trackStress"
    static let trackEnvironment = "settings.trackEnvironment"
    static let trackTiming = "settings.trackTiming"
    
    // Display Settings
    static let defaultTimeframe = "settings.defaultTimeframe"
    static let showConfidenceInList = "settings.showConfidenceInList"
    static let groupPredictionsByType = "settings.groupPredictionsByType"
    static let showAccuracyTrends = "settings.showAccuracyTrends"
    
    // Data Management Settings
    static let requireConfirmationForDataClear = "settings.requireConfirmationForDataClear"
    static let autoResolveOverduePredictions = "settings.autoResolveOverduePredictions"
    static let autoResolveAfterDays = "settings.autoResolveAfterDays"
  }
  
  private let userDefaults: UserDefaults
  
  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }
  
  // MARK: - Read Operations
  func getSettings() async throws -> Settings {
    do {
      // Helper function to get value with default
      func getValue<T>(_ key: String, defaultValue: T) -> T {
        let value = userDefaults.object(forKey: key)
        return value as? T ?? defaultValue
      }
      
      func getEnumValue<T: RawRepresentable>(_ key: String, defaultValue: T) -> T where T.RawValue == String {
        let rawValue = getValue(key, defaultValue: defaultValue.rawValue)
        return T(rawValue: rawValue) ?? defaultValue
      }
      
      func getDate(_ key: String) -> Date? {
        guard let timeInterval = userDefaults.object(forKey: key) as? TimeInterval else { return nil }
        return Date(timeIntervalSince1970: timeInterval)
      }
      
      let defaults = Settings.defaultSettings
      
      return Settings(
        remindersEnabled: getValue(Keys.remindersEnabled, defaultValue: defaults.remindersEnabled),
        analyticsEnabled: getValue(Keys.analyticsEnabled, defaultValue: defaults.analyticsEnabled),
        reminderInterval: getEnumValue(Keys.reminderInterval, defaultValue: defaults.reminderInterval),
        reminderTime: getDate(Keys.reminderTime),
        overdueReminderEnabled: getValue(Keys.overdueReminderEnabled, defaultValue: defaults.overdueReminderEnabled),
        exportFormat: getEnumValue(Keys.exportFormat, defaultValue: defaults.exportFormat),
        includeContextInExport: getValue(Keys.includeContextInExport, defaultValue: defaults.includeContextInExport),
        autoBackupEnabled: getValue(Keys.autoBackupEnabled, defaultValue: defaults.autoBackupEnabled),
        backupFrequency: getEnumValue(Keys.backupFrequency, defaultValue: defaults.backupFrequency),
        contextTrackingEnabled: getValue(Keys.contextTrackingEnabled, defaultValue: defaults.contextTrackingEnabled),
        trackMood: getValue(Keys.trackMood, defaultValue: defaults.trackMood),
        trackPressure: getValue(Keys.trackPressure, defaultValue: defaults.trackPressure),
        trackSleep: getValue(Keys.trackSleep, defaultValue: defaults.trackSleep),
        trackStress: getValue(Keys.trackStress, defaultValue: defaults.trackStress),
        trackEnvironment: getValue(Keys.trackEnvironment, defaultValue: defaults.trackEnvironment),
        trackTiming: getValue(Keys.trackTiming, defaultValue: defaults.trackTiming),
        defaultTimeframe: getEnumValue(Keys.defaultTimeframe, defaultValue: defaults.defaultTimeframe),
        showConfidenceInList: getValue(Keys.showConfidenceInList, defaultValue: defaults.showConfidenceInList),
        groupPredictionsByType: getValue(Keys.groupPredictionsByType, defaultValue: defaults.groupPredictionsByType),
        showAccuracyTrends: getValue(Keys.showAccuracyTrends, defaultValue: defaults.showAccuracyTrends),
        requireConfirmationForDataClear: getValue(Keys.requireConfirmationForDataClear, defaultValue: defaults.requireConfirmationForDataClear),
        autoResolveOverduePredictions: getValue(Keys.autoResolveOverduePredictions, defaultValue: defaults.autoResolveOverduePredictions),
        autoResolveAfterDays: getValue(Keys.autoResolveAfterDays, defaultValue: defaults.autoResolveAfterDays)
      )
    } catch {
      throw SettingsRepositoryError.loadFailed(error)
    }
  }
  
  func isRemindersEnabled() async throws -> Bool {
    userDefaults.bool(forKey: Keys.remindersEnabled)
  }
  
  func isAnalyticsEnabled() async throws -> Bool {
    userDefaults.object(forKey: Keys.analyticsEnabled) == nil ? 
      true : userDefaults.bool(forKey: Keys.analyticsEnabled)
  }
  
  // MARK: - Update Operations
  func updateSettings(_ settings: Settings) async throws {
    do {
      // Core Settings
      userDefaults.set(settings.remindersEnabled, forKey: Keys.remindersEnabled)
      userDefaults.set(settings.analyticsEnabled, forKey: Keys.analyticsEnabled)
      
      // Reminder Settings
      userDefaults.set(settings.reminderInterval.rawValue, forKey: Keys.reminderInterval)
      if let reminderTime = settings.reminderTime {
        userDefaults.set(reminderTime.timeIntervalSince1970, forKey: Keys.reminderTime)
      } else {
        userDefaults.removeObject(forKey: Keys.reminderTime)
      }
      userDefaults.set(settings.overdueReminderEnabled, forKey: Keys.overdueReminderEnabled)
      
      // Export Settings
      userDefaults.set(settings.exportFormat.rawValue, forKey: Keys.exportFormat)
      userDefaults.set(settings.includeContextInExport, forKey: Keys.includeContextInExport)
      userDefaults.set(settings.autoBackupEnabled, forKey: Keys.autoBackupEnabled)
      userDefaults.set(settings.backupFrequency.rawValue, forKey: Keys.backupFrequency)
      
      // Context Tracking Settings
      userDefaults.set(settings.contextTrackingEnabled, forKey: Keys.contextTrackingEnabled)
      userDefaults.set(settings.trackMood, forKey: Keys.trackMood)
      userDefaults.set(settings.trackPressure, forKey: Keys.trackPressure)
      userDefaults.set(settings.trackSleep, forKey: Keys.trackSleep)
      userDefaults.set(settings.trackStress, forKey: Keys.trackStress)
      userDefaults.set(settings.trackEnvironment, forKey: Keys.trackEnvironment)
      userDefaults.set(settings.trackTiming, forKey: Keys.trackTiming)
      
      // Display Settings
      userDefaults.set(settings.defaultTimeframe.rawValue, forKey: Keys.defaultTimeframe)
      userDefaults.set(settings.showConfidenceInList, forKey: Keys.showConfidenceInList)
      userDefaults.set(settings.groupPredictionsByType, forKey: Keys.groupPredictionsByType)
      userDefaults.set(settings.showAccuracyTrends, forKey: Keys.showAccuracyTrends)
      
      // Data Management Settings
      userDefaults.set(settings.requireConfirmationForDataClear, forKey: Keys.requireConfirmationForDataClear)
      userDefaults.set(settings.autoResolveOverduePredictions, forKey: Keys.autoResolveOverduePredictions)
      userDefaults.set(settings.autoResolveAfterDays, forKey: Keys.autoResolveAfterDays)
      
      // Ensure changes are persisted
      userDefaults.synchronize()
    } catch {
      throw SettingsRepositoryError.saveFailed(error)
    }
  }
  
  func setRemindersEnabled(_ enabled: Bool) async throws {
    do {
      userDefaults.set(enabled, forKey: Keys.remindersEnabled)
      userDefaults.synchronize()
    } catch {
      throw SettingsRepositoryError.saveFailed(error)
    }
  }
  
  func setAnalyticsEnabled(_ enabled: Bool) async throws {
    do {
      userDefaults.set(enabled, forKey: Keys.analyticsEnabled)
      userDefaults.synchronize()
    } catch {
      throw SettingsRepositoryError.saveFailed(error)
    }
  }
  
  // MARK: - Reset Operations
  func resetToDefaults() async throws {
    do {
      // Remove all settings keys
      let keys = [
        Keys.remindersEnabled, Keys.analyticsEnabled,
        Keys.reminderInterval, Keys.reminderTime, Keys.overdueReminderEnabled,
        Keys.exportFormat, Keys.includeContextInExport, Keys.autoBackupEnabled, Keys.backupFrequency,
        Keys.contextTrackingEnabled, Keys.trackMood, Keys.trackPressure, Keys.trackSleep, Keys.trackStress, Keys.trackEnvironment, Keys.trackTiming,
        Keys.defaultTimeframe, Keys.showConfidenceInList, Keys.groupPredictionsByType, Keys.showAccuracyTrends,
        Keys.requireConfirmationForDataClear, Keys.autoResolveOverduePredictions, Keys.autoResolveAfterDays
      ]
      
      for key in keys {
        userDefaults.removeObject(forKey: key)
      }
      
      userDefaults.synchronize()
    } catch {
      throw SettingsRepositoryError.saveFailed(error)
    }
  }
  
  // MARK: - Export Operations
  func exportSettingsData() async throws -> [String: Any] {
    do {
      let settings = try await getSettings()
      return settings.exportData()
    } catch {
      throw SettingsRepositoryError.exportFailed(error)
    }
  }
}

// MARK: - Extended Settings Repository
extension UserDefaultsSettingsRepository: SettingsRepositoryProtocol_Extended {
  func observeSettings() -> AsyncStream<Settings> {
    AsyncStream { continuation in
      let observer = NotificationCenter.default.addObserver(
        forName: UserDefaults.didChangeNotification,
        object: userDefaults,
        queue: .main
      ) { _ in
        Task {
          do {
            let settings = try await self.getSettings()
            continuation.yield(settings)
          } catch {
            print("Error observing settings: \(error)")
          }
        }
      }
      
      // Yield initial value
      Task {
        do {
          let settings = try await self.getSettings()
          continuation.yield(settings)
        } catch {
          print("Error getting initial settings: \(error)")
        }
      }
      
      continuation.onTermination = { _ in
        NotificationCenter.default.removeObserver(observer)
      }
    }
  }
  
  func observeSettingsChanges() -> AsyncStream<SettingsChange> {
    AsyncStream { continuation in
      var previousSettings: Settings?
      
      let observer = NotificationCenter.default.addObserver(
        forName: UserDefaults.didChangeNotification,
        object: userDefaults,
        queue: .main
      ) { _ in
        Task {
          do {
            let newSettings = try await self.getSettings()
            
            if let oldSettings = previousSettings {
              let change = SettingsChange(
                oldSettings: oldSettings,
                newSettings: newSettings,
                changedAt: Date()
              )
              continuation.yield(change)
            }
            
            previousSettings = newSettings
          } catch {
            print("Error observing settings changes: \(error)")
          }
        }
      }
      
      // Get initial settings
      Task {
        do {
          previousSettings = try await self.getSettings()
        } catch {
          print("Error getting initial settings for observation: \(error)")
        }
      }
      
      continuation.onTermination = { _ in
        NotificationCenter.default.removeObserver(observer)
      }
    }
  }
}

// MARK: - Testing Support
#if DEBUG
extension UserDefaultsSettingsRepository {
  static func createTestRepository() -> UserDefaultsSettingsRepository {
    let testDefaults = UserDefaults(suiteName: "TestDefaults-\(UUID().uuidString)")!
    return UserDefaultsSettingsRepository(userDefaults: testDefaults)
  }
  
  func clearAllSettings() {
    let keys = [
      Keys.remindersEnabled, Keys.analyticsEnabled,
      Keys.reminderInterval, Keys.reminderTime, Keys.overdueReminderEnabled,
      Keys.exportFormat, Keys.includeContextInExport, Keys.autoBackupEnabled, Keys.backupFrequency,
      Keys.contextTrackingEnabled, Keys.trackMood, Keys.trackPressure, Keys.trackSleep, Keys.trackStress, Keys.trackEnvironment, Keys.trackTiming,
      Keys.defaultTimeframe, Keys.showConfidenceInList, Keys.groupPredictionsByType, Keys.showAccuracyTrends,
      Keys.requireConfirmationForDataClear, Keys.autoResolveOverduePredictions, Keys.autoResolveAfterDays
    ]
    
    for key in keys {
      userDefaults.removeObject(forKey: key)
    }
    userDefaults.synchronize()
  }
}
#endif

// MARK: - Migration Support
extension UserDefaultsSettingsRepository {
  func migrateOldSettingsIfNeeded() async throws {
    let oldRemindersKey = "remindersEnabled"
    let oldAnalyticsKey = "showAnalytics"
    
    // Migrate reminders setting
    if userDefaults.object(forKey: oldRemindersKey) != nil {
      let oldValue = userDefaults.bool(forKey: oldRemindersKey)
      userDefaults.set(oldValue, forKey: Keys.remindersEnabled)
      userDefaults.removeObject(forKey: oldRemindersKey)
    }
    
    // Migrate analytics setting
    if userDefaults.object(forKey: oldAnalyticsKey) != nil {
      let oldValue = userDefaults.bool(forKey: oldAnalyticsKey)
      userDefaults.set(oldValue, forKey: Keys.analyticsEnabled)
      userDefaults.removeObject(forKey: oldAnalyticsKey)
    }
    
    userDefaults.synchronize()
  }
}