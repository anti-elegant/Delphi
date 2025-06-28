import SwiftUI

struct FormField<Content: View>: View {
  let label: String
  let content: () -> Content

  init(_ label: String, @ViewBuilder content: @escaping () -> Content) {
    self.label = label
    self.content = content
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.formSpacing) {
      Text(label)
        .formLabelStyle()
      content()
    }
  }
}

#Preview {
  VStack(spacing: DesignTokens.Spacing.lg) {
    FormField("Text Input") {
      Text("Sample text content")
        .font(.formInput)
        .formTextFieldStyle()
    }

    FormField("Multiple Line Field") {
      VStack(spacing: DesignTokens.Spacing.sm) {
        Text("First line of content")
          .font(.formInput)
        Text("Second line of content")
          .font(.formInput)
      }
      .formTextFieldStyle()
    }

    FormField("Custom Content") {
      HStack {
        Text("Custom")
        Spacer()
        Text("Layout")
      }
      .formTextFieldStyle()
    }
  }
  .padding()
}
