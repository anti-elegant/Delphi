import Foundation

// MARK: - Prediction Domain Entity
struct Prediction {
  // MARK: - Core Properties
  let id: UUID
  let title: String
  let description: String
  let type: PredictionType
  let confidence: Double // 0-100
  let expectedValue: String
  
  // MARK: - Context & Evidence
  let context: PredictionContext
  let evidence: [String] // Legacy support - will be migrated to context.allEvidence
  
  // MARK: - Dates
  let createdAt: Date
  let dueDate: Date
  let resolvedAt: Date?
  
  // MARK: - Resolution
  let actualValue: String?
  
  // MARK: - Computed Properties for Compatibility
  var targetDate: Date {
    dueDate
  }
  
  // MARK: - Enhanced Computed Properties
  /// Combined evidence from both legacy evidence array and context
  var allEvidence: [String] {
    var combined = evidence // Legacy evidence
    combined.append(contentsOf: context.allEvidence) // Context evidence
    return combined.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  }
  
  /// Check if prediction has any context information
  var hasContext: Bool {
    !context.isEmpty
  }
  
  /// Check if prediction has health-related context
  var hasHealthContext: Bool {
    context.hasHealthContext
  }
  
  /// Check if prediction has environmental context
  var hasEnvironmentalContext: Bool {
    context.hasEnvironmentalContext
  }
  
  /// Check if prediction has timing context
  var hasTimingContext: Bool {
    context.hasTimingContext
  }
  
  // MARK: - Core Computed Properties
  var status: PredictionStatus {
    if let _ = resolvedAt {
      return .resolved
    } else if dueDate < Date() {
      return .overdue
    } else {
      return .pending
    }
  }
  
  var isCorrect: Bool? {
    guard let actualValue = actualValue else { return nil }
    return expectedValue.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ==
           actualValue.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  var isOverdue: Bool {
    status == .overdue
  }
  
  var isResolved: Bool {
    status == .resolved
  }
  
  var isPending: Bool {
    status == .pending
  }
  
  var daysToDue: Int {
    Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
  }
  
  var daysUntilDue: String {
    let days = daysToDue
    if days < 0 {
      return "Overdue by \(abs(days)) day\(abs(days) == 1 ? "" : "s")"
    } else if days == 0 {
      return "Due today"
    } else {
      return "Due in \(days) day\(days == 1 ? "" : "s")"
    }
  }
}

// MARK: - Methods
extension Prediction {
  /// Create a resolved prediction
  func resolved(with actualValue: String, at date: Date = Date()) -> Prediction {
    Prediction(
      id: id,
      title: title,
      description: description,
      type: type,
      confidence: confidence,
      expectedValue: expectedValue,
      context: context,
      evidence: evidence,
      createdAt: createdAt,
      dueDate: dueDate,
      resolvedAt: date,
      actualValue: actualValue
    )
  }
  
  /// Update prediction with new evidence (legacy support)
  func withEvidence(_ newEvidence: [String]) -> Prediction {
    Prediction(
      id: id,
      title: title,
      description: description,
      type: type,
      confidence: confidence,
      expectedValue: expectedValue,
      context: context,
      evidence: newEvidence,
      createdAt: createdAt,
      dueDate: dueDate,
      resolvedAt: resolvedAt,
      actualValue: actualValue
    )
  }
  
  /// Update prediction with new context
  func withContext(_ newContext: PredictionContext) -> Prediction {
    Prediction(
      id: id,
      title: title,
      description: description,
      type: type,
      confidence: confidence,
      expectedValue: expectedValue,
      context: newContext,
      evidence: evidence,
      createdAt: createdAt,
      dueDate: dueDate,
      resolvedAt: resolvedAt,
      actualValue: actualValue
    )
  }
  
  /// Migrate legacy evidence to context for backward compatibility
  func withMigratedEvidence() -> Prediction {
    let migratedContext = context.isEmpty ?
      PredictionContext.fromLegacyEvidence(evidence) : context
    
    return Prediction(
      id: id,
      title: title,
      description: description,
      type: type,
      confidence: confidence,
      expectedValue: expectedValue,
      context: migratedContext,
      evidence: [], // Clear legacy evidence after migration
      createdAt: createdAt,
      dueDate: dueDate,
      resolvedAt: resolvedAt,
      actualValue: actualValue
    )
  }
}

// MARK: - Factory Methods
extension Prediction {
  /// Create prediction with context (new way)
  static func create(
    id: UUID = UUID(),
    title: String,
    description: String,
    type: PredictionType,
    confidence: Double,
    expectedValue: String,
    context: PredictionContext,
    dueDate: Date,
    createdAt: Date = Date()
  ) throws -> Prediction {
    let prediction = Prediction(
      id: id,
      title: title,
      description: description,
      type: type,
      confidence: confidence,
      expectedValue: expectedValue,
      context: context,
      evidence: [],
      createdAt: createdAt,
      dueDate: dueDate,
      resolvedAt: nil,
      actualValue: nil
    )
    
    try prediction.validate()
    try Prediction.validateCreation(dueDate: dueDate)
    
    return prediction
  }
  
  /// Create prediction with evidence (legacy support)
  static func createLegacy(
    id: UUID = UUID(),
    title: String,
    description: String,
    type: PredictionType,
    confidence: Double,
    expectedValue: String,
    evidence: [String],
    dueDate: Date,
    createdAt: Date = Date()
  ) throws -> Prediction {
    let prediction = Prediction(
      id: id,
      title: title,
      description: description,
      type: type,
      confidence: confidence,
      expectedValue: expectedValue,
      context: PredictionContext.fromLegacyEvidence(evidence),
      evidence: evidence,
      createdAt: createdAt,
      dueDate: dueDate,
      resolvedAt: nil,
      actualValue: nil
    )
    
    try prediction.validate()
    try Prediction.validateCreation(dueDate: dueDate)
    
    return prediction
  }
}

// MARK: - Protocol Conformances
extension Prediction: Identifiable {}

extension Prediction: Equatable {
  static func == (lhs: Prediction, rhs: Prediction) -> Bool {
    lhs.id == rhs.id
  }
}

extension Prediction: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

extension Prediction: Codable {}

// MARK: - Validation
extension Prediction {
  enum ValidationError: LocalizedError {
    case emptyTitle
    case emptyDescription
    case invalidConfidence
    case emptyExpectedValue
    case futureDueDate
    case invalidContext
    
    var errorDescription: String? {
      switch self {
      case .emptyTitle:
        return "Title cannot be empty"
      case .emptyDescription:
        return "Description cannot be empty"
      case .invalidConfidence:
        return "Confidence must be between 0 and 100"
      case .emptyExpectedValue:
        return "Expected value cannot be empty"
      case .futureDueDate:
        return "Due date must be in the future"
      case .invalidContext:
        return "Prediction context contains invalid data"
      }
    }
  }
  
  func validate() throws {
    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw ValidationError.emptyTitle
    }
    
    guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw ValidationError.emptyDescription
    }
    
    guard confidence >= 0 && confidence <= 100 else {
      throw ValidationError.invalidConfidence
    }
    
    guard !expectedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw ValidationError.emptyExpectedValue
    }
    
    // Validate context
    do {
      try context.validate()
    } catch {
      throw ValidationError.invalidContext
    }
  }
  
  static func validateCreation(dueDate: Date) throws {
    guard dueDate > Date() else {
      throw ValidationError.futureDueDate
    }
  }
}

// MARK: - Formatting Extensions
extension Prediction {
  var formattedDueDate: String {
    dueDate.formatted(date: .abbreviated, time: .omitted)
  }
  
  var formattedCreatedDate: String {
    createdAt.formatted(date: .abbreviated, time: .omitted)
  }
  
  var formattedResolvedDate: String? {
    guard let resolvedAt = resolvedAt else { return nil }
    return resolvedAt.formatted(date: .abbreviated, time: .omitted)
  }
  
  var formattedConfidence: String {
    "\(Int(confidence))%"
  }
}

