import SwiftUI

struct FormButton: View {
  let text: String
  let placeholder: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: DesignTokens.Spacing.md) {
        Text(text.isEmpty ? placeholder : text)
          .font(.formInput)
          .foregroundColor(
            text.isEmpty ? DesignTokens.Colors.formPlaceholder : .primary
          )
          .frame(maxWidth: .infinity, alignment: .leading)
          .lineLimit(1)

        Image(systemName: "pencil")
          .foregroundColor(.secondary)
          .font(.iconFont)
      }
    }
    .buttonStyle(PlainButtonStyle())
    .formTextFieldStyle()
  }
}

#Preview {
  VStack(spacing: DesignTokens.Spacing.lg) {
    FormButton(
      text: "",
      placeholder: "Tap to enter text",
      action: {}
    )

    FormButton(
      text: "Sample filled text that demonstrates the component with content",
      placeholder: "Tap to enter text",
      action: {}
    )

    FormButton(
      text: "Short text",
      placeholder: "Tap to enter text",
      action: {}
    )
  }
  .padding()
}
