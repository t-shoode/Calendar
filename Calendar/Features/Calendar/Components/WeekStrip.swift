import SwiftUI

/// Reusable horizontal week-day selector strip.
struct WeekStrip: View {
  @Environment(\.colorScheme) private var colorScheme
  @Binding var selectedDate: Date
  var currentMonth: Date = Date()

  private let calendar = Calendar.current

  private var weekDates: [Date] {
    let startOfWeek =
      calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
    return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
  }

  var body: some View {
    HStack(spacing: 0) {
      ForEach(weekDates, id: \.self) { date in
        let isSelected = date.isSameDay(as: selectedDate)
        let isToday = date.isToday

        Button {
          withAnimation(.easeInOut(duration: 0.15)) {
            selectedDate = date
          }
        } label: {
          VStack(spacing: 4) {
            Text(date.formatted(.dateTime.weekday(.narrow)))
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(isSelected ? .appAccent : Color.textTertiary)

            Text(date.formatted(.dateTime.day()))
              .font(.system(size: 16, weight: isSelected ? .bold : .medium))
              .foregroundColor(
                isSelected
                  ? (colorScheme == .dark ? .backgroundPrimary : .white)
                  : isToday
                    ? .appAccent
                    : Color.textPrimary
              )
              .frame(width: 34, height: 34)
              .background(
                Circle()
                  .fill(isSelected ? Color.appAccent : Color.clear)
              )
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }
}
