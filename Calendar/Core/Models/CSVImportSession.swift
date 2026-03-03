import Foundation
import SwiftData

enum CSVImportField: String, CaseIterable, Codable, Identifiable {
  case date
  case merchant
  case amount
  case currency
  case notes

  var id: String { rawValue }

  var title: String {
    switch self {
    case .date: return "Date"
    case .merchant: return "Merchant"
    case .amount: return "Amount"
    case .currency: return "Currency"
    case .notes: return "Notes"
    }
  }
}

@Model
final class CSVImportMapping {
  var id: UUID
  var name: String
  var headerFingerprint: String
  var delimiter: String
  var dateFormat: String
  var fieldMapJSON: String
  var isDefault: Bool
  var updatedAt: Date

  init(
    name: String,
    headerFingerprint: String,
    delimiter: String = ",",
    dateFormat: String = "dd.MM.yyyy HH:mm:ss",
    fieldMapJSON: String,
    isDefault: Bool = false
  ) {
    self.id = UUID()
    self.name = name
    self.headerFingerprint = headerFingerprint
    self.delimiter = delimiter
    self.dateFormat = dateFormat
    self.fieldMapJSON = fieldMapJSON
    self.isDefault = isDefault
    self.updatedAt = Date()
  }
}

@Model
class CSVImportSession {
  var id: UUID
  var importDate: Date
  var fileName: String
  var transactionCount: Int
  var templatesSuggested: Int
  var templatesCreated: Int
  var duplicateCount: Int
  var mappingId: UUID?
  var invalidRowCount: Int = 0
  var warningCount: Int = 0
  var isDeleted: Bool
  
  /// Date when this session should be hard deleted (30 days after import)
  var deleteAfterDate: Date {
    importDate.addingTimeInterval(30 * 24 * 60 * 60)
  }
  
  /// Check if session is older than 30 days
  var shouldBeDeleted: Bool {
    Date() >= deleteAfterDate
  }
  
  init(
    fileName: String,
    transactionCount: Int = 0,
    templatesSuggested: Int = 0,
    templatesCreated: Int = 0,
    duplicateCount: Int = 0,
    mappingId: UUID? = nil,
    invalidRowCount: Int = 0,
    warningCount: Int = 0
  ) {
    self.id = UUID()
    self.importDate = Date()
    self.fileName = fileName
    self.transactionCount = transactionCount
    self.templatesSuggested = templatesSuggested
    self.templatesCreated = templatesCreated
    self.duplicateCount = duplicateCount
    self.mappingId = mappingId
    self.invalidRowCount = invalidRowCount
    self.warningCount = warningCount
    self.isDeleted = false
  }
}

/// Represents a single transaction parsed from CSV
struct CSVTransaction: Identifiable {
  let id = UUID()
  let date: Date
  let merchant: String
  let amount: Double  // Negative = expense, Positive = income
  let currency: Currency
  let rawData: [String: String]  // Original row data for reference
  
  var isExpense: Bool {
    amount < 0
  }
  
  var isIncome: Bool {
    amount > 0
  }
  
  /// Returns absolute amount (always positive)
  var absoluteAmount: Double {
    abs(amount)
  }
}

/// Result of CSV import operation
struct CSVImportResult {
  let session: CSVImportSession
  let transactions: [CSVTransaction]
  let duplicates: [CSVTransaction]
  let suggestions: [TemplateSuggestion]
  let success: Bool
  let error: Error?
}
