import SwiftData
import SwiftUI

// MARK: - Sort Order

enum TodoSortOrder: String, CaseIterable {
  case manual
  case newestFirst
  case oldestFirst

  var label: String {
    switch self {
    case .manual: return Localization.string(.manual)
    case .newestFirst: return Localization.string(.newestFirst)
    case .oldestFirst: return Localization.string(.oldestFirst)
    }
  }
}

// MARK: - Filter

enum TodoFilter: String, CaseIterable {
  case all, queued, completed

  var label: String {
    switch self {
    case .all: return Localization.string(.all)
    case .queued: return Localization.string(.queued)
    case .completed: return Localization.string(.completed)
    }
  }
}

private struct CategoryStats {
  let queued: Int
  let completed: Int

  var total: Int { queued + completed }
  var progress: Double {
    guard total > 0 else { return 0 }
    return Double(completed) / Double(total)
  }
}

struct TodoView: View {
  @StateObject private var viewModel = TodoViewModel()
  @Query(sort: \TodoCategory.createdAt) private var categories: [TodoCategory]
  @Query(sort: \TodoItem.createdAt) private var allTodosRaw: [TodoItem]
  @Environment(\.modelContext) private var modelContext

  @State private var showingAddTodo = false
  @State private var showingAddCategory = false
  @State private var editingTodo: TodoItem?
  @State private var editingCategory: TodoCategory?
  @State private var sortOrder: TodoSortOrder = .manual
  @State private var filter: TodoFilter = .all
  @State private var searchText: String = ""

  private var allTodos: [TodoItem] {
    allTodosRaw.filter { !$0.isSubtask }
  }

  private var filteredTodos: [TodoItem] {
    var result = allTodos
    if !searchText.isEmpty {
      result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    switch filter {
    case .all: break
    case .queued: result = result.filter { !$0.isCompleted }
    case .completed: result = result.filter { $0.isCompleted }
    }
    return sortTodos(result)
  }

  private var queuedTodosForLoose: [TodoItem] {
    let base = allTodos.filter { !$0.isCompleted }
    if searchText.isEmpty { return base }
    return base.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
  }

  private var looseTodos: [TodoItem] {
    viewModel.selectLooseTodos(from: queuedTodosForLoose)
  }

  private var totalCount: Int { allTodos.count }
  private var completedCount: Int { allTodos.filter(\.isCompleted).count }
  private var queuedCount: Int { allTodos.filter { !$0.isCompleted }.count }

  private var pinnedRootCategories: [TodoCategory] {
    categories
      .filter { $0.parent == nil && $0.name != TodoViewModel.noCategoryName && $0.isPinned }
      .sorted { $0.sortOrder < $1.sortOrder }
  }

  private var unpinnedRootCategories: [TodoCategory] {
    categories
      .filter { $0.parent == nil && $0.name != TodoViewModel.noCategoryName && !$0.isPinned }
      .sorted { $0.sortOrder < $1.sortOrder }
  }

  var body: some View {
    VStack(spacing: 0) {
      header

      ScrollView {
        VStack(spacing: 16) {
          HStack {
            Picker("", selection: $filter) {
              ForEach(TodoFilter.allCases, id: \.self) { f in
                Text(f.label).tag(f)
              }
            }
            .pickerStyle(.segmented)
            .softControl(cornerRadius: 10, padding: 4)

            sortDropdown
          }
          .padding(.bottom, 4)

          categorySections

          if !looseTodos.isEmpty {
            SectionHeader(title: "Quick List")
            ForEach(looseTodos) { todo in
              todoRow(todo)
            }
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 120)
      }
    }
    .overlay(alignment: .bottomTrailing) {
      Menu {
        Button(action: { showingAddTodo = true }) {
          Label(Localization.string(.addTodo), systemImage: "checklist")
        }
        Button(action: { showingAddCategory = true }) {
          Label(Localization.string(.addCategory), systemImage: "folder.badge.plus")
        }
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 20, weight: .bold))
          .foregroundColor(.white)
          .frame(width: 56, height: 56)
          .background(Color.accentColor)
          .clipShape(Circle())
          .shadow(color: Color.accentColor.opacity(0.25), radius: 10, x: 0, y: 5)
      }
      .padding(.trailing, 24)
      .padding(.bottom, 100)
    }
    .sheet(isPresented: $showingAddTodo) {
      AddTodoSheet(categories: categories) {
        title, notes, priority, dueDate, reminder, category, recType, recInterval, recDays, recEnd,
        subtasks, repeatInterval, repeatCount in
        viewModel.createTodo(
          title: title,
          notes: notes,
          priority: priority,
          dueDate: dueDate,
          reminderInterval: reminder,
          reminderRepeatInterval: repeatInterval,
          reminderRepeatCount: repeatCount,
          category: category,
          parentTodo: nil,
          recurrenceType: recType,
          recurrenceInterval: recInterval,
          recurrenceDaysOfWeek: recDays,
          recurrenceEndDate: recEnd,
          subtasks: subtasks,
          context: modelContext
        )
      }
    }
    .sheet(isPresented: $showingAddCategory) {
      AddCategorySheet(categories: categories, onSave: { name, color, parentCat in
        viewModel.createCategory(name: name, color: color, parent: parentCat, context: modelContext)
      })
    }
    .sheet(item: $editingCategory) { cat in
      AddCategorySheet(category: cat, categories: categories, onSave: { name, color, parentCat in
        viewModel.updateCategory(cat, name: name, color: color, parent: parentCat, context: modelContext)
      }, onDelete: {
        viewModel.deleteCategory(cat, context: modelContext)
      })
    }
    .sheet(item: $editingTodo) { todo in
      AddTodoSheet(todo: todo, categories: categories) {
        title, notes, priority, dueDate, reminder, category, recType, recInterval, recDays, recEnd,
        subtasks, repeatInterval, repeatCount in
        viewModel.updateTodo(
          todo,
          title: title,
          notes: notes,
          priority: priority,
          dueDate: dueDate,
          reminderInterval: reminder,
          reminderRepeatInterval: repeatInterval,
          reminderRepeatCount: repeatCount,
          category: category,
          recurrenceType: recType,
          recurrenceInterval: recInterval,
          recurrenceDaysOfWeek: recDays,
          recurrenceEndDate: recEnd,
          subtasks: subtasks,
          context: modelContext
        )
      } onDelete: {
        viewModel.deleteTodo(todo, context: modelContext)
      }
    }
    .onAppear {
      viewModel.normalizeCompletionStatesOnLoad(context: modelContext, candidates: allTodos)
    }
    .onChange(of: allTodosRaw.count) { _, _ in
      viewModel.normalizeCompletionStatesOnLoad(context: modelContext, candidates: allTodos)
    }
  }

  private var header: some View {
    VStack(spacing: 16) {
      HStack {
        Text(Localization.string(.tabTodo))
          .font(.system(size: 22, weight: .bold, design: .rounded))
          .foregroundColor(.textPrimary)
        Spacer()
      }

      HStack(spacing: 10) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 14, weight: .bold))
          .foregroundColor(.textSecondary)

        TextField(Localization.string(.search), text: $searchText)
          .font(Typography.body)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .softControl(cornerRadius: 16, padding: 0)

      HStack(spacing: 12) {
        SummaryCard(label: Localization.string(.all), count: totalCount, color: .accentColor)
        SummaryCard(label: Localization.string(.queued), count: queuedCount, color: .priorityMedium)
        SummaryCard(label: Localization.string(.completed), count: completedCount, color: .eventGreen)
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 20)
  }

  @ViewBuilder
  private var categorySections: some View {
    if !pinnedRootCategories.isEmpty {
      SectionHeader(title: Localization.string(.pinned))
      categoryGrid(for: pinnedRootCategories)
    }

    if !unpinnedRootCategories.isEmpty {
      SectionHeader(title: "Categories")
      categoryGrid(for: unpinnedRootCategories)
    }

    if pinnedRootCategories.isEmpty && unpinnedRootCategories.isEmpty {
      emptyStateCard("No categories yet. Add one with the + button.")
    }
  }

  private func categoryGrid(for items: [TodoCategory]) -> some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
      ForEach(items) { category in
        let stats = statsForCategoryTree(category)
        NavigationLink {
          CategoryDetailView(categoryID: category.id, initialSortOrder: sortOrder, initialFilter: filter)
        } label: {
          CategorySummaryCard(category: category, stats: stats)
        }
        .buttonStyle(.plain)
        .contextMenu {
          Button(action: { viewModel.toggleCategoryPin(category, context: modelContext) }) {
            Label(category.isPinned ? "Unpin" : "Pin", systemImage: category.isPinned ? "pin.slash" : "pin")
          }
          Button(action: { editingCategory = category }) {
            Label("Edit", systemImage: "pencil")
          }
          Button(role: .destructive, action: { viewModel.deleteCategory(category, context: modelContext) }) {
            Label("Delete", systemImage: "trash")
          }
        }
      }
    }
  }

  private func todoRow(_ todo: TodoItem) -> some View {
    TodoRow(
      todo: todo,
      onToggle: { viewModel.toggleCompletion(todo, context: modelContext) },
      onTap: { editingTodo = todo },
      onDelete: { viewModel.deleteTodo(todo, context: modelContext) },
      onSubtaskToggle: { subtask in viewModel.toggleCompletion(subtask, context: modelContext) },
      onSubtaskTap: { subtask in editingTodo = subtask },
      onSubtaskDelete: { subtask in viewModel.deleteTodo(subtask, context: modelContext) }
    )
  }

  private func statsForCategoryTree(_ category: TodoCategory) -> CategoryStats {
    let todos = allTodos.filter { todo in
      guard var current = todo.category else { return false }
      while true {
        if current.id == category.id { return true }
        guard let parent = current.parent else { return false }
        current = parent
      }
    }
    let queued = todos.filter { !$0.isCompleted }.count
    let completed = todos.filter(\.isCompleted).count
    return CategoryStats(queued: queued, completed: completed)
  }

  private func sortTodos(_ todos: [TodoItem]) -> [TodoItem] {
    let sorted: [TodoItem]
    switch sortOrder {
    case .manual:
      sorted = todos.sorted { $0.sortOrder < $1.sortOrder }
    case .newestFirst:
      sorted = todos.sorted { $0.createdAt > $1.createdAt }
    case .oldestFirst:
      sorted = todos.sorted { $0.createdAt < $1.createdAt }
    }
    return sorted.sorted { ($0.isPinned ? 0 : 1) < ($1.isPinned ? 0 : 1) }
  }

  private func emptyStateCard(_ title: String) -> some View {
    Text(title)
      .font(Typography.body)
      .foregroundColor(.textSecondary)
      .frame(maxWidth: .infinity, alignment: .center)
      .softCard(cornerRadius: 14, padding: 18, shadow: false)
  }

  private var sortDropdown: some View {
    Menu {
      ForEach(TodoSortOrder.allCases, id: \.self) { order in
        Button(action: { sortOrder = order }) {
          HStack {
            Text(order.label)
            if sortOrder == order { Image(systemName: "checkmark") }
          }
        }
      }
    } label: {
      Image(systemName: "line.3.horizontal.decrease.circle")
        .font(.system(size: 18))
        .foregroundColor(.accentColor)
        .padding(8)
        .softControl(cornerRadius: 16, padding: 0)
    }
  }
}

private struct CategoryDetailView: View {
  let categoryID: UUID

  @StateObject private var viewModel = TodoViewModel()
  @Query(sort: \TodoCategory.createdAt) private var categories: [TodoCategory]
  @Query(sort: \TodoItem.createdAt) private var allTodosRaw: [TodoItem]
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  @State private var showingAddTodo = false
  @State private var showingAddCategory = false
  @State private var editingTodo: TodoItem?
  @State private var editingCategory: TodoCategory?
  @State private var sortOrder: TodoSortOrder
  @State private var filter: TodoFilter
  @State private var searchText: String = ""

  init(
    categoryID: UUID,
    initialSortOrder: TodoSortOrder = .manual,
    initialFilter: TodoFilter = .all
  ) {
    self.categoryID = categoryID
    _sortOrder = State(initialValue: initialSortOrder)
    _filter = State(initialValue: initialFilter)
  }

  private var currentCategory: TodoCategory? {
    categories.first { $0.id == categoryID }
  }

  private var childCategories: [TodoCategory] {
    categories
      .filter { $0.parent?.id == categoryID }
      .sorted { $0.sortOrder < $1.sortOrder }
  }

  private var allCategoryTodos: [TodoItem] {
    allTodosRaw.filter { !$0.isSubtask && $0.category?.id == categoryID }
  }

  private var filteredCategoryTodos: [TodoItem] {
    var result = allCategoryTodos
    if !searchText.isEmpty {
      result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    switch filter {
    case .all: break
    case .queued: result = result.filter { !$0.isCompleted }
    case .completed: result = result.filter { $0.isCompleted }
    }
    return sortTodos(result)
  }

  var body: some View {
    Group {
      if let category = currentCategory {
        ScrollView {
          VStack(spacing: 16) {
            CategoryDetailHeader(category: category, stats: currentCategoryStats)

            HStack(spacing: 10) {
              Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.textSecondary)

              TextField(Localization.string(.search), text: $searchText)
                .font(Typography.body)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .softControl(cornerRadius: 16, padding: 0)

            HStack {
              Picker("", selection: $filter) {
                ForEach(TodoFilter.allCases, id: \.self) { f in
                  Text(f.label).tag(f)
                }
              }
              .pickerStyle(.segmented)
              .softControl(cornerRadius: 10, padding: 4)

              sortDropdown
            }

            if !childCategories.isEmpty {
              SectionHeader(title: "Subcategories")
              LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(childCategories) { child in
                  NavigationLink {
                    CategoryDetailView(
                      categoryID: child.id,
                      initialSortOrder: sortOrder,
                      initialFilter: filter
                    )
                  } label: {
                    CategorySummaryCard(category: child, stats: statsForCategoryTree(child))
                  }
                  .buttonStyle(.plain)
                  .contextMenu {
                    Button(action: { viewModel.toggleCategoryPin(child, context: modelContext) }) {
                      Label(child.isPinned ? "Unpin" : "Pin", systemImage: child.isPinned ? "pin.slash" : "pin")
                    }
                    Button(action: { editingCategory = child }) {
                      Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: {
                      viewModel.deleteCategory(child, context: modelContext)
                    }) {
                      Label("Delete", systemImage: "trash")
                    }
                  }
                }
              }
            }

            SectionHeader(title: "Todos")
            if filteredCategoryTodos.isEmpty {
              emptyStateCard("No todos in this category")
            } else {
              ForEach(filteredCategoryTodos) { todo in
                TodoRow(
                  todo: todo,
                  onToggle: { viewModel.toggleCompletion(todo, context: modelContext) },
                  onTap: { editingTodo = todo },
                  onDelete: { viewModel.deleteTodo(todo, context: modelContext) },
                  onSubtaskToggle: { subtask in viewModel.toggleCompletion(subtask, context: modelContext) },
                  onSubtaskTap: { subtask in editingTodo = subtask },
                  onSubtaskDelete: { subtask in viewModel.deleteTodo(subtask, context: modelContext) }
                )
              }
            }
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 120)
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
              Button(action: { showingAddTodo = true }) {
                Label(Localization.string(.addTodo), systemImage: "checklist")
              }
              Button(action: { showingAddCategory = true }) {
                Label(Localization.string(.addCategory), systemImage: "folder.badge.plus")
              }
              Button(action: { editingCategory = category }) {
                Label("Edit Category", systemImage: "pencil")
              }
            } label: {
              Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
            }
          }
        }
        .sheet(isPresented: $showingAddTodo) {
          AddTodoSheet(categories: categories) {
            title, notes, priority, dueDate, reminder, selectedCategory, recType, recInterval, recDays,
            recEnd, subtasks, repeatInterval, repeatCount in
            let categoryForNewTodo = selectedCategory ?? currentCategory
            viewModel.createTodo(
              title: title,
              notes: notes,
              priority: priority,
              dueDate: dueDate,
              reminderInterval: reminder,
              reminderRepeatInterval: repeatInterval,
              reminderRepeatCount: repeatCount,
              category: categoryForNewTodo,
              parentTodo: nil,
              recurrenceType: recType,
              recurrenceInterval: recInterval,
              recurrenceDaysOfWeek: recDays,
              recurrenceEndDate: recEnd,
              subtasks: subtasks,
              context: modelContext
            )
          }
        }
        .sheet(isPresented: $showingAddCategory) {
          AddCategorySheet(categories: categories, onSave: { name, color, selectedParent in
            viewModel.createCategory(
              name: name,
              color: color,
              parent: selectedParent ?? currentCategory,
              context: modelContext
            )
          })
        }
        .sheet(item: $editingCategory) { cat in
          AddCategorySheet(category: cat, categories: categories, onSave: { name, color, parentCat in
            viewModel.updateCategory(cat, name: name, color: color, parent: parentCat, context: modelContext)
          }, onDelete: {
            let isCurrent = cat.id == categoryID
            viewModel.deleteCategory(cat, context: modelContext)
            if isCurrent {
              dismiss()
            }
          })
        }
        .sheet(item: $editingTodo) { todo in
          AddTodoSheet(todo: todo, categories: categories) {
            title, notes, priority, dueDate, reminder, selectedCategory, recType, recInterval, recDays,
            recEnd, subtasks, repeatInterval, repeatCount in
            viewModel.updateTodo(
              todo,
              title: title,
              notes: notes,
              priority: priority,
              dueDate: dueDate,
              reminderInterval: reminder,
              reminderRepeatInterval: repeatInterval,
              reminderRepeatCount: repeatCount,
              category: selectedCategory,
              recurrenceType: recType,
              recurrenceInterval: recInterval,
              recurrenceDaysOfWeek: recDays,
              recurrenceEndDate: recEnd,
              subtasks: subtasks,
              context: modelContext
            )
          } onDelete: {
            viewModel.deleteTodo(todo, context: modelContext)
          }
        }
        .onAppear {
          viewModel.normalizeCompletionStatesOnLoad(context: modelContext, candidates: allCategoryTodos)
        }
        .onChange(of: allTodosRaw.count) { _, _ in
          viewModel.normalizeCompletionStatesOnLoad(context: modelContext, candidates: allCategoryTodos)
        }
      } else {
        VStack {
          Text("Category not found")
            .font(Typography.headline)
            .foregroundColor(.textSecondary)
        }
      }
    }
  }

  private var currentCategoryStats: CategoryStats {
    let queued = allCategoryTodos.filter { !$0.isCompleted }.count
    let completed = allCategoryTodos.filter(\.isCompleted).count
    return CategoryStats(queued: queued, completed: completed)
  }

  private func statsForCategoryTree(_ category: TodoCategory) -> CategoryStats {
    let todos = allTodosRaw.filter { todo in
      guard !todo.isSubtask, var current = todo.category else { return false }
      while true {
        if current.id == category.id { return true }
        guard let parent = current.parent else { return false }
        current = parent
      }
    }
    let queued = todos.filter { !$0.isCompleted }.count
    let completed = todos.filter(\.isCompleted).count
    return CategoryStats(queued: queued, completed: completed)
  }

  private func sortTodos(_ todos: [TodoItem]) -> [TodoItem] {
    let sorted: [TodoItem]
    switch sortOrder {
    case .manual:
      sorted = todos.sorted { $0.sortOrder < $1.sortOrder }
    case .newestFirst:
      sorted = todos.sorted { $0.createdAt > $1.createdAt }
    case .oldestFirst:
      sorted = todos.sorted { $0.createdAt < $1.createdAt }
    }
    return sorted.sorted { ($0.isPinned ? 0 : 1) < ($1.isPinned ? 0 : 1) }
  }

  private func emptyStateCard(_ title: String) -> some View {
    Text(title)
      .font(Typography.body)
      .foregroundColor(.textSecondary)
      .frame(maxWidth: .infinity, alignment: .center)
      .softCard(cornerRadius: 14, padding: 18, shadow: false)
  }

  private var sortDropdown: some View {
    Menu {
      ForEach(TodoSortOrder.allCases, id: \.self) { order in
        Button(action: { sortOrder = order }) {
          HStack {
            Text(order.label)
            if sortOrder == order { Image(systemName: "checkmark") }
          }
        }
      }
    } label: {
      Image(systemName: "line.3.horizontal.decrease.circle")
        .font(.system(size: 18))
        .foregroundColor(.accentColor)
        .padding(8)
        .softControl(cornerRadius: 16, padding: 0)
    }
  }
}

struct SectionHeader: View {
  let title: String

  var body: some View {
    HStack {
      Text(title)
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundColor(.textTertiary)
      Spacer()
    }
    .padding(.leading, 4)
    .padding(.top, 8)
  }
}

private struct SummaryCard: View {
  let label: String
  let count: Int
  let color: Color

  var body: some View {
    VStack(spacing: 4) {
      Text("\(count)")
        .font(.system(size: 20, weight: .black, design: .rounded))
        .foregroundColor(color)
      Text(label)
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundColor(.textTertiary)
    }
    .frame(maxWidth: .infinity)
    .softCard(cornerRadius: 14, padding: 14, shadow: false)
  }
}

private struct CategorySummaryCard: View {
  let category: TodoCategory
  let stats: CategoryStats

  private var categoryColor: Color {
    Color.eventColor(named: category.color)
  }

  var body: some View {
    HStack(spacing: 12) {
      progressRing

      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
          Text(category.name)
            .font(Typography.subheadline)
            .fontWeight(.bold)
            .lineLimit(1)
            .foregroundColor(.textPrimary)

          if category.isPinned {
            Image(systemName: "pin.fill")
              .font(.system(size: 10))
              .foregroundColor(.textTertiary)
          }
        }

        Text("\(stats.queued) queued • \(stats.completed) completed")
          .font(Typography.caption)
          .foregroundColor(.textSecondary)
          .lineLimit(1)
      }

      Spacer(minLength: 0)
    }
    .softCard(cornerRadius: 14, padding: 12, shadow: true)
  }

  private var progressRing: some View {
    ZStack {
      Circle()
        .stroke(categoryColor.opacity(0.2), lineWidth: 4)
        .frame(width: 34, height: 34)
      Circle()
        .trim(from: 0, to: stats.progress)
        .stroke(categoryColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        .frame(width: 34, height: 34)
        .rotationEffect(.degrees(-90))
      Text("\(stats.total)")
        .font(.system(size: 10, weight: .bold))
        .foregroundColor(.textPrimary)
    }
  }
}

private struct CategoryDetailHeader: View {
  let category: TodoCategory
  let stats: CategoryStats

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(category.name)
        .font(Typography.headline)
        .fontWeight(.bold)
        .foregroundColor(.textPrimary)

      HStack(spacing: 8) {
        Text("\(stats.queued) queued")
          .font(Typography.caption)
          .foregroundColor(.textSecondary)
        Text("•")
          .foregroundColor(.textTertiary)
        Text("\(stats.completed) completed")
          .font(Typography.caption)
          .foregroundColor(.textSecondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .softCard(cornerRadius: 16, padding: 14, shadow: false)
    .overlay(alignment: .topTrailing) {
      Circle()
        .fill(Color.eventColor(named: category.color).opacity(0.3))
        .frame(width: 46, height: 46)
        .padding(16)
    }
  }
}
