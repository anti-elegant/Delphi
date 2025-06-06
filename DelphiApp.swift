import SwiftData
import SwiftUI

@main
struct DelphiApp: App {
  static let sharedModelContainer: ModelContainer = {
    let schema = Schema([
      Prediction.self
    ])
    let modelConfiguration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: false,
      cloudKitDatabase: .automatic  // This enables CloudKit sync
    )

    do {
      let container = try ModelContainer(
        for: schema,
        configurations: [modelConfiguration]
      )

      // Seed sample data in development
      #if DEBUG
        SampleDataSeeder.seedSampleData(in: container.mainContext)
      #endif

      return container
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      LandingView()
    }
    .modelContainer(DelphiApp.sharedModelContainer)
  }
}
