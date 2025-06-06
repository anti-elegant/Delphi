import SwiftData
import SwiftUI
import UIKit

struct PredictionFormView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @StateObject private var settings = SettingsStore.shared

  @State private var eventName: String = ""
  @State private var eventDesc: String = ""
  @State private var confidenceLevel: Double = 50
  @State private var estimatedValue: String = ""
  @State private var booleanValue: String = "Yes"
  @State private var pressureLevel: String = "Low"
  @State private var currentMood: String = "Good"
  @State private var takesMedicine: String = "No"
  @State private var evidenceList: [String] = []
  @State private var newEvidence: String = ""
  @State private var showingEvidenceInput: Bool = false
  @State private var editingIndex: Int? = nil
  @State private var editingText: String = ""
  @State private var showingNameSheet: Bool = false
  @State private var showingDescSheet: Bool = false
  @State private var showingEvidenceSheet: Bool = false
  @State private var showingEditSheet: Bool = false
  @State private var dueDate: Date = Date().addingTimeInterval(86400 * 30)  // Default to 30 days from now
  @State private var isSaving: Bool = false
  @State private var showSuccessCheckmark: Bool = false

  // Focus states for automatic focus in sheets and inline inputs
  @FocusState private var isNameFocused: Bool
  @FocusState private var isDescFocused: Bool
  @FocusState private var isEvidenceFocused: Bool
  @FocusState private var isEditFocused: Bool
  @FocusState private var isEstimatedValueFocused: Bool

  @State private var selectedType: EventType = .boolean

  private var canSave: Bool {
    !eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !eventDesc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    NavigationView {
      ScrollView {
        Spacer()
          .frame(height: 16)

        VStack(spacing: 32) {
          // Event Details section
          VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Event Details")

            VStack(spacing: 24) {
              FormField("Name") {
                FormButton(
                  text: eventName,
                  placeholder: "Enter name",
                  action: { showingNameSheet = true }
                )
                .accessibilityLabel("Event Name")
                .accessibilityHint(
                  "Tap to open full screen text editor for event name"
                )
                .accessibilityValue(
                  eventName.isEmpty ? "Not entered" : eventName
                )
              }

              FormField("Description") {
                FormButton(
                  text: eventDesc,
                  placeholder: "Enter description",
                  action: { showingDescSheet = true }
                )
                .accessibilityLabel("Event Description")
                .accessibilityHint(
                  "Tap to open full screen text editor for event description"
                )
                .accessibilityValue(
                  eventDesc.isEmpty ? "Not entered" : eventDesc
                )
              }

              FormField("Date") {
                DatePicker(
                  "Due",
                  selection: $dueDate,
                  displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .formDatePickerStyle()
              }

              FormField("Confidence Level") {
                FormPicker(selection: $confidenceLevel) {
                  ForEach(
                    Array(stride(from: 0, through: 100, by: 10)),
                    id: \.self
                  ) { value in
                    Text("\(value)%").tag(Double(value))
                  }
                }
              }

              FormField("Type") {
                FormPicker(selection: $selectedType) {
                  Text("Boolean").tag(EventType.boolean)
                  Text("Numeric").tag(EventType.numeric)
                }
              }

              if selectedType == .boolean {
                FormField("Estimated Value") {
                  FormPicker(selection: $booleanValue) {
                    Text("Yes").tag("Yes")
                    Text("No").tag("No")
                  }
                }
              }

              if selectedType == .numeric {
                VStack(alignment: .leading, spacing: 8) {
                  FormField("Estimated Value") {
                    FormTextField(
                      "Enter numeric value",
                      text: $estimatedValue,
                      keyboardType: .decimalPad,
                      isFocused: $isEstimatedValueFocused
                    )
                    .accessibilityLabel("Numeric Estimated Value")
                    .accessibilityHint(
                      "Enter a numeric value. Double tap to activate keyboard input."
                    )
                  }

                  // Acceptance Area Display
                  if settings.shouldShowAcceptanceArea,
                    let numericValue = Double(estimatedValue),
                    !estimatedValue.isEmpty
                  {
                    let acceptanceArea = settings.calculateAcceptanceArea(
                      for: numericValue
                    )

                    Text(
                      "Acceptance area is \(acceptanceArea.lower, specifier: "%.2f") to \(acceptanceArea.upper, specifier: "%.2f")"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                  }
                }
                .animation(
                  DesignTokens.Animation.slow,
                  value: settings.shouldShowAcceptanceArea
                )
                .animation(
                  DesignTokens.Animation.slow,
                  value: estimatedValue
                )
              }
            }
          }

          // Context section
          VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Context")

            VStack(spacing: 24) {
              FormField("Pressure Level") {
                FormPicker(selection: $pressureLevel) {
                  Text("Low").tag("Low")
                  Text("Medium").tag("Medium")
                  Text("High").tag("High")
                }
              }

              FormField("Current Mood") {
                FormPicker(selection: $currentMood) {
                  Text("Poor").tag("Poor")
                  Text("Fair").tag("Fair")
                  Text("Good").tag("Good")
                  Text("Excellent").tag("Excellent")
                }
              }

              FormField("Takes Medicine") {
                FormPicker(selection: $takesMedicine) {
                  Text("No").tag("No")
                  Text("Yes").tag("Yes")
                }
              }
            }
          }

          // Supporting Evidence section
          VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Evidence") {
              showingEvidenceSheet = true
            }

            if evidenceList.isEmpty {
              Text("No evidence added yet")
                .formLabelStyle()
            } else {
              List {
                ForEach(Array(evidenceList.enumerated()), id: \.offset) {
                  index,
                  evidence in
                  Text(evidence)
                    .foregroundColor(.primary)
                    .listRowInsets(
                      EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                      Button(action: {
                        evidenceList.remove(at: index)
                      }) {
                        Label("Delete", systemImage: "trash")
                      }
                      .tint(.gray)

                      Button(action: {
                        editingText = evidence
                        editingIndex = index
                        showingEditSheet = true
                      }) {
                        Label("Edit", systemImage: "pencil")
                      }
                      .tint(.primary)
                    }
                }
              }
              .listStyle(PlainListStyle())
              .frame(height: CGFloat(evidenceList.count * 48))
              .scrollDisabled(true)
            }
          }
        }
        .padding(.horizontal)

        Spacer()
          .frame(height: 64)

        HStack(spacing: 12) {
          PrimaryButton(isSaving ? "Saving..." : "Record") {
            guard canSave else { return }

            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            Task {
              await savePrediction()
            }
          }
          .disabled(!canSave || isSaving)

          if showSuccessCheckmark {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.green)
              .font(.title2)
              .transition(.scale.combined(with: .opacity))
          }
        }
        .animation(
          .spring(response: 0.5, dampingFraction: 0.8),
          value: showSuccessCheckmark
        )

        Spacer()
          .frame(height: 64)
      }
      .contentShape(Rectangle())
      .onTapGesture {
        // Hide keyboard when tapping outside of input fields
        if isEstimatedValueFocused {
          isEstimatedValueFocused = false
        }
      }
      .simultaneousGesture(
        DragGesture(minimumDistance: 20)
          .onChanged { _ in
            // Hide keyboard when scrolling
            if isEstimatedValueFocused {
              isEstimatedValueFocused = false
            }
          }
      )
      .navigationTitle("Add Prediction")
      .sheet(isPresented: $showingNameSheet) {
        FormSheet(
          title: "Event Name",
          text: $eventName,
          isFocused: $isNameFocused,
          onCancel: { showingNameSheet = false },
          onSave: { showingNameSheet = false }
        )
        .task {
          // Clear any existing focus states first
          isEstimatedValueFocused = false

          // Wait longer for sheet animation to complete
          try? await Task.sleep(nanoseconds: 600_000_000)  // 0.6 seconds delay
          isNameFocused = true
        }
      }
      .sheet(isPresented: $showingDescSheet) {
        FormSheet(
          title: "Event Description",
          text: $eventDesc,
          isFocused: $isDescFocused,
          onCancel: { showingDescSheet = false },
          onSave: { showingDescSheet = false }
        )
        .task {
          // Clear any existing focus states first
          isEstimatedValueFocused = false

          // Wait longer for sheet animation to complete
          try? await Task.sleep(nanoseconds: 600_000_000)  // 0.6 seconds delay
          isDescFocused = true
        }
      }
      .sheet(isPresented: $showingEvidenceSheet) {
        FormSheet(
          title: "Add Evidence",
          text: $newEvidence,
          isFocused: $isEvidenceFocused,
          saveButtonTitle: "Add",
          canSave: !newEvidence.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty,
          onCancel: {
            newEvidence = ""
            showingEvidenceSheet = false
          },
          onSave: {
            if !newEvidence.trimmingCharacters(in: .whitespacesAndNewlines)
              .isEmpty
            {
              evidenceList.append(
                newEvidence.trimmingCharacters(in: .whitespacesAndNewlines)
              )
              newEvidence = ""
            }
            showingEvidenceSheet = false
          }
        )
        .task {
          // Clear any existing focus states first
          isEstimatedValueFocused = false

          // Wait longer for sheet animation to complete
          try? await Task.sleep(nanoseconds: 600_000_000)  // 0.6 seconds delay
          isEvidenceFocused = true
        }
      }
      .sheet(isPresented: $showingEditSheet) {
        FormSheet(
          title: "Edit Evidence",
          text: $editingText,
          isFocused: $isEditFocused,
          saveButtonTitle: "Save",
          canSave: !editingText.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty,
          onCancel: {
            editingText = ""
            editingIndex = nil
            showingEditSheet = false
          },
          onSave: {
            if let index = editingIndex,
              !editingText.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            {
              evidenceList[index] = editingText.trimmingCharacters(
                in: .whitespacesAndNewlines
              )
            }
            editingText = ""
            editingIndex = nil
            showingEditSheet = false
          }
        )
        .task {
          // Clear any existing focus states first
          isEstimatedValueFocused = false

          // Wait longer for sheet animation to complete
          try? await Task.sleep(nanoseconds: 600_000_000)  // 0.6 seconds delay
          isEditFocused = true
        }
      }
    }
  }

  // MARK: - Save Function
  @MainActor
  private func savePrediction() async {
    isSaving = true

    do {
      let predictionService = PredictionService(modelContext: modelContext)
      try await predictionService.createPrediction(
        eventName: eventName.trimmingCharacters(in: .whitespacesAndNewlines),
        eventDescription: eventDesc.trimmingCharacters(
          in: .whitespacesAndNewlines
        ),
        confidenceLevel: confidenceLevel,
        estimatedValue: estimatedValue,
        booleanValue: booleanValue,
        pressureLevel: pressureLevel,
        currentMood: currentMood,
        takesMedicine: takesMedicine,
        evidenceList: evidenceList,
        selectedType: selectedType,
        dueDate: dueDate
      )

      isSaving = false

      // Show success checkmark with haptic feedback
      let successFeedback = UINotificationFeedbackGenerator()
      successFeedback.notificationOccurred(.success)

      withAnimation {
        showSuccessCheckmark = true
      }

      // Hide checkmark and dismiss after delay
      try await Task.sleep(nanoseconds: 1_200_000_000)  // 1.2 seconds

      withAnimation {
        showSuccessCheckmark = false
      }

      try await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds for animation

      // Reset form and dismiss
      resetForm()
      dismiss()

    } catch {
      print("Failed to save prediction: \(error)")
      isSaving = false

      // Error haptic feedback
      let errorFeedback = UINotificationFeedbackGenerator()
      errorFeedback.notificationOccurred(.error)

      // You might want to show an error alert here
    }
  }

  private func resetForm() {
    eventName = ""
    eventDesc = ""
    confidenceLevel = 50
    estimatedValue = ""
    booleanValue = "Yes"
    pressureLevel = "Low"
    currentMood = "Good"
    takesMedicine = "No"
    evidenceList = []
    selectedType = .boolean
    dueDate = Date().addingTimeInterval(86400 * 30)
    showSuccessCheckmark = false
  }
}

#Preview {
  PredictionFormView()
    .modelContainer(for: Prediction.self, inMemory: true)
}
