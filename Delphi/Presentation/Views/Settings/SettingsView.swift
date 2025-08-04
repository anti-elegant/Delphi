//
//  SettingsView.swift
//  Delphi
//
//  Comprehensive settings view for configuring all app preferences
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Core Settings
                Section("General") {
                    Toggle("Enable Reminders", isOn: $viewModel.remindersEnabled)
                    Toggle("Enable Analytics", isOn: $viewModel.analyticsEnabled)
                }
                
                // MARK: - Reminder Settings
                if viewModel.remindersEnabled {
                    Section("Reminder Settings") {
                        Picker("Reminder Frequency", selection: $viewModel.reminderInterval) {
                            ForEach(ReminderInterval.allCases) { interval in
                                Text(interval.displayName).tag(interval)
                            }
                        }
                        
                        if viewModel.reminderInterval != .disabled {
                            DatePicker("Reminder Time", 
                                     selection: Binding(
                                        get: { viewModel.reminderTime ?? Date() },
                                        set: { viewModel.reminderTime = $0 }
                                     ),
                                     displayedComponents: .hourAndMinute)
                        }
                        
                        Toggle("Overdue Reminders", isOn: $viewModel.overdueReminderEnabled)
                    }
                }
                
                // MARK: - Context Tracking
                Section("Context Tracking") {
                    Toggle("Enable Context Tracking", isOn: $viewModel.contextTrackingEnabled)
                    
                    if viewModel.contextTrackingEnabled {
                        Toggle("Track Mood", isOn: $viewModel.trackMood)
                        Toggle("Track Pressure", isOn: $viewModel.trackPressure)
                        Toggle("Track Sleep Quality", isOn: $viewModel.trackSleep)
                        Toggle("Track Stress Factors", isOn: $viewModel.trackStress)
                        Toggle("Track Environment", isOn: $viewModel.trackEnvironment)
                        Toggle("Track Timing", isOn: $viewModel.trackTiming)
                    }
                }
                
                // MARK: - Display Settings
                Section("Display") {
                    Picker("Default Timeframe", selection: $viewModel.defaultTimeframe) {
                        ForEach(DefaultTimeframe.allCases) { timeframe in
                            Text(timeframe.displayName).tag(timeframe)
                        }
                    }
                    
                    Toggle("Show Confidence in List", isOn: $viewModel.showConfidenceInList)
                    Toggle("Group by Type", isOn: $viewModel.groupPredictionsByType)
                    Toggle("Show Accuracy Trends", isOn: $viewModel.showAccuracyTrends)
                }
                
                // MARK: - Export Settings
                Section("Export & Backup") {
                    Picker("Export Format", selection: $viewModel.exportFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    
                    Toggle("Include Context in Export", isOn: $viewModel.includeContextInExport)
                    
                    Button("Export Data") {
                        Task {
                            if let url = await viewModel.exportData() {
                                // Present activity view controller or show success
                                presentShareSheet(url: url)
                            }
                        }
                    }
                    .disabled(viewModel.isExporting)
                    
                    if viewModel.isExporting {
                        HStack {
                            ProgressView(value: viewModel.exportProgress)
                            Text("\(Int(viewModel.exportProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle("Auto Backup", isOn: $viewModel.autoBackupEnabled)
                    
                    if viewModel.autoBackupEnabled {
                        Picker("Backup Frequency", selection: $viewModel.backupFrequency) {
                            ForEach(BackupFrequency.allCases) { frequency in
                                Text(frequency.displayName).tag(frequency)
                            }
                        }
                    }
                }
                
                // MARK: - Data Management
                Section("Data Management") {
                    Toggle("Require Confirmation for Data Clear", isOn: $viewModel.requireConfirmationForDataClear)
                    
                    Toggle("Auto-resolve Overdue Predictions", isOn: $viewModel.autoResolveOverduePredictions)
                    
                    if viewModel.autoResolveOverduePredictions {
                        Stepper("Auto-resolve after \(viewModel.autoResolveAfterDays) days", 
                               value: $viewModel.autoResolveAfterDays, 
                               in: 1...365)
                    }
                    
                    Button("Clear All Data", role: .destructive) {
                        Task {
                            let _ = await viewModel.deleteAllData()
                        }
                    }
                }
                
                // MARK: - App Settings
                Section("App") {
                    Button("Reset to Defaults") {
                        viewModel.resetToDefaults()
                    }
                    
                    if viewModel.hasUnsavedChanges {
                        Button("Save Changes") {
                            viewModel.saveAllSettings()
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                viewModel.loadSettings()
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { _ in viewModel.clearError() }
            )) {
                Button("OK") { }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "An unknown error occurred")
            }
            .confirmationDialog("Clear All Data", 
                              isPresented: $viewModel.showDeleteConfirmation,
                              titleVisibility: .visible) {
                Button("Clear All Data", role: .destructive) {
                    Task {
                        let _ = await viewModel.confirmDeleteAllData()
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.cancelDeleteAllData()
                }
            } message: {
                Text("This will permanently delete all your predictions and reset settings to defaults. This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Helper Methods
    private func presentShareSheet(url: URL) {
        // This would present a UIActivityViewController in a real app
        // For now, we'll just print the URL
        print("Export saved to: \(url)")
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(
        manageSettingsUseCase: DefaultManageSettingsUseCase(
            repository: UserDefaultsSettingsRepository()
        ),
        exportDataUseCase: DefaultExportDataUseCase(
            predictionRepository: LocalPredictionRepository(),
            settingsRepository: UserDefaultsSettingsRepository(),
            accuracyUseCase: DefaultCalculateAccuracyUseCase(
                repository: LocalPredictionRepository()
            )
        ),
        clearAllDataUseCase: DefaultClearAllDataUseCase(
            predictionRepository: LocalPredictionRepository(),
            settingsRepository: UserDefaultsSettingsRepository()
        )
    ))
}