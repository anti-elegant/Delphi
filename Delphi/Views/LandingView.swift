import SwiftUI

struct LandingView: View {
  @State private var showMainApp = false
  @State private var imageOpacity = 0.0
  @State private var imageBlur = 10.0
  @State private var textOpacity = 0.0
  @State private var textBlur = 10.0
  @State private var buttonOpacity = 0.0
  @State private var buttonBlur = 10.0

  var body: some View {
    if showMainApp {
      ContentView()
    } else {
      VStack {
        Spacer()

        VStack(spacing: 24) {
          Image(systemName: "brain.head.profile")
            .font(.system(size: 72, weight: .light))
            .foregroundColor(.secondary)
            .opacity(imageOpacity)
            .blur(radius: imageBlur)

          Text("What’s on your mind?")
            .font(.system(size: 24, weight: .medium, design: .serif))
            .foregroundColor(.secondary)
            .opacity(textOpacity)
            .blur(radius: textBlur)
        }

        Spacer()

        PrimaryButton("Continue") {
          // Provide haptic feedback
          let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
          impactFeedback.impactOccurred()

          withAnimation(DesignTokens.Animation.landingTransition) {
            showMainApp = true
          }
        }
        .padding(.bottom, 48)
        .opacity(buttonOpacity)
        .blur(radius: buttonBlur)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(UIColor.systemBackground))
      .onAppear {
        // Animate the image first with initial delay
        withAnimation(DesignTokens.Animation.landingImage.delay(0.2)) {
          imageOpacity = 1.0
          imageBlur = 0.0
        }

        // Animate the text with a slight delay
        withAnimation(DesignTokens.Animation.landingText.delay(0.3)) {
          textOpacity = 1.0
          textBlur = 0.0
        }

        // Animate the button last
        withAnimation(DesignTokens.Animation.landingButton.delay(0.5)) {
          buttonOpacity = 1.0
          buttonBlur = 0.0
        }
      }
    }
  }
}

#Preview {
  LandingView()
}
