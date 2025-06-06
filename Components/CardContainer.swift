import SwiftUI

struct CardContainer<Content: View>: View {
  let content: () -> Content
  let height: CGFloat?
  let padding: CGFloat

  init(
    height: CGFloat? = nil,
    padding: CGFloat = DesignTokens.Spacing.cardPadding,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.height = height
    self.padding = padding
    self.content = content
  }

  var body: some View {
    VStack {
      content()
    }
    .frame(height: height)
    .cardStyle(padding: padding)
  }
}

#Preview {
  VStack(spacing: DesignTokens.Spacing.lg) {
    CardContainer(height: 128) {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
        Text("Sample Card")
          .font(.cardTitle)
        Text(
          "This is a sample card with consistent styling using design tokens"
        )
        .font(.bodyText)
        .foregroundColor(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }

    CardContainer {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
        Text("Dynamic Height Card")
          .font(.cardTitle)
        Text(
          "This card adjusts its height based on content. The padding and styling are consistent across all cards."
        )
        .font(.bodyText)
        .foregroundColor(.secondary)
        Text("Additional content line to demonstrate automatic sizing.")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }

    CardContainer(padding: DesignTokens.Spacing.xl) {
      Text("Custom Padding Card")
        .font(.cardTitle)
        .frame(maxWidth: .infinity, alignment: .center)
    }
  }
  .padding()
}
