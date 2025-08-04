//
//  SettingsViewModel.swift
//  Delphi
//
//  ViewModel for handling comprehensive app settings management
//

import Foundation
import Combine

@MainActor
final class SettingsViewModel: BaseViewModel {
    // MARK: - Published Properties
    @Published var settings: Settings?
    
    // Core Settings
    @Published var remindersEnabled: Bool = false
    @Published var analyticsEnabled: Bool = true
    
    // Reminder Settings
    @Published var reminderInterval: ReminderInterval = .weekly
    @Published var reminderTime: Date?
    @Published var overdueReminderEnabled: Bool = true
    
    // Export Settings  
    @Published var exportFormat: ExportFormat = .json
    @Published var includeContextInExport: Bool = true
    @Published var autoBackupEnabled: Bool = false
    @Published var backupFrequency: BackupFrequency = .weekly
    
    // Context Tracking Settings
    @Published var contextTrackingEnabled: Bool = true
    @Published var trackMood: Bool = true
    @Published var trackPressure: Bool = false
    @Published var trackSleep: Bool = true
    @Published var trackStress: Bool = true
    @Published var trackEnvironment: Bool = false
    @Published var trackTiming: Bool = true
    
    // Display Settings
    @Published var defaultTimeframe: DefaultTimeframe = .month
    @Published var showConfidenceInList: Bool = true
    @Published var groupPredictionsByType: Bool = true
    @Published var showAccuracyTrends: Bool = true
    
    // Data Management Settings
    @Published var requireConfirmationForDataClear: Bool = true
    @Published var autoResolveOverduePredictions: Bool = false
    @Published var autoResolveAfterDays: Int = 30
    
    // UI State
    @Published var hasUnsavedChanges: Bool = false
    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0.0
    @Published var showDeleteConfirmation: Bool = false
    
    // MARK: - Dependencies
    private let manageSettingsUseCase: ManageSettingsUseCase
    private let exportDataUseCase: ExportDataUseCase
    private let clearAllDataUseCase: ClearAllDataUseCase
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var originalSettings: Settings?
    
    // MARK: - Initialization
    init(
        manageSettingsUseCase: ManageSettingsUseCase,
        exportDataUseCase: ExportDataUseCase,
        clearAllDataUseCase: ClearAllDataUseCase
    ) {
        self.manageSettingsUseCase = manageSettingsUseCase
        self.exportDataUseCase = exportDataUseCase
        self.clearAllDataUseCase = clearAllDataUseCase
        super.init()
        setupBindings()
        loadSettings()
    }
    
    // MARK: - Public Methods
    
    func loadSettings() {
        Task {
            await executeWithLoading { [weak self] in
                guard let self = self else { return }
                let settings = try await self.manageSettingsUseCase.getSettings()
                self.settings = settings
                self.originalSettings = settings
                self.updatePublishedProperties(from: settings)
            }
        }
    }
    
    func saveAllSettings() {
        Task {
            await executeWithLoading { [weak self] in
                guard let self = self else { return }
                
                let updatedSettings = Settings(
                    remindersEnabled: self.remindersEnabled,
                    analyticsEnabled: self.analyticsEnabled,
                    reminderInterval: self.reminderInterval,
                    reminderTime: self.reminderTime,
                    overdueReminderEnabled: self.overdueReminderEnabled,
                    exportFormat: self.exportFormat,
                    includeContextInExport: self.includeContextInExport,
                    autoBackupEnabled: self.autoBackupEnabled,
                    backupFrequency: self.backupFrequency,
                    contextTrackingEnabled: self.contextTrackingEnabled,
                    trackMood: self.trackMood,
                    trackPressure: self.trackPressure,
                    trackSleep: self.trackSleep,
                    trackStress: self.trackStress,
                    trackEnvironment: self.trackEnvironment,
                    trackTiming: self.trackTiming,
                    defaultTimeframe: self.defaultTimeframe,
                    showConfidenceInList: self.showConfidenceInList,
                    groupPredictionsByType: self.groupPredictionsByType,
                    showAccuracyTrends: self.showAccuracyTrends,
                    requireConfirmationForDataClear: self.requireConfirmationForDataClear,
                    autoResolveOverduePredictions: self.autoResolveOverduePredictions,
                    autoResolveAfterDays: self.autoResolveAfterDays
                )
                
                // Use the manage settings use case to update all settings
                let _ = try await self.manageSettingsUseCase.updateSettings(updatedSettings)
                
                self.settings = updatedSettings
                self.originalSettings = updatedSettings
                self.hasUnsavedChanges = false
            }
        }
    }
    
    func updateReminders(_ enabled: Bool) {
        remindersEnabled = enabled
        saveAllSettings()
    }
    
    func updateAnalytics(_ enabled: Bool) {
        analyticsEnabled = enabled
        saveAllSettings()
    }
    
    func resetToDefaults() {
        Task {
            await executeWithLoading { [weak self] in
                guard let self = self else { return }
                let defaultSettings = try await self.manageSettingsUseCase.resetToDefaults()
                self.settings = defaultSettings
                self.originalSettings = defaultSettings
                self.updatePublishedProperties(from: defaultSettings)
            }
        }
    }
    
    func exportData() async -> URL? {
        return await withCheckedContinuation { continuation in
            Task {
                do {
                    isExporting = true
                    exportProgress = 0.1
                    
                    let exportData: Data
                    switch exportFormat {
                    case .json:
                        exportData = try await exportDataUseCase.executeAsJSON()
                    case .csv:
                        exportData = try await exportDataUseCase.executeAsCSV()
                    case .text:
                        // Convert to text format
                        let jsonData = try await exportDataUseCase.executeAsJSON()
                        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
                        exportData = jsonString.data(using: .utf8) ?? Data()
                    }
                    
                    exportProgress = 0.7
                    
                    // Create temporary file
                    let tempDir = FileManager.default.temporaryDirectory
                    let fileName = "delphi_export_\(Date().timeIntervalSince1970).\(exportFormat.fileExtension)"
                    let fileURL = tempDir.appendingPathComponent(fileName)
                    
                    try exportData.write(to: fileURL)
                    exportProgress = 1.0
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isExporting = false
                        self.exportProgress = 0.0
                    }
                    
                    continuation.resume(returning: fileURL)
                } catch {
                    self.error = error
                    self.isExporting = false
                    self.exportProgress = 0.0
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func deleteAllData() async -> Bool {
        guard requireConfirmationForDataClear else {
            return await performDataDeletion()
        }
        
        showDeleteConfirmation = true
        return false // Will be handled by confirmation dialog
    }
    
    func confirmDeleteAllData() async -> Bool {
        showDeleteConfirmation = false
        return await performDataDeletion()
    }
    
    func cancelDeleteAllData() {
        showDeleteConfirmation = false
    }
    
    // MARK: - Private Methods
    
    private func performDataDeletion() async -> Bool {
        return await withCheckedContinuation { continuation in
            Task {
                do {
                    try await clearAllDataUseCase.execute()
                    continuation.resume(returning: true)
                } catch {
                    self.error = error
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func setupBindings() {
        // Simple approach: check for changes whenever any published property changes
        // Combine all boolean settings
        Publishers.CombineLatest4($remindersEnabled, $analyticsEnabled, $contextTrackingEnabled, $trackMood)
            .combineLatest(Publishers.CombineLatest4($trackPressure, $trackSleep, $trackStress, $trackEnvironment))
            .combineLatest($settings)
            .map { [weak self] _, _ in
                guard let self = self, let original = self.originalSettings else { return false }
                
                return self.hasAnyChanges(from: original)
            }
            .assign(to: &$hasUnsavedChanges)
    }
    
    private func hasAnyChanges(from original: Settings) -> Bool {
        return remindersEnabled != original.remindersEnabled ||
               analyticsEnabled != original.analyticsEnabled ||
               reminderInterval != original.reminderInterval ||
               overdueReminderEnabled != original.overdueReminderEnabled ||
               exportFormat != original.exportFormat ||
               includeContextInExport != original.includeContextInExport ||
               autoBackupEnabled != original.autoBackupEnabled ||
               backupFrequency != original.backupFrequency ||
               contextTrackingEnabled != original.contextTrackingEnabled ||
               trackMood != original.trackMood ||
               trackPressure != original.trackPressure ||
               trackSleep != original.trackSleep ||
               trackStress != original.trackStress ||
               trackEnvironment != original.trackEnvironment ||
               trackTiming != original.trackTiming ||
               defaultTimeframe != original.defaultTimeframe ||
               showConfidenceInList != original.showConfidenceInList ||
               groupPredictionsByType != original.groupPredictionsByType ||
               showAccuracyTrends != original.showAccuracyTrends ||
               requireConfirmationForDataClear != original.requireConfirmationForDataClear ||
               autoResolveOverduePredictions != original.autoResolveOverduePredictions ||
               autoResolveAfterDays != original.autoResolveAfterDays
    }
    
    private func updatePublishedProperties(from settings: Settings) {
        remindersEnabled = settings.remindersEnabled
        analyticsEnabled = settings.analyticsEnabled
        reminderInterval = settings.reminderInterval
        reminderTime = settings.reminderTime
        overdueReminderEnabled = settings.overdueReminderEnabled
        exportFormat = settings.exportFormat
        includeContextInExport = settings.includeContextInExport
        autoBackupEnabled = settings.autoBackupEnabled
        backupFrequency = settings.backupFrequency
        contextTrackingEnabled = settings.contextTrackingEnabled
        trackMood = settings.trackMood
        trackPressure = settings.trackPressure
        trackSleep = settings.trackSleep
        trackStress = settings.trackStress
        trackEnvironment = settings.trackEnvironment
        trackTiming = settings.trackTiming
        defaultTimeframe = settings.defaultTimeframe
        showConfidenceInList = settings.showConfidenceInList
        groupPredictionsByType = settings.groupPredictionsByType
        showAccuracyTrends = settings.showAccuracyTrends
        requireConfirmationForDataClear = settings.requireConfirmationForDataClear
        autoResolveOverduePredictions = settings.autoResolveOverduePredictions
        autoResolveAfterDays = settings.autoResolveAfterDays
    }
}