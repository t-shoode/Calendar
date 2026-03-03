import Foundation
import CryptoKit
import Compression
import Vision
import SwiftData
#if os(iOS)
  import UIKit
#endif

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
    let accounts = try context.fetch(FetchDescriptor<MonobankAccount>())
    let templates = try context.fetch(FetchDescriptor<RecurringExpenseTemplate>())
    let bills = try context.fetch(FetchDescriptor<BillItem>())
    let expenses = try context.fetch(FetchDescriptor<Expense>())

    let selected = accounts.filter { $0.isSelected }
    let availableAccounts = selected.isEmpty ? accounts : selected
    let currentBalanceUAH = availableAccounts.reduce(0.0) { total, account in
      let currency = MonobankProjectionMapper.currency(fromMonobankCode: account.currencyCode)
      let major = Double(account.balanceMinor) / 100.0
      return total + currency.convertToUAH(major)
    }

    let windowDays = 14
    let forecast = ForecastService.shared.forecastDays(
      startDate: date,
      days: windowDays,
      expenses: expenses,
      templates: templates,
      scenario: .baseline
    )

    var runningBalance = currentBalanceUAH
    var alertList: [CashflowAlert] = []

    if currentBalanceUAH <= 0 {
      alertList.append(
        CashflowAlert(
          title: "Balance is negative",
          message: "Available balance is below zero today.",
          severity: .critical
        )
      )
    }

    for day in forecast.sorted(by: { $0.date < $1.date }) {
      runningBalance += day.netUAH
      if runningBalance < 0 {
        alertList.append(
          CashflowAlert(
            title: "Negative cashflow expected",
            message: "Projected balance becomes negative on \(day.date.formatted(date: .abbreviated, time: .omitted)).",
            severity: .critical
          )
        )
        break
      }
      if runningBalance < 5_000 {
        alertList.append(
          CashflowAlert(
            title: "Low balance warning",
            message: "Projected balance drops below ₴5,000 on \(day.date.formatted(date: .abbreviated, time: .omitted)).",
            severity: .warning
          )
        )
        break
      }
    }

    let dueSoonBills = bills
      .filter { !$0.isPaid && $0.dueDate >= date && $0.dueDate <= Calendar.current.date(byAdding: .day, value: 7, to: date) ?? date }
      .sorted { $0.dueDate < $1.dueDate }
    if let nextBill = dueSoonBills.first {
      alertList.append(
        CashflowAlert(
          title: "Upcoming bill",
          message: "\(nextBill.name) is due on \(nextBill.dueDate.formatted(date: .abbreviated, time: .omitted)).",
          severity: .info
        )
      )
    }

    return alertList
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
    let existing = try context.fetch(FetchDescriptor<SubscriptionItem>())
    let templates = try context.fetch(FetchDescriptor<RecurringExpenseTemplate>())
      .filter { $0.isActive && !$0.isIncome }
    let expenses = try context.fetch(FetchDescriptor<Expense>())
      .filter { !$0.isIncome }

    var candidates = existing
    let normalizedExisting = Set(existing.map { PatternDetectionService().normalizeMerchant($0.merchant) })

    for template in templates {
      let normalizedMerchant = PatternDetectionService().normalizeMerchant(template.merchant)
      let isSubscriptionCategory = template.allCategories.contains(.subscriptions)
      let looksLikeSubscription = PatternDetectionService().normalizeMerchant(template.merchant).contains("sub")
        || PatternDetectionService().normalizeMerchant(template.merchant).contains("netflix")
        || PatternDetectionService().normalizeMerchant(template.merchant).contains("spotify")

      guard isSubscriptionCategory || looksLikeSubscription else { continue }
      guard !normalizedExisting.contains(normalizedMerchant) else { continue }

      let item = SubscriptionItem(
        name: template.title,
        merchant: template.merchant,
        amount: template.amount,
        currency: template.currencyEnum,
        billingCycle: BillingCycle(rawValue: template.frequency.rawValue) ?? .monthly,
        nextRenewalDate: template.nextDueDate(from: Date()) ?? Date(),
        leadTimeDays: 3,
        lastChargeDate: expenses
          .filter { PatternDetectionService().normalizeMerchant($0.merchant ?? $0.title) == normalizedMerchant }
          .sorted(by: { $0.date > $1.date })
          .first?.date,
        nextChargeAmount: template.amount,
        isActive: true,
        sourceTemplateId: template.id
      )
      candidates.append(item)
    }

    return candidates.sorted { $0.nextRenewalDate < $1.nextRenewalDate }
  }

  func save(_ item: SubscriptionItem, context: ModelContext) throws {
    item.updatedAt = Date()
    if try context.fetch(FetchDescriptor<SubscriptionItem>()).contains(where: { $0.id == item.id }) == false {
      context.insert(item)
    }
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
    bill.lastPaidAt = Date()
    let currency = Currency(rawValue: bill.currency) ?? .uah
    bill.lastPaidAmountUAH = currency.convertToUAH(bill.amount)
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
      .sorted { lhs, rhs in
        let left = SavingsPriority(rawValue: lhs.priority) ?? .medium
        let right = SavingsPriority(rawValue: rhs.priority) ?? .medium
        let rank: [SavingsPriority: Int] = [.high: 0, .medium: 1, .low: 2]
        if rank[left, default: 1] != rank[right, default: 1] {
          return rank[left, default: 1] < rank[right, default: 1]
        }
        return lhs.createdAt < rhs.createdAt
      }
  }

  func contribute(goal: SavingsGoal, amountUAH: Double, context: ModelContext) throws {
    let clamped = max(0, amountUAH)
    goal.currentAmountUAH += clamped
    let contribution = SavingsContribution(goalId: goal.id, amountUAH: clamped)
    context.insert(contribution)
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
    let recognizedText = try recognizeText(from: imageData)
    let parsed = parseReceiptText(recognizedText)
    let digest = SHA256.hash(data: imageData).map { String(format: "%02x", $0) }.joined()

    let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory())
    let fileURL = caches.appendingPathComponent("receipt-\(UUID().uuidString).jpg")
    try imageData.write(to: fileURL, options: [.atomic])

    let attachment = ReceiptAttachment(
      expenseId: expenseId,
      localFilePath: fileURL.path,
      ocrRawText: recognizedText,
      merchantGuess: parsed.merchant,
      amountGuess: parsed.amount,
      dateGuess: parsed.date,
      confidence: parsed.confidence,
      fileName: fileURL.lastPathComponent,
      mimeType: "image/jpeg",
      fileSize: Int64(imageData.count),
      sha256: digest,
      ocrStatus: "processed",
      ocrLanguage: "uk+en",
      ocrProcessedAt: Date()
    )
    context.insert(attachment)
    try context.save()
    return attachment
  }

  private func recognizeText(from imageData: Data) throws -> String {
    guard let image = UIImage(data: imageData)?.cgImage else {
      return ""
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["uk-UA", "en-US"]

    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try handler.perform([request])

    let observations = request.results ?? []
    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
    return lines.joined(separator: "\n")
  }

  private func parseReceiptText(_ text: String) -> (merchant: String?, amount: Double?, date: Date?, confidence: Double) {
    let lines = text
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    let merchant = lines.first

    var amountGuess: Double?
    let amountPatterns = [
      #"(?i)(?:total|sum|сума|разом)\s*[:\-]?\s*([0-9]+(?:[.,][0-9]{1,2})?)"#,
      #"([0-9]+(?:[.,][0-9]{1,2})?)\s*(?:грн|uah|₴)"#,
    ]
    for pattern in amountPatterns {
      if let regex = try? NSRegularExpression(pattern: pattern),
        let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
        match.numberOfRanges >= 2,
        let range = Range(match.range(at: 1), in: text)
      {
        amountGuess = Double(text[range].replacingOccurrences(of: ",", with: "."))
        break
      }
    }

    var dateGuess: Date?
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "uk_UA")
    for format in ["dd.MM.yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "dd.MM.yyyy HH:mm:ss"] {
      formatter.dateFormat = format
      if let match = lines.first(where: { formatter.date(from: $0) != nil }),
        let parsed = formatter.date(from: match)
      {
        dateGuess = parsed
        break
      }
    }

    var confidence = 0.3
    if merchant != nil { confidence += 0.2 }
    if amountGuess != nil { confidence += 0.3 }
    if dateGuess != nil { confidence += 0.2 }

    return (merchant, amountGuess, dateGuess, min(confidence, 0.95))
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
    let limits = try context.fetch(FetchDescriptor<BudgetLimit>())
    let payload = limits.map { BudgetLimitDTO(limit: $0) }
    let encoded = try JSONEncoder().encode(payload)
    let compressed = try CompressionCodec.compress(encoded)
    return try BackupCrypto.seal(payload: compressed, passphrase: passphrase)
  }

  func importEncryptedPackage(_ data: Data, context: ModelContext, passphrase: String) throws {
    let decrypted = try BackupCrypto.open(package: data, passphrase: passphrase)
    let decoded = try JSONDecoder().decode([BudgetLimitDTO].self, from: CompressionCodec.decompress(decrypted))
    let existing = Set(try context.fetch(FetchDescriptor<BudgetLimit>()).map(\.id))

    for item in decoded where !existing.contains(item.id) {
      let limit = item.toModel()
      context.insert(limit)
    }
    try context.save()
  }
}

private struct BudgetLimitDTO: Codable, BackupDTO {
  typealias Model = BudgetLimit
  let id: UUID
  let categoryRawValue: String
  let amountUAH: Double
  let period: String
  let rolloverEnabled: Bool
  let rolloverAmountUAH: Double
  let dailyBudgetEnabled: Bool
  let createdAt: Date
  let updatedAt: Date

  init(limit: BudgetLimit) {
    id = limit.id
    categoryRawValue = limit.categoryRawValue
    amountUAH = limit.amountUAH
    period = limit.period
    rolloverEnabled = limit.rolloverEnabled
    rolloverAmountUAH = limit.rolloverAmountUAH
    dailyBudgetEnabled = limit.dailyBudgetEnabled
    createdAt = limit.createdAt
    updatedAt = limit.updatedAt
  }

  func toModel() -> BudgetLimit {
    let limit = BudgetLimit(
      category: ExpenseCategory(rawValue: categoryRawValue) ?? .other,
      amountUAH: amountUAH,
      period: BudgetPeriod(rawValue: period) ?? .monthly,
      rolloverEnabled: rolloverEnabled,
      rolloverAmountUAH: rolloverAmountUAH,
      dailyBudgetEnabled: dailyBudgetEnabled
    )
    limit.id = id
    limit.createdAt = createdAt
    limit.updatedAt = updatedAt
    return limit
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
    let payload = try BackupPayload(context: context)
    let encoded = try JSONEncoder().encode(payload)
    let compressed = try CompressionCodec.compress(encoded)
    let checksum = BackupCrypto.checksumHex(compressed)

    let manifest = BackupManifest(
      schemaVersion: Constants.Backup.schemaVersion,
      exportDate: Date(),
      modelCounts: payload.modelCounts,
      checksum: checksum
    )

    let encryptedPayload = try BackupCrypto.seal(payload: compressed, passphrase: passphrase)
    let package = BackupPackage(manifest: manifest, encryptedPayload: encryptedPayload)
    return try JSONEncoder().encode(package)
  }

  func restoreBackup(_ backupData: Data, context: ModelContext, passphrase: String) throws {
    let package = try JSONDecoder().decode(BackupPackage.self, from: backupData)
    let decrypted = try BackupCrypto.open(package: package.encryptedPayload, passphrase: passphrase)
    let checksum = BackupCrypto.checksumHex(decrypted)
    guard checksum == package.manifest.checksum else {
      throw BackupRestoreError.invalidChecksum
    }

    let decoded = try JSONDecoder().decode(BackupPayload.self, from: CompressionCodec.decompress(decrypted))
    try decoded.restore(into: context)
    try context.save()
  }
}

struct BackupManifest: Codable {
  let schemaVersion: Int
  let exportDate: Date
  let modelCounts: [String: Int]
  let checksum: String
}

private struct BackupPackage: Codable {
  let manifest: BackupManifest
  let encryptedPayload: Data
}

private enum BackupRestoreError: LocalizedError {
  case invalidChecksum

  var errorDescription: String? {
    switch self {
    case .invalidChecksum:
      return "Backup integrity check failed."
    }
  }
}

private struct BackupPayload: Codable {
  var expenses: [ExpenseDTO]
  var templates: [RecurringTemplateDTO]
  var events: [EventDTO]
  var todoCategories: [TodoCategoryDTO]
  var todos: [TodoDTO]
  var budgetLimits: [BudgetLimitDTO]
  var fxRates: [FXRateDTO]
  var subscriptions: [SubscriptionDTO]
  var bills: [BillDTO]
  var savingsGoals: [SavingsGoalDTO]
  var netWorthAccounts: [NetWorthAccountDTO]
  var trips: [TripBudgetDTO]
  var weeklyReviews: [WeeklyReviewDTO]
  var whatIfScenarios: [WhatIfScenarioDTO]
  var csvMappings: [CSVImportMappingDTO]
  var notificationPreferences: [NotificationPreferencesDTO]
  var onboardingStates: [OnboardingStateDTO]

  var modelCounts: [String: Int] {
    [
      "expenses": expenses.count,
      "templates": templates.count,
      "events": events.count,
      "todoCategories": todoCategories.count,
      "todos": todos.count,
      "budgetLimits": budgetLimits.count,
      "fxRates": fxRates.count,
      "subscriptions": subscriptions.count,
      "bills": bills.count,
      "savingsGoals": savingsGoals.count,
      "netWorthAccounts": netWorthAccounts.count,
      "trips": trips.count,
      "weeklyReviews": weeklyReviews.count,
      "whatIfScenarios": whatIfScenarios.count,
      "csvMappings": csvMappings.count,
      "notificationPreferences": notificationPreferences.count,
      "onboardingStates": onboardingStates.count,
    ]
  }

  init(context: ModelContext) throws {
    expenses = try context.fetch(FetchDescriptor<Expense>()).map(ExpenseDTO.init)
    templates = try context.fetch(FetchDescriptor<RecurringExpenseTemplate>()).map(RecurringTemplateDTO.init)
    events = try context.fetch(FetchDescriptor<Event>()).map(EventDTO.init)
    todoCategories = try context.fetch(FetchDescriptor<TodoCategory>()).map(TodoCategoryDTO.init)
    todos = try context.fetch(FetchDescriptor<TodoItem>()).map(TodoDTO.init)
    budgetLimits = try context.fetch(FetchDescriptor<BudgetLimit>()).map(BudgetLimitDTO.init)
    fxRates = try context.fetch(FetchDescriptor<FXRate>()).map(FXRateDTO.init)
    subscriptions = try context.fetch(FetchDescriptor<SubscriptionItem>()).map(SubscriptionDTO.init)
    bills = try context.fetch(FetchDescriptor<BillItem>()).map(BillDTO.init)
    savingsGoals = try context.fetch(FetchDescriptor<SavingsGoal>()).map(SavingsGoalDTO.init)
    netWorthAccounts = try context.fetch(FetchDescriptor<NetWorthAccount>()).map(NetWorthAccountDTO.init)
    trips = try context.fetch(FetchDescriptor<TripBudget>()).map(TripBudgetDTO.init)
    weeklyReviews = try context.fetch(FetchDescriptor<WeeklyReviewSnapshot>()).map(WeeklyReviewDTO.init)
    whatIfScenarios = try context.fetch(FetchDescriptor<WhatIfScenario>()).map(WhatIfScenarioDTO.init)
    csvMappings = try context.fetch(FetchDescriptor<CSVImportMapping>()).map(CSVImportMappingDTO.init)
    notificationPreferences = try context.fetch(FetchDescriptor<NotificationPreferences>()).map(NotificationPreferencesDTO.init)
    onboardingStates = try context.fetch(FetchDescriptor<OnboardingState>()).map(OnboardingStateDTO.init)
  }

  func restore(into context: ModelContext) throws {
    let existingCategoryIDs = Set(try context.fetch(FetchDescriptor<TodoCategory>()).map(\.id))
    var categoryMap: [UUID: TodoCategory] = [:]
    for dto in todoCategories where !existingCategoryIDs.contains(dto.id) {
      let model = dto.toModel()
      context.insert(model)
      categoryMap[dto.id] = model
    }

    let allCategories = try context.fetch(FetchDescriptor<TodoCategory>())
    for category in allCategories {
      categoryMap[category.id] = category
    }
    for dto in todoCategories {
      guard let model = categoryMap[dto.id] else { continue }
      if let parentId = dto.parentId {
        model.parent = categoryMap[parentId]
      }
    }

    try restoreCollection(expenses, context: context) { dto in dto.toModel() }
    try restoreCollection(templates, context: context) { dto in dto.toModel() }
    try restoreCollection(events, context: context) { dto in dto.toModel() }
    try restoreCollection(budgetLimits, context: context) { dto in dto.toModel() }
    try restoreCollection(fxRates, context: context) { dto in dto.toModel() }
    try restoreCollection(subscriptions, context: context) { dto in dto.toModel() }
    try restoreCollection(bills, context: context) { dto in dto.toModel() }
    try restoreCollection(savingsGoals, context: context) { dto in dto.toModel() }
    try restoreCollection(netWorthAccounts, context: context) { dto in dto.toModel() }
    try restoreCollection(trips, context: context) { dto in dto.toModel() }
    try restoreCollection(weeklyReviews, context: context) { dto in dto.toModel() }
    try restoreCollection(whatIfScenarios, context: context) { dto in dto.toModel() }
    try restoreCollection(csvMappings, context: context) { dto in dto.toModel() }
    try restoreCollection(notificationPreferences, context: context) { dto in dto.toModel() }
    try restoreCollection(onboardingStates, context: context) { dto in dto.toModel() }

    let existingTodoIDs = Set(try context.fetch(FetchDescriptor<TodoItem>()).map(\.id))
    var todoMap: [UUID: TodoItem] = [:]
    for dto in todos where !existingTodoIDs.contains(dto.id) {
      let model = dto.toModel(categories: categoryMap)
      context.insert(model)
      todoMap[dto.id] = model
    }
    let allTodos = try context.fetch(FetchDescriptor<TodoItem>())
    for todo in allTodos {
      todoMap[todo.id] = todo
    }
    for dto in todos {
      guard let model = todoMap[dto.id] else { continue }
      if let parentId = dto.parentTodoId {
        model.parentTodo = todoMap[parentId]
      }
    }
  }

  private func restoreCollection<T: BackupDTO>(
    _ dtos: [T],
    context: ModelContext,
    build: (T) -> T.Model
  ) throws {
    let ids = Set(try context.fetch(FetchDescriptor<T.Model>()).map(\.id))
    for dto in dtos where !ids.contains(dto.id) {
      context.insert(build(dto))
    }
  }
}

private protocol BackupDTO {
  associatedtype Model: PersistentModelWithID
  var id: UUID { get }
}

private protocol PersistentModelWithID: PersistentModel {
  var id: UUID { get set }
}

extension Expense: PersistentModelWithID {}
extension RecurringExpenseTemplate: PersistentModelWithID {}
extension Event: PersistentModelWithID {}
extension TodoCategory: PersistentModelWithID {}
extension TodoItem: PersistentModelWithID {}
extension BudgetLimit: PersistentModelWithID {}
extension FXRate: PersistentModelWithID {}
extension SubscriptionItem: PersistentModelWithID {}
extension BillItem: PersistentModelWithID {}
extension SavingsGoal: PersistentModelWithID {}
extension NetWorthAccount: PersistentModelWithID {}
extension TripBudget: PersistentModelWithID {}
extension WeeklyReviewSnapshot: PersistentModelWithID {}
extension WhatIfScenario: PersistentModelWithID {}
extension CSVImportMapping: PersistentModelWithID {}
extension NotificationPreferences: PersistentModelWithID {}
extension OnboardingState: PersistentModelWithID {}

private struct ExpenseDTO: Codable, BackupDTO {
  typealias Model = Expense
  let id: UUID
  let title: String
  let amount: Double
  let date: Date
  let categories: [String]
  let paymentMethod: String
  let currency: String
  let merchant: String?
  let notes: String?
  let createdAt: Date
  let templateId: UUID?
  let isGenerated: Bool
  let isIncome: Bool

  init(_ expense: Expense) {
    id = expense.id
    title = expense.title
    amount = expense.amount
    date = expense.date
    categories = expense.categories
    paymentMethod = expense.paymentMethod
    currency = expense.currency
    merchant = expense.merchant
    notes = expense.notes
    createdAt = expense.createdAt
    templateId = expense.templateId
    isGenerated = expense.isGenerated
    isIncome = expense.isIncome
  }

  func toModel() -> Expense {
    let model = Expense(
      title: title,
      amount: amount,
      date: date,
      categories: categories.compactMap { ExpenseCategory(rawValue: $0) },
      paymentMethod: PaymentMethod(rawValue: paymentMethod) ?? .card,
      currency: Currency(rawValue: currency) ?? .uah,
      merchant: merchant,
      notes: notes,
      templateId: templateId,
      isGenerated: isGenerated,
      isIncome: isIncome
    )
    model.id = id
    model.createdAt = createdAt
    return model
  }
}

private struct RecurringTemplateDTO: Codable, BackupDTO {
  typealias Model = RecurringExpenseTemplate
  let id: UUID
  let title: String
  let amount: Double
  let amountTolerance: Double
  let categories: [String]
  let paymentMethod: String
  let currency: String
  let merchant: String
  let notes: String?
  let frequency: String
  let startDate: Date
  let lastGeneratedDate: Date?
  let isActive: Bool
  let isPaused: Bool
  let pausedUntil: Date?
  let occurrenceCount: Int
  let createdAt: Date
  let updatedAt: Date
  let isIncome: Bool

  init(_ template: RecurringExpenseTemplate) {
    id = template.id
    title = template.title
    amount = template.amount
    amountTolerance = template.amountTolerance
    categories = template.categories
    paymentMethod = template.paymentMethod
    currency = template.currency
    merchant = template.merchant
    notes = template.notes
    frequency = template.frequency.rawValue
    startDate = template.startDate
    lastGeneratedDate = template.lastGeneratedDate
    isActive = template.isActive
    isPaused = template.isPaused
    pausedUntil = template.pausedUntil
    occurrenceCount = template.occurrenceCount
    createdAt = template.createdAt
    updatedAt = template.updatedAt
    isIncome = template.isIncome
  }

  func toModel() -> RecurringExpenseTemplate {
    let model = RecurringExpenseTemplate(
      title: title,
      amount: amount,
      amountTolerance: amountTolerance,
      categories: categories.compactMap { ExpenseCategory(rawValue: $0) },
      paymentMethod: PaymentMethod(rawValue: paymentMethod) ?? .card,
      currency: Currency(rawValue: currency) ?? .uah,
      merchant: merchant,
      notes: notes,
      frequency: ExpenseFrequency(rawValue: frequency) ?? .monthly,
      startDate: startDate,
      occurrenceCount: occurrenceCount,
      isIncome: isIncome
    )
    model.id = id
    model.lastGeneratedDate = lastGeneratedDate
    model.isActive = isActive
    model.isPaused = isPaused
    model.pausedUntil = pausedUntil
    model.createdAt = createdAt
    model.updatedAt = updatedAt
    return model
  }
}

private struct EventDTO: Codable, BackupDTO {
  typealias Model = Event
  let id: UUID
  let date: Date
  let title: String
  let notes: String?
  let color: String
  let createdAt: Date
  let reminderInterval: TimeInterval?
  let recurrenceType: String?
  let recurrenceInterval: Int?
  let recurrenceEndDate: Date?
  let isHoliday: Bool
  let holidayId: String?

  init(_ event: Event) {
    id = event.id
    date = event.date
    title = event.title
    notes = event.notes
    color = event.color
    createdAt = event.createdAt
    reminderInterval = event.reminderInterval
    recurrenceType = event.recurrenceType
    recurrenceInterval = event.recurrenceInterval
    recurrenceEndDate = event.recurrenceEndDate
    isHoliday = event.isHoliday
    holidayId = event.holidayId
  }

  func toModel() -> Event {
    let model = Event(
      date: date,
      title: title,
      notes: notes,
      color: color,
      reminderInterval: reminderInterval,
      recurrenceType: recurrenceType.flatMap { RecurrenceType(rawValue: $0) },
      recurrenceInterval: recurrenceInterval ?? 1,
      recurrenceEndDate: recurrenceEndDate,
      isHoliday: isHoliday,
      holidayId: holidayId
    )
    model.id = id
    model.createdAt = createdAt
    return model
  }
}

private struct TodoCategoryDTO: Codable, BackupDTO {
  typealias Model = TodoCategory
  let id: UUID
  let name: String
  let color: String
  let createdAt: Date
  let isPinned: Bool
  let sortOrder: Int
  let parentId: UUID?

  init(_ category: TodoCategory) {
    id = category.id
    name = category.name
    color = category.color
    createdAt = category.createdAt
    isPinned = category.isPinned
    sortOrder = category.sortOrder
    parentId = category.parent?.id
  }

  func toModel() -> TodoCategory {
    let model = TodoCategory(name: name, color: color, isPinned: isPinned, sortOrder: sortOrder)
    model.id = id
    model.createdAt = createdAt
    return model
  }
}

private struct TodoDTO: Codable, BackupDTO {
  typealias Model = TodoItem
  let id: UUID
  let title: String
  let notes: String?
  let isCompleted: Bool
  let completedAt: Date?
  let priority: String
  let dueDate: Date?
  let reminderInterval: TimeInterval?
  let reminderRepeatInterval: TimeInterval?
  let reminderRepeatCount: Int?
  let createdAt: Date
  let sortOrder: Int
  let isPinned: Bool
  let categoryId: UUID?
  let parentTodoId: UUID?
  let recurrenceType: String?
  let recurrenceInterval: Int
  let recurrenceDaysOfWeek: [Int]?
  let recurrenceEndDate: Date?
  let linkedExpenseId: UUID?
  let linkedBillId: UUID?
  let smartPriorityOverride: Double?

  init(_ todo: TodoItem) {
    id = todo.id
    title = todo.title
    notes = todo.notes
    isCompleted = todo.isCompleted
    completedAt = todo.completedAt
    priority = todo.priority
    dueDate = todo.dueDate
    reminderInterval = todo.reminderInterval
    reminderRepeatInterval = todo.reminderRepeatInterval
    reminderRepeatCount = todo.reminderRepeatCount
    createdAt = todo.createdAt
    sortOrder = todo.sortOrder
    isPinned = todo.isPinned
    categoryId = todo.category?.id
    parentTodoId = todo.parentTodo?.id
    recurrenceType = todo.recurrenceType
    recurrenceInterval = todo.recurrenceInterval
    recurrenceDaysOfWeek = todo.recurrenceDaysOfWeek
    recurrenceEndDate = todo.recurrenceEndDate
    linkedExpenseId = todo.linkedExpenseId
    linkedBillId = todo.linkedBillId
    smartPriorityOverride = todo.smartPriorityOverride
  }

  func toModel(categories: [UUID: TodoCategory]) -> TodoItem {
    let model = TodoItem(
      title: title,
      notes: notes,
      priority: Priority(rawValue: priority) ?? .medium,
      dueDate: dueDate,
      reminderInterval: reminderInterval,
      reminderRepeatInterval: reminderRepeatInterval,
      reminderRepeatCount: reminderRepeatCount,
      category: categoryId.flatMap { categories[$0] },
      parentTodo: nil,
      recurrenceType: recurrenceType.flatMap { RecurrenceType(rawValue: $0) },
      recurrenceInterval: recurrenceInterval,
      recurrenceDaysOfWeek: recurrenceDaysOfWeek,
      recurrenceEndDate: recurrenceEndDate,
      sortOrder: sortOrder
    )
    model.id = id
    model.isCompleted = isCompleted
    model.completedAt = completedAt
    model.createdAt = createdAt
    model.isPinned = isPinned
    model.linkedExpenseId = linkedExpenseId
    model.linkedBillId = linkedBillId
    model.smartPriorityOverride = smartPriorityOverride
    return model
  }
}

private struct FXRateDTO: Codable, BackupDTO {
  typealias Model = FXRate
  let id: UUID
  let currency: String
  let rateToUAH: Double
  let source: String
  let isManual: Bool
  let updatedAt: Date

  init(_ model: FXRate) {
    id = model.id
    currency = model.currency
    rateToUAH = model.rateToUAH
    source = model.source
    isManual = model.isManual
    updatedAt = model.updatedAt
  }

  func toModel() -> FXRate {
    let model = FXRate(
      currency: Currency(rawValue: currency) ?? .uah,
      rateToUAH: rateToUAH,
      source: source,
      isManual: isManual
    )
    model.id = id
    model.updatedAt = updatedAt
    return model
  }
}

private struct SubscriptionDTO: Codable, BackupDTO {
  typealias Model = SubscriptionItem
  let id: UUID
  let name: String
  let merchant: String
  let amount: Double
  let currency: String
  let billingCycle: String
  let nextRenewalDate: Date
  let leadTimeDays: Int
  let lastChargeDate: Date?
  let nextChargeAmount: Double
  let isActive: Bool
  let sourceTemplateId: UUID?
  let sourceRuleId: UUID?
  let createdAt: Date
  let updatedAt: Date

  init(_ model: SubscriptionItem) {
    id = model.id
    name = model.name
    merchant = model.merchant
    amount = model.amount
    currency = model.currency
    billingCycle = model.billingCycle
    nextRenewalDate = model.nextRenewalDate
    leadTimeDays = model.leadTimeDays
    lastChargeDate = model.lastChargeDate
    nextChargeAmount = model.nextChargeAmount
    isActive = model.isActive
    sourceTemplateId = model.sourceTemplateId
    sourceRuleId = model.sourceRuleId
    createdAt = model.createdAt
    updatedAt = model.updatedAt
  }

  func toModel() -> SubscriptionItem {
    let model = SubscriptionItem(
      name: name,
      merchant: merchant,
      amount: amount,
      currency: Currency(rawValue: currency) ?? .uah,
      billingCycle: BillingCycle(rawValue: billingCycle) ?? .monthly,
      nextRenewalDate: nextRenewalDate,
      leadTimeDays: leadTimeDays,
      lastChargeDate: lastChargeDate,
      nextChargeAmount: nextChargeAmount,
      isActive: isActive,
      sourceTemplateId: sourceTemplateId,
      sourceRuleId: sourceRuleId
    )
    model.id = id
    model.createdAt = createdAt
    model.updatedAt = updatedAt
    return model
  }
}

private struct BillDTO: Codable, BackupDTO {
  typealias Model = BillItem
  let id: UUID
  let name: String
  let amount: Double
  let currency: String
  let dueDate: Date
  let recurrence: String
  let autopay: Bool
  let category: String
  let reminderLeadTime: TimeInterval
  let isPaid: Bool
  let lastPaidAt: Date?
  let lastPaidAmountUAH: Double?
  let linkedExpenseId: UUID?
  let createdAt: Date
  let updatedAt: Date

  init(_ model: BillItem) {
    id = model.id
    name = model.name
    amount = model.amount
    currency = model.currency
    dueDate = model.dueDate
    recurrence = model.recurrence
    autopay = model.autopay
    category = model.category
    reminderLeadTime = model.reminderLeadTime
    isPaid = model.isPaid
    lastPaidAt = model.lastPaidAt
    lastPaidAmountUAH = model.lastPaidAmountUAH
    linkedExpenseId = model.linkedExpenseId
    createdAt = model.createdAt
    updatedAt = model.updatedAt
  }

  func toModel() -> BillItem {
    let model = BillItem(
      name: name,
      amount: amount,
      currency: Currency(rawValue: currency) ?? .uah,
      dueDate: dueDate,
      recurrence: BillingCycle(rawValue: recurrence) ?? .monthly,
      autopay: autopay,
      category: ExpenseCategory(rawValue: category) ?? .other,
      reminderLeadTime: reminderLeadTime
    )
    model.id = id
    model.isPaid = isPaid
    model.lastPaidAt = lastPaidAt
    model.lastPaidAmountUAH = lastPaidAmountUAH
    model.linkedExpenseId = linkedExpenseId
    model.createdAt = createdAt
    model.updatedAt = updatedAt
    return model
  }
}

private struct SavingsGoalDTO: Codable, BackupDTO {
  typealias Model = SavingsGoal
  let id: UUID
  let title: String
  let targetAmountUAH: Double
  let currentAmountUAH: Double
  let targetDate: Date?
  let monthlyTargetUAH: Double
  let priority: String
  let isArchived: Bool
  let createdAt: Date
  let updatedAt: Date

  init(_ model: SavingsGoal) {
    id = model.id
    title = model.title
    targetAmountUAH = model.targetAmountUAH
    currentAmountUAH = model.currentAmountUAH
    targetDate = model.targetDate
    monthlyTargetUAH = model.monthlyTargetUAH
    priority = model.priority
    isArchived = model.isArchived
    createdAt = model.createdAt
    updatedAt = model.updatedAt
  }

  func toModel() -> SavingsGoal {
    let model = SavingsGoal(
      title: title,
      targetAmountUAH: targetAmountUAH,
      currentAmountUAH: currentAmountUAH,
      targetDate: targetDate,
      monthlyTargetUAH: monthlyTargetUAH,
      priority: SavingsPriority(rawValue: priority) ?? .medium,
      isArchived: isArchived
    )
    model.id = id
    model.createdAt = createdAt
    model.updatedAt = updatedAt
    return model
  }
}

private struct NetWorthAccountDTO: Codable, BackupDTO {
  typealias Model = NetWorthAccount
  let id: UUID
  let name: String
  let type: String
  let source: String
  let sourceAccountId: String?
  let balanceUAH: Double
  let includeInTotal: Bool
  let createdAt: Date
  let updatedAt: Date

  init(_ model: NetWorthAccount) {
    id = model.id
    name = model.name
    type = model.type
    source = model.source
    sourceAccountId = model.sourceAccountId
    balanceUAH = model.balanceUAH
    includeInTotal = model.includeInTotal
    createdAt = model.createdAt
    updatedAt = model.updatedAt
  }

  func toModel() -> NetWorthAccount {
    let model = NetWorthAccount(
      name: name,
      type: NetWorthAccountType(rawValue: type) ?? .asset,
      source: NetWorthSource(rawValue: source) ?? .manual,
      sourceAccountId: sourceAccountId,
      balanceUAH: balanceUAH,
      includeInTotal: includeInTotal
    )
    model.id = id
    model.createdAt = createdAt
    model.updatedAt = updatedAt
    return model
  }
}

private struct TripBudgetDTO: Codable, BackupDTO {
  typealias Model = TripBudget
  let id: UUID
  let name: String
  let startDate: Date
  let endDate: Date
  let budgetUAH: Double
  let homeCurrency: String
  let note: String?
  let tripCurrency: String
  let alertThresholdPercent: Double
  let isActive: Bool
  let createdAt: Date
  let updatedAt: Date

  init(_ model: TripBudget) {
    id = model.id
    name = model.name
    startDate = model.startDate
    endDate = model.endDate
    budgetUAH = model.budgetUAH
    homeCurrency = model.homeCurrency
    note = model.note
    tripCurrency = model.tripCurrency
    alertThresholdPercent = model.alertThresholdPercent
    isActive = model.isActive
    createdAt = model.createdAt
    updatedAt = model.updatedAt
  }

  func toModel() -> TripBudget {
    let model = TripBudget(
      name: name,
      startDate: startDate,
      endDate: endDate,
      budgetUAH: budgetUAH,
      homeCurrency: Currency(rawValue: homeCurrency) ?? .uah,
      note: note,
      tripCurrency: Currency(rawValue: tripCurrency) ?? .uah,
      alertThresholdPercent: alertThresholdPercent,
      isActive: isActive
    )
    model.id = id
    model.createdAt = createdAt
    model.updatedAt = updatedAt
    return model
  }
}

private struct WeeklyReviewDTO: Codable, BackupDTO {
  typealias Model = WeeklyReviewSnapshot
  let id: UUID
  let weekStart: Date
  let weekEnd: Date
  let summaryJSON: String
  let generatedAt: Date

  init(_ model: WeeklyReviewSnapshot) {
    id = model.id
    weekStart = model.weekStart
    weekEnd = model.weekEnd
    summaryJSON = model.summaryJSON
    generatedAt = model.generatedAt
  }

  func toModel() -> WeeklyReviewSnapshot {
    let model = WeeklyReviewSnapshot(weekStart: weekStart, weekEnd: weekEnd, summaryJSON: summaryJSON)
    model.id = id
    model.generatedAt = generatedAt
    return model
  }
}

private struct WhatIfScenarioDTO: Codable, BackupDTO {
  typealias Model = WhatIfScenario
  let id: UUID
  let title: String
  let deltaExpensesUAH: Double
  let deltaIncomeUAH: Double
  let period: String
  let impactJSON: String
  let createdAt: Date

  init(_ model: WhatIfScenario) {
    id = model.id
    title = model.title
    deltaExpensesUAH = model.deltaExpensesUAH
    deltaIncomeUAH = model.deltaIncomeUAH
    period = model.period
    impactJSON = model.impactJSON
    createdAt = model.createdAt
  }

  func toModel() -> WhatIfScenario {
    let model = WhatIfScenario(
      title: title,
      deltaExpensesUAH: deltaExpensesUAH,
      deltaIncomeUAH: deltaIncomeUAH,
      period: ScenarioPeriod(rawValue: period) ?? .month,
      impactJSON: impactJSON
    )
    model.id = id
    model.createdAt = createdAt
    return model
  }
}

private struct CSVImportMappingDTO: Codable, BackupDTO {
  typealias Model = CSVImportMapping
  let id: UUID
  let name: String
  let headerFingerprint: String
  let delimiter: String
  let dateFormat: String
  let fieldMapJSON: String
  let isDefault: Bool
  let updatedAt: Date

  init(_ model: CSVImportMapping) {
    id = model.id
    name = model.name
    headerFingerprint = model.headerFingerprint
    delimiter = model.delimiter
    dateFormat = model.dateFormat
    fieldMapJSON = model.fieldMapJSON
    isDefault = model.isDefault
    updatedAt = model.updatedAt
  }

  func toModel() -> CSVImportMapping {
    let model = CSVImportMapping(
      name: name,
      headerFingerprint: headerFingerprint,
      delimiter: delimiter,
      dateFormat: dateFormat,
      fieldMapJSON: fieldMapJSON,
      isDefault: isDefault
    )
    model.id = id
    model.updatedAt = updatedAt
    return model
  }
}

private struct NotificationPreferencesDTO: Codable, BackupDTO {
  typealias Model = NotificationPreferences
  let id: UUID
  let todoEnabled: Bool
  let eventEnabled: Bool
  let budgetEnabled: Bool
  let subscriptionEnabled: Bool
  let billEnabled: Bool
  let cashflowEnabled: Bool
  let timerEnabled: Bool
  let alarmEnabled: Bool
  let quietHoursEnabled: Bool
  let quietStartHour: Int
  let quietEndHour: Int
  let digestEnabled: Bool
  let digestHour: Int
  let throttleMinutes: Int
  let updatedAt: Date

  init(_ model: NotificationPreferences) {
    id = model.id
    todoEnabled = model.todoEnabled
    eventEnabled = model.eventEnabled
    budgetEnabled = model.budgetEnabled
    subscriptionEnabled = model.subscriptionEnabled
    billEnabled = model.billEnabled
    cashflowEnabled = model.cashflowEnabled
    timerEnabled = model.timerEnabled
    alarmEnabled = model.alarmEnabled
    quietHoursEnabled = model.quietHoursEnabled
    quietStartHour = model.quietStartHour
    quietEndHour = model.quietEndHour
    digestEnabled = model.digestEnabled
    digestHour = model.digestHour
    throttleMinutes = model.throttleMinutes
    updatedAt = model.updatedAt
  }

  func toModel() -> NotificationPreferences {
    let model = NotificationPreferences(
      todoEnabled: todoEnabled,
      eventEnabled: eventEnabled,
      budgetEnabled: budgetEnabled,
      subscriptionEnabled: subscriptionEnabled,
      billEnabled: billEnabled,
      cashflowEnabled: cashflowEnabled,
      timerEnabled: timerEnabled,
      alarmEnabled: alarmEnabled,
      quietHoursEnabled: quietHoursEnabled,
      quietStartHour: quietStartHour,
      quietEndHour: quietEndHour,
      digestEnabled: digestEnabled,
      digestHour: digestHour,
      throttleMinutes: throttleMinutes
    )
    model.id = id
    model.updatedAt = updatedAt
    return model
  }
}

private struct OnboardingStateDTO: Codable, BackupDTO {
  typealias Model = OnboardingState
  let id: UUID
  let hasCompleted: Bool
  let lastShownVersion: String
  let completedAt: Date?
  let lastUpdatedAt: Date

  init(_ model: OnboardingState) {
    id = model.id
    hasCompleted = model.hasCompleted
    lastShownVersion = model.lastShownVersion
    completedAt = model.completedAt
    lastUpdatedAt = model.lastUpdatedAt
  }

  func toModel() -> OnboardingState {
    let model = OnboardingState(
      hasCompleted: hasCompleted,
      lastShownVersion: lastShownVersion,
      completedAt: completedAt
    )
    model.id = id
    model.lastUpdatedAt = lastUpdatedAt
    return model
  }
}

private enum CompressionCodec {
  static func compress(_ data: Data) throws -> Data {
    guard !data.isEmpty else { return data }
    return try perform(operation: COMPRESSION_STREAM_ENCODE, input: data)
  }

  static func decompress(_ data: Data) throws -> Data {
    guard !data.isEmpty else { return data }
    return try perform(operation: COMPRESSION_STREAM_DECODE, input: data)
  }

  private static func perform(operation: compression_stream_operation, input: Data) throws -> Data {
    let bootstrapSrc = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
    let bootstrapDst = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
    defer {
      bootstrapSrc.deallocate()
      bootstrapDst.deallocate()
    }
    var stream = compression_stream(
      dst_ptr: bootstrapDst,
      dst_size: 0,
      src_ptr: UnsafePointer(bootstrapSrc),
      src_size: 0,
      state: nil
    )
    var status = compression_stream_init(&stream, operation, COMPRESSION_LZFSE)
    guard status != COMPRESSION_STATUS_ERROR else { throw NSError(domain: "Compression", code: -1) }
    defer { compression_stream_destroy(&stream) }

    let dstSize = 64 * 1024
    let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: dstSize)
    defer { dstBuffer.deallocate() }

    return try input.withUnsafeBytes { srcBuffer -> Data in
      guard let srcPtr = srcBuffer.bindMemory(to: UInt8.self).baseAddress else { return Data() }
      stream.src_ptr = srcPtr
      stream.src_size = input.count
      stream.dst_ptr = dstBuffer
      stream.dst_size = dstSize

      var output = Data()
      repeat {
        status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
        switch status {
        case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
          let produced = dstSize - stream.dst_size
          if produced > 0 {
            output.append(dstBuffer, count: produced)
          }
          stream.dst_ptr = dstBuffer
          stream.dst_size = dstSize
        default:
          throw NSError(domain: "Compression", code: -2)
        }
      } while status == COMPRESSION_STATUS_OK

      return output
    }
  }
}

private enum BackupCrypto {
  static func seal(payload: Data, passphrase: String) throws -> Data {
    let salt = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
    let nonceData = Data((0..<12).map { _ in UInt8.random(in: 0...255) })
    let key = deriveKey(passphrase: passphrase, salt: salt)
    let sealed = try AES.GCM.seal(payload, using: key, nonce: try AES.GCM.Nonce(data: nonceData))
    let package = EncryptedPayload(
      salt: salt,
      nonce: nonceData,
      ciphertext: sealed.ciphertext,
      tag: sealed.tag
    )
    return try JSONEncoder().encode(package)
  }

  static func open(package: Data, passphrase: String) throws -> Data {
    let decoded = try JSONDecoder().decode(EncryptedPayload.self, from: package)
    let key = deriveKey(passphrase: passphrase, salt: decoded.salt)
    let sealed = try AES.GCM.SealedBox(
      nonce: AES.GCM.Nonce(data: decoded.nonce),
      ciphertext: decoded.ciphertext,
      tag: decoded.tag
    )
    return try AES.GCM.open(sealed, using: key)
  }

  static func checksumHex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  private static func deriveKey(passphrase: String, salt: Data) -> SymmetricKey {
    var material = Data(passphrase.utf8) + salt
    for _ in 0..<120_000 {
      material = Data(SHA256.hash(data: material))
    }
    return SymmetricKey(data: material)
  }

  private struct EncryptedPayload: Codable {
    let salt: Data
    let nonce: Data
    let ciphertext: Data
    let tag: Data
  }
}

protocol NetWorthServiceProtocol {
  func totalNetWorthUAH(context: ModelContext) throws -> Double
  func recordSnapshot(context: ModelContext, date: Date) throws -> NetWorthSnapshot
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

  func recordSnapshot(context: ModelContext, date: Date = Date()) throws -> NetWorthSnapshot {
    let accounts = try context.fetch(FetchDescriptor<NetWorthAccount>())
      .filter { $0.includeInTotal }
    let assets = accounts
      .filter { (NetWorthAccountType(rawValue: $0.type) ?? .asset) == .asset }
      .reduce(0) { $0 + $1.balanceUAH }
    let liabilities = accounts
      .filter { (NetWorthAccountType(rawValue: $0.type) ?? .asset) == .liability }
      .reduce(0) { $0 + $1.balanceUAH }

    let snapshot = NetWorthSnapshot(date: date, assetsUAH: assets, liabilitiesUAH: liabilities)
    context.insert(snapshot)
    try context.save()
    return snapshot
  }
}

protocol TripBudgetServiceProtocol {
  func activeTrip(context: ModelContext) throws -> TripBudget?
  func remainingBudgetUAH(context: ModelContext, trip: TripBudget) throws -> Double
}

final class TripBudgetService: TripBudgetServiceProtocol {
  static let shared = TripBudgetService()
  private init() {}

  func activeTrip(context: ModelContext) throws -> TripBudget? {
    let now = Date()
    return try context.fetch(FetchDescriptor<TripBudget>())
      .first(where: { $0.isActive && $0.startDate <= now && $0.endDate >= now })
  }

  func remainingBudgetUAH(context: ModelContext, trip: TripBudget) throws -> Double {
    let expenses = try context.fetch(FetchDescriptor<Expense>())
      .filter { expense in
        expense.tripId == trip.id && !expense.isIncome
      }
    let spent = expenses.reduce(0.0) { partial, expense in
      partial + FXRateStore.shared.rateToUAH(for: expense.currencyEnum) * expense.amount
    }
    return trip.budgetUAH - spent
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
    let expenses = try context.fetch(FetchDescriptor<Expense>())
      .filter { $0.date >= weekStart && $0.date <= weekEnd && !$0.isIncome }
    let income = try context.fetch(FetchDescriptor<Expense>())
      .filter { $0.date >= weekStart && $0.date <= weekEnd && $0.isIncome }
    let todos = try context.fetch(FetchDescriptor<TodoItem>())
      .filter { $0.createdAt >= weekStart && $0.createdAt <= weekEnd }

    let expenseVM = ExpenseViewModel()
    let totalExpenses = expenses.reduce(0.0) { $0 + expenseVM.amountInUAH($1) }
    let totalIncome = income.reduce(0.0) { $0 + expenseVM.amountInUAH($1) }
    let completed = todos.filter(\.isCompleted).count
    let completionRate = todos.isEmpty ? 0 : Double(completed) / Double(todos.count)
    let topCategory = Dictionary(grouping: expenses, by: { $0.primaryCategory })
      .mapValues { rows in rows.reduce(0.0) { $0 + expenseVM.amountInUAH($1) } }
      .sorted(by: { $0.value > $1.value })
      .first?.key.displayName ?? "n/a"

    let summaryMap: [String: Any] = [
      "weekStart": weekStart.timeIntervalSince1970,
      "weekEnd": weekEnd.timeIntervalSince1970,
      "expensesUAH": totalExpenses,
      "incomeUAH": totalIncome,
      "netUAH": totalIncome - totalExpenses,
      "todoCompletionRate": completionRate,
      "topExpenseCategory": topCategory,
      "expenseCount": expenses.count,
      "todoCount": todos.count,
    ]
    let summaryData = try JSONSerialization.data(withJSONObject: summaryMap, options: [.sortedKeys])
    let summary = String(data: summaryData, encoding: .utf8) ?? "{}"
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
    if let override = todo.smartPriorityOverride {
      return override
    }

    let dueDateWeight: Double
    if let dueDate = todo.dueDate {
      let hoursRemaining = max(1, dueDate.timeIntervalSinceNow / 3600.0)
      dueDateWeight = 1.0 / hoursRemaining
    } else {
      dueDateWeight = 0
    }

    let overdueBoost = (todo.dueDate ?? .distantFuture) < Date() ? 1200.0 : 0
    let priorityWeight: Double
    switch todo.priorityEnum {
    case .high: priorityWeight = 600
    case .medium: priorityWeight = 300
    case .low: priorityWeight = 100
    }

    let financialWeight = linkedExpense.map { ExpenseViewModel().amountInUAH($0) / 20 } ?? 0
    return dueDateWeight * 1500 + priorityWeight + financialWeight + overdueBoost
  }
}

protocol CSVMappingServiceProtocol {
  func fingerprint(headers: [String]) -> String
  func loadMapping(context: ModelContext, headers: [String]) throws -> CSVImportMapping?
  func parseWithMapping(csvString: String, mapping: CSVImportMapping) -> (transactions: [CSVTransaction], invalidRows: Int)
}

final class CSVMappingService: CSVMappingServiceProtocol {
  static let shared = CSVMappingService()
  private init() {}

  func fingerprint(headers: [String]) -> String {
    let canonical = headers.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: "|")
    return BackupCrypto.checksumHex(Data(canonical.utf8))
  }

  func loadMapping(context: ModelContext, headers: [String]) throws -> CSVImportMapping? {
    let key = fingerprint(headers: headers)
    let mappings = try context.fetch(FetchDescriptor<CSVImportMapping>())
    if let exact = mappings.first(where: { $0.headerFingerprint == key }) {
      return exact
    }
    return mappings.first(where: \.isDefault)
  }

  func parseWithMapping(csvString: String, mapping: CSVImportMapping) -> (transactions: [CSVTransaction], invalidRows: Int) {
    let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }
    guard let headerLine = lines.first else { return ([], 0) }
    let headers = parseLine(headerLine, delimiter: mapping.delimiter)
    guard let fieldMap = decodeMap(mapping.fieldMapJSON) else { return ([], lines.count) }

    var parsed: [CSVTransaction] = []
    var invalidRows = 0
    let formatter = DateFormatter()
    formatter.dateFormat = mapping.dateFormat
    formatter.locale = Locale(identifier: "uk_UA")

    for line in lines.dropFirst() {
      let columns = parseLine(line, delimiter: mapping.delimiter)
      var row: [String: String] = [:]
      for (index, header) in headers.enumerated() where index < columns.count {
        row[header] = columns[index]
      }

      guard
        let dateHeader = fieldMap[.date],
        let merchantHeader = fieldMap[.merchant],
        let amountHeader = fieldMap[.amount],
        let dateRaw = row[dateHeader],
        let merchantRaw = row[merchantHeader],
        let amountRaw = row[amountHeader],
        let date = formatter.date(from: dateRaw.trimmingCharacters(in: .whitespacesAndNewlines)),
        !merchantRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        invalidRows += 1
        continue
      }

      let cleanedAmount = amountRaw
        .replacingOccurrences(of: ",", with: ".")
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "₴", with: "")
        .replacingOccurrences(of: "$", with: "")
        .replacingOccurrences(of: "€", with: "")
      guard let amount = Double(cleanedAmount), amount != 0 else {
        invalidRows += 1
        continue
      }

      let currencyRaw = fieldMap[.currency].flatMap { row[$0] }?.uppercased()
      let currency: Currency
      switch currencyRaw {
      case "USD": currency = .usd
      case "EUR": currency = .eur
      default: currency = .uah
      }

      parsed.append(
        CSVTransaction(
          date: date,
          merchant: merchantRaw.trimmingCharacters(in: .whitespacesAndNewlines),
          amount: amount,
          currency: currency,
          rawData: row
        )
      )
    }

    return (parsed, invalidRows)
  }

  private func decodeMap(_ json: String) -> [CSVImportField: String]? {
    guard let data = json.data(using: .utf8),
      let decoded = try? JSONDecoder().decode([String: String].self, from: data)
    else { return nil }
    return Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
      guard let field = CSVImportField(rawValue: key) else { return nil }
      return (field, value)
    })
  }

  private func parseLine(_ line: String, delimiter: String) -> [String] {
    let sep = delimiter.first ?? ","
    var columns: [String] = []
    var current = ""
    var inQuotes = false
    for char in line {
      if char == "\"" {
        inQuotes.toggle()
      } else if char == sep && !inQuotes {
        columns.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        current = ""
      } else {
        current.append(char)
      }
    }
    columns.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
    return columns
  }
}

protocol CalendarExportServiceProtocol {
  func exportRecurringExpensesAndBills(
    templates: [RecurringExpenseTemplate],
    bills: [BillItem],
    from startDate: Date,
    days: Int
  ) -> Data
}

final class CalendarExportService: CalendarExportServiceProtocol {
  static let shared = CalendarExportService()
  private init() {}

  func exportRecurringExpensesAndBills(
    templates: [RecurringExpenseTemplate],
    bills: [BillItem],
    from startDate: Date,
    days: Int = 120
  ) -> Data {
    let calendar = Calendar.current
    let endDate = calendar.date(byAdding: .day, value: max(1, days), to: startDate) ?? startDate

    var lines: [String] = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//Shoode//Calendar//EN",
      "CALSCALE:GREGORIAN",
    ]

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)

    for template in templates where template.isActive && !template.isCurrentlyPaused {
      var due = template.nextDueDate(from: startDate.addingTimeInterval(-1))
      while let date = due, date <= endDate {
        lines.append(contentsOf: eventLines(
          uid: "recurring-\(template.id.uuidString)-\(Int(date.timeIntervalSince1970))",
          start: date,
          summary: template.title,
          description: "Recurring \(template.isIncome ? "income" : "expense") \(template.currencyEnum.symbol)\(String(format: "%.2f", template.amount))",
          formatter: formatter
        ))
        due = template.nextDueDate(from: date)
      }
    }

    for bill in bills where !bill.isPaid && bill.dueDate >= startDate && bill.dueDate <= endDate {
      lines.append(contentsOf: eventLines(
        uid: "bill-\(bill.id.uuidString)",
        start: bill.dueDate,
        summary: "Bill: \(bill.name)",
        description: "Amount \(bill.amount) \(bill.currency)",
        formatter: formatter
      ))
    }

    lines.append("END:VCALENDAR")
    return Data(lines.joined(separator: "\r\n").utf8)
  }

  private func eventLines(
    uid: String,
    start: Date,
    summary: String,
    description: String,
    formatter: DateFormatter
  ) -> [String] {
    let stamp = formatter.string(from: Date())
    let begin = formatter.string(from: start)
    return [
      "BEGIN:VEVENT",
      "UID:\(uid)",
      "DTSTAMP:\(stamp)",
      "DTSTART:\(begin)",
      "SUMMARY:\(summary.replacingOccurrences(of: "\n", with: " "))",
      "DESCRIPTION:\(description.replacingOccurrences(of: "\n", with: " "))",
      "END:VEVENT",
    ]
  }
}

enum NotificationCategoryKind: String, CaseIterable {
  case todo
  case event
  case budget
  case subscription
  case bill
  case cashflow
  case timer
  case alarm
}

final class NotificationPreferencesService {
  static let shared = NotificationPreferencesService()
  private let defaults = UserDefaults(suiteName: Constants.Storage.appGroupIdentifier) ?? .standard

  private init() {}

  func current(context: ModelContext) -> NotificationPreferences {
    if let existing = try? context.fetch(FetchDescriptor<NotificationPreferences>()).first {
      syncToDefaults(existing)
      return existing
    }
    let prefs = NotificationPreferences()
    context.insert(prefs)
    try? context.save()
    syncToDefaults(prefs)
    return prefs
  }

  func syncToDefaults(_ prefs: NotificationPreferences) {
    defaults.set(prefs.quietHoursEnabled, forKey: Constants.Notifications.quietHoursEnabledKey)
    defaults.set(prefs.quietStartHour, forKey: Constants.Notifications.quietStartHourKey)
    defaults.set(prefs.quietEndHour, forKey: Constants.Notifications.quietEndHourKey)
    defaults.set(prefs.digestEnabled, forKey: Constants.Notifications.digestEnabledKey)
    defaults.set(prefs.digestHour, forKey: Constants.Notifications.digestHourKey)
    defaults.set(prefs.throttleMinutes, forKey: Constants.Notifications.throttleMinutesKey)
    defaults.set(prefs.todoEnabled, forKey: "notifications.category.todo")
    defaults.set(prefs.eventEnabled, forKey: "notifications.category.event")
    defaults.set(prefs.budgetEnabled, forKey: "notifications.category.budget")
    defaults.set(prefs.subscriptionEnabled, forKey: "notifications.category.subscription")
    defaults.set(prefs.billEnabled, forKey: "notifications.category.bill")
    defaults.set(prefs.cashflowEnabled, forKey: "notifications.category.cashflow")
    defaults.set(prefs.timerEnabled, forKey: "notifications.category.timer")
    defaults.set(prefs.alarmEnabled, forKey: "notifications.category.alarm")
  }

  func isAllowed(_ category: NotificationCategoryKind, now: Date = Date()) -> Bool {
    if !defaults.bool(forKey: "notifications.category.\(category.rawValue)"),
      defaults.object(forKey: "notifications.category.\(category.rawValue)") != nil
    {
      return false
    }

    let quietEnabled = defaults.bool(forKey: Constants.Notifications.quietHoursEnabledKey)
    guard quietEnabled else { return true }

    let start = defaults.integer(forKey: Constants.Notifications.quietStartHourKey)
    let end = defaults.integer(forKey: Constants.Notifications.quietEndHourKey)
    let hour = Calendar.current.component(.hour, from: now)

    if start == end { return true }
    if start < end {
      return !(hour >= start && hour < end)
    }
    return !(hour >= start || hour < end)
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
