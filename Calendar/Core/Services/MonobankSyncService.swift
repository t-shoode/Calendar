import Foundation
import SwiftData
import WidgetKit
import os

final class MonobankSyncService {
  static let shared = MonobankSyncService()

  private let session: URLSession
  private let tokenStore: MonobankTokenStore

  private init(
    session: URLSession = .shared,
    tokenStore: MonobankTokenStore = MonobankKeychainStore.shared
  ) {
    self.session = session
    self.tokenStore = tokenStore
  }

  struct SyncSummary {
    let imported: Int
    let updated: Int
    let conflicts: Int
    let skippedHolds: Int
  }

  struct WidgetMonobankBalanceItem: Codable {
    let accountId: String
    let balanceMajor: Double
    let currency: String
    let delta7Major: Double
    let delta30Major: Double
  }

  enum RangePreset: String {
    case days30 = "30d"
    case days90 = "90d"
    case days365 = "365d"
    case custom = "custom"

    var days: Int {
      switch self {
      case .days30: return 30
      case .days90: return 90
      case .days365: return 365
      case .custom: return 30
      }
    }
  }

  func saveToken(_ token: String, context: ModelContext) throws {
    let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedToken.isEmpty else {
      throw MonobankSyncError.missingToken
    }

    try tokenStore.saveToken(normalizedToken)
    let connection = try upsertConnection(context: context)
    connection.isConnected = true
    connection.lastSyncStatus = "connected"
    connection.lastSyncErrorMessage = nil
    connection.lastSyncErrorAt = nil
    connection.updatedAt = Date()
    try context.save()
  }

  func disconnect(context: ModelContext, hardDeleteImportedExpenses: Bool) throws {
    try tokenStore.deleteToken()

    let connection = try upsertConnection(context: context)
    connection.isConnected = false
    connection.clientId = nil
    connection.clientName = nil
    connection.selectedAccountIds = []
    connection.lastSyncStatus = "disconnected"
    connection.lastSyncErrorMessage = nil
    connection.lastSyncErrorAt = nil
    connection.updatedAt = Date()

    let accounts = try context.fetch(FetchDescriptor<MonobankAccount>())
    for account in accounts {
      context.delete(account)
    }

    let statements = try context.fetch(FetchDescriptor<MonobankStatementItem>())
    for statement in statements {
      context.delete(statement)
    }

    let states = try context.fetch(FetchDescriptor<MonobankSyncState>())
    for state in states {
      context.delete(state)
    }

    let conflicts = try context.fetch(FetchDescriptor<MonobankConflict>())
    for conflict in conflicts {
      context.delete(conflict)
    }

    if hardDeleteImportedExpenses {
      let expensesToDelete = try context.fetch(
        FetchDescriptor<Expense>(
          predicate: #Predicate { expense in
            expense.externalSource == "monobank"
          }))
      for expense in expensesToDelete {
        context.delete(expense)
      }
    }

    clearWidgetBalances()
    setWidgetAuthorization(isAuthorized: false)

    try context.save()
  }

  func syncIfNeededOnStartup(context: ModelContext) async {
    do {
      let connection = try upsertConnection(context: context)
      guard connection.hasConsent, connection.isConnected else { return }
      guard let token = try tokenStore.loadToken(), !token.isEmpty else { return }

      if let lastSyncAt = connection.lastSyncAt,
        Date().timeIntervalSince(lastSyncAt) < 60
      {
        return
      }

      _ = try await sync(context: context, token: token)
    } catch {
      Logging.log.error(
        "Monobank startup sync failed: \(String(describing: error), privacy: .public)")
    }
  }

  func sync(context: ModelContext, token: String? = nil) async throws -> SyncSummary {
    let resolvedToken: String
    if let token, !token.isEmpty {
      resolvedToken = token
    } else if let existingToken = try tokenStore.loadToken(), !existingToken.isEmpty {
      resolvedToken = existingToken
    } else {
      throw MonobankSyncError.missingToken
    }

    let connection = try upsertConnection(context: context)
    do {
      let clientInfo = try await fetchClientInfo(token: resolvedToken)
      connection.isConnected = true
      connection.clientId = clientInfo.clientId
      connection.clientName = clientInfo.name

      let updatedAccounts = try upsertAccounts(clientInfo.accounts, context: context)

      if connection.selectedAccountIds.isEmpty {
        connection.selectedAccountIds = updatedAccounts.prefix(1).map { $0.accountId }
        for account in updatedAccounts {
          account.isSelected = connection.selectedAccountIds.contains(account.accountId)
        }
      }

      let selectedSet = Set(connection.selectedAccountIds)
      for account in updatedAccounts where !selectedSet.contains(account.accountId) {
        account.isPinned = false
      }

      let range = statementRange(from: connection)

      var imported = 0
      var updated = 0
      var conflicts = 0
      var skippedHolds = 0

      for account in updatedAccounts where connection.selectedAccountIds.contains(account.accountId)
      {
        let items = try await fetchStatements(
          accountId: account.accountId,
          fromUnix: Int64(range.from.timeIntervalSince1970),
          toUnix: Int64(range.to.timeIntervalSince1970),
          token: resolvedToken
        )

        for dto in items {
          let statement = try upsertStatement(dto, accountId: account.accountId, context: context)
          if statement.hold {
            skippedHolds += 1
            continue
          }

          let projection = try projectStatement(statement, context: context)
          switch projection {
          case .created:
            imported += 1
          case .updated:
            updated += 1
          case .conflict:
            conflicts += 1
          case .skipped:
            break
          }
        }
      }

      connection.lastSyncAt = Date()
      connection.lastSyncStatus = "ok"
      connection.lastSyncErrorMessage = nil
      connection.lastSyncErrorAt = nil
      connection.updatedAt = Date()
      let statements = try context.fetch(FetchDescriptor<MonobankStatementItem>())
      syncBalancesToWidget(
        accounts: sortedSelectedAccounts(from: updatedAccounts),
        statements: statements
      )
      setWidgetAuthorization(isAuthorized: true)
      try context.save()

      return SyncSummary(
        imported: imported,
        updated: updated,
        conflicts: conflicts,
        skippedHolds: skippedHolds
      )
    } catch {
      if let syncError = error as? MonobankSyncError, syncError == .unauthorized {
        connection.isConnected = false
        connection.lastSyncStatus = "unauthorized"
        connection.lastSyncErrorMessage = MonobankSyncError.unauthorized.localizedDescription
        connection.lastSyncErrorAt = Date()
        clearWidgetBalances()
        setWidgetAuthorization(isAuthorized: false)
      } else {
        connection.lastSyncStatus = "error"
        connection.lastSyncErrorMessage = error.localizedDescription
        connection.lastSyncErrorAt = Date()
      }
      connection.updatedAt = Date()
      do {
        try context.save()
      } catch {
        Logging.log.error(
          "Failed to save Monobank sync error state: \(String(describing: error), privacy: .public)"
        )
      }
      throw error
    }
  }

  func setConsent(_ hasConsent: Bool, context: ModelContext) throws {
    let connection = try upsertConnection(context: context)
    connection.hasConsent = hasConsent
    connection.updatedAt = Date()
    try context.save()
  }

  func syncSelectedBalancesToWidget(context: ModelContext, userDefaults: UserDefaults? = nil) throws
  {
    let accounts = try context.fetch(FetchDescriptor<MonobankAccount>())
    let statements = try context.fetch(FetchDescriptor<MonobankStatementItem>())
    syncBalancesToWidget(accounts: accounts, statements: statements, userDefaults: userDefaults)
  }

  func resolveConflictKeepLocal(_ conflict: MonobankConflict, context: ModelContext) throws {
    conflict.status = "resolved_local"
    conflict.resolvedAt = Date()
    try context.save()
  }

  func resolveConflictUseServer(_ conflict: MonobankConflict, context: ModelContext) throws {
    let statementId = conflict.statementId
    let expenseId = conflict.expenseId
    let source = "monobank"

    guard
      let statement = try context.fetch(
        FetchDescriptor<MonobankStatementItem>(
          predicate: #Predicate { item in
            item.statementId == statementId
          })
      ).first
    else {
      throw MonobankSyncError.conflictDataMissing
    }

    guard
      let expense = try context.fetch(
        FetchDescriptor<Expense>(
          predicate: #Predicate { expense in
            expense.id == expenseId
          })
      ).first
    else {
      throw MonobankSyncError.conflictDataMissing
    }

    let projected = projectedFields(from: statement, context: context)
    apply(projected: projected, to: expense)
    expense.externalSource = source
    expense.externalId = statement.statementId
    expense.externalUpdatedAt = Date()
    expense.isManuallyEdited = false
    statement.projectedExpenseId = expense.id

    conflict.status = "resolved_server"
    conflict.resolvedAt = Date()

    try context.save()
  }

  private func upsertConnection(context: ModelContext) throws -> MonobankConnection {
    let connections = try context.fetch(
      FetchDescriptor<MonobankConnection>(
        sortBy: [SortDescriptor(\MonobankConnection.updatedAt, order: .reverse)]
      )
    )

    if let primary = connections.first {
      if connections.count > 1 {
        for duplicate in connections.dropFirst() {
          context.delete(duplicate)
        }
      }
      return primary
    }

    let newConnection = MonobankConnection()
    context.insert(newConnection)
    return newConnection
  }

  @discardableResult
  private func upsertAccounts(_ dtos: [MonobankAccountDTO], context: ModelContext) throws
    -> [MonobankAccount]
  {
    let existing = try context.fetch(FetchDescriptor<MonobankAccount>())
    var existingById: [String: MonobankAccount] = [:]
    for account in existing {
      existingById[account.accountId] = account
    }

    var result: [MonobankAccount] = []

    for dto in dtos {
      if let current = existingById[dto.id] {
        current.currencyCode = dto.currencyCode
        current.balanceMinor = dto.balance
        current.cashbackType = dto.cashbackType
        current.iban = dto.iban
        current.maskedPan = dto.maskedPan
        current.updatedAt = Date()
        result.append(current)
      } else {
        let account = MonobankAccount(
          accountId: dto.id,
          currencyCode: dto.currencyCode,
          balanceMinor: dto.balance,
          cashbackType: dto.cashbackType,
          iban: dto.iban,
          maskedPan: dto.maskedPan,
          isSelected: false
        )
        context.insert(account)
        result.append(account)
      }
    }

    return result
  }

  private func statementRange(from connection: MonobankConnection) -> (from: Date, to: Date) {
    let now = Date()
    let preset = RangePreset(rawValue: connection.rangePreset) ?? .days30

    if preset == .custom,
      let customFrom = connection.customFromDate,
      let customTo = connection.customToDate,
      customFrom <= customTo
    {
      return (customFrom, customTo)
    }

    let from = Calendar.current.date(byAdding: .day, value: -preset.days, to: now) ?? now
    return (from, now)
  }

  private func upsertStatement(
    _ dto: MonobankStatementDTO,
    accountId: String,
    context: ModelContext
  ) throws -> MonobankStatementItem {
    let statementId = dto.id

    let existing = try context.fetch(
      FetchDescriptor<MonobankStatementItem>(
        predicate: #Predicate { item in
          item.statementId == statementId
        })
    ).first

    if let existing {
      existing.accountId = accountId
      existing.transactionTime = Date(timeIntervalSince1970: TimeInterval(dto.time))
      existing.descriptionText = dto.description
      existing.mcc = dto.mcc
      existing.hold = dto.hold
      existing.amountMinor = dto.amount
      existing.operationAmountMinor = dto.operationAmount
      existing.currencyCode = dto.currencyCode
      existing.balanceMinor = dto.balance
      existing.comment = dto.comment
      existing.counterName = dto.counterName
      existing.updatedAt = Date()
      return existing
    }

    let newItem = MonobankStatementItem(
      statementId: dto.id,
      accountId: accountId,
      transactionTime: Date(timeIntervalSince1970: TimeInterval(dto.time)),
      descriptionText: dto.description,
      mcc: dto.mcc,
      hold: dto.hold,
      amountMinor: dto.amount,
      operationAmountMinor: dto.operationAmount,
      currencyCode: dto.currencyCode,
      balanceMinor: dto.balance,
      comment: dto.comment,
      counterName: dto.counterName
    )
    context.insert(newItem)
    return newItem
  }

  private enum ProjectionResult {
    case created
    case updated
    case conflict
    case skipped
  }

  private struct ProjectedFields {
    let title: String
    let amount: Double
    let date: Date
    let category: ExpenseCategory
    let categorizationRuleId: UUID?
    let paymentMethod: PaymentMethod
    let currency: Currency
    let merchant: String?
    let notes: String?
    let isIncome: Bool
  }

  private func projectStatement(_ statement: MonobankStatementItem, context: ModelContext) throws
    -> ProjectionResult
  {
    let source = "monobank"
    let statementId = statement.statementId

    let projected = projectedFields(from: statement, context: context)

    let existingExpense = try context.fetch(FetchDescriptor<Expense>()).first {
      $0.externalSource == source && $0.externalId == statementId
    }

    if let existingExpense {
      if existingExpense.isManuallyEdited,
        hasConflict(existingExpense: existingExpense, projected: projected)
      {
        let reason = conflictReason(existingExpense: existingExpense, projected: projected)
        try createConflictIfNeeded(
          statementId: statement.statementId,
          expenseId: existingExpense.id,
          reason: reason,
          context: context)
        return .conflict
      }

      apply(projected: projected, to: existingExpense)
      existingExpense.externalSource = source
      existingExpense.externalId = statement.statementId
      existingExpense.externalUpdatedAt = Date()
      statement.projectedExpenseId = existingExpense.id
      return .updated
    }

    let expense = Expense(
      title: projected.title,
      amount: projected.amount,
      date: projected.date,
      categories: [projected.category],
      paymentMethod: projected.paymentMethod,
      currency: projected.currency,
      merchant: projected.merchant,
      notes: projected.notes,
      templateId: nil,
      isGenerated: false,
      isIncome: projected.isIncome
    )
    expense.externalSource = source
    expense.externalId = statement.statementId
    expense.externalUpdatedAt = Date()
    expense.categorizationRuleId = projected.categorizationRuleId

    context.insert(expense)
    statement.projectedExpenseId = expense.id

    return .created
  }

  private func apply(projected: ProjectedFields, to expense: Expense) {
    expense.title = projected.title
    expense.amount = projected.amount
    expense.date = projected.date
    expense.categories = [projected.category.rawValue]
    expense.paymentMethod = projected.paymentMethod.rawValue
    expense.currency = projected.currency.rawValue
    expense.merchant = projected.merchant
    expense.notes = projected.notes
    expense.isIncome = projected.isIncome
    expense.categorizationRuleId = projected.categorizationRuleId
  }

  private func hasConflict(existingExpense: Expense, projected: ProjectedFields) -> Bool {
    if abs(existingExpense.amount - projected.amount) > 0.001 { return true }
    if existingExpense.title != projected.title { return true }
    if existingExpense.notes != projected.notes { return true }
    if existingExpense.currency != projected.currency.rawValue { return true }
    if existingExpense.isIncome != projected.isIncome { return true }
    return false
  }

  private func createConflictIfNeeded(
    statementId: String,
    expenseId: UUID,
    reason: String,
    context: ModelContext
  )
    throws
  {
    let pending = "pending"
    let existing = try context.fetch(
      FetchDescriptor<MonobankConflict>(
        predicate: #Predicate { conflict in
          conflict.statementId == statementId && conflict.expenseId == expenseId
            && conflict.status == pending
        })
    ).first

    guard existing == nil else { return }

    let conflict = MonobankConflict(
      statementId: statementId,
      expenseId: expenseId,
      reason: reason
    )
    context.insert(conflict)
  }

  private func conflictReason(existingExpense: Expense, projected: ProjectedFields) -> String {
    var details: [String] = []

    if abs(existingExpense.amount - projected.amount) > 0.001 {
      details.append(
        "Amount local \(String(format: "%.2f", existingExpense.amount)) vs bank \(String(format: "%.2f", projected.amount))"
      )
    }
    if existingExpense.title != projected.title {
      details.append("Title differs")
    }
    if existingExpense.notes != projected.notes {
      details.append("Notes differ")
    }
    if existingExpense.currency != projected.currency.rawValue {
      details.append("Currency differs")
    }
    if existingExpense.isIncome != projected.isIncome {
      details.append("Type differs")
    }

    if details.isEmpty {
      return "Server data differs from manually edited expense"
    }
    return details.joined(separator: " • ")
  }

  private func projectedFields(from statement: MonobankStatementItem, context: ModelContext)
    -> ProjectedFields
  {
    let amountMajor = MonobankProjectionMapper.amountMajor(
      fromMinor: statement.operationAmountMinor)
    let isIncome = MonobankProjectionMapper.isIncome(fromMinor: statement.operationAmountMinor)
    let title =
      statement.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? "Bank transaction" : statement.descriptionText
    let merchant = statement.counterName ?? statement.descriptionText
    let fallbackCategory = MonobankProjectionMapper.category(forMCC: statement.mcc)
    let resolved = CategorizationRuleService.shared.resolveCategory(
      context: context,
      merchant: merchant,
      mcc: statement.mcc,
      paymentMethod: .card,
      fallback: fallbackCategory
    )

    return ProjectedFields(
      title: title,
      amount: amountMajor,
      date: statement.transactionTime,
      category: resolved.category,
      categorizationRuleId: resolved.ruleId,
      paymentMethod: .card,
      currency: MonobankProjectionMapper.currency(fromMonobankCode: statement.currencyCode),
      merchant: merchant,
      notes: statement.comment,
      isIncome: isIncome
    )
  }

  private func fetchClientInfo(token: String) async throws -> MonobankClientInfoDTO {
    let url = URL(string: "https://api.monobank.ua/personal/client-info")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue(token, forHTTPHeaderField: "X-Token")

    let endpoint = "client-info"
    try enforceThrottle(endpoint: endpoint)

    let (data, response) = try await session.data(for: request)
    try validateResponse(response: response, data: data)
    return try JSONDecoder().decode(MonobankClientInfoDTO.self, from: data)
  }

  private func fetchStatements(accountId: String, fromUnix: Int64, toUnix: Int64, token: String)
    async throws
    -> [MonobankStatementDTO]
  {
    let maxWindow: Int64 = 2_682_000
    var start = fromUnix
    var collected: [MonobankStatementDTO] = []

    while start <= toUnix {
      let end = min(start + maxWindow, toUnix)
      let url = URL(
        string: "https://api.monobank.ua/personal/statement/\(accountId)/\(start)/\(end)")!

      var request = URLRequest(url: url)
      request.httpMethod = "GET"
      request.setValue(token, forHTTPHeaderField: "X-Token")

      let endpoint = "statement-\(accountId)"
      try enforceThrottle(endpoint: endpoint)

      let (data, response) = try await session.data(for: request)
      try validateResponse(response: response, data: data)
      let chunk = try JSONDecoder().decode([MonobankStatementDTO].self, from: data)
      collected.append(contentsOf: chunk)

      start = end + 1
    }

    return collected
  }

  private func enforceThrottle(endpoint: String) throws {
    let defaults = UserDefaults(suiteName: Constants.Storage.appGroupIdentifier)
    let key = "monobank.lastRequest.\(endpoint)"

    if let last = defaults?.object(forKey: key) as? Date,
      Date().timeIntervalSince(last) < 60
    {
      throw MonobankSyncError.throttled
    }

    defaults?.set(Date(), forKey: key)
  }

  private func validateResponse(response: URLResponse, data: Data) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
      throw MonobankSyncError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      switch httpResponse.statusCode {
      case 401:
        throw MonobankSyncError.unauthorized
      case 429:
        throw MonobankSyncError.rateLimited
      default:
        if let message = String(data: data, encoding: .utf8), !message.isEmpty {
          throw MonobankSyncError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
        throw MonobankSyncError.httpError(statusCode: httpResponse.statusCode, message: nil)
      }
    }
  }

  private func syncBalancesToWidget(
    accounts: [MonobankAccount],
    statements: [MonobankStatementItem],
    userDefaults: UserDefaults? = nil
  ) {
    let widgetAccounts = accountsForWidgetBalances(from: accounts)
    let payload = widgetAccounts.map { account in
      let delta7Minor = balanceDeltaMinor(
        currentBalanceMinor: account.balanceMinor,
        accountId: account.accountId,
        daysBack: 7,
        statements: statements
      )
      let delta30Minor = balanceDeltaMinor(
        currentBalanceMinor: account.balanceMinor,
        accountId: account.accountId,
        daysBack: 30,
        statements: statements
      )
      return WidgetMonobankBalanceItem(
        accountId: String(account.accountId.suffix(4)),
        balanceMajor: Double(account.balanceMinor) / 100.0,
        currency: MonobankProjectionMapper.currency(fromMonobankCode: account.currencyCode).rawValue,
        delta7Major: Double(delta7Minor) / 100.0,
        delta30Major: Double(delta30Minor) / 100.0
      )
    }

    let defaults = userDefaults ?? UserDefaults(suiteName: Constants.Storage.appGroupIdentifier)
    if let encoded = try? JSONEncoder().encode(payload) {
      defaults?.set(encoded, forKey: Constants.Widget.monobankBalancesKey)
    }
    defaults?.set(true, forKey: Constants.Widget.monobankAuthorizedKey)
    WidgetCenter.shared.reloadTimelines(ofKind: "CombinedWidget")
  }

  private func balanceDeltaMinor(
    currentBalanceMinor: Int64,
    accountId: String,
    daysBack: Int,
    statements: [MonobankStatementItem]
  ) -> Int64 {
    guard daysBack > 0 else { return 0 }
    let cutoff = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()

    let historicalBalance = statements
      .filter { $0.accountId == accountId && $0.transactionTime <= cutoff }
      .max(by: { $0.transactionTime < $1.transactionTime })?
      .balanceMinor ?? currentBalanceMinor

    return currentBalanceMinor - historicalBalance
  }

  private func accountsForWidgetBalances(from accounts: [MonobankAccount]) -> [MonobankAccount] {
    let selected = sortedSelectedAccounts(from: accounts)
    let pinnedSelected = selected.filter { $0.isPinned }
    return pinnedSelected.isEmpty ? selected : pinnedSelected
  }

  private func sortedSelectedAccounts(from accounts: [MonobankAccount]) -> [MonobankAccount] {
    accounts
      .filter { $0.isSelected }
      .sorted {
        if $0.isPinned != $1.isPinned {
          return $0.isPinned && !$1.isPinned
        }
        return $0.updatedAt > $1.updatedAt
      }
  }

  private func clearWidgetBalances() {
    let defaults = UserDefaults(suiteName: Constants.Storage.appGroupIdentifier)
    defaults?.removeObject(forKey: Constants.Widget.monobankBalancesKey)
    WidgetCenter.shared.reloadTimelines(ofKind: "CombinedWidget")
  }

  private func setWidgetAuthorization(isAuthorized: Bool, userDefaults: UserDefaults? = nil) {
    let defaults = userDefaults ?? UserDefaults(suiteName: Constants.Storage.appGroupIdentifier)
    defaults?.set(isAuthorized, forKey: Constants.Widget.monobankAuthorizedKey)
  }
}

private struct MonobankClientInfoDTO: Codable {
  let clientId: String
  let name: String
  let accounts: [MonobankAccountDTO]
}

private struct MonobankAccountDTO: Codable {
  let id: String
  let currencyCode: Int
  let cashbackType: String?
  let balance: Int64
  let iban: String?
  let maskedPan: [String]
}

private struct MonobankStatementDTO: Codable {
  let id: String
  let time: Int64
  let description: String
  let mcc: Int?
  let hold: Bool
  let amount: Int64
  let operationAmount: Int64
  let currencyCode: Int
  let balance: Int64
  let comment: String?
  let counterName: String?
}

enum MonobankSyncError: LocalizedError {
  case missingToken
  case throttled
  case unauthorized
  case rateLimited
  case invalidResponse
  case conflictDataMissing
  case httpError(statusCode: Int, message: String?)

  var errorDescription: String? {
    switch self {
    case .missingToken:
      return "Monobank token is not configured."
    case .throttled:
      return "Monobank requests are temporarily throttled. Please try again in a minute."
    case .unauthorized:
      return "Monobank token is invalid or expired."
    case .rateLimited:
      return "Monobank rate limit exceeded. Please retry in about a minute."
    case .invalidResponse:
      return "Invalid response from Monobank API."
    case .conflictDataMissing:
      return "Bank conflict source data is missing."
    case .httpError(let statusCode, let message):
      if let message, !message.isEmpty {
        return "Monobank request failed (\(statusCode)): \(message)"
      }
      return "Monobank request failed (\(statusCode))."
    }
  }
}

extension MonobankSyncError: Equatable {
  static func == (lhs: MonobankSyncError, rhs: MonobankSyncError) -> Bool {
    switch (lhs, rhs) {
    case (.missingToken, .missingToken), (.throttled, .throttled), (.unauthorized, .unauthorized),
      (.rateLimited, .rateLimited), (.invalidResponse, .invalidResponse),
      (.conflictDataMissing, .conflictDataMissing):
      return true
    case (.httpError(let lCode, let lMessage), .httpError(let rCode, let rMessage)):
      return lCode == rCode && lMessage == rMessage
    default:
      return false
    }
  }
}

enum MonobankProjectionMapper {
  static func amountMajor(fromMinor minor: Int64) -> Double {
    abs(Double(minor) / 100.0)
  }

  static func isIncome(fromMinor minor: Int64) -> Bool {
    minor > 0
  }

  static func currency(fromMonobankCode code: Int) -> Currency {
    switch code {
    case 840:
      return .usd
    case 978:
      return .eur
    case 980:
      return .uah
    default:
      return .uah
    }
  }

  static func category(forMCC mcc: Int?) -> ExpenseCategory {
    guard let mcc else { return .other }

    switch mcc {
    case 5411, 5422, 5441, 5451, 5462, 5499:
      return .groceries
    case 5812, 5814:
      return .dining
    case 4111, 4121, 4131, 4789, 5541, 5542:
      return .transportation
    case 5912, 5977:
      return .healthcare
    case 4899, 4814, 4900:
      return .subscriptions
    case 5311, 5331, 5399, 5651, 5661, 5691, 5699:
      return .shopping
    case 7832, 7922, 7991, 7997, 7999:
      return .entertainment
    default:
      return .other
    }
  }
}
