import SwiftData
import XCTest

@testable import Calendar

final class EventRecurrenceTests: XCTestCase {
  var container: ModelContainer!
  var context: ModelContext!
  var viewModel: EventViewModel!

  override func setUpWithError() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    container = try ModelContainer(
      for: Event.self, TodoItem.self, TodoCategory.self, Expense.self, RecurringExpenseTemplate.self,
      configurations: config
    )
    context = ModelContext(container)
    viewModel = EventViewModel()
  }

  func testWeeklyRecurringEventExpandsWithinInterval() throws {
    let calendar = Calendar.current
    let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 10, minute: 0))!
    let end = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 23, minute: 59))!
    let event = Event(
      date: start,
      title: "Standup",
      recurrenceType: .weekly,
      recurrenceInterval: 1
    )
    context.insert(event)
    try context.save()

    let occurrences = EventRecurrenceService.shared.occurrences(
      for: [event],
      in: DateInterval(start: start, end: end)
    )

    XCTAssertEqual(occurrences.count, 5)
    XCTAssertTrue(occurrences.allSatisfy { $0.sourceEvent.id == event.id })
    XCTAssertTrue(occurrences.contains { calendar.component(.day, from: $0.occurrenceDate) == 1 })
    XCTAssertTrue(occurrences.contains { calendar.component(.day, from: $0.occurrenceDate) == 8 })
  }

  func testUpdateFutureOccurrenceSplitsSeries() throws {
    let calendar = Calendar.current
    let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 9, minute: 0))!
    let event = Event(
      date: start,
      title: "Workout",
      recurrenceType: .weekly,
      recurrenceInterval: 1
    )
    context.insert(event)
    try context.save()

    let targetDate = calendar.date(byAdding: .weekOfYear, value: 2, to: start)!
    let occurrence = EventOccurrence(sourceEvent: event, occurrenceDate: targetDate)
    let editedDate = calendar.date(byAdding: .hour, value: 2, to: targetDate)!

    viewModel.updateEventOccurrence(
      occurrence,
      title: "Workout Plus",
      notes: nil,
      color: "red",
      date: editedDate,
      reminderInterval: nil,
      recurrenceType: .weekly,
      recurrenceInterval: 1,
      recurrenceEndDate: nil,
      scope: .thisAndFuture,
      context: context
    )

    let events = try context.fetch(FetchDescriptor<Event>())
    XCTAssertEqual(events.count, 2)

    let oldSeries = try XCTUnwrap(events.first { $0.id == event.id })
    XCTAssertEqual(oldSeries.recurrenceEndDate, targetDate.startOfDay.addingTimeInterval(-1))

    let newSeries = try XCTUnwrap(events.first { $0.id != event.id })
    XCTAssertEqual(newSeries.title, "Workout Plus")
    XCTAssertEqual(newSeries.date, editedDate)
    XCTAssertEqual(newSeries.recurrenceTypeEnum, .weekly)
  }

  func testDeleteFutureOccurrenceTruncatesSeries() throws {
    let calendar = Calendar.current
    let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 9, minute: 0))!
    let event = Event(
      date: start,
      title: "Bills",
      recurrenceType: .weekly,
      recurrenceInterval: 1
    )
    context.insert(event)
    try context.save()

    let targetDate = calendar.date(byAdding: .weekOfYear, value: 3, to: start)!
    let occurrence = EventOccurrence(sourceEvent: event, occurrenceDate: targetDate)

    viewModel.deleteEventOccurrence(occurrence, scope: .thisAndFuture, context: context)

    let events = try context.fetch(FetchDescriptor<Event>())
    XCTAssertEqual(events.count, 1)
    XCTAssertEqual(events[0].id, event.id)
    XCTAssertEqual(events[0].recurrenceEndDate, targetDate.startOfDay.addingTimeInterval(-1))
  }
}
