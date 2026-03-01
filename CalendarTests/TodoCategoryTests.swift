import XCTest
import SwiftData
@testable import Calendar

final class TodoCategoryTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var viewModel: TodoViewModel!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: TodoCategory.self, TodoItem.self, configurations: config)
        context = ModelContext(container)
        viewModel = TodoViewModel()
    }

    func testCategoryNestingDepth() throws {
        let root = TodoCategory(name: "Root")
        context.insert(root)
        
        let child = TodoCategory(name: "Child")
        context.insert(child)
        child.parent = root
        
        let grandchild = TodoCategory(name: "Grandchild")
        context.insert(grandchild)
        grandchild.parent = child
        
        XCTAssertEqual(root.depth, 0)
        XCTAssertEqual(child.depth, 1)
        XCTAssertEqual(grandchild.depth, 2)
        
        XCTAssertTrue(root.canAcceptChild())
        XCTAssertTrue(child.canAcceptChild())
        XCTAssertFalse(grandchild.canAcceptChild())
    }

    func testCircularNestingPrevention() throws {
        let cat1 = TodoCategory(name: "Cat 1")
        context.insert(cat1)
        
        let cat2 = TodoCategory(name: "Cat 2")
        context.insert(cat2)
        cat2.parent = cat1
        
        // Try to set cat1's parent to cat2 via viewModel
        viewModel.updateCategory(cat1, name: "Cat 1", color: "blue", parent: cat2, context: context)
        
        XCTAssertNil(cat1.parent, "Should prevent circular nesting")
    }

    func testCreateTodoPersistsSubtasks() throws {
        viewModel.createTodo(
            title: "Parent",
            notes: nil,
            priority: .medium,
            dueDate: nil,
            reminderInterval: nil,
            reminderRepeatInterval: nil,
            reminderRepeatCount: nil,
            category: nil,
            parentTodo: nil,
            recurrenceType: nil,
            recurrenceInterval: 1,
            recurrenceDaysOfWeek: nil,
            recurrenceEndDate: nil,
            subtasks: ["Sub 1", "Sub 2"],
            context: context
        )

        let parents = try context.fetch(FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.parentTodo == nil }
        ))
        XCTAssertEqual(parents.count, 1)

        let parent = try XCTUnwrap(parents.first)
        let subtaskTitles = (parent.subtasks ?? []).map(\.title).sorted()
        XCTAssertEqual(subtaskTitles, ["Sub 1", "Sub 2"])
    }

    func testUpdateTodoSyncsSubtasks() throws {
        let parent = TodoItem(title: "Parent", priority: .medium)
        let first = TodoItem(title: "First", priority: .medium, parentTodo: parent)
        let second = TodoItem(title: "Second", priority: .medium, parentTodo: parent)
        context.insert(parent)
        context.insert(first)
        context.insert(second)
        try context.save()

        viewModel.updateTodo(
            parent,
            title: parent.title,
            notes: parent.notes,
            priority: parent.priorityEnum,
            dueDate: parent.dueDate,
            reminderInterval: parent.reminderInterval,
            reminderRepeatInterval: parent.reminderRepeatInterval,
            reminderRepeatCount: parent.reminderRepeatCount,
            category: parent.category,
            recurrenceType: parent.recurrenceTypeEnum,
            recurrenceInterval: parent.recurrenceInterval,
            recurrenceDaysOfWeek: parent.recurrenceDaysOfWeek,
            recurrenceEndDate: parent.recurrenceEndDate,
            subtasks: ["Updated"],
            context: context
        )

        XCTAssertEqual(parent.subtasks?.count, 1)
        XCTAssertEqual(parent.subtasks?.first?.title, "Updated")

        viewModel.updateTodo(
            parent,
            title: parent.title,
            notes: parent.notes,
            priority: parent.priorityEnum,
            dueDate: parent.dueDate,
            reminderInterval: parent.reminderInterval,
            reminderRepeatInterval: parent.reminderRepeatInterval,
            reminderRepeatCount: parent.reminderRepeatCount,
            category: parent.category,
            recurrenceType: parent.recurrenceTypeEnum,
            recurrenceInterval: parent.recurrenceInterval,
            recurrenceDaysOfWeek: parent.recurrenceDaysOfWeek,
            recurrenceEndDate: parent.recurrenceEndDate,
            subtasks: ["Updated", "New 2", "New 3"],
            context: context
        )

        XCTAssertEqual(parent.subtasks?.count, 3)
        let titles = (parent.subtasks ?? []).map(\.title).sorted()
        XCTAssertEqual(titles, ["New 2", "New 3", "Updated"])
    }

    func testTodoWithoutSubtasksToggleWorksAsBefore() throws {
        let todo = TodoItem(title: "Standalone", priority: .medium)
        context.insert(todo)
        try context.save()

        viewModel.toggleCompletion(todo, context: context)

        XCTAssertTrue(todo.isCompleted)
        XCTAssertNotNil(todo.completedAt)
    }

    func testTodoWithSubtasksParentNotDirectlyToggled() throws {
        let parent = makeParentWithSubtasks(["A", "B"])

        viewModel.toggleCompletion(parent, context: context)

        XCTAssertFalse(parent.isCompleted)
        XCTAssertNil(parent.completedAt)
    }

    func testSubtaskToggleRecomputesParentCompletionFalseToTrue() throws {
        let parent = makeParentWithSubtasks(["A", "B"])
        let subtasks = try XCTUnwrap(parent.subtasks)
        let first = try XCTUnwrap(subtasks.first(where: { $0.title == "A" }))
        let second = try XCTUnwrap(subtasks.first(where: { $0.title == "B" }))

        viewModel.toggleSubtaskCompletion(first, context: context)
        XCTAssertFalse(parent.isCompleted)

        viewModel.toggleSubtaskCompletion(second, context: context)
        XCTAssertTrue(parent.isCompleted)
        XCTAssertNotNil(parent.completedAt)
    }

    func testSubtaskUncheckRecomputesParentTrueToFalse() throws {
        let parent = makeParentWithSubtasks(["A", "B"])
        let subtasks = try XCTUnwrap(parent.subtasks)
        let first = try XCTUnwrap(subtasks.first(where: { $0.title == "A" }))
        let second = try XCTUnwrap(subtasks.first(where: { $0.title == "B" }))

        viewModel.toggleSubtaskCompletion(first, context: context)
        viewModel.toggleSubtaskCompletion(second, context: context)
        XCTAssertTrue(parent.isCompleted)

        viewModel.toggleSubtaskCompletion(first, context: context)
        XCTAssertFalse(parent.isCompleted)
        XCTAssertNil(parent.completedAt)
    }

    func testRecurringParentRolloverTriggersOnlyOnDerivedCompletion() throws {
        let due = Date()
        let parent = TodoItem(
            title: "Recurring Parent",
            priority: .medium,
            dueDate: due,
            recurrenceType: .weekly
        )
        let subtask = TodoItem(title: "Sub", priority: .medium, parentTodo: parent)
        context.insert(parent)
        context.insert(subtask)
        try context.save()

        viewModel.toggleSubtaskCompletion(subtask, context: context)

        let parents = try context.fetch(FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.parentTodo == nil }
        ))
        XCTAssertEqual(parents.count, 2)
        XCTAssertTrue(parent.isCompleted)

        let next = try XCTUnwrap(parents.first(where: { $0.id != parent.id }))
        XCTAssertFalse(next.isCompleted)
        XCTAssertEqual(next.subtasks?.count, 1)
    }

    func testNormalizeOnLoadFixesMismatchedParentState() throws {
        let parent = makeParentWithSubtasks(["A", "B"])
        parent.subtasks?.forEach { $0.isCompleted = true }
        parent.isCompleted = false
        parent.completedAt = nil
        try context.save()

        viewModel.normalizeCompletionStatesOnLoad(context: context, candidates: [parent])

        XCTAssertTrue(parent.isCompleted)
        XCTAssertNotNil(parent.completedAt)
    }

    func testLooseTodoSelectorDeduplicatesAndSorts() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let overdue = TodoItem(title: "Overdue", priority: .high, dueDate: now.addingTimeInterval(-1800))
        let dueSoon = TodoItem(title: "Due Soon", priority: .medium, dueDate: now.addingTimeInterval(3600))
        let uncategorizedNoDue = TodoItem(title: "Uncategorized", priority: .low)
        let later = TodoItem(title: "Later", priority: .medium, dueDate: now.addingTimeInterval(60 * 60 * 96))

        let noCategory = TodoCategory(name: TodoViewModel.noCategoryName, color: "gray")
        context.insert(noCategory)
        overdue.category = noCategory
        dueSoon.category = noCategory
        uncategorizedNoDue.category = nil
        later.category = noCategory

        let selected = viewModel.selectLooseTodos(
            from: [later, uncategorizedNoDue, dueSoon, overdue],
            now: now
        )

        XCTAssertEqual(selected.first?.title, "Overdue")
        XCTAssertTrue(selected.contains(where: { $0.title == "Due Soon" }))
        XCTAssertTrue(selected.contains(where: { $0.title == "Uncategorized" }))
        XCTAssertFalse(selected.contains(where: { $0.title == "Later" }))
    }

    @discardableResult
    private func makeParentWithSubtasks(_ titles: [String]) -> TodoItem {
        let parent = TodoItem(title: "Parent", priority: .medium)
        context.insert(parent)
        for title in titles {
            let subtask = TodoItem(title: title, priority: .medium, parentTodo: parent)
            context.insert(subtask)
        }
        do {
            try context.save()
        } catch {
            XCTFail("Failed to save test data: \(error)")
        }
        return parent
    }
}
