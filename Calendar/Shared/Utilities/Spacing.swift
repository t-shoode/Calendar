import SwiftUI

enum AppSpacing {
  static let xxxs: CGFloat = 2
  static let xxs: CGFloat = 4
  static let xs: CGFloat = 8
  static let sm: CGFloat = 12
  static let md: CGFloat = 16
  static let lg: CGFloat = 20
  static let xl: CGFloat = 24
  static let xxl: CGFloat = 32
  static let xxxl: CGFloat = 48

  static let cardPadding: CGFloat = 18
  static let sectionSpacing: CGFloat = 24
}

enum AppRadius {
  static let small: CGFloat = 10
  static let card: CGFloat = 16
  static let large: CGFloat = 20
  static let sheet: CGFloat = 24
}

enum AppElevation {
  static let none: CGFloat = 0
  static let low: CGFloat = 6
  static let medium: CGFloat = 10
}

enum AppMotion {
  static let quick = Animation.easeInOut(duration: 0.16)
  static let standard = Animation.easeInOut(duration: 0.22)
  static let emphasis = Animation.spring(response: 0.26, dampingFraction: 0.9)
}

// MARK: - Spacing Tokens
// Standardized spacing values referenced everywhere instead of hardcoded magic numbers

struct Spacing {
  static let xxxs: CGFloat = AppSpacing.xxxs
  static let xxs: CGFloat = AppSpacing.xxs
  static let xs: CGFloat = AppSpacing.xs
  static let sm: CGFloat = AppSpacing.sm
  static let md: CGFloat = AppSpacing.md
  static let lg: CGFloat = AppSpacing.lg
  static let xl: CGFloat = AppSpacing.xl
  static let xxl: CGFloat = AppSpacing.xxl
  static let xxxl: CGFloat = AppSpacing.xxxl

  /// Standard card padding
  static let cardPadding: CGFloat = AppSpacing.cardPadding
  /// Standard section spacing
  static let sectionSpacing: CGFloat = AppSpacing.sectionSpacing
  /// Standard corner radius for cards
  static let cardRadius: CGFloat = AppRadius.card
  /// Small corner radius for inline elements
  static let smallRadius: CGFloat = AppRadius.small
  /// Large corner radius for sheets/modals
  static let sheetRadius: CGFloat = AppRadius.sheet
}
