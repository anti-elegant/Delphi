import Foundation

// MARK: - Prediction Status
enum PredictionStatus: String, CaseIterable, Codable, Sendable {
  case pending = "pending"
  case overdue = "overdue"
  case resolved = "resolved"
  
  var displayName: String {
    switch self {
    case .pending:
      return "Pending"
    case .overdue:
      return "Overdue"
    case .resolved:
      return "Resolved"
    }
  }
  
  var systemImageName: String {
    switch self {
    case .pending:
      return "clock"
    case .overdue:
      return "exclamationmark.triangle"
    case .resolved:
      return "checkmark.circle"
    }
  }
  
  var color: String {
    switch self {
    case .pending:
      return "blue"
    case .overdue:
      return "orange"
    case .resolved:
      return "green"
    }
  }
}

// MARK: - Extensions
extension PredictionStatus: Identifiable {
  var id: String { rawValue }
}

extension PredictionStatus: CustomStringConvertible {
  var description: String {
    switch self {
    case .pending:
      return "Prediction is waiting to be resolved"
    case .overdue:
      return "Prediction is past its due date"
    case .resolved:
      return "Prediction has been resolved with an outcome"
    }
  }
}

extension PredictionStatus: Comparable {
  static func < (lhs: PredictionStatus, rhs: PredictionStatus) -> Bool {
    let order: [PredictionStatus] = [.overdue, .pending, .resolved]
    guard let lhsIndex = order.firstIndex(of: lhs),
          let rhsIndex = order.firstIndex(of: rhs) else {
      return false
    }
    return lhsIndex < rhsIndex
  }
}
