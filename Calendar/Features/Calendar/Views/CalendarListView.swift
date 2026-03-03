import SwiftUI

/// List mode for the Calendar tab — vertical date column on left, colored event cards on right.
struct CalendarListView: View {
  let currentMonth: Date
  let events: [EventOccurrence]
  let todos: [TodoItem]
  let expenses: [Expense]
  var effectiveTodoDueDate: (TodoItem) -> Date = { $0.dueDate ?? .distantFuture }
  let onEventTap: (EventOccurrence) -> Void
  let onDateSelect: (Date) -> Void

  private let calendar = Calendar.current

  /// All days in the current month that have at least one event or todo.
  private var daysWithContent:
    [(date: Date, events: [EventOccurrence], todos: [TodoItem], expenses: [Expense])]
  {
    let start = currentMonth.startOfMonth
    let end = currentMonth.endOfMonth
    var result: [(Date, [EventOccurrence], [TodoItem], [Expense])] = []
    var day = start
    while day <= end {
      let dayEvents = events.filter { $0.occurrenceDate.isSameDay(as: day) }
      let dayTodos = todos.filter { effectiveTodoDueDate($0).isSameDay(as: day) && !$0.isCompleted }
      let dayExpenses = expenses.filter { $0.date.isSameDay(as: day) }
      
      if !dayEvents.isEmpty || !dayTodos.isEmpty || !dayExpenses.isEmpty {
        result.append((day, dayEvents, dayTodos, dayExpenses))
      }
      day = calendar.date(byAdding: .day, value: 1, to: day)!
    }
    return result
  }

  var body: some View {
    if daysWithContent.isEmpty {
      emptyState
    } else {
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(daysWithContent, id: \.date) { entry in
            CalendarListDayRow(
              date: entry.date,
              events: entry.events,
              todos: entry.todos,
              expenses: entry.expenses,
              isToday: entry.date.isToday,
              onEventTap: onEventTap,
              onDateSelect: onDateSelect
            )

            if entry.date != daysWithContent.last?.date {
              Divider()
                .padding(.leading, 72)
            }
          }
        }
        .padding(.horizontal, 16)
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Spacer()
      Image(systemName: "calendar")
        .font(.system(size: 40))
        .foregroundColor(Color.textTertiary)
      Text(Localization.string(.noEvents))
        .font(Typography.body)
        .foregroundColor(Color.textSecondary)
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }
}

// MARK: - Day Row

private struct CalendarListDayRow: View {
  let date: Date
  let events: [EventOccurrence]
  let todos: [TodoItem]
  let expenses: [Expense]
  let isToday: Bool
  let onEventTap: (EventOccurrence) -> Void
  let onDateSelect: (Date) -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      // Date column
      VStack(spacing: 2) {
        Text(date.formatted(.dateTime.day()))
          .font(.system(size: 22, weight: isToday ? .bold : .medium))
          .foregroundColor(isToday ? .appAccent : Color.textPrimary)

        Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(isToday ? .appAccent : Color.textTertiary)
      }
      .frame(width: 48)
      .padding(.vertical, 12)
      .onTapGesture { onDateSelect(date) }

      // Events column
      VStack(spacing: 6) {
        ForEach(events) { event in
          CalendarListEventCard(event: event)
            .onTapGesture { onEventTap(event) }
        }
        
        ForEach(expenses) { expense in
          CalendarListExpenseCard(expense: expense)
        }

        ForEach(todos) { todo in
          CalendarListTodoCard(todo: todo)
        }
      }
      .padding(.vertical, 10)
    }
  }
}

// MARK: - Event Card

private struct CalendarListEventCard: View {
  let event: EventOccurrence

  var body: some View {
    HStack(spacing: 10) {
      // Color bar
      RoundedRectangle(cornerRadius: 2)
        .fill(Color.eventColor(named: event.sourceEvent.color))
        .frame(width: 4)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(event.sourceEvent.title)
            .font(Typography.headline)
            .foregroundColor(Color.textPrimary)
            .lineLimit(1)

          if event.sourceEvent.isHoliday {
            Image(systemName: "star.fill")
              .font(.system(size: 10))
              .foregroundColor(.eventTeal)
          }
        }

        Text(event.occurrenceDate.formatted(date: .omitted, time: .shortened))
          .font(Typography.caption)
          .foregroundColor(Color.textSecondary)

        if let notes = event.sourceEvent.notes, !notes.isEmpty {
          Text(notes)
            .font(Typography.caption)
            .foregroundColor(Color.textTertiary)
            .lineLimit(2)
        }
      }

      Spacer()
    }
    .padding(12)
    .background(Color.surfaceCard)
    .clipShape(RoundedRectangle(cornerRadius: Spacing.smallRadius))
  }
}

private struct CalendarListExpenseCard: View {
  let expense: Expense
  
  var body: some View {
    HStack(spacing: 10) {
      RoundedRectangle(cornerRadius: 2)
        .fill(Color.orange)
        .frame(width: 4)
        
      VStack(alignment: .leading, spacing: 4) {
        Text(expense.title)
          .font(Typography.headline)
          .foregroundColor(Color.textPrimary)
          .lineLimit(1)
        
        Text(expense.amount.formatted(.currency(code: expense.currency)))
          .font(Typography.caption)
          .foregroundColor(Color.textSecondary)
      }
      
      Spacer()
    }
    .padding(12)
    .background(Color.surfaceCard)
    .clipShape(RoundedRectangle(cornerRadius: Spacing.smallRadius))
  }
}

// MARK: - Todo Card

private struct CalendarListTodoCard: View {
  let todo: TodoItem

  var body: some View {
    HStack(spacing: 10) {
      RoundedRectangle(cornerRadius: 2)
        .fill(Color.orange)
        .frame(width: 4)

      Image(systemName: "circle")
        .font(.system(size: 16))
        .foregroundColor(Color.textTertiary)

      Text(todo.title)
        .font(Typography.body)
        .foregroundColor(Color.textPrimary)
        .lineLimit(1)

      Spacer()
    }
    .padding(12)
    .background(Color.surfaceCard)
    .clipShape(RoundedRectangle(cornerRadius: Spacing.smallRadius))
  }
}
