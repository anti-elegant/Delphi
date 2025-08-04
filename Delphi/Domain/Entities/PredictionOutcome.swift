import Foundation

// MARK: - Prediction Outcome Domain Entity
enum PredictionOutcome: String, CaseIterable, Codable {
    case occurred = "occurred"
    case didNotOccur = "did_not_occur"  
    case partiallyOccurred = "partially_occurred"
}

// MARK: - Display Properties
extension PredictionOutcome {
    var displayName: String {
        switch self {
        case .occurred:
            return "Occurred"
        case .didNotOccur:
            return "Did Not Occur"
        case .partiallyOccurred:
            return "Partially Occurred"
        }
    }
}
