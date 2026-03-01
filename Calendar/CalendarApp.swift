import SwiftData
import SwiftUI

@main
struct CalendarApp: App {
  #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  #endif
  @StateObject private var appState = AppState()
  #if DEBUG
    @StateObject private var debugSettings = DebugSettings()
  #endif

  var body: some Scene {
    WindowGroup {
      #if DEBUG
        ContentView()
          .environmentObject(appState)
          .environmentObject(debugSettings)
          .preferredColorScheme(debugSettings.themeOverride.colorScheme)
          .modelContainer(for: [
            Event.self, TodoItem.self, TodoCategory.self, Expense.self,
            RecurringExpenseTemplate.self, CSVImportSession.self, Alarm.self, TimerPreset.self,
            TimerSession.self, BudgetLimit.self, CashflowForecastCache.self,
          ])
      #else
        ContentView()
          .environmentObject(appState)
          .modelContainer(for: [
            Event.self, TodoItem.self, TodoCategory.self, Expense.self,
            RecurringExpenseTemplate.self, CSVImportSession.self, Alarm.self, TimerPreset.self,
            TimerSession.self, BudgetLimit.self, CashflowForecastCache.self,
          ])
      #endif
    }
  }
}

struct ContentView: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.modelContext) private var modelContext
  @State private var showingSettings = false
  @StateObject private var startupManager = StartupManager()
  @State private var showSplash = true

  var body: some View {
    ZStack {
      let splashVisible = showSplash || startupManager.isRunning

      // Main content container — disabled while startup runs or while showing initial splash
      Group {
        // Atmospheric Background
        MeshGradientView()
          .ignoresSafeArea()
          .animation(nil, value: appState.selectedTab)

        // Main Content Area
        Group {
          if let selectedTab = appState.selectedTab {
            switch selectedTab {
            case .calendar:
              NavigationStack { CalendarView() }
            case .tasks:
              NavigationStack { TodoView() }
            case .expenses:
              NavigationStack { ExpensesView() }
            case .clock:
              NavigationStack { ClockView() }
            case .weather:
              NavigationStack { WeatherView() }
            }
          } else {
            Text(Localization.string(.selectTabPrompt))
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(1)
        .animation(.easeOut(duration: 0.15), value: appState.selectedTab)

        // Floating Tab Bar
        VStack {
          Spacer()
          FloatingTabBar(selectedTab: $appState.selectedTab)
        }
        .ignoresSafeArea(.keyboard)

        // Floating error banner
        FloatingErrorView()
          .zIndex(10)
      }
      .disabled(splashVisible)
      .opacity(splashVisible ? 0.98 : 1)
      .animation(.easeOut(duration: 0.25), value: splashVisible)

      // Keep SplashView mounted and controlled by `splashVisible`
      SplashView(manager: startupManager)
        .opacity(splashVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: splashVisible)
        .allowsHitTesting(splashVisible)
        .accessibilityHidden(!splashVisible)
    }
    .sheet(isPresented: $showingSettings) {
      SettingsSheet(isPresented: $showingSettings)
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
          withAnimation { showSplash = false }
        }
      }
    }
  }
}
