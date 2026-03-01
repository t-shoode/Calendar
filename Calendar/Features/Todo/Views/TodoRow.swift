import SwiftUI

struct TodoRow: View {
  let todo: TodoItem
  let onToggle: () -> Void
  let onTap: () -> Void
  let onDelete: () -> Void
  let onSubtaskToggle: (TodoItem) -> Void
  let onSubtaskTap: (TodoItem) -> Void
  let onSubtaskDelete: (TodoItem) -> Void

  @State private var isSubtasksExpanded: Bool
  @State private var showSubtaskHint = false

  init(
    todo: TodoItem,
    onToggle: @escaping () -> Void,
    onTap: @escaping () -> Void,
    onDelete: @escaping () -> Void,
    onSubtaskToggle: @escaping (TodoItem) -> Void,
    onSubtaskTap: @escaping (TodoItem) -> Void,
    onSubtaskDelete: @escaping (TodoItem) -> Void
  ) {
    self.todo = todo
    self.onToggle = onToggle
    self.onTap = onTap
    self.onDelete = onDelete
    self.onSubtaskToggle = onSubtaskToggle
    self.onSubtaskTap = onSubtaskTap
    self.onSubtaskDelete = onSubtaskDelete

    let subtaskCount = todo.subtasks?.count ?? 0
    _isSubtasksExpanded = State(initialValue: subtaskCount > 0 && subtaskCount <= 2)
  }

  private var orderedSubtasks: [TodoItem] {
    (todo.subtasks ?? []).sorted { $0.createdAt < $1.createdAt }
  }

  private var subtaskCount: Int { orderedSubtasks.count }

  private var completedSubtaskCount: Int {
    orderedSubtasks.filter(\.isCompleted).count
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 12) {
        TodoCheckbox(
          isCompleted: todo.isCompleted,
          priority: todo.priorityEnum,
          action: handleCheckboxTap
        )

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            Text(todo.title)
              .font(Typography.body)
              .fontWeight(.medium)
              .strikethrough(todo.isCompleted)
              .foregroundColor(todo.isCompleted ? Color.textTertiary : Color.textPrimary)
              .lineLimit(1)

            if todo.isRecurring {
              Image(systemName: "repeat")
                .font(.system(size: 12))
                .foregroundColor(Color.textTertiary)
            }
          }

          HStack(spacing: 8) {
            if let dueDate = todo.dueDate {
              HStack(spacing: 4) {
                Image(systemName: "calendar")
                  .font(.system(size: 10))
                Text(dueDate.formatted(date: .abbreviated, time: .shortened))
                  .font(Typography.caption)
              }
              .foregroundColor(dueDateColor(dueDate))
            }

            if !todo.isCompleted {
              PriorityBadge(priority: todo.priorityEnum)
            }

            if subtaskCount > 0 {
              Text("\(completedSubtaskCount)/\(subtaskCount) subtasks")
                .font(Typography.badge)
                .foregroundColor(.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondaryFill.opacity(0.75))
                .clipShape(Capsule())
                .contentTransition(.numericText())
            }
          }
        }

        Spacer()

        if subtaskCount > 0 {
          Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
              isSubtasksExpanded.toggle()
            }
          } label: {
            Image(systemName: isSubtasksExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
              .font(.system(size: 18, weight: .semibold))
              .foregroundColor(.accentColor)
          }
          .buttonStyle(.plain)
          .pressableScale(0.9)
        }

        if todo.isPinned {
          Image(systemName: "pin.fill")
            .font(.system(size: 10))
            .foregroundColor(Color.textTertiary)
        }
      }
      .contentShape(Rectangle())
      .onTapGesture(perform: onTap)

      if subtaskCount > 0 && isSubtasksExpanded {
        VStack(spacing: 6) {
          ForEach(orderedSubtasks) { subtask in
            SubtaskRow(
              subtask: subtask,
              onToggle: { onSubtaskToggle(subtask) },
              onTap: { onSubtaskTap(subtask) },
              onDelete: { onSubtaskDelete(subtask) }
            )
          }
        }
        .padding(.top, 8)
        .padding(.leading, 28)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }

      if showSubtaskHint {
        Text("Complete all subtasks to finish this todo.")
          .font(Typography.caption)
          .foregroundColor(.textTertiary)
          .padding(.top, 8)
          .padding(.leading, 34)
          .transition(.opacity)
      }
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 14)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color.surfaceCard.opacity(0.9))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(Color.border.opacity(0.25), lineWidth: 0.7)
    )
    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    .animation(.spring(response: 0.28, dampingFraction: 0.86), value: todo.isCompleted)
    .animation(.easeInOut(duration: 0.2), value: completedSubtaskCount)
    .swipeActions(edge: .trailing) {
      Button(role: .destructive, action: onDelete) {
        Label(Localization.string(.delete), systemImage: "trash")
      }
    }
  }

  private func dueDateColor(_ date: Date) -> Color {
    if todo.isCompleted { return Color.textTertiary }
    if date < Date() { return .priorityHigh }
    if Calendar.current.isDateInToday(date) { return .priorityMedium }
    return Color.textSecondary
  }

  private func handleCheckboxTap() {
    if todo.isParentCompletionDerived && !todo.isSubtask {
      withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
        isSubtasksExpanded = true
        showSubtaskHint = true
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        withAnimation(.easeOut(duration: 0.2)) {
          showSubtaskHint = false
        }
      }
      return
    }
    onToggle()
  }
}
