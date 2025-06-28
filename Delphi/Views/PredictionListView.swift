import SwiftData
import SwiftUI

// MARK: - Supporting Card Views
struct PredictionCard: View {
  let prediction: Prediction

  var body: some View {
    CardContainer(height: 128) {
      VStack(alignment: .leading, spacing: 8) {
        Text(prediction.eventName)
          .cardTitleStyle()
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)

        Text(prediction.eventDescription)
          .bodyTextStyle()
          .lineLimit(3)
          .multilineTextAlignment(.leading)
          .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
          )

        HStack {
          Spacer()

          if prediction.isPending {
            Text("Due in \(prediction.daysToDue) days")
              .font(.caption)
              .foregroundColor(.secondary)
          } else {
            Text(prediction.formattedDueDate)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
    }
  }
}

struct ResolvedPredictionCard: View {
  let prediction: Prediction

  private var predictionStatus:
    (wasCorrect: Bool, statusColor: Color, statusText: String)
  {
    guard let actualOutcome = prediction.actualOutcome else {
      return (false, .red, "Incorrect")
    }

    let wasCorrect: Bool
    switch prediction.selectedType {
    case .boolean:
      wasCorrect = actualOutcome == prediction.booleanValue
    case .numeric:
      wasCorrect = actualOutcome == prediction.estimatedValue
    }

    return (
      wasCorrect,
      wasCorrect ? .green : .red,
      wasCorrect ? "Correct" : "Incorrect"
    )
  }

  var body: some View {
    CardContainer(height: 128) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(prediction.eventName)
            .cardTitleStyle()
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

          Text(predictionStatus.statusText)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(predictionStatus.statusColor.opacity(0.15))
            .foregroundColor(predictionStatus.statusColor)
            .clipShape(Capsule())
        }

        Text(prediction.eventDescription)
          .bodyTextStyle()
          .lineLimit(2)
          .multilineTextAlignment(.leading)
          .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
          )

        HStack {
          Text(
            "Confidence: \(Int(Swift.max(0, Swift.min(100, prediction.confidenceLevel))))%"
          )
          .font(.caption)
          .foregroundColor(.secondary)

          Spacer()

          if let resolutionDate = prediction.formattedResolutionDate {
            Text("Resolved \(resolutionDate)")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
    }
  }
}

// MARK: - Stacked Card Views
struct StackedCardView: View {
  let predictions: [Prediction]
  let isExpanded: Bool
  let onCardTap: (Prediction) -> Void

  var body: some View {
    ZStack(alignment: .topLeading) {
      if !isExpanded && predictions.count > 1 {
        stackBackgroundCard
      }

      PredictionCard(prediction: predictions[0])
        .contentShape(Rectangle())
        .onTapGesture {
          onCardTap(predictions[0])
        }
    }
  }

  private var stackBackgroundCard: some View {
    HStack {
      Spacer()
      RoundedRectangle(cornerRadius: 12)
        .fill(DesignTokens.Colors.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(
              DesignTokens.Colors.cardBorder,
              lineWidth: DesignTokens.BorderWidth.thin
            )
        )
        .frame(height: 128)
    }
    .offset(y: 40)
  }
}

struct ResolvedStackedCardView: View {
  let predictions: [Prediction]
  let isExpanded: Bool
  let onCardTap: (Prediction) -> Void

  var body: some View {
    ZStack(alignment: .topLeading) {
      if !isExpanded && predictions.count > 1 {
        stackBackgroundCard
      }

      ResolvedPredictionCard(prediction: predictions[0])
        .contentShape(Rectangle())
        .onTapGesture {
          onCardTap(predictions[0])
        }
    }
  }

  private var stackBackgroundCard: some View {
    HStack {
      Spacer()
      RoundedRectangle(cornerRadius: 12)
        .fill(DesignTokens.Colors.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(
              DesignTokens.Colors.cardBorder,
              lineWidth: DesignTokens.BorderWidth.thin
            )
        )
        .frame(height: 128)
    }
    .offset(y: 40)
  }
}

// MARK: - Section Header Component
struct CollapsibleSectionHeader: View {
  let title: String
  let itemCount: Int
  let isExpanded: Bool
  let onToggle: () -> Void

  var body: some View {
    HStack {
      Text(title)
        .sectionHeaderStyle()

      Spacer()

      if itemCount > 1 {
        HStack(spacing: 4) {
          Text("\(itemCount) items")
            .font(.caption)
            .foregroundColor(.secondary)

          Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundColor(.secondary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray5))
        .clipShape(Capsule())
        .onTapGesture {
          onToggle()
        }
      }
    }
  }
}

// MARK: - Detail Sheet
struct PredictionDetailSheet: View {
  let prediction: Prediction
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  private var statusInfo: (color: Color, text: String) {
    if prediction.isResolved {
      return (.green, "Resolved")
    } else if prediction.isOverdue {
      return (.red, "Overdue")
    } else {
      return (.orange, "Pending")
    }
  }

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 32) {
          headerSection
          predictionDetailsSection
          contextSection

          if !prediction.evidenceList.isEmpty {
            evidenceSection
          }
        }
        .padding(24)
      }
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          actionsMenu
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .font(.toolbarButton)
        }
      }
    }
  }
}

// MARK: - Detail Sheet Components
extension PredictionDetailSheet {

  fileprivate var headerSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 12) {
        Text(statusInfo.text)
          .font(.caption)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(statusInfo.color.opacity(0.15))
          .foregroundColor(statusInfo.color)
          .clipShape(Capsule())

        Text(prediction.eventName)
          .font(.detailTitle)
          .foregroundColor(.primary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Text(prediction.eventDescription)
        .bodyTextStyle()
        .lineSpacing(4)
    }
  }

  fileprivate var predictionDetailsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Prediction Details")
        .font(.subsectionTitle)
        .foregroundColor(.primary)

      VStack(alignment: .leading, spacing: 8) {
        DetailRow(
          label: "Confidence Level",
          value: "\(Int(prediction.confidenceLevel))%"
        )

        if prediction.selectedType == .boolean {
          DetailRow(label: "Predicted Outcome", value: prediction.booleanValue)
        } else {
          DetailRow(label: "Estimated Value", value: prediction.estimatedValue)
        }

        DetailRow(label: "Due Date", value: prediction.formattedDueDate)
        DetailRow(
          label: "Created",
          value: DateFormatter.mediumDate.string(from: prediction.dateCreated)
        )
      }
    }
  }

  fileprivate var contextSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Context")
        .font(.subsectionTitle)
        .foregroundColor(.primary)

      VStack(alignment: .leading, spacing: 8) {
        DetailRow(label: "Pressure Level", value: prediction.pressureLevel)
        DetailRow(label: "Mood", value: prediction.currentMood)
        DetailRow(label: "Takes Medicine", value: prediction.takesMedicine)
      }
    }
  }

  fileprivate var evidenceSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Evidence")
        .font(.subsectionTitle)
        .foregroundColor(.primary)

      VStack(alignment: .leading, spacing: 8) {
        ForEach(prediction.evidenceList, id: \.self) { evidence in
          HStack(alignment: .top, spacing: 8) {
            Text("•")
              .bodyTextStyle()
            Text(evidence)
              .bodyTextStyle()
              .lineSpacing(4)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
    }
  }

  fileprivate var actionsMenu: some View {
    Menu {
      if !prediction.isResolved {
        Button {
          markAsCorrect()
        } label: {
          Label("Mark as Correct", systemImage: "checkmark.circle")
        }

        Button {
          markAsWrong()
        } label: {
          Label("Mark as Wrong", systemImage: "xmark.circle")
        }

        Divider()
      }

      Button(role: .destructive) {
        deletePrediction()
      } label: {
        Label("Delete", systemImage: "trash")
      }
    } label: {
      Image(systemName: "ellipsis.circle")
        .font(.toolbarButton)
    }
  }
}

// MARK: - Detail Row Component
struct DetailRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack {
      Text(label)
        .bodyTextStyle()
      Spacer()
      Text(value)
        .bodyTextStyle()
    }
  }
}

// MARK: - Detail Sheet Actions
extension PredictionDetailSheet {

  fileprivate func markAsCorrect() {
    provideFeedback(.impact(.medium))

    Task {
      let correctOutcome =
        prediction.selectedType == .boolean
        ? prediction.booleanValue : prediction.estimatedValue
      await resolvePrediction(with: correctOutcome)
    }
  }

  fileprivate func markAsWrong() {
    provideFeedback(.impact(.medium))

    Task {
      let wrongOutcome =
        prediction.selectedType == .boolean
        ? (prediction.booleanValue == "Yes" ? "No" : "Yes") : "Incorrect"
      await resolvePrediction(with: wrongOutcome)
    }
  }

  fileprivate func deletePrediction() {
    provideFeedback(.notification(.warning))

    Task {
      await performDeletePrediction()
    }
  }

  @MainActor
  private func resolvePrediction(with outcome: String) async {
    // Ensure PredictionStore has the model context
    PredictionStore.shared.setModelContext(modelContext)

    await PredictionStore.shared.resolvePrediction(
      prediction,
      actualOutcome: outcome
    )

    if PredictionStore.shared.lastError != nil {
      print(
        "Failed to resolve prediction: \(PredictionStore.shared.lastError!)"
      )
    } else {
      dismiss()
    }
  }

  @MainActor
  private func performDeletePrediction() async {
    // Ensure PredictionStore has the model context
    PredictionStore.shared.setModelContext(modelContext)

    await PredictionStore.shared.deletePrediction(prediction)

    if PredictionStore.shared.lastError != nil {
      print("Failed to delete prediction: \(PredictionStore.shared.lastError!)")
    } else {
      dismiss()
    }
  }

  private func provideFeedback(_ feedback: FeedbackType) {
    switch feedback {
    case .impact(let style):
      let impactFeedback = UIImpactFeedbackGenerator(style: style)
      impactFeedback.impactOccurred()
    case .notification(let type):
      let notificationFeedback = UINotificationFeedbackGenerator()
      notificationFeedback.notificationOccurred(type)
    }
  }
}

// MARK: - Main List View
struct PredictionListView: View {
  // MARK: - Environment & Dependencies
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Prediction.dateCreated, order: .reverse) private
    var allPredictions: [Prediction]

  // MARK: - State
  @State private var isOverdueExpanded = false
  @State private var isResolvedExpanded = false
  @State private var selectedPrediction: Prediction?

  // MARK: - Computed Properties
  private var overduePredictions: [Prediction] {
    allPredictions.filter { $0.isOverdue }
  }

  private var pendingPredictions: [Prediction] {
    allPredictions.filter { $0.isPending && !$0.isOverdue }
  }

  private var resolvedPredictions: [Prediction] {
    allPredictions.filter { $0.isResolved }
  }

  // MARK: - Body
  var body: some View {
    NavigationView {
      ZStack {
        List {
          if !pendingPredictions.isEmpty {
            pendingSectionList
          }

          if !overduePredictions.isEmpty {
            overdueSectionList
          }

          if !resolvedPredictions.isEmpty {
            resolvedSectionList
          }
        }
        .listStyle(PlainListStyle())

        if allPredictions.isEmpty {
          VStack(spacing: 16) {
            Image(systemName: "pencil.and.scribble")
              .font(.system(size: 48))
              .foregroundColor(.secondary)

            Text("No predictions yet")
              .bodyTextStyle()
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .navigationTitle("All Predictions")
      .navigationBarTitleDisplayMode(.large)
      .sheet(item: $selectedPrediction) { prediction in
        PredictionDetailSheet(prediction: prediction)
      }
      .onReceive(
        NotificationCenter.default.publisher(for: .showPredictionDetail)
      ) { notification in
        handleNotificationResponse(notification)
      }
      .onReceive(
        NotificationCenter.default.publisher(
          for: .resolvePredictionFromNotification
        )
      ) { notification in
        handleResolveFromNotification(notification)
      }
    }
  }
}

// MARK: - List Sections
extension PredictionListView {

  fileprivate var pendingSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      SectionHeader("Pending")
        .padding(.horizontal, 16)

      ForEach(pendingPredictions, id: \.id) { prediction in
        PredictionCard(prediction: prediction)
          .padding(.horizontal, 16)
          .onTapGesture {
            selectedPrediction = prediction
          }
      }
    }
  }

  fileprivate var overdueSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      CollapsibleSectionHeader(
        title: "Overdue",
        itemCount: overduePredictions.count,
        isExpanded: isOverdueExpanded
      ) {
        withAnimation(.easeInOut(duration: 0.3)) {
          isOverdueExpanded.toggle()
        }
      }
      .padding(.horizontal, 16)

      VStack(spacing: 16) {
        StackedCardView(
          predictions: overduePredictions,
          isExpanded: isOverdueExpanded
        ) { prediction in
          selectedPrediction = prediction
        }
        .padding(.horizontal, 16)

        if isOverdueExpanded {
          expandedOverdueCards
        }
      }
    }
  }

  fileprivate var resolvedSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      CollapsibleSectionHeader(
        title: "Resolved",
        itemCount: resolvedPredictions.count,
        isExpanded: isResolvedExpanded
      ) {
        withAnimation(.easeInOut(duration: 0.3)) {
          isResolvedExpanded.toggle()
        }
      }
      .padding(.horizontal, 16)

      VStack(spacing: 16) {
        ResolvedStackedCardView(
          predictions: resolvedPredictions,
          isExpanded: isResolvedExpanded
        ) { prediction in
          selectedPrediction = prediction
        }
        .padding(.horizontal, 16)

        if isResolvedExpanded {
          expandedResolvedCards
        }
      }
    }
  }

  fileprivate var expandedOverdueCards: some View {
    ForEach(
      Array(overduePredictions.dropFirst().enumerated()),
      id: \.element.id
    ) { index, prediction in
      PredictionCard(prediction: prediction)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .onTapGesture {
          selectedPrediction = prediction
        }
    }
  }

  fileprivate var expandedResolvedCards: some View {
    ForEach(
      Array(resolvedPredictions.dropFirst().enumerated()),
      id: \.element.id
    ) { index, prediction in
      ResolvedPredictionCard(prediction: prediction)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .onTapGesture {
          selectedPrediction = prediction
        }
    }
  }

  // MARK: - List-Compatible Sections
  fileprivate var pendingSectionList: some View {
    Section {
      ForEach(pendingPredictions, id: \.id) { prediction in
        PredictionCard(prediction: prediction)
          .listRowInsets(
            EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
          )
          .listRowSeparator(.hidden)
          .listRowBackground(Color.clear)
          .contentShape(Rectangle())
          .onTapGesture {
            selectedPrediction = prediction
          }
      }
    } header: {
      SectionHeader("Pending")
        .textCase(nil)
    }
  }

  fileprivate var overdueSectionList: some View {
    Section {
      StackedCardView(
        predictions: overduePredictions,
        isExpanded: isOverdueExpanded
      ) { prediction in
        selectedPrediction = prediction
      }
      .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
      .listRowSeparator(.hidden)
      .listRowBackground(Color.clear)
      .contentShape(Rectangle())

      if isOverdueExpanded {
        ForEach(
          Array(overduePredictions.dropFirst().enumerated()),
          id: \.element.id
        ) { index, prediction in
          PredictionCard(prediction: prediction)
            .listRowInsets(
              EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .contentShape(Rectangle())
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .onTapGesture {
              selectedPrediction = prediction
            }
        }
      }
    } header: {
      CollapsibleSectionHeader(
        title: "Overdue",
        itemCount: overduePredictions.count,
        isExpanded: isOverdueExpanded
      ) {
        withAnimation(.easeInOut(duration: 0.3)) {
          isOverdueExpanded.toggle()
        }
      }
      .textCase(nil)
    }
  }

  fileprivate var resolvedSectionList: some View {
    Section {
      ResolvedStackedCardView(
        predictions: resolvedPredictions,
        isExpanded: isResolvedExpanded
      ) { prediction in
        selectedPrediction = prediction
      }
      .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
      .listRowSeparator(.hidden)
      .listRowBackground(Color.clear)
      .contentShape(Rectangle())

      if isResolvedExpanded {
        ForEach(
          Array(resolvedPredictions.dropFirst().enumerated()),
          id: \.element.id
        ) { index, prediction in
          ResolvedPredictionCard(prediction: prediction)
            .listRowInsets(
              EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .contentShape(Rectangle())
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .onTapGesture {
              selectedPrediction = prediction
            }
        }
      }
    } header: {
      CollapsibleSectionHeader(
        title: "Resolved",
        itemCount: resolvedPredictions.count,
        isExpanded: isResolvedExpanded
      ) {
        withAnimation(.easeInOut(duration: 0.3)) {
          isResolvedExpanded.toggle()
        }
      }
      .textCase(nil)
    }
  }

  // MARK: - Notification Handlers
  private func handleNotificationResponse(
    _ notification: Foundation.Notification
  ) {
    guard let predictionId = notification.userInfo?["predictionId"] as? UUID,
      let prediction = allPredictions.first(where: { $0.id == predictionId })
    else {
      return
    }

    // Already on main thread in view context
    selectedPrediction = prediction
  }

  private func handleResolveFromNotification(
    _ notification: Foundation.Notification
  ) {
    guard let predictionId = notification.userInfo?["predictionId"] as? UUID,
      let outcome = notification.userInfo?["outcome"] as? String,
      let prediction = allPredictions.first(where: { $0.id == predictionId })
    else {
      return
    }

    Task {
      await resolvePredictionFromNotification(prediction, outcome: outcome)
    }
  }

  @MainActor
  private func resolvePredictionFromNotification(
    _ prediction: Prediction,
    outcome: String
  ) async {
    // Ensure PredictionStore has the model context
    PredictionStore.shared.setModelContext(modelContext)

    await PredictionStore.shared.resolvePrediction(
      prediction,
      actualOutcome: outcome
    )

    if PredictionStore.shared.lastError != nil {
      print(
        "Failed to resolve prediction from notification: \(PredictionStore.shared.lastError!)"
      )
    }
  }
}

// MARK: - Supporting Types
private enum FeedbackType {
  case impact(UIImpactFeedbackGenerator.FeedbackStyle)
  case notification(UINotificationFeedbackGenerator.FeedbackType)
}

// MARK: - Preview
#Preview {
  PredictionListView()
    .modelContainer(for: Prediction.self, inMemory: true)
}
