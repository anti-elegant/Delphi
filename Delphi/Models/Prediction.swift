import Foundation
import SwiftData

// MARK: - Event Type Enum
enum EventType: String, CaseIterable, Identifiable, Codable, Sendable {
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
  private var evidenceData: String = ""
  var selectedType: EventType

  // MARK: - Date Properties
  var dateCreated: Date
  var dueDate: Date
  var resolutionDate: Date?

  // MARK: - Status Properties
  var isPending: Bool
  var isResolved: Bool
  var actualOutcome: String?
  var lastModified: Date

  // MARK: - Evidence List Computed Property
  var evidenceList: [String] {
    get {
      guard !evidenceData.isEmpty else { return [] }
      return evidenceData.components(separatedBy: "|||")
        .map { $0.replacingOccurrences(of: "||PIPE||", with: "||") }
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    set {
      evidenceData =
        newValue
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .map { $0.replacingOccurrences(of: "||", with: "||PIPE||") }
        .joined(separator: "|||")
    }
  }

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
    self.evidenceData =
      evidenceList
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .map { $0.replacingOccurrences(of: "||", with: "||PIPE||") }
      .joined(separator: "|||")
    self.selectedType = selectedType
    self.dueDate = dueDate
    self.dateCreated = Date()
    self.isPending = dueDate > Date()
    self.isResolved = false
    self.actualOutcome = nil
    self.resolutionDate = nil
    self.lastModified = Date()
  }
}

// MARK: - Computed Properties
extension Prediction {

  var isOverdue: Bool {
    dueDate < Date() && !isResolved
  }

  var daysToDue: Int {
    Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
  }

  var formattedDueDate: String {
    DateFormatter.mediumDate.string(from: dueDate)
  }

  var formattedCreationDate: String {
    DateFormatter.mediumDate.string(from: dateCreated)
  }

  var formattedResolutionDate: String? {
    guard let resolutionDate = resolutionDate else { return nil }
    return DateFormatter.mediumDate.string(from: resolutionDate)
  }

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

  var wasCorrect: Bool? {
    guard isResolved, let outcome = actualOutcome else { return nil }
    switch selectedType {
    case .boolean: return outcome == booleanValue
    case .numeric: return outcome == estimatedValue
    }
  }

}

// MARK: - Update Methods
extension Prediction {

  func updatePendingStatus() {
    if !isResolved {
      isPending = dueDate > Date()
      lastModified = Date()
    }
  }

  func resolve(with outcome: String) {
    guard !isResolved else { return }
    actualOutcome = outcome
    isResolved = true
    isPending = false
    resolutionDate = Date()
    lastModified = Date()
  }
}
