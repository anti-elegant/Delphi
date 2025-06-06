import SwiftData
import SwiftUI

struct PredictionCard: View {
  let prediction: Prediction

  var body: some View {
    CardContainer(height: 128) {
      VStack(alignment: .leading, spacing: 8) {
        Text(prediction.eventName)
          .cardTitleStyle()
          .lineLimit(1)
          .frame(
            maxWidth: .infinity,
            alignment: .leading
          )

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

  private var wasCorrect: Bool {
    guard let actualOutcome = prediction.actualOutcome else { return false }

    switch prediction.selectedType {
    case .boolean:
      return actualOutcome == "Correct"
    case .numeric:
      return actualOutcome == prediction.estimatedValue
    }
  }

  private var statusColor: Color {
    return wasCorrect ? .green : .red
  }

  private var statusText: String {
    return wasCorrect ? "Correct" : "Incorrect"
  }

  var body: some View {
    CardContainer(height: 128) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(prediction.eventName)
            .cardTitleStyle()
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

          Text(statusText)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .foregroundColor(statusColor)
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
          Text("Confidence: \(Int(prediction.confidenceLevel))%")
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

struct StackedCardView: View {
  let predictions: [Prediction]
  let isExpanded: Bool
  let onCardTap: (Prediction) -> Void

  var body: some View {
    ZStack(alignment: .topLeading) {
      // Background stack rectangles (only when collapsed and multiple cards)
      if !isExpanded && predictions.count > 1 {
        // Second card background (middle, medium width)
        if predictions.count > 1 {
          HStack {
            Spacer()
            RoundedRectangle(cornerRadius: 12)
              .fill(Color("CardBackground"))
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .stroke(
                    Color("CardBorder"),
                    lineWidth: DesignTokens.BorderWidth.thin
                  )
              )
              .frame(height: 128)
          }
          .offset(y: 40)
        }
      }

      // Main card (always on top, full width)
      PredictionCard(prediction: predictions[0])
        .onTapGesture {
          onCardTap(predictions[0])
        }
    }
  }
}

struct ResolvedStackedCardView: View {
  let predictions: [Prediction]
  let isExpanded: Bool
  let onCardTap: (Prediction) -> Void

  var body: some View {
    ZStack(alignment: .topLeading) {
      // Background stack rectangles (only when collapsed and multiple cards)
      if !isExpanded && predictions.count > 1 {
        // Second card background (middle, medium width)
        if predictions.count > 1 {
          HStack {
            Spacer()
            RoundedRectangle(cornerRadius: 12)
              .fill(Color("CardBackground"))
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .stroke(
                    Color("CardBorder"),
                    lineWidth: DesignTokens.BorderWidth.thin
                  )
              )
              .frame(height: 128)
          }
          .offset(y: 40)
        }
      }

      // Main card (always on top, full width)
      ResolvedPredictionCard(prediction: predictions[0])
        .onTapGesture {
          onCardTap(predictions[0])
        }
    }
  }
}

struct PredictionDetailSheet: View {
  let prediction: Prediction
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  private var statusColor: Color {
    if prediction.isResolved {
      return .green
    } else if prediction.isOverdue {
      return .red
    } else {
      return .orange
    }
  }

  private var statusText: String {
    if prediction.isResolved {
      return "Resolved"
    } else if prediction.isOverdue {
      return "Overdue"
    } else {
      return "Pending"
    }
  }

  private func markAsCorrect() {
    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    impactFeedback.impactOccurred()

    Task {
      do {
        let predictionService = PredictionService(modelContext: modelContext)
        try await predictionService.resolvePrediction(
          prediction,
          actualOutcome: "Correct"
        )
        dismiss()
      } catch {
        print("Failed to mark prediction as correct: \(error)")
      }
    }
  }

  private func markAsWrong() {
    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    impactFeedback.impactOccurred()

    Task {
      do {
        let predictionService = PredictionService(modelContext: modelContext)
        try await predictionService.resolvePrediction(
          prediction,
          actualOutcome: "Incorrect"
        )
        dismiss()
      } catch {
        print("Failed to mark prediction as wrong: \(error)")
      }
    }
  }

  private func deletePrediction() {
    let notificationFeedback = UINotificationFeedbackGenerator()
    notificationFeedback.notificationOccurred(.warning)

    Task {
      do {
        let predictionService = PredictionService(modelContext: modelContext)
        try await predictionService.deletePrediction(prediction)
        dismiss()
      } catch {
        print("Failed to delete prediction: \(error)")
      }
    }
  }

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 32) {
          // Header with status
          VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
              Text(statusText)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.15))
                .foregroundColor(statusColor)
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

          // Prediction Details
          VStack(alignment: .leading, spacing: 16) {
            Text("Prediction Details")
              .font(.subsectionTitle)
              .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text("Confidence Level")
                  .bodyTextStyle()
                Spacer()
                Text("\(Int(prediction.confidenceLevel))%")
                  .bodyTextStyle()
              }

              if prediction.selectedType == .boolean {
                HStack {
                  Text("Predicted Outcome")
                    .bodyTextStyle()
                  Spacer()
                  Text(prediction.booleanValue)
                    .bodyTextStyle()
                }
              } else {
                HStack {
                  Text("Estimated Value")
                    .bodyTextStyle()
                  Spacer()
                  Text(prediction.estimatedValue)
                    .bodyTextStyle()
                }
              }

              HStack {
                Text("Due Date")
                  .bodyTextStyle()
                Spacer()
                Text(prediction.formattedDueDate)
                  .bodyTextStyle()
              }

              HStack {
                Text("Created")
                  .bodyTextStyle()
                Spacer()
                Text(
                  DateFormatter.shortDate.string(from: prediction.dateCreated)
                )
                .bodyTextStyle()
              }
            }
          }

          // Context Information
          VStack(alignment: .leading, spacing: 16) {
            Text("Context")
              .font(.subsectionTitle)
              .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text("Pressure Level")
                  .bodyTextStyle()
                Spacer()
                Text(prediction.pressureLevel)
                  .bodyTextStyle()
              }

              HStack {
                Text("Mood")
                  .bodyTextStyle()
                Spacer()
                Text(prediction.currentMood)
                  .bodyTextStyle()
              }

              HStack {
                Text("Takes Medicine")
                  .bodyTextStyle()
                Spacer()
                Text(prediction.takesMedicine)
                  .bodyTextStyle()
              }
            }
          }

          // Evidence
          if !prediction.evidenceList.isEmpty {
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

        }
        .padding(24)
      }
      .background(Color("ScreenBackground"))
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
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

struct PredictionListView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Prediction.dateCreated, order: .reverse) private
    var allPredictions: [Prediction]
  @State private var isOverdueExpanded = false
  @State private var isResolvedExpanded = false
  @State private var selectedPrediction: Prediction?

  var overduePredictions: [Prediction] {
    allPredictions.filter { $0.isOverdue }
  }

  var pendingPredictions: [Prediction] {
    allPredictions.filter { $0.isPending && !$0.isOverdue }
  }

  var resolvedPredictions: [Prediction] {
    allPredictions.filter { $0.isResolved }
  }

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 32) {
          // Pending predictions section
          if !pendingPredictions.isEmpty {
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

          // Overdue predictions section with stacking animation
          if !overduePredictions.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
              HStack {
                Text("Overdue")
                  .sectionHeaderStyle()

                Spacer()

                if overduePredictions.count > 1 {
                  HStack(spacing: 4) {
                    Text("\(overduePredictions.count) items")
                      .font(.caption)
                      .foregroundColor(.secondary)

                    Image(systemName: "chevron.right")
                      .font(.caption2)
                      .foregroundColor(.secondary)
                      .rotationEffect(.degrees(isOverdueExpanded ? 90 : 0))
                  }
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(Color.gray.opacity(0.2))
                  .clipShape(Capsule())
                  .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                      isOverdueExpanded.toggle()
                    }
                  }
                }
              }
              .padding(.horizontal, 16)

              VStack(spacing: 16) {
                // Stacked card view (collapsed) or first card (expanded)
                StackedCardView(
                  predictions: overduePredictions,
                  isExpanded: isOverdueExpanded
                ) { prediction in
                  selectedPrediction = prediction
                }
                .padding(.horizontal, 16)

                // Additional cards when expanded
                if isOverdueExpanded {
                  ForEach(
                    Array(overduePredictions.dropFirst().enumerated()),
                    id: \.element.id
                  ) { index, prediction in
                    PredictionCard(prediction: prediction)
                      .padding(.horizontal, 16)
                      .transition(.opacity.combined(with: .scale(scale: 0.95)))
                      .onTapGesture {
                        selectedPrediction = prediction
                      }
                  }
                }
              }
            }
          }

          // Resolved predictions section with stacking animation
          if !resolvedPredictions.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
              HStack {
                Text("Resolved")
                  .sectionHeaderStyle()

                Spacer()

                if resolvedPredictions.count > 1 {
                  HStack(spacing: 4) {
                    Text("\(resolvedPredictions.count) items")
                      .font(.caption)
                      .foregroundColor(.secondary)

                    Image(systemName: "chevron.right")
                      .font(.caption2)
                      .foregroundColor(.secondary)
                      .rotationEffect(.degrees(isResolvedExpanded ? 90 : 0))
                  }
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(Color.gray.opacity(0.2))
                  .clipShape(Capsule())
                  .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                      isResolvedExpanded.toggle()
                    }
                  }
                }
              }
              .padding(.horizontal, 16)

              VStack(spacing: 16) {
                // Stacked card view (collapsed) or first card (expanded)
                ResolvedStackedCardView(
                  predictions: resolvedPredictions,
                  isExpanded: isResolvedExpanded
                ) { prediction in
                  selectedPrediction = prediction
                }
                .padding(.horizontal, 16)

                // Additional cards when expanded
                if isResolvedExpanded {
                  ForEach(
                    Array(resolvedPredictions.dropFirst().enumerated()),
                    id: \.element.id
                  ) { index, prediction in
                    ResolvedPredictionCard(prediction: prediction)
                      .padding(.horizontal, 16)
                      .transition(.opacity.combined(with: .scale(scale: 0.95)))
                      .onTapGesture {
                        selectedPrediction = prediction
                      }
                  }
                }
              }
            }
          }
        }
        .padding(.vertical, 16)
      }
      .navigationTitle("All Predictions")
      .sheet(item: $selectedPrediction) { prediction in
        PredictionDetailSheet(prediction: prediction)
      }
    }
  }
}

#Preview {
  PredictionListView()
    .modelContainer(for: Prediction.self, inMemory: true)
}
