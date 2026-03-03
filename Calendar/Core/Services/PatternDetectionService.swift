import Foundation
import SwiftData

/// Service for detecting recurring expense patterns from transactions
class PatternDetectionService {

  /// Minimum number of occurrences to suggest a template (reduced to catch more patterns)
  private let minOccurrences = 2

  /// Time window for detection (3 months in seconds)
  private let detectionWindow: TimeInterval = 3 * 30 * 24 * 60 * 60

  /// Amount variance tolerance (increased to 10% for variable subscriptions)
  private let amountTolerance = 0.10

  /// Detect recurring patterns from transactions
  func detectPatterns(from transactions: [CSVTransaction]) -> [TemplateSuggestion] {
    // Filter to last 3 months
    let cutoffDate = Date().addingTimeInterval(-detectionWindow)
    let recentTransactions = transactions.filter { $0.date >= cutoffDate }

    // Group by normalized merchant name
    let grouped = Dictionary(grouping: recentTransactions) { normalizeMerchant($0.merchant) }

    var suggestions: [TemplateSuggestion] = []

    for (normalizedMerchant, merchantTransactions) in grouped {
      for isIncome in [false, true] {
        let directionTransactions = merchantTransactions.filter {
          isIncome ? $0.isIncome : $0.isExpense
        }
        guard directionTransactions.count >= minOccurrences else { continue }

        let isSubscription = isSubscriptionMerchant(normalizedMerchant)
        let tolerance = isSubscription ? 0.15 : amountTolerance
        let amountGroups = groupByAmount(directionTransactions, tolerance: tolerance)

        for amountGroup in amountGroups {
          let requiredOccurrences = isSubscription ? 2 : minOccurrences
          guard amountGroup.count >= requiredOccurrences else { continue }

          let sorted = amountGroup.sorted { $0.date < $1.date }
          guard
            let frequency = detectFrequency(from: sorted, isSubscription: isSubscription)
          else { continue }

          let amounts = sorted.map { abs($0.amount) }
          let avgAmount = amounts.reduce(0, +) / Double(amounts.count)
          let confidence = calculateConfidence(
            dates: sorted.map { $0.date },
            frequency: frequency,
            isSubscription: isSubscription
          )

          let categories = isIncome ? [.other] : suggestCategories(for: normalizedMerchant)

          let suggestion = TemplateSuggestion(
            merchant: normalizedMerchant,
            amount: avgAmount,
            frequency: frequency,
            occurrences: sorted.map { $0.date },
            categories: categories,
            suggestedAmount: avgAmount,
            confidence: confidence,
            isIncome: isIncome
          )

          suggestions.append(suggestion)
        }
      }
    }

    // Sort by confidence (highest first)
    return suggestions.sorted { $0.confidence > $1.confidence }
  }

  /// Check if merchant looks like a subscription service
  private func isSubscriptionMerchant(_ merchant: String) -> Bool {
    let subscriptionKeywords = [
      "netflix", "spotify", "apple", "google", "youtube", "microsoft",
      "adobe", "amazon", "prime", "disney", "hbo", "paramount",
      "subscription", "membership", "premium", "plus", "pro",
      "icloud", "dropbox", "zoom", "slack", "notion", "figma",
      "chatgpt", "openai", "midjourney", "canva", "grammarly",
      "підписка", "абонемент", "premium",
    ]

    let merchantLower = merchant.lowercased()
    return subscriptionKeywords.contains { merchantLower.contains($0) }
  }

  /// Normalize merchant name for matching (less aggressive)
  func normalizeMerchant(_ merchant: String) -> String {
    var normalized = merchant.lowercased()

    // Remove transaction IDs and numbers (common in bank statements)
    // But keep numbers that might be part of the name
    normalized = normalized.replacingOccurrences(of: "#\\d+", with: "", options: .regularExpression)
    normalized = normalized.replacingOccurrences(
      of: "\\b\\d{4,}\\b", with: "", options: .regularExpression)

    // Remove common location suffixes
    let locationWords = [
      "київ", "kyiv", "lviv", "odesa", "kharkiv", "dnipro", "vinnytsia", "ukraine",
    ]
    for word in locationWords {
      normalized = normalized.replacingOccurrences(of: word, with: "")
    }

    // Trim whitespace and clean up
    normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    normalized = normalized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

    return normalized
  }

  /// Group transactions by similar amounts
  private func groupByAmount(_ transactions: [CSVTransaction], tolerance: Double)
    -> [[CSVTransaction]]
  {
    var groups: [[CSVTransaction]] = []
    var used = Set<UUID>()

    for transaction in transactions {
      guard !used.contains(transaction.id) else { continue }

      var group = [transaction]
      used.insert(transaction.id)

      let baseAmount = abs(transaction.amount)
      let amountTolerance = baseAmount * tolerance

      for other in transactions {
        guard !used.contains(other.id) else { continue }

        let otherAmount = abs(other.amount)
        if abs(baseAmount - otherAmount) <= amountTolerance {
          group.append(other)
          used.insert(other.id)
        }
      }

      groups.append(group)
    }

    return groups
  }

  /// Detect frequency from sorted dates (more flexible ranges)
  private func detectFrequency(from transactions: [CSVTransaction], isSubscription: Bool)
    -> ExpenseFrequency?
  {
    guard transactions.count >= 2 else { return nil }

    let dates = transactions.map { $0.date }
    var intervals: [TimeInterval] = []

    for i in 1..<dates.count {
      let interval = dates[i].timeIntervalSince(dates[i - 1])
      intervals.append(interval)
    }

    guard !intervals.isEmpty else { return nil }

    let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
    let days = avgInterval / (24 * 60 * 60)

    // More flexible ranges for subscriptions
    let weeklyRange = isSubscription ? (5.0...10.0) : (6.0...8.0)
    let monthlyRange = isSubscription ? (25.0...35.0) : (28.0...32.0)
    let yearlyRange = isSubscription ? (350.0...380.0) : (360.0...370.0)

    if weeklyRange.contains(days) {
      return .weekly
    } else if monthlyRange.contains(days) {
      return .monthly
    } else if yearlyRange.contains(days) {
      return .yearly
    }

    return nil
  }

  /// Calculate confidence score based on regularity
  private func calculateConfidence(dates: [Date], frequency: ExpenseFrequency, isSubscription: Bool)
    -> Double
  {
    guard dates.count >= 2 else { return 0.0 }

    let expectedInterval = Double(frequency.daysInterval) * 24 * 60 * 60
    var totalVariance: TimeInterval = 0

    for i in 1..<dates.count {
      let actualInterval = dates[i].timeIntervalSince(dates[i - 1])
      let variance = abs(actualInterval - expectedInterval) / expectedInterval
      totalVariance += variance
    }

    let avgVariance = totalVariance / Double(dates.count - 1)

    // Subscriptions get a confidence boost
    let baseConfidence = max(0, 1 - avgVariance)
    let confidence = isSubscription ? min(1.0, baseConfidence + 0.1) : baseConfidence

    return min(1.0, confidence)
  }

  /// Suggest categories based on merchant name (expanded keywords)
  private func suggestCategories(for merchant: String) -> [ExpenseCategory] {
    let merchantLower = merchant.lowercased()

    // Expanded keyword mapping
    let keywords: [(keywords: [String], category: ExpenseCategory)] = [
      (["пекарня", "булочна", "хліб", "coffee", "starbucks", "cafe", "ресторан", "кафе"], .dining),
      (
        ["сільпо", "атб", "варус", "маркет", "groceries", "supermarket", "silpo", "atb"], .groceries
      ),
      (["заправка", "wog", "окко", "автодор", "shell", "bp", "fuel", "gas"], .transportation),
      (["аптека", "pharmacy", "medical", "лікарня", "hospital", "drugstore"], .healthcare),
      (
        ["кіно", "theatre", "theater", "concert", "entertainment", "movie", "cinema"],
        .entertainment
      ),
      (
        [
          "netflix", "spotify", "apple", "google", "subscription", "youtube", "disney", "hbo",
          "prime", "icloud",
        ], .subscriptions
      ),
      (["зал", "gym", "fitness", "sport"], .healthcare),
      (["одяг", "clothes", "fashion", "zara", "h&m", "shopping"], .shopping),
      (["рент", "rent", "комунальні", "utilities", "комуналка"], .housing),
      (["таксі", "taxi", "uber", "bolt", "унік"], .transportation),
      (["monobank", "поповнення", "переказ"], .other),
    ]

    for (words, category) in keywords {
      for word in words {
        if merchantLower.contains(word) {
          return [category]
        }
      }
    }

    return [.other]
  }

  /// Check if transaction is a duplicate of existing expense
  func isDuplicate(_ transaction: CSVTransaction, existingExpenses: [Expense]) -> Bool {
    let normalizedMerchant = normalizeMerchant(transaction.merchant)
    let transactionAmount = abs(transaction.amount)

    for expense in existingExpenses {
      // Check same day
      guard Calendar.current.isDate(transaction.date, inSameDayAs: expense.date) else {
        continue
      }

      // Check amount (within 10% tolerance for variable amounts)
      let tolerance = transactionAmount * 0.10
      guard abs(transactionAmount - expense.amount) <= tolerance else {
        continue
      }

      // Check merchant (fuzzy match)
      let expenseMerchant = normalizeMerchant(expense.title)
      guard normalizedMerchant == expenseMerchant else {
        continue
      }

      return true
    }

    return false
  }
}

final class CategorizationRuleService {
  static let shared = CategorizationRuleService()

  private init() {}

  func matchingRule(
    context: ModelContext,
    merchant: String?,
    mcc: Int?,
    paymentMethod: PaymentMethod?
  ) -> CategorizationRule? {
    guard
      let rules = try? context.fetch(FetchDescriptor<CategorizationRule>()),
      !rules.isEmpty
    else { return nil }

    let normalizedMerchant =
      merchant?
      .lowercased()
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    let enabled = rules
      .filter { $0.isEnabled }
      .sorted { lhs, rhs in
        if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
        return lhs.createdAt < rhs.createdAt
      }

    for rule in enabled {
      if let targetPaymentMethod = rule.targetPaymentMethod,
        !targetPaymentMethod.isEmpty
      {
        guard paymentMethod?.rawValue == targetPaymentMethod else { continue }
      }

      let type = CategorizationPatternType(rawValue: rule.patternType) ?? .contains
      switch type {
      case .contains:
        if normalizedMerchant.contains(rule.patternValue.lowercased()) {
          return rule
        }
      case .regex:
        if normalizedMerchant.range(of: rule.patternValue, options: .regularExpression) != nil {
          return rule
        }
      case .mcc:
        if let mcc, Int(rule.patternValue) == mcc {
          return rule
        }
      }
    }

    return nil
  }

  func resolveCategory(
    context: ModelContext,
    merchant: String?,
    mcc: Int?,
    paymentMethod: PaymentMethod?,
    fallback: ExpenseCategory
  ) -> (category: ExpenseCategory, ruleId: UUID?) {
    guard
      let rule = matchingRule(
        context: context,
        merchant: merchant,
        mcc: mcc,
        paymentMethod: paymentMethod
      ),
      rule.autoApply
    else {
      return (fallback, nil)
    }

    let category = ExpenseCategory(rawValue: rule.targetCategory) ?? fallback
    return (category, rule.id)
  }
}

// MARK: - Phase Expansion Service Interfaces (Local-First)

struct CashflowAlert: Identifiable, Codable {
  enum Severity: String, Codable {
    case info
    case warning
    case critical
  }

  let id: UUID
  let title: String
  let message: String
  let severity: Severity

  init(
    id: UUID = UUID(),
    title: String,
    message: String,
    severity: Severity
  ) {
    self.id = id
    self.title = title
    self.message = message
    self.severity = severity
  }
}

protocol CashflowAlertServiceProtocol {
  func evaluateAlerts(context: ModelContext, asOf date: Date) throws -> [CashflowAlert]
}

final class CashflowAlertService: CashflowAlertServiceProtocol {
  static let shared = CashflowAlertService()
  private init() {}

  func evaluateAlerts(context: ModelContext, asOf date: Date) throws -> [CashflowAlert] {
    _ = try context.fetch(FetchDescriptor<MonobankAccount>())
    _ = try context.fetch(FetchDescriptor<RecurringExpenseTemplate>())
    _ = try context.fetch(FetchDescriptor<BillItem>())
    _ = date
    return []
  }
}

protocol SubscriptionServiceProtocol {
  func detectCandidates(context: ModelContext) throws -> [SubscriptionItem]
  func save(_ item: SubscriptionItem, context: ModelContext) throws
}

final class SubscriptionService: SubscriptionServiceProtocol {
  static let shared = SubscriptionService()
  private init() {}

  func detectCandidates(context: ModelContext) throws -> [SubscriptionItem] {
    try context.fetch(FetchDescriptor<SubscriptionItem>())
  }

  func save(_ item: SubscriptionItem, context: ModelContext) throws {
    item.updatedAt = Date()
    context.insert(item)
    try context.save()
  }
}

protocol BillServiceProtocol {
  func dueBills(context: ModelContext, within days: Int) throws -> [BillItem]
  func markPaid(_ bill: BillItem, context: ModelContext) throws
}

final class BillService: BillServiceProtocol {
  static let shared = BillService()
  private init() {}

  func dueBills(context: ModelContext, within days: Int) throws -> [BillItem] {
    let now = Date()
    let end = Calendar.current.date(byAdding: .day, value: max(0, days), to: now) ?? now
    return try context.fetch(FetchDescriptor<BillItem>())
      .filter { $0.isPaid == false && $0.dueDate >= now && $0.dueDate <= end }
      .sorted { $0.dueDate < $1.dueDate }
  }

  func markPaid(_ bill: BillItem, context: ModelContext) throws {
    bill.isPaid = true
    bill.updatedAt = Date()
    try context.save()
  }
}

protocol SavingsServiceProtocol {
  func activeGoals(context: ModelContext) throws -> [SavingsGoal]
  func contribute(goal: SavingsGoal, amountUAH: Double, context: ModelContext) throws
}

final class SavingsService: SavingsServiceProtocol {
  static let shared = SavingsService()
  private init() {}

  func activeGoals(context: ModelContext) throws -> [SavingsGoal] {
    try context.fetch(FetchDescriptor<SavingsGoal>())
      .filter { !$0.isArchived }
      .sorted { $0.priority < $1.priority }
  }

  func contribute(goal: SavingsGoal, amountUAH: Double, context: ModelContext) throws {
    goal.currentAmountUAH += max(0, amountUAH)
    goal.updatedAt = Date()
    try context.save()
  }
}

protocol ReceiptOCRServiceProtocol {
  func processReceipt(
    imageData: Data,
    expenseId: UUID?,
    context: ModelContext
  ) throws -> ReceiptAttachment
}

final class ReceiptOCRService: ReceiptOCRServiceProtocol {
  static let shared = ReceiptOCRService()
  private init() {}

  func processReceipt(
    imageData: Data,
    expenseId: UUID?,
    context: ModelContext
  ) throws -> ReceiptAttachment {
    let attachment = ReceiptAttachment(
      expenseId: expenseId,
      localFilePath: "",
      ocrRawText: "",
      confidence: imageData.isEmpty ? 0 : 0.1
    )
    context.insert(attachment)
    try context.save()
    return attachment
  }
}

protocol BudgetSharingServiceProtocol {
  func exportEncryptedPackage(context: ModelContext, passphrase: String) throws -> Data
  func importEncryptedPackage(_ data: Data, context: ModelContext, passphrase: String) throws
}

final class BudgetSharingService: BudgetSharingServiceProtocol {
  static let shared = BudgetSharingService()
  private init() {}

  func exportEncryptedPackage(context: ModelContext, passphrase: String) throws -> Data {
    _ = passphrase
    let limits = try context.fetch(FetchDescriptor<BudgetLimit>())
    let payload = limits.map { $0.id.uuidString }.joined(separator: ",")
    return Data(payload.utf8)
  }

  func importEncryptedPackage(_ data: Data, context: ModelContext, passphrase: String) throws {
    _ = data
    _ = passphrase
    try context.save()
  }
}

protocol BackupRestoreServiceProtocol {
  func createBackup(context: ModelContext, passphrase: String) throws -> Data
  func restoreBackup(_ backupData: Data, context: ModelContext, passphrase: String) throws
}

final class BackupRestoreService: BackupRestoreServiceProtocol {
  static let shared = BackupRestoreService()
  private init() {}

  func createBackup(context: ModelContext, passphrase: String) throws -> Data {
    _ = passphrase
    let expenses = try context.fetch(FetchDescriptor<Expense>())
    let payload = expenses.map { $0.id.uuidString }.joined(separator: "|")
    return Data(payload.utf8)
  }

  func restoreBackup(_ backupData: Data, context: ModelContext, passphrase: String) throws {
    _ = backupData
    _ = passphrase
    try context.save()
  }
}

protocol NetWorthServiceProtocol {
  func totalNetWorthUAH(context: ModelContext) throws -> Double
}

final class NetWorthService: NetWorthServiceProtocol {
  static let shared = NetWorthService()
  private init() {}

  func totalNetWorthUAH(context: ModelContext) throws -> Double {
    let accounts = try context.fetch(FetchDescriptor<NetWorthAccount>())
      .filter { $0.includeInTotal }
    return accounts.reduce(0) { partialResult, account in
      let type = NetWorthAccountType(rawValue: account.type) ?? .asset
      return type == .asset
        ? partialResult + account.balanceUAH
        : partialResult - account.balanceUAH
    }
  }
}

protocol TripBudgetServiceProtocol {
  func activeTrip(context: ModelContext) throws -> TripBudget?
}

final class TripBudgetService: TripBudgetServiceProtocol {
  static let shared = TripBudgetService()
  private init() {}

  func activeTrip(context: ModelContext) throws -> TripBudget? {
    let now = Date()
    return try context.fetch(FetchDescriptor<TripBudget>())
      .first(where: { $0.isActive && $0.startDate <= now && $0.endDate >= now })
  }
}

protocol WeeklyReviewServiceProtocol {
  func generateWeeklyReview(context: ModelContext, weekStart: Date, weekEnd: Date) throws
    -> WeeklyReviewSnapshot
}

final class WeeklyReviewService: WeeklyReviewServiceProtocol {
  static let shared = WeeklyReviewService()
  private init() {}

  func generateWeeklyReview(context: ModelContext, weekStart: Date, weekEnd: Date) throws
    -> WeeklyReviewSnapshot
  {
    let summary = "{\"weekStart\":\"\(weekStart.timeIntervalSince1970)\",\"weekEnd\":\"\(weekEnd.timeIntervalSince1970)\"}"
    let snapshot = WeeklyReviewSnapshot(weekStart: weekStart, weekEnd: weekEnd, summaryJSON: summary)
    context.insert(snapshot)
    try context.save()
    return snapshot
  }
}

protocol WhatIfPlannerServiceProtocol {
  func createScenario(
    title: String,
    deltaExpensesUAH: Double,
    deltaIncomeUAH: Double,
    period: ScenarioPeriod,
    context: ModelContext
  ) throws -> WhatIfScenario
}

final class WhatIfPlannerService: WhatIfPlannerServiceProtocol {
  static let shared = WhatIfPlannerService()
  private init() {}

  func createScenario(
    title: String,
    deltaExpensesUAH: Double,
    deltaIncomeUAH: Double,
    period: ScenarioPeriod,
    context: ModelContext
  ) throws -> WhatIfScenario {
    let scenario = WhatIfScenario(
      title: title,
      deltaExpensesUAH: deltaExpensesUAH,
      deltaIncomeUAH: deltaIncomeUAH,
      period: period
    )
    context.insert(scenario)
    try context.save()
    return scenario
  }
}

protocol SmartPriorityServiceProtocol {
  func score(todo: TodoItem, linkedExpense: Expense?) -> Double
}

final class SmartPriorityService: SmartPriorityServiceProtocol {
  static let shared = SmartPriorityService()
  private init() {}

  func score(todo: TodoItem, linkedExpense: Expense?) -> Double {
    let dueDateWeight: Double
    if let dueDate = todo.dueDate {
      let hoursRemaining = max(1, dueDate.timeIntervalSinceNow / 3600.0)
      dueDateWeight = 1.0 / hoursRemaining
    } else {
      dueDateWeight = 0
    }

    let financialWeight = linkedExpense?.amount ?? 0
    return dueDateWeight * 1000 + financialWeight
  }
}

protocol CategorizationRuleServiceProtocol {
  func matchingRule(
    context: ModelContext,
    merchant: String?,
    mcc: Int?,
    paymentMethod: PaymentMethod?
  ) -> CategorizationRule?
  func resolveCategory(
    context: ModelContext,
    merchant: String?,
    mcc: Int?,
    paymentMethod: PaymentMethod?,
    fallback: ExpenseCategory
  ) -> (category: ExpenseCategory, ruleId: UUID?)
}

extension CategorizationRuleService: CategorizationRuleServiceProtocol {}

// MARK: - Widget Quick Action Interfaces

enum CombinedWidgetQuickAction: String, Codable, CaseIterable {
  case quickAddExpense
  case openPinnedBankCard
  case markTodoDone
}

protocol CombinedWidgetActionServiceProtocol {
  func availableActions() -> [CombinedWidgetQuickAction]
  func makeDeepLink(for action: CombinedWidgetQuickAction, payload: String?) -> URL?
}

final class CombinedWidgetActionService: CombinedWidgetActionServiceProtocol {
  static let shared = CombinedWidgetActionService()
  private init() {}

  func availableActions() -> [CombinedWidgetQuickAction] {
    CombinedWidgetQuickAction.allCases
  }

  func makeDeepLink(for action: CombinedWidgetQuickAction, payload: String?) -> URL? {
    var components = URLComponents()
    components.scheme = Constants.Widget.quickActionScheme
    components.host = Constants.Widget.quickActionHost
    components.path = "/\(action.rawValue)"
    if let payload, !payload.isEmpty {
      components.queryItems = [URLQueryItem(name: "id", value: payload)]
    }
    return components.url
  }
}
