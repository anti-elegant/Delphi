//
//  AnalyticsView.swift
//  Delphi
//
//  Analytics view using clean architecture with AnalyticsViewModel
//

import SwiftUI

#if canImport(Charts)
  import Charts
#endif

struct AnalyticsView: View {
    @StateObject private var viewModel: AnalyticsViewModel
    private let coordinator: AppCoordinator
    
    init(viewModel: AnalyticsViewModel, coordinator: AppCoordinator) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.coordinator = coordinator
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading Analytics...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error {
                    ErrorView(error: error) {
                        Task {
                            await viewModel.refreshAnalytics()
                        }
                    }
                } else if !viewModel.hasData {
                    EmptyAnalyticsView()
                } else {
                    analyticsContent
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refreshAnalytics()
            }
            .task {
                await viewModel.loadAnalytics()
            }
        }
    }
    
    private var analyticsContent: some View {
        List {
            overviewSection
            accuracySection
            predictionBreakdownSection
            recentPredictionsSection
        }
        .listStyle(PlainListStyle())
    }
    
    private var overviewSection: some View {
        Section("Overview") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MetricCard(
                    title: "Total",
                    value: "\(viewModel.totalPredictions)",
                    icon: "list.bullet",
                    color: .blue
                )
                
                MetricCard(
                    title: "Resolved",
                    value: "\(viewModel.resolvedPredictions)",
                    icon: "checkmark.circle",
                    color: .green
                )
                
                MetricCard(
                    title: "Pending",
                    value: "\(viewModel.pendingPredictions)",
                    icon: "clock",
                    color: .orange
                )
                
                MetricCard(
                    title: "Overdue",
                    value: "\(viewModel.overduePredictions)",
                    icon: "exclamationmark.triangle",
                    color: .red
                )
            }
            .padding(.vertical, 8)
        }
        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        .listRowBackground(Color.clear)
    }
    
    private var accuracySection: some View {
        Section("Performance") {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Accuracy Rate")
                            .font(.headline)
                        Text(viewModel.formattedAccuracyRate)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Avg Confidence")
                            .font(.headline)
                        Text(viewModel.formattedAverageConfidence)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Completion Rate")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(viewModel.formattedCompletionRate)
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }
    
    private var predictionBreakdownSection: some View {
        Section("By Type") {
            ForEach(PredictionType.allCases, id: \.self) { type in
                HStack {
                    Image(systemName: type.systemImageName)
                        .foregroundColor(Color(type.color))
                        .frame(width: 24)
                    
                    Text(type.displayName)
                        .font(.body)
                    
                    Spacer()
                    
                    Text("\(viewModel.predictionCountForType(type))")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var recentPredictionsSection: some View {
        Section("Recent Predictions") {
            ForEach(Array(viewModel.recentPredictions.prefix(5)), id: \.id) { prediction in
                PredictionRowView(prediction: prediction)
            }
        }
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct PredictionRowView: View {
    let prediction: Prediction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(prediction.title)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(1)
            
            HStack {
                Text(prediction.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(colorForStatus(prediction.status).opacity(0.2))
                    .foregroundColor(colorForStatus(prediction.status))
                    .cornerRadius(4)
                
                Spacer()
                
                Text("\(Int(prediction.confidence))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func colorForStatus(_ status: PredictionStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .overdue:
            return .red
        case .resolved:
            return .green
        }
    }
}

struct EmptyAnalyticsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Analytics Yet")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Create some predictions to see your analytics here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct ErrorView: View {
    let error: Error
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Error Loading Analytics")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Extensions

// MARK: - Preview
#Preview {
    let container = DIContainer.shared
    let viewModel = container.makeAnalyticsViewModel()
    let coordinator = AppCoordinator(container: container)
    
    AnalyticsView(viewModel: viewModel, coordinator: coordinator)
}
