import Foundation
import SwiftData

enum BudgetPeriod: String, Codable, CaseIterable {
  case monthly

  var displayName: String {
    switch self {
    case .monthly:
      return Localization.string(.expensePeriodMonthly)
    }
  }
}

@Model
final class BudgetLimit {
  var id: UUID
  var categoryRawValue: String
  var amountUAH: Double
  var period: String
  var rolloverEnabled: Bool
  var rolloverAmountUAH: Double
  var dailyBudgetEnabled: Bool
  var createdAt: Date
  var updatedAt: Date

  var category: ExpenseCategory {
    ExpenseCategory(rawValue: categoryRawValue) ?? .other
  }

  var periodEnum: BudgetPeriod {
    get { BudgetPeriod(rawValue: period) ?? .monthly }
    set { period = newValue.rawValue }
  }

  init(
    category: ExpenseCategory,
    amountUAH: Double,
    period: BudgetPeriod = .monthly,
    rolloverEnabled: Bool = false,
    rolloverAmountUAH: Double = 0,
    dailyBudgetEnabled: Bool = false
  ) {
    self.id = UUID()
    self.categoryRawValue = category.rawValue
    self.amountUAH = amountUAH
    self.period = period.rawValue
    self.rolloverEnabled = rolloverEnabled
    self.rolloverAmountUAH = rolloverAmountUAH
    self.dailyBudgetEnabled = dailyBudgetEnabled
    self.createdAt = Date()
    self.updatedAt = Date()
  }
}
