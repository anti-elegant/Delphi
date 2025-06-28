import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
  @StateObject private var settings = SettingsStore.shared
  @StateObject private var analyticsStore = AnalyticsStore.shared
  @StateObject private var notificationService = NotificationService.shared
  @StateObject private var cloudKitService = CloudKitSyncService.shared
  @Environment(\.modelContext) private var modelContext
  @State private var showingSyncError = false
  @State private var syncErrorMessage = ""
  @State private var showingExportSheet = false
  @State private var exportURL: URL?
  @State private var showingClearConfirmation = false
  @State private var isExporting = false

  private var isCurrentlySyncing: Bool {
    if case .syncing = cloudKitService.syncStatus {
      return true
    }
    return false
  }

  private var appVersion: String {
    let version =
      Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
      ?? "Unknown"
    let build =
      Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    return "\(version) (\(build))"
  }

  var body: some View {
    NavigationStack {
      List {
        preferencesSection

        dataManagementSection

        aboutSection
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.large)
      .alert("Sync Error", isPresented: $showingSyncError) {
        Button("OK") {}
      } message: {
        Text(syncErrorMessage)
      }

      .alert(
        "Clear All Data",
        isPresented: $showingClearConfirmation
      ) {
        Button("Clear All Data", role: .destructive) {
          let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
          impactFeedback.impactOccurred()
          Task {
            await clearAllData()
          }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text(
          "This will permanently delete all predictions, analytics data, and reset settings to defaults. This action cannot be undone."
        )
      }
      .onAppear {
        // Set the model context for CloudKit sync
        cloudKitService.setModelContext(modelContext)
      }
      .sheet(isPresented: $showingExportSheet) {
        if let url = exportURL {
          ActivityViewWrapper(activityItems: [url]) {
            showingExportSheet = false
            exportURL = nil
          }
        }
      }
    }
  }

  // MARK: - Section Views
  private var preferencesSection: some View {
    Section {
      HStack {
        Picker("Significance Level", selection: $settings.significanceLevel) {
          ForEach(settings.significanceLevels, id: \.self) { level in
            Text(String(format: "%.2f", level)).tag(level)
          }
        }
        .pickerStyle(.menu)
        .onChange(of: settings.significanceLevel) { _, _ in
          let impactFeedback = UIImpactFeedbackGenerator(style: .light)
          impactFeedback.impactOccurred()
        }
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
        .onChange(of: settings.acceptanceAreaDisplay) { _, _ in
          let impactFeedback = UIImpactFeedbackGenerator(style: .light)
          impactFeedback.impactOccurred()
        }
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Reminders")
          Spacer()
          Toggle("", isOn: $settings.remindersEnabled)
            .disabled(notificationService.authorizationStatus == .denied)
            .onChange(of: settings.remindersEnabled) { _, newValue in
              let impactFeedback = UIImpactFeedbackGenerator(style: .light)
              impactFeedback.impactOccurred()

              if newValue
                && notificationService.authorizationStatus != .authorized
              {
                Task {
                  try? await notificationService
                    .requestNotificationPermission()
                }
              }
            }
        }

        if notificationService.authorizationStatus == .denied {
          Text("Enable notifications in Settings to use reminders")
            .font(.caption)
            .foregroundColor(.orange)
        }
      }

      HStack {
        Text("Show Analytics")
        Spacer()
        Toggle("", isOn: $settings.showAnalytics)
          .onChange(of: settings.showAnalytics) { _, _ in
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
          }
      }

    } header: {
      Text("Preferences")
    } footer: {
      Text(
        "The acceptance area provides a statistical approximation based on your significance level, but cannot rigorously calculate actual prediction intervals given limited information. Users should exercise independent judgment when evaluating prediction accuracy."
      )
      .font(.caption)
      .foregroundColor(.secondary)
    }
  }

  private var dataManagementSection: some View {
    Section {
      iCloudSyncRow

      Button(action: {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        Task {
          await exportData()
        }
      }) {
        HStack {
          Text("Export")
          Spacer()
          if isExporting {
            ProgressView()
              .scaleEffect(0.8)
          } else {
            Image(systemName: "square.and.arrow.up")
          }
        }
      }
      .foregroundColor(.primary)
      .disabled(isExporting)

      Button(action: {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        showingClearConfirmation = true
      }) {
        HStack {
          Text("Clear All")
          Spacer()
          Image(systemName: "trash")
        }
      }
      .foregroundColor(.red)

    } header: {
      Text("Data Management")
    } footer: {
      Text(
        "CloudKit synchronization services may potentially affect iCloud storage and damage your data."
      )
      .font(.caption)
      .foregroundColor(.secondary)
    }
  }

  private var aboutSection: some View {
    Section("About") {
      HStack {
        Text("Version")
        Spacer()
        Text(appVersion)
          .foregroundColor(.secondary)
      }

      NavigationLink(destination: SupportView()) {
        Text("Support")
      }

      NavigationLink(destination: CreditsView()) {
        Text("Credits")
      }
    }
  }

  private var iCloudSyncRow: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text("iCloud Sync")
        Spacer()
        Toggle("", isOn: $settings.syncWithiCloud)
          .disabled(isCurrentlySyncing)
          .onChange(of: settings.syncWithiCloud) { _, newValue in
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            let syncCoordinator = SyncCoordinator.shared
            if newValue {
              syncCoordinator.enableCloudKitSync()
            } else {
              syncCoordinator.disableCloudKitSync()
            }
          }
      }

      // Show sync status caption when enabled
      if settings.syncWithiCloud {
        SyncStatusCaption()
      }
    }
  }

  // MARK: - Data Management Methods
  @MainActor
  private func exportData() async {
    isExporting = true
    defer { isExporting = false }

    do {
      // Ensure PredictionStore has the model context
      PredictionStore.shared.setModelContext(modelContext)
      let predictions = await PredictionStore.shared
        .fetchPredictionsForAnalytics()

      print("Exporting \(predictions.count) predictions")

      let exportData = try ExportData(
        predictions: predictions.map { prediction in
          ExportPrediction(
            id: prediction.id.uuidString,
            eventName: prediction.eventName,
            eventDescription: prediction.eventDescription,
            confidenceLevel: prediction.confidenceLevel,
            estimatedValue: prediction.estimatedValue,
            booleanValue: prediction.booleanValue,
            pressureLevel: prediction.pressureLevel,
            currentMood: prediction.currentMood,
            takesMedicine: prediction.takesMedicine,
            evidenceList: prediction.evidenceList,
            selectedType: prediction.selectedType.rawValue,
            dateCreated: prediction.dateCreated,
            dueDate: prediction.dueDate,
            resolutionDate: prediction.resolutionDate,
            isPending: prediction.isPending,
            isResolved: prediction.isResolved,
            actualOutcome: prediction.actualOutcome
          )
        },
        analyticsMetrics: analyticsStore.analyticsMetrics,
        settings: SettingsStore.shared.exportSettings(),
        exportDate: Date()
      )

      let jsonData = try JSONEncoder().encode(exportData)

      let documentsPath = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
      )[0]
      let fileName =
        "delphi_export_\(DateFormatter.fileDate.string(from: Date())).json"
      let fileURL = documentsPath.appendingPathComponent(fileName)

      try jsonData.write(to: fileURL)

      print("Export file created at: \(fileURL.path)")
      print(
        "File exists: \(FileManager.default.fileExists(atPath: fileURL.path))"
      )

      exportURL = fileURL
      showingExportSheet = true

    } catch {
      syncErrorMessage = "Failed to export data: \(error.localizedDescription)"
      showingSyncError = true
    }
  }

  @MainActor
  private func clearAllData() async {
    // Ensure PredictionStore has the model context
    PredictionStore.shared.setModelContext(modelContext)

    await PredictionStore.shared.deleteAllPredictions()

    analyticsStore.resetToDefaults()
    SettingsStore.shared.resetToDefaults()

    if PredictionStore.shared.lastError != nil {
      syncErrorMessage =
        "Failed to clear data: \(PredictionStore.shared.lastError!.localizedDescription)"
      showingSyncError = true
    } else {
      print("All data cleared successfully")
    }
  }
}

// MARK: - Export Data Models
struct ExportData: Codable {
  let predictions: [ExportPrediction]
  let analyticsMetrics: [AnalyticsMetric]
  let settingsData: Data  // Store settings as Data instead of [String: Any]
  let exportDate: Date

  enum CodingKeys: String, CodingKey {
    case predictions, analyticsMetrics, settingsData, exportDate
  }

  init(
    predictions: [ExportPrediction],
    analyticsMetrics: [AnalyticsMetric],
    settings: [String: Any],
    exportDate: Date
  ) throws {
    self.predictions = predictions
    self.analyticsMetrics = analyticsMetrics
    self.settingsData = try JSONSerialization.data(withJSONObject: settings)
    self.exportDate = exportDate
  }
}

struct ExportPrediction: Codable {
  let id: String
  let eventName: String
  let eventDescription: String
  let confidenceLevel: Double
  let estimatedValue: String
  let booleanValue: String
  let pressureLevel: String
  let currentMood: String
  let takesMedicine: String
  let evidenceList: [String]
  let selectedType: String
  let dateCreated: Date
  let dueDate: Date
  let resolutionDate: Date?
  let isPending: Bool
  let isResolved: Bool
  let actualOutcome: String?
}

// MARK: - Activity View Controller
struct ActivityViewWrapper: UIViewControllerRepresentable {
  let activityItems: [Any]
  let onDismiss: () -> Void

  func makeUIViewController(context: Context) -> UIActivityViewController {
    let controller = UIActivityViewController(
      activityItems: activityItems,
      applicationActivities: nil
    )

    controller.completionWithItemsHandler = { _, _, _, _ in
      onDismiss()
    }

    return controller
  }

  func updateUIViewController(
    _ uiViewController: UIActivityViewController,
    context: Context
  ) {
    // No updates needed
  }
}

// MARK: - Sync Status Caption
struct SyncStatusCaption: View {
  @StateObject private var syncCoordinator = SyncCoordinator.shared

  var body: some View {
    Text(syncStatusText)
      .font(.caption)
      .foregroundColor(.secondary)
  }

  private var syncStatusText: String {
    switch syncCoordinator.syncState {
    case .idle:
      if syncCoordinator.pendingChangesCount > 0 {
        return "\(syncCoordinator.pendingChangesCount) pending changes"
      } else if let lastSync = syncCoordinator.lastSyncDate {
        return "Last synced \(relativeDateString(from: lastSync))"
      } else {
        return "Never synced"
      }
    case .preparing:
      return "Preparing to sync..."
    case .syncing(let progress):
      return "Syncing... \(Int(progress * 100))%"
    case .success:
      if let lastSync = syncCoordinator.lastSyncDate {
        return "Last synced \(relativeDateString(from: lastSync))"
      }
      return "Synced"
    case .error(let message):
      return "Sync failed: \(message)"
    }
  }

  private func relativeDateString(from date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
  }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
  static let fileDate: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    return formatter
  }()

  static let relativeTime: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter
  }()
}

// MARK: - Destination Views
struct SupportView: View {
  var body: some View {
    List {
      Section("Resources") {
        Button(action: {
          if let url = URL(string: "mailto:apple@cy.sb") {
            UIApplication.shared.open(url)
          }
        }) {
          Label("Email", systemImage: "envelope")
        }
        .foregroundColor(.primary)

        Link(
          destination: URL(
            string: "https://github.com/anti-elegant/Delphi/issues"
          )!
        ) {
          Label("Roadmap", systemImage: "link")
        }
        .foregroundColor(.primary)
      }

      Section("Disclaimer") {
        Text(
          "This application is currently in rapid development and may undergo significant changes. Users are advised to exercise caution and understand that features, functionality, and data structures may be modified without prior notice."
        )
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Support")
    .navigationBarTitleDisplayMode(.large)
  }
}

struct CreditsView: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "cat.fill")
        .font(.system(size: 48))
        .foregroundColor(.secondary)

      Text("Made by CY and Claude Sonnet 4")
        .bodyTextStyle()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .navigationTitle("Credits")
    .navigationBarTitleDisplayMode(.large)
  }
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      SettingsView()
        .modelContainer(for: [Prediction.self], inMemory: true)
    }
  }
}
