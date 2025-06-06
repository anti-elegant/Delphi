import Charts
import SwiftUI

struct ChartData {
  let category: String
  let value: Double
}

struct AnalyticsCard: View {
  let metric: AnalyticsMetric

  private var requiresMoreData: Bool {
    metric.isLocked
  }

  var body: some View {
    CardContainer {
      VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 8) {
          Image(systemName: metric.icon)
            .font(.iconFont)
            .foregroundColor(.secondary)

          Text(metric.title)
            .cardTitleStyle()
        }

        if requiresMoreData {
          HStack {
            Text("N/A")
              .metricUnitStyle()

            Spacer()
          }
        } else {
          HStack(alignment: .firstTextBaseline) {
            Text(metric.value)
              .metricValueStyle()

            Text(metric.unit)
              .metricUnitStyle()

            Spacer()

            Chart {
              SectorMark(
                angle: .value("Completed", metric.percentage),
                innerRadius: .ratio(0.65),
                angularInset: 2.0
              )
              .cornerRadius(8)

              SectorMark(
                angle: .value("Remaining", 1.0 - metric.percentage),
                innerRadius: .ratio(0.65),
                angularInset: 2.0
              )
              .cornerRadius(8)
              .foregroundStyle(Color(red: 0.85, green: 0.85, blue: 0.85))
            }
            .frame(width: 48, height: 48)
          }
        }
      }
    }
  }
}

struct AnalyticsView: View {
  @StateObject private var analyticsStore = AnalyticsStore.shared
  @State private var selectedMetric: AnalyticsMetric?

  var body: some View {
    NavigationView {
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
      .listStyle(PlainListStyle())
      .navigationTitle("Analytics")
      .sheet(item: $selectedMetric) { metric in
        AnalyticsDetailSheet(metric: metric)
      }
    }
  }
}

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
      return (Color.primary, Color.gray.opacity(0.15))
    }
  }

  private var isLocked: Bool {
    metric.isLocked
  }

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 32) {
          // Header with icon and title
          HStack(spacing: 16) {
            Image(systemName: metric.icon)
              .font(.largeIcon)
              .foregroundColor(iconColors.foreground)
              .frame(width: 48, height: 48)
              .background(iconColors.background)
              .clipShape(Circle())

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

          // Description
          VStack(alignment: .leading, spacing: 16) {
            Text("About This Metric")
              .font(.subsectionTitle)
              .foregroundColor(.primary)

            Text(metric.description)
              .bodyTextStyle()
              .lineSpacing(4)
          }
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

#Preview {
  AnalyticsView()
}
