import SwiftUI
import WidgetKit

// MARK: - Combined Widget Data Model

struct CombinedEntry: TimelineEntry {
    let date: Date
    // Weather data
    let weatherIcon: String
    let currentTemp: Double
    let minTemp: Double
    let maxTemp: Double
    let city: String?
    let forecastDays: [ForecastDayInfo]
    // Calendar data  
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
    // Todo/Expense data for widget cells
    let upcomingItems: [UpcomingItem]
    let forcedColorScheme: String?
}

struct UpcomingItem: Codable {
    let id: String
    let title: String
    let date: Date
    let type: UpcomingItemType
    let priority: String?  // For todos
    let categoryColor: String?  // For todos
    let amount: Double?  // For expenses
    let currency: String?  // For expenses
    let expenseCategory: String?  // For expenses
}

enum UpcomingItemType: String, Codable {
    case todo
    case expense
}

// MARK: - Widget Data Models (for decoding shared data)

struct WidgetTodoItem: Codable {
    let id: String
    let title: String
    let dueDate: Date
    let priority: String
    let categoryColor: String
}

struct WidgetExpenseItem: Codable {
    let id: String
    let title: String
    let amount: Double
    let date: Date
    let currency: String
    let category: String
}

// MARK: - Combined Provider

struct CombinedProvider: TimelineProvider {
    func placeholder(in context: Context) -> CombinedEntry {
        let (thisWeek, nextWeek) = Self.getTwoWeeks(for: Date(), events: [:])
        return CombinedEntry(
            date: Date(),
            weatherIcon: "sun.max.fill",
            currentTemp: 18,
            minTemp: 12,
            maxTemp: 24,
            city: "Kyiv",
            forecastDays: placeholderForecastDays(),
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
            upcomingItems: [],
            forcedColorScheme: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CombinedEntry) -> Void) {
        let entry = createEntry(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CombinedEntry>) -> Void) {
        var entries: [CombinedEntry] = []
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

    private func createEntry(for date: Date) -> CombinedEntry {
        let defaults = UserDefaults.shared
        let forcedScheme = defaults.string(forKey: "debug_themeOverride")
        
        // Read weather data
        let weatherData = loadWeatherData(from: defaults)
        let weatherHistory = loadWeatherHistory(from: defaults)
        
        // Read calendar data
        let events = Self.decodeEventData(defaults.string(forKey: "widgetEventData"))
        let (thisWeek, nextWeek) = Self.getTwoWeeks(for: date, events: events)
        
        // Build forecast days
        let forecastDays = buildForecastDays(from: weatherData, history: weatherHistory, events: events)
        
        // Get current weather
        let currentWeather = getCurrentWeather(from: weatherData, for: date)
        
        // Get timer/alarm/todo data
        let timerIds = ["default", "countdown"]
        var activeTimerId: String?
        for id in timerIds {
            if defaults.bool(forKey: "widget_\(id)_hasTimer") {
                activeTimerId = id
                break
            }
        }
        
        let hasTimer = activeTimerId != nil
        let isTimerPaused = defaults.bool(forKey: "widget_\(activeTimerId ?? "default")_isPaused")
        let isStopwatch = defaults.bool(forKey: "widget_\(activeTimerId ?? "default")_isStopwatch")
        let timerEndTime = defaults.object(forKey: "widget_\(activeTimerId ?? "default")_timerEnd") as? Date
        let stopwatchStartTime = defaults.object(forKey: "widget_\(activeTimerId ?? "default")_stopwatchStart") as? Date
        let timerRemainingTime = timerEndTime?.timeIntervalSince(date) ?? 0
        
        let hasAlarm = defaults.bool(forKey: "widget_hasAlarm")
        let todoCount = defaults.integer(forKey: "incompleteTodoCount")
        
        // Load and merge upcoming todos and expenses
        let upcomingItems = loadUpcomingItems(from: defaults)
        
        return CombinedEntry(
            date: date,
            weatherIcon: currentWeather.icon,
            currentTemp: currentWeather.temp,
            minTemp: currentWeather.minTemp,
            maxTemp: currentWeather.maxTemp,
            city: weatherData?.city,
            forecastDays: forecastDays,
            thisWeek: thisWeek,
            nextWeek: nextWeek,
            hasTimer: hasTimer,
            hasAlarm: hasAlarm,
            timerEndTime: timerEndTime,
            timerRemainingTime: timerRemainingTime,
            isTimerPaused: isTimerPaused,
            isStopwatch: isStopwatch,
            stopwatchStartTime: stopwatchStartTime,
            todoCount: todoCount,
            upcomingItems: upcomingItems,
            forcedColorScheme: forcedScheme
        )
    }
    
    private func loadUpcomingItems(from defaults: UserDefaults) -> [UpcomingItem] {
        var todos: [UpcomingItem] = []
        var expenses: [UpcomingItem] = []
        
        // Load todos
        if let todoData = defaults.data(forKey: "widgetUpcomingTodos"),
           let widgetTodos = try? JSONDecoder().decode([WidgetTodoItem].self, from: todoData) {
            todos = widgetTodos.map { todo in
                UpcomingItem(
                    id: todo.id,
                    title: todo.title,
                    date: todo.dueDate,
                    type: .todo,
                    priority: todo.priority,
                    categoryColor: todo.categoryColor,
                    amount: nil,
                    currency: nil,
                    expenseCategory: nil
                )
            }
        }
        
        // If we have todos, show them (taking top 2)
        if !todos.isEmpty {
            return todos.sorted { $0.date < $1.date }.prefix(2).map { $0 }
        }
        
        // Load expenses (only if no todos)
        if let expenseData = defaults.data(forKey: "widgetUpcomingExpenses"),
           let widgetExpenses = try? JSONDecoder().decode([WidgetExpenseItem].self, from: expenseData) {
            expenses = widgetExpenses.map { expense in
                UpcomingItem(
                    id: expense.id,
                    title: expense.title,
                    date: expense.date,
                    type: .expense,
                    priority: nil,
                    categoryColor: nil,
                    amount: expense.amount,
                    currency: expense.currency,
                    expenseCategory: expense.category
                )
            }
        }
        
        // Sort by date and take top 2
        return expenses.sorted { $0.date < $1.date }.prefix(2).map { $0 }
    }

    // MARK: - Helper Methods
    
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

    private func buildForecastDays(from weatherData: WeatherData?, history: WeatherHistory?, events: [String: [String]]) -> [ForecastDayInfo] {
        let calendar = Calendar.current
        let today = Date()

        // Calculate Monday of current week
        let weekday = calendar.component(.weekday, from: today)
        let adjustedWeekday = (weekday + 5) % 7
        let mondayOfThisWeek = calendar.date(byAdding: .day, value: -adjustedWeekday, to: today)!
        
        let formatter = DateFormatter()
        formatter.locale = WidgetLocalization.locale
        let dayNames = formatter.shortStandaloneWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let orderedNames = Array(dayNames.dropFirst()) + [dayNames.first!]
        
        let dateKeyFormatter = DateFormatter()
        dateKeyFormatter.dateFormat = "yyyy-MM-dd"
        
        var forecastDays: [ForecastDayInfo] = []
        
        // Build 14 days (2 weeks) starting from Monday
        for i in 0..<14 {
            let dayDate = calendar.date(byAdding: .day, value: i, to: mondayOfThisWeek)!
            let dayOfMonth = calendar.component(.day, from: dayDate)
            let isToday = calendar.isDate(dayDate, inSameDayAs: today)
            let key = dateKeyFormatter.string(from: dayDate)
            let colors = events[key] ?? []
            
            // Find matching forecast data
            let (icon, minTemp, maxTemp) = findForecastInHistory(dayDate, history: history, currentData: weatherData, calendar: calendar)
            
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
    
    private func findForecastInHistory(_ date: Date, history: WeatherHistory?, currentData: WeatherData?, calendar: Calendar) -> (icon: String, minTemp: Double, maxTemp: Double) {
        let normalizedTarget = calendar.startOfDay(for: date)
        let _ = calendar.startOfDay(for: Date())
        
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
        
        return ("questionmark.circle", 0, 0)
    }

    private func getCurrentWeather(from weatherData: WeatherData?, for date: Date) -> (icon: String, temp: Double, minTemp: Double, maxTemp: Double, isDay: Bool) {
        guard let weatherData = weatherData else {
            return ("sun.max.fill", 18, 12, 24, true)
        }

        let calendar = Calendar.current

        // Get current hourly point
        if let current = weatherData.hourlyForecast.first(where: { $0.time > date }) ?? weatherData.hourlyForecast.first {
            let daily = weatherData.dailyForecast.first(where: { calendar.isDate($0.time, inSameDayAs: current.time) })
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
            return (firstDaily.code.icon(isDay: true), (firstDaily.minTemp + firstDaily.maxTemp) / 2, firstDaily.minTemp, firstDaily.maxTemp, true)
        }

        return ("sun.max.fill", 18, 12, 24, true)
    }

    static func getTwoWeeks(for date: Date, events: [String: [String]]) -> ([DayInfo], [DayInfo]) {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let adjustedWeekday = (weekday + 5) % 7
        let mondayOfThisWeek = calendar.date(byAdding: .day, value: -adjustedWeekday, to: date)!

        let formatter = DateFormatter()
        formatter.locale = WidgetLocalization.locale
        let dayNames = formatter.shortStandaloneWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
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

    static func decodeEventData(_ jsonString: String?) -> [String: [String]] {
        guard let jsonString = jsonString,
              let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String]]
        else { return [:] }
        return dict
    }

    private func placeholderForecastDays() -> [ForecastDayInfo] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = WidgetLocalization.locale
        let dayNames = formatter.shortStandaloneWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        return (0..<14).map { i in
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

// MARK: - Combined Widget

struct CombinedWidget: Widget {
    let kind: String = "CombinedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CombinedProvider()) { entry in
            CombinedWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(WidgetLocalization.string(.combined))
        .description(WidgetLocalization.string(.combinedWidgetDescription))
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Entry View

struct CombinedWidgetEntryView: View {
    var entry: CombinedProvider.Entry
    @Environment(\.colorScheme) var systemColorScheme

    private var scheme: WidgetColorScheme {
        WidgetColorScheme.from(forcedColorScheme: entry.forcedColorScheme, environment: systemColorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top: Weather section + Status icons
            HStack {
                // Weather info
                HStack(spacing: 8) {
                    Image(systemName: entry.weatherIcon)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(scheme.accent)
                        .symbolRenderingMode(.multicolor)

                    Text("\(Int(entry.currentTemp))°")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(scheme.textPrimary)
                }

                Spacer()

                // Min/Max temps
                VStack(alignment: .trailing, spacing: 4) {
                    Spacer()
                    
                    Text("\(Int(entry.minTemp))° / \(Int(entry.maxTemp))°")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(scheme.textSecondary)

                    if let city = entry.city {
                        Text(city)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(scheme.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }

                Spacer()

                // Status icons (Timer, Alarm, Todo)
                HStack(spacing: 12) {
                    // Timer
                    if entry.hasTimer || entry.isStopwatch {
                        TimerIcon(entry: entry, scheme: scheme)
                    }
                    
                    // Alarm
                    if entry.hasAlarm {
                        Image(systemName: "alarm.fill")
                            .font(.system(size: 18))
                            .foregroundColor(scheme.accent)
                    }
                    
                    // Todo count
                    if entry.todoCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(scheme.accent)
                            Text("\(entry.todoCount)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(scheme.textPrimary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(scheme.surface)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Divider
            Rectangle()
                .fill(scheme.divider)
                .frame(height: 0.5)
                .padding(.horizontal, 12)

            // Upcoming Items Section (Todos/Expenses) - Always show 2 cells
            HStack(spacing: 8) {
                // First cell - show item or placeholder
                if entry.upcomingItems.count > 0 {
                    UpcomingItemCell(item: entry.upcomingItems[0], scheme: scheme)
                        .frame(maxWidth: .infinity)
                } else {
                    UpcomingItemPlaceholderCell(scheme: scheme)
                        .frame(maxWidth: .infinity)
                }
                
                // Second cell - show item or placeholder
                if entry.upcomingItems.count > 1 {
                    UpcomingItemCell(item: entry.upcomingItems[1], scheme: scheme)
                        .frame(maxWidth: .infinity)
                } else {
                    UpcomingItemPlaceholderCell(scheme: scheme)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            // Divider
            Rectangle()
                .fill(scheme.divider)
                .frame(height: 0.5)
                .padding(.horizontal, 12)

            Spacer(minLength: 6)

            // Combined: Two weeks with weather for all days
            VStack(spacing: 8) {
                // This week with weather
                CombinedWeatherWeekRow(week: entry.thisWeek, forecastDays: entry.forecastDays, scheme: scheme)
                
                // Next week with weather
                CombinedWeatherWeekRow(week: entry.nextWeek, forecastDays: entry.forecastDays, scheme: scheme)
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 6)
        }
        .containerBackground(for: .widget) {
            widgetGradientBackground(scheme: scheme)
        }
    }
}

// MARK: - Subviews

struct CombinedWeatherWeekRow: View {
    let week: [DayInfo]
    let forecastDays: [ForecastDayInfo]
    let scheme: WidgetColorScheme
    
    private func getWeatherForDay(_ day: DayInfo) -> ForecastDayInfo? {
        return forecastDays.first { Calendar.current.isDate($0.fullDate, inSameDayAs: day.fullDate) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(week) { day in
                let weather = getWeatherForDay(day)
                CombinedWeatherDayCell(day: day, weather: weather, scheme: scheme)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct CombinedWeatherDayCell: View {
    let day: DayInfo
    let weather: ForecastDayInfo?
    let scheme: WidgetColorScheme

    var body: some View {
        VStack(spacing: 3) {
            // Day name
            Text(day.name.prefix(3).uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(
                    day.isToday
                        ? scheme.accent
                        : day.isWeekend
                            ? scheme.textSecondary
                            : scheme.textPrimary
                )
            
            // Weather icon
            if let weather = weather {
                Image(systemName: weather.weatherIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(scheme.accent)
                    .symbolRenderingMode(.multicolor)
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(scheme.textSecondary)
            }
            
            // Min/Max temps (small)
            if let weather = weather {
                Text("\(Int(weather.minTemp))°/\(Int(weather.maxTemp))°")
                    .font(.system(size: 7, weight: .medium, design: .rounded))
                    .foregroundColor(scheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text("--/--")
                    .font(.system(size: 7, weight: .medium, design: .rounded))
                    .foregroundColor(scheme.textSecondary)
            }

            // Day number with rings
            ZStack {
                if day.isToday {
                    Circle()
                        .fill(scheme.todayHighlight)
                        .frame(width: 18, height: 18)
                }

                if !day.eventColors.isEmpty {
                    DayEventRing(eventColors: day.eventColors, scheme: scheme, size: 20)
                }

                Text("\(day.date)")
                    .font(.system(size: 9, weight: day.isToday ? .bold : .semibold, design: .rounded))
                    .foregroundColor(day.isToday ? .white : scheme.textPrimary)
            }
            .frame(width: 22, height: 22)
        }
        .padding(.vertical, 2)
    }
}

struct UpcomingItemCell: View {
    let item: UpcomingItem
    let scheme: WidgetColorScheme
    
    private var iconName: String {
        switch item.type {
        case .todo:
            return "checkmark.circle.fill"
        case .expense:
            return "creditcard.fill"
        }
    }
    
    private var iconColor: Color {
        switch item.type {
        case .todo:
            return widgetEventColor(item.categoryColor ?? "blue")
        case .expense:
            return .orange
        }
    }
    
    private var subtitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        let dateString = formatter.string(from: item.date)
        
        switch item.type {
        case .todo:
            return dateString
        case .expense:
            if let amount = item.amount, let currency = item.currency {
                let symbol = currencySymbol(currency)
                return "\(symbol)\(Int(amount)) • \(dateString)"
            }
            return dateString
        }
    }
    
    private func currencySymbol(_ currency: String) -> String {
        switch currency.lowercased() {
        case "usd": return "$"
        case "eur": return "€"
        case "uah": return "₴"
        default: return "$"
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(scheme.textPrimary)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(scheme.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(scheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct UpcomingItemPlaceholderCell: View {
    let scheme: WidgetColorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.dashed")
                .font(.system(size: 20))
                .foregroundColor(scheme.textSecondary.opacity(0.5))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("No items")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(scheme.textSecondary)
                    .lineLimit(1)
                
                Text("Tap to add")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(scheme.textSecondary.opacity(0.7))
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(scheme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct TimerIcon: View {
    let entry: CombinedEntry
    let scheme: WidgetColorScheme

    var body: some View {
        let isActive = entry.timerRemainingTime > 0 && !entry.isTimerPaused
        let isPaused = entry.isTimerPaused
        
        ZStack {
            Circle()
                .fill(isActive ? scheme.accent.opacity(0.2) : scheme.surface)
                .frame(width: 32, height: 32)
            
            Image(systemName: entry.isStopwatch ? "stopwatch.fill" : "timer")
                .font(.system(size: 16))
                .foregroundColor(isActive ? scheme.accent : isPaused ? .orange : scheme.textSecondary)
        }
    }
}
