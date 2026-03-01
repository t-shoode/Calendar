import Foundation
import SwiftData
import os

final class DuplicateDetectionService {
  static let shared = DuplicateDetectionService()

  private let patternService = PatternDetectionService()
  private let minimumScore = 0.75

  private init() {}

  func refreshSuggestions(context: ModelContext, withinDays days: Int = 180) {
    let calendar = Calendar.current
    let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()

    let descriptor = FetchDescriptor<Expense>(
      predicate: #Predicate { expense in
        expense.date >= cutoff
      }
    )

    let suggestionDescriptor = FetchDescriptor<DuplicateSuggestion>()

    do {
      let expenses = try context.fetch(descriptor)
      let existing = try context.fetch(suggestionDescriptor)
      let dismissed = Set(existing.filter { $0.statusEnum != .pending }.map { $0.pairKey })
      let pending = existing.filter { $0.statusEnum == .pending }
      for item in pending { context.delete(item) }

      var newSuggestions: [DuplicateSuggestion] = []

      for i in 0..<expenses.count {
        for j in (i + 1)..<expenses.count {
          let a = expenses[i]
          let b = expenses[j]

          if !isDateClose(a.date, b.date) { continue }
          if a.isIncome != b.isIncome { continue }

          guard let score = duplicateScore(expenseA: a, expenseB: b), score >= minimumScore else {
            continue
          }
          let suggestion = DuplicateSuggestion(
            expenseIdA: a.id,
            expenseIdB: b.id,
            score: score
          )
          if dismissed.contains(suggestion.pairKey) { continue }
          newSuggestions.append(suggestion)
        }
      }

      for suggestion in newSuggestions {
        context.insert(suggestion)
      }

      try context.save()
    } catch {
      Logging.log.error("Duplicate detection failed: \(String(describing: error), privacy: .public)")
    }
  }

  func duplicateScore(expenseA: Expense, expenseB: Expense) -> Double? {
    let amountA = expenseA.currencyEnum.convertToUAH(expenseA.amount)
    let amountB = expenseB.currencyEnum.convertToUAH(expenseB.amount)
    let amountTolerance = min(amountA, amountB) * 0.05
    guard abs(amountA - amountB) <= amountTolerance else { return nil }

    let nameA = patternService.normalizeMerchant(expenseA.title)
    let nameB = patternService.normalizeMerchant(expenseB.title)
    let merchantSimilarity = stringSimilarity(nameA, nameB)
    guard merchantSimilarity >= 0.6 else { return nil }

    let dateDistance = abs(expenseA.date.timeIntervalSince(expenseB.date))
    let oneDay: TimeInterval = 24 * 60 * 60
    let dateScore = max(0, 1 - min(dateDistance / oneDay, 1))

    let amountDiffRatio = abs(amountA - amountB) / max(amountA, amountB)
    let amountScore = max(0, 1 - min(amountDiffRatio / 0.05, 1))

    return (dateScore * 0.35) + (amountScore * 0.35) + (merchantSimilarity * 0.30)
  }

  func dismissSuggestion(_ suggestion: DuplicateSuggestion, context: ModelContext) throws {
    suggestion.statusEnum = .dismissed
    try context.save()
  }

  func mergeSuggestion(_ suggestion: DuplicateSuggestion, context: ModelContext) throws {
    // Avoid a complex disjunction predicate here to keep SwiftData predicate type-checking stable
    // across compiler versions.
    let allExpenses = try context.fetch(FetchDescriptor<Expense>())
    let matches = allExpenses.filter {
      $0.id == suggestion.expenseIdA || $0.id == suggestion.expenseIdB
    }
    guard matches.count == 2 else {
      suggestion.statusEnum = .dismissed
      try context.save()
      return
    }

    let keep = matches.min(by: { $0.createdAt < $1.createdAt }) ?? matches[0]
    let remove = matches.first(where: { $0.id != keep.id })
    if let remove {
      if let existingNotes = keep.notes, !existingNotes.isEmpty, let removeNotes = remove.notes, !removeNotes.isEmpty {
        keep.notes = "\(existingNotes)\n\(removeNotes)"
      } else if keep.notes == nil {
        keep.notes = remove.notes
      }
      context.delete(remove)
    }

    suggestion.statusEnum = .merged
    try context.save()
  }

  private func isDateClose(_ lhs: Date, _ rhs: Date) -> Bool {
    abs(lhs.timeIntervalSince(rhs)) <= (24 * 60 * 60)
  }

  private func stringSimilarity(_ a: String, _ b: String) -> Double {
    if a == b { return 1 }
    let tokensA = Set(a.split(separator: " ").map(String.init))
    let tokensB = Set(b.split(separator: " ").map(String.init))
    guard !tokensA.isEmpty || !tokensB.isEmpty else { return 0 }

    let intersection = tokensA.intersection(tokensB).count
    let union = tokensA.union(tokensB).count
    if union == 0 { return 0 }
    return Double(intersection) / Double(union)
  }
}
