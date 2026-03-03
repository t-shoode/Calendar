import Combine
import Foundation
import SwiftData
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Codable, Sendable {
  case calendar
  case tasks
  case expenses
  case clock
  case weather

  var id: String { rawValue }
}

class AppState: ObservableObject {
  typealias Tab = AppTab

  @Published var selectedTab: AppTab = .calendar
  @Published var selectedDate: Date = Date()

  init() {}
}

@Model
final class NotificationPreferences {
  var id: UUID
  var todoEnabled: Bool
  var eventEnabled: Bool
  var budgetEnabled: Bool
  var subscriptionEnabled: Bool
  var billEnabled: Bool
  var cashflowEnabled: Bool
  var timerEnabled: Bool
  var alarmEnabled: Bool
  var quietHoursEnabled: Bool
  var quietStartHour: Int
  var quietEndHour: Int
  var digestEnabled: Bool
  var digestHour: Int
  var throttleMinutes: Int
  var updatedAt: Date

  init(
    todoEnabled: Bool = true,
    eventEnabled: Bool = true,
    budgetEnabled: Bool = true,
    subscriptionEnabled: Bool = true,
    billEnabled: Bool = true,
    cashflowEnabled: Bool = true,
    timerEnabled: Bool = true,
    alarmEnabled: Bool = true,
    quietHoursEnabled: Bool = false,
    quietStartHour: Int = 22,
    quietEndHour: Int = 8,
    digestEnabled: Bool = false,
    digestHour: Int = 9,
    throttleMinutes: Int = 5
  ) {
    self.id = UUID()
    self.todoEnabled = todoEnabled
    self.eventEnabled = eventEnabled
    self.budgetEnabled = budgetEnabled
    self.subscriptionEnabled = subscriptionEnabled
    self.billEnabled = billEnabled
    self.cashflowEnabled = cashflowEnabled
    self.timerEnabled = timerEnabled
    self.alarmEnabled = alarmEnabled
    self.quietHoursEnabled = quietHoursEnabled
    self.quietStartHour = quietStartHour
    self.quietEndHour = quietEndHour
    self.digestEnabled = digestEnabled
    self.digestHour = digestHour
    self.throttleMinutes = throttleMinutes
    self.updatedAt = Date()
  }
}

@Model
final class OnboardingState {
  var id: UUID
  var hasCompleted: Bool
  var lastShownVersion: String
  var completedAt: Date?
  var lastUpdatedAt: Date

  init(
    hasCompleted: Bool = false,
    lastShownVersion: String = "",
    completedAt: Date? = nil
  ) {
    self.id = UUID()
    self.hasCompleted = hasCompleted
    self.lastShownVersion = lastShownVersion
    self.completedAt = completedAt
    self.lastUpdatedAt = Date()
  }
}

enum AppDeepLinkAction: Equatable {
  case quickAddExpense
  case openPinnedBankCard
  case markTodoDone(id: UUID)
  case openSettings

  init?(url: URL) {
    guard
      url.scheme == Constants.Widget.quickActionScheme,
      url.host == Constants.Widget.quickActionHost
    else {
      return nil
    }

    let action = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    switch action {
    case CombinedWidgetQuickAction.quickAddExpense.rawValue:
      self = .quickAddExpense
    case CombinedWidgetQuickAction.openPinnedBankCard.rawValue:
      self = .openPinnedBankCard
    case CombinedWidgetQuickAction.markTodoDone.rawValue:
      guard
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
        let idRaw = components.queryItems?.first(where: { $0.name == "id" })?.value,
        let id = UUID(uuidString: idRaw)
      else {
        return nil
      }
      self = .markTodoDone(id: id)
    case "settings":
      self = .openSettings
    default:
      return nil
    }
  }
}

@MainActor
final class NavigationCoordinator: ObservableObject {
  enum Sheet: Identifiable {
    case settings

    var id: String {
      switch self {
      case .settings:
        return "settings"
      }
    }
  }

  @Published var selectedTab: AppTab = .calendar
  @Published var calendarPath = NavigationPath()
  @Published var tasksPath = NavigationPath()
  @Published var expensesPath = NavigationPath()
  @Published var clockPath = NavigationPath()
  @Published var weatherPath = NavigationPath()
  @Published var activeSheet: Sheet?

  func binding(for tab: AppTab) -> Binding<NavigationPath> {
    switch tab {
    case .calendar:
      return Binding(
        get: { self.calendarPath },
        set: { self.calendarPath = $0 }
      )
    case .tasks:
      return Binding(
        get: { self.tasksPath },
        set: { self.tasksPath = $0 }
      )
    case .expenses:
      return Binding(
        get: { self.expensesPath },
        set: { self.expensesPath = $0 }
      )
    case .clock:
      return Binding(
        get: { self.clockPath },
        set: { self.clockPath = $0 }
      )
    case .weather:
      return Binding(
        get: { self.weatherPath },
        set: { self.weatherPath = $0 }
      )
    }
  }

  func handle(_ action: AppDeepLinkAction, post: (Notification.Name, Any?) -> Void = { name, obj in
    NotificationCenter.default.post(name: name, object: obj)
  }) {
    switch action {
    case .quickAddExpense:
      selectedTab = .expenses
      post(Constants.WidgetAction.quickAddExpenseNotification, nil)
    case .openPinnedBankCard:
      selectedTab = .expenses
      post(Constants.WidgetAction.openPinnedBankCardNotification, nil)
    case .markTodoDone(let id):
      selectedTab = .tasks
      post(Constants.WidgetAction.markTodoDoneNotification, id)
    case .openSettings:
      activeSheet = .settings
    }
  }
}
