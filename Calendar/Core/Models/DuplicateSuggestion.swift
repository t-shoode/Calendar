import Foundation
import SwiftData

enum DuplicateStatus: String, Codable, CaseIterable {
  case pending
  case dismissed
  case merged
}

@Model
final class DuplicateSuggestion {
  var id: UUID
  var expenseIdA: UUID
  var expenseIdB: UUID
  var score: Double
  var status: String
  var pairKey: String
  var createdAt: Date

  var statusEnum: DuplicateStatus {
    get { DuplicateStatus(rawValue: status) ?? .pending }
    set { status = newValue.rawValue }
  }

  init(expenseIdA: UUID, expenseIdB: UUID, score: Double, status: DuplicateStatus = .pending) {
    self.id = UUID()
    self.expenseIdA = expenseIdA
    self.expenseIdB = expenseIdB
    self.score = score
    self.status = status.rawValue
    let ordered = [expenseIdA.uuidString, expenseIdB.uuidString].sorted()
    self.pairKey = "\(ordered[0])-\(ordered[1])"
    self.createdAt = Date()
  }
}
