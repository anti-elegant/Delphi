//
//  AnalyticsViewModel.swift
//  Delphi
//
//  ViewModel for handling analytics data and statistics
//

import Foundation
import Combine

@MainActor
final class AnalyticsViewModel: BaseViewModel {
    // MARK: - Published Properties
    @Published var totalPredictions: Int = 0
    @Published var resolvedPredictions: Int = 0
    @Published var pendingPredictions: Int = 0
    @Published var overduePredictions: Int = 0
    @Published var accuracyRate: Double = 0.0
    @Published var averageConfidence: Double = 0.0
    @Published var recentPredictions: [Prediction] = []
    @Published var mostConfidentPredictions: [Prediction] = []
    @Published var predictionsByType: [PredictionType: Int] = [:]
    @Published var monthlyStats: [MonthlyStats] = []
    
    // MARK: - Dependencies
    private let getAnalyticsSummaryUseCase: GetAnalyticsSummaryUseCase
    
    // MARK: - Initialization
    init(getAnalyticsSummaryUseCase: GetAnalyticsSummaryUseCase) {
        self.getAnalyticsSummaryUseCase = getAnalyticsSummaryUseCase
        super.init()
    }
    
    // MARK: - Public Methods
    
    func loadAnalytics() async {
        await executeWithLoading { [self] in
            let summary = try await self.getAnalyticsSummaryUseCase.execute()
            
            await MainActor.run {
                self.updateAnalytics(with: summary)
            }
        }
    }
    
    func refreshAnalytics() async {
        await loadAnalytics()
    }
    
    // MARK: - Computed Properties
    
    var formattedAccuracyRate: String {
        String(format: "%.1f%%", accuracyRate * 100)
    }
    
    var formattedAverageConfidence: String {
        String(format: "%.1f%%", averageConfidence)
    }
    
    var hasData: Bool {
        totalPredictions > 0
    }
    
    var completionRate: Double {
        guard totalPredictions > 0 else { return 0.0 }
        return Double(resolvedPredictions) / Double(totalPredictions)
    }
    
    var formattedCompletionRate: String {
        String(format: "%.1f%%", completionRate * 100)
    }
    
    var pendingRate: Double {
        guard totalPredictions > 0 else { return 0.0 }
        return Double(pendingPredictions) / Double(totalPredictions)
    }
    
    var overdueRate: Double {
        guard totalPredictions > 0 else { return 0.0 }
        return Double(overduePredictions) / Double(totalPredictions)
    }
    
    // MARK: - Helper Methods
    
    func predictionCountForType(_ type: PredictionType) -> Int {
        predictionsByType[type] ?? 0
    }
    
    func monthlyStatsForCurrentYear() -> [MonthlyStats] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return monthlyStats.filter { $0.year == currentYear }
    }
    
    func getTopPerformingMonths(limit: Int = 3) -> [MonthlyStats] {
        return monthlyStats
            .sorted { $0.accuracyRate > $1.accuracyRate }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - Private Methods
    
    private func updateAnalytics(with summary: AnalyticsSummary) {
        totalPredictions = summary.totalPredictions
        resolvedPredictions = summary.resolvedPredictions
        pendingPredictions = summary.pendingPredictions
        overduePredictions = summary.overduePredictions
        accuracyRate = summary.accuracyMetric.percentage
        averageConfidence = 0.0 // Not available in current summary struct
        recentPredictions = [] // Not available in current summary struct
        mostConfidentPredictions = [] // Not available in current summary struct
        predictionsByType = [:] // Not available in current summary struct
        monthlyStats = [] // Not available in current summary struct
    }
}

// MARK: - Supporting Types

struct MonthlyStats: Identifiable, Equatable {
    let id = UUID()
    let year: Int
    let month: Int
    let predictionsCount: Int
    let resolvedCount: Int
    let accuracyRate: Double
    let averageConfidence: Double
    
    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let date = Calendar.current.date(from: DateComponents(year: year, month: month)) ?? Date()
        return formatter.string(from: date)
    }
    
    var formattedAccuracy: String {
        String(format: "%.1f%%", accuracyRate * 100)
    }
    
    var formattedConfidence: String {
        String(format: "%.1f%%", averageConfidence)
    }
}

