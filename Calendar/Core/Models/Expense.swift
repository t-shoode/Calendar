import Foundation
import SwiftData

@Model
class Expense {
  var id: UUID
  var title: String
  var amount: Double
  var date: Date
  var categories: [String]  // Array of ExpenseCategory rawValues (max 3)
  var paymentMethod: String  // "cash" or "card"
  var currency: String  // currency rawValue (usd/uah/eur)
  var merchant: String?
  var notes: String?
  var createdAt: Date

  // Recurring expense tracking
  var templateId: UUID?  // Links to RecurringTemplate (nil = one-time)
  var isGenerated: Bool  // true = auto-created from template
  var isIncome: Bool = false  // true = income, false = expense

  // Protect user edits made directly to generated expenses
  var isManuallyEdited: Bool = false

  // Snapshot/version marker copied from the template when the expense was generated
  var templateSnapshotHash: String?

  // External sync linkage (e.g. Monobank statement item)
  var externalSource: String?
  var externalId: String?
  var externalUpdatedAt: Date?

  // Feature expansion linkages
  var linkedEventId: UUID?
  var tripId: UUID?
  var receiptAttachmentId: UUID?
  var isSubscriptionCandidate: Bool = false
  var categorizationRuleId: UUID?

  var primaryCategory: ExpenseCategory {
    ExpenseCategory(rawValue: categories.first ?? "other") ?? .other
  }

  var allCategories: [ExpenseCategory] {
    categories.compactMap { ExpenseCategory(rawValue: $0) }
  }

  var paymentMethodEnum: PaymentMethod {
    get { PaymentMethod(rawValue: paymentMethod) ?? .card }
    set { paymentMethod = newValue.rawValue }
  }

  var currencyEnum: Currency {
    get { Currency(rawValue: currency) ?? .uah }
    set { currency = newValue.rawValue }
  }

  /// Add a category (returns false if max 3 reached)
  func addCategory(_ category: ExpenseCategory) -> Bool {
    guard categories.count < 3 else { return false }
    if !categories.contains(category.rawValue) {
      categories.append(category.rawValue)
    }
    return true
  }

  /// Remove a category
  func removeCategory(_ category: ExpenseCategory) {
    categories.removeAll { $0 == category.rawValue }
  }

  init(
    title: String,
    amount: Double,
    date: Date = Date(),
    categories: [ExpenseCategory] = [.other],
    paymentMethod: PaymentMethod = .card,
    currency: Currency = .uah,
    merchant: String? = nil,
    notes: String? = nil,
    templateId: UUID? = nil,
    isGenerated: Bool = false,
    isIncome: Bool = false
  ) {
    self.id = UUID()
    self.title = title
    self.amount = amount
    self.date = date
    self.categories = categories.map { $0.rawValue }
    self.paymentMethod = paymentMethod.rawValue
    self.currency = currency.rawValue
    self.merchant = merchant
    self.notes = notes
    self.createdAt = Date()
    self.templateId = templateId
    self.isGenerated = isGenerated
    self.isIncome = isIncome
    self.externalSource = nil
    self.externalId = nil
    self.externalUpdatedAt = nil
    self.linkedEventId = nil
    self.tripId = nil
    self.receiptAttachmentId = nil
    self.isSubscriptionCandidate = false
    self.categorizationRuleId = nil
  }
}

enum Currency: String, Codable, CaseIterable {
  case usd
  case uah
  case eur

  var symbol: String {
    switch self {
    case .usd: return "$"
    case .uah: return "₴"
    case .eur: return "€"
    }
  }

  var displayName: String {
    switch self {
    case .usd: return "USD"
    case .uah: return "UAH"
    case .eur: return "EUR"
    }
  }

  /// Exchange rate to UAH (1 unit of this currency = X UAH)
  var rateToUAH: Double {
    switch self {
    case .usd: return 43.0
    case .uah: return 1.0
    case .eur: return 51.0
    }
  }

  /// Convert amount from this currency to UAH
  func convertToUAH(_ amount: Double) -> Double {
    return amount * rateToUAH
  }

  /// Convert amount from UAH to this currency
  func convertFromUAH(_ amountInUAH: Double) -> Double {
    return amountInUAH / rateToUAH
  }
}

enum PaymentMethod: String, Codable, CaseIterable {
  case cash
  case card

  var displayName: String {
    switch self {
    case .cash: return Localization.string(.expenseCash)
    case .card: return Localization.string(.expenseCard)
    }
  }

  var icon: String {
    switch self {
    case .cash: return "banknote"
    case .card: return "creditcard"
    }
  }
}

enum ExpenseFrequency: String, Codable, CaseIterable {
  case oneTime = "oneTime"
  case weekly = "weekly"
  case monthly = "monthly"
  case yearly = "yearly"

  var displayName: String {
    switch self {
    case .oneTime: return Localization.string(.none)
    case .weekly: return Localization.string(.expenseWeekly)
    case .monthly: return Localization.string(.expenseMonthly)
    case .yearly: return Localization.string(.expenseYearly)
    }
  }

  /// Approximate days between occurrences
  var daysInterval: Int {
    switch self {
    case .oneTime: return 0
    case .weekly: return 7
    case .monthly: return 30
    case .yearly: return 365
    }
  }

  /// Get next occurrence date from a given date
  func nextDate(from date: Date) -> Date {
    let calendar = Calendar.current
    switch self {
    case .oneTime:
      return date
    case .weekly:
      return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
    case .monthly:
      return calendar.date(byAdding: .month, value: 1, to: date) ?? date
    case .yearly:
      return calendar.date(byAdding: .year, value: 1, to: date) ?? date
    }
  }
}

enum BillingCycle: String, Codable, CaseIterable {
  case weekly
  case monthly
  case yearly
}

enum CategorizationPatternType: String, Codable, CaseIterable {
  case contains
  case regex
  case mcc
}

enum NetWorthAccountType: String, Codable, CaseIterable {
  case asset
  case liability
}

enum NetWorthSource: String, Codable, CaseIterable {
  case manual
  case monobank
}

enum ScenarioPeriod: String, Codable, CaseIterable {
  case week
  case month
  case quarter
}

enum SavingsPriority: String, Codable, CaseIterable {
  case low
  case medium
  case high
}

@Model
final class SubscriptionItem {
  var id: UUID
  var name: String
  var merchant: String
  var amount: Double
  var currency: String
  var billingCycle: String
  var nextRenewalDate: Date
  var isActive: Bool
  var sourceTemplateId: UUID?
  var sourceRuleId: UUID?
  var createdAt: Date
  var updatedAt: Date

  init(
    name: String,
    merchant: String,
    amount: Double,
    currency: Currency,
    billingCycle: BillingCycle,
    nextRenewalDate: Date,
    isActive: Bool = true,
    sourceTemplateId: UUID? = nil,
    sourceRuleId: UUID? = nil
  ) {
    self.id = UUID()
    self.name = name
    self.merchant = merchant
    self.amount = amount
    self.currency = currency.rawValue
    self.billingCycle = billingCycle.rawValue
    self.nextRenewalDate = nextRenewalDate
    self.isActive = isActive
    self.sourceTemplateId = sourceTemplateId
    self.sourceRuleId = sourceRuleId
    self.createdAt = Date()
    self.updatedAt = Date()
  }
}

@Model
final class BillItem {
  var id: UUID
  var name: String
  var amount: Double
  var currency: String
  var dueDate: Date
  var recurrence: String
  var autopay: Bool
  var category: String
  var reminderLeadTime: TimeInterval
  var isPaid: Bool
  var createdAt: Date
  var updatedAt: Date

  init(
    name: String,
    amount: Double,
    currency: Currency,
    dueDate: Date,
    recurrence: BillingCycle = .monthly,
    autopay: Bool = false,
    category: ExpenseCategory = .other,
    reminderLeadTime: TimeInterval = 24 * 3600
  ) {
    self.id = UUID()
    self.name = name
    self.amount = amount
    self.currency = currency.rawValue
    self.dueDate = dueDate
    self.recurrence = recurrence.rawValue
    self.autopay = autopay
    self.category = category.rawValue
    self.reminderLeadTime = reminderLeadTime
    self.isPaid = false
    self.createdAt = Date()
    self.updatedAt = Date()
  }
}

@Model
final class SavingsGoal {
  var id: UUID
  var title: String
  var targetAmountUAH: Double
  var currentAmountUAH: Double
  var targetDate: Date?
  var monthlyTargetUAH: Double
  var priority: String
  var isArchived: Bool
  var createdAt: Date
  var updatedAt: Date

  init(
    title: String,
    targetAmountUAH: Double,
    currentAmountUAH: Double = 0,
    targetDate: Date? = nil,
    monthlyTargetUAH: Double = 0,
    priority: SavingsPriority = .medium,
    isArchived: Bool = false
  ) {
    self.id = UUID()
    self.title = title
    self.targetAmountUAH = targetAmountUAH
    self.currentAmountUAH = currentAmountUAH
    self.targetDate = targetDate
    self.monthlyTargetUAH = monthlyTargetUAH
    self.priority = priority.rawValue
    self.isArchived = isArchived
    self.createdAt = Date()
    self.updatedAt = Date()
  }
}

@Model
final class CategorizationRule {
  var id: UUID
  var patternType: String
  var patternValue: String
  var targetCategory: String
  var targetPaymentMethod: String?
  var priority: Int
  var isEnabled: Bool
  var autoApply: Bool
  var createdAt: Date
  var updatedAt: Date

  init(
    patternType: CategorizationPatternType,
    patternValue: String,
    targetCategory: ExpenseCategory,
    targetPaymentMethod: PaymentMethod? = nil,
    priority: Int = 100,
    isEnabled: Bool = true,
    autoApply: Bool = true
  ) {
    self.id = UUID()
    self.patternType = patternType.rawValue
    self.patternValue = patternValue
    self.targetCategory = targetCategory.rawValue
    self.targetPaymentMethod = targetPaymentMethod?.rawValue
    self.priority = priority
    self.isEnabled = isEnabled
    self.autoApply = autoApply
    self.createdAt = Date()
    self.updatedAt = Date()
  }
}

@Model
final class ReceiptAttachment {
  var id: UUID
  var expenseId: UUID?
  var localFilePath: String
  var ocrRawText: String
  var merchantGuess: String?
  var amountGuess: Double?
  var dateGuess: Date?
  var confidence: Double
  var createdAt: Date

  init(
    expenseId: UUID? = nil,
    localFilePath: String,
    ocrRawText: String,
    merchantGuess: String? = nil,
    amountGuess: Double? = nil,
    dateGuess: Date? = nil,
    confidence: Double = 0
  ) {
    self.id = UUID()
    self.expenseId = expenseId
    self.localFilePath = localFilePath
    self.ocrRawText = ocrRawText
    self.merchantGuess = merchantGuess
    self.amountGuess = amountGuess
    self.dateGuess = dateGuess
    self.confidence = confidence
    self.createdAt = Date()
  }
}

@Model
final class NetWorthAccount {
  var id: UUID
  var name: String
  var type: String
  var source: String
  var sourceAccountId: String?
  var balanceUAH: Double
  var includeInTotal: Bool
  var createdAt: Date
  var updatedAt: Date

  init(
    name: String,
    type: NetWorthAccountType,
    source: NetWorthSource,
    sourceAccountId: String? = nil,
    balanceUAH: Double = 0,
    includeInTotal: Bool = true
  ) {
    self.id = UUID()
    self.name = name
    self.type = type.rawValue
    self.source = source.rawValue
    self.sourceAccountId = sourceAccountId
    self.balanceUAH = balanceUAH
    self.includeInTotal = includeInTotal
    self.createdAt = Date()
    self.updatedAt = Date()
  }
}

@Model
final class TripBudget {
  var id: UUID
  var name: String
  var startDate: Date
  var endDate: Date
  var budgetUAH: Double
  var homeCurrency: String
  var isActive: Bool
  var createdAt: Date
  var updatedAt: Date

  init(
    name: String,
    startDate: Date,
    endDate: Date,
    budgetUAH: Double,
    homeCurrency: Currency = .uah,
    isActive: Bool = true
  ) {
    self.id = UUID()
    self.name = name
    self.startDate = startDate
    self.endDate = endDate
    self.budgetUAH = budgetUAH
    self.homeCurrency = homeCurrency.rawValue
    self.isActive = isActive
    self.createdAt = Date()
    self.updatedAt = Date()
  }
}

@Model
final class WeeklyReviewSnapshot {
  var id: UUID
  var weekStart: Date
  var weekEnd: Date
  var summaryJSON: String
  var generatedAt: Date

  init(weekStart: Date, weekEnd: Date, summaryJSON: String) {
    self.id = UUID()
    self.weekStart = weekStart
    self.weekEnd = weekEnd
    self.summaryJSON = summaryJSON
    self.generatedAt = Date()
  }
}

@Model
final class WhatIfScenario {
  var id: UUID
  var title: String
  var deltaExpensesUAH: Double
  var deltaIncomeUAH: Double
  var period: String
  var impactJSON: String
  var createdAt: Date

  init(
    title: String,
    deltaExpensesUAH: Double,
    deltaIncomeUAH: Double,
    period: ScenarioPeriod = .month,
    impactJSON: String = "{}"
  ) {
    self.id = UUID()
    self.title = title
    self.deltaExpensesUAH = deltaExpensesUAH
    self.deltaIncomeUAH = deltaIncomeUAH
    self.period = period.rawValue
    self.impactJSON = impactJSON
    self.createdAt = Date()
  }
}
