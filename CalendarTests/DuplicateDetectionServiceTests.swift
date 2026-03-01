import SwiftData
import XCTest

@testable import Calendar

final class DuplicateDetectionServiceTests: XCTestCase {
  private var container: ModelContainer!
  private var context: ModelContext!
  private let service = DuplicateDetectionService.shared

  override func setUpWithError() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    container = try ModelContainer(
      for: Expense.self, DuplicateSuggestion.self, configurations: config
    )
    context = ModelContext(container)
  }

  func testDuplicateScore_returnsHighScoreForNearDuplicate() {
    let baseDate = Date()
    let a = Expense(
      title: "Netflix Premium",
      amount: 100,
      date: baseDate,
      categories: [.subscriptions],
      paymentMethod: .card,
      currency: .uah
    )
    let b = Expense(
      title: "Netflix Premium UA",
      amount: 101,
      date: Calendar.current.date(byAdding: .hour, value: 1, to: baseDate) ?? baseDate,
      categories: [.subscriptions],
      paymentMethod: .card,
      currency: .uah
    )

    let score = service.duplicateScore(expenseA: a, expenseB: b)
    XCTAssertNotNil(score)
    XCTAssertGreaterThanOrEqual(score ?? 0, 0.75)
  }

  func testDuplicateScore_returnsNilForLowMerchantSimilarity() {
    let baseDate = Date()
    let a = Expense(
      title: "Netflix",
      amount: 100,
      date: baseDate,
      categories: [.subscriptions],
      paymentMethod: .card,
      currency: .uah
    )
    let b = Expense(
      title: "Local Grocery",
      amount: 100,
      date: baseDate,
      categories: [.groceries],
      paymentMethod: .card,
      currency: .uah
    )

    XCTAssertNil(service.duplicateScore(expenseA: a, expenseB: b))
  }

  func testMergeSuggestion_deletesOneExpenseAndMarksMerged() throws {
    let a = Expense(
      title: "Duplicate A",
      amount: 100,
      date: Date(),
      categories: [.other],
      paymentMethod: .card,
      currency: .uah,
      notes: "from a"
    )
    let b = Expense(
      title: "Duplicate A",
      amount: 100,
      date: Date(),
      categories: [.other],
      paymentMethod: .card,
      currency: .uah,
      notes: "from b"
    )
    context.insert(a)
    context.insert(b)

    let suggestion = DuplicateSuggestion(expenseIdA: a.id, expenseIdB: b.id, score: 0.95)
    context.insert(suggestion)
    try context.save()

    try service.mergeSuggestion(suggestion, context: context)

    let expenses = try context.fetch(FetchDescriptor<Expense>())
    XCTAssertEqual(expenses.count, 1)
    XCTAssertEqual(suggestion.statusEnum, .merged)
  }
}
