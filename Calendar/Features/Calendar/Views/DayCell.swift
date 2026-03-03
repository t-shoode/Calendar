import SwiftUI

struct DayCell: View {
  @Environment(\.colorScheme) private var colorScheme
  let date: Date
  let isCurrentMonth: Bool
  let isSelected: Bool
  let isToday: Bool
  let events: [EventOccurrence]
  var todos: [TodoItem] = []
  var expenses: [Expense] = []

  var body: some View {
    VStack(spacing: 4) {
      ZStack {
          if isCurrentMonth {
              if isSelected {
                  Circle()
                      .fill(Color.appAccent)
                      .frame(width: 36, height: 36)
                      .transition(.scale.combined(with: .opacity))
              } else if isToday {
                  Circle()
                      .strokeBorder(Color.appAccent, lineWidth: 2)
                      .frame(width: 36, height: 36)
              }
          }
          
          Text(date.formattedDay)
            .font(.system(size: 16, weight: isCurrentMonth && (isToday || isSelected) ? .bold : .medium))
            .foregroundColor(textColor)
      }

      HStack(spacing: 3) {
        if isCurrentMonth {
          if !events.isEmpty {
            EventIndicator(events: events)
          }
          if !todos.isEmpty {
            TodoIndicator(count: todos.count)
          }
          if !expenses.isEmpty {
            ExpenseIndicator(count: expenses.count)
          }
        }
      }
      .frame(height: 6)
    }
    .frame(height: 50)
    .frame(maxWidth: .infinity)
    .contentShape(Rectangle())
  }

  private var textColor: Color {
    if !isCurrentMonth {
      return Color.textTertiary.opacity(0.5)
    } else if isSelected {
      return colorScheme == .dark ? .backgroundPrimary : .white
    } else if isToday {
      return .appAccent
    } else {
      return Color.textPrimary
    }
  }
}

struct TodoIndicator: View {
  let count: Int

  var body: some View {
    Circle()
      .fill(Color.statusInProgress)
      .frame(width: 5, height: 5)
  }
}

struct ExpenseIndicator: View {
  let count: Int
  
  var body: some View {
    Circle()
      .fill(Color.orange)
      .frame(width: 5, height: 5)
  }
}
