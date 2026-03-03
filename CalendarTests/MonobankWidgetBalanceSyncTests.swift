import SwiftData
import XCTest

@testable import Calendar

final class MonobankWidgetBalanceSyncTests: XCTestCase {
  var container: ModelContainer!
  var context: ModelContext!
  var defaults: UserDefaults!
  var suiteName: String!

  override func setUpWithError() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    container = try ModelContainer(
      for: MonobankAccount.self,
      configurations: config
    )
    context = ModelContext(container)

    suiteName = "test.monobank.widget.\(UUID().uuidString)"
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

  func testSyncSelectedBalancesToWidgetWritesPayload() throws {
    let selectedAccount = MonobankAccount(
      accountId: "abc123456789",
      currencyCode: 980,
      balanceMinor: 123_45,
      cashbackType: nil,
      iban: nil,
      maskedPan: [],
      isSelected: true
    )
    let unselectedAccount = MonobankAccount(
      accountId: "def987654321",
      currencyCode: 840,
      balanceMinor: 555_00,
      cashbackType: nil,
      iban: nil,
      maskedPan: [],
      isSelected: false
    )

    context.insert(selectedAccount)
    context.insert(unselectedAccount)
    try context.save()

    try MonobankSyncService.shared.syncSelectedBalancesToWidget(
      context: context,
      userDefaults: defaults
    )

    let data = defaults.data(forKey: Constants.Widget.monobankBalancesKey)
    XCTAssertNotNil(data)
    XCTAssertTrue(defaults.bool(forKey: Constants.Widget.monobankAuthorizedKey))

    let decoded = try JSONDecoder().decode(
      [MonobankSyncService.WidgetMonobankBalanceItem].self, from: data!)
    XCTAssertEqual(decoded.count, 1)
    XCTAssertEqual(decoded.first?.accountId, "6789")
    XCTAssertEqual(decoded.first?.currency, "uah")
    XCTAssertEqual(decoded.first?.balanceMajor ?? 0, 123.45, accuracy: 0.001)
  }

  func testSyncSelectedBalancesToWidgetUsesPinnedAccountsWhenAvailable() throws {
    let pinnedUAH = MonobankAccount(
      accountId: "aaa11112222",
      currencyCode: 980,
      balanceMinor: 200_00,
      cashbackType: nil,
      iban: nil,
      maskedPan: [],
      isSelected: true,
      isPinned: true
    )
    let pinnedUSD = MonobankAccount(
      accountId: "bbb33334444",
      currencyCode: 840,
      balanceMinor: 50_00,
      cashbackType: nil,
      iban: nil,
      maskedPan: [],
      isSelected: true,
      isPinned: true
    )
    let selectedUnpinned = MonobankAccount(
      accountId: "ccc55556666",
      currencyCode: 978,
      balanceMinor: 75_00,
      cashbackType: nil,
      iban: nil,
      maskedPan: [],
      isSelected: true,
      isPinned: false
    )

    context.insert(pinnedUAH)
    context.insert(pinnedUSD)
    context.insert(selectedUnpinned)
    try context.save()

    try MonobankSyncService.shared.syncSelectedBalancesToWidget(
      context: context,
      userDefaults: defaults
    )

    let data = defaults.data(forKey: Constants.Widget.monobankBalancesKey)
    XCTAssertNotNil(data)

    let decoded = try JSONDecoder().decode(
      [MonobankSyncService.WidgetMonobankBalanceItem].self, from: data!)
    let ids = Set(decoded.map(\.accountId))

    XCTAssertEqual(decoded.count, 2)
    XCTAssertEqual(ids, ["2222", "4444"])
  }
}
