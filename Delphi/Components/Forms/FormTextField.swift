import SwiftUI

struct FormTextField: View {
  let placeholder: String
  let text: Binding<String>
  let keyboardType: UIKeyboardType
  let isFocused: FocusState<Bool>.Binding

  init(
    _ placeholder: String,
    text: Binding<String>,
    keyboardType: UIKeyboardType = .default,
    isFocused: FocusState<Bool>.Binding
  ) {
    self.placeholder = placeholder
    self.text = text
    self.keyboardType = keyboardType
    self.isFocused = isFocused
  }

  var body: some View {
    ZStack(alignment: .leading) {
      // Custom placeholder
      if text.wrappedValue.isEmpty {
        Text(placeholder)
          .font(.formInput)
          .foregroundColor(DesignTokens.Colors.formPlaceholder)
          .allowsHitTesting(false)
      }

      TextField("", text: text)
        .font(.formInput)
        .keyboardType(keyboardType)
        .focused(isFocused)
    }
    .formTextFieldStyle(isFocused: isFocused.wrappedValue)
    .animation(DesignTokens.Animation.formFocus, value: isFocused.wrappedValue)
    .onTapGesture {
      isFocused.wrappedValue = true
    }
  }
}

#Preview {
  @Previewable @State var text = ""
  @Previewable @State var numberText = ""
  @FocusState var isFocused: Bool
  @FocusState var isNumberFocused: Bool

  return VStack(spacing: DesignTokens.Spacing.lg) {
    FormTextField("Enter text", text: $text, isFocused: $isFocused)

    FormTextField(
      "Enter number",
      text: $numberText,
      keyboardType: .numberPad,
      isFocused: $isNumberFocused
    )

    FormTextField(
      "Prefilled text",
      text: .constant("Sample content"),
      isFocused: $isFocused
    )
  }
  .padding()
}
