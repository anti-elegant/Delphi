import SwiftUI

struct ContentView: View {
  @StateObject private var settings = SettingsStore.shared

  var body: some View {
    TabView {
      PredictionFormView()
        .tabItem {
          Image(systemName: "plus.circle")
          Text("Record")
        }

      PredictionListView()
        .tabItem {
          Image(systemName: "doc.text.fill")
          Text("View All")
        }

      if settings.showAnalytics {
        AnalyticsView()
          .tabItem {
            Image(systemName: "chart.pie")
            Text("Analytics")
          }
      }

      SettingsView()
        .tabItem {
          Image(systemName: "gear")
          Text("Settings")
        }
    }
  }
}

#Preview {
  ContentView()
}
