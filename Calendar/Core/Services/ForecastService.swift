import Foundation
import SwiftData

enum ForecastScenario: String, CaseIterable, Identifiable {
  case baseline
  case conservative
  case optimistic

  var id: String { rawValue }

  var title: String {
    switch self {
    case .baseline:
      return Localization.string(.forecastScenarioBaseline)
    case .conservative:
      return Localization.string(.forecastScenarioConservative)
    case .optimistic:
      return Localization.string(.forecastScenarioOptimistic)
    }
  }
}

struct ForecastConfidenceBand: Identifiable {
  let id: String
  let date: Date
  let lowNetUAH: Double
  let highNetUAH: Double
}

final class ForecastService {
  static let shared = ForecastService()

  private init() {}

  func forecastDays(
    startDate: Date,
    days: Int,
    expenses: [Expense],
    templates: [RecurringExpenseTemplate],
    scenario: ForecastScenario = .baseline
  ) -> [ForecastDay] {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: startDate)
    let end = calendar.date(byAdding: .day, value: max(days - 1, 0), to: start) ?? start

    var daily: [Date: (expense: Double, income: Double)] = [:]

    for expense in expenses {
      guard expense.date >= start && expense.date <= end else { continue }
      let day = calendar.startOfDay(for: expense.date)
      var entry = daily[day] ?? (0, 0)
      let amount = ExpenseViewModel().amountInUAH(expense)
      if expense.isIncome {
        entry.income += amount
      } else {
        entry.expense += amount
      }
      daily[day] = entry
    }

    for template in templates {
      guard template.isActive && !template.isCurrentlyPaused else { continue }
      var due = template.nextDueDate(from: start.addingTimeInterval(-1))
      while let date = due, date <= end {
        let day = calendar.startOfDay(for: date)
        var entry = daily[day] ?? (0, 0)
        let amount = ExpenseViewModel().amountInUAH(template)
        if template.isIncome {
          entry.income += amount
        } else {
          entry.expense += amount
        }
        daily[day] = entry
        due = template.nextDueDate(from: date)
      }
    }

    let multipliers = scenarioMultipliers(for: scenario)
    let sortedDays = daily.keys.sorted()
    return sortedDays.map { day in
      let entry = daily[day] ?? (0, 0)
      return ForecastDay(
        date: day,
        expensesUAH: entry.expense * multipliers.expense,
        incomeUAH: entry.income * multipliers.income
      )
    }
  }

  func confidenceBand(
    startDate: Date,
    days: Int,
    expenses: [Expense],
    templates: [RecurringExpenseTemplate],
    bills: [BillItem]
  ) -> [ForecastConfidenceBand] {
    let forecast = forecastDays(
      startDate: startDate,
      days: days,
      expenses: expenses,
      templates: templates,
      scenario: .baseline
    )
    guard !forecast.isEmpty else { return [] }

    let historicalStdDev = historicalNetStdDeviation(
      referenceDate: startDate,
      expenses: expenses,
      templates: templates,
      bills: bills
    )
    let confidenceFactor = 1.28  // ~80% confidence band

    return forecast.map { day in
      let radius = historicalStdDev * confidenceFactor
      let low = day.netUAH - radius
      let high = day.netUAH + radius
      return ForecastConfidenceBand(
        id: day.id,
        date: day.date,
        lowNetUAH: low,
        highNetUAH: high
      )
    }
  }

  func applyWhatIf(
    to days: [ForecastDay],
    deltaExpensesUAH: Double,
    deltaIncomeUAH: Double
  ) -> [ForecastDay] {
    guard !days.isEmpty else { return [] }
    let count = Double(days.count)
    let expenseDeltaPerDay = deltaExpensesUAH / count
    let incomeDeltaPerDay = deltaIncomeUAH / count

    return days.map { day in
      ForecastDay(
        date: day.date,
        expensesUAH: max(day.expensesUAH + expenseDeltaPerDay, 0),
        incomeUAH: max(day.incomeUAH + incomeDeltaPerDay, 0)
      )
    }
  }

  func cacheForecast(
    startDate: Date,
    days: Int,
    expenses: [Expense],
    templates: [RecurringExpenseTemplate],
    context: ModelContext
  ) throws -> CashflowForecastCache {
    let start = Calendar.current.startOfDay(for: startDate)
    let forecast = forecastDays(startDate: start, days: days, expenses: expenses, templates: templates)
    let payload = try JSONEncoder().encode(forecast)
    let endDate = Calendar.current.date(byAdding: .day, value: max(days - 1, 0), to: start) ?? start

    let descriptor = FetchDescriptor<CashflowForecastCache>(
      predicate: #Predicate { cache in
        cache.startDate == start && cache.endDate == endDate
      }
    )
    if let existing = try context.fetch(descriptor).first {
      existing.payload = payload
      existing.updatedAt = Date()
      try context.save()
      return existing
    }

    let cache = CashflowForecastCache(startDate: start, endDate: endDate, payload: payload)
    context.insert(cache)
    try context.save()
    return cache
  }

  private func scenarioMultipliers(for scenario: ForecastScenario) -> (expense: Double, income: Double) {
    switch scenario {
    case .baseline:
      return (expense: 1.0, income: 1.0)
    case .conservative:
      return (expense: 1.12, income: 0.94)
    case .optimistic:
      return (expense: 0.92, income: 1.06)
    }
  }

  private func historicalNetStdDeviation(
    referenceDate: Date,
    expenses: [Expense],
    templates: [RecurringExpenseTemplate],
    bills: [BillItem]
  ) -> Double {
    let calendar = Calendar.current
    let end = calendar.startOfDay(for: referenceDate)
    let start = calendar.date(byAdding: .day, value: -90, to: end) ?? end

    var dailyNet: [Date: Double] = [:]

    for expense in expenses where expense.date >= start && expense.date <= end {
      let day = calendar.startOfDay(for: expense.date)
      let amountUAH = ExpenseViewModel().amountInUAH(expense)
      dailyNet[day, default: 0] += expense.isIncome ? amountUAH : -amountUAH
    }

    for template in templates where template.isActive && !template.isCurrentlyPaused {
      var due = template.nextDueDate(from: start.addingTimeInterval(-1))
      while let date = due, date <= end {
        let day = calendar.startOfDay(for: date)
        let amountUAH = ExpenseViewModel().amountInUAH(template)
        dailyNet[day, default: 0] += template.isIncome ? amountUAH : -amountUAH
        due = template.nextDueDate(from: date)
      }
    }

    for bill in bills where bill.dueDate >= start && bill.dueDate <= end {
      let day = calendar.startOfDay(for: bill.dueDate)
      let currency = Currency(rawValue: bill.currency) ?? .uah
      let amountUAH = currency.convertToUAH(bill.amount)
      dailyNet[day, default: 0] -= amountUAH
    }

    let values = dailyNet.values
    guard values.count > 1 else { return 0 }
    let mean = values.reduce(0, +) / Double(values.count)
    let variance = values.reduce(0) { partialResult, value in
      let delta = value - mean
      return partialResult + (delta * delta)
    } / Double(values.count)
    return sqrt(max(variance, 0))
  }
}
