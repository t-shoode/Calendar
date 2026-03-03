import Foundation

public struct Localization {
  enum Language {
    case ukrainian
    case english
  }

  static var currentLanguage: Language {
    // Retrieve the user's preferred language order
    let preferred = Locale.preferredLanguages.first ?? "en"

    // "uk" is Ukrainian. It might appear as "uk-UA", "uk-US", "uk" etc.
    if preferred.starts(with: "uk") {
      return .ukrainian
    }

    let langCode = Locale.current.language.languageCode?.identifier ?? "en"
    return langCode == "uk" ? .ukrainian : .english
  }

  static var locale: Locale {
    return currentLanguage == .ukrainian ? Locale(identifier: "uk_UA") : Locale(identifier: "en_US")
  }

  public enum Key {
    // Common
    case save
    case cancel
    case update
    case delete
    case clearAll
    case clearAllExpenses
    case clearAllTemplates
    case clearEverything
    case cannotBeUndone
    case templates

    // Calendar / Event List
    case selectDate
    case eventsCount(Int)
    case noEvents
    case tapToAdd
    case addEvent

    // Add/Edit Event
    case newEvent
    case editEvent
    case title
    case eventTitlePlaceholder
    case notes
    case notesPlaceholder
    case color
    case date
    case reminder
    case none
    case atTimeOfEvent
    case minutesBefore(Int)
    case hoursBefore(Int)
    case dayBefore  // 1 day
    case daysBefore(Int)
    case minutesShort(Int)
    case minutesUnit

    // Widget / Timer / Alarm
    case active
    case idle
    case alarm
    case timer
    case set
    case off
    case status

    // Accessibility / Navigation
    case previousMonth
    case nextMonth
    case calendarFor(String)

    // Tabs
    case tabCalendar
    case tabTimer
    case tabAlarm
    case tabExpenses
    case tabClock
    case tabWeather
    case tabBudget

    // UI Labels
    case today
    case remaining
    case elapsed
    case more(Int)
    case add
    case total

    // Alarm View
    case noAlarmSet
    case tapToSetAlarm
    case setAlarm
    case edit
    // .delete already exists

    // Time Picker / Timer Views
    case timePicker
    case alarmWillRingAt(String)
    case alarmSetFor(String)
    case countdown
    case selectTimerType
    case timeRemaining(String)
    case alarmTime(String)

    // General / Errors
    case pageNotFound
    case selectTabPrompt

    // Startup / Splash
    case splashStarting
    case splashContinueInBackground
    case splashPreGenerating
    case splashPreparing
    case splashSyncingWidgets
    case splashGeneratingRecurring
    case splashCleaningTodos
    case splashRefreshingFX
    case splashRefreshingWeather
    case splashSyncingMonobank
    case splashFinalizing

    // Weekdays (Manual if needed, or use Locale)
    // We will often use DateFormatter with .locale, but for explicit UI labels:
    case mon, tue, wed, thu, fri, sat, sun

    // Todo
    case tabTodo
    case addTodo
    case editTodo
    case todoTitle
    case addCategory
    case editCategory
    case categoryName
    case parentCategory
    case noCategory
    case category
    case priority
    case priorityHigh
    case priorityMedium
    case priorityLow
    case dueDate
    case hasDueDate
    case recurring
    case weekly
    case monthly
    case yearly
    case everyNWeeks(Int)
    case everyNMonths(Int)
    case everyNYears(Int)
    case endDate
    case subtasks
    case addSubtask
    case noTodos
    case tapToAddTodo
    case todosCount(Int)
    case completed
    case inProgress
    case queued

    // Sorting
    case sortBy
    case newestFirst
    case oldestFirst
    case manual

    // Filter / Search
    case search
    case all
    case overdue

    // Pin
    case pin
    case unpin
    case pinned

    // Settings
    case settings
    case appInfo
    case version
    case build
    case mode
    case debugSettings

    // Monobank
    case monobankTitle
    case monobankConsent
    case monobankPersonalToken
    case monobankPasteToken
    case monobankConnect
    case monobankReconnect
    case monobankSyncNow
    case monobankSyncing
    case monobankImportRange
    case monobankRange30Days
    case monobankRange90Days
    case monobankRange365Days
    case monobankRangeCustom
    case monobankFrom
    case monobankTo
    case monobankSyncAccounts
    case monobankStatus
    case monobankTokenState
    case monobankAuthorizationState
    case monobankLastError
    case monobankTokenPresent
    case monobankTokenMissing
    case monobankNoErrors
    case monobankConnected
    case monobankDisconnected
    case monobankUnauthorized
    case monobankSyncError
    case monobankNever
    case monobankLastSync
    case monobankPendingConflicts
    case monobankDisconnect
    case monobankDisconnectTitle
    case monobankDisconnectKeepImported
    case monobankDisconnectDeleteImported
    case monobankDisconnectPrompt
    case monobankConnectedAndSynced
    case monobankSyncSummary(Int, Int, Int)
    case monobankDisconnectedMessage
    case monobankConflictsCount(Int)
    case monobankConflictTitle
    case monobankKeepLocal
    case monobankUseBank
    case monobankStatementId(String)
    case monobankCardDetails
    case monobankCardTheme
    case monobankTransactions
    case monobankMinAmount
    case monobankMaxAmount
    case monobankNoTransactionsForFilters
    case monobankItemsCount(Int)
    case pinnedTrend
    case monobankRemoveCard
    case monobankRemoveCardTitle
    case monobankRemoveCardPrompt
    case monobankRemoveCardKeepImported
    case monobankRemoveCardDeleteImported
    case monobankThemeAuto
    case monobankThemeBlack
    case monobankThemeWhite
    case monobankThemePlatinum
    case monobankThemeIron

    // Repeat Reminder
    case repeatReminder
    case repeatReminderOff
    case everyNMinutes(Int)
    case repeatReminderFromDate
    case repeatReminderCount

    // Holidays
    case holidays
    case holidayCountry
    case holidayLanguage
    case holidayApiKey
    case holidayNone
    case holidaySyncNow
    case holidayLastSync
    case holidaySearchCountry
    case holidaySyncing
    case holidaySyncSuccess
    case holidaySyncError
    case holiday
    case holidayNever
    case holidayApiKeyPlaceholder
    case fxRates
    case fxRate
    case fxRateToUAH
    case fxManualOverride
    case fxLastUpdated(String)

    // Expenses
    case expenseWeekly
    case expenseMonthly
    case expenseYearly
    case expenseTotal
    case expenseNoExpenses
    case expenseTapToAdd
    case expenseAdd
    case expenseEdit
    case expenseAmount
    case expenseCategory
    case expensePaymentMethod
    case expenseCurrency
    case expenseMerchant
    case expenseCash
    case expenseCard
    case expenseGroceries
    case expenseHousing
    case expenseTransportation
    case expenseSubscriptions
    case expenseHealthcare
    case expenseDebt
    case expenseEntertainment
    case expenseDining
    case expenseShopping
    case expenseOther
    case templateDetails
    case templateTitlePlaceholder
    case merchantPlaceholder
    case amountTolerance
    case addRecurringExpense
    case editRecurringExpense
    case startDate
    case amount
    case merchant
    case frequency

    // Weather
    case weather
    case minTemp
    case maxTemp
    case dailyForecast
    case hourlyForecast
    case city
    case searchCity
    case weatherSearchPrompt
    case weatherClear
    case weatherPartlyCloudy
    case weatherOvercast
    case weatherFog
    case weatherDrizzle
    case weatherRain
    case weatherSnow
    case weatherThunderstorm
    case weatherCloudy

    // Expense View UI
    case expenseHeader
    case expenseHistory
    case expenseBudget
    case expenseInsights
    case forecast
    case forecastNoData
    case forecastMonthlyTotals
    case forecastDailyTotals
    case expensePeriodAll
    case expensePeriodWeekly
    case expensePeriodMonthly
    case expensePeriodYearly
    case expenseTotalCapitalized
    case expenseExpensesLabel
    case expenseIncomeLabel
    case expenseIncomeToggle

    // Expense Dialogs
    case clearAllDataPrompt
    case clearAllExpensesConfirm
    case clearAllTemplatesConfirm
    case clearEverythingConfirm

    // CSV Import
    case importFromBank
    case transactions
    case duplicates
    case duplicateSuggestionsX(Int)
    case possibleDuplicate
    case merge
    case dismiss
    case analyzingCSV
    case cannotAccessFile
    case noFileSelected
    case selectPatternsPrompt
    case createTemplatesX(Int)

    // Budget & Recurring
    case activeRecurringX(Int)
    case pausedX(Int)
    case inactiveX(Int)
    case budgets
    case addBudget
    case editBudget
    case noBudgetsYet
    case budgetUsedPercent(Int)
    case budgetWarningTitle
    case budgetWarningBody(String)
    case budgetExceededTitle
    case budgetExceededBody(String)
    case budgetRolloverAmount(String)
    case budgetRemainingAmount(String)
    case budgetPerDayAmount(String)
    case budgetEnableRollover
    case budgetDailyTarget
    case budgetPresetEssentials
    case budgetPresetBalanced
    case budgetPresetStudent
    case pause
    case resume
    case activate
    case nextOccurrence(String)
    case forecastScenario
    case forecastScenarioBaseline
    case forecastScenarioConservative
    case forecastScenarioOptimistic
    case forecastConfidenceRange
    case forecastNetRange(String, String)
    case whatIfPlanner
    case whatIfScenarioTitle
    case whatIfExtraExpenses
    case whatIfExtraIncome
    case whatIfLatest(String)
    case insightsTopDrivers
    case insightsAnomalies
    case insightsWhatIfScenarios
    case insightsBaseline(String)

    // Insights
    case spendingTrends
    case thisMonthSpending
    case incomeThisMonth
    case netIncome(String)
    case wasAmount(String)
    case detectedXTimes(Int)
    case failedToReadFile(String)

    // Additional Expense Keys
    case noExpenses
    case activeRecurring
    case paused
    case expenseNoRecurringExpenses
    case importBankStatement
    case uploadCSV
    case selectCSVFile
    case recurringPatternsDetected
    case patternsFound
    case selectPatterns
    case createTemplates
    case importAllTransactions
    case importAnotherFile
    case noDataYet
    case addExpensesForInsights
    case detected
    case categories
    case lastOccurrences
    case next
    case yearlyProjection
  }

  public static func string(_ key: Key) -> String {
    let lang = currentLanguage

    switch key {
    // Common
    case .save:
      return lang == .ukrainian ? "Зберегти" : "Save"
    case .cancel:
      return lang == .ukrainian ? "Скасувати" : "Cancel"
    case .update:
      return lang == .ukrainian ? "Оновити" : "Update"
    case .delete:
      return lang == .ukrainian ? "Видалити" : "Delete"
    case .clearAll:
      return lang == .ukrainian ? "Очистити все" : "Clear All"
    case .clearAllExpenses:
      return lang == .ukrainian ? "Очистити всі витрати" : "Clear All Expenses"
    case .clearAllTemplates:
      return lang == .ukrainian ? "Очистити всі шаблони" : "Clear All Templates"
    case .clearEverything:
      return lang == .ukrainian ? "Очистити все" : "Clear Everything"
    case .cannotBeUndone:
      return lang == .ukrainian
        ? "Цю дію не можна скасувати. Всі ваші дані будуть видалені назавжди."
        : "This action cannot be undone. All your data will be permanently deleted."
    case .templates:
      return lang == .ukrainian ? "Шаблони" : "Templates"

    // Calendar
    case .selectDate:
      return lang == .ukrainian ? "Оберіть дату" : "Select a date"
    case .eventsCount(let count):
      if lang == .ukrainian {
        // Simple pluralization for UA (can be complex, simplification: "X подій")
        return "\(count) подій"
      } else {
        return "\(count) event\(count == 1 ? "" : "s")"
      }
    case .noEvents:
      return lang == .ukrainian ? "Немає подій" : "No events"
    case .tapToAdd:
      return lang == .ukrainian ? "Натисніть, щоб додати" : "Tap to add"
    case .addEvent:
      return lang == .ukrainian ? "Додати подію" : "Add event"

    // Add/Edit
    case .newEvent:
      return lang == .ukrainian ? "Нова подія" : "New Event"
    case .editEvent:
      return lang == .ukrainian ? "Редагувати подію" : "Edit Event"
    case .title:
      return lang == .ukrainian ? "Назва" : "Title"
    case .eventTitlePlaceholder:
      return lang == .ukrainian ? "Назва події" : "Event Title"
    case .notes:
      return lang == .ukrainian ? "Нотатки" : "Notes"
    case .notesPlaceholder:
      return lang == .ukrainian ? "Додати нотатки..." : "Add notes..."
    case .color:
      return lang == .ukrainian ? "Колір" : "Color"
    case .date:
      return lang == .ukrainian ? "Дата" : "Date"
    case .reminder:
      return lang == .ukrainian ? "Нагадування" : "Reminder"
    case .none:
      return lang == .ukrainian ? "Немає" : "None"
    case .atTimeOfEvent:
      return lang == .ukrainian ? "Під час події" : "At time of event"
    case .minutesBefore(let min):
      return lang == .ukrainian ? "\(min) хв до" : "\(min) mins before"
    case .hoursBefore(let hours):
      return lang == .ukrainian ? "\(hours) год до" : "\(hours) hours before"
    case .dayBefore:
      return lang == .ukrainian ? "1 день до" : "1 day before"
    case .daysBefore(let days):
      return lang == .ukrainian ? "\(days) днів до" : "\(days) days before"
    case .minutesShort(let min):
      return lang == .ukrainian ? "\(min) хв" : "\(min) min"
    case .minutesUnit:
      return lang == .ukrainian ? "хв" : "min"

    // Widget
    case .active:
      return lang == .ukrainian ? "Активний" : "Active"
    case .idle:
      return lang == .ukrainian ? "Очікування" : "Idle"
    case .alarm:
      return lang == .ukrainian ? "Будильник" : "Alarm"
    case .timer:
      return lang == .ukrainian ? "Таймер" : "Timer"
    case .set:
      return lang == .ukrainian ? "Встановлено" : "Set"
    case .off:
      return lang == .ukrainian ? "Вимк" : "Off"
    case .status:
      return lang == .ukrainian ? "Статус" : "Status"

    // Accessibility / Navigation
    case .previousMonth:
      return lang == .ukrainian ? "Попередній місяць" : "Previous month"
    case .nextMonth:
      return lang == .ukrainian ? "Наступний місяць" : "Next month"
    case .calendarFor(let dateString):
      return lang == .ukrainian ? "Календар на \(dateString)" : "Calendar for \(dateString)"

    // Tabs
    case .tabCalendar:
      return lang == .ukrainian ? "Календар" : "Calendar"
    case .tabTimer:
      return lang == .ukrainian ? "Таймер" : "Timer"
    case .tabAlarm:
      return lang == .ukrainian ? "Будильник" : "Alarm"
    case .tabExpenses:
      return lang == .ukrainian ? "Банк" : "Bank"
    case .tabClock:
      return lang == .ukrainian ? "Годинник" : "Clock"
    case .tabBudget:
      return lang == .ukrainian ? "Бюджет" : "Budget"

    // Alarm View
    case .noAlarmSet:
      return lang == .ukrainian ? "Будильник не встановлено" : "No Alarm Set"
    case .tapToSetAlarm:
      return lang == .ukrainian
        ? "Натисніть кнопку нижче, щоб встановити будильник"
        : "Tap the button below to set an alarm"
    case .setAlarm:
      return lang == .ukrainian ? "Встановити будильник" : "Set Alarm"
    case .edit:
      return lang == .ukrainian ? "Редагувати" : "Edit"

    // Weekdays
    case .mon: return "Mon"  // Usually formatted by DateFormatter
    case .tue: return "Tue"
    case .wed: return "Wed"
    case .thu: return "Thu"
    case .fri: return "Fri"
    case .sat: return "Sat"
    case .sun: return "Sun"

    // Time Picker / Timer
    case .timePicker:
      return lang == .ukrainian ? "Вибір часу" : "Time picker"
    case .alarmWillRingAt(let time):
      return lang == .ukrainian ? "Будильник продзвенить о \(time)" : "Alarm will ring at \(time)"
    case .alarmSetFor(let time):
      return lang == .ukrainian ? "Будильник встановлено на \(time)" : "Alarm set for \(time)"
    case .countdown:
      return lang == .ukrainian ? "Зворотній відлік" : "Countdown"
    case .selectTimerType:
      return lang == .ukrainian ? "Оберіть тип таймера" : "Select timer type"
    case .timeRemaining(let time):
      return lang == .ukrainian ? "Залишилось часу: \(time)" : "Time remaining: \(time)"
    case .alarmTime(let time):
      return lang == .ukrainian ? "Час будильника: \(time)" : "Alarm time: \(time)"

    // General
    case .pageNotFound:
      return lang == .ukrainian ? "Сторінку не знайдено" : "Page Not Found"
    case .selectTabPrompt:
      return lang == .ukrainian
        ? "Будь ласка, оберіть вкладку на бічній панелі" : "Please select a tab from the sidebar"

    // Startup / Splash
    case .splashStarting:
      return lang == .ukrainian ? "Запуск…" : "Starting…"
    case .splashContinueInBackground:
      return lang == .ukrainian ? "Продовжити у фоновому режимі" : "Continue in background"
    case .splashPreGenerating:
      return lang == .ukrainian
        ? "Підготовка даних та синхронізація віджетів — це може зайняти кілька секунд."
        : "Pre-generating data and syncing widgets — this may take a few seconds."

    case .splashPreparing:
      return lang == .ukrainian ? "Підготовка…" : "Preparing…"
    case .splashSyncingWidgets:
      return lang == .ukrainian ? "Синхронізація віджетів…" : "Syncing widgets…"
    case .splashGeneratingRecurring:
      return lang == .ukrainian ? "Генерація повторюваних записів…" : "Generating recurring items…"
    case .splashCleaningTodos:
      return lang == .ukrainian ? "Очищення завдань…" : "Cleaning up todos…"
    case .splashRefreshingFX:
      return lang == .ukrainian ? "Оновлення FX курсів…" : "Refreshing FX rates…"
    case .splashRefreshingWeather:
      return lang == .ukrainian ? "Оновлення погоди…" : "Refreshing weather…"
    case .splashSyncingMonobank:
      return lang == .ukrainian ? "Синхронізація Monobank…" : "Syncing Monobank…"
    case .splashFinalizing:
      return lang == .ukrainian ? "Завершення…" : "Finalizing…"

    // Todo
    case .tabTodo:
      return lang == .ukrainian ? "Завдання" : "Todo"
    case .addTodo:
      return lang == .ukrainian ? "Додати завдання" : "Add Todo"
    case .editTodo:
      return lang == .ukrainian ? "Редагувати завдання" : "Edit Todo"
    case .todoTitle:
      return lang == .ukrainian ? "Назва завдання" : "Todo Title"
    case .addCategory:
      return lang == .ukrainian ? "Додати категорію" : "Add Category"
    case .editCategory:
      return lang == .ukrainian ? "Редагувати категорію" : "Edit Category"
    case .categoryName:
      return lang == .ukrainian ? "Назва категорії" : "Category Name"
    case .parentCategory:
      return lang == .ukrainian ? "Батьківська категорія" : "Parent Category"
    case .noCategory:
      return lang == .ukrainian ? "Без категорії" : "No Category"
    case .category:
      return lang == .ukrainian ? "Категорія" : "Category"
    case .priority:
      return lang == .ukrainian ? "Пріоритет" : "Priority"
    case .priorityHigh:
      return lang == .ukrainian ? "Високий" : "High"
    case .priorityMedium:
      return lang == .ukrainian ? "Середній" : "Medium"
    case .priorityLow:
      return lang == .ukrainian ? "Низький" : "Low"
    case .dueDate:
      return lang == .ukrainian ? "Термін" : "Due Date"
    case .hasDueDate:
      return lang == .ukrainian ? "Встановити термін" : "Set Due Date"
    case .recurring:
      return lang == .ukrainian ? "Повторення" : "Recurring"
    case .weekly:
      return lang == .ukrainian ? "Щотижня" : "Weekly"
    case .monthly:
      return lang == .ukrainian ? "Щомісяця" : "Monthly"
    case .yearly:
      return lang == .ukrainian ? "Щороку" : "Yearly"
    case .everyNWeeks(let n):
      return lang == .ukrainian ? "Кожні \(n) тижнів" : "Every \(n) week\(n == 1 ? "" : "s")"
    case .everyNMonths(let n):
      return lang == .ukrainian ? "Кожні \(n) місяців" : "Every \(n) month\(n == 1 ? "" : "s")"
    case .everyNYears(let n):
      return lang == .ukrainian ? "Кожні \(n) років" : "Every \(n) year\(n == 1 ? "" : "s")"
    case .endDate:
      return lang == .ukrainian ? "Дата завершення" : "End Date"
    case .subtasks:
      return lang == .ukrainian ? "Підзавдання" : "Subtasks"
    case .addSubtask:
      return lang == .ukrainian ? "Додати підзавдання" : "Add Subtask"
    case .noTodos:
      return lang == .ukrainian ? "Немає завдань" : "No Todos"
    case .tapToAddTodo:
      return lang == .ukrainian ? "Натисніть, щоб додати завдання" : "Tap to add a todo"
    case .todosCount(let count):
      if lang == .ukrainian {
        return "\(count) завдань"
      } else {
        return "\(count) todo\(count == 1 ? "" : "s")"
      }
    case .completed:
      return lang == .ukrainian ? "виконано" : "completed"
    case .inProgress:
      return lang == .ukrainian ? "в процесі" : "in progress"
    case .queued:
      return lang == .ukrainian ? "в черзі" : "queued"
    case .sortBy:
      return lang == .ukrainian ? "Сортувати" : "Sort by"
    case .newestFirst:
      return lang == .ukrainian ? "Спочатку нові" : "Newest first"
    case .oldestFirst:
      return lang == .ukrainian ? "Спочатку старі" : "Oldest first"
    case .manual:
      return lang == .ukrainian ? "Вручну" : "Manual"
    case .search:
      return lang == .ukrainian ? "Пошук" : "Search"
    case .all:
      return lang == .ukrainian ? "Всі" : "All"
    case .overdue:
      return lang == .ukrainian ? "Прострочені" : "Overdue"
    case .pin:
      return lang == .ukrainian ? "Закріпити" : "Pin"
    case .unpin:
      return lang == .ukrainian ? "Відкріпити" : "Unpin"
    case .pinned:
      return lang == .ukrainian ? "Закріплені" : "Pinned"
    case .settings:
      return lang == .ukrainian ? "Налаштування" : "Settings"
    case .appInfo:
      return lang == .ukrainian ? "Про додаток" : "App Info"
    case .version:
      return lang == .ukrainian ? "Версія" : "Version"
    case .build:
      return lang == .ukrainian ? "Збірка" : "Build"
    case .mode:
      return lang == .ukrainian ? "Режим" : "Mode"
    case .debugSettings:
      return lang == .ukrainian ? "Налаштування налагодження" : "Debug Settings"

    // Monobank
    case .monobankTitle:
      return "Monobank"
    case .monobankConsent:
      return lang == .ukrainian
        ? "Я погоджуюсь на підключення даних Monobank"
        : "I consent to linking Monobank data"
    case .monobankPersonalToken:
      return lang == .ukrainian ? "Персональний токен" : "Personal token"
    case .monobankPasteToken:
      return lang == .ukrainian ? "Вставте X-Token" : "Paste X-Token"
    case .monobankConnect:
      return lang == .ukrainian ? "Підключити" : "Connect"
    case .monobankReconnect:
      return lang == .ukrainian ? "Перепідключити" : "Reconnect"
    case .monobankSyncNow:
      return lang == .ukrainian ? "Синхронізувати" : "Sync now"
    case .monobankSyncing:
      return lang == .ukrainian ? "Синхронізація…" : "Syncing…"
    case .monobankImportRange:
      return lang == .ukrainian ? "Період імпорту" : "Import range"
    case .monobankRange30Days:
      return lang == .ukrainian ? "30 днів" : "30 days"
    case .monobankRange90Days:
      return lang == .ukrainian ? "90 днів" : "90 days"
    case .monobankRange365Days:
      return lang == .ukrainian ? "365 днів" : "365 days"
    case .monobankRangeCustom:
      return lang == .ukrainian ? "Кастомний" : "Custom"
    case .monobankFrom:
      return lang == .ukrainian ? "Від" : "From"
    case .monobankTo:
      return lang == .ukrainian ? "До" : "To"
    case .monobankSyncAccounts:
      return lang == .ukrainian ? "Рахунки для синхронізації" : "Sync accounts"
    case .monobankStatus:
      return lang == .ukrainian ? "Статус" : "Status"
    case .monobankTokenState:
      return lang == .ukrainian ? "Токен" : "Token"
    case .monobankAuthorizationState:
      return lang == .ukrainian ? "Авторизація" : "Authorization"
    case .monobankLastError:
      return lang == .ukrainian ? "Остання помилка" : "Last error"
    case .monobankTokenPresent:
      return lang == .ukrainian ? "Наявний" : "Present"
    case .monobankTokenMissing:
      return lang == .ukrainian ? "Відсутній" : "Missing"
    case .monobankNoErrors:
      return lang == .ukrainian ? "Немає" : "None"
    case .monobankConnected:
      return lang == .ukrainian ? "Підключено" : "Connected"
    case .monobankDisconnected:
      return lang == .ukrainian ? "Відключено" : "Disconnected"
    case .monobankUnauthorized:
      return lang == .ukrainian ? "Токен недійсний" : "Token unauthorized"
    case .monobankSyncError:
      return lang == .ukrainian ? "Помилка синхронізації" : "Sync error"
    case .monobankNever:
      return lang == .ukrainian ? "Ніколи" : "Never"
    case .monobankLastSync:
      return lang == .ukrainian ? "Остання синхронізація" : "Last sync"
    case .monobankPendingConflicts:
      return lang == .ukrainian ? "Конфлікти" : "Pending conflicts"
    case .monobankDisconnect:
      return lang == .ukrainian ? "Відключити" : "Disconnect"
    case .monobankDisconnectTitle:
      return lang == .ukrainian ? "Відключити Monobank" : "Disconnect Monobank"
    case .monobankDisconnectKeepImported:
      return lang == .ukrainian ? "Залишити імпортовані витрати" : "Keep imported expenses"
    case .monobankDisconnectDeleteImported:
      return lang == .ukrainian ? "Видалити імпортовані витрати" : "Delete imported expenses"
    case .monobankDisconnectPrompt:
      return lang == .ukrainian
        ? "Оберіть, що робити з уже імпортованими транзакціями."
        : "Choose what to do with already imported transactions."
    case .monobankConnectedAndSynced:
      return lang == .ukrainian ? "Підключено та синхронізовано." : "Connected and synced."
    case .monobankSyncSummary(let imported, let updated, let conflicts):
      return lang == .ukrainian
        ? "Імпортовано: \(imported), Оновлено: \(updated), Конфлікти: \(conflicts)"
        : "Imported: \(imported), Updated: \(updated), Conflicts: \(conflicts)"
    case .monobankDisconnectedMessage:
      return lang == .ukrainian ? "Відключено." : "Disconnected."
    case .monobankConflictsCount(let count):
      return lang == .ukrainian ? "Конфлікти Monobank: \(count)" : "Monobank conflicts: \(count)"
    case .monobankConflictTitle:
      return lang == .ukrainian ? "Конфлікт синхронізації банку" : "Bank sync conflict"
    case .monobankKeepLocal:
      return lang == .ukrainian ? "Залишити локальне" : "Keep local"
    case .monobankUseBank:
      return lang == .ukrainian ? "Використати банк" : "Use bank"
    case .monobankStatementId(let id):
      return lang == .ukrainian ? "ID виписки: \(id)" : "Statement ID: \(id)"
    case .monobankCardDetails:
      return lang == .ukrainian ? "Деталі картки" : "Card details"
    case .monobankCardTheme:
      return lang == .ukrainian ? "Тема картки" : "Card theme"
    case .monobankTransactions:
      return lang == .ukrainian ? "Транзакції" : "Transactions"
    case .monobankMinAmount:
      return lang == .ukrainian ? "Мін" : "Min"
    case .monobankMaxAmount:
      return lang == .ukrainian ? "Макс" : "Max"
    case .monobankNoTransactionsForFilters:
      return lang == .ukrainian
        ? "Немає транзакцій для поточних фільтрів."
        : "No transactions for current filters."
    case .monobankItemsCount(let count):
      return lang == .ukrainian ? "\(count) елементів" : "\(count) items"
    case .pinnedTrend:
      return lang == .ukrainian ? "Тренд закріплених" : "Pinned trend"
    case .monobankRemoveCard:
      return lang == .ukrainian ? "Прибрати картку" : "Remove card"
    case .monobankRemoveCardTitle:
      return lang == .ukrainian ? "Прибрати картку" : "Remove card"
    case .monobankRemoveCardPrompt:
      return lang == .ukrainian
        ? "Оберіть, що робити з уже імпортованими транзакціями цієї картки."
        : "Choose what to do with already imported transactions for this card."
    case .monobankRemoveCardKeepImported:
      return lang == .ukrainian ? "Залишити імпортовані" : "Keep imported"
    case .monobankRemoveCardDeleteImported:
      return lang == .ukrainian ? "Видалити імпортовані" : "Delete imported"
    case .monobankThemeAuto:
      return lang == .ukrainian ? "Авто" : "Auto"
    case .monobankThemeBlack:
      return lang == .ukrainian ? "Чорна" : "Black"
    case .monobankThemeWhite:
      return lang == .ukrainian ? "Біла" : "White"
    case .monobankThemePlatinum:
      return lang == .ukrainian ? "Платинова" : "Platinum"
    case .monobankThemeIron:
      return lang == .ukrainian ? "Залізна" : "Iron"

    // Repeat Reminder
    case .repeatReminder:
      return lang == .ukrainian ? "Повторне нагадування" : "Repeat Reminder"
    case .repeatReminderOff:
      return lang == .ukrainian ? "Вимкнено" : "Off"
    case .everyNMinutes(let n):
      return lang == .ukrainian ? "Кожні \(n) хв" : "Every \(n) min"
    case .repeatReminderFromDate:
      return lang == .ukrainian ? "Нагадувати з" : "Remind from"
    case .repeatReminderCount:
      return lang == .ukrainian ? "Кількість разів" : "Times"

    // Holidays
    case .holidays:
      return lang == .ukrainian ? "Свята" : "Holidays"
    case .holidayCountry:
      return lang == .ukrainian ? "Країна" : "Country"
    case .holidayLanguage:
      return lang == .ukrainian ? "Мова" : "Language"
    case .holidayApiKey:
      return lang == .ukrainian ? "API ключ" : "API Key"
    case .holidayNone:
      return lang == .ukrainian ? "Не вибрано" : "None"
    case .holidaySyncNow:
      return lang == .ukrainian ? "Синхронізувати" : "Sync Now"
    case .holidayLastSync:
      return lang == .ukrainian ? "Остання синхронізація" : "Last Sync"
    case .holidaySearchCountry:
      return lang == .ukrainian ? "Пошук країни" : "Search country"
    case .holidaySyncing:
      return lang == .ukrainian ? "Синхронізація..." : "Syncing..."
    case .holidaySyncSuccess:
      return lang == .ukrainian ? "Синхронізовано" : "Synced"
    case .holidaySyncError:
      return lang == .ukrainian ? "Помилка синхронізації" : "Sync Error"
    case .holiday:
      return lang == .ukrainian ? "Свято" : "Holiday"
    case .holidayNever:
      return lang == .ukrainian ? "Ніколи" : "Never"
    case .holidayApiKeyPlaceholder:
      return lang == .ukrainian ? "Введіть API ключ" : "Enter API key"
    case .fxRates:
      return lang == .ukrainian ? "FX курси" : "FX Rates"
    case .fxRate:
      return lang == .ukrainian ? "Курс" : "Rate"
    case .fxRateToUAH:
      return lang == .ukrainian ? "Курс до UAH" : "Rate to UAH"
    case .fxManualOverride:
      return lang == .ukrainian ? "Ручне перевизначення" : "Manual override"
    case .fxLastUpdated(let value):
      return lang == .ukrainian ? "Оновлено: \(value)" : "Updated: \(value)"

    // Expenses
    case .expenseWeekly:
      return lang == .ukrainian ? "Тижневі" : "Weekly"
    case .expenseMonthly:
      return lang == .ukrainian ? "Місячні" : "Monthly"
    case .expenseYearly:
      return lang == .ukrainian ? "Річні" : "Yearly"
    case .expenseTotal:
      return lang == .ukrainian ? "Загалом" : "Total"
    case .expenseNoExpenses:
      return lang == .ukrainian ? "Немає витрат" : "No Expenses"
    case .expenseTapToAdd:
      return lang == .ukrainian ? "Натисніть +, щоб додати витрату" : "Tap + to add an expense"
    case .expenseAdd:
      return lang == .ukrainian ? "Додати витрату" : "Add Expense"
    case .expenseEdit:
      return lang == .ukrainian ? "Редагувати витрату" : "Edit Expense"
    case .expenseAmount:
      return lang == .ukrainian ? "Сума" : "Amount"
    case .expenseCategory:
      return lang == .ukrainian ? "Категорія" : "Category"
    case .expensePaymentMethod:
      return lang == .ukrainian ? "Спосіб оплати" : "Payment Method"
    case .expenseCurrency:
      return lang == .ukrainian ? "Валюта" : "Currency"
    case .expenseMerchant:
      return lang == .ukrainian ? "Продавець" : "Merchant"
    case .expenseCash:
      return lang == .ukrainian ? "Готівка" : "Cash"
    case .expenseCard:
      return lang == .ukrainian ? "Картка" : "Card"
    case .expenseGroceries:
      return lang == .ukrainian ? "Продукти" : "Groceries"
    case .expenseHousing:
      return lang == .ukrainian ? "Житло" : "Housing"
    case .expenseTransportation:
      return lang == .ukrainian ? "Транспорт" : "Transportation"
    case .expenseSubscriptions:
      return lang == .ukrainian ? "Підписки" : "Subscriptions"
    case .expenseHealthcare:
      return lang == .ukrainian ? "Здоров'я" : "Healthcare"
    case .expenseDebt:
      return lang == .ukrainian ? "Борги" : "Debt"
    case .expenseEntertainment:
      return lang == .ukrainian ? "Розваги" : "Entertainment"
    case .expenseDining:
      return lang == .ukrainian ? "Їжа" : "Dining"
    case .expenseShopping:
      return lang == .ukrainian ? "Покупки" : "Shopping"
    case .expenseOther:
      return lang == .ukrainian ? "Інше" : "Other"
    case .templateDetails:
      return lang == .ukrainian ? "Деталі шаблону" : "Template Details"
    case .templateTitlePlaceholder:
      return lang == .ukrainian ? "Назва (наприклад, Netflix)" : "Title (e.g., Netflix)"
    case .merchantPlaceholder:
      return lang == .ukrainian ? "Назва продавця" : "Merchant name"
    case .amountTolerance:
      return lang == .ukrainian ? "Допустима різниця суми" : "Amount tolerance"
    case .addRecurringExpense:
      return lang == .ukrainian ? "Додати періодичну витрату" : "Add Recurring Expense"
    case .editRecurringExpense:
      return lang == .ukrainian ? "Редагувати періодичну витрату" : "Edit Recurring Expense"
    case .startDate:
      return lang == .ukrainian ? "Дата початку" : "Start date"
    case .amount:
      return lang == .ukrainian ? "Сума" : "Amount"
    case .merchant:
      return lang == .ukrainian ? "Продавець" : "Merchant"
    case .frequency:
      return lang == .ukrainian ? "Частота" : "Frequency"
    case .noExpenses:
      return lang == .ukrainian ? "Немає витрат" : "No expenses"
    case .activeRecurring:
      return lang == .ukrainian ? "Активні періодичні" : "Active Recurring"
    case .paused:
      return lang == .ukrainian ? "Призупинені" : "Paused"
    case .expenseNoRecurringExpenses:
      return lang == .ukrainian ? "Немає періодичних витрат" : "No Recurring Expenses"
    case .importBankStatement:
      return lang == .ukrainian ? "Імпорт виписки банку" : "Import Bank Statement"
    case .uploadCSV:
      return lang == .ukrainian
        ? "Завантажте CSV файл з Monobank або PUMB для автоматичного виявлення періодичних витрат."
        : "Upload a CSV file from Monobank or PUMB to automatically detect recurring expenses."
    case .selectCSVFile:
      return lang == .ukrainian ? "Обрати CSV файл" : "Select CSV File"
    case .recurringPatternsDetected:
      return lang == .ukrainian
        ? "Виявлено періодичні витрати" : "Recurring Expense Patterns Detected"
    case .patternsFound:
      return lang == .ukrainian ? "знайдено" : "found"
    case .selectPatterns:
      return lang == .ukrainian
        ? "Оберіть шаблони для автоматичного відстеження"
        : "Select patterns to create templates for automatic tracking"
    case .createTemplates:
      return lang == .ukrainian ? "Створити шаблони" : "Create Templates"
    case .importAllTransactions:
      return lang == .ukrainian ? "Імпортувати всі транзакції" : "Import All Transactions"
    case .importAnotherFile:
      return lang == .ukrainian ? "Імпортувати інший файл" : "Import Another File"
    case .spendingTrends:
      return lang == .ukrainian ? "Тренди витрат" : "Spending Trends"
    case .thisMonthSpending:
      return lang == .ukrainian ? "Витрати цього місяця" : "This Month's Spending"
    case .incomeThisMonth:
      return lang == .ukrainian ? "Дохід цього місяця" : "Income This Month"
    case .noDataYet:
      return lang == .ukrainian ? "Даних ще немає" : "No Data Yet"
    case .addExpensesForInsights:
      return lang == .ukrainian
        ? "Додайте витрати, щоб побачити аналітику та тренди"
        : "Add some expenses to see insights and trends"
    case .detected:
      return lang == .ukrainian ? "Виявлено" : "Detected"
    case .categories:
      return lang == .ukrainian ? "Категорії" : "Categories"
    case .lastOccurrences:
      return lang == .ukrainian ? "Останні:" : "Last occurrences:"
    case .next:
      return lang == .ukrainian ? "Далі:" : "Next:"
    case .yearlyProjection:
      return lang == .ukrainian ? "Річна прогнозна сума" : "Yearly Projection"

    // Weather
    case .weather:
      return lang == .ukrainian ? "Погода" : "Weather"
    case .minTemp:
      return lang == .ukrainian ? "Мін." : "Min"
    case .maxTemp:
      return lang == .ukrainian ? "Макс." : "Max"
    case .dailyForecast:
      return lang == .ukrainian ? "Прогноз на тиждень" : "Daily Forecast"
    case .hourlyForecast:
      return lang == .ukrainian ? "Прогноз по годинах" : "Hourly Forecast"
    case .city:
      return lang == .ukrainian ? "Місто" : "City"
    case .searchCity:
      return lang == .ukrainian ? "Пошук міста..." : "Search city..."
    case .weatherSearchPrompt:
      return lang == .ukrainian
        ? "Пошукайте місто, щоб побачити погоду" : "Search for a city to see weather"
    case .weatherClear:
      return lang == .ukrainian ? "Ясно" : "Clear"
    case .weatherPartlyCloudy:
      return lang == .ukrainian ? "Мінлива хмарність" : "Partly Cloudy"
    case .weatherOvercast:
      return lang == .ukrainian ? "Пасмурно" : "Overcast"
    case .weatherFog:
      return lang == .ukrainian ? "Туман" : "Fog"
    case .weatherDrizzle:
      return lang == .ukrainian ? "Мряка" : "Drizzle"
    case .weatherRain:
      return lang == .ukrainian ? "Дощ" : "Rain"
    case .weatherSnow:
      return lang == .ukrainian ? "Сніг" : "Snow"
    case .weatherThunderstorm:
      return lang == .ukrainian ? "Гроза" : "Thunderstorm"
    case .weatherCloudy:
      return lang == .ukrainian ? "Хмарно" : "Cloudy"
    case .tabWeather:
      return lang == .ukrainian ? "Погода" : "Weather"
    case .today:
      return lang == .ukrainian ? "Сьогодні" : "Today"
    case .remaining:
      return lang == .ukrainian ? "Залишилось" : "Remaining"
    case .elapsed:
      return lang == .ukrainian ? "Минуло" : "Elapsed"
    case .more(let count):
      return lang == .ukrainian ? "Ще \(count)" : "\(count) more"
    case .add:
      return lang == .ukrainian ? "Додати" : "Add"
    case .total:
      return lang == .ukrainian ? "Всього" : "Total"
    case .expenseHeader:
      return lang == .ukrainian ? "ВИТРАТИ" : "EXPENSES"
    case .expenseHistory:
      return lang == .ukrainian ? "Історія" : "History"
    case .expenseBudget:
      return lang == .ukrainian ? "Бюджет" : "Budget"
    case .expenseInsights:
      return lang == .ukrainian ? "Аналітика" : "Insights"
    case .forecast:
      return lang == .ukrainian ? "Прогноз" : "Forecast"
    case .forecastNoData:
      return lang == .ukrainian
        ? "Немає майбутніх витрат або доходів" : "No upcoming expenses or income"
    case .forecastMonthlyTotals:
      return lang == .ukrainian ? "Підсумки по місяцях" : "Monthly Totals"
    case .forecastDailyTotals:
      return lang == .ukrainian ? "Підсумки по днях" : "Daily Totals"
    case .expensePeriodAll:
      return lang == .ukrainian ? "Все" : "All"
    case .expensePeriodWeekly:
      return lang == .ukrainian ? "Тиждень" : "Weekly"
    case .expensePeriodMonthly:
      return lang == .ukrainian ? "Місяць" : "Monthly"
    case .expensePeriodYearly:
      return lang == .ukrainian ? "Рік" : "Yearly"
    case .expenseTotalCapitalized:
      return lang == .ukrainian ? "ЗАГАЛОМ" : "TOTAL"
    case .expenseExpensesLabel:
      return lang == .ukrainian ? "ВИТРАТИ" : "EXPENSES"
    case .expenseIncomeLabel:
      return lang == .ukrainian ? "ДОХІД" : "INCOME"
    case .expenseIncomeToggle:
      return lang == .ukrainian ? "Дохід" : "Income"
    case .clearAllDataPrompt:
      return lang == .ukrainian ? "Очистити всі дані?" : "Clear All Data?"
    case .clearAllExpensesConfirm:
      return lang == .ukrainian ? "Очистити всі витрати" : "Clear All Expenses"
    case .clearAllTemplatesConfirm:
      return lang == .ukrainian ? "Очистити всі шаблони" : "Clear All Templates"
    case .clearEverythingConfirm:
      return lang == .ukrainian ? "Очистити все" : "Clear Everything"
    case .importFromBank:
      return lang == .ukrainian ? "Імпорт з банку" : "Import from Bank"
    case .transactions:
      return lang == .ukrainian ? "Транзакції" : "Transactions"
    case .duplicates:
      return lang == .ukrainian ? "Дублікати" : "Duplicates"
    case .duplicateSuggestionsX(let count):
      return lang == .ukrainian
        ? "Виявлено можливі дублікати: \(count)"
        : "Possible duplicates found: \(count)"
    case .possibleDuplicate:
      return lang == .ukrainian ? "Можливий дублікат" : "Possible duplicate"
    case .merge:
      return lang == .ukrainian ? "Об'єднати" : "Merge"
    case .dismiss:
      return lang == .ukrainian ? "Відхилити" : "Dismiss"
    case .analyzingCSV:
      return lang == .ukrainian ? "Аналіз CSV..." : "Analyzing CSV..."
    case .cannotAccessFile:
      return lang == .ukrainian ? "Не вдалося отримати доступ до файлу" : "Cannot access file"
    case .noFileSelected:
      return lang == .ukrainian ? "Файл не обрано" : "No file selected"
    case .selectPatternsPrompt:
      return lang == .ukrainian
        ? "Оберіть шаблони для автоматичного відстеження"
        : "Select patterns to create templates for automatic tracking"
    case .createTemplatesX(let count):
      return lang == .ukrainian ? "Створити \(count) шаблонів" : "Create \(count) Templates"
    case .activeRecurringX(let count):
      return lang == .ukrainian ? "Активні періодичні (\(count))" : "Active Recurring (\(count))"
    case .pausedX(let count):
      return lang == .ukrainian ? "Призупинені (\(count))" : "Paused (\(count))"
    case .inactiveX(let count):
      return lang == .ukrainian ? "Неактивні (\(count))" : "Inactive (\(count))"
    case .budgets:
      return lang == .ukrainian ? "Бюджети" : "Budgets"
    case .addBudget:
      return lang == .ukrainian ? "Додати бюджет" : "Add Budget"
    case .editBudget:
      return lang == .ukrainian ? "Редагувати бюджет" : "Edit Budget"
    case .noBudgetsYet:
      return lang == .ukrainian ? "Бюджетів ще немає" : "No budgets yet"
    case .budgetUsedPercent(let percent):
      return lang == .ukrainian ? "Використано: \(percent)%" : "Used: \(percent)%"
    case .budgetWarningTitle:
      return lang == .ukrainian ? "Наближення до ліміту" : "Budget Warning"
    case .budgetWarningBody(let amount):
      return lang == .ukrainian
        ? "Ви досягли 80% бюджету. Витрачено: \(amount)"
        : "You reached 80% of your budget. Spent: \(amount)"
    case .budgetExceededTitle:
      return lang == .ukrainian ? "Бюджет перевищено" : "Budget Exceeded"
    case .budgetExceededBody(let amount):
      return lang == .ukrainian
        ? "Ви досягли 100% бюджету. Витрачено: \(amount)"
        : "You reached 100% of your budget. Spent: \(amount)"
    case .budgetRolloverAmount(let amount):
      return lang == .ukrainian ? "Перенесення: \(amount)" : "Rollover: \(amount)"
    case .budgetRemainingAmount(let amount):
      return lang == .ukrainian ? "Залишок: \(amount)" : "Remaining: \(amount)"
    case .budgetPerDayAmount(let amount):
      return lang == .ukrainian ? "На день: \(amount)" : "Per day: \(amount)"
    case .budgetEnableRollover:
      return lang == .ukrainian ? "Увімкнути перенесення" : "Enable rollover"
    case .budgetDailyTarget:
      return lang == .ukrainian ? "Показувати ціль на день" : "Show per-day target"
    case .budgetPresetEssentials:
      return lang == .ukrainian ? "Необхідне" : "Essentials"
    case .budgetPresetBalanced:
      return lang == .ukrainian ? "Збалансований" : "Balanced"
    case .budgetPresetStudent:
      return lang == .ukrainian ? "Студент" : "Student"
    case .pause:
      return lang == .ukrainian ? "Призупинити" : "Pause"
    case .resume:
      return lang == .ukrainian ? "Відновити" : "Resume"
    case .activate:
      return lang == .ukrainian ? "Активувати" : "Activate"
    case .nextOccurrence(let date):
      return lang == .ukrainian ? "Наступна: \(date)" : "Next: \(date)"
    case .forecastScenario:
      return lang == .ukrainian ? "Сценарій" : "Scenario"
    case .forecastScenarioBaseline:
      return lang == .ukrainian ? "Базовий" : "Baseline"
    case .forecastScenarioConservative:
      return lang == .ukrainian ? "Консервативний" : "Conservative"
    case .forecastScenarioOptimistic:
      return lang == .ukrainian ? "Оптимістичний" : "Optimistic"
    case .forecastConfidenceRange:
      return lang == .ukrainian ? "Діапазон впевненості" : "Confidence range"
    case .forecastNetRange(let low, let high):
      return lang == .ukrainian ? "Нетто \(low) ... \(high)" : "Net \(low) ... \(high)"
    case .whatIfPlanner:
      return lang == .ukrainian ? "Планувальник what-if" : "What-if Planner"
    case .whatIfScenarioTitle:
      return lang == .ukrainian ? "Назва сценарію" : "Scenario title"
    case .whatIfExtraExpenses:
      return lang == .ukrainian ? "Додаткові витрати (UAH)" : "Extra expenses (UAH)"
    case .whatIfExtraIncome:
      return lang == .ukrainian ? "Додатковий дохід (UAH)" : "Extra income (UAH)"
    case .whatIfLatest(let value):
      return lang == .ukrainian ? "Останній: \(value)" : "Latest: \(value)"
    case .insightsTopDrivers:
      return lang == .ukrainian ? "Найбільші драйвери витрат" : "Top spend drivers"
    case .insightsAnomalies:
      return lang == .ukrainian ? "Аномалії" : "Anomalies"
    case .insightsWhatIfScenarios:
      return lang == .ukrainian ? "What-if сценарії" : "What-if scenarios"
    case .insightsBaseline(let value):
      return lang == .ukrainian ? "База \(value)" : "Baseline \(value)"
    case .netIncome(let amount):
      return lang == .ukrainian ? "Чистий дохід: \(amount)" : "Net: \(amount)"
    case .wasAmount(let amount):
      return lang == .ukrainian ? "(було \(amount))" : "(was \(amount))"
    case .detectedXTimes(let count):
      return lang == .ukrainian ? "Виявлено \(count)р." : "Detected \(count)x"
    case .failedToReadFile(let error):
      return lang == .ukrainian
        ? "Не вдалося прочитати файл: \(error)" : "Failed to read file: \(error)"
    }
  }
}
