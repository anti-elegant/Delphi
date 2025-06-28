import SwiftData
import SwiftUI
import UIKit

// MARK: - Main View
struct PredictionFormView: View {
  // MARK: - Environment & Dependencies
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @StateObject private var settings = SettingsStore.shared

  // MARK: - Form State
  @State private var eventName: String = ""
  @State private var eventDesc: String = ""
  @State private var confidenceLevel: Double = 50 {
    didSet {
      // Ensure confidence level stays within valid range
      if confidenceLevel < 0 {
        confidenceLevel = 0
      } else if confidenceLevel > 100 {
        confidenceLevel = 100
      }
    }
  }
  @State private var estimatedValue: String = ""
  @State private var booleanValue: String = "Yes"
  @State private var pressureLevel: String = "Low"
  @State private var currentMood: String = "Good"
  @State private var takesMedicine: String = "No"
  @State private var evidenceList: [String] = []
  @State private var newEvidence: String = ""
  @State private var dueDate: Date =
    Calendar.current.date(byAdding: .day, value: 30, to: Date())
    ?? Date().addingTimeInterval(86400 * 30)
  @State private var selectedType: EventType = .boolean

  // MARK: - UI State
  @State private var showingEvidenceInput: Bool = false
  @State private var editingIndex: Int? = nil
  @State private var editingText: String = ""
  @State private var showingNameSheet: Bool = false
  @State private var showingDescSheet: Bool = false
  @State private var showingEvidenceSheet: Bool = false
  @State private var showingEditSheet: Bool = false
  @State private var isSaving: Bool = false
  @State private var showSuccessCheckmark: Bool = false

  // MARK: - Focus States
  @FocusState private var isNameFocused: Bool
  @FocusState private var isDescFocused: Bool
  @FocusState private var isEvidenceFocused: Bool
  @FocusState private var isEditFocused: Bool
  @FocusState private var isEstimatedValueFocused: Bool

  // MARK: - Computed Properties
  private var canSave: Bool {
    !eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !eventDesc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var shouldShowAcceptanceArea: Bool {
    settings.shouldShowAcceptanceArea && selectedType == .numeric
      && !estimatedValue.isEmpty && Double(estimatedValue) != nil
  }

  // MARK: - Body
  var body: some View {
    NavigationView {
      ScrollView {
        Spacer()
          .frame(height: 16)

        VStack(spacing: 32) {
          eventDetailsSection
          contextSection
          evidenceSection
        }
        .padding(.horizontal)

        Spacer()
          .frame(height: 64)

        saveButtonSection

        Spacer()
          .frame(height: 64)
      }
      .ignoresSafeArea(.keyboard)
      .contentShape(Rectangle())
      .onTapGesture {
        dismissKeyboard()
      }
      .simultaneousGesture(
        DragGesture(minimumDistance: 20)
          .onChanged { _ in
            dismissKeyboard()
          }
      )
      .navigationTitle("Add Prediction")
      .sheet(isPresented: $showingNameSheet) {
        nameSheet
      }
      .sheet(isPresented: $showingDescSheet) {
        descriptionSheet
      }
      .sheet(isPresented: $showingEvidenceSheet) {
        evidenceSheet
      }
      .sheet(isPresented: $showingEditSheet) {
        editEvidenceSheet
      }
    }
  }
}

// MARK: - View Components
extension PredictionFormView {

  fileprivate var eventDetailsSection: some View {
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
          .accessibilityValue(eventName.isEmpty ? "Not entered" : eventName)
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
          .accessibilityValue(eventDesc.isEmpty ? "Not entered" : eventDesc)
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

        estimatedValueField
      }
    }
  }

  fileprivate var estimatedValueField: some View {
    Group {
      if selectedType == .boolean {
        FormField("Estimated Value") {
          FormPicker(selection: $booleanValue) {
            Text("Yes").tag("Yes")
            Text("No").tag("No")
          }
        }
      } else {
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

          if shouldShowAcceptanceArea {
            acceptanceAreaDisplay
          }
        }
        .animation(
          DesignTokens.Animation.slow,
          value: settings.shouldShowAcceptanceArea
        )
        .animation(DesignTokens.Animation.slow, value: estimatedValue)
      }
    }
  }

  fileprivate var acceptanceAreaDisplay: some View {
    Group {
      if let numericValue = Double(estimatedValue) {
        let acceptanceArea = settings.calculateAcceptanceArea(for: numericValue)

        Text(
          "Acceptance area is \(acceptanceArea.lower, specifier: "%.2f") to \(acceptanceArea.upper, specifier: "%.2f")"
        )
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.leading, 12)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
  }

  fileprivate var contextSection: some View {
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
  }

  fileprivate var evidenceSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      SectionHeader("Evidence") {
        showingEvidenceSheet = true
      }

      if evidenceList.isEmpty {
        Text("No evidence added yet")
          .formLabelStyle()
      } else {
        evidenceListView
      }
    }
  }

  fileprivate var evidenceListView: some View {
    LazyVStack(spacing: 0) {
      ForEach(Array(evidenceList.enumerated()), id: \.offset) {
        index,
        evidence in
        EvidenceRow(
          evidence: evidence,
          onEdit: {
            editingText = evidence
            editingIndex = index
            showingEditSheet = true
          },
          onDelete: {
            evidenceList.remove(at: index)
          }
        )

        if index < evidenceList.count - 1 {
          Divider()
            .padding(.horizontal, 12)
        }
      }
    }
    .background(DesignTokens.Colors.cardBackground)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(
          DesignTokens.Colors.cardBorder,
          lineWidth: DesignTokens.BorderWidth.thin
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  fileprivate var saveButtonSection: some View {
    HStack(spacing: 12) {
      PrimaryButton(isSaving ? "Saving..." : "Record") {
        guard canSave else { return }

        provideFeedback(.impact(.medium))

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
  }
}

// MARK: - Sheet Views
extension PredictionFormView {

  fileprivate var nameSheet: some View {
    FormSheet(
      title: "Event Name",
      text: $eventName,
      isFocused: $isNameFocused,
      onCancel: { showingNameSheet = false },
      onSave: { showingNameSheet = false }
    )
    .task {
      await prepareSheetFocus { isNameFocused = true }
    }
  }

  fileprivate var descriptionSheet: some View {
    FormSheet(
      title: "Event Description",
      text: $eventDesc,
      isFocused: $isDescFocused,
      onCancel: { showingDescSheet = false },
      onSave: { showingDescSheet = false }
    )
    .task {
      await prepareSheetFocus { isDescFocused = true }
    }
  }

  fileprivate var evidenceSheet: some View {
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
        addEvidence()
        showingEvidenceSheet = false
      }
    )
    .task {
      await prepareSheetFocus { isEvidenceFocused = true }
    }
  }

  fileprivate var editEvidenceSheet: some View {
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
        saveEditedEvidence()
        showingEditSheet = false
      }
    )
    .task {
      await prepareSheetFocus { isEditFocused = true }
    }
  }
}

// MARK: - Helper Methods
extension PredictionFormView {

  fileprivate func dismissKeyboard() {
    if isEstimatedValueFocused {
      isEstimatedValueFocused = false
    }
  }

  fileprivate func provideFeedback(_ feedback: FeedbackType) {
    switch feedback {
    case .impact(let style):
      let impactFeedback = UIImpactFeedbackGenerator(style: style)
      impactFeedback.impactOccurred()
    case .notification(let type):
      let notificationFeedback = UINotificationFeedbackGenerator()
      notificationFeedback.notificationOccurred(type)
    }
  }

  fileprivate func prepareSheetFocus(focusAction: @escaping () -> Void) async {
    // Clear any existing focus states first
    isEstimatedValueFocused = false

    // Wait for sheet animation to complete
    try? await Task.sleep(nanoseconds: 600_000_000)  // 0.6 seconds delay
    focusAction()
  }

  fileprivate func addEvidence() {
    let trimmedEvidence = newEvidence.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    if !trimmedEvidence.isEmpty {
      evidenceList.append(trimmedEvidence)
      newEvidence = ""
    }
  }

  fileprivate func saveEditedEvidence() {
    guard let index = editingIndex else { return }

    let trimmedText = editingText.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    if !trimmedText.isEmpty {
      evidenceList[index] = trimmedText
    }

    editingText = ""
    editingIndex = nil
  }

  fileprivate func resetForm() {
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
    dueDate =
      Calendar.current.date(byAdding: .day, value: 30, to: Date())
      ?? Date().addingTimeInterval(86400 * 30)
    showSuccessCheckmark = false
  }
}

// MARK: - Business Logic
extension PredictionFormView {

  @MainActor
  fileprivate func savePrediction() async {
    isSaving = true

    // Ensure PredictionStore has the model context
    PredictionStore.shared.setModelContext(modelContext)

    await PredictionStore.shared.createPrediction(
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

    // Check for errors
    if PredictionStore.shared.lastError != nil {
      await handleSaveError(PredictionStore.shared.lastError!)
    } else {
      await handleSuccessfulSave()
    }
  }

  @MainActor
  private func handleSuccessfulSave() async {
    // Show success checkmark
    withAnimation {
      showSuccessCheckmark = true
    }

    // Hide checkmark and dismiss after delay
    try? await Task.sleep(nanoseconds: 1_200_000_000)  // 1.2 seconds

    withAnimation {
      showSuccessCheckmark = false
    }

    try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds for animation

    // Reset form and dismiss
    resetForm()
    dismiss()
  }

  @MainActor
  private func handleSaveError(_ error: Error) async {
    print("Failed to save prediction: \(error)")
    isSaving = false

    // You might want to show an error alert here
  }
}

// MARK: - Supporting Components
struct EvidenceRow: View {
  let evidence: String
  let onEdit: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Text(evidence)
        .evidenceTextStyle()
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)  // Allow text to expand vertically

      HStack(spacing: 8) {
        Button(action: {
          // Add haptic feedback
          let impactFeedback = UIImpactFeedbackGenerator(style: .light)
          impactFeedback.impactOccurred()
          onEdit()
        }) {
          Image(systemName: "pencil")
            .font(.caption)
            .foregroundColor(.primary)
            .frame(width: 32, height: 32)
            .background(Color(.systemGray6))
            .clipShape(Circle())
        }

        Button(action: {
          // Add haptic feedback
          let impactFeedback = UIImpactFeedbackGenerator(style: .light)
          impactFeedback.impactOccurred()
          onDelete()
        }) {
          Image(systemName: "trash")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(width: 32, height: 32)
            .background(Color(.systemGray6))
            .clipShape(Circle())
        }
      }
      .padding(.top, 2)  // Align buttons with first line of text
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 16)
  }
}

// MARK: - Supporting Types
private enum FeedbackType {
  case impact(UIImpactFeedbackGenerator.FeedbackStyle)
  case notification(UINotificationFeedbackGenerator.FeedbackType)
}

// MARK: - Preview
#Preview {
  PredictionFormView()
    .modelContainer(for: Prediction.self, inMemory: true)
}
