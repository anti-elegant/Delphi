import SwiftUI
import SwiftData

struct ContentView: View {
  @EnvironmentObject private var appCoordinator: AppCoordinator
  @Environment(\.diContainer) private var container: DIContainer?

  var body: some View {
    Group {
      if let container = container {
        appCoordinator.makeTabView()
      } else {
        // Fallback view - should not be reached with proper clean architecture setup
        VStack(spacing: 16) {
          Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 48))
            .foregroundColor(.orange)
          
          Text("Configuration Error")
            .font(.title2)
            .fontWeight(.medium)
          
          Text("DI Container not available. Please check app initialization.")
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding()
      }
    }
  }
}

#Preview {
  let container = DIContainer.shared
  let coordinator = AppCoordinator(container: container)
  
  ContentView()
    .environmentObject(coordinator)
    .environment(\.diContainer, container)
}
