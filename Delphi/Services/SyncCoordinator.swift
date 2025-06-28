import Combine
import Foundation
import SwiftUI

// MARK: - Sync State
enum SyncState: Equatable {
  case idle
  case preparing
  case syncing(progress: Double)
  case success
  case error(String)

  var isActive: Bool {
    switch self {
    case .preparing, .syncing:
      return true
    default:
      return false
    }
  }
}

// MARK: - Sync Coordinator
@MainActor
final class SyncCoordinator: ObservableObject {
  static let shared = SyncCoordinator()

  // MARK: - Published Properties
  @Published private(set) var syncState: SyncState = .idle
  @Published private(set) var lastSyncDate: Date?
  @Published private(set) var pendingChangesCount: Int = 0
  @Published private(set) var isCloudKitEnabled: Bool = false
  @Published private(set) var canSync: Bool = false

  // MARK: - Private Properties
  private let cloudKitService = CloudKitSyncService.shared
  private let settingsStore = SettingsStore.shared
  private var cancellables = Set<AnyCancellable>()
  private let syncDebounceTime: TimeInterval = 2.0
  private let maxSyncFrequency: TimeInterval = 30.0
  private var lastSyncTime: Date?

  // MARK: - Initialization
  private init() {
    setupBindings()
    loadSyncState()
  }

  // MARK: - Public Interface
  func requestSync() {
    Task { await performSyncIfNeeded() }
  }

  func enableCloudKitSync() {
    settingsStore.syncWithiCloud = true
  }

  func disableCloudKitSync() {
    settingsStore.syncWithiCloud = false
  }

  func resetSyncState() {
    syncState = .idle
    lastSyncTime = nil
    pendingChangesCount = 0
    saveSyncState()
  }

  // MARK: - Private Setup
  private func setupBindings() {
    // Observe CloudKit service state
    cloudKitService.$isNetworkAvailable
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.updateCanSyncStatus()
      }
      .store(in: &cancellables)

    cloudKitService.$syncStatus
      .receive(on: DispatchQueue.main)
      .sink { [weak self] status in
        self?.handleSyncStatusChange(status)
      }
      .store(in: &cancellables)

    cloudKitService.$lastSyncDate
      .receive(on: DispatchQueue.main)
      .sink { [weak self] date in
        self?.lastSyncDate = date
        self?.saveSyncState()
      }
      .store(in: &cancellables)

    cloudKitService.$pendingChangesCount
      .receive(on: DispatchQueue.main)
      .sink { [weak self] count in
        self?.pendingChangesCount = count
      }
      .store(in: &cancellables)

    // Observe settings changes
    Timer.publish(every: 1.0, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        let newValue = SettingsStore.shared.syncWithiCloud
        if self?.isCloudKitEnabled != newValue {
          self?.isCloudKitEnabled = newValue
          self?.updateCanSyncStatus()
        }
      }
      .store(in: &cancellables)
  }

  private func handleSyncStatusChange(_ status: SyncStatus) {
    switch status {
    case .idle:
      if syncState.isActive {
        syncState = .idle
      }
    case .syncing:
      syncState = .syncing(progress: cloudKitService.syncProgress)
    case .success:
      syncState = .success
      lastSyncTime = Date()
      saveSyncState()
    case .error(let error):
      syncState = .error(error.localizedDescription)
      saveSyncState()
    }
  }

  private func updateCanSyncStatus() {
    canSync = isCloudKitEnabled && cloudKitService.isNetworkAvailable
  }

  private func performSyncIfNeeded() async {
    guard canSync else {
      print("Cannot sync: CloudKit disabled or network unavailable")
      return
    }

    // Rate limiting: don't sync too frequently
    if let lastSync = lastSyncTime,
      Date().timeIntervalSince(lastSync) < maxSyncFrequency
    {
      print("Sync rate limited - too frequent")
      return
    }

    guard pendingChangesCount > 0 else {
      print("No pending changes to sync")
      return
    }

    syncState = .preparing

    do {
      try await cloudKitService.performIncrementalSync()
    } catch {
      print("Sync failed: \(error)")
      // Error will be handled by status change observer
    }
  }

  // MARK: - Persistence
  private func loadSyncState() {
    lastSyncDate = cloudKitService.lastSyncDate
    isCloudKitEnabled = settingsStore.syncWithiCloud
    updateCanSyncStatus()

    // Initial update of pending changes count
    Task {
      await cloudKitService.updatePendingChangesCount()
    }
  }

  private func saveSyncState() {
    // Sync state is automatically persisted via CloudKitService
  }
}

// MARK: - View Extension for Easy Access
extension View {
  func syncCoordinator() -> SyncCoordinator {
    SyncCoordinator.shared
  }
}
