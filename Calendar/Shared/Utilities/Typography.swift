import SwiftUI

enum AppTypography {
  static let largeTitle = Font.system(size: 30, weight: .bold)
  static let title = Font.system(size: 22, weight: .semibold)
  static let headline = Font.system(size: 17, weight: .semibold)
  static let body = Font.system(size: 16, weight: .regular)
  static let subheadline = Font.system(size: 14, weight: .medium)
  static let caption = Font.system(size: 12, weight: .regular)
  static let badge = Font.system(size: 11, weight: .medium)

  static func timer(size: CGFloat = 64) -> Font {
    .system(size: size, weight: .bold, design: .monospaced)
  }
}

// MARK: - Typography Scale
// Consistent type scale used across all views

public struct Typography {
  /// 28pt bold — screen titles like "February 2026"
  static let largeTitle = AppTypography.largeTitle

  /// 20pt semibold — section headers
  static let title = AppTypography.title

  /// 16pt semibold — event names, card titles
  static let headline = AppTypography.headline

  /// 15pt regular — descriptions, notes
  static let body = AppTypography.body

  /// 14pt medium — secondary info rows
  static let subheadline = AppTypography.subheadline

  /// 12pt regular — timestamps, secondary info
  static let caption = AppTypography.caption

  /// 11pt medium — status badges, counts
  static let badge = AppTypography.badge

  /// Monospaced for timer displays
  static func timer(size: CGFloat = 64) -> Font {
    AppTypography.timer(size: size)
  }
}
