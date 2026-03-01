import XCTest

@testable import Calendar

final class BudgetServiceTests: XCTestCase {
  private let service = BudgetService.shared

  func testSpentUAH_usesFXConversionForMixedCurrencies() {
    let date = Date()
    let usd = Expense(
      title: "USD expense",
      amount: 2,
      date: date,
      categories: [.groceries],
      paymentMethod: .card,
      currency: .usd
    )
    let eur = Expense(
      title: "EUR expense",
      amount: 1,
      date: date,
      categories: [.groceries],
      paymentMethod: .card,
      currency: .eur
    )

    let spent = service.spentUAH(
      for: .groceries,
      expenses: [usd, eur],
      in: .monthly,
      referenceDate: date
    )

    XCTAssertEqual(spent, 137, accuracy: 0.001)
  }

  func testCrossedThresholds_returnsEightyAndHundredAtLimit() {
    let thresholds = service.crossedThresholds(spentUAH: 1000, limitAmountUAH: 1000)
    XCTAssertEqual(thresholds, [.eighty, .hundred])
  }
}
