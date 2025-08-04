import Foundation

// MARK: - Accuracy Metric Domain Entity
struct AccuracyMetric {
  let correctCount: Int
  let totalCount: Int
  let percentage: Double
  let lastUpdated: Date
  
  // MARK: - Computed Properties
  var formattedPercentage: String {
    if totalCount == 0 {
      return "N/A"
    }
    return String(format: "%.1f%%", percentage * 100)
  }
  
  var displayValue: String {
    if totalCount == 0 {
      return "No data"
    }
    return "\(correctCount)/\(totalCount)"
  }
  
  var isEmpty: Bool {
    totalCount == 0
  }
  
  var description: String {
    if isEmpty {
      return "No predictions have been resolved yet. Create and resolve predictions to see your accuracy."
    } else {
      return "You've correctly predicted \(correctCount) out of \(totalCount) outcomes."
    }
  }
}

// MARK: - Initializers
extension AccuracyMetric {
  init(correctCount: Int, totalCount: Int, lastUpdated: Date = Date()) {
    self.correctCount = correctCount
    self.totalCount = totalCount
    self.percentage = totalCount > 0 ? Double(correctCount) / Double(totalCount) : 0.0
    self.lastUpdated = lastUpdated
  }
  
  static let empty = AccuracyMetric(correctCount: 0, totalCount: 0)
}

// MARK: - Protocol Conformances
extension AccuracyMetric: Equatable {}

extension AccuracyMetric: Codable {}

// MARK: - Factory Methods
extension AccuracyMetric {
  /// Calculate accuracy from a list of predictions
  static func calculate(from predictions: [Prediction], at date: Date = Date()) -> AccuracyMetric {
    let resolvedPredictions = predictions.filter { $0.isResolved }
    let correctPredictions = resolvedPredictions.filter { $0.isCorrect == true }
    
    return AccuracyMetric(
      correctCount: correctPredictions.count,
      totalCount: resolvedPredictions.count,
      lastUpdated: date
    )
  }
}

// MARK: - Validation
extension AccuracyMetric {
  enum ValidationError: LocalizedError {
    case invalidCounts
    case negativeValues
    
    var errorDescription: String? {
      switch self {
      case .invalidCounts:
        return "Correct count cannot be greater than total count"
      case .negativeValues:
        return "Counts cannot be negative"
      }
    }
  }
  
  func validate() throws {
    guard correctCount >= 0 && totalCount >= 0 else {
      throw ValidationError.negativeValues
    }
    
    guard correctCount <= totalCount else {
      throw ValidationError.invalidCounts
    }
  }
}
