import SwiftUI

struct AdaptiveTabBar: View {
  @EnvironmentObject var appState: AppState
  #if DEBUG
    @EnvironmentObject var debugSettings: DebugSettings
  #endif
  @State private var showingSettings = false

  var body: some View {
    TabView(selection: $appState.selectedTab) {
      NavigationStack {
        CalendarView()
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
                  .foregroundColor(.textSecondary)
              }
              .accessibilityLabel(Localization.string(.settings))
            }
          }
      }
      .tabItem {
        Image(systemName: "calendar")
        Text(Localization.string(.tabCalendar))
      }
      .tag(AppState.Tab.calendar)

      NavigationStack {
        TodoView()
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
                  .foregroundColor(.textSecondary)
              }
            }
          }
      }
      .tabItem {
        Image(systemName: "list.bullet")
        Text(Localization.string(.tabTodo))
      }
      .tag(AppState.Tab.tasks)

      NavigationStack {
        ExpensesView()
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
                  .foregroundColor(.textSecondary)
              }
            }
          }
      }
      .tabItem {
        Image(systemName: "building.columns")
        Text(Localization.string(.tabExpenses))
      }
      .tag(AppState.Tab.expenses)

      NavigationStack {
        ClockView()
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
                  .foregroundColor(.textSecondary)
              }
            }
          }
      }
      .tabItem {
        Image(systemName: "clock")
        Text(Localization.string(.tabClock))
      }
      .tag(AppState.Tab.clock)

      NavigationStack {
        WeatherView()
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
                  .foregroundColor(.textSecondary)
              }
            }
          }
      }
      .tabItem {
        Image(systemName: "cloud.sun")
        Text(Localization.string(.tabWeather))
      }
      .tag(AppState.Tab.weather)
    }
    .sheet(isPresented: $showingSettings) {
      SettingsSheet(isPresented: $showingSettings)
        .environmentObject(appState)
        #if DEBUG
          .environmentObject(debugSettings)
        #endif
    }
  }
}
