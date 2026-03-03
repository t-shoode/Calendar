import XCTest

@testable import Calendar

final class MonobankProjectionMapperTests: XCTestCase {
  func testAmountConversionFromMinorUnits() {
    XCTAssertEqual(
      MonobankProjectionMapper.amountMajor(fromMinor: -12_345), 123.45, accuracy: 0.0001)
    XCTAssertEqual(MonobankProjectionMapper.amountMajor(fromMinor: 500), 5.0, accuracy: 0.0001)
  }

  func testIncomeSignMapping() {
    XCTAssertFalse(MonobankProjectionMapper.isIncome(fromMinor: -100))
    XCTAssertTrue(MonobankProjectionMapper.isIncome(fromMinor: 100))
  }

  func testCurrencyCodeMapping() {
    XCTAssertEqual(MonobankProjectionMapper.currency(fromMonobankCode: 980), .uah)
    XCTAssertEqual(MonobankProjectionMapper.currency(fromMonobankCode: 840), .usd)
    XCTAssertEqual(MonobankProjectionMapper.currency(fromMonobankCode: 978), .eur)
    XCTAssertEqual(MonobankProjectionMapper.currency(fromMonobankCode: 999), .uah)
  }

  func testMCCCategoryMapping() {
    XCTAssertEqual(MonobankProjectionMapper.category(forMCC: 5411), .groceries)
    XCTAssertEqual(MonobankProjectionMapper.category(forMCC: 5812), .dining)
    XCTAssertEqual(MonobankProjectionMapper.category(forMCC: 5541), .transportation)
    XCTAssertEqual(MonobankProjectionMapper.category(forMCC: 4899), .subscriptions)
    XCTAssertEqual(MonobankProjectionMapper.category(forMCC: 5311), .shopping)
    XCTAssertEqual(MonobankProjectionMapper.category(forMCC: 7997), .entertainment)
    XCTAssertEqual(MonobankProjectionMapper.category(forMCC: nil), .other)
  }
}
