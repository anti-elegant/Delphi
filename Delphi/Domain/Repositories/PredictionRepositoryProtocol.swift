import Foundation

// MARK: - Prediction Repository Protocol
protocol PredictionRepositoryProtocol {
  
  // MARK: - Create
  func save(_ prediction: Prediction) async throws
  
  // MARK: - Read
  func getAll() async throws -> [Prediction]
  func getById(_ id: UUID) async throws -> Prediction?
  func getByStatus(_ status: PredictionStatus) async throws -> [Prediction]
  func getPending() async throws -> [Prediction]
  func getOverdue() async throws -> [Prediction]
  func getResolved() async throws -> [Prediction]
  
  // MARK: - Update
  func update(_ prediction: Prediction) async throws
  func resolve(_ id: UUID, actualValue: String, resolvedAt: Date) async throws
  
  // MARK: - Delete
  func delete(_ id: UUID) async throws
  func deleteAll() async throws
  
  // MARK: - Analytics Support
  func getResolvedCount() async throws -> Int
  func getCorrectCount() async throws -> Int
  func calculateAccuracy() async throws -> AccuracyMetric
}

// MARK: - Repository Error Types
enum PredictionRepositoryError: LocalizedError {
  case predictionNotFound(UUID)
  case saveFailed(Error)
  case fetchFailed(Error)
  case updateFailed(Error)
  case deleteFailed(Error)
  case invalidData
  case alreadyResolved(UUID)
  
  var errorDescription: String? {
    switch self {
    case .predictionNotFound(let id):
      return "Prediction with ID \(id) not found"
    case .saveFailed(let error):
      return "Failed to save prediction: \(error.localizedDescription)"
    case .fetchFailed(let error):
      return "Failed to fetch predictions: \(error.localizedDescription)"
    case .updateFailed(let error):
      return "Failed to update prediction: \(error.localizedDescription)"
    case .deleteFailed(let error):
      return "Failed to delete prediction: \(error.localizedDescription)"
    case .invalidData:
      return "Invalid prediction data"
    case .alreadyResolved(let id):
      return "Prediction \(id) is already resolved"
    }
  }
}

// MARK: - Prediction Query Options
struct PredictionQueryOptions {
  let sortBy: SortOption
  let order: SortOrder
  let limit: Int?
  let offset: Int?
  
  enum SortOption {
    case createdDate
    case dueDate
    case resolvedDate
    case confidence
    case title
  }
  
  enum SortOrder {
    case ascending
    case descending
  }
  
  static let defaultOptions = PredictionQueryOptions(
    sortBy: .createdDate,
    order: .descending,
    limit: nil,
    offset: nil
  )
}

// MARK: - Extended Repository Protocol
protocol PredictionRepositoryProtocol_Extended: PredictionRepositoryProtocol {
  func getWithOptions(_ options: PredictionQueryOptions) async throws -> [Prediction]
  func search(query: String) async throws -> [Prediction]
  func getStatistics() async throws -> PredictionStatistics
}

// MARK: - Prediction Statistics
struct PredictionStatistics {
  let totalCount: Int
  let pendingCount: Int
  let overdueCount: Int
  let resolvedCount: Int
  let averageConfidence: Double
  let accuracyMetric: AccuracyMetric
}
