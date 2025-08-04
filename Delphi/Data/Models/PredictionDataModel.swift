import Foundation
import SwiftData

// MARK: - Prediction Data Model for SwiftData
@Model
final class PredictionDataModel {
  // MARK: - Core Properties
  @Attribute(.unique) var id: UUID
  var title: String
  var predictionDescription: String
  var type: String // PredictionType raw value
  var confidence: Double
  var expectedValue: String
  private var evidenceData: String = ""
  private var contextData: String = ""
  
  // MARK: - Dates
  var createdAt: Date
  var dueDate: Date
  var resolvedAt: Date?
  
  // MARK: - Resolution
  var actualValue: String?
  
  // MARK: - Evidence List Computed Property
  var evidence: [String] {
    get {
      guard !evidenceData.isEmpty else { return [] }
      return evidenceData.components(separatedBy: "|||")
        .map { $0.replacingOccurrences(of: "||PIPE||", with: "||") }
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    set {
      evidenceData = newValue
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .map { $0.replacingOccurrences(of: "||", with: "||PIPE||") }
        .joined(separator: "|||")
    }
  }
  
  // MARK: - Context Computed Property
  var context: PredictionContext {
    get {
      guard !contextData.isEmpty else { return PredictionContext.empty }
      guard let data = contextData.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(PredictionContext.self, from: data) else {
        return PredictionContext.empty
      }
      return decoded
    }
    set {
      guard let data = try? JSONEncoder().encode(newValue),
            let string = String(data: data, encoding: .utf8) else {
        contextData = ""
        return
      }
      contextData = string
    }
  }
  
  // MARK: - Initialization
  init(
    id: UUID = UUID(),
    title: String,
    predictionDescription: String,
    type: String,
    confidence: Double,
    expectedValue: String,
    context: PredictionContext = .empty,
    evidence: [String] = [],
    createdAt: Date = Date(),
    dueDate: Date,
    resolvedAt: Date? = nil,
    actualValue: String? = nil
  ) {
    self.id = id
    self.title = title
    self.predictionDescription = predictionDescription
    self.type = type
    self.confidence = confidence
    self.expectedValue = expectedValue
    self.createdAt = createdAt
    self.dueDate = dueDate
    self.resolvedAt = resolvedAt
    self.actualValue = actualValue
    
    // Set evidence and context using the computed properties
    self.context = context
    self.evidence = evidence
  }
}

// MARK: - Domain Conversion
extension PredictionDataModel {
  /// Convert from domain entity to data model
  static func from(domain: Prediction) -> PredictionDataModel {
    PredictionDataModel(
      id: domain.id,
      title: domain.title,
      predictionDescription: domain.description,
      type: domain.type.rawValue,
      confidence: domain.confidence,
      expectedValue: domain.expectedValue,
      context: domain.context,
      evidence: domain.evidence,
      createdAt: domain.createdAt,
      dueDate: domain.dueDate,
      resolvedAt: domain.resolvedAt,
      actualValue: domain.actualValue
    )
  }
  
  /// Convert from data model to domain entity
  func toDomain() -> Prediction? {
    guard let predictionType = PredictionType(rawValue: type) else {
      return nil
    }
    
    return Prediction(
      id: id,
      title: title,
      description: predictionDescription,
      type: predictionType,
      confidence: confidence,
      expectedValue: expectedValue,
      context: context,
      evidence: evidence,
      createdAt: createdAt,
      dueDate: dueDate,
      resolvedAt: resolvedAt,
      actualValue: actualValue
    )
  }
}

// MARK: - Query Helpers
extension PredictionDataModel {
  static func allPredictions() -> FetchDescriptor<PredictionDataModel> {
    FetchDescriptor<PredictionDataModel>(
      sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
  }
  
  static func pendingPredictions() -> FetchDescriptor<PredictionDataModel> {
    let now = Date()
    return FetchDescriptor<PredictionDataModel>(
      predicate: #Predicate { prediction in
        prediction.resolvedAt == nil && prediction.dueDate > now
      },
      sortBy: [SortDescriptor(\.dueDate, order: .forward)]
    )
  }
  
  static func overduePredictions() -> FetchDescriptor<PredictionDataModel> {
    let now = Date()
    return FetchDescriptor<PredictionDataModel>(
      predicate: #Predicate { prediction in
        prediction.resolvedAt == nil && prediction.dueDate <= now
      },
      sortBy: [SortDescriptor(\.dueDate, order: .reverse)]
    )
  }
  
  static func resolvedPredictions() -> FetchDescriptor<PredictionDataModel> {
    FetchDescriptor<PredictionDataModel>(
      predicate: #Predicate { $0.resolvedAt != nil },
      sortBy: [SortDescriptor(\.resolvedAt, order: .reverse)]
    )
  }
  
  static func predictionById(_ id: UUID) -> FetchDescriptor<PredictionDataModel> {
    FetchDescriptor<PredictionDataModel>(
      predicate: #Predicate { $0.id == id }
    )
  }
}
