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

  func testRolloverCarryAmount_returnsUnusedPartOnly() {
    XCTAssertEqual(
      service.rolloverCarryAmount(limitAmountUAH: 1000, previousSpentUAH: 750),
      250,
      accuracy: 0.001
    )
    XCTAssertEqual(
      service.rolloverCarryAmount(limitAmountUAH: 1000, previousSpentUAH: 1400),
      0,
      accuracy: 0.001
    )
  }

  func testEffectiveBudget_includesRolloverOnlyWhenEnabled() {
    let rolloverEnabled = BudgetLimit(
      category: .groceries,
      amountUAH: 1000,
      rolloverEnabled: true,
      rolloverAmountUAH: 180
    )
    let rolloverDisabled = BudgetLimit(
      category: .groceries,
      amountUAH: 1000,
      rolloverEnabled: false,
      rolloverAmountUAH: 180
    )

    XCTAssertEqual(service.effectiveBudgetUAH(for: rolloverEnabled), 1180, accuracy: 0.001)
    XCTAssertEqual(service.effectiveBudgetUAH(for: rolloverDisabled), 1000, accuracy: 0.001)
  }

  func testRemainingPerDay_usesEffectiveBudgetAndDaysLeft() {
    let calendar = Calendar(identifier: .gregorian)
    let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 16))!
    let spentDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!

    let limit = BudgetLimit(
      category: .groceries,
      amountUAH: 1000,
      rolloverEnabled: true,
      rolloverAmountUAH: 200
    )
    let expense = Expense(
      title: "Groceries",
      amount: 400,
      date: spentDate,
      categories: [.groceries],
      paymentMethod: .card,
      currency: .uah
    )

    let remaining = service.remainingBudgetUAH(
      for: limit,
      expenses: [expense],
      referenceDate: referenceDate
    )
    let perDay = service.remainingPerDayUAH(
      for: limit,
      expenses: [expense],
      referenceDate: referenceDate
    )

    XCTAssertEqual(remaining, 800, accuracy: 0.001)
    XCTAssertEqual(perDay, 50, accuracy: 0.001)
  }
}
