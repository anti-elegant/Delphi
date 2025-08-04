//
//  PredictionListViewModel.swift
//  Delphi
//
//  ViewModel for handling prediction list functionality
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class PredictionListViewModel: BaseViewModel {
    // MARK: - Published Properties
    @Published var predictions: [Prediction] = []
    @Published var pendingPredictions: [Prediction] = []
    @Published var overduePredictions: [Prediction] = []
    @Published var resolvedPredictions: [Prediction] = []
    @Published var selectedPrediction: Prediction?
    @Published var isOverdueExpanded = false
    @Published var isResolvedExpanded = false
    
    // MARK: - Dependencies
    private let getPredictionsUseCase: GetPredictionsUseCase
    private let deletePredictionUseCase: DeletePredictionUseCase
    private let resolvePredictionUseCase: ResolvePredictionUseCase
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        getPredictionsUseCase: GetPredictionsUseCase,
        deletePredictionUseCase: DeletePredictionUseCase,
        resolvePredictionUseCase: ResolvePredictionUseCase
    ) {
        self.getPredictionsUseCase = getPredictionsUseCase
        self.deletePredictionUseCase = deletePredictionUseCase
        self.resolvePredictionUseCase = resolvePredictionUseCase
        super.init()
        
        loadPredictions()
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func loadPredictions() {
        Task {
            await executeWithLoading { [weak self] in
                guard let self = self else { return }
                let allPredictions = try await self.getPredictionsUseCase.execute()
                self.predictions = allPredictions
                self.updateCategorizedPredictions()
            }
        }
    }
    
    func deletePrediction(_ prediction: Prediction) {
        Task {
            await executeWithLoading { [weak self] in
                guard let self = self else { return }
                try await self.deletePredictionUseCase.execute(predictionId: prediction.id)
                self.predictions.removeAll { $0.id == prediction.id }
                self.updateCategorizedPredictions()
            }
        }
    }
    
    func resolvePrediction(_ prediction: Prediction, actualOutcome: String) {
        Task {
            await executeWithLoading { [weak self] in
                guard let self = self else { return }
                let request = ResolvePredictionRequest(
                    predictionId: prediction.id,
                    actualValue: actualOutcome
                )
                try await self.resolvePredictionUseCase.execute(request: request)
                
                // Update local state
                if let index = self.predictions.firstIndex(where: { $0.id == prediction.id }) {
                    let updatedPrediction = self.predictions[index].resolved(with: actualOutcome, at: Date())
                    self.predictions[index] = updatedPrediction
                }
                self.updateCategorizedPredictions()
            }
        }
    }
    
    func toggleOverdueExpansion() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isOverdueExpanded.toggle()
        }
    }
    
    func toggleResolvedExpansion() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isResolvedExpanded.toggle()
        }
    }
    
    func selectPrediction(_ prediction: Prediction) {
        selectedPrediction = prediction
    }
    
    func refresh() {
        loadPredictions()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Update categorized predictions when main predictions array changes
        $predictions
            .sink { [weak self] _ in
                self?.updateCategorizedPredictions()
            }
            .store(in: &cancellables)
    }
    
    private func updateCategorizedPredictions() {
        let now = Date()
        
        pendingPredictions = predictions.filter { prediction in
            prediction.status == .pending && prediction.dueDate > now
        }
        
        overduePredictions = predictions.filter { prediction in
            prediction.status == .pending && prediction.dueDate <= now
        }
        
        resolvedPredictions = predictions.filter { prediction in
            prediction.status == .resolved
        }
    }
}

// MARK: - Computed Properties
extension PredictionListViewModel {
    var hasPredictions: Bool {
        !predictions.isEmpty
    }
    
    var hasPendingPredictions: Bool {
        !pendingPredictions.isEmpty
    }
    
    var hasOverduePredictions: Bool {
        !overduePredictions.isEmpty
    }
    
    var hasResolvedPredictions: Bool {
        !resolvedPredictions.isEmpty
    }
}
