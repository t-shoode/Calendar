import SwiftUI
import SwiftData

struct EventListView: View {
  let date: Date?
  let events: [EventOccurrence]
  var todos: [TodoItem] = []
  var expenses: [Expense] = []
  let onEdit: (EventOccurrence) -> Void
  let onDelete: (EventOccurrence) -> Void
  let onAdd: () -> Void
  var onTodoToggle: ((TodoItem) -> Void)?
  var onTodoTap: ((TodoItem) -> Void)?
  var onExpenseTap: ((Expense) -> Void)?
  var showJumpToToday: Bool = false
  var onJumpToToday: (() -> Void)?

  @State private var showingDetailSheet = false

  private var incompleteTodos: [TodoItem] {
    todos.filter { !$0.isCompleted }
  }

  private var isToday: Bool {
    guard let date else { return false }
    return date.isToday
  }

  private var allItemCount: Int {
    events.count + incompleteTodos.count + expenses.count
  }

  private var contentHeight: CGFloat {
    if allItemCount == 0 { return 112 }
    let visibleRows = min(allItemCount, 3)
    let rowsHeight = CGFloat(visibleRows) * 42
    let extra = allItemCount > 3 ? 28.0 : 0.0
    return min(max(rowsHeight + extra, 112), 176)
  }


  // Helper to determine what to show in the limited space (max 3 items)
  private func getPreviewItems() -> (events: [EventOccurrence], expenses: [Expense], todos: [TodoItem]) {
    var pEvents: [EventOccurrence] = []
    var pExpenses: [Expense] = []
    var pTodos: [TodoItem] = []
    
    var remainingSlots = 3
    
    // 1. Events take priority
    let eventCount = min(events.count, remainingSlots)
    pEvents = Array(events.prefix(eventCount))
    remainingSlots -= eventCount
    
    // 2. Expenses next
    if remainingSlots > 0 {
        let expenseCount = min(expenses.count, remainingSlots)
        pExpenses = Array(expenses.prefix(expenseCount))
        remainingSlots -= expenseCount
    }
    
    // 3. Todos last
    if remainingSlots > 0 {
        let todoCount = min(incompleteTodos.count, remainingSlots)
        pTodos = Array(incompleteTodos.prefix(todoCount))
    }
    
    return (pEvents, pExpenses, pTodos)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header Section
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 1) {
          if let date {
            Text(date.formattedDate)
              .font(.system(size: 18, weight: .black))
              .foregroundColor(Color.textPrimary)
          }

          if isToday {
            Text(Localization.string(.today).uppercased())
              .font(.system(size: 10, weight: .black))
              .foregroundColor(.appAccent)
              .tracking(1)
          } else if let date {
            Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
              .font(.system(size: 10, weight: .semibold))
              .foregroundColor(.textSecondary)
              .tracking(0.8)
          }
        }

        Spacer()

        HStack(spacing: 12) {
          if showJumpToToday, let onJumpToToday {
            Button(action: onJumpToToday) {
              Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.textPrimary)
                .frame(width: 30, height: 30)
            }
            .softControl(cornerRadius: 10, padding: 2)
            .buttonStyle(.plain)
          }

          Button(action: onAdd) {
            Image(systemName: "plus")
              .font(.system(size: 15, weight: .bold))
              .foregroundColor(.appAccent)
              .frame(width: 30, height: 30)
          }
          .softControl(cornerRadius: 10, padding: 2)
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 14)
      .padding(.bottom, 12)

      // Content area
      ScrollView {
          VStack(alignment: .leading, spacing: 10) {
            if events.isEmpty && incompleteTodos.isEmpty && expenses.isEmpty {
              VStack(spacing: 8) {
                  Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 24))
                    .foregroundColor(Color.textTertiary)
                  Text(Localization.string(.noEvents))
                    .font(Typography.caption)
                    .foregroundColor(Color.textSecondary)
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 20)
            } else {
              let previews = getPreviewItems()
              
              ForEach(previews.events) { event in
                CompactEventRow(event: event)
                  .onTapGesture { onEdit(event) }
              }

              ForEach(previews.expenses) { expense in
                CompactExpenseRow(expense: expense)
                  .onTapGesture { onExpenseTap?(expense) }
              }

              ForEach(previews.todos) { todo in
                CompactTodoRow(todo: todo, onToggle: { onTodoToggle?(todo) })
                  .onTapGesture { onTodoTap?(todo) }
              }

              if allItemCount > 3 {
                Button {
                  showingDetailSheet = true
                } label: {
                  Text(Localization.string(.more(allItemCount - 3)).uppercased())
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.appAccent)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
              }
            }
          }
          .padding(.horizontal, 16)
      }
      .frame(height: contentHeight)
      .padding(.bottom, 12)
    }
    .softCard(cornerRadius: 20, padding: 0, shadow: false)
    .padding(.horizontal, 20)
    .sheet(isPresented: $showingDetailSheet) {
      EventListDetailSheet(
        date: date,
        events: events,
        todos: incompleteTodos,
        expenses: expenses,
        isToday: isToday,
        onEdit: onEdit,
        onDelete: onDelete,
        onAdd: onAdd,
        onTodoToggle: onTodoToggle,
        onTodoTap: onTodoTap,
        onExpenseTap: onExpenseTap
      )
      .presentationDetents([.medium, .large])
    }
  }
}

struct CompactEventRow: View {
  let event: EventOccurrence
  var body: some View {
    HStack(spacing: 8) {
      Circle().fill(Color.eventColor(named: event.sourceEvent.color)).frame(width: 8, height: 8)
      Text(event.sourceEvent.title).font(Typography.body).fontWeight(.semibold).foregroundColor(Color.textPrimary).lineLimit(1)
      Spacer()
      Text(event.occurrenceDate.formatted(date: .omitted, time: .shortened)).font(Typography.caption).foregroundColor(Color.textSecondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .softControl(cornerRadius: 10, padding: 0)
  }
}

struct CompactExpenseRow: View {
  let expense: Expense
  var body: some View {
    HStack(spacing: 8) {
      Circle().fill(Color.orange).frame(width: 8, height: 8)
      Text(expense.title).font(Typography.body).fontWeight(.semibold).foregroundColor(Color.textPrimary).lineLimit(1)
      Spacer()
      Text(expense.amount.formatted(.currency(code: expense.currency))).font(Typography.caption).foregroundColor(Color.textSecondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .softControl(cornerRadius: 10, padding: 0)
  }
}

struct CompactTodoRow: View {
  let todo: TodoItem
  let onToggle: () -> Void
  var body: some View {
    HStack(spacing: 8) {
      Button(action: onToggle) {
        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle").font(.system(size: 16)).foregroundColor(priorityColor)
      }.buttonStyle(.plain)
      Text(todo.title).font(Typography.body).fontWeight(.medium).foregroundColor(Color.textPrimary).lineLimit(1)
      Spacer()
      PriorityBadge(priority: todo.priorityEnum)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .softControl(cornerRadius: 10, padding: 0)
  }
  private var priorityColor: Color {
    switch todo.priorityEnum {
    case .high: return .priorityHigh
    case .medium: return .priorityMedium
    case .low: return .priorityLow
    }
  }
}

struct EventListDetailSheet: View {
  @Environment(\.dismiss) private var dismiss
  let date: Date?
  let events: [EventOccurrence]
  let todos: [TodoItem]
  let expenses: [Expense]
  let isToday: Bool
  let onEdit: (EventOccurrence) -> Void
  let onDelete: (EventOccurrence) -> Void
  let onAdd: () -> Void
  var onTodoToggle: ((TodoItem) -> Void)?
  var onTodoTap: ((TodoItem) -> Void)?
  var onExpenseTap: ((Expense) -> Void)?

  var body: some View {
    NavigationStack {
      ZStack {
          Color.backgroundPrimary.ignoresSafeArea()
          ScrollView {
            LazyVStack(spacing: 8) {
              ForEach(events) { event in
                EventRow(event: event).onTapGesture { onEdit(event) }
              }
              
              if !expenses.isEmpty {
                HStack {
                  Text(Localization.string(.tabBudget).uppercased()).font(.system(size: 10, weight: .black)).foregroundColor(Color.textTertiary).tracking(2)
                  Spacer()
                }.padding(.top, 16).padding(.leading, 4)
                ForEach(expenses) { expense in
                  ExpenseRow(expense: expense).onTapGesture { onExpenseTap?(expense) }
                }
              }

              if !todos.isEmpty {
                HStack {
                  Text(Localization.string(.tabTodo).uppercased()).font(.system(size: 10, weight: .black)).foregroundColor(Color.textTertiary).tracking(2)
                  Spacer()
                }.padding(.top, 16).padding(.leading, 4)
                ForEach(todos) { todo in
                  EventListTodoRow(todo: todo, onToggle: { onTodoToggle?(todo) }, onTap: { onTodoTap?(todo) })
                }
              }
            }.padding(20)
          }
      }
      .navigationTitle(isToday ? Localization.string(.today) : (date?.formattedDate ?? ""))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button { dismiss(); onAdd() } label: { Image(systemName: "plus.circle.fill").font(.system(size: 20)) }
        }
      }
    }
  }
}

struct EventRow: View {
  let event: EventOccurrence
  var body: some View {
    HStack(spacing: 12) {
      RoundedRectangle(cornerRadius: 2).fill(Color.eventColor(named: event.sourceEvent.color)).frame(width: 4, height: 32)
      VStack(alignment: .leading, spacing: 2) {
          Text(event.sourceEvent.title).font(Typography.body).fontWeight(.bold)
          Text(event.occurrenceDate.formatted(date: .omitted, time: .shortened)).font(Typography.caption).foregroundColor(.textSecondary)
      }
      Spacer()
    }
    .padding(12)
    .softControl(cornerRadius: 12, padding: 0)
  }
}



struct EventListTodoRow: View {
  let todo: TodoItem
  let onToggle: () -> Void
  let onTap: () -> Void
  var body: some View {
    HStack(spacing: 12) {
      Button(action: onToggle) {
        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle").font(.system(size: 18))
      }.buttonStyle(.plain)
      Text(todo.title).strikethrough(todo.isCompleted)
      Spacer()
      PriorityBadge(priority: todo.priorityEnum)
    }
    .padding(12)
    .softControl(cornerRadius: 12, padding: 0)
    .onTapGesture(perform: onTap)
  }
}
