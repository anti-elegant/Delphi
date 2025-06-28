import Combine
import SwiftUI
import UIKit
import UserNotifications

// MARK: - Syncable Protocol
@MainActor
protocol Syncable {
  func trackChange(
    id: String,
    recordType: String,
    changeType: LocalChange.ChangeType
  )
}

extension Syncable {
  @MainActor
  func trackChange(
    id: String,
    recordType: String,
    changeType: LocalChange.ChangeType
  ) {
    CloudKitSyncService.shared.trackChange(
      id: id,
      recordType: recordType,
      changeType: changeType
    )
  }
}

// MARK: - Settings Keys
private enum SettingsKeys {
  static let significanceLevel = "significanceLevel"
  static let acceptanceAreaDisplay = "acceptanceAreaDisplay"
  static let syncWithiCloud = "syncWithiCloud"
  static let connectToHealth = "connectToHealth"
  static let remindersEnabled = "remindersEnabled"
  static let selectedAppIcon = "selectedAppIcon"
  static let showAnalytics = "showAnalytics"
  static let lastModified = "settingsLastModified"
  static let needsCloudKitSync = "settingsNeedsCloudKitSync"
}

// MARK: - Settings Store
@MainActor
final class SettingsStore: ObservableObject, Syncable {
  static let shared = SettingsStore()

  // MARK: - Published Properties with AppStorage
  @AppStorage(SettingsKeys.significanceLevel)
  var significanceLevel: Double = 0.05 {
    didSet { handleChange() }
  }

  @AppStorage(SettingsKeys.acceptanceAreaDisplay)
  var acceptanceAreaDisplay: String = "Hide" {
    didSet { handleChange() }
  }

  @AppStorage(SettingsKeys.syncWithiCloud)
  var syncWithiCloud: Bool = false {
    didSet {
      handleChange()
      handleSyncSettingChange()
    }
  }

  @AppStorage(SettingsKeys.connectToHealth)
  var connectToHealth: Bool = false {
    didSet { handleChange() }
  }

  @AppStorage(SettingsKeys.remindersEnabled)
  var remindersEnabled: Bool = false {
    didSet {
      handleChange()
      handleReminderSettingChange()
    }
  }

  @AppStorage(SettingsKeys.selectedAppIcon)
  var selectedAppIcon: String = "AppIcon" {
    didSet { handleChange() }
  }

  @AppStorage(SettingsKeys.showAnalytics)
  var showAnalytics: Bool = true {
    didSet { handleChange() }
  }

  // MARK: - Sync Tracking Properties
  @AppStorage(SettingsKeys.lastModified)
  private var lastModifiedTimestamp: Double = Date().timeIntervalSince1970

  @AppStorage(SettingsKeys.needsCloudKitSync)
  private var needsCloudKitSyncFlag: Bool = true

  @Published private(set) var hasPendingChanges = false

  // MARK: - Constants
  let significanceLevels = [0.01, 0.05, 0.10]
  let availableAppIcons = [
    ("AppIcon", "Light"),
    ("AppIconDark", "Dark"),
    ("AppIconGradient", "Gradient"),
  ]

  // MARK: - Private Properties
  private var isInitialized = false

  // MARK: - Computed Properties
  var shouldShowAcceptanceArea: Bool {
    acceptanceAreaDisplay == "Show"
  }

  var lastModified: Date {
    get { Date(timeIntervalSince1970: lastModifiedTimestamp) }
    set { lastModifiedTimestamp = newValue.timeIntervalSince1970 }
  }

  var needsCloudKitSync: Bool {
    get { needsCloudKitSyncFlag }
    set { needsCloudKitSyncFlag = newValue }
  }

  // MARK: - Initialization
  private init() {
    // Delay initialization to avoid triggering didSet during init
    Task { @MainActor in
      try? await Task.sleep(nanoseconds: 100_000_000)
      isInitialized = true
    }
  }

  // MARK: - Deinitialization
  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: - Business Logic
  func calculateAcceptanceArea(for value: Double) -> (
    lower: Double, upper: Double
  ) {
    let lower = value * (1.0 - significanceLevel)
    let upper = value * (1.0 + significanceLevel)
    return (lower: lower, upper: upper)
  }

  // MARK: - Data Management
  func resetToDefaults() {
    significanceLevel = 0.05
    acceptanceAreaDisplay = "Hide"
    syncWithiCloud = false
    connectToHealth = false
    remindersEnabled = false
    selectedAppIcon = "AppIcon"
    showAnalytics = true
    markForSync()
  }

  func exportSettings() -> [String: Any] {
    return [
      SettingsKeys.significanceLevel: significanceLevel,
      SettingsKeys.acceptanceAreaDisplay: acceptanceAreaDisplay,
      SettingsKeys.syncWithiCloud: syncWithiCloud,
      SettingsKeys.connectToHealth: connectToHealth,
      SettingsKeys.remindersEnabled: remindersEnabled,
      SettingsKeys.selectedAppIcon: selectedAppIcon,
      SettingsKeys.showAnalytics: showAnalytics,
      SettingsKeys.lastModified: lastModifiedTimestamp,
    ]
  }

  // MARK: - CloudKit Sync Support
  func applyServerSettings(
    _ serverSettings: [String: Any],
    conflictResolution: ConflictResolutionStrategy = .newerWins
  ) {
    guard
      let serverLastModified = serverSettings[SettingsKeys.lastModified]
        as? Double
    else {
      return
    }

    let serverDate = Date(timeIntervalSince1970: serverLastModified)
    let shouldApplyServerSettings: Bool

    switch conflictResolution {
    case .newerWins: shouldApplyServerSettings = serverDate > lastModified
    case .serverWins: shouldApplyServerSettings = true
    case .clientWins: shouldApplyServerSettings = false
    }

    guard shouldApplyServerSettings else { return }

    let wasInitialized = isInitialized
    isInitialized = false

    if let value = serverSettings[SettingsKeys.significanceLevel] as? Double {
      significanceLevel = value
    }
    if let value = serverSettings[SettingsKeys.acceptanceAreaDisplay] as? String
    {
      acceptanceAreaDisplay = value
    }
    if let value = serverSettings[SettingsKeys.syncWithiCloud] as? Bool {
      syncWithiCloud = value
    }
    if let value = serverSettings[SettingsKeys.connectToHealth] as? Bool {
      connectToHealth = value
    }
    if let value = serverSettings[SettingsKeys.remindersEnabled] as? Bool {
      remindersEnabled = value
    }
    if let value = serverSettings[SettingsKeys.selectedAppIcon] as? String {
      selectedAppIcon = value
    }
    if let value = serverSettings[SettingsKeys.showAnalytics] as? Bool {
      showAnalytics = value
    }

    lastModified = serverDate
    needsCloudKitSync = false
    isInitialized = wasInitialized
  }

  func markAsSynced() {
    needsCloudKitSync = false
  }

  // MARK: - Private Methods
  private func handleChange() {
    guard isInitialized else { return }
    markForSync()
  }

  private func markForSync() {
    lastModified = Date()
    needsCloudKitSync = true
    trackChange(
      id: "AppSettings",
      recordType: "AppSettings",
      changeType: .updated
    )
  }

  // MARK: - Notification Management
  private func handleReminderSettingChange() {
    guard
      !ProcessInfo.processInfo.environment.keys.contains(
        "XCODE_RUNNING_FOR_PREVIEWS"
      )
    else { return }

    if remindersEnabled {
      Task {
        try await NotificationService.shared.requestNotificationPermission()
        NotificationCenter.default.post(
          name: .scheduleNotificationsForExistingPredictions,
          object: nil
        )
      }
    } else {
      NotificationService.shared.cancelAllNotifications()
    }
  }

  private func handleSyncSettingChange() {
    // Sync coordinator will handle the change automatically

    // Setup CloudKit notifications when iCloud sync is enabled
    if syncWithiCloud {
      Task {
        await setupCloudKitNotificationsIfNeeded()
      }
    }
  }

  private func setupCloudKitNotificationsIfNeeded() async {
    guard
      !ProcessInfo.processInfo.environment.keys.contains(
        "XCODE_RUNNING_FOR_PREVIEWS"
      )
    else { return }

    // Request authorization for CloudKit push notifications (async/await)
    do {
      let granted = try await UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .badge, .sound])
      if granted {
        await MainActor.run {
          UIApplication.shared.registerForRemoteNotifications()
        }
      }
    } catch {
      // Handle potential error if desired (currently ignored)
    }
  }
}

// MARK: - Notification Names
extension Notification.Name {
  static let scheduleNotificationsForExistingPredictions = Notification.Name(
    "scheduleNotificationsForExistingPredictions"
  )
}
