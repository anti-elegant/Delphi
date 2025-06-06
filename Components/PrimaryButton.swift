import SwiftUI

struct PrimaryButton: View {
  let title: String
  let action: () -> Void
  let width: CGFloat?
  let isFullWidth: Bool
  @Environment(\.isEnabled) private var isEnabled

  init(
    _ title: String,
    width: CGFloat? = nil,
    isFullWidth: Bool = false,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.width = width
    self.isFullWidth = isFullWidth
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.buttonText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.md)
    }
    .primaryButtonStyle(
      isEnabled: isEnabled,
      width: isFullWidth ? nil : (width ?? DesignTokens.ButtonSize.defaultWidth)
    )
  }
}

#Preview {
  VStack(spacing: DesignTokens.Spacing.lg) {
    PrimaryButton("Default Button") {
      print("Default button tapped")
    }

    PrimaryButton("Custom Width", width: 200) {
      print("Custom width button tapped")
    }

    PrimaryButton("Full Width", isFullWidth: true) {
      print("Full width button tapped")
    }

    PrimaryButton("Disabled") {
      print("Should not print")
    }
    .disabled(true)
  }
  .padding()
}
