import Foundation

// MARK: - Resolve Prediction Use Case
protocol ResolvePredictionUseCase {
  func execute(request: ResolvePredictionRequest) async throws -> Prediction
}

// MARK: - Resolve Prediction Request
struct ResolvePredictionRequest {
  let predictionId: UUID
  let actualValue: String
  let resolvedAt: Date
  
  init(predictionId: UUID, actualValue: String, resolvedAt: Date = Date()) {
    self.predictionId = predictionId
    self.actualValue = actualValue
    self.resolvedAt = resolvedAt
  }
  
  func validate() throws {
    guard !actualValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw ResolvePredictionError.emptyActualValue
    }
    
    guard resolvedAt <= Date() else {
      throw ResolvePredictionError.futureResolutionDate
    }
  }
}

// MARK: - Resolve Prediction Error
enum ResolvePredictionError: LocalizedError {
  case predictionNotFound(UUID)
  case emptyActualValue
  case futureResolutionDate
  case alreadyResolved(UUID)
  case updateFailed(Error)
  
  var errorDescription: String? {
    switch self {
    case .predictionNotFound(let id):
      return "Prediction with ID \(id) not found"
    case .emptyActualValue:
      return "Actual value cannot be empty"
    case .futureResolutionDate:
      return "Resolution date cannot be in the future"
    case .alreadyResolved(let id):
      return "Prediction \(id) is already resolved"
    case .updateFailed(let error):
      return "Failed to resolve prediction: \(error.localizedDescription)"
    }
  }
}

// MARK: - Default Implementation
final class DefaultResolvePredictionUseCase: ResolvePredictionUseCase {
  private let repository: PredictionRepositoryProtocol
  
  init(repository: PredictionRepositoryProtocol) {
    self.repository = repository
  }
  
  func execute(request: ResolvePredictionRequest) async throws -> Prediction {
    // Validate the request
    try request.validate()
    
    // Get the existing prediction
    guard let existingPrediction = try await repository.getById(request.predictionId) else {
      throw ResolvePredictionError.predictionNotFound(request.predictionId)
    }
    
    // Check if prediction is already resolved
    guard !existingPrediction.isResolved else {
      throw ResolvePredictionError.alreadyResolved(request.predictionId)
    }
    
    // Create resolved prediction
    let resolvedPrediction = existingPrediction.resolved(
      with: request.actualValue.trimmingCharacters(in: .whitespacesAndNewlines),
      at: request.resolvedAt
    )
    
    // Update in repository
    do {
      try await repository.update(resolvedPrediction)
      return resolvedPrediction
    } catch {
      throw ResolvePredictionError.updateFailed(error)
    }
  }
}

// MARK: - Bulk Resolve Use Case
protocol BulkResolvePredictionsUseCase {
  func execute(requests: [ResolvePredictionRequest]) async throws -> [Prediction]
}

// MARK: - Bulk Resolve Default Implementation
final class DefaultBulkResolvePredictionsUseCase: BulkResolvePredictionsUseCase {
  private let resolvePredictionUseCase: ResolvePredictionUseCase
  
  init(resolvePredictionUseCase: ResolvePredictionUseCase) {
    self.resolvePredictionUseCase = resolvePredictionUseCase
  }
  
  func execute(requests: [ResolvePredictionRequest]) async throws -> [Prediction] {
    var resolvedPredictions: [Prediction] = []
    var errors: [Error] = []
    
    for request in requests {
      do {
        let resolved = try await resolvePredictionUseCase.execute(request: request)
        resolvedPredictions.append(resolved)
      } catch {
        errors.append(error)
      }
    }
    
    // If any errors occurred, throw a compound error
    if !errors.isEmpty {
      throw BulkResolveError.partialFailure(
        resolved: resolvedPredictions,
        errors: errors
      )
    }
    
    return resolvedPredictions
  }
}

// MARK: - Bulk Resolve Error
enum BulkResolveError: LocalizedError {
  case partialFailure(resolved: [Prediction], errors: [Error])
  
  var errorDescription: String? {
    switch self {
    case .partialFailure(let resolved, let errors):
      return "Resolved \(resolved.count) predictions, but \(errors.count) failed"
    }
  }
}
