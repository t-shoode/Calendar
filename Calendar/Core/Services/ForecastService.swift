import Foundation
import SwiftData

final class ForecastService {
  static let shared = ForecastService()

  private init() {}

  func forecastDays(
    startDate: Date,
    days: Int,
    expenses: [Expense],
    templates: [RecurringExpenseTemplate]
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

    let sortedDays = daily.keys.sorted()
    return sortedDays.map { day in
      let entry = daily[day] ?? (0, 0)
      return ForecastDay(date: day, expensesUAH: entry.expense, incomeUAH: entry.income)
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
}
