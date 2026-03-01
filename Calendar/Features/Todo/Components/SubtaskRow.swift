import SwiftUI

struct SubtaskRow: View {
  let subtask: TodoItem
  let onToggle: () -> Void
  let onTap: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      TodoCheckbox(
        isCompleted: subtask.isCompleted,
        priority: subtask.priorityEnum,
        action: onToggle
      )

      Text(subtask.title)
        .font(.system(size: 14))
        .strikethrough(subtask.isCompleted)
        .foregroundColor(subtask.isCompleted ? .secondary : .primary)
        .lineLimit(1)

      Spacer()

      Button(action: onDelete) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 16))
          .foregroundColor(.secondary.opacity(0.5))
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(.ultraThinMaterial.opacity(0.35))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .contentShape(Rectangle())
    .onTapGesture(perform: onTap)
  }
}
