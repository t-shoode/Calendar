import Foundation
import SwiftData
import UserNotifications

enum BudgetThreshold: String, CaseIterable {
  case eighty
  case hundred

  var fraction: Double {
    switch self {
    case .eighty:
      return 0.8
    case .hundred:
      return 1.0
    }
  }
}

final class BudgetService {
  static let shared = BudgetService()

  private let defaults: UserDefaults
  private let expenseViewModel = ExpenseViewModel()

  private init() {
    defaults = UserDefaults(suiteName: Constants.Storage.appGroupIdentifier) ?? .standard
  }

  func spentUAH(
    for category: ExpenseCategory,
    expenses: [Expense],
    in period: BudgetPeriod,
    referenceDate: Date = Date()
  ) -> Double {
    let bounds = periodBounds(period, referenceDate: referenceDate)
    return expenses
      .filter { $0.primaryCategory == category && $0.date >= bounds.start && $0.date <= bounds.end }
      .reduce(0) { $0 + expenseViewModel.amountInUAH($1) }
  }

  func crossedThresholds(spentUAH: Double, limitAmountUAH: Double) -> [BudgetThreshold] {
    guard limitAmountUAH > 0 else { return [] }
    return BudgetThreshold.allCases.filter { spentUAH >= (limitAmountUAH * $0.fraction) }
  }

  func evaluateBudgets(
    limits: [BudgetLimit],
    expenses: [Expense],
    referenceDate: Date = Date()
  ) {
    for limit in limits {
      let period = limit.periodEnum
      let spent = spentUAH(for: limit.category, expenses: expenses, in: period, referenceDate: referenceDate)
      let thresholds = crossedThresholds(spentUAH: spent, limitAmountUAH: limit.amountUAH)
      let periodToken = periodKey(period, referenceDate: referenceDate)

      if thresholds.contains(.eighty) {
        notifyOnce(
          key: "budget-\(limit.categoryRawValue)-\(period.rawValue)-\(periodToken)-80",
          title: Localization.string(.budgetWarningTitle),
          body: Localization.string(.budgetWarningBody("\(Currency.uah.symbol)\(String(format: "%.0f", spent))"))
        )
      }
      if thresholds.contains(.hundred) {
        notifyOnce(
          key: "budget-\(limit.categoryRawValue)-\(period.rawValue)-\(periodToken)-100",
          title: Localization.string(.budgetExceededTitle),
          body: Localization.string(.budgetExceededBody("\(Currency.uah.symbol)\(String(format: "%.0f", spent))"))
        )
      }
    }
  }

  private func notifyOnce(key: String, title: String, body: String) {
    let already = defaults.bool(forKey: key)
    guard !already else { return }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
    let request = UNNotificationRequest(identifier: key, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)

    defaults.set(true, forKey: key)
  }

  private func periodBounds(_ period: BudgetPeriod, referenceDate: Date) -> (start: Date, end: Date) {
    let calendar = Calendar.current
    switch period {
    case .monthly:
      let interval = calendar.dateInterval(of: .month, for: referenceDate)
        ?? DateInterval(start: referenceDate, end: referenceDate)
      let end = calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
      return (interval.start, end)
    }
  }

  private func periodKey(_ period: BudgetPeriod, referenceDate: Date) -> String {
    let bounds = periodBounds(period, referenceDate: referenceDate)
    let components = Calendar.current.dateComponents([.year, .month], from: bounds.start)
    let year = components.year ?? 0
    let month = components.month ?? 0
    return String(format: "%04d-%02d", year, month)
  }
}
