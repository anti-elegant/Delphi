import SwiftUI

// MARK: - Design Tokens
/// Centralized design system tokens for consistent styling across the app
enum DesignTokens {

  // MARK: - Spacing & Layout
  enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32

    // Form-specific spacing - standardized for consistent visual height
    // Using EdgeInsets for precise control over horizontal vs vertical padding
    static let formPadding = EdgeInsets(
      top: 8,
      leading: 0,
      bottom: 8,
      trailing: 0
    )  // For pickers, buttons
    static let formTextPadding = EdgeInsets(
      top: 14.5,
      leading: 12,
      bottom: 14.5,
      trailing: 12
    )  // For text inputs
    static let formDatePadding = EdgeInsets(
      top: 8,
      leading: 12,
      bottom: 8,
      trailing: 8
    )  // For date pickers

    static let formSpacing: CGFloat = sm
    static let cardPadding: CGFloat = lg
  }

  // MARK: - Corner Radius
  enum CornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20

    // Component-specific radius
    static let form: CGFloat = md
    static let card: CGFloat = md
    static let button: CGFloat = lg
  }

  // MARK: - Border Width
  enum BorderWidth {
    static let thin: CGFloat = 1
    static let medium: CGFloat = 2
    static let thick: CGFloat = 3

    // State-specific widths
    static let formDefault: CGFloat = thin
    static let formFocused: CGFloat = medium
  }

  // MARK: - Colors
  enum Colors {
    // Form colors
    static let formBorder = Color.gray.opacity(0.2)
    static let formBorderFocused = Color.accentColor
    static let formBackground = Color.clear
    static let formPlaceholder = Color.secondary.opacity(0.4)

    // Card colors (using asset catalog colors)
    static let cardBackground = Color("CardBackground")
    static let cardBorder = Color("CardBorder")
    static let screenBackground = Color("ScreenBackground")

    // Button colors
    static let buttonPrimary = Color.accentColor
    static let buttonDisabled = Color.gray
    static let buttonText = Color.white
  }

  // MARK: - Animation
  enum Animation {
    static let fast = SwiftUI.Animation.easeInOut(duration: 0.15)
    static let standard = SwiftUI.Animation.easeInOut(duration: 0.2)
    static let slow = SwiftUI.Animation.easeInOut(duration: 0.3)

    // Landing page animations - longer durations for smooth entrance
    static let landingTransition = SwiftUI.Animation.easeInOut(duration: 0.6)
    static let landingImage = SwiftUI.Animation.easeOut(duration: 0.8)
    static let landingText = SwiftUI.Animation.easeOut(duration: 0.6)
    static let landingButton = SwiftUI.Animation.easeOut(duration: 0.5)

    // Component-specific animations
    static let formFocus = standard
    static let buttonPress = fast
  }

  // MARK: - Button Sizing
  enum ButtonSize {
    static let defaultWidth: CGFloat = 280  // More reasonable than screen-based calculation
    static let fullWidth: CGFloat? = nil
    static let height: CGFloat = 52
  }
}

// MARK: - Form Field Styling Extensions
extension View {

  /// Base form field styling - creates consistent outer border and appearance
  private func baseFormFieldStyle(isFocused: Bool = false, padding: EdgeInsets)
    -> some View
  {
    self
      .padding(padding)
      .background(DesignTokens.Colors.formBackground)
      .overlay(
        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.form)
          .stroke(
            isFocused
              ? DesignTokens.Colors.formBorderFocused
              : DesignTokens.Colors.formBorder,
            lineWidth: isFocused
              ? DesignTokens.BorderWidth.formFocused
              : DesignTokens.BorderWidth.formDefault
          )
      )
  }

  /// Standard form field styling for pickers and buttons
  func formFieldStyle(isFocused: Bool = false) -> some View {
    baseFormFieldStyle(
      isFocused: isFocused,
      padding: DesignTokens.Spacing.formPadding
    )
  }

  /// Text input form field styling with adjusted padding for consistent height
  func formTextFieldStyle(isFocused: Bool = false) -> some View {
    baseFormFieldStyle(
      isFocused: isFocused,
      padding: DesignTokens.Spacing.formTextPadding
    )
  }

  /// Date picker form field styling with system-appropriate padding
  func formDatePickerStyle(isFocused: Bool = false) -> some View {
    baseFormFieldStyle(
      isFocused: isFocused,
      padding: DesignTokens.Spacing.formDatePadding
    )
  }

  /// Apply standard card styling
  func cardStyle(padding: CGFloat = DesignTokens.Spacing.cardPadding)
    -> some View
  {
    self
      .padding(padding)
      .background(DesignTokens.Colors.cardBackground)
      .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card))
      .overlay(
        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
          .stroke(
            DesignTokens.Colors.cardBorder,
            lineWidth: DesignTokens.BorderWidth.thin
          )
      )
  }

  /// Apply standard button styling
  func primaryButtonStyle(
    isEnabled: Bool = true,
    width: CGFloat? = DesignTokens.ButtonSize.defaultWidth
  ) -> some View {
    self
      .frame(maxWidth: width == nil ? .infinity : width)
      .frame(height: DesignTokens.ButtonSize.height)
      .background(
        isEnabled
          ? DesignTokens.Colors.buttonPrimary
          : DesignTokens.Colors.buttonDisabled
      )
      .foregroundColor(DesignTokens.Colors.buttonText)
      .cornerRadius(DesignTokens.CornerRadius.button)
      .animation(DesignTokens.Animation.buttonPress, value: isEnabled)
  }
}

// MARK: - Shared DateFormatter Extensions
extension DateFormatter {
  /// Standard medium date formatter (e.g., "Jan 1, 2024")
  static let mediumDate: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
  }()

  /// Standard short date formatter (e.g., "1/1/24")
  static let shortDate: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter
  }()

  /// Standard long date formatter (e.g., "January 1, 2024")
  static let longDate: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    return formatter
  }()

  /// Time only formatter (e.g., "3:30 PM")
  static let timeOnly: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
  }()

  /// Full date and time formatter (e.g., "Jan 1, 2024 at 3:30 PM")
  static let mediumDateTime: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()
}
