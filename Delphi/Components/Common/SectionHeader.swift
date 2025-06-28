import SwiftUI

struct SectionHeader: View {
  let title: String
  let action: (() -> Void)?

  init(_ title: String, action: (() -> Void)? = nil) {
    self.title = title
    self.action = action
  }

  var body: some View {
    HStack {
      Text(title)
        .sectionHeaderStyle()

      Spacer()

      if let action = action {
        Button(action: action) {
          Image(systemName: "plus.circle.fill")
            .font(.sectionHeader)
            .foregroundColor(Color(.label))
        }
      }
    }
  }
}

#Preview {
  VStack(spacing: DesignTokens.Spacing.lg) {
    SectionHeader("Sample Section")
    SectionHeader("Section with Action") {}
  }
}
