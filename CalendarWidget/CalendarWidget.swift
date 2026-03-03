import SwiftUI
import UIKit
import WidgetKit

// MARK: - Widget Definition

struct CalendarWidget: Widget {
  let kind: String = "CalendarWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      CalendarWidgetEntryView(entry: entry)
    }
    .configurationDisplayName(WidgetLocalization.string(.calendar))
    .description(WidgetLocalization.string(.widgetDescription))
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}

// MARK: - Data Models

struct DayInfo: Identifiable {
  let id = UUID()
  let name: String
  let date: Int
  let fullDate: Date
  let isToday: Bool
  let isWeekend: Bool
  let eventColors: [String]
}

struct CalendarEntry: TimelineEntry {
  let date: Date
  let thisWeek: [DayInfo]
  let nextWeek: [DayInfo]
  let hasTimer: Bool
  let hasAlarm: Bool
  let timerEndTime: Date?
  let timerRemainingTime: TimeInterval
  let isTimerPaused: Bool
  let isStopwatch: Bool
  let stopwatchStartTime: Date?
  let todoCount: Int
  let forcedColorScheme: String?
}

// MARK: - Provider

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> CalendarEntry {
    let (thisWeek, nextWeek) = Self.getTwoWeeks(for: Date(), events: [:])
    return CalendarEntry(
      date: Date(),
      thisWeek: thisWeek,
      nextWeek: nextWeek,
      hasTimer: false,
      hasAlarm: false,
      timerEndTime: nil,
      timerRemainingTime: 0,
      isTimerPaused: false,
      isStopwatch: false,
      stopwatchStartTime: nil,
      todoCount: 0,
      forcedColorScheme: nil
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
    let defaults = UserDefaults.shared
    let events = Self.decodeEventData(defaults.string(forKey: "widgetEventData"))
    let (thisWeek, nextWeek) = Self.getTwoWeeks(for: Date(), events: events)
    let entry = CalendarEntry(
      date: Date(),
      thisWeek: thisWeek,
      nextWeek: nextWeek,
      hasTimer: false,
      hasAlarm: false,
      timerEndTime: nil,
      timerRemainingTime: 0,
      isTimerPaused: false,
      isStopwatch: false,
      stopwatchStartTime: nil,
      todoCount: defaults.integer(forKey: "incompleteTodoCount"),
      forcedColorScheme: defaults.string(forKey: "debug_themeOverride")
    )
    completion(entry)
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    var entries: [CalendarEntry] = []
    let currentDate = Date()
    let defaults = UserDefaults.shared

    let todoCount = defaults.integer(forKey: "incompleteTodoCount")
    let forcedScheme = defaults.string(forKey: "debug_themeOverride")
    let events = Self.decodeEventData(defaults.string(forKey: "widgetEventData"))

    let timerIds = ["default", "countdown"]
    var activeTimerId: String?
    for id in timerIds {
      if defaults.bool(forKey: "\(id).isRunning") || defaults.bool(forKey: "\(id).isPaused") {
        activeTimerId = id
        break
      }
    }

    let timerId = activeTimerId ?? "default"
    let globalHasTimer = defaults.bool(forKey: "hasActiveTimer")
    let isRunning = defaults.bool(forKey: "\(timerId).isRunning")
    let isPaused = defaults.bool(forKey: "\(timerId).isPaused")
    let isStopwatch = defaults.bool(forKey: "\(timerId).isStopwatch")
    let remainingTime = defaults.double(forKey: "\(timerId).remainingTime")
    let endTime = defaults.object(forKey: "\(timerId).endTime") as? Date
    let startTime = defaults.object(forKey: "\(timerId).startTime") as? Date

    let hasActiveTimer = isRunning || isStopwatch || globalHasTimer
    // When a timer is running, generate per-minute entries for accurate MM:SS display
    let entryCount = hasActiveTimer && !isPaused ? 60 : 5
    let entryInterval: Calendar.Component = hasActiveTimer && !isPaused ? .minute : .hour

    for offset in 0..<entryCount {
      let entryDate = Calendar.current.date(
        byAdding: entryInterval, value: offset, to: currentDate)!
      let (thisWeek, nextWeek) = Self.getTwoWeeks(for: entryDate, events: events)

      let entry = CalendarEntry(
        date: entryDate,
        thisWeek: thisWeek,
        nextWeek: nextWeek,
        hasTimer: hasActiveTimer || isPaused,
        hasAlarm: defaults.bool(forKey: "hasActiveAlarm"),
        timerEndTime: endTime,
        timerRemainingTime: remainingTime,
        isTimerPaused: isPaused,
        isStopwatch: isStopwatch,
        stopwatchStartTime: startTime,
        todoCount: todoCount,
        forcedColorScheme: forcedScheme
      )
      entries.append(entry)
    }

    let timeline = Timeline(entries: entries, policy: .atEnd)
    completion(timeline)
  }

  static func decodeEventData(_ jsonString: String?) -> [String: [String]] {
    guard let jsonString = jsonString,
      let data = jsonString.data(using: .utf8),
      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String]]
    else { return [:] }
    return dict
  }

  static func getTwoWeeks(for date: Date, events: [String: [String]]) -> ([DayInfo], [DayInfo]) {
    let calendar = Calendar.current
    let weekday = calendar.component(.weekday, from: date)
    let adjustedWeekday = (weekday + 5) % 7
    let mondayOfThisWeek = calendar.date(byAdding: .day, value: -adjustedWeekday, to: date)!

    let formatter = DateFormatter()
    formatter.locale = WidgetLocalization.locale
    let dayNames =
      formatter.shortStandaloneWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    let orderedNames = Array(dayNames.dropFirst()) + [dayNames.first!]

    let dateKeyFormatter = DateFormatter()
    dateKeyFormatter.dateFormat = "yyyy-MM-dd"

    var thisWeek: [DayInfo] = []
    var nextWeek: [DayInfo] = []

    for i in 0..<14 {
      let dayDate = calendar.date(byAdding: .day, value: i, to: mondayOfThisWeek)!
      let dayOfMonth = calendar.component(.day, from: dayDate)
      let isToday = calendar.isDate(dayDate, inSameDayAs: date)
      let key = dateKeyFormatter.string(from: dayDate)
      let colors = events[key] ?? []

      let info = DayInfo(
        name: orderedNames[i % 7],
        date: dayOfMonth,
        fullDate: dayDate,
        isToday: isToday,
        isWeekend: (i % 7) >= 5,
        eventColors: colors
      )

      if i < 7 {
        thisWeek.append(info)
      } else {
        nextWeek.append(info)
      }
    }

    return (thisWeek, nextWeek)
  }
}

// MARK: - Widget Design Tokens
// Mirrors the app's Color+Theme.swift — uses UIColor system-adaptive colors
// so light/dark mode is handled automatically by the system.

enum WidgetColorScheme {
  case light, dark

  // Colors synced with the app's Color+Theme.swift design tokens
  var background: Color {
    self == .dark ? Color(red: 18 / 255, green: 20 / 255, blue: 24 / 255) : Color(UIColor.systemBackground)
  }
  var surface: Color {
    self == .dark
      ? Color(red: 34 / 255, green: 37 / 255, blue: 44 / 255)
      : Color(UIColor.secondarySystemGroupedBackground)
  }
  var surfaceElevated: Color {
    self == .dark
      ? Color(red: 29 / 255, green: 32 / 255, blue: 38 / 255)
      : Color(UIColor.tertiarySystemFill)
  }
  var textPrimary: Color { Color(UIColor.label) }
  var textSecondary: Color { Color(UIColor.secondaryLabel) }
  var accent: Color {
    self == .dark
      ? Color(red: 216 / 255, green: 220 / 255, blue: 227 / 255)
      : Color(red: 47 / 255, green: 51 / 255, blue: 58 / 255)
  }
  var todayHighlight: Color { accent }
  var iconMuted: Color { Color(UIColor.tertiaryLabel) }
  var divider: Color {
    self == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.12)
  }
  var cardBorderStrong: Color {
    self == .dark ? Color.white.opacity(0.13) : Color.black.opacity(0.08)
  }
  var cardBorder: Color {
    self == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.06)
  }

  static func from(forcedColorScheme: String?, environment: ColorScheme) -> WidgetColorScheme {
    if let forced = forcedColorScheme {
      switch forced {
      case "Light": return .light
      case "Dark": return .dark
      default: break
      }
    }
    return environment == .dark ? .dark : .light
  }
}

// MARK: - Event Color Mapping

/// Parsed widget color entry – distinguishes events from todos
struct WidgetColorEntry {
  let color: Color
  let isTodo: Bool
  let isHoliday: Bool
  let priority: String  // "high", "medium", "low" (only for todos)

  /// Priority color for alternating dashes — aligned with app's Color+Theme
  var priorityColor: Color {
    switch priority.lowercased() {
    case "high": return .red
    case "medium": return .orange
    case "low": return .blue
    default: return .orange
    }
  }
}

func parseWidgetColorEntry(_ name: String) -> WidgetColorEntry {
  if name.hasPrefix("todo:") {
    // Format: "todo:categoryColor:priority"
    let parts = name.dropFirst(5).split(separator: ":", maxSplits: 1)
    let catColor = parts.count > 0 ? String(parts[0]) : "green"
    let priKey = parts.count > 1 ? String(parts[1]) : "medium"
    return WidgetColorEntry(
      color: widgetEventColor(catColor),
      isTodo: true,
      isHoliday: false,
      priority: priKey
    )
  }
  if name.hasPrefix("holiday:") {
    let colorName = String(name.dropFirst(8))
    return WidgetColorEntry(
      color: widgetEventColor(colorName),
      isTodo: false,
      isHoliday: true,
      priority: ""
    )
  }
  return WidgetColorEntry(color: widgetEventColor(name), isTodo: false, isHoliday: false, priority: "")
}

/// Event colors aligned with the app's Color+Theme design tokens
func widgetEventColor(_ name: String) -> Color {
  switch name.lowercased() {
  case "blue": return .blue
  case "green": return .green
  case "orange": return .orange
  case "red": return .red
  case "purple": return .purple
  case "pink": return .pink
  case "yellow": return .yellow
  case "teal": return Color(red: 50 / 255, green: 173 / 255, blue: 230 / 255)
  default: return .blue
  }
}

// MARK: - Entry View

struct CalendarWidgetEntryView: View {
  var entry: Provider.Entry
  @Environment(\.widgetFamily) var family
  @Environment(\.colorScheme) var systemColorScheme

  /// Resolved color scheme — honors debug override, otherwise follows system
  private var resolvedColorScheme: ColorScheme {
    if let forced = entry.forcedColorScheme {
      switch forced {
      case "Light": return .light
      case "Dark": return .dark
      default: break
      }
    }
    return systemColorScheme
  }

  var body: some View {
    let scheme = WidgetColorScheme.from(forcedColorScheme: entry.forcedColorScheme, environment: systemColorScheme)
    Group {
      switch family {
      case .systemMedium:
        MediumWidgetView(entry: entry, scheme: scheme)
      case .systemLarge:
        LargeWidgetView(entry: entry, scheme: scheme)
      default:
        MediumWidgetView(entry: entry, scheme: scheme)
      }
    }
    // Force the environment so UIColor-based tokens resolve to the correct variant
    .environment(\.colorScheme, resolvedColorScheme)
  }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
  let entry: Provider.Entry
  let scheme: WidgetColorScheme

  var body: some View {
    VStack(spacing: 8) {
      // Header: day name + status icons
      HStack(alignment: .center) {
        Text(
          entry.date.formatted(.dateTime.weekday(.wide).locale(WidgetLocalization.locale))
            .localizedCapitalized
        )
        .font(.system(size: 22, weight: .black))
        .foregroundColor(scheme.textPrimary)

        Spacer()

        TopRightIcons(entry: entry, scheme: scheme)
      }

      VStack(spacing: 4) {
        // This week (label + day cell per column)
        HStack(spacing: 0) {
          ForEach(entry.thisWeek) { day in
            DayColumn(day: day, scheme: scheme, cellSize: 34, labelSize: 9)
              .frame(maxWidth: .infinity)
          }
        }

        // Next week
        HStack(spacing: 0) {
          ForEach(entry.nextWeek) { day in
            DayCell(day: day, scheme: scheme, size: 34)
              .frame(maxWidth: .infinity)
          }
        }
      }
      .padding(8)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(scheme.surface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(scheme.cardBorderStrong, lineWidth: 0.6)
      )
    }
    .padding(.horizontal, 14)
    .padding(.top, 12)
    .padding(.bottom, 10)
    .containerBackground(for: .widget) {
      widgetGradientBackground(scheme: scheme)
    }
  }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
  let entry: Provider.Entry
  let scheme: WidgetColorScheme

  var body: some View {
    VStack(spacing: 10) {
      // Header
      HStack(alignment: .center) {
        Text(
          entry.date.formatted(.dateTime.weekday(.wide).locale(WidgetLocalization.locale))
            .localizedCapitalized
        )
        .font(.system(size: 24, weight: .black))
        .foregroundColor(scheme.textPrimary)

        Spacer()

        TopRightIcons(entry: entry, scheme: scheme, iconSize: 30)
      }

      VStack(spacing: 4) {
        // This week (label + day cell per column)
        HStack(spacing: 0) {
          ForEach(entry.thisWeek) { day in
            DayColumn(day: day, scheme: scheme, cellSize: 42, labelSize: 11)
              .frame(maxWidth: .infinity)
          }
        }

        // Next week
        HStack(spacing: 0) {
          ForEach(entry.nextWeek) { day in
            DayCell(day: day, scheme: scheme, size: 42)
              .frame(maxWidth: .infinity)
          }
        }
      }
      .padding(10)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(scheme.surface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(scheme.cardBorderStrong, lineWidth: 0.6)
      )

      // Status cards
      VStack(alignment: .leading, spacing: 10) {
        Text(WidgetLocalization.string(.status).uppercased())
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(scheme.textSecondary)
          .tracking(0.5)

        HStack(spacing: 10) {
          StatusCard(
            icon: "timer",
            title: WidgetLocalization.string(.timer),
            statusText: timerStatusText(entry: entry),
            color: scheme.accent,
            isActive: entry.hasTimer,
            scheme: scheme
          )

          StatusCard(
            icon: "alarm.fill",
            title: WidgetLocalization.string(.alarm),
            status: entry.hasAlarm
              ? WidgetLocalization.string(.set) : WidgetLocalization.string(.off),
            color: .orange,
            isActive: entry.hasAlarm,
            scheme: scheme
          )

          StatusCard(
            icon: "checkmark.circle",
            title: WidgetLocalization.string(.todo),
            status: "\(entry.todoCount)",
            color: .green,
            isActive: entry.todoCount > 0,
            scheme: scheme
          )
        }
      }
      .padding(.top, 4)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .containerBackground(for: .widget) {
      widgetGradientBackground(scheme: scheme)
    }
  }
}

// MARK: - Top Right Icons

struct TopRightIcons: View {
  let entry: Provider.Entry
  let scheme: WidgetColorScheme
  var iconSize: CGFloat = 26

  var body: some View {
    HStack(spacing: 6) {
      TimerCircleIcon(entry: entry, scheme: scheme, size: iconSize)
      AlarmCircleIcon(entry: entry, scheme: scheme, size: iconSize)
      TodoCircleIcon(entry: entry, scheme: scheme, size: iconSize)
    }
  }
}

struct TimerCircleIcon: View {
  let entry: Provider.Entry
  let scheme: WidgetColorScheme
  let size: CGFloat

  private var hasHours: Bool {
    if entry.isTimerPaused {
      return entry.timerRemainingTime >= 3600
    } else if entry.isStopwatch, let startTime = entry.stopwatchStartTime {
      return Date().timeIntervalSince(startTime) >= 3600
    } else if let endTime = entry.timerEndTime {
      return endTime.timeIntervalSince(Date()) >= 3600
    }
    return false
  }

  private var dynamicWidth: CGFloat {
    hasHours ? size * 1.45 : size
  }

  private var activeTimerColor: Color { scheme.accent }

  var body: some View {
    ZStack {
      if hasHours {
        Capsule()
          .stroke(entry.hasTimer ? activeTimerColor : scheme.iconMuted, lineWidth: 2)
          .frame(width: dynamicWidth, height: size)
      } else {
        Circle()
          .stroke(entry.hasTimer ? activeTimerColor : scheme.iconMuted, lineWidth: 2)
          .frame(width: size, height: size)
      }

      if entry.hasTimer {
        timerText
          .font(
            .system(size: hasHours ? size * 0.26 : size * 0.28, weight: .bold, design: .monospaced)
          )
          .foregroundColor(activeTimerColor)
          .minimumScaleFactor(0.4)
          .lineLimit(1)
          .frame(width: dynamicWidth - 6, height: size - 6)
      } else {
        Image(systemName: "timer")
          .font(.system(size: size * 0.38, weight: .medium))
          .foregroundColor(scheme.iconMuted)
      }
    }
    .frame(width: dynamicWidth, height: size)
  }

  private var timerText: Text {
    if entry.isTimerPaused {
      return Text(formatCompactDuration(entry.timerRemainingTime))
    } else if entry.isStopwatch, let startTime = entry.stopwatchStartTime {
      let elapsed = entry.date.timeIntervalSince(startTime)
      return Text(formatCompactDuration(elapsed))
    } else if let endTime = entry.timerEndTime {
      let remaining = max(0, endTime.timeIntervalSince(entry.date))
      return Text(formatCompactDuration(remaining))
    } else {
      return Text("--:--")
    }
  }

  /// Compact string for the icon: always zero-pads minutes
  private func formatCompactDuration(_ duration: TimeInterval) -> String {
    let totalSeconds = Int(duration)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
  }
}

struct AlarmCircleIcon: View {
  let entry: Provider.Entry
  let scheme: WidgetColorScheme
  let size: CGFloat

  private var alarmColor: Color {
    entry.hasAlarm ? scheme.textPrimary : scheme.iconMuted
  }

  var body: some View {
    ZStack {
      Circle()
        .stroke(alarmColor, lineWidth: 2)
        .frame(width: size, height: size)

      Image(systemName: entry.hasAlarm ? "alarm.fill" : "alarm")
        .font(.system(size: size * 0.45, weight: .medium))
        .foregroundColor(alarmColor)
    }
    .frame(width: size, height: size)
  }
}

struct TodoCircleIcon: View {
  let entry: Provider.Entry
  let scheme: WidgetColorScheme
  let size: CGFloat

  var body: some View {
    ZStack {
      Circle()
        .stroke(entry.todoCount > 0 ? .orange : scheme.iconMuted, lineWidth: 2)
        .frame(width: size, height: size)

      Text("\(entry.todoCount)")
        .font(.system(size: size * 0.38, weight: .bold))
        .foregroundColor(entry.todoCount > 0 ? .orange : scheme.iconMuted)
    }
    .frame(width: size, height: size)
  }
}

// MARK: - Day Column (Label + Cell with Today Highlight)

struct DayColumn: View {
  let day: DayInfo
  let scheme: WidgetColorScheme
  let cellSize: CGFloat
  let labelSize: CGFloat

  var body: some View {
    VStack(spacing: 4) {
      Text(day.name.prefix(3).uppercased())
        .font(.system(size: labelSize, weight: .bold))
        .foregroundColor(
          day.isToday
            ? scheme.accent
            : day.isWeekend
              ? scheme.textSecondary
              : scheme.textPrimary
        )

      DayCell(day: day, scheme: scheme, size: cellSize)
    }
    .padding(.vertical, 4)
    .padding(.horizontal, 2)
  }
}

// MARK: - Day Cell

struct DayCell: View {
  let day: DayInfo
  let scheme: WidgetColorScheme
  let size: CGFloat

  private var entries: [WidgetColorEntry] {
    day.eventColors.prefix(2).map { parseWidgetColorEntry($0) }
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      ZStack {
        if day.isToday {
          Circle()
            .fill(scheme.todayHighlight)
            .frame(width: size - 2, height: size - 2)
        }

        Text("\(day.date)")
          .font(.system(size: size * 0.37, weight: day.isToday ? .bold : .semibold))
          .foregroundColor(day.isToday ? (scheme == .dark ? Color.black.opacity(0.85) : .white) : scheme.textPrimary)
      }

      if !entries.isEmpty {
        HStack(spacing: 2) {
          ForEach(entries.indices, id: \.self) { index in
            Circle()
              .fill(entries[index].color)
              .frame(width: 3.5, height: 3.5)
          }
        }
        .offset(y: 4)
      }
    }
    .frame(width: size, height: size)
  }
}

// MARK: - Status Card (Large Widget)

struct StatusCard: View {
  let icon: String
  let title: String
  let statusText: Text
  let color: Color
  let isActive: Bool
  let scheme: WidgetColorScheme

  init(
    icon: String, title: String, statusText: Text? = nil, status: String? = nil,
    color: Color, isActive: Bool, scheme: WidgetColorScheme
  ) {
    self.icon = icon
    self.title = title
    self.statusText = statusText ?? Text(status ?? "")
    self.color = color
    self.isActive = isActive
    self.scheme = scheme
  }

  var body: some View {
    VStack(spacing: 4) {
      ZStack {
        Circle()
          .fill(isActive ? color.opacity(0.15) : scheme.surfaceElevated)
          .frame(width: 30, height: 30)

        Image(systemName: icon)
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(isActive ? color : scheme.iconMuted)
      }

      statusText
        .font(.system(size: 12, weight: .bold))
        .foregroundColor(scheme.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(scheme.surface)
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(scheme.cardBorder, lineWidth: 0.5)
        )
    )
  }
}

// MARK: - Widget Background

@ViewBuilder
func widgetGradientBackground(scheme: WidgetColorScheme) -> some View {
  scheme.background
}

// MARK: - Helpers

func timerStatusText(entry: CalendarEntry) -> Text {
  if entry.hasTimer {
    if entry.isTimerPaused {
      return Text(formatDuration(entry.timerRemainingTime))
    } else if entry.isStopwatch, let startTime = entry.stopwatchStartTime {
      return Text(startTime, style: .timer)
    } else if let endTime = entry.timerEndTime {
      return Text(endTime, style: .timer)
    } else {
      return Text(WidgetLocalization.string(.active))
    }
  } else {
    return Text(WidgetLocalization.string(.idle))
  }
}

func formatDuration(_ duration: TimeInterval) -> String {
  let totalSeconds = Int(duration)
  let hours = totalSeconds / 3600
  let minutes = (totalSeconds % 3600) / 60
  let seconds = totalSeconds % 60
  if hours > 0 {
    return String(format: "%d:%02d:%02d", hours, minutes, seconds)
  }
  return String(format: "%02d:%02d", minutes, seconds)
}

func formatCompactDuration(_ duration: TimeInterval) -> String {
  let totalSeconds = Int(duration)
  let minutes = (totalSeconds % 3600) / 60
  let seconds = totalSeconds % 60
  return String(format: "%02d:%02d", minutes, seconds)
}

// MARK: - Shared UserDefaults

extension UserDefaults {
  static var shared: UserDefaults {
    UserDefaults(suiteName: "group.com.shoode.calendar") ?? .standard
  }
}
