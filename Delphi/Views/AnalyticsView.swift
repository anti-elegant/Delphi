import SwiftUI

#if canImport(Charts)
  import Charts
#endif

// MARK: - Supporting Types
struct ChartData {
  let category: String
  let value: Double
}

// MARK: - Analytics Card Component
struct AnalyticsCard: View {
  let metric: AnalyticsMetric

  private var requiresMoreData: Bool {
    metric.isLocked
  }

  var body: some View {
    CardContainer {
      VStack(alignment: .leading, spacing: 16) {
        cardHeader

        if requiresMoreData {
          lockedContent
        } else {
          metricContent
        }
      }
    }
  }
}

// MARK: - Analytics Card Components
extension AnalyticsCard {

  fileprivate var cardHeader: some View {
    HStack(spacing: 8) {
      Image(systemName: metric.icon)
        .font(.iconFont)
        .foregroundColor(.secondary)

      Text(metric.title)
        .cardTitleStyle()
    }
  }

  fileprivate var lockedContent: some View {
    HStack {
      Text("N/A")
        .metricUnitStyle()

      Spacer()
    }
  }

  fileprivate var metricContent: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(metric.value)
        .metricValueStyle()

      Text(metric.unit)
        .metricUnitStyle()

      Spacer()

      metricChart
    }
  }

  fileprivate var metricChart: some View {
    // Always use fallback chart for stability and consistency
    fallbackChart
  }

  private var fallbackChart: some View {
    ZStack {
      Circle()
        .stroke(Color.secondary, lineWidth: 8)
        .frame(width: 48, height: 48)

      Circle()
        .trim(from: 0, to: safePercentage)
        .stroke(.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
        .frame(width: 48, height: 48)
        .rotationEffect(.degrees(-90))
    }
  }

  // Safe percentage for chart rendering
  private var safePercentage: Double {
    let percentage = metric.percentage
    return Swift.max(
      0.0,
      Swift.min(1.0, percentage.isFinite ? percentage : 0.0)
    )
  }
}

// MARK: - Main Analytics View
struct AnalyticsView: View {
  @StateObject private var analyticsStore = AnalyticsStore.shared
  @State private var selectedMetric: AnalyticsMetric?

  var body: some View {
    NavigationView {
      ZStack {
        List {
          ForEach(analyticsStore.analyticsMetrics, id: \.id) { metric in
            AnalyticsCard(metric: metric)
              .listRowInsets(
                EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16)
              )
              .listRowSeparator(.hidden)
              .listRowBackground(Color.clear)
              .onTapGesture {
                selectedMetric = metric
              }
          }
        }

        if analyticsStore.analyticsMetrics.isEmpty {
          VStack(spacing: 16) {
            Image(systemName: "pencil.and.scribble")
              .font(.system(size: 48))
              .foregroundColor(.secondary)

            Text("Working in progress")
              .bodyTextStyle()
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .listStyle(PlainListStyle())
      .navigationTitle("Analytics")
      .navigationBarTitleDisplayMode(.large)
      .sheet(item: $selectedMetric) { metric in
        AnalyticsDetailSheet(metric: metric)
      }
    }
  }
}

// MARK: - Analytics Detail Sheet
struct AnalyticsDetailSheet: View {
  let metric: AnalyticsMetric
  @Environment(\.dismiss) private var dismiss

  private var iconColors: (foreground: Color, background: Color) {
    switch metric.title {
    case "Accuracy":
      return (Color.blue, Color.blue.opacity(0.15))
    case "Pressure":
      return (Color.orange, Color.orange.opacity(0.15))
    case "Mood":
      return (Color.purple, Color.purple.opacity(0.15))
    case "Medicine":
      return (Color.green, Color.green.opacity(0.15))
    default:
      return (Color.primary, Color(.systemGray5))
    }
  }

  private var isLocked: Bool {
    metric.isLocked
  }

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 32) {
          headerSection
          descriptionSection
        }
        .padding(24)
      }
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
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
extension AnalyticsDetailSheet {

  fileprivate var headerSection: some View {
    HStack(spacing: 16) {
      metricIcon
      metricInfo
    }
  }

  fileprivate var metricIcon: some View {
    Image(systemName: metric.icon)
      .font(.largeIcon)
      .foregroundColor(iconColors.foreground)
      .frame(width: 48, height: 48)
      .background(iconColors.background)
      .clipShape(Circle())
  }

  fileprivate var metricInfo: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(metric.title)
        .font(.detailTitle)
        .foregroundColor(.primary)

      if isLocked {
        Text("Record more to unlock")
          .font(.metricSecondaryValue)
          .foregroundColor(.secondary)
      } else {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(metric.value)
            .font(.metricSecondaryValue)
            .foregroundColor(.secondary)

          if !metric.unit.isEmpty {
            Text(metric.unit)
              .metricUnitStyle()
          }
        }
      }
    }
  }

  fileprivate var descriptionSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("About This Metric")
        .font(.subsectionTitle)
        .foregroundColor(.primary)

      Text(metric.description)
        .bodyTextStyle()
        .lineSpacing(4)
    }
  }
}

// MARK: - Preview
#Preview {
  AnalyticsView()
}
