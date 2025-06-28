import BackgroundTasks
import CloudKit
import Foundation
import Network
import SwiftData
import UIKit

// MARK: - CloudKit Sync Error Types
enum CloudKitSyncError: LocalizedError, Equatable, Sendable {
  case iCloudAccountNotAvailable
  case permissionDenied
  case networkUnavailable
  case syncFailed(String)
  case recordNotFound
  case quotaExceeded
  case unknownError
  case conflictResolutionFailed
  case batchOperationFailed
  case changeTokenInvalid

  static func == (lhs: CloudKitSyncError, rhs: CloudKitSyncError) -> Bool {
    switch (lhs, rhs) {
    case (.iCloudAccountNotAvailable, .iCloudAccountNotAvailable),
      (.permissionDenied, .permissionDenied),
      (.networkUnavailable, .networkUnavailable),
      (.recordNotFound, .recordNotFound),
      (.quotaExceeded, .quotaExceeded),
      (.unknownError, .unknownError),
      (.conflictResolutionFailed, .conflictResolutionFailed),
      (.batchOperationFailed, .batchOperationFailed),
      (.changeTokenInvalid, .changeTokenInvalid):
      return true
    case (.syncFailed, .syncFailed):
      return true  // Simplified comparison for errors
    default:
      return false
    }
  }

  var errorDescription: String? {
    switch self {
    case .iCloudAccountNotAvailable:
      return
        "iCloud account is not available. Please sign in to iCloud in Settings."
    case .permissionDenied:
      return "Permission denied for iCloud access."
    case .networkUnavailable:
      return "Network connection is required for iCloud sync."
    case .syncFailed(let message):
      return "Sync failed: \(message)"
    case .recordNotFound:
      return "Record not found in iCloud."
    case .quotaExceeded:
      return "iCloud storage quota exceeded."
    case .unknownError:
      return "An unknown error occurred during sync."
    case .conflictResolutionFailed:
      return "Failed to resolve data conflicts during sync."
    case .batchOperationFailed:
      return "Batch operation failed during sync."
    case .changeTokenInvalid:
      return "Sync state is invalid. A full sync will be performed."
    }
  }
}

// MARK: - Sync Status
enum SyncStatus: Equatable, Sendable {
  case idle
  case syncing
  case success
  case error(CloudKitSyncError)

  static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
    switch (lhs, rhs) {
    case (.idle, .idle), (.syncing, .syncing), (.success, .success):
      return true
    case (.error(let lhsError), .error(let rhsError)):
      return lhsError == rhsError
    default:
      return false
    }
  }
}

// MARK: - Conflict Resolution Strategy
enum ConflictResolutionStrategy: Sendable {
  case newerWins
  case serverWins
  case clientWins
}

// MARK: - Sync Configuration
struct SyncConfiguration: Sendable {
  let batchSize: Int
  let maxRetries: Int
  let retryDelay: TimeInterval
  let conflictResolutionStrategy: ConflictResolutionStrategy
  let debounceDelay: TimeInterval
  let backgroundSyncInterval: TimeInterval
  let incrementalSyncThreshold: Int
  let maxSyncFrequency: TimeInterval  // Minimum time between syncs

  static let `default` = SyncConfiguration(
    batchSize: 50,  // Reduced for better performance
    maxRetries: 3,
    retryDelay: 2.0,
    conflictResolutionStrategy: .newerWins,
    debounceDelay: 3.0,  // Wait 3 seconds after last change before syncing
    backgroundSyncInterval: 300.0,  // Background sync every 5 minutes
    incrementalSyncThreshold: 10,  // Switch to incremental sync after 10 items
    maxSyncFrequency: 30.0  // Don't sync more than once every 30 seconds
  )
}

// MARK: - Deletion Tracking
struct DeletionRecord: Codable, Sendable {
  let id: String
  let recordType: String
  let deletedAt: Date

  init(id: String, recordType: String, deletedAt: Date = Date()) {
    self.id = id
    self.recordType = recordType
    self.deletedAt = deletedAt
  }
}

// MARK: - Local Change Tracking
struct LocalChange: Codable, Sendable {
  let id: String
  let recordType: String
  let changeType: ChangeType
  let timestamp: Date

  enum ChangeType: String, Codable, Sendable {
    case created
    case updated
    case deleted
  }

  init(
    id: String,
    recordType: String,
    changeType: ChangeType,
    timestamp: Date = Date()
  ) {
    self.id = id
    self.recordType = recordType
    self.changeType = changeType
    self.timestamp = timestamp
  }
}

// Moved to top of file to be accessible by other classes

// MARK: - CloudKit Record Extensions
extension CKRecord {
  convenience init(from prediction: Prediction, in zoneID: CKRecordZone.ID) {
    let recordID = CKRecord.ID(
      recordName: "prediction_\(prediction.id.uuidString)",
      zoneID: zoneID
    )
    self.init(
      recordType: CloudKitSyncService.RecordType.prediction,
      recordID: recordID
    )

    self["id"] = prediction.id.uuidString
    self["eventName"] = prediction.eventName.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    self["eventDescription"] = prediction.eventDescription.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    self["confidenceLevel"] = Swift.max(
      0.0,
      Swift.min(100.0, prediction.confidenceLevel)
    )
    self["estimatedValue"] = prediction.estimatedValue
    self["booleanValue"] = prediction.booleanValue
    self["pressureLevel"] = prediction.pressureLevel
    self["currentMood"] = prediction.currentMood
    self["takesMedicine"] = prediction.takesMedicine
    self["evidenceList"] = prediction.evidenceList
    self["selectedType"] = prediction.selectedType.rawValue
    self["dateCreated"] = prediction.dateCreated
    self["dueDate"] = prediction.dueDate
    self["resolutionDate"] = prediction.resolutionDate
    self["isPending"] = prediction.isPending ? 1 : 0
    self["isResolved"] = prediction.isResolved ? 1 : 0
    self["actualOutcome"] = prediction.actualOutcome
    self["lastModified"] = prediction.lastModified
  }
}

// MARK: - CloudKit Sync Service
/// CloudKit sync service for Delphi prediction tracker app
///
/// REQUIREMENTS:
/// 1. Add CloudKit capability in Xcode project settings
/// 2. Use default CloudKit container (CKContainer.default())
/// 3. Configure CloudKit schema with record types: Prediction, AnalyticsMetrics, AppSettings
/// 4. Enable CloudKit entitlement in app's entitlements file
@MainActor
final class CloudKitSyncService: ObservableObject {
  static let shared = CloudKitSyncService()

  // MARK: - Properties
  private var container: CKContainer?
  private var modelContext: ModelContext?
  private let configuration: SyncConfiguration

  @Published private(set) var syncStatus: SyncStatus = .idle
  @Published private(set) var lastSyncDate: Date?
  @Published private(set) var isInitialSetupComplete = false
  @Published private(set) var syncProgress: Double = 0.0
  @Published private(set) var pendingChangesCount: Int = 0

  // MARK: - Sync Timing
  private var debounceTimer: Timer?
  private var backgroundSyncTimer: Timer?
  private var lastSyncAttempt: Date?
  private var hasPendingChanges = false

  // MARK: - Network Monitoring
  private let networkMonitor = NWPathMonitor()
  private let networkQueue = DispatchQueue(label: "NetworkMonitor")
  @Published private(set) var isNetworkAvailable = false

  // MARK: - Computed Properties
  private var privateDatabase: CKDatabase? {
    container?.privateCloudDatabase
  }

  // MARK: - Record Types
  enum RecordType {
    static let prediction = "Prediction"
    static let analyticsMetrics = "AnalyticsMetric"
    static let appSettings = "AppSettings"
    static let tombstone = "TombstoneRecord"  // For tracking deletions
  }

  // MARK: - Change Tracking
  private var pendingChanges: [LocalChange] = []
  private var deletionRecords: [DeletionRecord] = []
  private let changeTrackingQueue = DispatchQueue(
    label: "ChangeTracking",
    qos: .utility
  )

  // MARK: - Zone Configuration
  private let customZoneID = CKRecordZone.ID(zoneName: "DelphiAppZone")

  // MARK: - Background Task Identifiers
  static let backgroundSyncTaskIdentifier = "com.delphi.background-sync"

  // MARK: - Change Tokens
  private var predictionChangeToken: CKServerChangeToken? {
    get {
      guard
        let data = UserDefaults.standard.data(forKey: "predictionChangeToken")
      else { return nil }
      return try? NSKeyedUnarchiver.unarchivedObject(
        ofClass: CKServerChangeToken.self,
        from: data
      )
    }
    set {
      if let token = newValue {
        let data = try? NSKeyedArchiver.archivedData(
          withRootObject: token,
          requiringSecureCoding: true
        )
        UserDefaults.standard.set(data, forKey: "predictionChangeToken")
      } else {
        UserDefaults.standard.removeObject(forKey: "predictionChangeToken")
      }
    }
  }

  // MARK: - Initialization
  private init(configuration: SyncConfiguration = .default) {
    self.configuration = configuration
    self.container = nil
    self.modelContext = nil

    #if !targetEnvironment(simulator)
      if !ProcessInfo.processInfo.environment.keys.contains(
        "XCODE_RUNNING_FOR_PREVIEWS"
      ) {
        loadLastSyncDate()
        loadChangeTracking()
        setupNotificationObservers()
        registerBackgroundTasks()
        startNetworkMonitoring()
      }
    #endif
  }

  // MARK: - Deinitialization
  deinit {
    debounceTimer?.invalidate()
    backgroundSyncTimer?.invalidate()
    networkMonitor.cancel()
    NotificationCenter.default.removeObserver(self)
  }

  private func setupNotificationObservers() {
    // Listen for app lifecycle changes to sync pending changes when app becomes active
    NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      #if !targetEnvironment(simulator)
        if !ProcessInfo.processInfo.environment.keys.contains(
          "XCODE_RUNNING_FOR_PREVIEWS"
        ) {
          Task { [weak self] in
            guard let self = self else { return }
            await self.syncPendingChangesIfNeeded()
          }
        }
      #endif
    }

    // Schedule background sync when app goes to background
    NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.scheduleBackgroundSync()
      }
    }

    // Cancel background sync when app enters foreground
    NotificationCenter.default.addObserver(
      forName: UIApplication.willEnterForegroundNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.cancelBackgroundSync()
      }
    }
  }

  // MARK: - Public Interface
  func enableSync() async throws {
    guard
      !ProcessInfo.processInfo.environment.keys.contains(
        "XCODE_RUNNING_FOR_PREVIEWS"
      )
    else { return }

    #if targetEnvironment(simulator)
      return
    #else
      guard SettingsStore.shared.syncWithiCloud else { return }

      try await checkAccountStatus()
      try await performInitialSetup()

      // Perform initial sync
      try await performFullSync()
    #endif
  }

  // MARK: - Change-Based Sync Interface
  func markDataChanged() {
    guard SettingsStore.shared.syncWithiCloud && isNetworkAvailable else {
      return
    }

    hasPendingChanges = true
    scheduleDebouncedSync()
  }

  // MARK: - Change Tracking Methods
  func trackChange(
    id: String,
    recordType: String,
    changeType: LocalChange.ChangeType
  ) {
    Task { [weak self] in
      guard let self = self else { return }

      let change = LocalChange(
        id: id,
        recordType: recordType,
        changeType: changeType
      )
      await MainActor.run {
        self.pendingChanges.append(change)
        self.saveChangeTracking()
        self.markDataChanged()
      }

      await self.updatePendingChangesCount()
    }
  }

  func trackDeletion(id: String, recordType: String) {
    Task { [weak self] in
      guard let self = self else { return }

      let deletion = DeletionRecord(id: id, recordType: recordType)
      await MainActor.run {
        self.deletionRecords.append(deletion)
        self.saveChangeTracking()
        self.markDataChanged()
      }

      await self.updatePendingChangesCount()
      self.trackChange(id: id, recordType: recordType, changeType: .deleted)
    }
  }

  private func saveChangeTracking() {
    let encoder = JSONEncoder()

    if let pendingData = try? encoder.encode(pendingChanges) {
      UserDefaults.standard.set(pendingData, forKey: "pendingChanges")
    }

    if let deletionData = try? encoder.encode(deletionRecords) {
      UserDefaults.standard.set(deletionData, forKey: "deletionRecords")
    }
  }

  private func loadChangeTracking() {
    let decoder = JSONDecoder()

    if let pendingData = UserDefaults.standard.data(forKey: "pendingChanges"),
      let changes = try? decoder.decode([LocalChange].self, from: pendingData)
    {
      pendingChanges = changes
    }

    if let deletionData = UserDefaults.standard.data(forKey: "deletionRecords"),
      let deletions = try? decoder.decode(
        [DeletionRecord].self,
        from: deletionData
      )
    {
      deletionRecords = deletions
    }
  }

  private func clearProcessedChanges(_ processedChanges: [LocalChange]) {
    Task { [weak self] in
      guard let self = self else { return }

      await MainActor.run {
        let processedIds = Set(
          processedChanges.map { "\($0.id)_\($0.recordType)_\($0.changeType)" }
        )
        self.pendingChanges.removeAll { change in
          processedIds.contains(
            "\(change.id)_\(change.recordType)_\(change.changeType)"
          )
        }

        // Also clean up old deletion records (older than 30 days)
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        self.deletionRecords.removeAll { $0.deletedAt < thirtyDaysAgo }

        self.saveChangeTracking()
      }
    }
  }

  @MainActor
  private func scheduleDebouncedSync() {
    // Cancel existing timer
    debounceTimer?.invalidate()

    // Schedule new sync after debounce delay
    debounceTimer = Timer.scheduledTimer(
      withTimeInterval: configuration.debounceDelay,
      repeats: false
    ) {
      [weak self] _ in
      Task { [weak self] in
        await self?.syncPendingChangesIfNeeded()
      }
    }
  }

  private func syncPendingChangesIfNeeded() async {
    guard
      SettingsStore.shared.syncWithiCloud && isNetworkAvailable
        && hasPendingChanges
    else { return }

    // Check if enough time has passed since last sync
    if let lastSync = lastSyncAttempt,
      Date().timeIntervalSince(lastSync) < configuration.maxSyncFrequency
    {
      return
    }

    do {
      try await performIncrementalSync()
      hasPendingChanges = false
      lastSyncAttempt = Date()
    } catch {
      // Keep pending changes flag if sync failed
      print("Sync failed, will retry later: \(error)")
    }
  }

  func disableSync() {
    SettingsStore.shared.syncWithiCloud = false
    syncStatus = .idle
    hasPendingChanges = false
    // Clear change tokens
    predictionChangeToken = nil

    // Stop all sync timers
    Task { @MainActor in
      stopDebouncedSync()
      cancelBackgroundSync()
    }
  }

  @MainActor
  private func stopDebouncedSync() {
    debounceTimer?.invalidate()
    debounceTimer = nil
  }

  func performFullSync() async throws {
    guard
      !ProcessInfo.processInfo.environment.keys.contains(
        "XCODE_RUNNING_FOR_PREVIEWS"
      )
    else { return }

    #if targetEnvironment(simulator)
      return
    #else
      guard SettingsStore.shared.syncWithiCloud else { return }

      syncStatus = .syncing
      syncProgress = 0.0

      do {
        try await checkAccountStatus()

        // Reset change tokens for full sync
        predictionChangeToken = nil

        // Sync in order: Settings -> Analytics -> Predictions
        syncProgress = min(max(0.1, 0.0), 1.0)
        try await syncSettings()

        syncProgress = min(max(0.3, 0.0), 1.0)
        try await syncAnalyticsMetrics()

        syncProgress = min(max(0.5, 0.0), 1.0)
        let _ = try await syncPredictionsIncremental()

        syncProgress = 1.0
        lastSyncDate = Date()
        saveLastSyncDate()
        syncStatus = .success

      } catch let error as CloudKitSyncError {
        syncProgress = 0.0
        syncStatus = .error(error)
        throw error
      } catch {
        syncProgress = 0.0
        let cloudKitError = mapCKErrorToSyncError(error)
        syncStatus = .error(cloudKitError)
        throw cloudKitError
      }
    #endif
  }

  func performIncrementalSync() async throws {
    guard
      !ProcessInfo.processInfo.environment.keys.contains(
        "XCODE_RUNNING_FOR_PREVIEWS"
      )
    else { return }

    #if targetEnvironment(simulator)
      return
    #else
      guard SettingsStore.shared.syncWithiCloud && isNetworkAvailable else {
        if !isNetworkAvailable {
          throw CloudKitSyncError.networkUnavailable
        }
        return
      }

      syncStatus = .syncing
      var processedChanges: [LocalChange] = []

      do {
        try await checkAccountStatus()

        // Smart sync: check if we should do incremental or full sync
        let pendingChangesCount = await countPendingChanges()
        if pendingChangesCount > configuration.incrementalSyncThreshold,
          let lastSync = lastSyncDate,
          Date().timeIntervalSince(lastSync) > 300  // 5 minutes
        {
          print(
            "Large number of changes (\(pendingChangesCount)), performing full sync"
          )
          try await performFullSync()
          return
        }

        // Process deletions first (tombstone records)
        let deletionChanges = try await processPendingDeletions()
        processedChanges.append(contentsOf: deletionChanges)

        // Then sync regular changes
        let syncChanges = try await syncPredictionsIncremental()
        processedChanges.append(contentsOf: syncChanges)

        let settingsChanges = try await syncSettingsIncremental()
        processedChanges.append(contentsOf: settingsChanges)

        let analyticsChanges = try await syncAnalyticsIncremental()
        processedChanges.append(contentsOf: analyticsChanges)

        // Clear processed changes
        clearProcessedChanges(processedChanges)

        lastSyncDate = Date()
        saveLastSyncDate()
        syncStatus = .success

      } catch let error as CloudKitSyncError {
        syncStatus = .error(error)
        throw error
      } catch {
        let cloudKitError = mapCKErrorToSyncError(error)
        syncStatus = .error(cloudKitError)
        throw cloudKitError
      }
    #endif
  }

  func countPendingChanges() async -> Int {
    let predictionStore = PredictionStore.shared
    let pendingPredictions = predictionStore.predictions
    let pendingSettings = SettingsStore.shared.needsCloudKitSync ? 1 : 0
    let pendingAnalytics = AnalyticsStore.shared.getMetricsNeedingSync().count
    let pendingLocalChanges = pendingChanges.count

    return pendingPredictions.count + pendingSettings + pendingAnalytics
      + pendingLocalChanges
  }

  @MainActor
  func updatePendingChangesCount() async {
    pendingChangesCount = await countPendingChanges()
  }

  private func processPendingDeletions() async throws -> [LocalChange] {
    try initializeCloudKitIfNeeded()
    guard let privateDatabase = privateDatabase else {
      throw CloudKitSyncError.iCloudAccountNotAvailable
    }

    var processedChanges: [LocalChange] = []

    // Get deletion changes from pending changes
    let deletionChanges = pendingChanges.filter { $0.changeType == .deleted }

    for change in deletionChanges {
      do {
        // Create tombstone record for the deletion
        let tombstoneRecord = CKRecord(
          recordType: RecordType.tombstone,
          recordID: CKRecord.ID(
            recordName: "tombstone_\(change.id)_\(change.recordType)",
            zoneID: customZoneID
          )
        )

        tombstoneRecord["originalRecordId"] = change.id
        tombstoneRecord["originalRecordType"] = change.recordType
        tombstoneRecord["deletedAt"] = change.timestamp
        tombstoneRecord["createdAt"] = Date()

        // Save tombstone record
        let _ = try await privateDatabase.save(tombstoneRecord)

        // Try to delete the original record if it exists
        let originalRecordID = CKRecord.ID(
          recordName: getRecordName(
            for: change.id,
            recordType: change.recordType
          ),
          zoneID: customZoneID
        )

        do {
          try await privateDatabase.deleteRecord(withID: originalRecordID)
        } catch let error as CKError where error.code == .unknownItem {
          // Record already deleted or never existed, continue
        }

        processedChanges.append(change)
        print("✅ Processed deletion for \(change.recordType): \(change.id)")

      } catch {
        print(
          "❌ Failed to process deletion for \(change.recordType): \(change.id) - \(error)"
        )
        // Continue with other deletions even if one fails
      }
    }

    return processedChanges
  }

  private func getRecordName(for id: String, recordType: String) -> String {
    switch recordType {
    case RecordType.prediction:
      return "prediction_\(id)"
    case RecordType.analyticsMetrics:
      return "AnalyticsMetric_\(id)"
    case RecordType.appSettings:
      return "AppSettings"
    default:
      return id
    }
  }

  private func processTombstoneRecords() async throws {
    try initializeCloudKitIfNeeded()
    guard let privateDatabase = privateDatabase else {
      throw CloudKitSyncError.iCloudAccountNotAvailable
    }

    // Use zone-based fetching instead of queries to avoid queryable field requirements
    do {
      let zoneConfiguration =
        CKFetchRecordZoneChangesOperation.ZoneConfiguration()
      zoneConfiguration.previousServerChangeToken = nil  // Fetch all changes for tombstones

      let (modificationResults, _, _, _) =
        try await privateDatabase.recordZoneChanges(
          inZoneWith: customZoneID,
          since: nil
        )

      // Process only tombstone records from the modifications
      for (_, result) in modificationResults {
        switch result {
        case .success(let modification):
          let record = modification.record
          if record.recordType == RecordType.tombstone {
            await processTombstoneRecord(record)
          }
        case .failure(let error):
          print("Failed to fetch record: \(error)")
        }
      }

      print("✅ Processed tombstone records from zone changes")

    } catch let error as CKError where error.code == .zoneNotFound {
      // Zone doesn't exist yet, which is fine for first sync
      print(
        "Zone not found for tombstone processing - this is expected for first sync"
      )
    } catch {
      print("Failed to fetch zone changes for tombstones: \(error)")
      // Don't throw here - continue with regular sync even if tombstone processing fails
    }
  }

  @MainActor
  private func processTombstoneRecord(_ record: CKRecord) async {
    guard let originalRecordId = record["originalRecordId"] as? String,
      let originalRecordType = record["originalRecordType"] as? String,
      let deletedAt = record["deletedAt"] as? Date
    else {
      print("Invalid tombstone record: \(record.recordID)")
      return
    }

    // Check if this deletion is newer than our last sync
    if let lastSync = lastSyncDate, deletedAt <= lastSync {
      return  // Already processed this deletion
    }

    // Process the deletion based on record type
    switch originalRecordType {
    case RecordType.prediction:
      await deleteLocalPrediction(withId: originalRecordId)
    case RecordType.analyticsMetrics:
      await deleteLocalAnalyticsMetric(withId: originalRecordId)
    case RecordType.appSettings:
      // Settings can't really be "deleted", just reset
      print("Received deletion for settings - ignoring")
    default:
      print("Unknown record type in tombstone: \(originalRecordType)")
    }
  }

  @MainActor
  private func deleteLocalPrediction(withId id: String) async {
    guard let predictionId = UUID(uuidString: id) else {
      return
    }

    let predictionStore = PredictionStore.shared

    if let prediction = await predictionStore.findPrediction(by: predictionId) {
      // Delete without tracking (since this is coming from server)
      await predictionStore.deletePrediction(prediction)
      print("Deleted local prediction due to server tombstone: \(id)")
    }
  }

  @MainActor
  private func deleteLocalAnalyticsMetric(withId id: String) async {
    await MainActor.run {
      let analyticsStore = AnalyticsStore.shared
      analyticsStore.deleteMetric(withId: id)
      print("Deleted local analytics metric due to server tombstone: \(id)")
    }
  }

  func forceSyncData() async throws {
    try await performFullSync()
  }

  func downloadFromCloud() async throws {
    #if targetEnvironment(simulator)
      return
    #else
      guard SettingsStore.shared.syncWithiCloud else { return }

      syncStatus = .syncing

      do {
        try await checkAccountStatus()

        try await downloadSettingsFromCloud()
        try await downloadAnalyticsFromCloud()
        try await downloadPredictionsFromCloud()

        lastSyncDate = Date()
        saveLastSyncDate()
        syncStatus = .success

      } catch let error as CloudKitSyncError {
        syncStatus = .error(error)
        throw error
      } catch {
        let cloudKitError = mapCKErrorToSyncError(error)
        syncStatus = .error(cloudKitError)
        throw cloudKitError
      }
    #endif
  }

  func setModelContext(_ context: ModelContext) {
    self.modelContext = context
  }

  // MARK: - Sync Timing Management
  // Removed aggressive periodic syncing - now using change-based syncing only

  @MainActor
  private func scheduleBackgroundSync() {
    guard SettingsStore.shared.syncWithiCloud else { return }

    cancelBackgroundSync()  // Cancel any existing timer

    // Use background app refresh for better battery efficiency
    scheduleBackgroundAppRefresh()

    // Fallback timer for foreground operation (only sync if there are pending changes)
    backgroundSyncTimer = Timer.scheduledTimer(
      withTimeInterval: configuration.backgroundSyncInterval,
      repeats: true
    ) {
      [weak self] _ in
      Task { [weak self] in
        guard let self = self else { return }
        await self.syncPendingChangesIfNeeded()
      }
    }
  }

  @MainActor
  private func cancelBackgroundSync() {
    backgroundSyncTimer?.invalidate()
    backgroundSyncTimer = nil
  }

  // MARK: - Background Task Management
  private func registerBackgroundTasks() {
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: Self.backgroundSyncTaskIdentifier,
      using: nil
    ) { task in
      Task {
        await self.handleBackgroundSync(task: task as! BGAppRefreshTask)
      }
    }
  }

  @MainActor
  private func scheduleBackgroundAppRefresh() {
    let request = BGAppRefreshTaskRequest(
      identifier: Self.backgroundSyncTaskIdentifier
    )
    request.earliestBeginDate = Date(
      timeIntervalSinceNow: configuration.backgroundSyncInterval
    )

    do {
      try BGTaskScheduler.shared.submit(request)
      print("Background sync task scheduled")
    } catch {
      print("Failed to schedule background sync: \(error)")
    }
  }

  private func handleBackgroundSync(task: BGAppRefreshTask) async {
    // Schedule the next background refresh
    await MainActor.run {
      scheduleBackgroundAppRefresh()
    }

    // Set expiration handler
    task.expirationHandler = {
      task.setTaskCompleted(success: false)
    }

    // Perform background sync only if network is available and there are pending changes
    do {
      if SettingsStore.shared.syncWithiCloud && isNetworkAvailable
        && hasPendingChanges
      {
        try await performIncrementalSync()
        hasPendingChanges = false
        lastSyncAttempt = Date()
        task.setTaskCompleted(success: true)
      } else {
        task.setTaskCompleted(success: true)
      }
    } catch {
      print("Background sync failed: \(error)")
      task.setTaskCompleted(success: false)
    }
  }

  // MARK: - Network Monitoring
  private func startNetworkMonitoring() {
    networkMonitor.pathUpdateHandler = { [weak self] path in
      DispatchQueue.main.async {
        self?.isNetworkAvailable = path.status == .satisfied

        // Trigger sync when network becomes available and there are pending changes
        if path.status == .satisfied && SettingsStore.shared.syncWithiCloud {
          Task { [weak self] in
            guard let self = self else { return }
            await self.syncPendingChangesIfNeeded()
          }
        }
      }
    }

    networkMonitor.start(queue: networkQueue)
  }

  // MARK: - Error Mapping
  private func mapCKErrorToSyncError(_ error: Error) -> CloudKitSyncError {
    guard let ckError = error as? CKError else {
      return .syncFailed(error.localizedDescription)
    }

    switch ckError.code {
    case .notAuthenticated:
      return .iCloudAccountNotAvailable
    case .permissionFailure:
      return .permissionDenied
    case .networkUnavailable, .networkFailure:
      return .networkUnavailable
    case .quotaExceeded:
      return .quotaExceeded
    case .unknownItem:
      return .recordNotFound
    case .changeTokenExpired:
      return .changeTokenInvalid
    case .batchRequestFailed:
      return .batchOperationFailed
    case .serverRecordChanged:
      return .conflictResolutionFailed
    default:
      return .syncFailed(ckError.localizedDescription)
    }
  }

  // MARK: - Lazy CloudKit Initialization
  private func initializeCloudKitIfNeeded() throws {
    guard
      !ProcessInfo.processInfo.environment.keys.contains(
        "XCODE_RUNNING_FOR_PREVIEWS"
      )
    else {
      throw CloudKitSyncError.iCloudAccountNotAvailable
    }

    if container == nil {
      container = CKContainer.default()
    }
  }

  // MARK: - Private Methods
  private func checkAccountStatus() async throws {
    try initializeCloudKitIfNeeded()
    guard let container = container else {
      throw CloudKitSyncError.iCloudAccountNotAvailable
    }

    let status = try await container.accountStatus()

    switch status {
    case .available:
      break
    case .noAccount:
      throw CloudKitSyncError.iCloudAccountNotAvailable
    case .restricted, .couldNotDetermine:
      throw CloudKitSyncError.permissionDenied
    case .temporarilyUnavailable:
      throw CloudKitSyncError.networkUnavailable
    @unknown default:
      throw CloudKitSyncError.unknownError
    }
  }

  private func performInitialSetup() async throws {
    guard !isInitialSetupComplete else { return }

    try await createCustomZoneIfNeeded()
    try await setupSubscriptions()

    isInitialSetupComplete = true
  }

  private func createCustomZoneIfNeeded() async throws {
    try initializeCloudKitIfNeeded()
    guard let privateDatabase = privateDatabase else {
      throw CloudKitSyncError.iCloudAccountNotAvailable
    }

    let zone = CKRecordZone(zoneID: customZoneID)

    do {
      let _ = try await privateDatabase.save(zone)
    } catch let error as CKError where error.code == .serverRecordChanged {
      // Zone already exists, continue silently
    } catch let error as CKError where error.code == .limitExceeded {
      // Too many zones, but continue (zone might still exist)
      print("⚠️ CloudKit zone limit exceeded, but continuing")
    } catch {
      print("❌ Failed to create CloudKit zone: \(error)")
      throw mapCKErrorToSyncError(error)
    }
  }

  private func setupSubscriptions() async throws {
    try initializeCloudKitIfNeeded()
    guard let privateDatabase = privateDatabase else {
      throw CloudKitSyncError.iCloudAccountNotAvailable
    }

    // Create subscription for predictions
    let predicate = NSPredicate(value: true)
    let subscription = CKQuerySubscription(
      recordType: RecordType.prediction,
      predicate: predicate,
      subscriptionID: "prediction-changes",
      options: [
        .firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion,
      ]
    )

    let notificationInfo = CKSubscription.NotificationInfo()
    notificationInfo.shouldSendContentAvailable = true
    subscription.notificationInfo = notificationInfo

    do {
      let _ = try await privateDatabase.save(subscription)
    } catch let error as CKError where error.code == .serverRejectedRequest {
      // Subscription might already exist or be rejected for other reasons
      print("Subscription creation rejected (might already exist): \(error)")
    } catch {
      // Don't fail setup if subscription creation fails
      print("Failed to create subscription: \(error)")
    }
  }

  // MARK: - Settings Sync
  private func syncSettings() async throws {
    let _ = try await syncSettingsIncremental()
  }

  func syncSettingsIncremental() async throws -> [LocalChange] {
    try initializeCloudKitIfNeeded()
    guard let privateDatabase = privateDatabase else {
      throw CloudKitSyncError.iCloudAccountNotAvailable
    }

    // Ensure zone exists before syncing
    try await createCustomZoneIfNeeded()

    let settings = SettingsStore.shared

    // Only sync if settings have changed
    guard settings.needsCloudKitSync else { return [] }

    let settingsData = settings.exportSettings()
    let recordID = CKRecord.ID(recordName: "AppSettings", zoneID: customZoneID)

    do {
      let existingRecord = try await privateDatabase.record(for: recordID)

      // Check if we need to resolve conflicts
      if let serverLastModified = existingRecord["lastModified"] as? Date,
        serverLastModified > settings.lastModified
      {

        // Server version is newer, apply conflict resolution
        var serverSettings: [String: Any] = [:]
        for (key, _) in settingsData {
          if let value = existingRecord[key] {
            serverSettings[key] = value
          }
        }

        settings.applyServerSettings(
          serverSettings,
          conflictResolution: configuration.conflictResolutionStrategy
        )
        return []
      }

      // Update existing record with local changes
      for (key, value) in settingsData {
        if let recordValue = convertToCKRecordValue(value) {
          existingRecord[key] = recordValue
        }
      }
      existingRecord["lastModified"] = settings.lastModified

      let _ = try await privateDatabase.save(existingRecord)
      settings.markAsSynced()

      return [
        LocalChange(
          id: "AppSettings",
          recordType: RecordType.appSettings,
          changeType: .updated
        )
      ]

    } catch let error as CKError where error.code == .unknownItem {
      // Record doesn't exist, create new one
      let newRecord = CKRecord(
        recordType: RecordType.appSettings,
        recordID: recordID
      )

      for (key, value) in settingsData {
        if let recordValue = convertToCKRecordValue(value) {
          newRecord[key] = recordValue
        }
      }
      newRecord["lastModified"] = settings.lastModified

      let _ = try await privateDatabase.save(newRecord)
      settings.markAsSynced()

      return [
        LocalChange(
          id: "AppSettings",
          recordType: RecordType.appSettings,
          changeType: .created
        )
      ]

    } catch {
      throw mapCKErrorToSyncError(error)
    }
  }

  // MARK: - Analytics Sync
  private func syncAnalyticsMetrics() async throws {
    let _ = try await syncAnalyticsIncremental()
  }

  func syncAnalyticsIncremental() async throws -> [LocalChange] {
    try initializeCloudKitIfNeeded()
    guard let privateDatabase = privateDatabase else {
      throw CloudKitSyncError.iCloudAccountNotAvailable
    }

    // Ensure zone exists before syncing
    try await createCustomZoneIfNeeded()

    let analyticsStore = AnalyticsStore.shared
    let metricsNeedingSync = analyticsStore.getMetricsNeedingSync()

    print("🔄 Starting analytics sync for \(metricsNeedingSync.count) metrics")

    // Only sync if there are changes
    guard !metricsNeedingSync.isEmpty else {
      print("✅ No analytics metrics need syncing")
      return []
    }

    do {
      // Sync individual metric records for better granularity
      var syncedMetricIds: [String] = []

      for metric in metricsNeedingSync {
        let recordID = CKRecord.ID(
          recordName: "AnalyticsMetric_\(metric.id)",
          zoneID: customZoneID
        )

        do {
          let existingRecord = try await privateDatabase.record(for: recordID)

          // Check for conflicts
          if let serverLastModified = existingRecord["lastModified"] as? Date,
            serverLastModified > metric.lastModified
          {

            print(
              "🔄 Resolving conflict for metric \(metric.id): server version is newer"
            )
            // Server version is newer, create server metric and apply conflict resolution
            let serverMetric = createMetricFromRecord(existingRecord)
            analyticsStore.applyServerChanges(
              [serverMetric],
              conflictResolution: configuration.conflictResolutionStrategy
            )
            syncedMetricIds.append(metric.id)
            continue
          }

          // Update existing record
          updateRecordFromMetric(existingRecord, with: metric)
          let _ = try await privateDatabase.save(existingRecord)
          syncedMetricIds.append(metric.id)
          print("✅ Updated metric \(metric.id)")

        } catch let error as CKError where error.code == .unknownItem {
          // Record doesn't exist, create new one
          let newRecord = CKRecord(
            recordType: RecordType.analyticsMetrics,
            recordID: recordID
          )
          updateRecordFromMetric(newRecord, with: metric)
          let _ = try await privateDatabase.save(newRecord)
          syncedMetricIds.append(metric.id)
          print("✅ Created metric \(metric.id)")
        } catch let error as CKError where error.code == .zoneNotFound {
          print(
            "❌ Zone not found for metric \(metric.id) - this should not happen after zone creation"
          )
          throw error
        } catch {
          // Handle other errors, but continue with the next metric
          print("❌ Failed to sync metric \(metric.id): \(error)")
          continue
        }
      }

      // Mark synced metrics as no longer needing sync
      analyticsStore.markMetricsAsSynced(syncedMetricIds)

      // Return processed changes
      return syncedMetricIds.map { id in
        LocalChange(
          id: id,
          recordType: RecordType.analyticsMetrics,
          changeType: .updated
        )
      }

    } catch {
      throw mapCKErrorToSyncError(error)
    }
  }

  // MARK: - Analytics Helper Methods
  private func updateRecordFromMetric(
    _ record: CKRecord,
    with metric: AnalyticsMetric
  ) {
    record["id"] = metric.id
    record["icon"] = metric.icon
    record["title"] = metric.title
    record["value"] = metric.value
    record["unit"] = metric.unit
    record["percentage"] = Swift.max(
      0.0,
      Swift.min(1.0, metric.percentage.isFinite ? metric.percentage : 0.0)
    )
    record["description"] = metric.description
    record["isLocked"] = metric.isLocked ? 1 : 0
    record["lastModified"] = metric.lastModified
  }

  private func createMetricFromRecord(_ record: CKRecord) -> AnalyticsMetric {
    // Validate percentage from CloudKit to prevent Metal rendering issues
    let rawPercentage = record["percentage"] as? Double ?? 0.0
    let validPercentage = Swift.max(
      0.0,
      Swift.min(1.0, rawPercentage.isFinite ? rawPercentage : 0.0)
    )

    return AnalyticsMetric(
      id: record["id"] as? String ?? "",
      icon: record["icon"] as? String ?? "",
      title: record["title"] as? String ?? "",
      value: record["value"] as? String ?? "",
      unit: record["unit"] as? String ?? "",
      percentage: validPercentage,
      description: record["description"] as? String ?? "",
      isLocked: (record["isLocked"] as? Int ?? 0) == 1,
      lastModified: record["lastModified"] as? Date ?? Date(),
      needsCloudKitSync: false
    )
  }

  // MARK: - Predictions Sync with Incremental Support
  private func syncPredictionsIncremental() async throws -> [LocalChange] {
    try initializeCloudKitIfNeeded()
    guard privateDatabase != nil else {
      throw CloudKitSyncError.iCloudAccountNotAvailable
    }

    // Ensure zone exists before syncing
    try await createCustomZoneIfNeeded()

    let predictionStore = PredictionStore.shared

    do {
      // First, fetch changes from server (including tombstones)
      try await fetchServerChanges()

      // Process any tombstone records we received
      try await processTombstoneRecords()

      // Then upload local changes
      let localPredictions = await predictionStore.fetchModifiedSince(
        lastSyncDate
      )
      let uploadedChanges = try await uploadPredictions(localPredictions)

      return uploadedChanges

    } catch {
      throw mapCKErrorToSyncError(error)
    }
  }

  private func fetchServerChanges() async throws {
    try initializeCloudKitIfNeeded()
    guard let privateDatabase = privateDatabase else {
      throw CloudKitSyncError.iCloudAccountNotAvailable
    }

    // Use modern async/await CloudKit API
    do {
      let zoneConfiguration =
        CKFetchRecordZoneChangesOperation.ZoneConfiguration()
      zoneConfiguration.previousServerChangeToken = predictionChangeToken

      let (modificationResults, deletions, newChangeToken, _) =
        try await privateDatabase.recordZoneChanges(
          inZoneWith: customZoneID,
          since: predictionChangeToken
        )

      // Process changed records
      var changedRecords: [CKRecord] = []
      for (_, result) in modificationResults {
        switch result {
        case .success(let modification):
          changedRecords.append(modification.record)
        case .failure(let error):
          print("Failed to fetch record: \(error)")
        }
      }

      // Process deleted records
      let deletedRecordIDs = deletions.map { $0.recordID }

      // Apply changes
      await processServerChanges(
        changed: changedRecords,
        deleted: deletedRecordIDs
      )

      // Update change token
      predictionChangeToken = newChangeToken

    } catch {
      throw mapCKErrorToSyncError(error)
    }
  }

  @MainActor
  private func processServerChanges(changed: [CKRecord], deleted: [CKRecord.ID])
    async
  {
    let predictionStore = PredictionStore.shared

    // Process changed records
    for record in changed {
      await processChangedRecord(record, using: predictionStore)
    }

    // Process deleted records
    for recordID in deleted {
      await processDeletedRecord(recordID, using: predictionStore)
    }
  }

  @MainActor
  private func processChangedRecord(
    _ record: CKRecord,
    using store: PredictionStore
  ) async {
    guard record.recordType == RecordType.prediction else {
      // This is expected if other record types (e.g., AppSettings) are modified
      // in the same zone. The sync methods for those types handle their own server changes.
      return
    }

    guard let idString = record["id"] as? String,
      let predictionId = UUID(uuidString: idString)
    else {
      print("Warning: Invalid prediction record or UUID: \(record.recordID)")
      return
    }

    let existingPrediction = await store.findPrediction(by: predictionId)

    if let existing = existingPrediction {
      // Apply conflict resolution
      let serverModified = record["lastModified"] as? Date ?? Date.distantPast
      let localModified = existing.lastModified

      switch configuration.conflictResolutionStrategy {
      case .newerWins:
        if serverModified > localModified {
          updatePredictionFromRecord(existing, with: record)
        }
      case .serverWins:
        updatePredictionFromRecord(existing, with: record)
      case .clientWins:
        // Keep local version, don't update
        break
      }
      // Save changes if any were made
      await store.updatePrediction(existing)

    } else {
      // Create new prediction from server record
      await createPredictionFromRecord(record, using: store)
    }
  }

  @MainActor
  private func processDeletedRecord(
    _ recordID: CKRecord.ID,
    using store: PredictionStore
  ) async {
    let predictionIdString = recordID.recordName.replacingOccurrences(
      of: "prediction_",
      with: ""
    )
    guard !predictionIdString.isEmpty,
      let predictionId = UUID(uuidString: predictionIdString)
    else {
      print("Warning: Invalid UUID in deleted record: \(recordID.recordName)")
      return
    }

    if let prediction = await store.findPrediction(by: predictionId) {
      await store.deletePrediction(prediction)
    }
  }

  private func updatePredictionFromRecord(
    _ prediction: Prediction,
    with record: CKRecord
  ) {
    if let eventName = record["eventName"] as? String {
      prediction.eventName = eventName
    }
    if let eventDescription = record["eventDescription"] as? String {
      prediction.eventDescription = eventDescription
    }
    if let confidenceLevel = record["confidenceLevel"] as? Double,
      confidenceLevel >= 0 && confidenceLevel <= 100
    {
      prediction.confidenceLevel = confidenceLevel
    }
    if let estimatedValue = record["estimatedValue"] as? String {
      prediction.estimatedValue = estimatedValue
    }
    if let booleanValue = record["booleanValue"] as? String {
      prediction.booleanValue = booleanValue
    }
    if let pressureLevel = record["pressureLevel"] as? String {
      prediction.pressureLevel = pressureLevel
    }
    if let currentMood = record["currentMood"] as? String {
      prediction.currentMood = currentMood
    }
    if let takesMedicine = record["takesMedicine"] as? String {
      prediction.takesMedicine = takesMedicine
    }
    if let evidenceList = record["evidenceList"] as? [String] {
      prediction.evidenceList = evidenceList
    }
    if let selectedTypeString = record["selectedType"] as? String,
      let selectedType = EventType(rawValue: selectedTypeString)
    {
      prediction.selectedType = selectedType
    }
    if let dueDate = record["dueDate"] as? Date {
      prediction.dueDate = dueDate
    }
    if let resolutionDate = record["resolutionDate"] as? Date {
      prediction.resolutionDate = resolutionDate
    }
    if let isPendingInt = record["isPending"] as? Int {
      prediction.isPending = isPendingInt != 0
    }
    if let isResolvedInt = record["isResolved"] as? Int {
      prediction.isResolved = isResolvedInt != 0
    }
    if let actualOutcome = record["actualOutcome"] as? String {
      prediction.actualOutcome = actualOutcome
    }
    if let lastModified = record["lastModified"] as? Date {
      prediction.lastModified = lastModified
    }
  }

  private func createPredictionFromRecord(
    _ record: CKRecord,
    using store: PredictionStore
  ) async {
    guard let idString = record["id"] as? String,
      let predictionId = UUID(uuidString: idString),
      let eventName = record["eventName"] as? String,
      !eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let eventDescription = record["eventDescription"] as? String,
      !eventDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let confidenceLevel = record["confidenceLevel"] as? Double,
      confidenceLevel >= 0 && confidenceLevel <= 100,
      let estimatedValue = record["estimatedValue"] as? String,
      let booleanValue = record["booleanValue"] as? String,
      let pressureLevel = record["pressureLevel"] as? String,
      let currentMood = record["currentMood"] as? String,
      let takesMedicine = record["takesMedicine"] as? String,
      let evidenceList = record["evidenceList"] as? [String],
      let selectedTypeString = record["selectedType"] as? String,
      let selectedType = EventType(rawValue: selectedTypeString),
      let dueDate = record["dueDate"] as? Date,
      let lastModified = record["lastModified"] as? Date
    else {
      print(
        "Warning: Invalid data in CloudKit record, skipping: \(record.recordID)"
      )
      return
    }

    // Since we need to create a prediction with a specific ID from the server,
    // we'll need to use the underlying service directly for this special case
    guard let modelContext = store.modelContext else {
      print(
        "Warning: Model context not available for creating prediction from record"
      )
      return
    }

    let newPrediction = Prediction(
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
    newPrediction.id = predictionId  // Manually set the ID from the record
    newPrediction.lastModified = lastModified

    // Manually insert and save since the store's create method creates a new UUID
    do {
      modelContext.insert(newPrediction)
      try modelContext.save()

      // Refresh the store's predictions list
      await store.refreshPredictions()
    } catch {
      print("Failed to create prediction from record: \(error)")
    }
  }

  private func uploadPredictions(_ predictions: [Prediction]) async throws
    -> [LocalChange]
  {
    try initializeCloudKitIfNeeded()
    guard let privateDatabase = privateDatabase else {
      throw CloudKitSyncError.iCloudAccountNotAvailable
    }

    // Process in batches for better performance
    let batches = predictions.chunked(into: configuration.batchSize)
    var allChanges: [LocalChange] = []

    for (index, batch) in batches.enumerated() {
      let batchChanges = try await uploadPredictionBatch(
        batch,
        to: privateDatabase
      )
      allChanges.append(contentsOf: batchChanges)

      // Update progress
      let progress = Double(index + 1) / Double(batches.count) * 0.8 + 0.1
      await MainActor.run {
        syncProgress = min(max(progress, 0.0), 1.0)
      }
    }

    return allChanges
  }

  // MARK: - Download from CloudKit
  func downloadSettingsFromCloud() async throws {
    try initializeCloudKitIfNeeded()
    guard let privateDatabase = privateDatabase else {
      throw CloudKitSyncError.iCloudAccountNotAvailable
    }

    let recordID = CKRecord.ID(recordName: "AppSettings", zoneID: customZoneID)

    do {
      let record = try await privateDatabase.record(for: recordID)

      // Convert CloudKit record to settings dictionary
      var serverSettings: [String: Any] = [:]

      if let significanceLevel = record["significanceLevel"] as? Double {
        serverSettings["significanceLevel"] = significanceLevel
      }
      if let acceptanceAreaDisplay = record["acceptanceAreaDisplay"] as? String
      {
        serverSettings["acceptanceAreaDisplay"] = acceptanceAreaDisplay
      }
      if let connectToHealth = record["connectToHealth"] as? Bool {
        serverSettings["connectToHealth"] = connectToHealth
      }
      if let remindersEnabled = record["remindersEnabled"] as? Bool {
        serverSettings["remindersEnabled"] = remindersEnabled
      }
      if let lastModified = record["lastModified"] as? Date {
        serverSettings["settingsLastModified"] =
          lastModified.timeIntervalSince1970
      }

      // Apply server settings with conflict resolution
      SettingsStore.shared.applyServerSettings(serverSettings)

    } catch let error as CKError where error.code == .unknownItem {
      // No settings in cloud yet, continue with local settings
      return
    } catch {
      throw mapCKErrorToSyncError(error)
    }
  }

  func downloadAnalyticsFromCloud() async throws {
    try initializeCloudKitIfNeeded()
    guard let privateDatabase = privateDatabase else {
      throw CloudKitSyncError.iCloudAccountNotAvailable
    }

    do {
      // Query for all analytics metric records
      let query = CKQuery(
        recordType: RecordType.analyticsMetrics,
        predicate: NSPredicate(value: true)
      )

      let (results, _) = try await privateDatabase.records(
        matching: query,
        inZoneWith: customZoneID
      )

      var serverMetrics: [AnalyticsMetric] = []

      for (_, result) in results {
        switch result {
        case .success(let record):
          let metric = createMetricFromRecord(record)
          serverMetrics.append(metric)
        case .failure(let error):
          print("Failed to fetch analytics record: \(error)")
        }
      }

      // Apply server metrics with conflict resolution
      if !serverMetrics.isEmpty {
        AnalyticsStore.shared.applyServerChanges(serverMetrics)
      }

    } catch let error as CKError where error.code == .unknownItem {
      return
    } catch {
      throw mapCKErrorToSyncError(error)
    }
  }

  func downloadPredictionsFromCloud() async throws {
    try initializeCloudKitIfNeeded()
    guard let privateDatabase = privateDatabase else {
      throw CloudKitSyncError.iCloudAccountNotAvailable
    }

    let predictionStore = PredictionStore.shared

    do {
      let query = CKQuery(
        recordType: RecordType.prediction,
        predicate: NSPredicate(value: true)
      )

      let (results, _) = try await privateDatabase.records(
        matching: query,
        inZoneWith: customZoneID
      )

      for (_, result) in results {
        switch result {
        case .success(let record):
          await createPredictionFromRecord(record, using: predictionStore)
        case .failure(let error):
          print("Failed to fetch record: \(error)")
        }
      }

    } catch {
      throw mapCKErrorToSyncError(error)
    }
  }

  // MARK: - Helper Methods
  private func getModelContext() -> ModelContext? {
    return modelContext
  }

  private func convertToCKRecordValue(_ value: Any) -> CKRecordValue? {
    switch value {
    case let stringValue as String:
      return stringValue.isEmpty ? nil : stringValue as CKRecordValue
    case let doubleValue as Double:
      return doubleValue.isFinite ? doubleValue as CKRecordValue : nil
    case let intValue as Int:
      return intValue as CKRecordValue
    case let boolValue as Bool:
      return (boolValue ? 1 : 0) as CKRecordValue
    case let dateValue as Date:
      return dateValue as CKRecordValue
    case let dataValue as Data:
      return dataValue.isEmpty ? nil : dataValue as CKRecordValue
    case let arrayValue as [String]:
      return arrayValue.isEmpty ? nil : arrayValue as CKRecordValue
    default:
      print("Warning: Cannot convert value to CKRecordValue: \(value)")
      return nil
    }
  }

  private func loadLastSyncDate() {
    if let date = UserDefaults.standard.object(forKey: "lastCloudKitSyncDate")
      as? Date
    {
      lastSyncDate = date
    }
  }

  private func saveLastSyncDate() {
    if let date = lastSyncDate {
      UserDefaults.standard.set(date, forKey: "lastCloudKitSyncDate")
    }
  }
}

// MARK: - Array Extension for Chunking
extension Array {
  func chunked(into size: Int) -> [[Element]] {
    return stride(from: 0, to: count, by: size).map {
      Array(self[$0..<Swift.min($0 + size, count)])
    }
  }
}

// MARK: - CKDatabase Extension for async operations
extension CKDatabase {
  func perform(_ operation: CKDatabaseOperation) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      let resumeHandler = ResumeHandler(continuation: continuation)

      if let modifyOperation = operation as? CKModifyRecordsOperation {
        modifyOperation.modifyRecordsResultBlock = { result in
          switch result {
          case .success:
            resumeHandler.resume()
          case .failure(let error):
            resumeHandler.resume(throwing: error)
          }
        }
      } else {
        // For other operation types, use the completion block
        operation.completionBlock = {
          resumeHandler.resume()
        }
      }

      self.add(operation)
    }
  }
}

// MARK: - Thread-safe Resume Handler
private final class ResumeHandler: @unchecked Sendable {
  private var continuation: CheckedContinuation<Void, Error>?
  private let lock = NSLock()

  init(continuation: CheckedContinuation<Void, Error>) {
    self.continuation = continuation
  }

  func resume() {
    lock.lock()
    defer { lock.unlock() }

    if let continuation = self.continuation {
      self.continuation = nil
      continuation.resume()
    }
  }

  func resume(throwing error: Error) {
    lock.lock()
    defer { lock.unlock() }

    if let continuation = self.continuation {
      self.continuation = nil
      continuation.resume(throwing: error)
    }
  }
}

// MARK: - CloudKit Push Notification Handling
extension CloudKitSyncService {

  /// Handle CloudKit push notifications to trigger incremental sync
  func handleCloudKitNotification(_ userInfo: [AnyHashable: Any]) async {
    guard
      let notification = CKNotification(
        fromRemoteNotificationDictionary: userInfo
      )
    else {
      return
    }

    switch notification.notificationType {
    case .query:
      // A query subscription fired - trigger incremental sync
      Task {
        try? await performIncrementalSync()
      }
    case .database:
      // Database-level notification - might want to handle differently
      break
    case .recordZone:
      // Record zone notification
      break
    case .readNotification:
      // Read notification - not typically used for sync
      break
    @unknown default:
      // Added missing case for exhaustive switch
      print("Unknown CloudKit notification type received")
      break
    }
  }

  /// Check if the app can use CloudKit (for onboarding flows)
  func checkCloudKitAvailability() async -> Bool {
    do {
      try await checkAccountStatus()
      return true
    } catch {
      return false
    }
  }

  /// Reset sync state (useful for troubleshooting)
  func resetSyncState() {
    predictionChangeToken = nil
    lastSyncDate = nil
    isInitialSetupComplete = false
    UserDefaults.standard.removeObject(forKey: "lastCloudKitSyncDate")
  }

  /// Development-only function to completely reset the CloudKit container
  /// WARNING: This will delete ALL data in your iCloud container permanently!
  /// Use only during development when you have corrupted data that can't be cleared from Settings
  @MainActor
  func resetCloudKitContainer() async throws {
    #if DEBUG
      print(
        "🚨 WARNING: Resetting entire CloudKit container - ALL DATA WILL BE LOST!"
      )

      try initializeCloudKitIfNeeded()
      guard let privateDatabase = privateDatabase else {
        throw CloudKitSyncError.iCloudAccountNotAvailable
      }

      var resetErrors: [String] = []

      // Step 1: Delete all prediction records
      do {
        try await deleteAllRecords(
          ofType: RecordType.prediction,
          from: privateDatabase
        )
      } catch {
        resetErrors.append(
          "Failed to delete predictions: \(error.localizedDescription)"
        )
        print(
          "⚠️ Warning: Failed to delete prediction records, continuing reset: \(error)"
        )
      }

      // Step 2: Delete all analytics records
      do {
        try await deleteAllRecords(
          ofType: RecordType.analyticsMetrics,
          from: privateDatabase
        )
      } catch {
        resetErrors.append(
          "Failed to delete analytics: \(error.localizedDescription)"
        )
        print(
          "⚠️ Warning: Failed to delete analytics records, continuing reset: \(error)"
        )
      }

      // Step 3: Delete settings record
      do {
        try await deleteSettingsRecord(from: privateDatabase)
      } catch {
        resetErrors.append(
          "Failed to delete settings: \(error.localizedDescription)"
        )
        print(
          "⚠️ Warning: Failed to delete settings record, continuing reset: \(error)"
        )
      }

      // Step 4: Delete the custom zone (this will cascade delete all records in it)
      do {
        try await deleteCustomZone(from: privateDatabase)
      } catch {
        resetErrors.append(
          "Failed to delete zone: \(error.localizedDescription)"
        )
        print(
          "⚠️ Warning: Failed to delete custom zone, continuing reset: \(error)"
        )
      }

      // Step 5: Reset all local sync state (always succeeds)
      resetSyncState()

      // Step 6: Clear all local store sync flags (always succeeds)
      AnalyticsStore.shared.markMetricsAsSynced(
        AnalyticsStore.shared.getMetricsNeedingSync().map { $0.id }
      )
      SettingsStore.shared.markAsSynced()

      if resetErrors.isEmpty {
        print("✅ CloudKit container reset completed successfully")
      } else {
        print("⚠️ CloudKit container reset completed with warnings:")
        for error in resetErrors {
          print("  - \(error)")
        }
      }
      print(
        "ℹ️  You may need to restart the app for changes to take full effect"
      )
    #else
      throw CloudKitSyncError.syncFailed(
        "CloudKit reset is only available in DEBUG builds"
      )
    #endif
  }

  // MARK: - Private Reset Helper Methods

  private func deleteAllRecords(
    ofType recordType: String,
    from database: CKDatabase
  ) async throws {
    print("Deleting all records of type: \(recordType)")

    do {
      let query = CKQuery(
        recordType: recordType,
        predicate: NSPredicate(value: true)
      )
      let (results, _) = try await database.records(
        matching: query,
        inZoneWith: customZoneID
      )

      var recordIDsToDelete: [CKRecord.ID] = []
      for (recordID, result) in results {
        switch result {
        case .success(_):
          recordIDsToDelete.append(recordID)
        case .failure(let error):
          print("Failed to fetch record \(recordID): \(error)")
        }
      }

      if !recordIDsToDelete.isEmpty {
        let operation = CKModifyRecordsOperation(
          recordsToSave: nil,
          recordIDsToDelete: recordIDsToDelete
        )
        operation.qualityOfService = .userInitiated

        try await database.perform(operation)
        print(
          "Deleted \(recordIDsToDelete.count) records of type \(recordType)"
        )
      } else {
        print("No records found of type \(recordType)")
      }

    } catch let error as CKError {
      // Handle specific CloudKit errors
      switch error.code {
      case .invalidArguments:
        // This happens when the field is not queryable - likely means no records exist yet
        print(
          "CloudKit schema not initialized for \(recordType) or no records exist - skipping deletion"
        )
        return
      case .zoneNotFound:
        print("Zone not found for \(recordType) - skipping deletion")
        return
      case .unknownItem:
        print("No records found of type \(recordType) - skipping deletion")
        return
      default:
        print("CloudKit error deleting records of type \(recordType): \(error)")
        throw error
      }
    } catch {
      print("Unexpected error deleting records of type \(recordType): \(error)")
      throw error
    }
  }

  private func deleteSettingsRecord(from database: CKDatabase) async throws {
    print("Deleting settings record")

    let recordID = CKRecord.ID(recordName: "AppSettings", zoneID: customZoneID)

    do {
      try await database.deleteRecord(withID: recordID)
      print("Settings record deleted successfully")
    } catch let error as CKError where error.code == .unknownItem {
      print("Settings record not found (already deleted or never created)")
    } catch {
      throw error
    }
  }

  private func deleteCustomZone(from database: CKDatabase) async throws {
    print("Deleting custom zone: \(customZoneID.zoneName)")

    do {
      try await database.deleteRecordZone(withID: customZoneID)
      print("Custom zone deleted successfully")
    } catch let error as CKError where error.code == .zoneNotFound {
      print("Custom zone not found (already deleted or never created)")
    } catch {
      throw error
    }
  }
}

// MARK: - Sync Metrics and Monitoring
extension CloudKitSyncService {

  struct SyncMetrics {
    let duration: TimeInterval
    let recordsUploaded: Int
    let recordsDownloaded: Int
    let errors: [CloudKitSyncError]
    let timestamp: Date
  }

  private func recordSyncMetrics(_ metrics: SyncMetrics) {
    // You could send these to analytics or logging service
    print(
      "Sync completed in \(metrics.duration)s - Up: \(metrics.recordsUploaded), Down: \(metrics.recordsDownloaded)"
    )

    if !metrics.errors.isEmpty {
      print("Sync errors: \(metrics.errors)")
    }
  }
}

// MARK: - Data Validation
extension CloudKitSyncService {

  private func validateRecordBeforeUpload(_ record: CKRecord) -> Bool {
    // Ensure required fields are present
    guard record["id"] != nil,
      record["eventName"] != nil,
      record["dateCreated"] != nil
    else {
      return false
    }

    // Validate data types
    if let confidenceLevel = record["confidenceLevel"] as? Double {
      guard confidenceLevel >= 0 && confidenceLevel <= 100 else {
        return false
      }
    }

    return true
  }

  private func uploadPredictionBatch(
    _ predictions: [Prediction],
    to database: CKDatabase
  ) async throws -> [LocalChange] {
    let records = predictions.map { CKRecord(from: $0, in: customZoneID) }

    let operation = CKModifyRecordsOperation(
      recordsToSave: records,
      recordIDsToDelete: nil
    )
    operation.savePolicy = .ifServerRecordUnchanged
    operation.qualityOfService = .userInitiated

    // Add retry logic for batch operations
    var retryCount = 0
    repeat {
      do {
        try await database.perform(operation)
        return predictions.map { prediction in
          LocalChange(
            id: prediction.id.uuidString,
            recordType: RecordType.prediction,
            changeType: .updated
          )
        }
      } catch let error as CKError {
        retryCount += 1
        if retryCount >= configuration.maxRetries {
          throw error
        }

        // Handle partial failures
        if error.code == .partialFailure {
          // Log and continue - some records succeeded
          print("Partial failure in batch upload: \(error)")
          return predictions.map { prediction in
            LocalChange(
              id: prediction.id.uuidString,
              recordType: RecordType.prediction,
              changeType: .updated
            )
          }
        }

        // Wait before retry
        try await Task.sleep(
          nanoseconds: UInt64(configuration.retryDelay * 1_000_000_000)
        )
      }
    } while retryCount < configuration.maxRetries

    // This shouldn't be reached, but just in case
    return []
  }
}
