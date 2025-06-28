import CloudKit
import SwiftData
import SwiftUI
import UserNotifications

@main
struct DelphiApp: App {
  @StateObject private var notificationService = NotificationService.shared

  // MARK: - Development Flags
  #if DEBUG
    /// Set to true to force a complete database rebuild on next launch
    /// This will clear ALL existing data and create fresh sample data
    ///
    /// Usage:
    /// 1. Set `forceRebuildDatabase = true`
    /// 2. Build and run the app - database will be cleared and reseeded
    /// 3. Set `forceRebuildDatabase = false` to prevent future clears
    ///
    /// Note: This only affects DEBUG builds and won't impact production
    private static let forceRebuildDatabase = false
  #endif

  static let sharedModelContainer: ModelContainer = {
    let schema = Schema([
      Prediction.self
    ])

    // Only enable CloudKit in production with proper entitlements
    let cloudKitDatabase: ModelConfiguration.CloudKitDatabase
    #if targetEnvironment(simulator)
      // Disable CloudKit in simulator to prevent crashes
      cloudKitDatabase = .none
    #else
      // Enable CloudKit on device if entitlements are available
      if Bundle.main.object(
        forInfoDictionaryKey: "com.apple.developer.icloud-services"
      ) != nil {
        cloudKitDatabase = .automatic
      } else {
        cloudKitDatabase = .none
      }
    #endif

    let modelConfiguration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: false,
      cloudKitDatabase: cloudKitDatabase
    )

    do {
      let container = try ModelContainer(
        for: schema,
        configurations: [modelConfiguration]
      )

      // Handle database rebuild in development if needed
      #if DEBUG
        if forceRebuildDatabase {
          print("🔄 Force rebuild enabled - clearing all existing data...")
          Task { @MainActor in
            // Clear existing data by resetting UserDefaults and clearing ModelContainer
            let domain = Bundle.main.bundleIdentifier!
            UserDefaults.standard.removePersistentDomain(forName: domain)
            UserDefaults.standard.synchronize()
            print(
              "✅ All existing data cleared - app will reseed on next launch"
            )
          }
        }
      #endif

      return container
    } catch {
      // If container creation fails (likely due to schema changes), try to recover
      print("Initial ModelContainer creation failed: \(error)")

      #if DEBUG
        // In debug mode, try to clear the store and recreate
        do {
          // Create a new configuration that will recreate the store
          let recoveryConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // Disable CloudKit during recovery
          )

          let recoveryContainer = try ModelContainer(
            for: schema,
            configurations: [recoveryConfiguration]
          )

          // Clear UserDefaults during recovery to allow fresh start
          Task { @MainActor in
            let domain = Bundle.main.bundleIdentifier!
            UserDefaults.standard.removePersistentDomain(forName: domain)
            UserDefaults.standard.synchronize()
            print("✅ Recovery completed - data cleared")
          }

          print("ModelContainer recovered successfully")
          return recoveryContainer
        } catch {
          print("Recovery failed: \(error)")
          fatalError("Could not create or recover ModelContainer: \(error)")
        }
      #else
        fatalError("Could not create ModelContainer: \(error)")
      #endif
    }
  }()

  var body: some Scene {
    WindowGroup {
      LandingView()
        .environmentObject(notificationService)
    }
    .modelContainer(DelphiApp.sharedModelContainer)
  }

}

// MARK: - CloudKit Push Notification Handling
class AppDelegate: NSObject, UIApplicationDelegate {

  func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (
      UIBackgroundFetchResult
    ) -> Void
  ) {

    // Check if this is a CloudKit notification
    if userInfo["ck"] as? [String: Any] != nil {
      Task {
        await CloudKitSyncService.shared.handleCloudKitNotification(userInfo)
        completionHandler(.newData)
      }
    } else {
      completionHandler(.noData)
    }
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("Failed to register for remote notifications: \(error)")
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    print("Successfully registered for remote notifications")
  }
}
