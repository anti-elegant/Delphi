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
  @Previewable @State var text =
    "Sample text content that demonstrates the FormSheet component with multi-line text editing capabilities."
  @Previewable @State var emptyText = ""
  @FocusState var isFocused: Bool

  return VStack(spacing: DesignTokens.Spacing.lg) {
    Text("FormSheet Preview")
      .font(.sectionHeader)

    Text("Tap the buttons below to see FormSheet in action")
      .font(.bodyText)
      .foregroundColor(.secondary)

    // Note: In a real app, these would open as sheets
    // This is just to show the structure
    FormSheet(
      title: "Edit Text",
      text: $text,
      isFocused: $isFocused,
      onCancel: {},
      onSave: {}
    )
    .frame(height: 200)
  }
  .padding()
}
