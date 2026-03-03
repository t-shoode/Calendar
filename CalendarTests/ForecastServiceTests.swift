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

  func testForecastDays_appliesScenarioMultipliers() {
    let calendar = Calendar(identifier: .gregorian)
    let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

    let expense = Expense(
      title: "Expense",
      amount: 100,
      date: start,
      categories: [.other],
      paymentMethod: .card,
      currency: .uah,
      isIncome: false
    )
    let income = Expense(
      title: "Income",
      amount: 100,
      date: start,
      categories: [.other],
      paymentMethod: .card,
      currency: .uah,
      isIncome: true
    )

    let baseline = service.forecastDays(
      startDate: start,
      days: 1,
      expenses: [expense, income],
      templates: [],
      scenario: .baseline
    )
    let conservative = service.forecastDays(
      startDate: start,
      days: 1,
      expenses: [expense, income],
      templates: [],
      scenario: .conservative
    )
    let optimistic = service.forecastDays(
      startDate: start,
      days: 1,
      expenses: [expense, income],
      templates: [],
      scenario: .optimistic
    )

    XCTAssertEqual(baseline.count, 1)
    XCTAssertEqual(conservative.count, 1)
    XCTAssertEqual(optimistic.count, 1)

    XCTAssertEqual(baseline[0].expensesUAH, 100, accuracy: 0.001)
    XCTAssertEqual(baseline[0].incomeUAH, 100, accuracy: 0.001)
    XCTAssertEqual(conservative[0].expensesUAH, 112, accuracy: 0.001)
    XCTAssertEqual(conservative[0].incomeUAH, 94, accuracy: 0.001)
    XCTAssertEqual(optimistic[0].expensesUAH, 92, accuracy: 0.001)
    XCTAssertEqual(optimistic[0].incomeUAH, 106, accuracy: 0.001)
  }

  func testConfidenceBand_returnsLowAndHighBounds() {
    let calendar = Calendar(identifier: .gregorian)
    let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
    let historyDate1 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 13))!
    let historyDate2 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 14))!

    let upcoming = Expense(
      title: "Upcoming",
      amount: 200,
      date: start,
      categories: [.other],
      paymentMethod: .card,
      currency: .uah
    )
    let historical1 = Expense(
      title: "History 1",
      amount: 50,
      date: historyDate1,
      categories: [.other],
      paymentMethod: .card,
      currency: .uah
    )
    let historical2 = Expense(
      title: "History 2",
      amount: 600,
      date: historyDate2,
      categories: [.other],
      paymentMethod: .card,
      currency: .uah
    )
    let bill = BillItem(
      name: "Utility",
      amount: 100,
      currency: .uah,
      dueDate: historyDate2,
      recurrence: .monthly
    )

    let bands = service.confidenceBand(
      startDate: start,
      days: 1,
      expenses: [upcoming, historical1, historical2],
      templates: [],
      bills: [bill]
    )

    XCTAssertEqual(bands.count, 1)
    XCTAssertLessThan(bands[0].lowNetUAH, bands[0].highNetUAH)
  }

  func testApplyWhatIf_distributesDeltaAcrossDays() {
    let calendar = Calendar(identifier: .gregorian)
    let day1 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    let day2 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!

    let base = [
      ForecastDay(date: day1, expensesUAH: 100, incomeUAH: 200),
      ForecastDay(date: day2, expensesUAH: 100, incomeUAH: 200),
    ]

    let adjusted = service.applyWhatIf(
      to: base,
      deltaExpensesUAH: 40,
      deltaIncomeUAH: 20
    )

    XCTAssertEqual(adjusted[0].expensesUAH, 120, accuracy: 0.001)
    XCTAssertEqual(adjusted[1].expensesUAH, 120, accuracy: 0.001)
    XCTAssertEqual(adjusted[0].incomeUAH, 210, accuracy: 0.001)
    XCTAssertEqual(adjusted[1].incomeUAH, 210, accuracy: 0.001)
  }
}
