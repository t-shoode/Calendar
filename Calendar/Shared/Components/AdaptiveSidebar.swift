import Combine
import SwiftUI

struct AdaptiveSidebar: View {
  @EnvironmentObject var appState: AppState
  private var selectedTabBinding: Binding<AppTab?> {
    Binding<AppTab?>(
      get: { appState.selectedTab },
      set: { if let value = $0 { appState.selectedTab = value } }
    )
  }

  var body: some View {
    NavigationSplitView {
      List(selection: selectedTabBinding) {
        NavigationLink(value: AppState.Tab.calendar) {
          Label(Localization.string(.tabCalendar), systemImage: "calendar")
        }

        NavigationLink(value: AppState.Tab.tasks) {
          Label(Localization.string(.tabTodo), systemImage: "checkmark.circle")
        }

        NavigationLink(value: AppState.Tab.expenses) {
          Label(Localization.string(.tabExpenses), systemImage: "banknote")
        }

        NavigationLink(value: AppState.Tab.clock) {
          Label(Localization.string(.tabClock), systemImage: "clock")
        }
      }
      .navigationTitle(Localization.string(.tabCalendar))
    } detail: {
      switch appState.selectedTab {
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
  }
}
