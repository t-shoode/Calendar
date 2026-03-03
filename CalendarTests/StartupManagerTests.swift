import SwiftData
import XCTest

@testable import Calendar

@MainActor
final class StartupManagerTests: XCTestCase {
  var container: ModelContainer!
  var context: ModelContext!

  override func setUpWithError() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    container = try ModelContainer(
      for: Event.self, TodoItem.self, TodoCategory.self, Expense.self,
      RecurringExpenseTemplate.self, MonobankConnection.self, MonobankAccount.self,
      MonobankStatementItem.self, MonobankSyncState.self, MonobankConflict.self,
      configurations: config)
    context = ModelContext(container)
  }

  func testStartupCompletes() async throws {
    // keep test fast by using a short minimumDisplayDuration
    let manager = StartupManager(timeout: 1, minimumDisplayDuration: 0.01)
    manager.start(using: context)

    while manager.isRunning {
      try await Task.sleep(nanoseconds: 50_000_000)
    }

    XCTAssertFalse(manager.isRunning)
  }

  func testStartupPerformsBackgroundWork_andMergesChanges() async throws {
    // create a template that should produce at least one generated expense
    let template = RecurringExpenseTemplate(
      title: "Test",
      amount: 1.0,
      merchant: "Test",
      frequency: .monthly,
      startDate: Date()
    )
    context.insert(template)
    try context.save()

    let manager = StartupManager(timeout: 2, minimumDisplayDuration: 0.0)
    manager.start(using: context)

    // wait until manager stops running or timeout
    while manager.isRunning {
      try await Task.sleep(nanoseconds: 25_000_000)
    }

    // Ensure background-generated expenses exist in main context (merge happened)
    let expenses = try context.fetch(FetchDescriptor<Expense>())
    XCTAssertTrue(expenses.contains { $0.templateId == template.id })
  }

  func testTimeoutSetsTimedOut() async throws {
    // keep test fast by using a short minimumDisplayDuration
    let manager = StartupManager(timeout: 0.1, minimumDisplayDuration: 0.01)
    manager.start(using: context)

    while !manager.timedOut {
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    XCTAssertTrue(manager.timedOut)
  }
}
