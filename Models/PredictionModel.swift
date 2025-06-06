import Foundation
import SwiftData

// MARK: - Event Type Enum
enum EventType: String, CaseIterable, Identifiable, Codable {
  case boolean = "boolean"
  case numeric = "numeric"

  var id: Self { self }

  var displayName: String {
    switch self {
    case .boolean:
      return "Yes/No"
    case .numeric:
      return "Numeric"
    }
  }
}

// MARK: - Prediction Model
@Model
final class Prediction: Identifiable {

  // MARK: - Core Properties
  @Attribute(.unique) var id: UUID
  var eventName: String
  var eventDescription: String
  var confidenceLevel: Double
  var estimatedValue: String
  var booleanValue: String
  var pressureLevel: String
  var currentMood: String
  var takesMedicine: String
  var evidenceList: [String]
  var selectedType: EventType

  // MARK: - Date Properties
  var dateCreated: Date
  var dueDate: Date
  var resolutionDate: Date?

  // MARK: - Status Properties
  var isPending: Bool
  var isResolved: Bool
  var actualOutcome: String?

  // MARK: - Initialization
  init(
    eventName: String,
    eventDescription: String,
    confidenceLevel: Double,
    estimatedValue: String,
    booleanValue: String,
    pressureLevel: String,
    currentMood: String,
    takesMedicine: String,
    evidenceList: [String],
    selectedType: EventType,
    dueDate: Date
  ) {
    // Validate inputs
    precondition(
      !eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      "Event name cannot be empty"
    )
    precondition(
      !eventDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      "Event description cannot be empty"
    )
    precondition(
      confidenceLevel >= 0 && confidenceLevel <= 100,
      "Confidence level must be between 0 and 100"
    )

    self.id = UUID()
    self.eventName = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
    self.eventDescription = eventDescription.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    self.confidenceLevel = confidenceLevel
    self.estimatedValue = estimatedValue
    self.booleanValue = booleanValue
    self.pressureLevel = pressureLevel
    self.currentMood = currentMood
    self.takesMedicine = takesMedicine
    self.evidenceList = evidenceList.filter {
      !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    self.selectedType = selectedType
    self.dueDate = dueDate
    self.dateCreated = Date()
    self.isPending = dueDate > Date()
    self.isResolved = false
    self.actualOutcome = nil
    self.resolutionDate = nil
  }
}

// MARK: - Computed Properties
extension Prediction {

  /// Returns true if the prediction is overdue (past due date and not resolved)
  var isOverdue: Bool {
    dueDate < Date() && !isResolved
  }

  /// Returns the number of days until due date (negative if overdue)
  var daysToDue: Int {
    Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
  }

  /// Returns the number of days since creation
  var daysSinceCreated: Int {
    Calendar.current.dateComponents([.day], from: dateCreated, to: Date()).day
      ?? 0
  }

  /// Returns the number of days it took to resolve (if resolved)
  var daysToResolve: Int? {
    guard let resolutionDate = resolutionDate else { return nil }
    return Calendar.current.dateComponents(
      [.day],
      from: dateCreated,
      to: resolutionDate
    ).day
  }

  /// Returns a formatted due date string
  var formattedDueDate: String {
    DateFormatter.mediumDate.string(from: dueDate)
  }

  /// Returns a formatted creation date string
  var formattedCreationDate: String {
    DateFormatter.mediumDate.string(from: dateCreated)
  }

  /// Returns a formatted resolution date string (if resolved)
  var formattedResolutionDate: String? {
    guard let resolutionDate = resolutionDate else { return nil }
    return DateFormatter.mediumDate.string(from: resolutionDate)
  }

  /// Returns the prediction status as a readable string
  var statusDescription: String {
    if isResolved {
      return "Resolved"
    } else if isOverdue {
      return "Overdue"
    } else if isPending {
      return "Pending"
    } else {
      return "Unknown"
    }
  }

  /// Returns whether the prediction was correct (only meaningful if resolved)
  var wasCorrect: Bool? {
    guard isResolved, let outcome = actualOutcome else { return nil }

    switch selectedType {
    case .boolean:
      return outcome == booleanValue
    case .numeric:
      return outcome == estimatedValue
    }
  }

  /// Returns the confidence level as a percentage string
  var confidencePercentage: String {
    return String(format: "%.1f%%", confidenceLevel)
  }

  /// Returns the primary predicted value based on type
  var primaryPredictedValue: String {
    switch selectedType {
    case .boolean:
      return booleanValue
    case .numeric:
      return estimatedValue
    }
  }
}

// MARK: - Validation Methods
extension Prediction {

  /// Validates the prediction data
  func validate() -> [String] {
    var errors: [String] = []

    if eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      errors.append("Event name is required")
    }

    if eventDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      errors.append("Event description is required")
    }

    if confidenceLevel < 0 || confidenceLevel > 100 {
      errors.append("Confidence level must be between 0 and 100")
    }

    if selectedType == .numeric
      && estimatedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      errors.append("Estimated value is required for numeric predictions")
    }

    return errors
  }

  /// Returns true if the prediction data is valid
  var isValid: Bool {
    return validate().isEmpty
  }
}

// MARK: - Update Methods
extension Prediction {

  /// Updates the pending status based on current date
  func updatePendingStatus() {
    if !isResolved {
      isPending = dueDate > Date()
    }
  }

  /// Resolves the prediction with the given outcome
  func resolve(with outcome: String) {
    guard !isResolved else { return }

    actualOutcome = outcome
    isResolved = true
    isPending = false
    resolutionDate = Date()
  }
}
