import SwiftUI

#if canImport(UIKit)
  import UIKit
  typealias PlatformColor = UIColor
#elseif canImport(AppKit)
  import AppKit
  typealias PlatformColor = NSColor
#endif

// MARK: - Design System Colors
// Clean, calm surfaces with a restrained accent and category-specific colors.

extension Color {
  // MARK: - Helper for platform-specific colors
  private static func platformColor(ios: UIColorKey, mac: NSColorKey) -> Color {
    #if canImport(UIKit)
      switch ios {
      case .systemBackground: return Color(uiColor: .systemBackground)
      case .secondarySystemBackground: return Color(uiColor: .secondarySystemBackground)
      case .tertiarySystemBackground: return Color(uiColor: .tertiarySystemBackground)
      case .systemGroupedBackground: return Color(uiColor: .systemGroupedBackground)
      case .secondarySystemGroupedBackground: return Color(uiColor: .secondarySystemGroupedBackground)
      case .label: return Color(uiColor: .label)
      case .secondaryLabel: return Color(uiColor: .secondaryLabel)
      case .tertiaryLabel: return Color(uiColor: .tertiaryLabel)
      case .separator: return Color(uiColor: .separator)
      case .opaqueSeparator: return Color(uiColor: .opaqueSeparator)
      case .systemFill: return Color(uiColor: .systemFill)
      case .secondarySystemFill: return Color(uiColor: .secondarySystemFill)
      case .tertiarySystemFill: return Color(uiColor: .tertiarySystemFill)
      case .systemGray: return Color(uiColor: .systemGray)
      case .systemGray2: return Color(uiColor: .systemGray2)
      }
    #elseif canImport(AppKit)
      switch mac {
      case .windowBackgroundColor: return Color(nsColor: .windowBackgroundColor)
      case .controlBackgroundColor: return Color(nsColor: .controlBackgroundColor)
      case .textBackgroundColor: return Color(nsColor: .textBackgroundColor)
      case .underPageBackgroundColor: return Color(nsColor: .underPageBackgroundColor)
      case .labelColor: return Color(nsColor: .labelColor)
      case .secondaryLabelColor: return Color(nsColor: .secondaryLabelColor)
      case .tertiaryLabelColor: return Color(nsColor: .tertiaryLabelColor)
      case .separatorColor: return Color(nsColor: .separatorColor)
      case .gridColor: return Color(nsColor: .gridColor)
      case .controlColor: return Color(nsColor: .controlColor)
      case .selectedControlColor: return Color(nsColor: .selectedControlColor)
      case .quaternaryLabelColor: return Color(nsColor: .quaternaryLabelColor)
      case .systemGray: return Color(nsColor: .systemGray)
      }
    #else
      return .clear
    #endif
  }

  private enum UIColorKey {
    case systemBackground, secondarySystemBackground, tertiarySystemBackground, systemGroupedBackground
    case secondarySystemGroupedBackground, label, secondaryLabel, tertiaryLabel, separator, opaqueSeparator
    case systemFill, secondarySystemFill, tertiarySystemFill, systemGray, systemGray2
  }

  private enum NSColorKey {
    case windowBackgroundColor, controlBackgroundColor, textBackgroundColor, underPageBackgroundColor
    case labelColor, secondaryLabelColor, tertiaryLabelColor, separatorColor, gridColor
    case controlColor, selectedControlColor, quaternaryLabelColor, systemGray
  }

  // MARK: - Backgrounds
  static let backgroundPrimary = platformColor(ios: .systemBackground, mac: .windowBackgroundColor)
  static let backgroundSecondary = platformColor(ios: .secondarySystemBackground, mac: .controlBackgroundColor)
  static let backgroundTertiary = platformColor(ios: .tertiarySystemBackground, mac: .textBackgroundColor)
  static let backgroundGrouped = platformColor(ios: .systemGroupedBackground, mac: .underPageBackgroundColor)

  // MARK: - Surfaces
  static let surfaceCard = platformColor(ios: .secondarySystemGroupedBackground, mac: .controlBackgroundColor)
  static let surfaceElevated = platformColor(ios: .tertiarySystemBackground, mac: .textBackgroundColor)
  
  // Soft glass/surface layering
  static let glassPrimary = Color.white.opacity(0.72)
  static let glassSecondary = Color.white.opacity(0.5)
  static let glassTertiary = Color.black.opacity(0.04)
  
  // MARK: - Effects
  static let haloHighlight = Color.white.opacity(0.4)
  static let haloShadow = Color.black.opacity(0.08)

  // MARK: - Mesh Gradient Palettes
  static let atmosphereBlue = [
    Color(red: 0.96, green: 0.98, blue: 1.0),
    Color(red: 0.9, green: 0.97, blue: 0.96),
    Color(red: 0.99, green: 0.96, blue: 0.92),
    Color(red: 0.94, green: 0.94, blue: 0.98),
  ]
  
  static let atmosphereSunset = [
    Color(red: 0.96, green: 0.9, blue: 0.84),
    Color(red: 0.98, green: 0.84, blue: 0.76),
    Color(red: 0.88, green: 0.84, blue: 0.96),
    Color(red: 0.84, green: 0.92, blue: 0.9),
  ]
  
  static let atmosphereNight = [
    Color(red: 0.09, green: 0.11, blue: 0.16),
    Color(red: 0.11, green: 0.16, blue: 0.18),
    Color(red: 0.12, green: 0.11, blue: 0.2),
    Color(red: 0.08, green: 0.1, blue: 0.13),
  ]

  // MARK: - Text
  static let textPrimary = platformColor(ios: .label, mac: .labelColor)
  static let textSecondary = platformColor(ios: .secondaryLabel, mac: .secondaryLabelColor)
  static let textTertiary = platformColor(ios: .tertiaryLabel, mac: .tertiaryLabelColor)

  // MARK: - Chrome
  static let border = platformColor(ios: .separator, mac: .separatorColor)
  static let divider = platformColor(ios: .opaqueSeparator, mac: .gridColor)
  static let fill = platformColor(ios: .systemFill, mac: .controlColor)
  static let secondaryFill = platformColor(ios: .secondarySystemFill, mac: .selectedControlColor)
  static let tertiaryFill = platformColor(ios: .tertiarySystemFill, mac: .quaternaryLabelColor)
  static let separator = platformColor(ios: .separator, mac: .separatorColor)

  // MARK: - Overlays
  static let backgroundScrim = Color.black.opacity(0.3)
  static let shadowColor = Color.black.opacity(0.08)

  // MARK: - Event Colors
  static let eventBlue = Color.blue
  static let eventGreen = Color.green
  static let eventOrange = Color.orange
  static let eventRed = Color.red
  static let eventPurple = Color.purple
  static let eventPink = Color.pink
  static let eventYellow = Color.yellow
  static let eventTeal = Color(red: 50 / 255, green: 173 / 255, blue: 230 / 255)

  static func eventColor(named name: String) -> Color {
    switch name.lowercased() {
    case "blue": return .eventBlue
    case "green": return .eventGreen
    case "orange": return .eventOrange
    case "red": return .eventRed
    case "purple": return .eventPurple
    case "pink": return .eventPink
    case "yellow": return .eventYellow
    case "teal": return .eventTeal
    default: return .eventBlue
    }
  }

  // MARK: - Status Badge Colors
  static let statusCompleted = Color.green
  static let statusInProgress = Color.orange
  static let statusQueued = platformColor(ios: .systemGray, mac: .systemGray)

  // MARK: - Priority Colors
  static let priorityHigh = Color.red
  static let priorityMedium = Color.orange
  static let priorityLow = Color.blue

  // MARK: - Expense Category Colors
  static let expenseGroceries = Color(red: 76 / 255, green: 175 / 255, blue: 80 / 255)
  static let expenseHousing = Color(red: 66 / 255, green: 133 / 255, blue: 244 / 255)
  static let expenseTransport = Color(red: 255 / 255, green: 152 / 255, blue: 0 / 255)
  static let expenseSubscriptions = Color(red: 156 / 255, green: 39 / 255, blue: 176 / 255)
  static let expenseHealthcare = Color(red: 233 / 255, green: 30 / 255, blue: 99 / 255)
  static let expenseDebt = Color(red: 244 / 255, green: 67 / 255, blue: 54 / 255)
  static let expenseEntertainment = Color(red: 255 / 255, green: 193 / 255, blue: 7 / 255)
  static let expenseDining = Color(red: 121 / 255, green: 85 / 255, blue: 72 / 255)
  static let expenseShopping = Color(red: 0 / 255, green: 150 / 255, blue: 136 / 255)
  static let expenseOther = platformColor(ios: .systemGray2, mac: .systemGray)
}
