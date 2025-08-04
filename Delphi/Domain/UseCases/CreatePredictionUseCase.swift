import Foundation

// MARK: - Create Prediction Use Case
protocol CreatePredictionUseCase {
  func execute(request: CreatePredictionRequest) async throws -> Prediction
}

// MARK: - Create Prediction Request
struct CreatePredictionRequest {
  let title: String
  let description: String
  let type: PredictionType
  let confidence: Double
  let expectedValue: String
  let context: PredictionContext
  let dueDate: Date
  
  // Legacy support
  init(
    title: String,
    description: String,
    type: PredictionType,
    confidence: Double,
    expectedValue: String,
    context: PredictionContext = .empty,
    dueDate: Date
  ) {
    self.title = title
    self.description = description
    self.type = type
    self.confidence = confidence
    self.expectedValue = expectedValue
    self.context = context
    self.dueDate = dueDate
  }
  
  // Legacy evidence-based initializer for backward compatibility
  init(
    title: String,
    description: String,
    type: PredictionType,
    confidence: Double,
    expectedValue: String,
    evidence: [String],
    dueDate: Date
  ) {
    self.title = title
    self.description = description
    self.type = type
    self.confidence = confidence
    self.expectedValue = expectedValue
    self.context = PredictionContext.fromLegacyEvidence(evidence)
    self.dueDate = dueDate
  }
  
  func validate() throws {
    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw CreatePredictionError.emptyTitle
    }
    
    guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw CreatePredictionError.emptyDescription
    }
    
    guard confidence >= 0 && confidence <= 100 else {
      throw CreatePredictionError.invalidConfidence
    }
    
    guard !expectedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw CreatePredictionError.emptyExpectedValue
    }
    
    guard dueDate > Date() else {
      throw CreatePredictionError.invalidDueDate
    }
    
    // Validate context
    do {
      try context.validate()
    } catch {
      throw CreatePredictionError.invalidContext(error)
    }
  }
}

// MARK: - Create Prediction Error
enum CreatePredictionError: LocalizedError {
  case emptyTitle
  case emptyDescription
  case invalidConfidence
  case emptyExpectedValue
  case invalidDueDate
  case invalidContext(Error)
  case saveFailed(Error)
  
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
    case .invalidDueDate:
      return "Due date must be in the future"
    case .invalidContext(let error):
      return "Invalid prediction context: \(error.localizedDescription)"
    case .saveFailed(let error):
      return "Failed to save prediction: \(error.localizedDescription)"
    }
  }
}

// MARK: - Default Implementation
final class DefaultCreatePredictionUseCase: CreatePredictionUseCase {
  private let repository: PredictionRepositoryProtocol
  
  init(repository: PredictionRepositoryProtocol) {
    self.repository = repository
  }
  
  func execute(request: CreatePredictionRequest) async throws -> Prediction {
    // Validate the request
    try request.validate()
    
    // Create the prediction entity using the factory method
    let prediction = try Prediction.create(
      title: request.title.trimmingCharacters(in: .whitespacesAndNewlines),
      description: request.description.trimmingCharacters(in: .whitespacesAndNewlines),
      type: request.type,
      confidence: request.confidence,
      expectedValue: request.expectedValue.trimmingCharacters(in: .whitespacesAndNewlines),
      context: request.context,
      dueDate: request.dueDate
    )
    
    // Save to repository
    do {
      try await repository.save(prediction)
      return prediction
    } catch {
      throw CreatePredictionError.saveFailed(error)
    }
  }
}
