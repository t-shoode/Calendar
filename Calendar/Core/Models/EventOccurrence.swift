import Foundation

struct EventOccurrence: Identifiable {
  let sourceEvent: Event
  let occurrenceDate: Date

  var id: String {
    "\(sourceEvent.id.uuidString)-\(Int64(occurrenceDate.timeIntervalSince1970))"
  }

  var isGeneratedOccurrence: Bool {
    occurrenceDate != sourceEvent.date
  }
}
