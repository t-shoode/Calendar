import Combine
import Foundation
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
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
