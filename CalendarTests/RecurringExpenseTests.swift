import SwiftData
import XCTest

@testable import Calendar

final class RecurringExpenseTests: XCTestCase {
  var container: ModelContainer!
  var context: ModelContext!

  override func setUpWithError() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    container = try ModelContainer(
      for: Expense.self, RecurringExpenseTemplate.self, configurations: config)
    context = ModelContext(container)
  }

  func testUpdateGeneratedExpenses_updatesCategories_and_canUndo() throws {
    // Create template and a generated expense linked to it
    let template = RecurringExpenseTemplate(
      title: "Gym",
      amount: 30.0,
      categories: [.other],
      merchant: "GymCo",
      frequency: .monthly,
      startDate: Date()
    )
    context.insert(template)

    let calendar = Calendar.current
    let nextMonth = calendar.date(byAdding: .month, value: 1, to: Date())!
    let expense = Expense(
      title: "Gym",
      amount: 30.0,
      date: nextMonth,
      categories: [.other],
      paymentMethod: .card,
      currency: .uah,
      merchant: "GymCo",
      templateId: template.id,
      isGenerated: true
    )
    context.insert(expense)
    try context.save()

    // Update template categories and run propagation
    template.categories = [ExpenseCategory.fitness.rawValue]
    template.updatedAt = Date()
    try context.save()

    let result = RecurringExpenseService.shared.updateGeneratedExpenses(
      for: template, applyFrom: Date(), context: context)

    XCTAssertEqual(result.updatedCount, 1)
    XCTAssertEqual(result.skippedManualCount, 0)

    // Verify generated expense was updated
    let fetched = try context.fetch(FetchDescriptor<Expense>()).first {
      $0.templateId == template.id
    }
    XCTAssertEqual(fetched?.categories.first, ExpenseCategory.fitness.rawValue)

    // Undo and verify categories restored to original
    let undone = RecurringExpenseService.shared.undoLastTemplateUpdate(
      templateId: template.id, context: context)
    XCTAssertTrue(undone)

    let restored = try context.fetch(FetchDescriptor<Expense>()).first {
      $0.templateId == template.id
    }
    XCTAssertEqual(restored?.categories.first, ExpenseCategory.other.rawValue)
  }

  func testUpdateGeneratedExpenses_skipsManuallyEdited() throws {
    let template = RecurringExpenseTemplate(
      title: "Membership",
      amount: 10.0,
      merchant: "Club",
      frequency: .monthly,
      startDate: Date()
    )
    context.insert(template)

    let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
    let expense = Expense(title: "Membership", amount: 10.0, date: nextMonth)
    expense.templateId = template.id
    expense.isGenerated = true
    expense.isManuallyEdited = true
    context.insert(expense)
    try context.save()

    template.title = "Club Membership"
    template.updatedAt = Date()
    try context.save()

    let result = RecurringExpenseService.shared.updateGeneratedExpenses(
      for: template, applyFrom: Date(), context: context)
    XCTAssertEqual(result.updatedCount, 0)
    XCTAssertEqual(result.skippedManualCount, 1)
  }

  func testGenerateRecurringExpenses_skipsInactiveTemplates() throws {
    let template = RecurringExpenseTemplate(
      title: "Streaming",
      amount: 15.0,
      merchant: "StreamCo",
      frequency: .monthly,
      startDate: Date()
    )
    template.isActive = false
    context.insert(template)
    try context.save()

    RecurringExpenseService.shared.generateRecurringExpenses(context: context)

    let expenses = try context.fetch(FetchDescriptor<Expense>())
    XCTAssertTrue(expenses.isEmpty)
  }

  func testNotificationTriggerDate_schedulesAsapWhenDayBeforePassed() {
    let calendar = Calendar.current
    let dueDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 12))!
    let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 10))!

    let trigger = RecurringExpenseService.shared.notificationTriggerDate(
      forDueDate: dueDate, now: now)
    let expected = now.addingTimeInterval(5 * 60)

    XCTAssertNotNil(trigger)
    XCTAssertEqual(trigger!.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1.0)
  }
}
