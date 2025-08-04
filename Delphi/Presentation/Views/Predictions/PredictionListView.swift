//
//  PredictionListView.swift
//  Delphi
//
//  Prediction list view using clean architecture with PredictionListViewModel
//

import SwiftUI

struct PredictionListView: View {
    @StateObject private var viewModel: PredictionListViewModel
    private let coordinator: AppCoordinator
    
    @State private var selectedPrediction: Prediction?
    
    init(viewModel: PredictionListViewModel, coordinator: AppCoordinator) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.coordinator = coordinator
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading predictions...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error {
                    ErrorView(error: error) {
                        Task {
                            await viewModel.loadPredictions()
                        }
                    }
                } else if viewModel.predictions.isEmpty {
                    EmptyPredictionsView {
                        coordinator.showPredictionForm()
                    }
                } else {
                    predictionsList
                }
            }
            .navigationTitle("Predictions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        coordinator.showPredictionForm()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await viewModel.loadPredictions()
            }
            .task {
                await viewModel.loadPredictions()
            }
            .sheet(item: $selectedPrediction) { prediction in
                PredictionDetailView(prediction: prediction, viewModel: viewModel)
            }
        }
    }
    
    private var predictionsList: some View {
        List {
            if !viewModel.pendingPredictions.isEmpty {
                pendingSection
            }
            
            if !viewModel.overduePredictions.isEmpty {
                overdueSection
            }
            
            if !viewModel.resolvedPredictions.isEmpty {
                resolvedSection
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var pendingSection: some View {
        Section("Pending") {
            ForEach(viewModel.pendingPredictions, id: \.id) { prediction in
                PredictionRow(prediction: prediction) {
                    selectedPrediction = prediction
                }
            }
        }
    }
    
    private var overdueSection: some View {
        Section("Overdue") {
            ForEach(viewModel.overduePredictions, id: \.id) { prediction in
                PredictionRow(prediction: prediction, isOverdue: true) {
                    selectedPrediction = prediction
                }
            }
        }
    }
    
    private var resolvedSection: some View {
        Section("Resolved") {
            ForEach(viewModel.resolvedPredictions, id: \.id) { prediction in
                ResolvedPredictionRow(prediction: prediction) {
                    selectedPrediction = prediction
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct PredictionRow: View {
    let prediction: Prediction
    let isOverdue: Bool
    let onTap: () -> Void
    
    init(prediction: Prediction, isOverdue: Bool = false, onTap: @escaping () -> Void) {
        self.prediction = prediction
        self.isOverdue = isOverdue
        self.onTap = onTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(prediction.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                if isOverdue {
                    Text("OVERDUE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                }
            }
            
            Text(prediction.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text("Confidence: \(Int(prediction.confidence))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(prediction.targetDate, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

struct ResolvedPredictionRow: View {
    let prediction: Prediction
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(prediction.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                // TODO: Add outcome display when PredictionOutcome is properly integrated
                Text("Resolved")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green)
                    .cornerRadius(4)
            }
            
            Text(prediction.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text("Confidence: \(Int(prediction.confidence))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let resolvedAt = prediction.resolvedAt {
                    Text("Resolved \(resolvedAt, format: .dateTime.day().month().year())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
}

struct EmptyPredictionsView: View {
    let onAddPrediction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wand.and.sparkles")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Predictions Yet")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Start making predictions about future events to track your forecasting ability.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Add Your First Prediction") {
                onAddPrediction()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct PredictionDetailView: View {
    let prediction: Prediction
    let viewModel: PredictionListViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    detailsSection
                    
                    if prediction.status == .pending {
                        actionsSection
                    }
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(prediction.status.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(colorForStatus(prediction.status))
                .cornerRadius(8)
            
            Text(prediction.title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(prediction.description)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)
            
            DetailRow(label: "Confidence", value: "\(Int(prediction.confidence))%")
            DetailRow(label: "Type", value: prediction.type.displayName)
            DetailRow(label: "Target Date", value: prediction.targetDate.formatted(date: .abbreviated, time: .omitted))
            DetailRow(label: "Created", value: prediction.createdAt.formatted(date: .abbreviated, time: .omitted))
            
            if let resolvedAt = prediction.resolvedAt {
                DetailRow(label: "Resolved", value: resolvedAt.formatted(date: .abbreviated, time: .omitted))
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button("Mark as Resolved") {
                Task {
                    // TODO: Update when PredictionOutcome is properly integrated
                    await viewModel.resolvePrediction(prediction, actualOutcome: "resolved")
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
        }
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

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Extensions


// MARK: - Preview

#Preview {
    let container = DIContainer.shared
    let viewModel = container.makePredictionListViewModel()
    let coordinator = AppCoordinator(container: container)
    
    PredictionListView(viewModel: viewModel, coordinator: coordinator)
}
