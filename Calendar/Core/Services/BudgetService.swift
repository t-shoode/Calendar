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

enum BudgetProfilePreset: String, CaseIterable, Identifiable {
  case essentials
  case balanced
  case student

  var id: String { rawValue }

  var title: String {
    switch self {
    case .essentials:
      return Localization.string(.budgetPresetEssentials)
    case .balanced:
      return Localization.string(.budgetPresetBalanced)
    case .student:
      return Localization.string(.budgetPresetStudent)
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

  func rolloverCarryAmount(limitAmountUAH: Double, previousSpentUAH: Double) -> Double {
    max(limitAmountUAH - previousSpentUAH, 0)
  }

  func effectiveBudgetUAH(for limit: BudgetLimit) -> Double {
    limit.amountUAH + (limit.rolloverEnabled ? max(limit.rolloverAmountUAH, 0) : 0)
  }

  func remainingBudgetUAH(
    for limit: BudgetLimit,
    expenses: [Expense],
    referenceDate: Date = Date()
  ) -> Double {
    let spent = spentUAH(
      for: limit.category,
      expenses: expenses,
      in: limit.periodEnum,
      referenceDate: referenceDate
    )
    return effectiveBudgetUAH(for: limit) - spent
  }

  func remainingPerDayUAH(
    for limit: BudgetLimit,
    expenses: [Expense],
    referenceDate: Date = Date()
  ) -> Double {
    let remaining = remainingBudgetUAH(for: limit, expenses: expenses, referenceDate: referenceDate)
    let bounds = periodBounds(limit.periodEnum, referenceDate: referenceDate)
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: referenceDate)
    let periodEnd = calendar.startOfDay(for: bounds.end)

    if today > periodEnd {
      return remaining
    }

    let daysLeft = (calendar.dateComponents([.day], from: today, to: periodEnd).day ?? 0) + 1
    return remaining / Double(max(daysLeft, 1))
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
      let effectiveLimit = effectiveBudgetUAH(for: limit)
      let thresholds = crossedThresholds(spentUAH: spent, limitAmountUAH: effectiveLimit)
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

  func refreshRollover(
    limits: [BudgetLimit],
    expenses: [Expense],
    context: ModelContext,
    referenceDate: Date = Date()
  ) throws {
    var didChange = false
    let currentPeriod = periodKey(.monthly, referenceDate: referenceDate)
    let calendar = Calendar.current

    for limit in limits {
      let stateKey = "budget.rollover.\(limit.id.uuidString)"
      let lastAppliedPeriod = defaults.string(forKey: stateKey)

      if !limit.rolloverEnabled {
        if limit.rolloverAmountUAH != 0 {
          limit.rolloverAmountUAH = 0
          limit.updatedAt = Date()
          didChange = true
        }
        defaults.set(currentPeriod, forKey: stateKey)
        continue
      }

      if lastAppliedPeriod == currentPeriod {
        continue
      }

      let previousReference =
        calendar.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
      let previousSpent = spentUAH(
        for: limit.category,
        expenses: expenses,
        in: limit.periodEnum,
        referenceDate: previousReference
      )
      let carryAmount = rolloverCarryAmount(
        limitAmountUAH: limit.amountUAH,
        previousSpentUAH: previousSpent
      )

      if abs(limit.rolloverAmountUAH - carryAmount) > 0.001 {
        limit.rolloverAmountUAH = carryAmount
        limit.updatedAt = Date()
        didChange = true
      }

      defaults.set(currentPeriod, forKey: stateKey)
    }

    if didChange {
      try context.save()
    }
  }

  func presetAllocations(
    profile: BudgetProfilePreset,
    monthlyBudgetUAH: Double
  ) -> [(category: ExpenseCategory, amountUAH: Double)] {
    let base = max(monthlyBudgetUAH, 1)

    func value(_ percent: Double) -> Double {
      (base * percent).rounded()
    }

    switch profile {
    case .essentials:
      return [
        (.housing, value(0.38)),
        (.groceries, value(0.23)),
        (.transportation, value(0.16)),
        (.healthcare, value(0.10)),
        (.subscriptions, value(0.07)),
        (.other, value(0.06)),
      ]
    case .balanced:
      return [
        (.housing, value(0.30)),
        (.groceries, value(0.20)),
        (.transportation, value(0.14)),
        (.subscriptions, value(0.10)),
        (.entertainment, value(0.10)),
        (.dining, value(0.10)),
        (.other, value(0.06)),
      ]
    case .student:
      return [
        (.housing, value(0.32)),
        (.groceries, value(0.22)),
        (.transportation, value(0.12)),
        (.dining, value(0.11)),
        (.entertainment, value(0.10)),
        (.subscriptions, value(0.07)),
        (.other, value(0.06)),
      ]
    }
  }

  func applyPreset(
    profile: BudgetProfilePreset,
    monthlyBudgetUAH: Double,
    limits: [BudgetLimit],
    context: ModelContext
  ) throws {
    let allocations = presetAllocations(profile: profile, monthlyBudgetUAH: monthlyBudgetUAH)
    for allocation in allocations {
      if let existing = limits.first(where: { $0.category == allocation.category }) {
        existing.amountUAH = allocation.amountUAH
        existing.updatedAt = Date()
      } else {
        let limit = BudgetLimit(
          category: allocation.category,
          amountUAH: allocation.amountUAH,
          period: .monthly
        )
        context.insert(limit)
      }
    }
    try context.save()
  }

  private func notifyOnce(key: String, title: String, body: String) {
    guard NotificationPreferencesService.shared.isAllowed(.budget) else { return }

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

  private func periodBounds(
    _ period: BudgetPeriod,
    referenceDate: Date,
    monthOffset: Int = 0
  ) -> (start: Date, end: Date) {
    let calendar = Calendar.current
    let anchoredDate = calendar.date(byAdding: .month, value: monthOffset, to: referenceDate) ?? referenceDate
    switch period {
    case .monthly:
      let interval = calendar.dateInterval(of: .month, for: anchoredDate)
        ?? DateInterval(start: anchoredDate, end: anchoredDate)
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
