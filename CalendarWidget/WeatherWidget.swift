import SwiftUI
import WidgetKit

// MARK: - Data Models

struct WeatherEntry: TimelineEntry {
  let date: Date
  let weatherIcon: String
  let currentTemp: Double
  let minTemp: Double
  let maxTemp: Double
  let isDay: Bool
  let city: String?
  let weekDays: [DayWeatherInfo]
  let forecastDays: [ForecastDayInfo]  // New field for actual forecast data
  let forcedColorScheme: String?
}

struct ForecastDayInfo: Identifiable {
  let id = UUID()
  let name: String
  let date: Int
  let fullDate: Date
  let weatherIcon: String
  let minTemp: Double
  let maxTemp: Double
  let isToday: Bool
  let isWeekend: Bool
  let eventColors: [String]
}

struct DayWeatherInfo: Identifiable {
  let id = UUID()
  let name: String
  let date: Int
  let fullDate: Date
  let weatherIcon: String
  let minTemp: Double
  let maxTemp: Double
  let isToday: Bool
  let isWeekend: Bool
  let eventColors: [String]
}

// MARK: - Weather History Models (for caching past forecasts)

struct WeatherHistory: Codable {
  var entries: [WeatherHistoryEntry]
  let city: String

  func entry(for date: Date) -> WeatherHistoryEntry? {
    return entries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
  }
}

struct WeatherHistoryEntry: Codable, Identifiable {
  var id: String { "\(date.timeIntervalSince1970)" }
  let date: Date
  let minTemp: Double
  let maxTemp: Double
  let code: WeatherCode
}

// MARK: - Provider

struct WeatherProvider: TimelineProvider {
  func placeholder(in context: Context) -> WeatherEntry {
    WeatherEntry(
      date: Date(),
      weatherIcon: "sun.max.fill",
      currentTemp: 18,
      minTemp: 12,
      maxTemp: 24,
      isDay: true,
      city: "Kyiv",
      weekDays: placeholderWeekDays(),
      forecastDays: placeholderForecastDays(),
      forcedColorScheme: nil
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
    let entry = createEntry(for: Date())
    completion(entry)
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
    var entries: [WeatherEntry] = []
    let currentDate = Date()

    // Generate entries every hour for 24 hours
    for offset in 0..<24 {
      let entryDate = Calendar.current.date(byAdding: .hour, value: offset, to: currentDate)!
      let entry = createEntry(for: entryDate)
      entries.append(entry)
    }

    let timeline = Timeline(entries: entries, policy: .atEnd)
    completion(timeline)
  }

  private func createEntry(for date: Date) -> WeatherEntry {
    let defaults = UserDefaults.shared
    let forcedScheme = defaults.string(forKey: "debug_themeOverride")

    // Read weather data
    let weatherData = loadWeatherData(from: defaults)

    // Read weather history
    let weatherHistory = loadWeatherHistory(from: defaults)

    // Read calendar events
    let events = decodeEventData(defaults.string(forKey: "widgetEventData"))

    // Build week days with weather and events
    let weekDays = buildWeekDays(for: date, weatherData: weatherData, events: events)

    // Build forecast days from weather history (includes cached past data)
    let forecastDays = buildForecastDays(from: weatherData, history: weatherHistory, events: events)

    // Get current weather
    let currentWeather = getCurrentWeather(from: weatherData, for: date)

    return WeatherEntry(
      date: date,
      weatherIcon: currentWeather.icon,
      currentTemp: currentWeather.temp,
      minTemp: currentWeather.minTemp,
      maxTemp: currentWeather.maxTemp,
      isDay: currentWeather.isDay,
      city: weatherData?.city,
      weekDays: weekDays,
      forecastDays: forecastDays,
      forcedColorScheme: forcedScheme
    )
  }

  private func buildForecastDays(
    from weatherData: WeatherData?, history: WeatherHistory?, events: [String: [String]]
  ) -> [ForecastDayInfo] {
    let calendar = Calendar.current
    let today = Date()

    // Calculate Monday of current week
    let weekday = calendar.component(.weekday, from: today)
    let adjustedWeekday = (weekday + 5) % 7  // Convert to 0=Monday, 6=Sunday
    let mondayOfThisWeek = calendar.date(byAdding: .day, value: -adjustedWeekday, to: today)!

    let formatter = DateFormatter()
    formatter.locale = WidgetLocalization.locale
    let dayNames =
      formatter.shortStandaloneWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    let orderedNames = Array(dayNames.dropFirst()) + [dayNames.first!]  // Mon, Tue, Wed, Thu, Fri, Sat, Sun

    let dateKeyFormatter = DateFormatter()
    dateKeyFormatter.dateFormat = "yyyy-MM-dd"

    var forecastDays: [ForecastDayInfo] = []

    // Build 7 days starting from Monday
    for i in 0..<7 {
      let dayDate = calendar.date(byAdding: .day, value: i, to: mondayOfThisWeek)!
      let dayOfMonth = calendar.component(.day, from: dayDate)
      let isToday = calendar.isDate(dayDate, inSameDayAs: today)
      let key = dateKeyFormatter.string(from: dayDate)
      let colors = events[key] ?? []

      // First try to find in history (cached past data)
      let (icon, minTemp, maxTemp) = findForecastInHistory(
        dayDate, history: history, currentData: weatherData, calendar: calendar)

      let info = ForecastDayInfo(
        name: orderedNames[i % 7].prefix(3).uppercased(),
        date: dayOfMonth,
        fullDate: dayDate,
        weatherIcon: icon,
        minTemp: minTemp,
        maxTemp: maxTemp,
        isToday: isToday,
        isWeekend: i >= 5,
        eventColors: colors
      )
      forecastDays.append(info)
    }

    return forecastDays
  }

  private func findForecastInHistory(
    _ date: Date, history: WeatherHistory?, currentData: WeatherData?, calendar: Calendar
  ) -> (icon: String, minTemp: Double, maxTemp: Double) {
    let normalizedTarget = calendar.startOfDay(for: date)
    let today = calendar.startOfDay(for: Date())

    // First check history (for past days)
    if let history = history, let entry = history.entry(for: normalizedTarget) {
      return (entry.code.icon(isDay: true), entry.minTemp, entry.maxTemp)
    }

    // Then check current forecast data (for today and future)
    if let currentData = currentData {
      for dailyPoint in currentData.dailyForecast {
        let normalizedPoint = calendar.startOfDay(for: dailyPoint.time)
        if normalizedTarget == normalizedPoint {
          return (dailyPoint.code.icon(isDay: true), dailyPoint.minTemp, dailyPoint.maxTemp)
        }
      }
    }

    // No data found - if it's a past day, maybe show yesterday's data as fallback?
    // Or show placeholder for days beyond forecast range
    if normalizedTarget < today {
      // Try to find the most recent historical data
      if let history = history, let mostRecent = history.entries.last {
        return (mostRecent.code.icon(isDay: true), mostRecent.minTemp, mostRecent.maxTemp)
      }
    }

    return ("questionmark.circle", 0, 0)
  }

  private func loadWeatherData(from defaults: UserDefaults) -> WeatherData? {
    guard let data = defaults.data(forKey: "widgetWeatherData") else { return nil }
    do {
      return try JSONDecoder().decode(WeatherData.self, from: data)
    } catch {
      return nil
    }
  }

  private func loadWeatherHistory(from defaults: UserDefaults) -> WeatherHistory? {
    guard let data = defaults.data(forKey: "widgetWeatherHistory") else { return nil }
    do {
      return try JSONDecoder().decode(WeatherHistory.self, from: data)
    } catch {
      return nil
    }
  }

  private func decodeEventData(_ jsonString: String?) -> [String: [String]] {
    guard let jsonString = jsonString,
      let data = jsonString.data(using: .utf8),
      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String]]
    else { return [:] }
    return dict
  }

  private func buildWeekDays(for date: Date, weatherData: WeatherData?, events: [String: [String]])
    -> [DayWeatherInfo]
  {
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

    var weekDays: [DayWeatherInfo] = []

    for i in 0..<7 {
      let dayDate = calendar.date(byAdding: .day, value: i, to: mondayOfThisWeek)!
      let dayOfMonth = calendar.component(.day, from: dayDate)
      let isToday = calendar.isDate(dayDate, inSameDayAs: date)
      let key = dateKeyFormatter.string(from: dayDate)
      let colors = events[key] ?? []

      // Get weather for this day
      let dayWeather = getWeatherForDay(dayDate, from: weatherData)

      let info = DayWeatherInfo(
        name: orderedNames[i % 7],
        date: dayOfMonth,
        fullDate: dayDate,
        weatherIcon: dayWeather.icon,
        minTemp: dayWeather.minTemp,
        maxTemp: dayWeather.maxTemp,
        isToday: isToday,
        isWeekend: (i % 7) >= 5,
        eventColors: colors
      )
      weekDays.append(info)
    }

    return weekDays
  }

  private func getWeatherForDay(_ date: Date, from weatherData: WeatherData?) -> (
    icon: String, minTemp: Double, maxTemp: Double
  ) {
    guard let weatherData = weatherData else {
      return ("questionmark.circle", 0, 0)
    }

    let calendar = Calendar.current

    // Normalize the input date to midnight (API dates are at midnight)
    let normalizedDate = calendar.startOfDay(for: date)

    // Try to find matching daily forecast by comparing normalized dates
    for dailyPoint in weatherData.dailyForecast {
      let normalizedPointDate = calendar.startOfDay(for: dailyPoint.time)

      if normalizedDate == normalizedPointDate {
        return (dailyPoint.code.icon(isDay: true), dailyPoint.minTemp, dailyPoint.maxTemp)
      }
    }

    // Fallback: use isDate comparison
    if let dailyPoint = weatherData.dailyForecast.first(where: {
      calendar.isDate($0.time, inSameDayAs: date)
    }) {
      return (dailyPoint.code.icon(isDay: true), dailyPoint.minTemp, dailyPoint.maxTemp)
    }

    // Last resort: return first day
    if let firstDaily = weatherData.dailyForecast.first {
      return (firstDaily.code.icon(isDay: true), firstDaily.minTemp, firstDaily.maxTemp)
    }

    return ("questionmark.circle", 0, 0)
  }

  private func getCurrentWeather(from weatherData: WeatherData?, for date: Date) -> (
    icon: String, temp: Double, minTemp: Double, maxTemp: Double, isDay: Bool
  ) {
    guard let weatherData = weatherData else {
      return ("sun.max.fill", 18, 12, 24, true)
    }

    let calendar = Calendar.current

    // Get current hourly point
    if let current = weatherData.hourlyForecast.first(where: { $0.time > date })
      ?? weatherData.hourlyForecast.first
    {
      let daily = weatherData.dailyForecast.first(where: {
        calendar.isDate($0.time, inSameDayAs: current.time)
      })
      return (
        current.code.icon(isDay: current.isDay),
        current.temperature,
        daily?.minTemp ?? current.temperature - 5,
        daily?.maxTemp ?? current.temperature + 5,
        current.isDay
      )
    }

    // Fallback to first daily
    if let firstDaily = weatherData.dailyForecast.first {
      return (
        firstDaily.code.icon(isDay: true), (firstDaily.minTemp + firstDaily.maxTemp) / 2,
        firstDaily.minTemp, firstDaily.maxTemp, true
      )
    }

    return ("sun.max.fill", 18, 12, 24, true)
  }

  private func placeholderWeekDays() -> [DayWeatherInfo] {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.locale = WidgetLocalization.locale
    let dayNames =
      formatter.shortStandaloneWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    let orderedNames = Array(dayNames.dropFirst()) + [dayNames.first!]

    return (0..<7).map { i in
      let date = calendar.date(byAdding: .day, value: i, to: Date())!
      return DayWeatherInfo(
        name: orderedNames[i % 7],
        date: calendar.component(.day, from: date),
        fullDate: date,
        weatherIcon: "sun.max.fill",
        minTemp: 15,
        maxTemp: 25,
        isToday: i == 0,
        isWeekend: i >= 5,
        eventColors: []
      )
    }
  }

  private func placeholderForecastDays() -> [ForecastDayInfo] {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.locale = WidgetLocalization.locale
    let dayNames =
      formatter.shortStandaloneWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    return (0..<7).map { i in
      let date = calendar.date(byAdding: .day, value: i, to: Date())!
      let weekdayIndex = calendar.component(.weekday, from: date) - 1
      return ForecastDayInfo(
        name: dayNames[weekdayIndex],
        date: calendar.component(.day, from: date),
        fullDate: date,
        weatherIcon: "sun.max.fill",
        minTemp: 15 + Double(i),
        maxTemp: 25 + Double(i),
        isToday: i == 0,
        isWeekend: (weekdayIndex == 0 || weekdayIndex == 6),
        eventColors: []
      )
    }
  }
}

// MARK: - Weather Widget

struct WeatherWidget: Widget {
  let kind: String = "WeatherWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: WeatherProvider()) { entry in
      WeatherWidgetEntryView(entry: entry)
    }
    .configurationDisplayName(WidgetLocalization.string(.weather))
    .description(WidgetLocalization.string(.weatherWidgetDescription))
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

// MARK: - Entry View

struct WeatherWidgetEntryView: View {
  var entry: WeatherProvider.Entry
  @Environment(\.widgetFamily) var family
  @Environment(\.colorScheme) var systemColorScheme

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
    let scheme = WidgetColorScheme.from(
      forcedColorScheme: entry.forcedColorScheme, environment: systemColorScheme)
    Group {
      switch family {
      case .systemSmall:
        SmallWeatherWidgetView(entry: entry, scheme: scheme)
      case .systemMedium:
        MediumWeatherWidgetView(entry: entry, scheme: scheme)
      case .systemLarge:
        LargeWeatherWidgetView(entry: entry, scheme: scheme)
      default:
        SmallWeatherWidgetView(entry: entry, scheme: scheme)
      }
    }
    .environment(\.colorScheme, resolvedColorScheme)
  }
}

// MARK: - Small Widget

struct SmallWeatherWidgetView: View {
  let entry: WeatherProvider.Entry
  let scheme: WidgetColorScheme

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: entry.weatherIcon)
        .font(.system(size: 48, weight: .medium))
        .foregroundColor(scheme.accent)
        .symbolRenderingMode(.hierarchical)

      Text("\(Int(entry.currentTemp))°")
        .font(.system(size: 36, weight: .bold))
        .foregroundColor(scheme.textPrimary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .containerBackground(for: .widget) {
      widgetGradientBackground(scheme: scheme)
    }
  }
}

// MARK: - Medium Widget

struct MediumWeatherWidgetView: View {
  let entry: WeatherProvider.Entry
  let scheme: WidgetColorScheme

  var body: some View {
    VStack(spacing: 0) {
      // Top section: Weather info
      HStack(alignment: .center) {
        // Left: Weather icon + current temp (horizontal)
        HStack(spacing: 8) {
          Image(systemName: entry.weatherIcon)
            .font(.system(size: 32, weight: .medium))
            .foregroundColor(scheme.accent)
            .symbolRenderingMode(.hierarchical)

          Text("\(Int(entry.currentTemp))°")
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(scheme.textPrimary)
        }

        Spacer()

        // Right: Min/Max temps (vertically centered)
        VStack(alignment: .trailing, spacing: 4) {
          Spacer()

          Text("\(Int(entry.minTemp))° / \(Int(entry.maxTemp))°")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(scheme.textSecondary)

          if let city = entry.city {
            Text(city)
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(scheme.textSecondary)
              .lineLimit(1)
          }

          Spacer()
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(scheme.surface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(scheme.cardBorderStrong, lineWidth: 0.6)
      )
      .padding(.horizontal, 10)
      .padding(.top, 8)

      // Divider
      VStack(spacing: 0) {
        Rectangle()
          .fill(scheme.divider)
          .frame(height: 0.5)
          .padding(.horizontal, 12)

        Spacer(minLength: 6)

        // Bottom: Week strip (NO weather icons)
        HStack(spacing: 0) {
          ForEach(entry.weekDays) { day in
            DayColumnMedium(day: day, scheme: scheme)
              .frame(maxWidth: .infinity)
          }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
      }
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(scheme.surfaceElevated)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(scheme.cardBorder, lineWidth: 0.6)
      )
      .padding(.horizontal, 10)
      .padding(.top, 8)
      .padding(.bottom, 6)
    }
    .containerBackground(for: .widget) {
      widgetGradientBackground(scheme: scheme)
    }
  }
}

// MARK: - Large Widget

struct LargeWeatherWidgetView: View {
  let entry: WeatherProvider.Entry
  let scheme: WidgetColorScheme

  var body: some View {
    VStack(spacing: 0) {
      // Top section: Weather info (same as medium)
      HStack(alignment: .top) {
        // Left: Weather icon + current temp
        VStack(spacing: 4) {
          Image(systemName: entry.weatherIcon)
            .font(.system(size: 40, weight: .medium))
            .foregroundColor(scheme.accent)
            .symbolRenderingMode(.hierarchical)

          Text("\(Int(entry.currentTemp))°")
            .font(.system(size: 32, weight: .bold))
            .foregroundColor(scheme.textPrimary)
        }

        Spacer()

        // Right: Min/Max temps
        VStack(alignment: .trailing, spacing: 4) {
          Text("\(Int(entry.minTemp))° / \(Int(entry.maxTemp))°")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(scheme.textSecondary)

          if let city = entry.city {
            Text(city)
              .font(.system(size: 14, weight: .medium))
              .foregroundColor(scheme.textSecondary)
              .lineLimit(1)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(scheme.surface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(scheme.cardBorderStrong, lineWidth: 0.6)
      )
      .padding(.horizontal, 10)
      .padding(.top, 10)

      Spacer(minLength: 12)

      VStack(spacing: 0) {
        // Divider
        Rectangle()
          .fill(scheme.divider)
          .frame(height: 0.5)
          .padding(.horizontal, 12)

        Spacer(minLength: 12)

        // Large week strip with full weather info - use forecastDays
        HStack(spacing: 8) {
          ForEach(entry.forecastDays) { day in
            ForecastDayLargeColumn(day: day, scheme: scheme)
              .frame(maxWidth: .infinity)
          }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
      }
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(scheme.surfaceElevated)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(scheme.cardBorder, lineWidth: 0.6)
      )
      .padding(.horizontal, 10)
      .padding(.top, 10)
      .padding(.bottom, 8)
    }
    .containerBackground(for: .widget) {
      widgetGradientBackground(scheme: scheme)
    }
  }
}

// MARK: - Day Column (Medium - No weather icons)

struct DayColumnMedium: View {
  let day: DayWeatherInfo
  let scheme: WidgetColorScheme

  var body: some View {
    VStack(spacing: 6) {
      // Day name
      Text(day.name.prefix(3).uppercased())
        .font(.system(size: 9, weight: .bold))
        .foregroundColor(
          day.isToday
            ? scheme.accent
            : day.isWeekend
              ? scheme.textSecondary
              : scheme.textPrimary
        )

      // Day number with event ring (no weather icon)
      ZStack {
        // Today highlight
        if day.isToday {
          Circle()
            .fill(scheme.todayHighlight)
            .frame(width: 26, height: 26)
        }

        // Event ring if events exist
        if !day.eventColors.isEmpty {
          DayEventRing(eventColors: day.eventColors, scheme: scheme, size: 28)
        }

        Text("\(day.date)")
          .font(.system(size: 13, weight: day.isToday ? .bold : .semibold))
          .foregroundColor(day.isToday ? (scheme == .dark ? Color.black.opacity(0.85) : .white) : scheme.textPrimary)
      }
      .frame(width: 30, height: 30)
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Day Weather Column (with weather icons - for reference, used in Large)

struct DayWeatherColumn: View {
  let day: DayWeatherInfo
  let scheme: WidgetColorScheme

  var body: some View {
    VStack(spacing: 4) {
      // Day name
      Text(day.name.prefix(3).uppercased())
        .font(.system(size: 9, weight: .bold))
        .foregroundColor(
          day.isToday
            ? scheme.accent
            : day.isWeekend
              ? scheme.textSecondary
              : scheme.textPrimary
        )

      // Weather icon
      Image(systemName: day.weatherIcon)
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(scheme.accent)
        .symbolRenderingMode(.hierarchical)

      // Day number with event ring
      ZStack {
        // Today highlight
        if day.isToday {
          Circle()
            .fill(scheme.todayHighlight)
            .frame(width: 24, height: 24)
        }

        // Event ring if events exist
        if !day.eventColors.isEmpty {
          DayEventRing(eventColors: day.eventColors, scheme: scheme, size: 26)
        }

        Text("\(day.date)")
          .font(.system(size: 12, weight: day.isToday ? .bold : .semibold))
          .foregroundColor(day.isToday ? (scheme == .dark ? Color.black.opacity(0.85) : .white) : scheme.textPrimary)
      }
      .frame(width: 28, height: 28)
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Day Weather Large Column

struct DayWeatherLargeColumn: View {
  let day: DayWeatherInfo
  let scheme: WidgetColorScheme

  var body: some View {
    VStack(spacing: 6) {
      // Day name
      Text(day.name.prefix(3).uppercased())
        .font(.system(size: 10, weight: .bold))
        .foregroundColor(
          day.isToday
            ? scheme.accent
            : day.isWeekend
              ? scheme.textSecondary
              : scheme.textPrimary
        )

      // Weather icon
      Image(systemName: day.weatherIcon)
        .font(.system(size: 22, weight: .medium))
        .foregroundColor(scheme.accent)
        .symbolRenderingMode(.hierarchical)

      // Min temp
      Text("\(Int(day.minTemp))°")
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(scheme.textSecondary)

      // Max temp
      Text("\(Int(day.maxTemp))°")
        .font(.system(size: 12, weight: .bold))
        .foregroundColor(scheme.textPrimary)

      // Day number with today highlight and event ring
      ZStack {
        // Today highlight
        if day.isToday {
          Circle()
            .fill(scheme.todayHighlight)
            .frame(width: 26, height: 26)
        }

        // Event ring if events exist
        if !day.eventColors.isEmpty {
          DayEventRing(eventColors: day.eventColors, scheme: scheme, size: 30)
        }

        Text("\(day.date)")
          .font(.system(size: 14, weight: day.isToday ? .bold : .semibold))
          .foregroundColor(day.isToday ? (scheme == .dark ? Color.black.opacity(0.85) : .white) : scheme.textPrimary)
      }
      .frame(width: 32, height: 32)
    }
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(day.isToday ? scheme.todayHighlight.opacity(0.1) : Color.clear)
    )
  }
}

// MARK: - Forecast Day Large Column

struct ForecastDayLargeColumn: View {
  let day: ForecastDayInfo
  let scheme: WidgetColorScheme

  var body: some View {
    VStack(spacing: 6) {
      // Day name
      Text(day.name.prefix(3).uppercased())
        .font(.system(size: 10, weight: .bold))
        .foregroundColor(
          day.isToday
            ? scheme.accent
            : day.isWeekend
              ? scheme.textSecondary
              : scheme.textPrimary
        )

      // Weather icon
      Image(systemName: day.weatherIcon)
        .font(.system(size: 22, weight: .medium))
        .foregroundColor(scheme.accent)
        .symbolRenderingMode(.hierarchical)

      // Min temp
      Text("\(Int(day.minTemp))°")
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(scheme.textSecondary)

      // Max temp
      Text("\(Int(day.maxTemp))°")
        .font(.system(size: 12, weight: .bold))
        .foregroundColor(scheme.textPrimary)

      // Day number with today highlight and event ring
      ZStack {
        // Today highlight
        if day.isToday {
          Circle()
            .fill(scheme.todayHighlight)
            .frame(width: 26, height: 26)
        }

        // Event ring if events exist
        if !day.eventColors.isEmpty {
          DayEventRing(eventColors: day.eventColors, scheme: scheme, size: 30)
        }

        Text("\(day.date)")
          .font(.system(size: 14, weight: day.isToday ? .bold : .semibold))
          .foregroundColor(day.isToday ? (scheme == .dark ? Color.black.opacity(0.85) : .white) : scheme.textPrimary)
      }
      .frame(width: 32, height: 32)
    }
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(day.isToday ? scheme.todayHighlight.opacity(0.1) : Color.clear)
    )
  }
}

// MARK: - Day Event Ring

struct DayEventRing: View {
  let eventColors: [String]
  let scheme: WidgetColorScheme
  let size: CGFloat

  var body: some View {
    let entries = eventColors.prefix(2).map { parseWidgetColorEntry($0) }

    VStack(spacing: 0) {
      Spacer()

      HStack(spacing: 2) {
        ForEach(entries.indices, id: \.self) { index in
          Circle()
            .fill(entries[index].color)
            .frame(width: 3.5, height: 3.5)
        }
      }
      .padding(.bottom, 2)
    }
    .frame(width: size, height: size)
  }
}

// MARK: - Weather Data Model (Shared with main app)

struct WeatherData: Codable {
  let city: String
  let lastSyncDate: Date
  let hourlyForecast: [HourlyPoint]
  let dailyForecast: [DailyPoint]
}

struct HourlyPoint: Codable, Identifiable {
  var id: String { "\(time.timeIntervalSince1970)" }
  let time: Date
  let temperature: Double
  let code: WeatherCode
  let isDay: Bool
}

struct DailyPoint: Codable, Identifiable {
  var id: String { "\(time.timeIntervalSince1970)" }
  let time: Date
  let minTemp: Double
  let maxTemp: Double
  let code: WeatherCode
}

enum WeatherCode: Int, Codable {
  case clearSky = 0
  case mainlyClear = 1
  case partlyCloudy = 2
  case overcast = 3
  case fog = 45
  case depositingRimeFog = 48
  case drizzleLight = 51
  case drizzleModerate = 53
  case drizzleDense = 55
  case freezingDrizzleLight = 56
  case freezingDrizzleDense = 57
  case rainSlight = 61
  case rainModerate = 63
  case rainHeavy = 65
  case freezingRainLight = 66
  case freezingRainHeavy = 67
  case snowSlight = 71
  case snowModerate = 73
  case snowHeavy = 75
  case snowGrains = 77
  case rainShowersSlight = 80
  case rainShowersModerate = 81
  case rainShowersViolent = 82
  case snowShowersSlight = 85
  case snowShowersHeavy = 86
  case thunderstormSlight = 95
  case thunderstormSlightHail = 96
  case thunderstormHeavyHail = 99

  func icon(isDay: Bool) -> String {
    switch self {
    case .clearSky, .mainlyClear:
      return isDay ? "sun.max.fill" : "moon.stars.fill"
    case .partlyCloudy:
      return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
    case .fog, .depositingRimeFog:
      return "cloud.fog.fill"
    case .overcast:
      return "cloud.fill"
    case .drizzleLight, .drizzleModerate, .drizzleDense:
      return "cloud.drizzle.fill"
    case .freezingDrizzleLight, .freezingDrizzleDense:
      return "cloud.hail.fill"
    case .rainSlight, .rainModerate, .rainHeavy:
      return "cloud.rain.fill"
    case .freezingRainLight, .freezingRainHeavy:
      return "cloud.heavyrain.fill"
    case .snowSlight, .snowModerate, .snowHeavy, .snowGrains:
      return "snowflake"
    case .rainShowersSlight, .rainShowersModerate, .rainShowersViolent:
      return isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill"
    case .snowShowersSlight, .snowShowersHeavy:
      return "cloud.snow.fill"
    case .thunderstormSlight, .thunderstormSlightHail, .thunderstormHeavyHail:
      return "cloud.bolt.rain.fill"
    }
  }
}
