import SwiftUI
import SwiftData

/// Timeline mode for the Calendar tab — horizontal week strip + vertical hourly axis with event blocks.
struct CalendarTimelineView: View {
  @Binding var selectedDate: Date
  let events: [EventOccurrence]
  let expenses: [Expense]
  let onEventTap: (EventOccurrence) -> Void
  let onDateSelect: (Date) -> Void
  let currentMonth: Date

  private let startHour = 0
  private let endHour = 24
  private let hourHeight: CGFloat = 56

  private var timelineEvents: [EventOccurrence] {
    events.filter { !$0.sourceEvent.isHoliday && $0.occurrenceDate.isSameDay(as: selectedDate) }
  }

  private var timelineExpenses: [Expense] {
    expenses.filter { $0.date.isSameDay(as: selectedDate) }
  }

  private var allDayEvents: [EventOccurrence] {
    events.filter { $0.sourceEvent.isHoliday && $0.occurrenceDate.isSameDay(as: selectedDate) }
  }

  var body: some View {
    VStack(spacing: 0) {
      WeekStrip(
        selectedDate: Binding(
          get: { selectedDate },
          set: { date in
            selectedDate = date
            onDateSelect(date)
          }
        ), currentMonth: currentMonth)


      Divider()

      // Hourly timeline
      GeometryReader { geometry in
        let totalWidth = geometry.size.width
        let holidayWidth = totalWidth * 0.175
        let timelineWidth = totalWidth - holidayWidth

        HStack(spacing: 0) {
          ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
              // Column 1: Timeline Section
              ZStack(alignment: .topLeading) {
                // Hour grid
                VStack(spacing: 0) {
                  ForEach(startHour..<endHour, id: \.self) { hour in
                    HStack(alignment: .top, spacing: 8) {
                      Text(hourLabel(hour))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(Color.textTertiary)
                        .frame(width: 44, alignment: .trailing)

                      VStack(spacing: 0) {
                        Divider()
                        Spacer()
                      }
                    }
                    .frame(height: hourHeight)
                    .id(hour)
                  }
                }

                // Event blocks
                ForEach(timelineEvents) { event in
                  TimelineEventBlock(
                    event: event,
                    hourHeight: hourHeight,
                    startHour: startHour
                  )
                  .onTapGesture { onEventTap(event) }
                }

                // Expense blocks
                ForEach(timelineExpenses) { expense in
                  TimelineExpenseBlock(
                    expense: expense,
                    hourHeight: hourHeight,
                    startHour: startHour
                  )
                }
              }
              .frame(width: timelineWidth)
            }
            .onAppear {
              let targetHour = Calendar.current.component(.hour, from: Date())
              withAnimation {
                proxy.scrollTo(max(targetHour - 1, 0), anchor: .top)
              }
            }
          }

          // Column 3: Holidays Section (Sticky)
          VStack(spacing: 0) {
            let dayHolidays = allDayEvents

            if !dayHolidays.isEmpty {
              VStack(spacing: 12) {
                Spacer()
                ForEach(dayHolidays) { holiday in
                  Text(holiday.sourceEvent.title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 10)
                    .background(Color.eventTeal)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                }
                Spacer()
              }
              .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
              Spacer()
            }
          }
          .frame(width: holidayWidth)
          .background(Color.backgroundTertiary.opacity(0.2))
        }
      }
      .gesture(
        DragGesture()
          .onEnded { value in
            let threshold: CGFloat = 50
            if value.translation.width < -threshold {
              // Swipe Left -> Next Day
              moveDay(by: 1)
            } else if value.translation.width > threshold {
              // Swipe Right -> Previous Day
              moveDay(by: -1)
            }
          }
      )
    }
  }

  private func moveDay(by offset: Int) {
    if let newDate = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) {
      withAnimation {
        selectedDate = newDate
        onDateSelect(newDate)
      }
    }
  }


  private func hourLabel(_ hour: Int) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat =
      DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current)?.contains("a")
        == true ? "h a" : "HH:mm"
    var components = DateComponents()
    components.hour = hour
    let date = Calendar.current.date(from: components) ?? Date()
    formatter.locale = Locale.current
    return formatter.string(from: date)
  }
}

// MARK: - Event Block

private struct TimelineEventBlock: View {
  let event: EventOccurrence
  let hourHeight: CGFloat
  let startHour: Int

  private var topOffset: CGFloat {
    let cal = Calendar.current
    let hour = cal.component(.hour, from: event.occurrenceDate)
    let minute = cal.component(.minute, from: event.occurrenceDate)
    return CGFloat(hour - startHour) * hourHeight + CGFloat(minute) / 60.0 * hourHeight
  }

  private var blockHeight: CGFloat {
    // Default 1-hour event if no end time
    max(hourHeight * 0.8, 40)
  }

  var body: some View {
    HStack(spacing: 0) {
      RoundedRectangle(cornerRadius: 3)
        .fill(Color.eventColor(named: event.sourceEvent.color))
        .frame(width: 4)

      VStack(alignment: .leading, spacing: 2) {
        Text(event.sourceEvent.title)
          .font(Typography.caption)
          .fontWeight(.semibold)
          .foregroundColor(Color.textPrimary)
          .lineLimit(1)

        Text(event.occurrenceDate.formatted(date: .omitted, time: .shortened))
          .font(.system(size: 10))
          .foregroundColor(Color.textSecondary)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)

      Spacer()
    }
    .frame(height: blockHeight)
    .background(Color.eventColor(named: event.sourceEvent.color).opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .padding(.leading, 60)  // After the hour label column
    .offset(y: topOffset)
  }
}

private struct TimelineExpenseBlock: View {
  let expense: Expense
  let hourHeight: CGFloat
  let startHour: Int

  private var topOffset: CGFloat {
    let cal = Calendar.current
    let hour = cal.component(.hour, from: expense.date)
    let minute = cal.component(.minute, from: expense.date)
    return CGFloat(hour - startHour) * hourHeight + CGFloat(minute) / 60.0 * hourHeight
  }

  private var blockHeight: CGFloat {
    // Default size for expense block
    max(hourHeight * 0.6, 30)
  }

  var body: some View {
    HStack(spacing: 0) {
      RoundedRectangle(cornerRadius: 3)
        .fill(Color.orange)
        .frame(width: 4)

      VStack(alignment: .leading, spacing: 2) {
        Text(expense.title)
          .font(Typography.caption)
          .fontWeight(.semibold)
          .foregroundColor(Color.textPrimary)
          .lineLimit(1)

        Text(expense.amount.formatted(.currency(code: expense.currency)))
          .font(.system(size: 10))
          .foregroundColor(Color.textSecondary)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)

      Spacer()
    }
    .frame(height: blockHeight)
    .background(Color.orange.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .padding(.leading, 60)  // After the hour label column
    .offset(y: topOffset)
  }
}
