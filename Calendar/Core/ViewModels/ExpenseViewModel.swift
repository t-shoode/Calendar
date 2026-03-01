import SwiftData
import SwiftUI
import WidgetKit

class ExpenseViewModel {

  func addExpense(
    title: String,
    amount: Double,
    date: Date,
    category: ExpenseCategory,
    paymentMethod: PaymentMethod,
    currency: Currency,
    merchant: String?,
    notes: String?,
    isIncome: Bool,
    context: ModelContext
  ) throws {
    let expense = Expense(
      title: title,
      amount: amount,
      date: date,
      categories: [category],
      paymentMethod: paymentMethod,
      currency: currency,
      merchant: merchant,
      notes: notes,
      isIncome: isIncome
    )
    context.insert(expense)
    try context.save()
    syncExpensesToWidget(context: context)
  }

  func updateExpense(
    _ expense: Expense,
    title: String,
    amount: Double,
    date: Date,
    category: ExpenseCategory,
    paymentMethod: PaymentMethod,
    currency: Currency,
    merchant: String?,
    notes: String?,
    isIncome: Bool,
    context: ModelContext
  ) throws {
    expense.title = title
    expense.amount = amount
    expense.date = date
    expense.categories = [category.rawValue]
    expense.paymentMethod = paymentMethod.rawValue
    expense.currency = currency.rawValue
    expense.merchant = merchant
    expense.notes = notes
    expense.isIncome = isIncome

    // Mark as manually edited to avoid being overwritten by template propagation
    expense.isManuallyEdited = true

    try context.save()
    syncExpensesToWidget(context: context)
  }

  func deleteExpense(_ expense: Expense, context: ModelContext) throws {
    context.delete(expense)
    try context.save()
    syncExpensesToWidget(context: context)
  }

  // MARK: - Aggregation

  func amountInUAH(_ expense: Expense) -> Double {
    let rate = FXRateStore.shared.rateToUAH(for: expense.currencyEnum)
    return expense.amount * rate
  }

  func amountInUAH(_ template: RecurringExpenseTemplate) -> Double {
    let rate = FXRateStore.shared.rateToUAH(for: template.currencyEnum)
    return template.amount * rate
  }

  func totalForPeriod(expenses: [Expense], start: Date, end: Date, isIncome: Bool? = nil) -> Double
  {
    expenses
      .filter {
        $0.date >= start && $0.date <= end && (isIncome == nil || $0.isIncome == isIncome!)
      }
      .reduce(0) { $0 + $1.amount }
  }

  /// Calculate total amount in UAH for a period (converts all currencies to UAH)
  func totalInUAHForPeriod(expenses: [Expense], start: Date, end: Date, isIncome: Bool? = nil)
    -> Double
  {
    let filtered = expenses.filter {
      $0.date >= start && $0.date <= end && (isIncome == nil || $0.isIncome == isIncome!)
    }
    return filtered.reduce(0) { total, expense in
      total + expense.currencyEnum.convertToUAH(expense.amount)
    }
  }

  /// Get multi-currency totals for a period
  /// Returns: (uah: Double, usd: Double, eur: Double)
  /// - uah: Total in UAH (converted from all currencies)
  /// - usd: Total in USD (converted from UAH total)
  /// - eur: Total in EUR (converted from UAH total)
  func multiCurrencyTotalsForPeriod(
    expenses: [Expense], start: Date, end: Date, isIncome: Bool? = nil
  ) -> (uah: Double, usd: Double, eur: Double) {
    let totalUAH = totalInUAHForPeriod(
      expenses: expenses, start: start, end: end, isIncome: isIncome)
    let usd = Currency.usd.convertFromUAH(totalUAH)
    let eur = Currency.eur.convertFromUAH(totalUAH)
    return (uah: totalUAH, usd: usd, eur: eur)
  }

  func totalByCategory(expenses: [Expense]) -> [(category: ExpenseCategory, total: Double)] {
    var map: [ExpenseCategory: Double] = [:]
    for expense in expenses {
      map[expense.primaryCategory, default: 0] += expense.amount
    }
    return map.sorted { $0.value > $1.value }.map { (category: $0.key, total: $0.value) }
  }

  func dailyTotals(expenses: [Expense]) -> [Date: Double] {
    var map: [Date: Double] = [:]
    let calendar = Calendar.current
    for expense in expenses {
      let day = calendar.startOfDay(for: expense.date)
      map[day, default: 0] += expense.amount
    }
    return map
  }

  func groupedByDate(expenses: [Expense]) -> [(date: Date, expenses: [Expense])] {
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: expenses) { calendar.startOfDay(for: $0.date) }
    return grouped.sorted { $0.key > $1.key }.map { (date: $0.key, expenses: $0.value) }
  }

  // MARK: - Widget Sync

  func syncExpensesToWidget(context: ModelContext, userDefaults: UserDefaults? = nil) {
    let calendar = Calendar.current
    let now = Date()
    let weekLater = calendar.date(byAdding: .day, value: 7, to: now)!

    let descriptor = FetchDescriptor<Expense>(
      predicate: #Predicate { expense in
        expense.date >= now && expense.date <= weekLater
      },
      sortBy: [SortDescriptor(\.date)]
    )

    do {
      let expenses = try context.fetch(descriptor)

      // Filter for Monthly Recurring Expenses only
      // We need to fetch templates to check linkage
      let templateDescriptor = FetchDescriptor<RecurringExpenseTemplate>()
      let templates = try context.fetch(templateDescriptor)
      let monthlyTemplateIds = Set(templates.filter { $0.frequencyEnum == .monthly }.map { $0.id })

      let widgetExpenses = expenses.filter { expense in
        guard let templateId = expense.templateId else { return false }
        return monthlyTemplateIds.contains(templateId)
      }
      .prefix(2).map { expense -> WidgetExpenseItem in
        WidgetExpenseItem(
          id: expense.id.uuidString,
          title: expense.title,
          amount: expense.amount,
          date: expense.date,
          currency: expense.currency,
          category: expense.primaryCategory.rawValue
        )
      }

      let defaults = userDefaults ?? UserDefaults(suiteName: Constants.Storage.appGroupIdentifier)
      if let encoded = try? JSONEncoder().encode(Array(widgetExpenses)) {
        defaults?.set(encoded, forKey: "widgetUpcomingExpenses")
      }
      WidgetCenter.shared.reloadTimelines(ofKind: "CalendarWidget")
      WidgetCenter.shared.reloadTimelines(ofKind: "CombinedWidget")
    } catch {
      // Silently fail for widget sync
    }
  }
}

// MARK: - Widget Data Models

struct WidgetExpenseItem: Codable {
  let id: String
  let title: String
  let amount: Double
  let date: Date
  let currency: String
  let category: String
}
