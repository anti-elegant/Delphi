import SwiftUI

struct FormSheet: View {
  let title: String
  let text: Binding<String>
  let isFocused: FocusState<Bool>.Binding
  let onCancel: () -> Void
  let onSave: () -> Void
  let saveButtonTitle: String
  let canSave: Bool

  init(
    title: String,
    text: Binding<String>,
    isFocused: FocusState<Bool>.Binding,
    saveButtonTitle: String = "Done",
    canSave: Bool = true,
    onCancel: @escaping () -> Void,
    onSave: @escaping () -> Void
  ) {
    self.title = title
    self.text = text
    self.isFocused = isFocused
    self.saveButtonTitle = saveButtonTitle
    self.canSave = canSave
    self.onCancel = onCancel
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      TextEditor(text: text)
        .font(.formInput)
        .lineSpacing(DesignTokens.Spacing.xs)
        .focused(isFocused)
        .padding(DesignTokens.Spacing.lg)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel", action: onCancel)
              .font(.toolbarButton)
          }
          ToolbarItem(placement: .navigationBarTrailing) {
            Button(saveButtonTitle, action: onSave)
              .font(.toolbarButton)
              .disabled(!canSave)
          }
        }
    }
    .task {
      try? await Task.sleep(nanoseconds: 500_000_000)
      isFocused.wrappedValue = true
    }
  }
}

#Preview {
  @Previewable @State var text = "Sample text content for FormSheet preview"
  @FocusState var isFocused: Bool

  return FormSheet(
    title: "Edit Text",
    text: $text,
    isFocused: $isFocused,
    onCancel: {},
    onSave: {}
  )
  .frame(height: 300)
}
