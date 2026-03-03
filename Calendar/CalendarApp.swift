import SwiftData
import SwiftUI
#if canImport(AppIntents)
  import AppIntents
#endif
#if os(iOS)
  import UIKit
#endif

@main
struct CalendarApp: App {
  #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  #endif
  @StateObject private var appState = AppState()
  #if DEBUG
    @StateObject private var debugSettings = DebugSettings()
  #endif

  init() {
    #if os(iOS)
      configureTabBarAppearance()
    #endif
  }

  #if os(iOS)
    private func configureTabBarAppearance() {
      let appearance = UITabBarAppearance()
      appearance.configureWithOpaqueBackground()
      appearance.backgroundColor = UIColor.secondarySystemGroupedBackground
      appearance.shadowColor = UIColor.separator.withAlphaComponent(0.25)

      let normalColor = UIColor.secondaryLabel
      let selectedColor = UIColor.label
      let inlineNormal = [NSAttributedString.Key.foregroundColor: normalColor]
      let inlineSelected = [NSAttributedString.Key.foregroundColor: selectedColor]

      appearance.stackedLayoutAppearance.normal.iconColor = normalColor
      appearance.stackedLayoutAppearance.normal.titleTextAttributes = inlineNormal
      appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
      appearance.stackedLayoutAppearance.selected.titleTextAttributes = inlineSelected

      appearance.inlineLayoutAppearance.normal.iconColor = normalColor
      appearance.inlineLayoutAppearance.normal.titleTextAttributes = inlineNormal
      appearance.inlineLayoutAppearance.selected.iconColor = selectedColor
      appearance.inlineLayoutAppearance.selected.titleTextAttributes = inlineSelected

      appearance.compactInlineLayoutAppearance.normal.iconColor = normalColor
      appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = inlineNormal
      appearance.compactInlineLayoutAppearance.selected.iconColor = selectedColor
      appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = inlineSelected

      UITabBar.appearance().standardAppearance = appearance
      UITabBar.appearance().scrollEdgeAppearance = appearance
    }
  #endif

  var body: some Scene {
    WindowGroup {
      #if DEBUG
        ContentView()
          .environmentObject(appState)
          .environmentObject(debugSettings)
          .preferredColorScheme(debugSettings.themeOverride.colorScheme)
          .tint(.appAccent)
          .modelContainer(for: [
            Event.self, TodoItem.self, TodoCategory.self, Expense.self,
            SubscriptionItem.self, BillItem.self, SavingsGoal.self, CategorizationRule.self,
            ReceiptAttachment.self, NetWorthAccount.self, TripBudget.self,
            WeeklyReviewSnapshot.self, WhatIfScenario.self,
            RecurringExpenseTemplate.self, CSVImportSession.self, Alarm.self, TimerPreset.self,
            TimerSession.self, BudgetLimit.self, CashflowForecastCache.self,
            DuplicateSuggestion.self, FXRate.self, CSVImportMapping.self,
            SavingsContribution.self, NetWorthSnapshot.self,
            NotificationPreferences.self, OnboardingState.self,
            MonobankConnection.self, MonobankAccount.self, MonobankStatementItem.self,
            MonobankSyncState.self, MonobankConflict.self,
          ])
      #else
        ContentView()
          .environmentObject(appState)
          .tint(.appAccent)
          .modelContainer(for: [
            Event.self, TodoItem.self, TodoCategory.self, Expense.self,
            SubscriptionItem.self, BillItem.self, SavingsGoal.self, CategorizationRule.self,
            ReceiptAttachment.self, NetWorthAccount.self, TripBudget.self,
            WeeklyReviewSnapshot.self, WhatIfScenario.self,
            RecurringExpenseTemplate.self, CSVImportSession.self, Alarm.self, TimerPreset.self,
            TimerSession.self, BudgetLimit.self, CashflowForecastCache.self,
            DuplicateSuggestion.self, FXRate.self, CSVImportMapping.self,
            SavingsContribution.self, NetWorthSnapshot.self,
            NotificationPreferences.self, OnboardingState.self,
            MonobankConnection.self, MonobankAccount.self, MonobankStatementItem.self,
            MonobankSyncState.self, MonobankConflict.self,
          ])
      #endif
    }
  }
}

private enum PendingShortcutKind: String, Codable {
  case addExpense
  case addTodo
  case startTimer
  case openTab
  case quickCapture
}

private struct PendingShortcutAction: Codable {
  let kind: PendingShortcutKind
  var title: String?
  var amount: Double?
  var merchant: String?
  var notes: String?
  var targetTab: AppTab?
}

private struct OnboardingFlowView: View {
  let onSkip: () -> Void
  let onFinish: (_ city: String, _ fxUSD: Double?, _ fxEUR: Double?, _ monobankConsent: Bool, _ requestNotificationPermission: Bool) -> Void

  @State private var step = 0
  @State private var city = ""
  @State private var fxUSD = ""
  @State private var fxEUR = ""
  @State private var monobankConsent = false
  @State private var requestNotifications = true

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        ProgressView(value: Double(step + 1), total: 4)
          .tint(.appAccent)
          .padding(.top, 12)

        TabView(selection: $step) {
          onboardingCard(
            title: "Welcome to Calendar",
            subtitle: "Set up your core preferences now. You can edit everything later in Settings."
          )
          .tag(0)

          VStack(alignment: .leading, spacing: 12) {
            onboardingCard(
              title: "Notifications",
              subtitle: "Control reminders for events, todos, budgets, and recurring payments."
            )
            Toggle("Allow notifications now", isOn: $requestNotifications)
          }
          .tag(1)

          VStack(alignment: .leading, spacing: 12) {
            onboardingCard(
              title: "Weather city",
              subtitle: "Used for weather tab and widgets."
            )
            TextField("City (e.g. Kyiv)", text: $city)
              .textFieldStyle(.roundedBorder)
          }
          .tag(2)

          VStack(alignment: .leading, spacing: 12) {
            onboardingCard(
              title: "Finance defaults",
              subtitle: "Optional: set manual FX and consent for Monobank connection."
            )
            TextField("USD → UAH rate (optional)", text: $fxUSD)
              .keyboardType(.decimalPad)
              .textFieldStyle(.roundedBorder)
            TextField("EUR → UAH rate (optional)", text: $fxEUR)
              .keyboardType(.decimalPad)
              .textFieldStyle(.roundedBorder)
            Toggle("I consent to Monobank data linking", isOn: $monobankConsent)
          }
          .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))

        HStack {
          Button("Skip") {
            onSkip()
          }
          .foregroundColor(.secondary)

          Spacer()

          if step > 0 {
            Button("Back") {
              withAnimation { step = max(step - 1, 0) }
            }
          }

          Button(step == 3 ? "Finish" : "Next") {
            if step == 3 {
              onFinish(
                city,
                Double(fxUSD.replacingOccurrences(of: ",", with: ".")),
                Double(fxEUR.replacingOccurrences(of: ",", with: ".")),
                monobankConsent,
                requestNotifications
              )
            } else {
              withAnimation { step = min(step + 1, 3) }
            }
          }
          .buttonStyle(.borderedProminent)
          .tint(.appAccent)
        }
        .padding(.bottom, 8)
      }
      .padding(20)
      .background(Color.backgroundPrimary.ignoresSafeArea())
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  @ViewBuilder
  private func onboardingCard(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.system(size: 22, weight: .bold))
      Text(subtitle)
        .font(.system(size: 14))
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private extension String {
  var nonEmpty: String? {
    isEmpty ? nil : self
  }
}

#if canImport(AppIntents)
  enum ShortcutTab: String, AppEnum {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Tab")
    static var caseDisplayRepresentations: [ShortcutTab: DisplayRepresentation] = [
      .calendar: "Calendar",
      .tasks: "Tasks",
      .expenses: "Expenses",
      .clock: "Clock",
      .weather: "Weather",
    ]

    case calendar
    case tasks
    case expenses
    case clock
    case weather

    var appTab: AppTab {
      switch self {
      case .calendar: return .calendar
      case .tasks: return .tasks
      case .expenses: return .expenses
      case .clock: return .clock
      case .weather: return .weather
      }
    }
  }

  struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Expense"
    static var openAppWhenRun = true

    @Parameter(title: "Title")
    var title: String
    @Parameter(title: "Amount")
    var amount: Double
    @Parameter(title: "Merchant")
    var merchant: String?

    func perform() async throws -> some IntentResult {
      let payload = PendingShortcutAction(
        kind: .addExpense,
        title: title,
        amount: amount,
        merchant: merchant,
        notes: nil,
        targetTab: .expenses
      )
      try await writePendingShortcutAction(payload)
      return .result()
    }
  }

  struct AddTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Todo"
    static var openAppWhenRun = true

    @Parameter(title: "Title")
    var title: String
    @Parameter(title: "Notes")
    var notes: String?

    func perform() async throws -> some IntentResult {
      let payload = PendingShortcutAction(
        kind: .addTodo,
        title: title,
        amount: nil,
        merchant: nil,
        notes: notes,
        targetTab: .tasks
      )
      try await writePendingShortcutAction(payload)
      return .result()
    }
  }

  struct StartTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Timer"
    static var openAppWhenRun = true

    @Parameter(title: "Seconds")
    var seconds: Double

    func perform() async throws -> some IntentResult {
      let payload = PendingShortcutAction(
        kind: .startTimer,
        title: nil,
        amount: seconds,
        merchant: nil,
        notes: nil,
        targetTab: .clock
      )
      try await writePendingShortcutAction(payload)
      return .result()
    }
  }

  struct OpenTabIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Tab"
    static var openAppWhenRun = true

    @Parameter(title: "Tab")
    var tab: ShortcutTab

    func perform() async throws -> some IntentResult {
      let payload = PendingShortcutAction(
        kind: .openTab,
        title: nil,
        amount: nil,
        merchant: nil,
        notes: nil,
        targetTab: tab.appTab
      )
      try await writePendingShortcutAction(payload)
      return .result()
    }
  }

  struct QuickCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Capture"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
      let payload = PendingShortcutAction(
        kind: .quickCapture,
        title: nil,
        amount: nil,
        merchant: nil,
        notes: nil,
        targetTab: .expenses
      )
      try await writePendingShortcutAction(payload)
      return .result()
    }
  }

  struct CalendarShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
      AppShortcut(
        intent: AddExpenseIntent(),
        phrases: ["Add expense in \(.applicationName)"],
        shortTitle: "Add Expense",
        systemImageName: "plus.circle"
      )
      AppShortcut(
        intent: AddTodoIntent(),
        phrases: ["Add todo in \(.applicationName)"],
        shortTitle: "Add Todo",
        systemImageName: "checkmark.circle"
      )
      AppShortcut(
        intent: StartTimerIntent(),
        phrases: ["Start timer in \(.applicationName)"],
        shortTitle: "Start Timer",
        systemImageName: "timer"
      )
      AppShortcut(
        intent: OpenTabIntent(),
        phrases: ["Open \(\.$tab) in \(.applicationName)"],
        shortTitle: "Open Tab",
        systemImageName: "square.grid.2x2"
      )
      AppShortcut(
        intent: QuickCaptureIntent(),
        phrases: ["Quick capture in \(.applicationName)"],
        shortTitle: "Quick Capture",
        systemImageName: "bolt.fill"
      )
    }
  }

  @MainActor
  @discardableResult
  private func writePendingShortcutAction(_ action: PendingShortcutAction) async throws -> Bool {
    let defaults = UserDefaults(suiteName: Constants.Storage.appGroupIdentifier) ?? .standard
    let payload = try JSONEncoder().encode(action)
    defaults.set(payload, forKey: Constants.Shortcuts.pendingActionKey)
    return true
  }
#endif

struct ContentView: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \OnboardingState.lastUpdatedAt, order: .reverse) private var onboardingStates:
    [OnboardingState]
  @StateObject private var navigationCoordinator = NavigationCoordinator()
  @StateObject private var startupManager = StartupManager()
  @State private var showSplash = true
  @State private var showOnboarding = false

  var body: some View {
    ZStack {
      let splashVisible = showSplash || startupManager.isRunning

      Group {
        Color.backgroundPrimary
          .ignoresSafeArea()

        TabView(selection: $navigationCoordinator.selectedTab) {
          tabContent(for: .calendar)
            .tabItem {
              Label(Localization.string(.tabCalendar), systemImage: "calendar")
            }
            .tag(AppTab.calendar)

          tabContent(for: .tasks)
            .tabItem {
              Label(Localization.string(.tabTodo), systemImage: "checkmark.circle")
            }
            .tag(AppTab.tasks)

          tabContent(for: .expenses)
            .tabItem {
              Label(Localization.string(.tabExpenses), systemImage: "building.columns")
            }
            .tag(AppTab.expenses)

          tabContent(for: .clock)
            .tabItem {
              Label(Localization.string(.tabClock), systemImage: "clock")
            }
            .tag(AppTab.clock)

          tabContent(for: .weather)
            .tabItem {
              Label(Localization.string(.tabWeather), systemImage: "cloud.sun")
            }
            .tag(AppTab.weather)
        }
        .animation(AppMotion.quick, value: navigationCoordinator.selectedTab)
        .tint(.appAccent)

        FloatingErrorView()
          .zIndex(5)
      }
      .disabled(splashVisible || showOnboarding)
      .opacity((splashVisible || showOnboarding) ? 0 : 1)
      .animation(AppMotion.standard, value: splashVisible || showOnboarding)

      SplashView(manager: startupManager)
        .opacity(splashVisible ? 1 : 0)
        .animation(AppMotion.standard, value: splashVisible)
        .allowsHitTesting(splashVisible)
        .accessibilityHidden(!splashVisible)
    }
    .sheet(item: $navigationCoordinator.activeSheet) { sheet in
      switch sheet {
      case .settings:
        SettingsSheet(
          isPresented: Binding(
            get: { navigationCoordinator.activeSheet != nil },
            set: { if !$0 { navigationCoordinator.activeSheet = nil } }
          )
        )
      }
    }
    .fullScreenCover(isPresented: $showOnboarding) {
      OnboardingFlowView(
        onSkip: { completeOnboarding(markCompleted: false) },
        onFinish: { city, fxUSD, fxEUR, monobankConsent, requestNotificationPermission in
          applyOnboardingSelections(
            city: city,
            fxUSD: fxUSD,
            fxEUR: fxEUR,
            monobankConsent: monobankConsent,
            requestNotificationPermission: requestNotificationPermission
          )
          completeOnboarding(markCompleted: true)
        }
      )
    }
    .onReceive(NotificationCenter.default.publisher(for: Constants.WidgetAction.markTodoDoneNotification))
    { note in
      if let id = note.object as? UUID {
        markTodoDone(id)
      }
    }
    .onChange(of: navigationCoordinator.selectedTab) { _, newTab in
      appState.selectedTab = newTab
    }
    .onChange(of: appState.selectedTab) { _, newTab in
      if navigationCoordinator.selectedTab != newTab {
        navigationCoordinator.selectedTab = newTab
      }
    }
    .onOpenURL { url in
      handleWidgetActionURL(url)
    }
    .onAppear {
      showSplash = true
      startupManager.start(using: modelContext)
      _ = NotificationPreferencesService.shared.current(context: modelContext)
      evaluateOnboardingVisibility()
      processPendingShortcutAction()
    }
    .onChange(of: startupManager.isRunning) { _, running in
      if running {
        showSplash = true
      } else {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
          withAnimation(AppMotion.standard) { showSplash = false }
        }
      }
    }
    .onChange(of: onboardingStates.count) { _, _ in
      evaluateOnboardingVisibility()
    }
  }

  @ViewBuilder
  private func tabContent(for tab: AppTab) -> some View {
    NavigationStack(path: navigationCoordinator.binding(for: tab)) {
      tabRootView(for: tab)
    }
  }

  @ViewBuilder
  private func tabRootView(for tab: AppTab) -> some View {
    switch tab {
    case .calendar:
      CalendarView()
    case .tasks:
      TodoView()
    case .expenses:
      ExpensesView()
    case .clock:
      ClockView()
    case .weather:
      WeatherView()
    }
  }

  private func handleWidgetActionURL(_ url: URL) {
    guard let action = AppDeepLinkAction(url: url) else { return }
    navigationCoordinator.handle(action)
  }

  private func markTodoDone(_ todoId: UUID) {
    do {
      let todos = try modelContext.fetch(FetchDescriptor<TodoItem>())
      guard let todo = todos.first(where: { $0.id == todoId }) else { return }
      guard !todo.isCompleted else { return }

      todo.isCompleted = true
      todo.completedAt = Date()
      try modelContext.save()
      TodoViewModel().syncTodoCountToWidget(context: modelContext)
      EventViewModel().syncEventsToWidget(context: modelContext)
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
  }

  private func evaluateOnboardingVisibility() {
    let defaults = UserDefaults(suiteName: Constants.Storage.appGroupIdentifier) ?? .standard
    if defaults.bool(forKey: Constants.Onboarding.forceRunFlagKey) {
      showOnboarding = true
      return
    }

    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    guard let state = onboardingStates.first else {
      showOnboarding = true
      return
    }

    if !state.hasCompleted {
      showOnboarding = true
      return
    }

    showOnboarding = false
    if state.lastShownVersion != currentVersion {
      state.lastShownVersion = currentVersion
      state.lastUpdatedAt = Date()
      try? modelContext.save()
    }
  }

  private func applyOnboardingSelections(
    city: String,
    fxUSD: Double?,
    fxEUR: Double?,
    monobankConsent: Bool,
    requestNotificationPermission: Bool
  ) {
    let sharedDefaults = UserDefaults(suiteName: Constants.Storage.appGroupIdentifier) ?? .standard
    let normalizedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
    if !normalizedCity.isEmpty {
      sharedDefaults.set(normalizedCity, forKey: Constants.Weather.cityKey)
    }

    if requestNotificationPermission {
      NotificationService.shared.requestAuthorization()
    }

    if let usd = fxUSD, usd > 0 {
      try? FXRateService.shared.setManualRate(currency: .usd, rateToUAH: usd, context: modelContext)
    }
    if let eur = fxEUR, eur > 0 {
      try? FXRateService.shared.setManualRate(currency: .eur, rateToUAH: eur, context: modelContext)
    }

    if monobankConsent {
      let descriptor = FetchDescriptor<MonobankConnection>(
        sortBy: [SortDescriptor(\MonobankConnection.updatedAt, order: .reverse)]
      )
      let connection = (try? modelContext.fetch(descriptor).first) ?? {
        let newConnection = MonobankConnection()
        modelContext.insert(newConnection)
        return newConnection
      }()
      connection.hasConsent = true
      connection.updatedAt = Date()
      try? modelContext.save()
    }
  }

  private func completeOnboarding(markCompleted: Bool) {
    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    let state = onboardingStates.first ?? {
      let newState = OnboardingState()
      modelContext.insert(newState)
      return newState
    }()

    state.hasCompleted = markCompleted
    state.lastShownVersion = currentVersion
    state.completedAt = markCompleted ? Date() : nil
    state.lastUpdatedAt = Date()

    let defaults = UserDefaults(suiteName: Constants.Storage.appGroupIdentifier) ?? .standard
    defaults.set(false, forKey: Constants.Onboarding.forceRunFlagKey)

    try? modelContext.save()
    showOnboarding = false
  }

  private func processPendingShortcutAction() {
    let defaults = UserDefaults(suiteName: Constants.Storage.appGroupIdentifier) ?? .standard
    guard
      let rawData = defaults.data(forKey: Constants.Shortcuts.pendingActionKey),
      let action = try? JSONDecoder().decode(PendingShortcutAction.self, from: rawData)
    else { return }

    defaults.removeObject(forKey: Constants.Shortcuts.pendingActionKey)

    switch action.kind {
    case .addExpense:
      do {
        try ExpenseViewModel().addExpense(
          title: action.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Quick Expense",
          amount: max(action.amount ?? 0, 0.01),
          date: Date(),
          category: .other,
          paymentMethod: .card,
          currency: .uah,
          merchant: action.merchant,
          notes: action.notes,
          isIncome: false,
          context: modelContext
        )
      } catch {
        ErrorPresenter.presentOnMain(error)
      }
      appState.selectedTab = .expenses
    case .addTodo:
      TodoViewModel().createTodo(
        title: action.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Quick Todo",
        notes: action.notes,
        priority: .medium,
        dueDate: nil,
        reminderInterval: nil,
        reminderRepeatInterval: nil,
        reminderRepeatCount: nil,
        category: nil,
        parentTodo: nil,
        recurrenceType: nil,
        recurrenceInterval: 1,
        recurrenceDaysOfWeek: nil,
        recurrenceEndDate: nil,
        subtasks: [],
        context: modelContext
      )
      appState.selectedTab = .tasks
    case .startTimer:
      let defaults = UserDefaults.shared
      let duration = max(action.amount ?? 300, 10)
      defaults.set(duration, forKey: "countdown.remainingTime")
      defaults.set(duration, forKey: "countdown.totalDuration")
      defaults.set(true, forKey: "countdown.isRunning")
      defaults.set(false, forKey: "countdown.isPaused")
      defaults.set(false, forKey: "countdown.isStopwatch")
      defaults.set(Date().addingTimeInterval(duration), forKey: "countdown.endTime")
      defaults.set(true, forKey: "hasActiveTimer")
      appState.selectedTab = .clock
    case .openTab:
      appState.selectedTab = action.targetTab ?? .calendar
    case .quickCapture:
      appState.selectedTab = .expenses
    }
  }
}
