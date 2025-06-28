import SwiftUI

struct FormPicker<SelectionValue: Hashable, Content: View>: View {
  let selection: Binding<SelectionValue>
  let content: () -> Content

  init(
    selection: Binding<SelectionValue>,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.selection = selection
    self.content = content
  }

  var body: some View {
    Picker("", selection: selection) {
      content()
    }
    .font(.formInput)
    .frame(maxWidth: .infinity, alignment: .leading)
    .formFieldStyle()
  }
}

#Preview {
  @Previewable @State var selection = "Option 1"
  @Previewable @State var numberSelection = 1

  return VStack(spacing: DesignTokens.Spacing.lg) {
    FormPicker(selection: $selection) {
      Text("Option 1").tag("Option 1")
      Text("Option 2").tag("Option 2")
      Text("Long Option Name That Tests Layout").tag("Option 3")
    }

    FormPicker(selection: $numberSelection) {
      Text("One").tag(1)
      Text("Two").tag(2)
      Text("Three").tag(3)
    }
  }
  .padding()
}
