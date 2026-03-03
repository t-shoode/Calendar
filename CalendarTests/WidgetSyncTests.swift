import SwiftData
import XCTest

@testable import Calendar

final class WidgetSyncTests: XCTestCase {
  var container: ModelContainer!
  var context: ModelContext!
  var defaults: UserDefaults!
  var suiteName: String!

  override func setUpWithError() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    container = try ModelContainer(
      for: Event.self, TodoItem.self, TodoCategory.self, Expense.self,
      RecurringExpenseTemplate.self, MonobankConnection.self, MonobankAccount.self,
      MonobankStatementItem.self, MonobankSyncState.self, MonobankConflict.self,
      configurations: config)
    context = ModelContext(container)

    // unique suite for isolation
    suiteName = "test.widgets.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)
    defaults.removePersistentDomain(forName: suiteName)
  }

  override func tearDownWithError() throws {
    if let suiteName {
      defaults?.removePersistentDomain(forName: suiteName)
    }
    defaults = nil
    suiteName = nil
  }

  func testEventSync_writesWidgetEventDataToInjectedUserDefaults() throws {
    // create an event within the widget window
    let event = Event(
      date: Date(), title: "TestEvent", notes: nil, color: "red", reminderInterval: nil)
    context.insert(event)
    try context.save()

    EventViewModel().syncEventsToWidget(context: context, userDefaults: defaults)

    let json = defaults.string(forKey: "widgetEventData")
    XCTAssertNotNil(json)
    XCTAssertTrue(json!.contains("TestEvent"))
  }

  func testExpenseSync_writesUpcomingExpensesToInjectedUserDefaults() throws {
    let template = RecurringExpenseTemplate(
      title: "A", amount: 5.0, merchant: "M", frequency: .monthly, startDate: Date())
    context.insert(template)

    let expense = Expense(
      title: "A", amount: 5.0, date: Date(), categories: [.other], paymentMethod: .card,
      currency: .uah)
    expense.templateId = template.id
    context.insert(expense)
    try context.save()

    ExpenseViewModel().syncExpensesToWidget(context: context, userDefaults: defaults)
    let data = defaults.data(forKey: "widgetUpcomingExpenses")
    XCTAssertNotNil(data)
  }

  func testTodoSync_writesUpcomingTodosAndCountToInjectedUserDefaults() throws {
    let category = TodoCategory(name: "C", color: "blue")
    context.insert(category)

    let todo = TodoItem(
      title: "T", priority: .medium,
      dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()), reminderInterval: nil,
      category: category)
    context.insert(todo)
    try context.save()

    TodoViewModel().syncTodoCountToWidget(context: context, userDefaults: defaults)
    XCTAssertEqual(defaults.integer(forKey: "incompleteTodoCount"), 1)
    XCTAssertNotNil(defaults.data(forKey: "widgetUpcomingTodos"))
  }
}
