import Foundation
import SwiftData

enum Priority: String, Codable, CaseIterable {
  case low
  case medium
  case high

  var displayName: String {
    switch self {
    case .low: return Localization.string(.priorityLow)
    case .medium: return Localization.string(.priorityMedium)
    case .high: return Localization.string(.priorityHigh)
    }
  }

  var sortOrder: Int {
    switch self {
    case .high: return 0
    case .medium: return 1
    case .low: return 2
    }
  }
}

enum RecurrenceType: String, Codable, CaseIterable {
  case weekly
  case monthly
  case yearly

  var displayName: String {
    switch self {
    case .weekly: return Localization.string(.weekly)
    case .monthly: return Localization.string(.monthly)
    case .yearly: return Localization.string(.yearly)
    }
  }
}

@Model
class TodoItem {
  var id: UUID
  var title: String
  var notes: String?
  var isCompleted: Bool
  var completedAt: Date?
  var priority: String
  var dueDate: Date?
  var reminderInterval: TimeInterval?
  var reminderRepeatInterval: TimeInterval?
  var reminderRepeatCount: Int?
  var createdAt: Date
  var sortOrder: Int
  var isPinned: Bool

  var category: TodoCategory?

  var parentTodo: TodoItem?

  @Relationship(deleteRule: .cascade, inverse: \TodoItem.parentTodo)
  var subtasks: [TodoItem]?

  var recurrenceType: String?
  var recurrenceInterval: Int
  var recurrenceDaysOfWeek: [Int]?
  var recurrenceEndDate: Date?

  var priorityEnum: Priority {
    get { Priority(rawValue: priority) ?? .medium }
    set { priority = newValue.rawValue }
  }

  var recurrenceTypeEnum: RecurrenceType? {
    get { recurrenceType.flatMap { RecurrenceType(rawValue: $0) } }
    set { recurrenceType = newValue?.rawValue }
  }

  var isRecurring: Bool {
    recurrenceType != nil
  }

  var isSubtask: Bool {
    parentTodo != nil
  }

  var hasSubtasks: Bool {
    !(subtasks?.isEmpty ?? true)
  }

  var isParentCompletionDerived: Bool {
    hasSubtasks
  }

  var subtaskProgress: (completed: Int, total: Int) {
    let allSubtasks = subtasks ?? []
    let completedCount = allSubtasks.filter(\.isCompleted).count
    return (completed: completedCount, total: allSubtasks.count)
  }

  init(
    title: String,
    notes: String? = nil,
    priority: Priority = .medium,
    dueDate: Date? = nil,
    reminderInterval: TimeInterval? = nil,
    reminderRepeatInterval: TimeInterval? = nil,
    reminderRepeatCount: Int? = nil,
    category: TodoCategory? = nil,
    parentTodo: TodoItem? = nil,
    recurrenceType: RecurrenceType? = nil,
    recurrenceInterval: Int = 1,
    recurrenceDaysOfWeek: [Int]? = nil,
    recurrenceEndDate: Date? = nil,
    sortOrder: Int = 0
  ) {
    self.id = UUID()
    self.title = title
    self.notes = notes
    self.isCompleted = false
    self.completedAt = nil
    self.priority = priority.rawValue
    self.dueDate = dueDate
    self.reminderInterval = reminderInterval
    self.reminderRepeatInterval = reminderRepeatInterval
    self.reminderRepeatCount = reminderRepeatCount
    self.createdAt = Date()
    self.sortOrder = sortOrder
    self.isPinned = false
    self.category = category
    self.parentTodo = parentTodo
    self.subtasks = []
    self.recurrenceType = recurrenceType?.rawValue
    self.recurrenceInterval = recurrenceInterval
    self.recurrenceDaysOfWeek = recurrenceDaysOfWeek
    self.recurrenceEndDate = recurrenceEndDate
  }

  func nextDueDate() -> Date? {
    guard let currentDue = dueDate, let type = recurrenceTypeEnum else { return nil }

    let calendar = Calendar.current
    var nextDate: Date?

    switch type {
    case .weekly:
      nextDate = calendar.date(byAdding: .weekOfYear, value: recurrenceInterval, to: currentDue)
    case .monthly:
      nextDate = calendar.date(byAdding: .month, value: recurrenceInterval, to: currentDue)
    case .yearly:
      nextDate = calendar.date(byAdding: .year, value: recurrenceInterval, to: currentDue)
    }

    if let endDate = recurrenceEndDate, let next = nextDate, next > endDate {
      return nil
    }

    return nextDate
  }
}
