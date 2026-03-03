import Foundation
import SwiftData
import os

/// Service for importing CSV files and managing import sessions
class CSVImportService {

  private let patternDetection = PatternDetectionService()
  private let mappingService = CSVMappingService.shared

  /// Import CSV file and return result
  func importCSV(
    csvData: Data,
    fileName: String,
    existingExpenses: [Expense],
    existingTemplates: [RecurringExpenseTemplate],
    context: ModelContext
  ) -> CSVImportResult {

    // Create import session
    let session = CSVImportSession(fileName: fileName)

    // Parse CSV
    guard let csvString = String(data: csvData, encoding: .utf8) else {
      return CSVImportResult(
        session: session,
        transactions: [],
        duplicates: [],
        suggestions: [],
        success: false,
        error: ImportError.invalidEncoding
      )
    }

    let (allTransactions, mappingId, invalidRowCount) = parseTransactions(
      csvString: csvString,
      context: context
    )
    session.transactionCount = allTransactions.count
    session.mappingId = mappingId
    session.invalidRowCount = invalidRowCount

    // Filter out duplicates
    let (uniqueTransactions, duplicates) = filterDuplicates(
      transactions: allTransactions,
      existingExpenses: existingExpenses
    )
    session.duplicateCount = duplicates.count
    session.warningCount = invalidRowCount > 0 ? 1 : 0

    // Detect patterns
    var suggestions = patternDetection.detectPatterns(from: uniqueTransactions)

    // Filter out suggestions that already have templates
    suggestions = filterExistingTemplates(
      suggestions: suggestions, existingTemplates: existingTemplates)

    session.templatesSuggested = suggestions.count

    // Save session
    context.insert(session)

    // Cleanup old sessions
    cleanupOldSessions(context: context)

    return CSVImportResult(
      session: session,
      transactions: uniqueTransactions,
      duplicates: duplicates,
      suggestions: suggestions,
      success: true,
      error: nil
    )
  }

  private func parseTransactions(
    csvString: String,
    context: ModelContext
  ) -> (transactions: [CSVTransaction], mappingId: UUID?, invalidRowCount: Int) {
    let lines = csvString.components(separatedBy: .newlines)
    guard let headerLine = lines.first else {
      return ([], nil, 0)
    }

    let headers = headerLine
      .split(separator: ",")
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

    if let mapping = try? mappingService.loadMapping(context: context, headers: headers) {
      let parsed = mappingService.parseWithMapping(csvString: csvString, mapping: mapping)
      return (parsed.transactions, mapping.id, parsed.invalidRows)
    }

    return (CSVParser.parse(csvString: csvString), nil, 0)
  }

  /// Filter out transactions that are duplicates of existing expenses
  private func filterDuplicates(
    transactions: [CSVTransaction],
    existingExpenses: [Expense]
  ) -> (unique: [CSVTransaction], duplicates: [CSVTransaction]) {
    var unique: [CSVTransaction] = []
    var duplicates: [CSVTransaction] = []

    for transaction in transactions {
      if patternDetection.isDuplicate(transaction, existingExpenses: existingExpenses) {
        duplicates.append(transaction)
      } else {
        unique.append(transaction)
      }
    }

    return (unique, duplicates)
  }

  /// Filter out suggestions that already have templates
  private func filterExistingTemplates(
    suggestions: [TemplateSuggestion],
    existingTemplates: [RecurringExpenseTemplate]
  ) -> [TemplateSuggestion] {
    return suggestions.filter { suggestion in
      // Check if a template already exists for this merchant with similar amount
      let normalizedSuggestion = patternDetection.normalizeMerchant(suggestion.merchant)

      for template in existingTemplates {
        let normalizedTemplate = patternDetection.normalizeMerchant(template.merchant)

        // Check merchant match
        guard normalizedSuggestion == normalizedTemplate else { continue }

        // Check amount similarity (within 20% tolerance)
        let tolerance = suggestion.suggestedAmount * 0.20
        guard abs(suggestion.suggestedAmount - template.amount) <= tolerance else { continue }

        // Check frequency match
        guard suggestion.frequency == template.frequency else { continue }

        // This suggestion already has a template, filter it out
        return false
      }

      // No existing template found, keep this suggestion
      return true
    }
  }

  /// Create templates from suggestions
  func createTemplates(
    from suggestions: [TemplateSuggestion],
    context: ModelContext
  ) -> [RecurringExpenseTemplate] {
    var createdTemplates: [RecurringExpenseTemplate] = []

    for suggestion in suggestions {
      let template = RecurringExpenseTemplate(
        title: suggestion.merchant,
        amount: suggestion.suggestedAmount,
        amountTolerance: 0.05,
        categories: suggestion.categories,
        paymentMethod: .card,  // Default
        currency: .uah,
        merchant: suggestion.merchant,
        notes: nil,
        frequency: suggestion.frequency,
        startDate: suggestion.occurrences.first ?? Date(),
        occurrenceCount: suggestion.occurrenceCount,
        isIncome: suggestion.isIncome
      )

      context.insert(template)
      createdTemplates.append(template)
    }

    return createdTemplates
  }

  /// Create a single expense from a transaction
  func createExpense(
    from transaction: CSVTransaction,
    template: RecurringExpenseTemplate? = nil,
    context: ModelContext
  ) -> Expense {
    let categories = template?.allCategories ?? [.other]

    let expense = Expense(
      title: transaction.merchant,
      amount: transaction.absoluteAmount,
      date: transaction.date,
      categories: categories,
      paymentMethod: template?.paymentMethodEnum ?? .card,
      currency: transaction.currency,
      merchant: transaction.merchant,
      notes: nil,
      templateId: template?.id,
      isGenerated: false,
      isIncome: transaction.isIncome
    )

    context.insert(expense)
    return expense
  }

  /// Cleanup old import sessions (keep only last 2, delete after 30 days)
  private func cleanupOldSessions(context: ModelContext) {
    let descriptor = FetchDescriptor<CSVImportSession>()

    do {
      let allSessions = try context.fetch(descriptor)
      let sessions = allSessions.filter { !$0.isDeleted }

      // Sort by date (oldest first)
      let sortedSessions = sessions.sorted { $0.importDate < $1.importDate }

      // Keep only last 2, mark others as deleted
      if sortedSessions.count > 2 {
        let toDelete = sortedSessions.dropLast(2)
        for session in toDelete {
          session.isDeleted = true
        }
      }

      // Hard delete anything older than 30 days
      let cutoffDate = Date().addingTimeInterval(-30 * 24 * 60 * 60)
      for session in allSessions {
        if session.importDate < cutoffDate {
          context.delete(session)
        }
      }

      try context.save()

    } catch {
      Logging.log.error(
        "Error cleaning up import sessions: \(String(describing: error), privacy: .public)")
    }
  }

  /// Get import history
  func getImportHistory(context: ModelContext) -> [CSVImportSession] {
    let descriptor = FetchDescriptor<CSVImportSession>(
      sortBy: [SortDescriptor(\.importDate, order: .reverse)]
    )

    do {
      let allSessions = try context.fetch(descriptor)
      return allSessions.filter { !$0.isDeleted }
    } catch {
      return []
    }
  }
}

enum ImportError: LocalizedError {
  case invalidEncoding
  case parseError

  var errorDescription: String? {
    switch self {
    case .invalidEncoding:
      return "Invalid file encoding. Please ensure the file is UTF-8 encoded."
    case .parseError:
      return "Unable to parse CSV file. Please check the file format."
    }
  }
}
