import SwiftData
import SwiftUI
import UserNotifications

@main
struct DelphiApp: App {
  @StateObject private var notificationService = NotificationService.shared
  
  // MARK: - Clean Architecture Dependencies
  @StateObject private var appCoordinator: AppCoordinator
  
  init() {
    // Configure DI Container with ModelContext
    let container = DIContainer.shared
    let modelContext = ModelContext(DelphiApp.sharedModelContainer)
    container.setModelContext(modelContext)
    
    // Initialize AppCoordinator
    self._appCoordinator = StateObject(wrappedValue: AppCoordinator(container: container))
  }

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
      PredictionDataModel.self
    ])

    let modelConfiguration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: false
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
            isStoredInMemoryOnly: false
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
      ContentView()
        .environmentObject(notificationService)
        .environmentObject(appCoordinator)
        .environment(\.diContainer, DIContainer.shared)
        .onAppear {
          // Suppress Apple Intelligence XPC warnings in simulator
          #if targetEnvironment(simulator)
          setenv("OS_ACTIVITY_MODE", "disable", 1)
          #endif
        }
    }
    .modelContainer(DelphiApp.sharedModelContainer)
  }

}

