import Foundation

// MARK: - Calculate Accuracy Use Case
protocol CalculateAccuracyUseCase {
  func execute() async throws -> AccuracyMetric
  func executeForDateRange(_ dateRange: DateRange) async throws -> AccuracyMetric
}

// MARK: - Date Range
struct DateRange {
  let startDate: Date
  let endDate: Date
  
  init(startDate: Date, endDate: Date) {
    self.startDate = startDate
    self.endDate = endDate
  }
  
  static func lastMonth() -> DateRange {
    let now = Date()
    let calendar = Calendar.current
    let startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
    return DateRange(startDate: startDate, endDate: now)
  }
  
  static func lastWeek() -> DateRange {
    let now = Date()
    let calendar = Calendar.current
    let startDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
    return DateRange(startDate: startDate, endDate: now)
  }
  
  static func allTime() -> DateRange {
    let now = Date()
    let distantPast = Date.distantPast
    return DateRange(startDate: distantPast, endDate: now)
  }
  
  func validate() throws {
    guard startDate <= endDate else {
      throw DateRangeError.invalidRange
    }
  }
}

// MARK: - Date Range Error
enum DateRangeError: LocalizedError {
  case invalidRange
  
  var errorDescription: String? {
    switch self {
    case .invalidRange:
      return "Start date must be before or equal to end date"
    }
  }
}

// MARK: - Calculate Accuracy Error
enum CalculateAccuracyError: LocalizedError {
  case fetchFailed(Error)
  case calculationFailed(Error)
  
  var errorDescription: String? {
    switch self {
    case .fetchFailed(let error):
      return "Failed to fetch predictions for accuracy calculation: \(error.localizedDescription)"
    case .calculationFailed(let error):
      return "Failed to calculate accuracy: \(error.localizedDescription)"
    }
  }
}

// MARK: - Default Implementation
final class DefaultCalculateAccuracyUseCase: CalculateAccuracyUseCase {
  private let repository: PredictionRepositoryProtocol
  
  init(repository: PredictionRepositoryProtocol) {
    self.repository = repository
  }
  
  func execute() async throws -> AccuracyMetric {
    do {
      let resolvedPredictions = try await repository.getResolved()
      return calculateAccuracy(from: resolvedPredictions)
    } catch {
      throw CalculateAccuracyError.fetchFailed(error)
    }
  }
  
  func executeForDateRange(_ dateRange: DateRange) async throws -> AccuracyMetric {
    do {
      try dateRange.validate()
      
      let allResolved = try await repository.getResolved()
      let filteredPredictions = allResolved.filter { prediction in
        guard let resolvedAt = prediction.resolvedAt else { return false }
        return resolvedAt >= dateRange.startDate && resolvedAt <= dateRange.endDate
      }
      
      return calculateAccuracy(from: filteredPredictions)
    } catch let error as DateRangeError {
      throw error
    } catch {
      throw CalculateAccuracyError.fetchFailed(error)
    }
  }
  
  private func calculateAccuracy(from predictions: [Prediction]) -> AccuracyMetric {
    let correctPredictions = predictions.filter { $0.isCorrect == true }
    
    return AccuracyMetric(
      correctCount: correctPredictions.count,
      totalCount: predictions.count
    )
  }
}

