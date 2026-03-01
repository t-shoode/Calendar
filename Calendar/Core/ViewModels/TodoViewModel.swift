import Combine
import SwiftData
import SwiftUI
import WidgetKit

class TodoViewModel: ObservableObject {

  static let noCategoryName = "No Category"

  func createCategory(
    name: String, color: String, parent: TodoCategory? = nil, context: ModelContext
  ) {
    if let parent = parent, parent.depth >= 2 {
      ErrorPresenter.shared.present(message: "Cannot nest category deeper than 3 levels")
      return
    }

    let descriptor = FetchDescriptor<TodoCategory>()
    var existingCount = 0
    do {
      existingCount = try context.fetchCount(descriptor)
    } catch {
      ErrorPresenter.presentOnMain(error)
      existingCount = 0
    }
    let category = TodoCategory(name: name, color: color, sortOrder: existingCount)
    context.insert(category)
    category.parent = parent

    do {
      try context.save()
    } catch {
      ErrorPresenter.shared.present(error)
      return
    }
  }

  func updateCategory(
    _ category: TodoCategory, name: String, color: String, parent: TodoCategory? = nil,
    context: ModelContext
  ) {
    if let parent = parent {
      if parent.id == category.id {
        ErrorPresenter.shared.present(message: "A category cannot be its own parent")
        return
      }
      if parent.depth >= 2 {
        ErrorPresenter.shared.present(message: "Cannot nest category deeper than 3 levels")
        return
      }
      // Check for cycles (basic check: parent shouldn't be a descendant of category)
      var p: TodoCategory? = parent
      while let currentP = p {
        if currentP.id == category.id {
          ErrorPresenter.shared.present(message: "Circular nesting is not allowed")
          return
        }
        p = currentP.parent
      }
    }

    category.name = name
    category.color = color
    category.parent = parent
    do {
      try context.save()
    } catch {
      ErrorPresenter.shared.present(error)
    }
  }

  func moveCategory(
    _ category: TodoCategory, toParent newParent: TodoCategory?, context: ModelContext
  ) {
    updateCategory(
      category, name: category.name, color: category.color, parent: newParent, context: context)
  }

  func deleteCategory(_ category: TodoCategory, context: ModelContext) {
    context.delete(category)
    do {
      try context.save()
    } catch {
      ErrorPresenter.shared.present(error)
    }
  }

  func toggleCategoryPin(_ category: TodoCategory, context: ModelContext) {
    category.isPinned.toggle()
    do {
      try context.save()
    } catch {
      ErrorPresenter.shared.present(error)
    }
  }

  func reparentCategory(_ source: TodoCategory, into target: TodoCategory, context: ModelContext) {
    // Don't reparent into self
    guard source.id != target.id else { return }
    // Don't reparent if already a child of target
    guard source.parent?.id != target.id else { return }
    // Respect max depth (target.depth + 1 must be < 3)
    guard target.depth < 2 else {
      ErrorPresenter.shared.present(message: "Cannot nest categories deeper than 2 levels")
      return
    }
    // Don't allow reparenting a parent into its own child
    var ancestor: TodoCategory? = target
    while let a = ancestor {
      if a.id == source.id { return }
      ancestor = a.parent
    }

    source.parent = target
    // Set sortOrder to be last among target's subcategories
    let siblingCount = target.subcategories?.count ?? 0
    source.sortOrder = siblingCount

    do {
      try context.save()
    } catch {
      ErrorPresenter.shared.present(error)
    }
  }

  func toggleTodoPin(_ todo: TodoItem, context: ModelContext) {
    todo.isPinned.toggle()
    do {
      try context.save()
    } catch {
      ErrorPresenter.shared.present(error)
    }
  }

  func createTodo(
    title: String,
    notes: String?,
    priority: Priority,
    dueDate: Date?,
    reminderInterval: TimeInterval?,
    reminderRepeatInterval: TimeInterval?,
    reminderRepeatCount: Int?,
    category: TodoCategory?,
    parentTodo: TodoItem?,
    recurrenceType: RecurrenceType?,
    recurrenceInterval: Int,
    recurrenceDaysOfWeek: [Int]?,
    recurrenceEndDate: Date?,
    subtasks: [String] = [],
    context: ModelContext
  ) {
    let todo = TodoItem(
      title: title,
      notes: notes,
      priority: priority,
      dueDate: dueDate,
      reminderInterval: reminderInterval,
      reminderRepeatInterval: reminderRepeatInterval,
      reminderRepeatCount: reminderRepeatCount,
      parentTodo: parentTodo,
      recurrenceType: recurrenceType,
      recurrenceInterval: recurrenceInterval,
      recurrenceDaysOfWeek: recurrenceDaysOfWeek,
      recurrenceEndDate: recurrenceEndDate
    )
    context.insert(todo)

    if let category = category {
      todo.category = category
      category.todos?.append(todo)
    }

    for subtaskTitle in normalizedSubtaskTitles(subtasks) {
      let subtask = TodoItem(
        title: subtaskTitle,
        priority: priority,
        parentTodo: todo
      )
      context.insert(subtask)
    }

    do {
      try context.save()
    } catch {
      ErrorPresenter.shared.present(error)
      return
    }

    if dueDate != nil && (reminderInterval != nil || reminderRepeatInterval != nil) {
      NotificationService.shared.scheduleTodoNotification(todo: todo)
    }

    syncTodoCountToWidget(context: context)
    EventViewModel().syncEventsToWidget(context: context)
  }

  func updateTodo(
    _ todo: TodoItem,
    title: String,
    notes: String?,
    priority: Priority,
    dueDate: Date?,
    reminderInterval: TimeInterval?,
    reminderRepeatInterval: TimeInterval?,
    reminderRepeatCount: Int?,
    category: TodoCategory?,
    recurrenceType: RecurrenceType?,
    recurrenceInterval: Int,
    recurrenceDaysOfWeek: [Int]?,
    recurrenceEndDate: Date?,
    subtasks: [String],
    context: ModelContext
  ) {
    todo.title = title
    todo.notes = notes
    todo.priorityEnum = priority
    todo.dueDate = dueDate
    todo.reminderInterval = reminderInterval
    todo.reminderRepeatInterval = reminderRepeatInterval
    todo.reminderRepeatCount = reminderRepeatCount
    todo.category = category
    todo.recurrenceTypeEnum = recurrenceType
    todo.recurrenceInterval = recurrenceInterval
    todo.recurrenceDaysOfWeek = recurrenceDaysOfWeek
    todo.recurrenceEndDate = recurrenceEndDate
    syncSubtasks(for: todo, titles: subtasks, context: context)
    if todo.hasSubtasks {
      recomputeParentCompletionState(for: todo, context: context, allowRecurring: false)
    }
    do {
      try context.save()
    } catch {
      ErrorPresenter.shared.present(error)
      return
    }

    NotificationService.shared.cancelTodoNotification(id: todo.id)
    if dueDate != nil && (reminderInterval != nil || reminderRepeatInterval != nil) {
      NotificationService.shared.scheduleTodoNotification(todo: todo)
    }

    syncTodoCountToWidget(context: context)
    EventViewModel().syncEventsToWidget(context: context)
  }

  func deleteTodo(_ todo: TodoItem, context: ModelContext) {
    let parent = todo.parentTodo
    NotificationService.shared.cancelTodoNotification(id: todo.id)
    context.delete(todo)
    if let parent = parent {
      recomputeParentCompletionState(for: parent, context: context, allowRecurring: false)
    }
    do {
      try context.save()
    } catch {
      ErrorPresenter.shared.present(error)
      return
    }
    syncTodoCountToWidget(context: context)
    EventViewModel().syncEventsToWidget(context: context)
  }

  func toggleCompletion(_ todo: TodoItem, context: ModelContext) {
    if todo.isSubtask {
      toggleSubtaskCompletion(todo, context: context)
      return
    }
    if todo.isParentCompletionDerived {
      return
    }
    toggleStandaloneTodoCompletion(todo, context: context)
  }

  func toggleStandaloneTodoCompletion(_ todo: TodoItem, context: ModelContext) {
    setCompletionState(for: todo, isCompleted: !todo.isCompleted, context: context, allowRecurring: true)
    persistAndSync(context: context)
  }

  func toggleSubtaskCompletion(_ subtask: TodoItem, context: ModelContext) {
    guard subtask.isSubtask else {
      toggleStandaloneTodoCompletion(subtask, context: context)
      return
    }
    setCompletionState(
      for: subtask, isCompleted: !subtask.isCompleted, context: context, allowRecurring: false)
    if let parent = subtask.parentTodo {
      recomputeParentCompletionState(for: parent, context: context)
    }
    persistAndSync(context: context)
  }

  func recomputeParentCompletion(for parent: TodoItem, context: ModelContext) {
    recomputeParentCompletionState(for: parent, context: context)
    persistAndSync(context: context)
  }

  func normalizeCompletionStatesOnLoad(context: ModelContext, candidates: [TodoItem]? = nil) {
    let parents: [TodoItem]
    if let candidates = candidates {
      parents = candidates.filter { !$0.isSubtask && $0.hasSubtasks }
    } else {
      let descriptor = FetchDescriptor<TodoItem>(
        predicate: #Predicate { todo in
          todo.parentTodo == nil
        }
      )
      do {
        parents = try context.fetch(descriptor).filter(\.hasSubtasks)
      } catch {
        ErrorPresenter.shared.present(error)
        return
      }
    }

    var hasChanges = false
    for parent in parents {
      let expected = expectedParentCompletion(for: parent)
      if parent.isCompleted != expected {
        hasChanges = true
      }
      recomputeParentCompletionState(for: parent, context: context, allowRecurring: false)
    }

    if hasChanges {
      persistAndSync(context: context)
    }
  }

  func addSubtask(to parent: TodoItem, title: String, context: ModelContext) {
    let subtask = TodoItem(
      title: title,
      priority: parent.priorityEnum,
      parentTodo: parent
    )
    context.insert(subtask)
    recomputeParentCompletionState(for: parent, context: context, allowRecurring: false)
    do {
      try context.save()
    } catch {
      ErrorPresenter.shared.present(error)
      return
    }
    syncTodoCountToWidget(context: context)
    EventViewModel().syncEventsToWidget(context: context)
  }

  private func normalizedSubtaskTitles(_ titles: [String]) -> [String] {
    titles
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private func syncSubtasks(for todo: TodoItem, titles: [String], context: ModelContext) {
    let normalized = normalizedSubtaskTitles(titles)
    let existing = (todo.subtasks ?? []).sorted { $0.createdAt < $1.createdAt }

    for (index, title) in normalized.enumerated() {
      if index < existing.count {
        existing[index].title = title
      } else {
        let subtask = TodoItem(
          title: title,
          priority: todo.priorityEnum,
          parentTodo: todo
        )
        context.insert(subtask)
      }
    }

    if existing.count > normalized.count {
      for stale in existing[normalized.count...] {
        context.delete(stale)
      }
    }
  }

  private func expectedParentCompletion(for parent: TodoItem) -> Bool {
    guard parent.hasSubtasks else { return parent.isCompleted }
    let allSubtasks = parent.subtasks ?? []
    return !allSubtasks.isEmpty && allSubtasks.allSatisfy(\.isCompleted)
  }

  private func recomputeParentCompletionState(
    for parent: TodoItem, context: ModelContext, allowRecurring: Bool = true
  ) {
    guard parent.hasSubtasks else { return }
    let expected = expectedParentCompletion(for: parent)
    setCompletionState(
      for: parent, isCompleted: expected, context: context, allowRecurring: allowRecurring)
  }

  private func setCompletionState(
    for todo: TodoItem, isCompleted: Bool, context: ModelContext, allowRecurring: Bool
  ) {
    guard todo.isCompleted != isCompleted else { return }
    todo.isCompleted = isCompleted

    if isCompleted {
      todo.completedAt = Date()
      NotificationService.shared.cancelTodoNotification(id: todo.id)

      if allowRecurring {
        createRecurringSuccessorIfNeeded(from: todo, context: context)
      }
    } else {
      todo.completedAt = nil
      if todo.dueDate != nil && (todo.reminderInterval != nil || todo.reminderRepeatInterval != nil) {
        NotificationService.shared.scheduleTodoNotification(todo: todo)
      }
    }
  }

  private func createRecurringSuccessorIfNeeded(from todo: TodoItem, context: ModelContext) {
    guard todo.isRecurring, let nextDue = todo.nextDueDate() else { return }

    let newTodo = TodoItem(
      title: todo.title,
      notes: todo.notes,
      priority: todo.priorityEnum,
      dueDate: nextDue,
      reminderInterval: todo.reminderInterval,
      reminderRepeatInterval: todo.reminderRepeatInterval,
      reminderRepeatCount: todo.reminderRepeatCount,
      category: todo.category,
      parentTodo: nil,
      recurrenceType: todo.recurrenceTypeEnum,
      recurrenceInterval: todo.recurrenceInterval,
      recurrenceDaysOfWeek: todo.recurrenceDaysOfWeek,
      recurrenceEndDate: todo.recurrenceEndDate
    )
    context.insert(newTodo)

    if let subtasks = todo.subtasks {
      for subtask in subtasks {
        let newSubtask = TodoItem(
          title: subtask.title,
          notes: subtask.notes,
          priority: subtask.priorityEnum,
          dueDate: nil,
          reminderInterval: nil,
          category: nil,
          parentTodo: newTodo
        )
        context.insert(newSubtask)
      }
    }

    if newTodo.reminderInterval != nil || newTodo.reminderRepeatInterval != nil {
      NotificationService.shared.scheduleTodoNotification(todo: newTodo)
    }
  }

  private func persistAndSync(context: ModelContext) {
    do {
      try context.save()
    } catch {
      ErrorPresenter.shared.present(error)
      return
    }
    syncTodoCountToWidget(context: context)
    EventViewModel().syncEventsToWidget(context: context)
  }

  func selectLooseTodos(
    from todos: [TodoItem], now: Date = Date(), dueSoonHours: Int = 72, limit: Int = 6
  ) -> [TodoItem] {
    let dueSoonCutoff = now.addingTimeInterval(TimeInterval(dueSoonHours * 3600))
    let queuedTodos = todos.filter { !$0.isCompleted && !$0.isSubtask }

    let uncategorized = queuedTodos.filter { todo in
      todo.category == nil || todo.category?.name == TodoViewModel.noCategoryName
    }
    let dueSoon = queuedTodos.filter { todo in
      guard let dueDate = todo.dueDate else { return false }
      return dueDate <= dueSoonCutoff
    }

    var merged: [UUID: TodoItem] = [:]
    for todo in uncategorized + dueSoon {
      merged[todo.id] = todo
    }

    return merged.values
      .sorted { lhs, rhs in
        let lhsOverdue = (lhs.dueDate ?? .distantFuture) < now
        let rhsOverdue = (rhs.dueDate ?? .distantFuture) < now
        if lhsOverdue != rhsOverdue { return lhsOverdue && !rhsOverdue }

        let lhsDue = lhs.dueDate ?? .distantFuture
        let rhsDue = rhs.dueDate ?? .distantFuture
        if lhsDue != rhsDue { return lhsDue < rhsDue }

        if lhs.priorityEnum.sortOrder != rhs.priorityEnum.sortOrder {
          return lhs.priorityEnum.sortOrder < rhs.priorityEnum.sortOrder
        }
        if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
        return lhs.createdAt > rhs.createdAt
      }
      .prefix(limit)
      .map { $0 }
  }

  func createDefaultCategoryIfNeeded(context: ModelContext) {
    let descriptor = FetchDescriptor<TodoCategory>(
      predicate: #Predicate { $0.name == "No Category" }
    )

    do {
      let existing = try context.fetch(descriptor)
      if existing.isEmpty {
        let defaultCategory = TodoCategory(name: TodoViewModel.noCategoryName, color: "gray")
        context.insert(defaultCategory)
        do {
          try context.save()
        } catch {
          ErrorPresenter.shared.present(error)
        }
      }
    } catch {
      let defaultCategory = TodoCategory(name: TodoViewModel.noCategoryName, color: "gray")
      context.insert(defaultCategory)
      do {
        try context.save()
      } catch {
        ErrorPresenter.shared.present(error)
      }
    }
  }

  func cleanupCompletedTodos(context: ModelContext) {
    let calendar = Calendar.current
    let now = Date()

    guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return }

    let descriptor = FetchDescriptor<TodoItem>(
      predicate: #Predicate { todo in
        todo.isCompleted == true && todo.parentTodo == nil
      }
    )

    do {
      let completedTodos = try context.fetch(descriptor)
      for todo in completedTodos {
        if let completedAt = todo.completedAt, completedAt < startOfWeek {
          context.delete(todo)
        }
      }
      do {
        try context.save()
      } catch {
        ErrorPresenter.shared.present(error)
      }
    } catch {
      ErrorPresenter.shared.present(error)
    }
  }

  func rescheduleAllNotifications(context: ModelContext) {
    let now = Date()
    let descriptor = FetchDescriptor<TodoItem>(
      predicate: #Predicate { todo in
        todo.isCompleted == false && todo.parentTodo == nil
      }
    )

    do {
      let todos = try context.fetch(descriptor)
      let todosWithReminders = todos.filter { todo in
        guard let dueDate = todo.dueDate,
          let reminder = todo.reminderInterval,
          reminder > 0
        else { return false }
        let notifyDate = dueDate.addingTimeInterval(-reminder)
        return notifyDate > now
      }
      NotificationService.shared.syncTodoNotifications(todos: todosWithReminders)
    } catch {
      ErrorPresenter.shared.present(error)
    }
  }

  func syncTodoCountToWidget(context: ModelContext, userDefaults: UserDefaults? = nil) {
    let descriptor = FetchDescriptor<TodoItem>(
      predicate: #Predicate { todo in
        todo.isCompleted == false && todo.parentTodo == nil
      }
    )
    var count = 0
    var todos: [TodoItem] = []
    do {
      count = try context.fetchCount(descriptor)
      todos = try context.fetch(descriptor)
    } catch {
      ErrorPresenter.shared.present(error)
      count = 0
    }

    // Share upcoming todos (next 7 days) for widget
    let calendar = Calendar.current
    let now = Date()
    let weekLater = calendar.date(byAdding: .day, value: 7, to: now)!

    let upcomingTodos =
      todos
      .filter { todo in
        guard let dueDate = todo.dueDate else { return false }
        return dueDate >= now && dueDate <= weekLater
      }
      .sorted { ($0.dueDate ?? now) < ($1.dueDate ?? now) }
      .prefix(2)
      .map { todo -> WidgetTodoItem in
        WidgetTodoItem(
          id: todo.id.uuidString,
          title: todo.title,
          dueDate: todo.dueDate ?? now,
          priority: todo.priorityEnum.rawValue,
          categoryColor: todo.category?.color ?? "gray"
        )
      }

    let defaults = userDefaults ?? UserDefaults(suiteName: Constants.Storage.appGroupIdentifier)
    defaults?.set(count, forKey: "incompleteTodoCount")

    // Share upcoming todos
    if let encoded = try? JSONEncoder().encode(Array(upcomingTodos)) {
      defaults?.set(encoded, forKey: "widgetUpcomingTodos")
    }

    WidgetCenter.shared.reloadTimelines(ofKind: "CalendarWidget")
    WidgetCenter.shared.reloadTimelines(ofKind: "CombinedWidget")
  }
}

// MARK: - Widget Data Models

struct WidgetTodoItem: Codable {
  let id: String
  let title: String
  let dueDate: Date
  let priority: String
  let categoryColor: String
}
