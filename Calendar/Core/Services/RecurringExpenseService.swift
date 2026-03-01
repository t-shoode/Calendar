import Foundation
import SwiftData
import UserNotifications
import os

/// Service for managing recurring expense generation and notifications
class RecurringExpenseService {

  static let shared = RecurringExpenseService()

  private init() {}

  // MARK: - Expense Generation

  /// Generate recurring expenses from templates
  /// Call this on app launch and when viewing Budget tab
  func generateRecurringExpenses(context: ModelContext) {
    let descriptor = FetchDescriptor<RecurringExpenseTemplate>()

    do {
      let templates = try context.fetch(descriptor)

      let calendar = Calendar.current
      let now = Date()
      for template in templates {
        guard template.isActive else { continue }
        guard !template.isCurrentlyPaused else { continue }
        guard template.frequency != .oneTime else { continue }

        // Generate up to 2 months ahead
        let twoMonthsFromNow = calendar.date(byAdding: .day, value: 60, to: now)
          ?? now.addingTimeInterval(60 * 24 * 60 * 60)

        // Always step from startDate by adding N periods to preserve day-of-month
        // e.g., startDate = Nov 24 → Dec 24, Jan 24, Feb 24, etc.
        var lastGeneratedExpenseDate: Date? = nil
        let maxMultiplier = maxGenerationMultiplier(
          for: template.frequency,
          startDate: template.startDate,
          endDate: twoMonthsFromNow,
          calendar: calendar
        )

        for multiplier in 0...maxMultiplier {
          guard
            let date = dateByAddingFrequency(
              template.frequency,
              multiplier: multiplier,
              to: template.startDate,
              calendar: calendar
            )
          else { break }

          // Skip the startDate itself (occurrence 0) — only generate future ones
          // But include it if it's today or in the future
          if multiplier == 0 && date < calendar.startOfDay(for: now) {
            continue
          }

          // Stop if we've gone past our generation window
          if date > twoMonthsFromNow { break }

          // Create expense if it doesn't exist
          if !expenseExists(for: template, on: date, context: context) {
            createExpense(from: template, on: date, context: context)
          }

          lastGeneratedExpenseDate = date
        }

        // Update last generated date, but do NOT move it into the future.
        // Only advance lastGeneratedDate if the last generated expense is today or in the past.
        if let lastExpenseDate = lastGeneratedExpenseDate {
          if lastExpenseDate <= now {
            template.lastGeneratedDate = lastExpenseDate
          } else {
            // If we only generated future occurrences, leave lastGeneratedDate unchanged
          }
        }
      }

      try context.save()

      // Schedule notifications for upcoming expenses
      scheduleUpcomingNotifications(context: context)

    } catch {
      Logging.log.error(
        "Error generating recurring expenses: \(String(describing: error), privacy: .public)")
    }
  }

  /// Check if an expense already exists for a template on a specific date
  private func expenseExists(
    for template: RecurringExpenseTemplate,
    on date: Date,
    context: ModelContext
  ) -> Bool {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

    let templateId = template.id
    var descriptor = FetchDescriptor<Expense>(
      predicate: #Predicate { expense in
        expense.templateId == templateId && expense.date >= startOfDay && expense.date < endOfDay
      }
    )
    descriptor.fetchLimit = 1

    do {
      let existing = try context.fetch(descriptor)
      return !existing.isEmpty
    } catch {
      Logging.log.error(
        "Error checking existing expense: \(String(describing: error), privacy: .public)")
      // Safer to assume existence on failure to avoid duplicates
      return true
    }
  }

  /// Create an expense from a template
  private func createExpense(
    from template: RecurringExpenseTemplate,
    on date: Date,
    context: ModelContext
  ) {
    let expense = Expense(
      title: template.title,
      amount: template.amount,
      date: date,
      categories: template.allCategories,
      paymentMethod: template.paymentMethodEnum,
      currency: template.currencyEnum,
      merchant: template.merchant,
      notes: template.notes,
      templateId: template.id,
      isGenerated: true,
      isIncome: template.isIncome
    )
    // Record the template's updatedAt as a lightweight snapshot marker
    expense.templateSnapshotHash = "\(template.updatedAt.timeIntervalSince1970)"

    context.insert(expense)
  }

  // MARK: - Notifications

  /// Schedule notifications for upcoming recurring expenses
  func scheduleUpcomingNotifications(context: ModelContext) {
    // Only cancel existing EXPENSE notifications (not alarm/event/todo ones)
    // Capture the ModelContainer so we can create a main-thread ModelContext for scheduling
    let modelContainer = context.container
    UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] requests in
      let expenseIds =
        requests
        .filter { $0.identifier.hasPrefix("recurring-expense-") }
        .map { $0.identifier }
      UNUserNotificationCenter.current().removePendingNotificationRequests(
        withIdentifiers: expenseIds)

      // Run scheduling on the main actor using a main-thread ModelContext
      DispatchQueue.main.async {
        // modelContainer is non-optional; create a main-thread ModelContext directly
        let mainContext = ModelContext(modelContainer)
        self?.scheduleNewExpenseNotifications(context: mainContext)
      }
    }
  }

  private func scheduleNewExpenseNotifications(context: ModelContext) {
    let descriptor = FetchDescriptor<RecurringExpenseTemplate>()

    do {
      let allTemplates = try context.fetch(descriptor)
      let templates = allTemplates.filter { $0.isActive && !$0.isCurrentlyPaused }
      let upcomingExpenses = getUpcomingExpenses(from: templates, within: 7)

      guard !upcomingExpenses.isEmpty else { return }

      // Group by date
      let groupedByDate = Dictionary(grouping: upcomingExpenses) { expense in
        Calendar.current.startOfDay(for: expense.date)
      }

      // Schedule notification for each date
      for (date, expenses) in groupedByDate.sorted(by: { $0.key < $1.key }) {
        let expenseItems = expenses.filter { !$0.template.isIncome }
        if !expenseItems.isEmpty {
          scheduleNotification(for: expenseItems, on: date, kind: .expense)
        }

        let incomeItems = expenses.filter { $0.template.isIncome }
        if !incomeItems.isEmpty {
          scheduleNotification(for: incomeItems, on: date, kind: .income)
        }
      }

    } catch {
      Logging.log.error(
        "Error scheduling notifications: \(String(describing: error), privacy: .public)")
    }
  }

  /// Get upcoming expenses within specified days
  private func getUpcomingExpenses(
    from templates: [RecurringExpenseTemplate],
    within days: Int
  ) -> [(template: RecurringExpenseTemplate, date: Date)] {
    let calendar = Calendar.current
    let now = Date()
    let cutoff = calendar.date(byAdding: .day, value: days, to: now)!

    var upcoming: [(RecurringExpenseTemplate, Date)] = []

    for template in templates {
      guard let nextDate = template.nextDueDate(from: now), nextDate <= cutoff else { continue }
      upcoming.append((template, nextDate))
    }

    return upcoming.sorted {
      (item1: (RecurringExpenseTemplate, Date), item2: (RecurringExpenseTemplate, Date)) -> Bool in
      item1.1 < item2.1
    }
  }

  private enum RecurringNotificationKind: String {
    case expense
    case income
  }

  /// Schedule a notification for expenses on a specific date
  private func scheduleNotification(
    for expenses: [(template: RecurringExpenseTemplate, date: Date)],
    on date: Date,
    kind: RecurringNotificationKind
  ) {
    let content = UNMutableNotificationContent()

    if expenses.count == 1 {
      let expense = expenses[0]
      let symbol = expense.template.currencyEnum.symbol
      switch kind {
      case .expense:
        content.title = "💰 Upcoming Payment"
        content.body =
          "\(expense.template.title) - \(symbol)\(String(format: "%.2f", expense.template.amount)) due tomorrow"
      case .income:
        content.title = "💵 Incoming Payment"
        content.body =
          "\(expense.template.title) +\(symbol)\(String(format: "%.2f", expense.template.amount)) expected tomorrow"
      }
    } else {
      let names = expenses.prefix(3).map { $0.template.title }.joined(separator: ", ")
      let more = expenses.count > 3 ? " and \(expenses.count - 3) more" : ""
      let groupedByCurrency = Dictionary(grouping: expenses) { $0.template.currencyEnum }

      switch kind {
      case .expense:
        content.title = "💰 \(expenses.count) Payments Due Tomorrow"
      case .income:
        content.title = "💵 \(expenses.count) Payments Expected Tomorrow"
      }
      if groupedByCurrency.count == 1 {
        let total = expenses.reduce(0) { $0 + $1.template.amount }
        let symbol = groupedByCurrency.first?.key.symbol ?? "₴"
        switch kind {
        case .expense:
          content.body = "Total: \(symbol)\(String(format: "%.2f", total)) - \(names)\(more)"
        case .income:
          content.body = "Total: +\(symbol)\(String(format: "%.2f", total)) - \(names)\(more)"
        }
      } else {
        let totalsText = groupedByCurrency
          .map { (currency, items) -> String in
            let total = items.reduce(0) { $0 + $1.template.amount }
            switch kind {
            case .expense:
              return "\(currency.symbol)\(String(format: "%.2f", total))"
            case .income:
              return "+\(currency.symbol)\(String(format: "%.2f", total))"
            }
          }
          .sorted()
          .joined(separator: ", ")
        content.body = "Totals: \(totalsText) - \(names)\(more)"
      }
    }

    content.sound = .default
    content.badge = 1

    // Schedule for 9 AM the day before, or ASAP if missed
    let calendar = Calendar.current
    guard let triggerDate = notificationTriggerDate(forDueDate: date) else { return }
    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)

    let trigger = UNCalendarNotificationTrigger(
      dateMatching: components,
      repeats: false
    )

    let request = UNNotificationRequest(
      identifier: "recurring-expense-\(date.timeIntervalSince1970)-\(kind.rawValue)",
      content: content,
      trigger: trigger
    )

    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        Logging.log.error(
          "Error scheduling notification: \(String(describing: error), privacy: .public)")
      }
    }
  }

  func notificationTriggerDate(forDueDate date: Date, now: Date = Date()) -> Date? {
    let calendar = Calendar.current
    guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: date) else { return nil }
    var components = calendar.dateComponents([.year, .month, .day], from: dayBefore)
    components.hour = 9
    components.minute = 0

    guard let scheduled = calendar.date(from: components) else { return nil }
    if scheduled <= now {
      return now.addingTimeInterval(5 * 60)
    }
    return scheduled
  }

  // MARK: - Update Generated Expenses (apply template edits)

  private struct _UndoSnapshot: Codable {
    let expenseId: UUID
    let title: String
    let amount: Double
    let merchant: String?
    let notes: String?
    let paymentMethod: String
    let currency: String
    let isIncome: Bool
    // Optional categories: added to support undoing category changes (backwards-compatible)
    let categories: [String]?
    let templateSnapshotHash: String?
  }

  /// Count matching future generated expenses for preview/UI
  func countFutureGeneratedExpenses(
    for template: RecurringExpenseTemplate, from date: Date = Date(), context: ModelContext
  ) -> Int {
    do {
      let startOfDay = Calendar.current.startOfDay(for: date)
      let templateId = template.id
      let descriptor = FetchDescriptor<Expense>(
        predicate: #Predicate { expense in
          expense.templateId == templateId && expense.isGenerated && expense.date >= startOfDay
        }
      )
      let matches = try context.fetch(descriptor)
      return matches.count
    } catch {
      return 0
    }
  }

  /// Update future generated expenses using values from the template.
  /// Skips any expenses that were manually edited by the user.
  func updateGeneratedExpenses(
    for template: RecurringExpenseTemplate, applyFrom date: Date = Date(), context: ModelContext
  ) -> (updatedCount: Int, skippedManualCount: Int) {
    let startOfDay = Calendar.current.startOfDay(for: date)
    var updated = 0
    var skipped = 0
    var undoSnapshots: [_UndoSnapshot] = []

    do {
      let templateId = template.id
      let descriptor = FetchDescriptor<Expense>(
        predicate: #Predicate { expense in
          expense.templateId == templateId && expense.isGenerated && expense.date >= startOfDay
        }
      )
      let candidates = try context.fetch(descriptor)

      for expense in candidates {
        if expense.isManuallyEdited {
          skipped += 1
          continue
        }

        // Save a pre-update snapshot for possible undo
        let snap = _UndoSnapshot(
          expenseId: expense.id,
          title: expense.title,
          amount: expense.amount,
          merchant: expense.merchant,
          notes: expense.notes,
          paymentMethod: expense.paymentMethod,
          currency: expense.currency,
          isIncome: expense.isIncome,
          categories: expense.categories,
          templateSnapshotHash: expense.templateSnapshotHash
        )
        undoSnapshots.append(snap)

        // Apply template fields
        expense.title = template.title
        expense.amount = template.amount
        expense.categories = template.allCategories.map { $0.rawValue }
        expense.paymentMethod = template.paymentMethod
        expense.currency = template.currency
        expense.merchant = template.merchant
        expense.notes = template.notes
        expense.isIncome = template.isIncome
        expense.templateSnapshotHash = "\(template.updatedAt.timeIntervalSince1970)"

        updated += 1
      }

      // Persist undo buffer in UserDefaults (short-lived)
      if !undoSnapshots.isEmpty {
        if let data = try? JSONEncoder().encode(undoSnapshots) {
          UserDefaults.standard.set(data, forKey: "lastTemplateUpdate.\(template.id.uuidString)")
        }
      }

      try context.save()

      // Resync widgets & notifications
      ExpenseViewModel().syncExpensesToWidget(context: context)
      scheduleUpcomingNotifications(context: context)

    } catch {
      Logging.log.error(
        "Error updating generated expenses: \(String(describing: error), privacy: .public)")
    }

    return (updated, skipped)
  }

  /// Undo the most recent template-driven update (best-effort)
  func undoLastTemplateUpdate(templateId: UUID, context: ModelContext) -> Bool {
    // Load snapshot (best-effort simple implementation)
    let key = "lastTemplateUpdate.\(templateId.uuidString)"
    guard let data = UserDefaults.standard.data(forKey: key),
      let snaps = try? JSONDecoder().decode([_UndoSnapshot].self, from: data)
    else {
      return false
    }

    var applied = false
    do {
      let descriptor = FetchDescriptor<Expense>(
        predicate: #Predicate { expense in
          expense.templateId == templateId
        }
      )
      let expenses = try context.fetch(descriptor)
      let expensesById = Dictionary(uniqueKeysWithValues: expenses.map { ($0.id, $0) })

      for snap in snaps {
        if let expense = expensesById[snap.expenseId] {
          expense.title = snap.title
          expense.amount = snap.amount
          expense.merchant = snap.merchant
          expense.notes = snap.notes
          // Restore categories if present in snapshot (backwards-compatible)
          if let cats = snap.categories {
            expense.categories = cats
          }
          expense.paymentMethod = snap.paymentMethod
          expense.currency = snap.currency
          expense.isIncome = snap.isIncome
          expense.templateSnapshotHash = snap.templateSnapshotHash
          applied = true
        }
      }
      if applied {
        try context.save()
        ExpenseViewModel().syncExpensesToWidget(context: context)
        scheduleUpcomingNotifications(context: context)
        UserDefaults.standard.removeObject(forKey: key)
      }
    } catch {
      ErrorPresenter.presentOnMain(error)
      Logging.log.error(
        "Failed to undo template update: \(String(describing: error), privacy: .public)")
      return false
    }

    return applied
  }

  // MARK: - Missed Payment Detection

  /// Check for missed recurring payments (3+ days overdue)
  func checkMissedPayments(context: ModelContext) -> [RecurringExpenseTemplate] {
    let descriptor = FetchDescriptor<RecurringExpenseTemplate>()

    do {
      let allTemplates = try context.fetch(descriptor)
      let templates = allTemplates.filter { $0.isActive && !$0.isCurrentlyPaused }
      let calendar = Calendar.current
      let now = Date()
      let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now)
        ?? now.addingTimeInterval(-3 * 24 * 60 * 60)

      return templates.filter { template in
        guard let lastDueDate = mostRecentDueDate(for: template, onOrBefore: now) else {
          return false
        }
        return lastDueDate < threeDaysAgo
          && !expenseExists(for: template, on: lastDueDate, context: context)
      }

    } catch {
      return []
    }
  }

  private func dateByAddingFrequency(
    _ frequency: ExpenseFrequency,
    multiplier: Int,
    to startDate: Date,
    calendar: Calendar
  ) -> Date? {
    switch frequency {
    case .weekly:
      return calendar.date(byAdding: .weekOfYear, value: multiplier, to: startDate)
    case .monthly:
      return calendar.date(byAdding: .month, value: multiplier, to: startDate)
    case .yearly:
      return calendar.date(byAdding: .year, value: multiplier, to: startDate)
    case .oneTime:
      return nil
    }
  }

  private func maxGenerationMultiplier(
    for frequency: ExpenseFrequency,
    startDate: Date,
    endDate: Date,
    calendar: Calendar
  ) -> Int {
    guard endDate >= startDate else { return 0 }
    let diff: Int
    switch frequency {
    case .weekly:
      diff = calendar.dateComponents([.weekOfYear], from: startDate, to: endDate).weekOfYear ?? 0
    case .monthly:
      diff = calendar.dateComponents([.month], from: startDate, to: endDate).month ?? 0
    case .yearly:
      diff = calendar.dateComponents([.year], from: startDate, to: endDate).year ?? 0
    case .oneTime:
      diff = 0
    }
    return max(0, diff) + 1
  }

  private func mostRecentDueDate(
    for template: RecurringExpenseTemplate,
    onOrBefore date: Date
  ) -> Date? {
    guard template.frequency != .oneTime else {
      return template.startDate <= date ? template.startDate : nil
    }
    guard template.startDate <= date else { return nil }
    guard let nextDate = template.nextDueDate(from: date) else { return nil }

    let calendar = Calendar.current
    switch template.frequency {
    case .weekly:
      return calendar.date(byAdding: .weekOfYear, value: -1, to: nextDate)
    case .monthly:
      return calendar.date(byAdding: .month, value: -1, to: nextDate)
    case .yearly:
      return calendar.date(byAdding: .year, value: -1, to: nextDate)
    case .oneTime:
      return nil
    }
  }
}
