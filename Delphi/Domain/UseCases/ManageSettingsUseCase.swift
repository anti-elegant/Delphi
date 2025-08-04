import Foundation

// MARK: - Manage Settings Use Case
protocol ManageSettingsUseCase {
  func getSettings() async throws -> Settings
  func updateSettings(_ settings: Settings) async throws -> Settings
  func updateReminders(_ enabled: Bool) async throws -> Settings
  func updateAnalytics(_ enabled: Bool) async throws -> Settings
  func resetToDefaults() async throws -> Settings
}

// MARK: - Export Data Use Case
protocol ExportDataUseCase {
  func execute() async throws -> ExportData
  func executeAsJSON() async throws -> Data
  func executeAsCSV() async throws -> Data
}

// MARK: - Export Data
struct ExportData: Codable {
  let predictions: [Prediction]
  let settings: Settings
  let accuracyMetric: AccuracyMetric
  let exportedAt: Date
  let appVersion: String
  
  init(
    predictions: [Prediction],
    settings: Settings,
    accuracyMetric: AccuracyMetric,
    exportedAt: Date = Date(),
    appVersion: String = "1.0.0"
  ) {
    self.predictions = predictions
    self.settings = settings
    self.accuracyMetric = accuracyMetric
    self.exportedAt = exportedAt
    self.appVersion = appVersion
  }
}

// MARK: - Settings Management Error
enum SettingsManagementError: LocalizedError {
  case loadFailed(Error)
  case saveFailed(Error)
  case resetFailed(Error)
  case exportFailed(Error)
  
  var errorDescription: String? {
    switch self {
    case .loadFailed(let error):
      return "Failed to load settings: \(error.localizedDescription)"
    case .saveFailed(let error):
      return "Failed to save settings: \(error.localizedDescription)"
    case .resetFailed(let error):
      return "Failed to reset settings: \(error.localizedDescription)"
    case .exportFailed(let error):
      return "Failed to export data: \(error.localizedDescription)"
    }
  }
}

// MARK: - Default Settings Management Implementation
final class DefaultManageSettingsUseCase: ManageSettingsUseCase {
  private let repository: SettingsRepositoryProtocol
  
  init(repository: SettingsRepositoryProtocol) {
    self.repository = repository
  }
  
  func getSettings() async throws -> Settings {
    do {
      return try await repository.getSettings()
    } catch {
      throw SettingsManagementError.loadFailed(error)
    }
  }
  
  func updateSettings(_ settings: Settings) async throws -> Settings {
    do {
      try await repository.updateSettings(settings)
      return settings
    } catch {
      throw SettingsManagementError.saveFailed(error)
    }
  }
  
  func updateReminders(_ enabled: Bool) async throws -> Settings {
    do {
      let currentSettings = try await repository.getSettings()
      let updatedSettings = currentSettings.withReminders(enabled)
      try await repository.updateSettings(updatedSettings)
      return updatedSettings
    } catch {
      throw SettingsManagementError.saveFailed(error)
    }
  }
  
  func updateAnalytics(_ enabled: Bool) async throws -> Settings {
    do {
      let currentSettings = try await repository.getSettings()
      let updatedSettings = currentSettings.withAnalytics(enabled)
      try await repository.updateSettings(updatedSettings)
      return updatedSettings
    } catch {
      throw SettingsManagementError.saveFailed(error)
    }
  }
  
  func resetToDefaults() async throws -> Settings {
    do {
      try await repository.resetToDefaults()
      return try await repository.getSettings()
    } catch {
      throw SettingsManagementError.resetFailed(error)
    }
  }
}

// MARK: - Default Export Data Implementation
final class DefaultExportDataUseCase: ExportDataUseCase {
  private let predictionRepository: PredictionRepositoryProtocol
  private let settingsRepository: SettingsRepositoryProtocol
  private let accuracyUseCase: CalculateAccuracyUseCase
  
  init(
    predictionRepository: PredictionRepositoryProtocol,
    settingsRepository: SettingsRepositoryProtocol,
    accuracyUseCase: CalculateAccuracyUseCase
  ) {
    self.predictionRepository = predictionRepository
    self.settingsRepository = settingsRepository
    self.accuracyUseCase = accuracyUseCase
  }
  
  func execute() async throws -> ExportData {
    do {
      let predictions = try await predictionRepository.getAll()
      let settings = try await settingsRepository.getSettings()
      let accuracyMetric = try await accuracyUseCase.execute()
      
      return ExportData(
        predictions: predictions,
        settings: settings,
        accuracyMetric: accuracyMetric
      )
    } catch {
      throw SettingsManagementError.exportFailed(error)
    }
  }
  
  func executeAsJSON() async throws -> Data {
    do {
      let exportData = try await execute()
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      return try encoder.encode(exportData)
    } catch {
      throw SettingsManagementError.exportFailed(error)
    }
  }
  
  func executeAsCSV() async throws -> Data {
    do {
      let exportData = try await execute()
      let csvContent = createCSVContent(from: exportData)
      guard let csvData = csvContent.data(using: .utf8) else {
        throw SettingsManagementError.exportFailed(NSError(domain: "CSV", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert CSV to data"]))
      }
      return csvData
    } catch {
      throw SettingsManagementError.exportFailed(error)
    }
  }
  
  private func createCSVContent(from exportData: ExportData) -> String {
    var csv = "ID,Title,Description,Type,Confidence,Expected Value,Evidence,Created At,Due Date,Resolved At,Actual Value,Is Correct,Status\n"
    
    for prediction in exportData.predictions {
      let evidenceString = prediction.evidence.joined(separator: "; ")
      let isCorrectString = prediction.isCorrect?.description ?? "N/A"
      let resolvedAtString = prediction.resolvedAt?.description ?? ""
      let actualValueString = prediction.actualValue ?? ""
      
      csv += "\"\(prediction.id)\","
      csv += "\"\(prediction.title)\","
      csv += "\"\(prediction.description)\","
      csv += "\"\(prediction.type.displayName)\","
      csv += "\(prediction.confidence),"
      csv += "\"\(prediction.expectedValue)\","
      csv += "\"\(evidenceString)\","
      csv += "\"\(prediction.createdAt)\","
      csv += "\"\(prediction.dueDate)\","
      csv += "\"\(resolvedAtString)\","
      csv += "\"\(actualValueString)\","
      csv += "\"\(isCorrectString)\","
      csv += "\"\(prediction.status.displayName)\"\n"
    }
    
    return csv
  }
}

// MARK: - Clear All Data Use Case
protocol ClearAllDataUseCase {
  func execute() async throws
}

// MARK: - Default Clear All Data Implementation
final class DefaultClearAllDataUseCase: ClearAllDataUseCase {
  private let predictionRepository: PredictionRepositoryProtocol
  private let settingsRepository: SettingsRepositoryProtocol
  
  init(
    predictionRepository: PredictionRepositoryProtocol,
    settingsRepository: SettingsRepositoryProtocol
  ) {
    self.predictionRepository = predictionRepository
    self.settingsRepository = settingsRepository
  }
  
  func execute() async throws {
    do {
      // Delete all predictions first
      try await predictionRepository.deleteAll()
      
      // Reset settings to defaults
      try await settingsRepository.resetToDefaults()
    } catch {
      throw SettingsManagementError.resetFailed(error)
    }
  }
}
