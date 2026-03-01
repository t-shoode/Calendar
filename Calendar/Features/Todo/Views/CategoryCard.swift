import SwiftUI

struct CategoryCard: View {
  let category: TodoCategory
  let todos: [TodoItem]
  let isExpanded: (TodoCategory) -> Bool
  let onToggleExpand: (TodoCategory) -> Void
  let onEdit: (TodoCategory) -> Void
  let onDelete: (TodoCategory) -> Void
  let onTogglePin: (TodoCategory) -> Void

  // Todo actions
  let onTodoToggle: (TodoItem) -> Void
  let onTodoTap: (TodoItem) -> Void
  let onTodoDelete: (TodoItem) -> Void
  let onTodoTogglePin: (TodoItem) -> Void

  // Drag and Drop callbacks
  let onMoveTodo: (TodoItem, Int) -> Void
  let onDropItem: (String, TodoCategory) -> Bool
  let onTargetedChange: (Bool, TodoCategory) -> Void

  private var filteredTodos: [TodoItem] {
    todos.filter { $0.category?.id == category.id }
  }

  /// Counts todos in this category plus all subcategories recursively
  private var recursiveTodoCount: Int {
    var count = filteredTodos.count
    if let subs = category.subcategories {
      for sub in subs {
        count += countTodosRecursive(in: sub)
      }
    }
    return count
  }

  private func countTodosRecursive(in cat: TodoCategory) -> Int {
    var count = todos.filter { $0.category?.id == cat.id }.count
    if let subs = cat.subcategories {
      for sub in subs {
        count += countTodosRecursive(in: sub)
      }
    }
    return count
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if category.depth == 0 {
          categoryContent
          .softCard(cornerRadius: 16, padding: 12, shadow: true)
          .padding(.bottom, 8)
      } else {
          categoryContent
              .padding(.leading, 12)
              .overlay(alignment: .leading) {
                  Rectangle()
                      .fill(Color.eventColor(named: category.color).opacity(0.3))
                      .frame(width: 2)
                      .padding(.leading, 4)
                      .padding(.vertical, 4)
              }
      }
    }
  }

  @ViewBuilder
  private var categoryContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button(action: { onToggleExpand(category) }) {
        HStack(spacing: 12) {
          Image(systemName: isExpanded(category) ? "chevron.down" : "chevron.right")
            .font(.system(size: category.depth == 0 ? 14 : 12, weight: .bold))
            .foregroundColor(Color.eventColor(named: category.color))

          Text(category.name)
            .font(category.depth == 0 ? Typography.headline : Typography.subheadline)
            .fontWeight(.bold)
            .foregroundColor(Color.textPrimary)

          Spacer()

          if recursiveTodoCount > 0 || !(category.subcategories?.isEmpty ?? true) {
            Text("\(recursiveTodoCount)")
              .font(Typography.badge)
              .foregroundColor(Color.textTertiary)
              .padding(.horizontal, 8)
              .padding(.vertical, 2)
              .softChip()
              .clipShape(Capsule())
          }
        }
      }
      .buttonStyle(.plain)
      .padding(.vertical, 8)
      .padding(.horizontal, category.depth == 0 ? 4 : 0)
      .contextMenu {
        Button(action: { onTogglePin(category) }) {
          Label(category.isPinned ? "Unpin" : "Pin", systemImage: category.isPinned ? "pin.slash" : "pin")
        }
        Button(action: { onEdit(category) }) {
          Label("Edit", systemImage: "pencil")
        }
        Button(role: .destructive, action: { onDelete(category) }) {
          Label("Delete", systemImage: "trash")
        }
      }

      if isExpanded(category) {
        VStack(alignment: .leading, spacing: 8) {
          if let subcategories = category.subcategories?.sorted(by: { $0.sortOrder < $1.sortOrder }),
            !subcategories.isEmpty
          {
            ForEach(subcategories) { sub in
              CategoryCard(
                category: sub,
                todos: todos,
                isExpanded: isExpanded,
                onToggleExpand: onToggleExpand,
                onEdit: onEdit,
                onDelete: onDelete,
                onTogglePin: onTogglePin,
                onTodoToggle: onTodoToggle,
                onTodoTap: onTodoTap,
                onTodoDelete: onTodoDelete,
                onTodoTogglePin: onTodoTogglePin,
                onMoveTodo: onMoveTodo,
                onDropItem: onDropItem,
                onTargetedChange: onTargetedChange
              )
            }
          }

          if !filteredTodos.isEmpty {
            ForEach(filteredTodos) { todo in
              todoRowView(todo)
            }
          }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
      }
    }
  }

  @ViewBuilder
  private func todoRowView(_ todo: TodoItem) -> some View {
    TodoRow(
      todo: todo,
      onToggle: { onTodoToggle(todo) },
      onTap: { onTodoTap(todo) },
      onDelete: { onTodoDelete(todo) },
      onSubtaskToggle: { onTodoToggle($0) },
      onSubtaskTap: { onTodoTap($0) },
      onSubtaskDelete: { onTodoDelete($0) }
    )
  }
}
