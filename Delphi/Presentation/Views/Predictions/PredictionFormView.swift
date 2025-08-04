//
//  PredictionFormView.swift
//  Delphi
//
//  Prediction form view using clean architecture with PredictionFormViewModel
//

import SwiftUI

// Import design system and components
import Foundation

struct PredictionFormView: View {
    @StateObject private var viewModel: PredictionFormViewModel
    private let coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: PredictionFormViewModel, coordinator: AppCoordinator) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.coordinator = coordinator
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    eventDetailsSection
                    evidenceSection
                    saveSection
                }
                .padding()
            }
            .navigationTitle("New Prediction")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        coordinator.hidePredictionForm()
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
            .onChange(of: viewModel.showSuccessCheckmark) { success in
                if success {
                    // Auto-dismiss after success animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        coordinator.hidePredictionForm()
                    }
                }
            }
        }
    }
    
    private var eventDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Event Details")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("What will happen?", text: $viewModel.eventName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Describe the event...", text: $viewModel.eventDescription, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    DatePicker("When should this be resolved?",
                              selection: $viewModel.dueDate,
                              displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confidence Level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    VStack(spacing: 8) {
                        HStack {
                            Text("How confident are you?")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(viewModel.confidenceLevel))%")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Slider(value: $viewModel.confidenceLevel, in: 0...100, step: 5)
                            .accentColor(.blue)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Prediction Type", selection: $viewModel.selectedType) {
                        Text("Personal").tag(PredictionType.personal)
                        Text("Professional").tag(PredictionType.professional)
                    }
                    .pickerStyle(.segmented)
                }
                
                if viewModel.selectedType == .personal {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Predicted Outcome")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Will it happen?", selection: $viewModel.booleanValue) {
                            Text("Yes").tag("Yes")
                            Text("No").tag("No")
                        }
                        .pickerStyle(.segmented)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estimated Value")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter expected value", text: $viewModel.estimatedValue)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                    }
                }
            }
        }
    }
    
    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Supporting Evidence")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Add") {
                    viewModel.showingEvidenceInput.toggle()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            if viewModel.evidenceList.isEmpty {
                Text("No evidence added yet")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(Array(viewModel.evidenceList.enumerated()), id: \.offset) { index, evidence in
                    EvidenceRow(
                        evidence: evidence,
                        onEdit: {
                            viewModel.startEditingEvidence(at: index)
                        },
                        onDelete: {
                            viewModel.deleteEvidence(at: index)
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $viewModel.showingEvidenceInput) {
            AddEvidenceSheet(
                newEvidence: $viewModel.newEvidence,
                onSave: {
                    viewModel.addEvidence()
                    viewModel.showingEvidenceInput = false
                },
                onCancel: {
                    viewModel.newEvidence = ""
                    viewModel.showingEvidenceInput = false
                }
            )
        }
        .sheet(isPresented: $viewModel.showingEditSheet) {
            EditEvidenceSheet(
                editingText: $viewModel.editingText,
                onSave: {
                    viewModel.saveEditedEvidence()
                    viewModel.showingEditSheet = false
                },
                onCancel: {
                    viewModel.editingText = ""
                    viewModel.editingIndex = nil
                    viewModel.showingEditSheet = false
                }
            )
        }
    }
    
    private var saveSection: some View {
        VStack(spacing: 12) {
            if viewModel.showSuccessCheckmark {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    Text("Prediction saved!")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: {
                    Task {
                        let success = await viewModel.savePrediction()
                        if success {
                            // Success animation will trigger auto-dismiss
                        }
                    }
                }) {
                    HStack {
                        if viewModel.isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(viewModel.isSaving ? "Saving..." : "Save Prediction")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canSave ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!viewModel.canSave || viewModel.isSaving)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.showSuccessCheckmark)
    }
}

// MARK: - Supporting Views


struct EvidenceRow: View {
    let evidence: String
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("•")
                .font(.body)
                .foregroundColor(.secondary)
            
            Text(evidence)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddEvidenceSheet: View {
    @Binding var newEvidence: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add Evidence")
                    .font(.headline)
                
                TextField("Enter supporting evidence...", text: $newEvidence, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .lineLimit(3...10)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Evidence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onSave()
                    }
                    .disabled(newEvidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

struct EditEvidenceSheet: View {
    @Binding var editingText: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Edit Evidence")
                    .font(.headline)
                
                TextField("Edit evidence...", text: $editingText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .lineLimit(3...10)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Evidence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

// MARK: - Preview

#Preview {
    let container = DIContainer.shared
    let viewModel = container.makePredictionFormViewModel()
    let coordinator = AppCoordinator(container: container)
    
    PredictionFormView(viewModel: viewModel, coordinator: coordinator)
}
