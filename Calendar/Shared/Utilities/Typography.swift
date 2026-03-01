import SwiftUI

// MARK: - Typography Scale
// Consistent type scale used across all views

public struct Typography {
  /// 28pt bold — screen titles like "February 2026"
  static let largeTitle = Font.system(size: 30, weight: .bold, design: .rounded)

  /// 20pt semibold — section headers
  static let title = Font.system(size: 22, weight: .semibold, design: .rounded)

  /// 16pt semibold — event names, card titles
  static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)

  /// 15pt regular — descriptions, notes
  static let body = Font.system(size: 16, weight: .regular, design: .rounded)

  /// 14pt medium — secondary info rows
  static let subheadline = Font.system(size: 14, weight: .medium, design: .rounded)

  /// 12pt regular — timestamps, secondary info
  static let caption = Font.system(size: 12, weight: .regular, design: .rounded)

  /// 11pt medium — status badges, counts
  static let badge = Font.system(size: 11, weight: .medium, design: .rounded)

  /// Monospaced for timer displays
  static func timer(size: CGFloat = 64) -> Font {
    .system(size: size, weight: .bold, design: .monospaced)
  }
}
