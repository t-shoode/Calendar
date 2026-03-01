import XCTest

@testable import Calendar

final class ForecastServiceTests: XCTestCase {
  private let service = ForecastService.shared

  func testForecastDays_includesRecurringAndFutureExpensesInUAH() {
    let calendar = Calendar(identifier: .gregorian)
    let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    let oneDayLater = calendar.date(byAdding: .day, value: 1, to: start)!

    let futureExpense = Expense(
      title: "Rent",
      amount: 100,
      date: oneDayLater,
      categories: [.housing],
      paymentMethod: .card,
      currency: .uah,
      isIncome: false
    )
    let recurring = RecurringExpenseTemplate(
      title: "Subscription",
      amount: 2,
      categories: [.subscriptions],
      paymentMethod: .card,
      currency: .usd,
      merchant: "Service",
      frequency: .monthly,
      startDate: start,
      isIncome: false
    )

    let forecast = service.forecastDays(
      startDate: start,
      days: 3,
      expenses: [futureExpense],
      templates: [recurring]
    )

    XCTAssertEqual(forecast.count, 2)
    XCTAssertEqual(forecast[0].date, start)
    XCTAssertEqual(forecast[0].expensesUAH, 86, accuracy: 0.001)
    XCTAssertEqual(forecast[1].date, oneDayLater)
    XCTAssertEqual(forecast[1].expensesUAH, 100, accuracy: 0.001)
  }

  func testForecastDays_respectsWindowBounds() {
    let calendar = Calendar(identifier: .gregorian)
    let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    let nextDay = calendar.date(byAdding: .day, value: 1, to: start)!

    let outOfWindowExpense = Expense(
      title: "Out",
      amount: 10,
      date: nextDay,
      categories: [.other],
      paymentMethod: .card,
      currency: .uah
    )

    let forecast = service.forecastDays(
      startDate: start,
      days: 1,
      expenses: [outOfWindowExpense],
      templates: []
    )

    XCTAssertTrue(forecast.isEmpty)
  }
}
