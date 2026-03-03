import Foundation
import SwiftData

@Model
final class MonobankConnection {
  var id: UUID
  var hasConsent: Bool
  var isConnected: Bool
  var clientId: String?
  var clientName: String?
  var selectedAccountIds: [String]
  var rangePreset: String
  var customFromDate: Date?
  var customToDate: Date?
  var lastSyncAt: Date?
  var lastSyncStatus: String?
  var lastSyncErrorMessage: String?
  var lastSyncErrorAt: Date?
  var createdAt: Date
  var updatedAt: Date

  init() {
    self.id = UUID()
    self.hasConsent = false
    self.isConnected = false
    self.clientId = nil
    self.clientName = nil
    self.selectedAccountIds = []
    self.rangePreset = "30d"
    self.customFromDate = nil
    self.customToDate = nil
    self.lastSyncAt = nil
    self.lastSyncStatus = nil
    self.lastSyncErrorMessage = nil
    self.lastSyncErrorAt = nil
    self.createdAt = Date()
    self.updatedAt = Date()
  }
}

@Model
final class MonobankAccount {
  var id: UUID
  var accountId: String
  var currencyCode: Int
  var balanceMinor: Int64
  var cashbackType: String?
  var iban: String?
  var maskedPan: [String]
  var isSelected: Bool
  var isPinned: Bool = false
  var cardTheme: String = "auto"
  var themeVersion: String?
  var updatedAt: Date

  init(
    accountId: String,
    currencyCode: Int,
    balanceMinor: Int64,
    cashbackType: String?,
    iban: String?,
    maskedPan: [String],
    isSelected: Bool,
    isPinned: Bool = false,
    cardTheme: String = "auto",
    themeVersion: String? = nil
  ) {
    self.id = UUID()
    self.accountId = accountId
    self.currencyCode = currencyCode
    self.balanceMinor = balanceMinor
    self.cashbackType = cashbackType
    self.iban = iban
    self.maskedPan = maskedPan
    self.isSelected = isSelected
    self.isPinned = isPinned
    self.cardTheme = cardTheme
    self.themeVersion = themeVersion
    self.updatedAt = Date()
  }
}

@Model
final class MonobankStatementItem {
  var id: UUID
  var statementId: String
  var accountId: String
  var transactionTime: Date
  var descriptionText: String
  var mcc: Int?
  var hold: Bool
  var amountMinor: Int64
  var operationAmountMinor: Int64
  var currencyCode: Int
  var balanceMinor: Int64
  var comment: String?
  var counterName: String?
  var projectedExpenseId: UUID?
  var updatedAt: Date

  init(
    statementId: String,
    accountId: String,
    transactionTime: Date,
    descriptionText: String,
    mcc: Int?,
    hold: Bool,
    amountMinor: Int64,
    operationAmountMinor: Int64,
    currencyCode: Int,
    balanceMinor: Int64,
    comment: String?,
    counterName: String?
  ) {
    self.id = UUID()
    self.statementId = statementId
    self.accountId = accountId
    self.transactionTime = transactionTime
    self.descriptionText = descriptionText
    self.mcc = mcc
    self.hold = hold
    self.amountMinor = amountMinor
    self.operationAmountMinor = operationAmountMinor
    self.currencyCode = currencyCode
    self.balanceMinor = balanceMinor
    self.comment = comment
    self.counterName = counterName
    self.projectedExpenseId = nil
    self.updatedAt = Date()
  }
}

@Model
final class MonobankSyncState {
  var id: UUID
  var endpointKey: String
  var lastRequestAt: Date?
  var lastSyncedUnix: Int64

  init(endpointKey: String) {
    self.id = UUID()
    self.endpointKey = endpointKey
    self.lastRequestAt = nil
    self.lastSyncedUnix = 0
  }
}

@Model
final class MonobankConflict {
  var id: UUID
  var statementId: String
  var expenseId: UUID
  var reason: String
  var status: String
  var createdAt: Date
  var resolvedAt: Date?

  init(statementId: String, expenseId: UUID, reason: String, status: String = "pending") {
    self.id = UUID()
    self.statementId = statementId
    self.expenseId = expenseId
    self.reason = reason
    self.status = status
    self.createdAt = Date()
    self.resolvedAt = nil
  }
}
