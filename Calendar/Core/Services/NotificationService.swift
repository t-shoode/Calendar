import Foundation
import UserNotifications

class NotificationService: NSObject, UNUserNotificationCenterDelegate {
  static let shared = NotificationService()

  private override init() {
    super.init()
    UNUserNotificationCenter.current().delegate = self
  }

  func requestAuthorization() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
      granted, error in
      if let error = error {
        ErrorPresenter.presentOnMain(error)
      }
    }
  }

  func scheduleTimerNotification(duration: TimeInterval, identifier: String = "timer") {
    let content = UNMutableNotificationContent()
    content.title = "Timer Complete"
    content.body = "Your timer has finished!"
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        ErrorPresenter.presentOnMain(error)
      }
    }
  }

  func scheduleAlarmNotification(date: Date) {
    let content = UNMutableNotificationContent()
    content.title = "Alarm"
    content.body = "Your alarm is ringing!"
    content.sound = .default

    let components = Calendar.current.dateComponents([.hour, .minute], from: date)
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    let request = UNNotificationRequest(identifier: "alarm", content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        ErrorPresenter.presentOnMain(error)
      }
    }
  }

  func cancelTimerNotifications(identifier: String = "timer") {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
      identifier
    ])
  }

  func cancelAlarmNotifications() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["alarm"])
  }

  // MARK: - Event Notifications

  func syncEventNotifications(occurrences: [EventOccurrence]) {
    // 1. Cancel all existing event notifications to prevent duplicates/stale data
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
      let eventIdentifiers =
        requests
        .filter { $0.identifier.hasPrefix("event-") }
        .map { $0.identifier }

      UNUserNotificationCenter.current().removePendingNotificationRequests(
        withIdentifiers: eventIdentifiers)

      // 2. Schedule notifications for upcoming events (limit to 50 to respect OS limits)
      // Filter: Has reminder, is in future
      let upcomingEvents =
        occurrences
        .filter { occurrence in
          guard let offset = occurrence.sourceEvent.reminderInterval, offset > 0 else { return false }
          let notifyDate = occurrence.occurrenceDate.addingTimeInterval(-offset)
          return notifyDate > Date()
        }
        .sorted { $0.occurrenceDate < $1.occurrenceDate }
        .prefix(50)

      for occurrence in upcomingEvents {
        self.scheduleEventNotification(occurrence: occurrence)
      }

      // print(" synced \(upcomingEvents.count) event notifications")
    }
  }

  private func scheduleEventNotification(occurrence: EventOccurrence) {
    let event = occurrence.sourceEvent
    guard let offset = event.reminderInterval, offset > 0 else { return }
    let notifyDate = occurrence.occurrenceDate.addingTimeInterval(-offset)

    let content = UNMutableNotificationContent()
    content.title = event.title
    content.body =
      "Upcoming event at \(occurrence.occurrenceDate.formatted(date: .omitted, time: .shortened))"
    content.sound = .default

    let components = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute, .second], from: notifyDate)
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    let identifier =
      "event-\(event.id.uuidString)-\(Int64(occurrence.occurrenceDate.timeIntervalSince1970))"

    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        ErrorPresenter.presentOnMain(error)
      }
    }
  }

  func scheduleTodoNotification(todo: TodoItem) {
    guard let dueDate = todo.dueDate else { return }

    // Schedule the main reminder at the due date
    let offset = todo.reminderInterval ?? 0
    if offset > 0 {
      let notifyDate = dueDate.addingTimeInterval(-offset)
      if notifyDate > Date() {
        let content = UNMutableNotificationContent()
        content.title = todo.title
        content.body = "Due at \(dueDate.formatted(date: .abbreviated, time: .shortened))"
        content.sound = .default

        let components = Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute, .second], from: notifyDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "todo-\(todo.id.uuidString)"

        let request = UNNotificationRequest(
          identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
          if let error = error {
            ErrorPresenter.presentOnMain(error)
          }
        }
      }
    }

    // Schedule repeat reminders (every N minutes from due date, X times)
    if let repeatInterval = todo.reminderRepeatInterval, repeatInterval > 0 {
      let count = todo.reminderRepeatCount ?? 3
      scheduleRepeatReminders(
        todo: todo, dueDate: dueDate, repeatInterval: repeatInterval, count: count)
    }
  }

  private func scheduleRepeatReminders(
    todo: TodoItem, dueDate: Date, repeatInterval: TimeInterval, count: Int
  ) {
    let now = Date()
    let maxNotifications = min(count, 50)

    for i in 1...maxNotifications {
      let fireDate = dueDate.addingTimeInterval(repeatInterval * Double(i))
      guard fireDate > now else { continue }

      let content = UNMutableNotificationContent()
      content.title = todo.title
      content.body =
        "Reminder \(i)/\(maxNotifications) — due at \(dueDate.formatted(date: .abbreviated, time: .shortened))"
      content.sound = .default

      let components = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute, .second], from: fireDate)
      let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
      let identifier = "todo-repeat-\(todo.id.uuidString)-\(i)"

      let request = UNNotificationRequest(
        identifier: identifier, content: content, trigger: trigger)
      UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
          ErrorPresenter.presentOnMain(error)
        }
      }
    }
  }

  func cancelTodoNotification(id: UUID) {
    // Cancel main reminder
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
      "todo-\(id.uuidString)"
    ])
    // Cancel all repeat reminders for this todo
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
      let repeatIds = requests.filter {
        $0.identifier.hasPrefix("todo-repeat-\(id.uuidString)")
      }.map { $0.identifier }
      if !repeatIds.isEmpty {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
          withIdentifiers: repeatIds)
      }
    }
  }

  func syncTodoNotifications(todos: [TodoItem]) {
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
      let todoIdentifiers =
        requests
        .filter { $0.identifier.hasPrefix("todo-") }
        .map { $0.identifier }

      UNUserNotificationCenter.current().removePendingNotificationRequests(
        withIdentifiers: todoIdentifiers)

      let upcomingTodos =
        todos
        .filter { todo in
          guard let dueDate = todo.dueDate else { return false }
          let offset = todo.reminderInterval ?? 0
          let notifyDate = dueDate.addingTimeInterval(-offset)
          return notifyDate > Date()
        }
        .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        .prefix(50)

      for todo in upcomingTodos {
        self.scheduleTodoNotification(todo: todo)
      }
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }
}
