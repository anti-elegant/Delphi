import Foundation

// MARK: - Delete Prediction Use Case
protocol DeletePredictionUseCase {
  func execute(predictionId: UUID) async throws
  func executeAll() async throws
}

// MARK: - Delete Prediction Error
enum DeletePredictionError: LocalizedError {
  case predictionNotFound(UUID)
  case deleteFailed(Error)
  case deleteAllFailed(Error)
  
  var errorDescription: String? {
    switch self {
    case .predictionNotFound(let id):
      return "Prediction with ID \(id) not found"
    case .deleteFailed(let error):
      return "Failed to delete prediction: \(error.localizedDescription)"
    case .deleteAllFailed(let error):
      return "Failed to delete all predictions: \(error.localizedDescription)"
    }
  }
}

// MARK: - Default Implementation
final class DefaultDeletePredictionUseCase: DeletePredictionUseCase {
  private let repository: PredictionRepositoryProtocol
  
  init(repository: PredictionRepositoryProtocol) {
    self.repository = repository
  }
  
  func execute(predictionId: UUID) async throws {
    do {
      // Verify prediction exists before attempting to delete
      guard try await repository.getById(predictionId) != nil else {
        throw DeletePredictionError.predictionNotFound(predictionId)
      }
      
      try await repository.delete(predictionId)
    } catch let error as DeletePredictionError {
      throw error
    } catch {
      throw DeletePredictionError.deleteFailed(error)
    }
  }
  
  func executeAll() async throws {
    do {
      try await repository.deleteAll()
    } catch {
      throw DeletePredictionError.deleteAllFailed(error)
    }
  }
}

// MARK: - Bulk Delete Use Case
protocol BulkDeletePredictionsUseCase {
  func execute(predictionIds: [UUID]) async throws -> BulkDeleteResult
}

// MARK: - Bulk Delete Result
struct BulkDeleteResult {
  let successfulDeletes: [UUID]
  let failedDeletes: [UUID: Error]
  
  var totalRequested: Int {
    successfulDeletes.count + failedDeletes.count
  }
  
  var hasFailures: Bool {
    !failedDeletes.isEmpty
  }
  
  var allSucceeded: Bool {
    failedDeletes.isEmpty
  }
}

// MARK: - Bulk Delete Default Implementation
final class DefaultBulkDeletePredictionsUseCase: BulkDeletePredictionsUseCase {
  private let deleteUseCase: DeletePredictionUseCase
  
  init(deleteUseCase: DeletePredictionUseCase) {
    self.deleteUseCase = deleteUseCase
  }
  
  func execute(predictionIds: [UUID]) async throws -> BulkDeleteResult {
    var successfulDeletes: [UUID] = []
    var failedDeletes: [UUID: Error] = [:]
    
    for predictionId in predictionIds {
      do {
        try await deleteUseCase.execute(predictionId: predictionId)
        successfulDeletes.append(predictionId)
      } catch {
        failedDeletes[predictionId] = error
      }
    }
    
    return BulkDeleteResult(
      successfulDeletes: successfulDeletes,
      failedDeletes: failedDeletes
    )
  }
}

// MARK: - Delete by Status Use Case
protocol DeletePredictionsByStatusUseCase {
  func execute(status: PredictionStatus) async throws -> Int
}

// MARK: - Delete by Status Default Implementation
final class DefaultDeletePredictionsByStatusUseCase: DeletePredictionsByStatusUseCase {
  private let repository: PredictionRepositoryProtocol
  
  init(repository: PredictionRepositoryProtocol) {
    self.repository = repository
  }
  
  func execute(status: PredictionStatus) async throws -> Int {
    do {
      let predictions = try await repository.getByStatus(status)
      let predictionIds = predictions.map { $0.id }
      
      for id in predictionIds {
        try await repository.delete(id)
      }
      
      return predictionIds.count
    } catch {
      throw DeletePredictionError.deleteFailed(error)
    }
  }
}
