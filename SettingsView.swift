import SwiftUI

struct SettingsView: View {
  @StateObject private var settings = SettingsStore.shared

  var body: some View {
    NavigationView {
      List {

        Section {
          HStack {
            Picker("Significance Level", selection: $settings.significanceLevel)
            {
              ForEach(settings.significanceLevels, id: \.self) { level in
                Text(String(format: "%.2f", level)).tag(level)
              }
            }
            .pickerStyle(.menu)
          }

          HStack {
            Picker(
              "Acceptance Area",
              selection: $settings.acceptanceAreaDisplay
            ) {
              Text("Show").tag("Show")
              Text("Hide").tag("Hide")
            }
            .pickerStyle(.menu)
          }

          HStack {
            Text("Reminders")
            Spacer()
            Toggle("", isOn: $settings.remindersEnabled)
          }

        } header: {
          Text("Preferences")
        } footer: {
          Text(
            "The acceptance area shows a confidence interval for numeric predictions based on your significance level. Lower significance levels create narrower acceptance ranges. This statistical estimate helps you understand prediction uncertainty, but should be adjusted based on your domain knowledge."
          )
          .font(.caption)
          .foregroundColor(.secondary)
        }

        Section {
          HStack {
            Text("iCloud Sync")
            Spacer()
            Toggle("", isOn: $settings.syncWithiCloud)
          }

          HStack {
            Text("Connect to Health")
            Spacer()
            Toggle("", isOn: $settings.connectToHealth)
          }

          Button(action: {
            // Export functionality
            print("Export tapped")
          }) {
            HStack {
              Text("Export")
              Spacer()
              Image(systemName: "square.and.arrow.up")
            }
          }
          .foregroundColor(.primary)

          Button(action: {
            // Clear all functionality
            print("Clear All tapped")
          }) {
            HStack {
              Text("Clear All")
              Spacer()
              Image(systemName: "trash")
            }
          }

        } header: {
          Text("Data Management")
        } footer: {
          Text(
            "Apple Health integration enables automatic reading and writing of relevant health metrics, including blood pressure measurements and medication adherence data, to enhance prediction accuracy and provide comprehensive health tracking when applicable."
          )
          .font(.caption)
          .foregroundColor(.secondary)
        }

        Section("About") {
          HStack {
            Text("Version")
            Spacer()
            Text("1.0.0")
              .foregroundColor(.secondary)
          }

          Button(action: {
            // Help & Support functionality
            print("Help & Support tapped")
          }) {
            HStack {
              Text("Help & Support")
              Spacer()
              Image(systemName: "questionmark.circle")
            }
          }
          .foregroundColor(.primary)

          Button(action: {
            // Credits functionality
            print("Credits tapped")
          }) {
            HStack {
              Text("Credits")
              Spacer()
              Image(systemName: "info.circle")
            }
          }
          .foregroundColor(.primary)

        }
      }
      .background(DesignTokens.Colors.cardBackground)
      .scrollContentBackground(.hidden)
      .navigationTitle("Settings")
    }
  }
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView()
  }
}
