import Foundation

// MARK: - App Configuration
struct AppConfiguration {
  static let shared = AppConfiguration()
  
  // MARK: - App Info
  let appName: String
  let appVersion: String
  let buildNumber: String
  
  // MARK: - Feature Flags
  let isAnalyticsEnabled: Bool
  let isExportEnabled: Bool
  let isNotificationsEnabled: Bool
  
  // MARK: - Data Configuration
  let maxPredictionsCount: Int
  let maxEvidenceCount: Int
  let maxExportSize: Int // in MB
  
  // MARK: - UI Configuration
  let animationDuration: TimeInterval
  let debounceDelay: TimeInterval
  
  // MARK: - Validation Configuration
  let minConfidenceLevel: Double
  let maxConfidenceLevel: Double
  let maxTitleLength: Int
  let maxDescriptionLength: Int
  let maxEvidenceLength: Int
  
  // MARK: - Initialization
  private init() {
    // App Info
    self.appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Delphi"
    self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    // Feature Flags
    self.isAnalyticsEnabled = true
    self.isExportEnabled = true
    self.isNotificationsEnabled = true
    
    // Data Configuration
    self.maxPredictionsCount = 1000
    self.maxEvidenceCount = 10
    self.maxExportSize = 50 // 50MB
    
    // UI Configuration
    self.animationDuration = 0.3
    self.debounceDelay = 0.5
    
    // Validation Configuration
    self.minConfidenceLevel = 0.0
    self.maxConfidenceLevel = 100.0
    self.maxTitleLength = 100
    self.maxDescriptionLength = 500
    self.maxEvidenceLength = 200
  }
}

// MARK: - Environment Detection
extension AppConfiguration {
  var isDebug: Bool {
    #if DEBUG
    return true
    #else
    return false
    #endif
  }
  
  var isTestEnvironment: Bool {
    NSClassFromString("XCTestCase") != nil
  }
  
  var isSimulator: Bool {
    #if targetEnvironment(simulator)
    return true
    #else
    return false
    #endif
  }
}

// MARK: - Logging Configuration
extension AppConfiguration {
  var shouldLogErrors: Bool {
    isDebug || isTestEnvironment
  }
  
  var shouldLogAnalytics: Bool {
    !isTestEnvironment && isAnalyticsEnabled
  }
  
  var logLevel: LogLevel {
    if isDebug {
      return .verbose
    } else if isTestEnvironment {
      return .warning
    } else {
      return .error
    }
  }
}

// MARK: - Log Level
enum LogLevel: Int, CaseIterable {
  case verbose = 0
  case info = 1
  case warning = 2
  case error = 3
  
  var description: String {
    switch self {
    case .verbose:
      return "VERBOSE"
    case .info:
      return "INFO"
    case .warning:
      return "WARNING"
    case .error:
      return "ERROR"
    }
  }
}

// MARK: - Validation Helpers
extension AppConfiguration {
  func validateTitle(_ title: String) -> Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
    title.count <= maxTitleLength
  }
  
  func validateDescription(_ description: String) -> Bool {
    !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
    description.count <= maxDescriptionLength
  }
  
  func validateConfidence(_ confidence: Double) -> Bool {
    confidence >= minConfidenceLevel && confidence <= maxConfidenceLevel
  }
  
  func validateEvidence(_ evidence: String) -> Bool {
    !evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
    evidence.count <= maxEvidenceLength
  }
  
  func validateEvidenceList(_ evidenceList: [String]) -> Bool {
    evidenceList.count <= maxEvidenceCount &&
    evidenceList.allSatisfy { validateEvidence($0) }
  }
}

// MARK: - Export Configuration
extension AppConfiguration {
  var supportedExportFormats: [ExportFormat] {
    guard isExportEnabled else { return [] }
    return [.json, .csv]
  }
  
  enum ExportFormat: String, CaseIterable {
    case json = "json"
    case csv = "csv"
    
    var fileExtension: String {
      rawValue
    }
    
    var mimeType: String {
      switch self {
      case .json:
        return "application/json"
      case .csv:
        return "text/csv"
      }
    }
    
    var displayName: String {
      switch self {
      case .json:
        return "JSON"
      case .csv:
        return "CSV"
      }
    }
  }
}

// MARK: - App State
extension AppConfiguration {
  var appDisplayName: String {
    "\(appName) v\(appVersion)"
  }
  
  var fullVersionString: String {
    "\(appVersion) (\(buildNumber))"
  }
  
  var userAgent: String {
    "\(appName)/\(appVersion) iOS"
  }
}
