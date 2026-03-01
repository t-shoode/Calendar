import SwiftUI

struct MonthView: View {
  let currentMonth: Date
  let selectedDate: Date?
  let events: [EventOccurrence]
  var todos: [TodoItem] = []
  var expenses: [Expense] = []
  var effectiveTodoDueDate: (TodoItem) -> Date = { $0.dueDate ?? .distantFuture }
  let onSelectDate: (Date) -> Void

  private let calendar = Calendar.current
  private let daysInWeek = 7
  private let totalRows = 6  // Always 6 rows for consistent layout

  private var days: [Date] {
    let startOfMonth = currentMonth.startOfMonth
    let endOfMonth = currentMonth.endOfMonth

    let firstWeekday = calendar.component(.weekday, from: startOfMonth)
    let leadingEmptyDays = (firstWeekday + 5) % 7

    var allDays: [Date] = []

    // Fill leading days from previous month
    if leadingEmptyDays > 0 {
      for i in stride(from: leadingEmptyDays, through: 1, by: -1) {
        if let prevDate = calendar.date(byAdding: .day, value: -i, to: startOfMonth) {
          allDays.append(prevDate)
        }
      }
    }

    // Fill current month days
    var currentDate = startOfMonth
    while currentDate <= endOfMonth {
      allDays.append(currentDate)
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
    }

    // Fill trailing days from next month
    let totalCells = totalRows * daysInWeek
    let remainingCells = totalCells - allDays.count
    if remainingCells > 0 {
      var nextDate = calendar.date(byAdding: .day, value: 1, to: endOfMonth)!
      for _ in 0..<remainingCells {
        allDays.append(nextDate)
        nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate)!
      }
    }

    return allDays
  }

  var body: some View {
    LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: daysInWeek), spacing: 2
    ) {
      ForEach(Array(days.enumerated()), id: \.offset) { _, date in
        let isCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
        let isSelected = selectedDate != nil && date.isSameDay(as: selectedDate!)
        let isToday = date.isToday

        DayCell(
          date: date,
          isCurrentMonth: isCurrentMonth,
          isSelected: isSelected,
          isToday: isToday,
          events: isCurrentMonth ? eventsForDate(date) : [],
          todos: isCurrentMonth ? todosForDate(date) : [],
          expenses: isCurrentMonth ? expensesForDate(date) : []
        )
        .onTapGesture {
          onSelectDate(date)
        }
      }
    }
    .padding(.horizontal, 16)
  }

  private func eventsForDate(_ date: Date) -> [EventOccurrence] {
    events.filter { $0.occurrenceDate.isSameDay(as: date) }
  }

  private func todosForDate(_ date: Date) -> [TodoItem] {
    todos.filter { effectiveTodoDueDate($0).isSameDay(as: date) && !$0.isCompleted }
  }

  private func expensesForDate(_ date: Date) -> [Expense] {
    expenses.filter { $0.date.isSameDay(as: date) }
  }
}
