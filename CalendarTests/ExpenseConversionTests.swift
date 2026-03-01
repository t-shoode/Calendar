import XCTest

@testable import Calendar

final class ExpenseConversionTests: XCTestCase {
  func testAmountInUAH_convertsExpenseByCurrencyRate() {
    let viewModel = ExpenseViewModel()
    let expense = Expense(
      title: "USD Test",
      amount: 2.0,
      date: Date(),
      categories: [.other],
      paymentMethod: .card,
      currency: .usd,
      merchant: "Test",
      notes: nil,
      templateId: nil,
      isGenerated: false,
      isIncome: false
    )

    let converted = viewModel.amountInUAH(expense)
    XCTAssertEqual(converted, 86.0, accuracy: 0.001)
  }

  func testAmountInUAH_convertsTemplateByCurrencyRate() {
    let viewModel = ExpenseViewModel()
    let template = RecurringExpenseTemplate(
      title: "EUR Test",
      amount: 2.0,
      categories: [.other],
      paymentMethod: .card,
      currency: .eur,
      merchant: "Test",
      frequency: .monthly,
      startDate: Date()
    )

    let converted = viewModel.amountInUAH(template)
    XCTAssertEqual(converted, 102.0, accuracy: 0.001)
  }
}
