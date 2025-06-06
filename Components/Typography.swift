import SwiftUI

extension Font {
  // MARK: - Section & Header Fonts
  static let sectionHeader = Font.system(
    size: 22,
    weight: .bold,
    design: .serif
  )
  static let cardTitle = Font.system(
    size: 18,
    weight: .semibold,
    design: .serif
  )
  static let detailTitle = Font.system(
    size: 28,
    weight: .bold,
    design: .serif
  )
  static let subsectionTitle = Font.system(
    size: 20,
    weight: .semibold,
    design: .serif
  )

  // MARK: - Body Text Fonts
  static let bodyText = Font.system(
    size: 16,
    weight: .regular,
    design: .serif
  )
  static let bodyTextMedium = Font.system(
    size: 16,
    weight: .medium,
    design: .serif
  )

  // MARK: - Form & Input Fonts
  static let formLabel = Font.system(size: 14, weight: .medium)
  static let formInput = Font.system(size: 16, weight: .regular)

  // MARK: - Metric & Analytics Fonts
  static let metricValue = Font.system(
    size: 28,
    weight: .bold,
    design: .rounded
  )
  static let metricSecondaryValue = Font.system(
    size: 20,
    weight: .semibold,
    design: .rounded
  )
  static let metricUnit = Font.system(
    size: 14,
    weight: .medium,
    design: .rounded
  )
  static let metricDescription = Font.system(
    size: 18,
    weight: .medium,
    design: .rounded
  )

  // MARK: - UI Element Fonts
  static let buttonText = Font.system(size: 18, weight: .semibold)
  static let toolbarButton = Font.system(size: 16, weight: .medium)
  static let iconFont = Font.system(size: 18, weight: .medium)
  static let largeIcon = Font.system(size: 32, weight: .medium)
}

// MARK: - Text View Extensions for Common Styles
extension Text {
  func sectionHeaderStyle() -> some View {
    self
      .font(.sectionHeader)
      .foregroundColor(.primary)
  }

  func cardTitleStyle() -> some View {
    self
      .font(.cardTitle)
      .foregroundColor(.primary)
  }

  func bodyTextStyle() -> some View {
    self
      .font(.bodyText)
      .foregroundColor(.secondary)
  }

  func formLabelStyle() -> some View {
    self
      .font(.formLabel)
      .foregroundColor(.secondary)
  }

  func metricValueStyle() -> some View {
    self
      .font(.metricValue)
      .foregroundColor(.primary)
  }

  func metricUnitStyle() -> some View {
    self
      .font(.metricUnit)
      .foregroundColor(.secondary)
  }
}

#Preview {
  VStack(alignment: .leading, spacing: 16) {
    Text("Section Header").sectionHeaderStyle()
    Text("Card Title").cardTitleStyle()
    Text("Body text content").bodyTextStyle()
    Text("Form Label").formLabelStyle()
    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
      Text("73.2%").metricValueStyle()
      Text("PCC").metricUnitStyle()
    }
  }
  .padding()
}
