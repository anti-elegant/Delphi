//
//  PredictionFormViewModel.swift
//  Delphi
//
//  ViewModel for handling prediction creation and editing
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class PredictionFormViewModel: BaseViewModel {
    // MARK: - Published Properties
    @Published var eventName = ""
    @Published var eventDescription = ""
    @Published var confidenceLevel: Double = 50
    @Published var estimatedValue = ""
    @Published var booleanValue = "Yes"
    @Published var evidenceList: [String] = []
    @Published var newEvidence = ""
    @Published var dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date().addingTimeInterval(86400 * 30)
    @Published var selectedType: PredictionType = .personal
    @Published var isSaving = false
    @Published var showSuccessCheckmark = false
    
    // MARK: - UI State
    @Published var showingEvidenceInput = false
    @Published var editingIndex: Int?
    @Published var editingText = ""
    @Published var showingNameSheet = false
    @Published var showingDescSheet = false
    @Published var showingEvidenceSheet = false
    @Published var showingEditSheet = false
    
    // MARK: - Dependencies
    private let createPredictionUseCase: CreatePredictionUseCase
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var canSave: Bool {
        !eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !eventDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Initialization
    init(createPredictionUseCase: CreatePredictionUseCase) {
        self.createPredictionUseCase = createPredictionUseCase
        super.init()
        
        setupValidation()
    }
    
    // MARK: - Public Methods
    
    func savePrediction() async -> Bool {
        guard canSave else { return false }
        
        isSaving = true
        defer { isSaving = false }
        
        do {
            let request = CreatePredictionRequest(
                title: eventName.trimmingCharacters(in: .whitespacesAndNewlines),
                description: eventDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                type: selectedType,
                confidence: confidenceLevel,
                expectedValue: selectedType == .personal ? booleanValue : estimatedValue,
                evidence: evidenceList, // Use legacy evidence initializer for now
                dueDate: dueDate
            )
            let _ = try await createPredictionUseCase.execute(request: request)
            await showSuccessAnimation()
            resetForm()
            return true
        } catch {
            self.error = error
            return false
        }
    }
    
    func addEvidence() {
        let trimmedEvidence = newEvidence.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEvidence.isEmpty {
            evidenceList.append(trimmedEvidence)
            newEvidence = ""
        }
    }
    
    func saveEditedEvidence() {
        guard let index = editingIndex else { return }
        
        let trimmedText = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            evidenceList[index] = trimmedText
        }
        
        editingText = ""
        editingIndex = nil
    }
    
    func deleteEvidence(at index: Int) {
        guard index < evidenceList.count else { return }
        evidenceList.remove(at: index)
    }
    
    func startEditingEvidence(at index: Int) {
        guard index < evidenceList.count else { return }
        editingText = evidenceList[index]
        editingIndex = index
        showingEditSheet = true
    }
    
    func resetForm() {
        eventName = ""
        eventDescription = ""
        confidenceLevel = 50
        estimatedValue = ""
        booleanValue = "Yes"
        evidenceList = []
        selectedType = .personal
        dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date().addingTimeInterval(86400 * 30)
        showSuccessCheckmark = false
        clearError()
    }
    
    // MARK: - Private Methods
    
    private func setupValidation() {
        // Ensure confidence level stays within valid range
        $confidenceLevel
            .sink { [weak self] value in
                if value < 0 {
                    self?.confidenceLevel = 0
                } else if value > 100 {
                    self?.confidenceLevel = 100
                }
            }
            .store(in: &cancellables)
    }
    
    private func showSuccessAnimation() async {
        await MainActor.run {
            SwiftUI.withAnimation {
                showSuccessCheckmark = true
            }
        }
        
        try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2 seconds
        
        await MainActor.run {
            SwiftUI.withAnimation {
                showSuccessCheckmark = false
            }
        }
    }
}

