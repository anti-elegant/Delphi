//
//  GetAnalyticsSummaryUseCase.swift
//  Delphi
//
//  Use case for retrieving analytics summary data
//

import Foundation

// MARK: - Analytics Summary Use Case Protocol
protocol GetAnalyticsSummaryUseCase {
    func execute() async throws -> AnalyticsSummary
}

// MARK: - Analytics Summary
struct AnalyticsSummary {
    let totalPredictions: Int
    let pendingPredictions: Int
    let overduePredictions: Int
    let resolvedPredictions: Int
    let accuracyMetric: AccuracyMetric
    let lastUpdated: Date
    
    var hasData: Bool {
        totalPredictions > 0
    }
    
    var hasResolvedData: Bool {
        resolvedPredictions > 0
    }
}

// MARK: - Default Implementation
final class DefaultGetAnalyticsSummaryUseCase: GetAnalyticsSummaryUseCase {
    private let predictionRepository: PredictionRepositoryProtocol
    private let accuracyUseCase: CalculateAccuracyUseCase
    
    init(
        predictionRepository: PredictionRepositoryProtocol,
        accuracyUseCase: CalculateAccuracyUseCase
    ) {
        self.predictionRepository = predictionRepository
        self.accuracyUseCase = accuracyUseCase
    }
    
    func execute() async throws -> AnalyticsSummary {
        do {
            let allPredictions = try await predictionRepository.getAll()
            let pendingPredictions = try await predictionRepository.getPending()
            let overduePredictions = try await predictionRepository.getOverdue()
            let resolvedPredictions = try await predictionRepository.getResolved()
            let accuracyMetric = try await accuracyUseCase.execute()
            
            return AnalyticsSummary(
                totalPredictions: allPredictions.count,
                pendingPredictions: pendingPredictions.count,
                overduePredictions: overduePredictions.count,
                resolvedPredictions: resolvedPredictions.count,
                accuracyMetric: accuracyMetric,
                lastUpdated: Date()
            )
        } catch {
            throw CalculateAccuracyError.fetchFailed(error)
        }
    }
}
