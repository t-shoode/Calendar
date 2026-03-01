import SwiftData
import SwiftUI
import WidgetKit

enum EventEditScope {
  case thisAndFuture
}

class EventViewModel {
  func addEvent(
    date: Date, title: String, notes: String?, color: String, reminderInterval: TimeInterval?,
    recurrenceType: RecurrenceType?, recurrenceInterval: Int, recurrenceEndDate: Date?,
    context: ModelContext
  ) {
    let event = Event(
      date: date,
      title: title,
      notes: notes,
      color: color,
      reminderInterval: reminderInterval,
      recurrenceType: recurrenceType,
      recurrenceInterval: recurrenceInterval,
      recurrenceEndDate: recurrenceEndDate
    )
    context.insert(event)
    do {
      try context.save()
      rescheduleAllNotifications(context: context)
      syncEventsToWidget(context: context)
    } catch {
      ErrorPresenter.shared.present(error)
    }
  }

  func updateEvent(
    _ event: Event, title: String, notes: String?, color: String, date: Date,
    reminderInterval: TimeInterval?, recurrenceType: RecurrenceType?, recurrenceInterval: Int,
    recurrenceEndDate: Date?,
    context: ModelContext
  ) {
    event.title = title
    event.notes = notes
    event.color = color
    event.date = date
    event.reminderInterval = reminderInterval
    event.recurrenceTypeEnum = recurrenceType
    event.recurrenceInterval = recurrenceInterval
    event.recurrenceEndDate = recurrenceEndDate
    do {
      try context.save()
      rescheduleAllNotifications(context: context)
      syncEventsToWidget(context: context)
    } catch {
      ErrorPresenter.shared.present(error)
    }
  }

  func updateEventOccurrence(
    _ occurrence: EventOccurrence,
    title: String,
    notes: String?,
    color: String,
    date: Date,
    reminderInterval: TimeInterval?,
    recurrenceType: RecurrenceType?,
    recurrenceInterval: Int,
    recurrenceEndDate: Date?,
    scope: EventEditScope = .thisAndFuture,
    context: ModelContext
  ) {
    switch scope {
    case .thisAndFuture:
      break
    }

    let source = occurrence.sourceEvent
    let isAnchorOccurrence = occurrence.occurrenceDate == source.date
    if !isAnchorOccurrence && source.isRecurring {
      source.recurrenceEndDate = occurrence.occurrenceDate.startOfDay.addingTimeInterval(-1)

      let newSeries = Event(
        date: date,
        title: title,
        notes: notes,
        color: color,
        reminderInterval: reminderInterval,
        recurrenceType: recurrenceType,
        recurrenceInterval: recurrenceInterval,
        recurrenceEndDate: recurrenceEndDate
      )
      context.insert(newSeries)

      do {
        try context.save()
        rescheduleAllNotifications(context: context)
        syncEventsToWidget(context: context)
      } catch {
        ErrorPresenter.shared.present(error)
      }
      return
    }

    updateEvent(
      source,
      title: title,
      notes: notes,
      color: color,
      date: date,
      reminderInterval: reminderInterval,
      recurrenceType: recurrenceType,
      recurrenceInterval: recurrenceInterval,
      recurrenceEndDate: recurrenceEndDate,
      context: context
    )
  }

  func deleteEvent(_ event: Event, context: ModelContext) {
    context.delete(event)
    do {
      try context.save()
      rescheduleAllNotifications(context: context)
      syncEventsToWidget(context: context)
    } catch {
      ErrorPresenter.shared.present(error)
    }
  }

  func deleteEventOccurrence(
    _ occurrence: EventOccurrence,
    scope: EventEditScope = .thisAndFuture,
    context: ModelContext
  ) {
    switch scope {
    case .thisAndFuture:
      break
    }

    let source = occurrence.sourceEvent
    let isAnchorOccurrence = occurrence.occurrenceDate == source.date

    if !isAnchorOccurrence && source.isRecurring {
      source.recurrenceEndDate = occurrence.occurrenceDate.startOfDay.addingTimeInterval(-1)
      do {
        try context.save()
        rescheduleAllNotifications(context: context)
        syncEventsToWidget(context: context)
      } catch {
        ErrorPresenter.shared.present(error)
      }
      return
    }

    deleteEvent(source, context: context)
  }

  func rescheduleAllNotifications(context: ModelContext) {
    let now = Date()
    let descriptor = FetchDescriptor<Event>(sortBy: [SortDescriptor(\.date)])

    do {
      let events = try context.fetch(descriptor)
      let end = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now
      let occurrences = EventRecurrenceService.shared.occurrences(
        for: events,
        in: DateInterval(start: now, end: end)
      )
      NotificationService.shared.syncEventNotifications(occurrences: occurrences)
    } catch {
      ErrorPresenter.shared.present(error)
    }
  }

  func syncEventsToWidget(context: ModelContext, userDefaults: UserDefaults? = nil) {
    let calendar = Calendar.current
    let today = Date()

    guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return }
    let rangeStart = calendar.date(byAdding: .day, value: -1, to: weekStart)!
    let rangeEnd = calendar.date(byAdding: .day, value: 15, to: weekStart)!

    let eventDescriptor = FetchDescriptor<Event>(sortBy: [SortDescriptor(\.date)])

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"

    var eventMap: [String: [String]] = [:]

    // Sync events
    do {
      let events = try context.fetch(eventDescriptor)
      let occurrences = EventRecurrenceService.shared.occurrences(
        for: events,
        in: DateInterval(start: rangeStart, end: rangeEnd)
      )

      for occurrence in occurrences {
        let source = occurrence.sourceEvent
        let key = formatter.string(from: occurrence.occurrenceDate)
        var colors = eventMap[key] ?? []
        if colors.count < 6 {
          colors.append(source.isHoliday ? "holiday:\(source.color)" : source.color)
        }
        eventMap[key] = colors
      }
    } catch {}

    // Sync todos with due dates (prefixed with "todo:" for widget differentiation)
    let todoDescriptor = FetchDescriptor<TodoItem>(
      predicate: #Predicate { todo in
        todo.isCompleted == false && todo.parentTodo == nil && todo.dueDate != nil
      }
    )

    do {
      let todos = try context.fetch(todoDescriptor)
      for todo in todos {
        guard let dueDate = todo.dueDate,
          dueDate >= rangeStart && dueDate <= rangeEnd
        else { continue }
        let key = formatter.string(from: dueDate)
        var colors = eventMap[key] ?? []
        if colors.count < 6 {
          let catColor = todo.category?.color ?? "green"
          let priKey = todo.priority  // "low", "medium", "high"
          colors.append("todo:\(catColor):\(priKey)")
        }
        eventMap[key] = colors
      }
    } catch {}

    do {
      let data = try JSONSerialization.data(withJSONObject: eventMap)
      if let jsonString = String(data: data, encoding: .utf8) {
        let defaults = userDefaults ?? UserDefaults(suiteName: Constants.Storage.appGroupIdentifier)
        defaults?.set(jsonString, forKey: "widgetEventData")
      }
    } catch {
      ErrorPresenter.shared.present(error)
    }

    WidgetCenter.shared.reloadTimelines(ofKind: "CalendarWidget")
    WidgetCenter.shared.reloadTimelines(ofKind: "CombinedWidget")
  }
}
