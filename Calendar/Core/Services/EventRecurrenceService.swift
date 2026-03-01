import Foundation

final class EventRecurrenceService {
  static let shared = EventRecurrenceService()

  private init() {}

  private let maxOccurrencesPerEvent = 500

  func occurrences(for events: [Event], in interval: DateInterval) -> [EventOccurrence] {
    var result: [EventOccurrence] = []

    for event in events {
      guard !event.isHoliday, event.isRecurring else {
        if interval.contains(event.date) {
          result.append(EventOccurrence(sourceEvent: event, occurrenceDate: event.date))
        }
        continue
      }

      guard event.date <= interval.end else { continue }
      if let recurrenceEndDate = event.recurrenceEndDate, recurrenceEndDate < interval.start {
        continue
      }

      var date = event.date
      var iterations = 0

      while iterations < maxOccurrencesPerEvent {
        if let recurrenceEndDate = event.recurrenceEndDate, date > recurrenceEndDate {
          break
        }

        if interval.contains(date) {
          result.append(EventOccurrence(sourceEvent: event, occurrenceDate: date))
        }

        if date > interval.end {
          break
        }

        guard let nextDate = nextOccurrenceDate(from: date, event: event) else { break }
        date = nextDate
        iterations += 1
      }
    }

    return result.sorted { $0.occurrenceDate < $1.occurrenceDate }
  }

  func occurrences(for events: [Event], on date: Date) -> [EventOccurrence] {
    let interval = DateInterval(start: date.startOfDay, end: date.endOfDay)
    return occurrences(for: events, in: interval)
  }

  private func nextOccurrenceDate(from date: Date, event: Event) -> Date? {
    guard let recurrenceType = event.recurrenceTypeEnum else { return nil }
    let interval = max(1, event.recurrenceInterval ?? 1)

    switch recurrenceType {
    case .weekly:
      return Calendar.current.date(byAdding: .weekOfYear, value: interval, to: date)
    case .monthly:
      return Calendar.current.date(byAdding: .month, value: interval, to: date)
    case .yearly:
      return Calendar.current.date(byAdding: .year, value: interval, to: date)
    }
  }
}
