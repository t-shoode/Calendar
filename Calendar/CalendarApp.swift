import SwiftData
import SwiftUI
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
            DuplicateSuggestion.self, FXRate.self,
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
            DuplicateSuggestion.self, FXRate.self,
            MonobankConnection.self, MonobankAccount.self, MonobankStatementItem.self,
            MonobankSyncState.self, MonobankConflict.self,
          ])
      #endif
    }
  }
}

struct ContentView: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.modelContext) private var modelContext
  @StateObject private var navigationCoordinator = NavigationCoordinator()
  @StateObject private var startupManager = StartupManager()
  @State private var showSplash = true

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
      .disabled(splashVisible)
      .opacity(splashVisible ? 0 : 1)
      .animation(AppMotion.standard, value: splashVisible)

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
}
