import SwiftData
import XCTest

@testable import Calendar

final class FXRateServiceTests: XCTestCase {
  private var container: ModelContainer!
  private var context: ModelContext!
  private let service = FXRateService.shared

  override func setUpWithError() throws {
    clearFXDefaults()
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    container = try ModelContainer(for: FXRate.self, configurations: config)
    context = ModelContext(container)
  }

  override func tearDownWithError() throws {
    clearFXDefaults()
  }

  func testUpsertRate_updatesConversionUsingLatestRate() throws {
    try service.upsertRate(currency: .usd, rateToUAH: 50, source: "test", context: context)
    try context.save()

    let expense = Expense(
      title: "USD",
      amount: 2,
      date: Date(),
      categories: [.other],
      paymentMethod: .card,
      currency: .usd
    )
    let converted = ExpenseViewModel().amountInUAH(expense)

    XCTAssertEqual(converted, 100, accuracy: 0.001)
  }

  func testManualRate_preventsAutoOverride() throws {
    try service.setManualRate(currency: .usd, rateToUAH: 60, context: context)
    try service.upsertRate(currency: .usd, rateToUAH: 40, source: "test", context: context)

    let expense = Expense(
      title: "USD",
      amount: 2,
      date: Date(),
      categories: [.other],
      paymentMethod: .card,
      currency: .usd
    )
    let converted = ExpenseViewModel().amountInUAH(expense)

    XCTAssertEqual(converted, 120, accuracy: 0.001)
  }

  func testAmountConversion_fallsBackToBuiltInRateWhenNoCache() {
    let expense = Expense(
      title: "USD",
      amount: 2,
      date: Date(),
      categories: [.other],
      paymentMethod: .card,
      currency: .usd
    )
    let converted = ExpenseViewModel().amountInUAH(expense)

    XCTAssertEqual(converted, 86, accuracy: 0.001)
  }

  private func clearFXDefaults() {
    let defaults = UserDefaults(suiteName: Constants.Storage.appGroupIdentifier) ?? .standard
    defaults.removeObject(forKey: Constants.FX.rateUSDKey)
    defaults.removeObject(forKey: Constants.FX.rateEURKey)
    defaults.removeObject(forKey: Constants.FX.manualUSDKey)
    defaults.removeObject(forKey: Constants.FX.manualEURKey)
    defaults.removeObject(forKey: Constants.FX.updatedAtKey)
  }
}
