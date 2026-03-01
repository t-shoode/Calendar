import SwiftUI

struct EventIndicator: View {
  let events: [EventOccurrence]

  private var displayedEvents: [EventOccurrence] {
    Array(events.prefix(3))
  }

  var body: some View {
    HStack(spacing: 3) {
      ForEach(displayedEvents, id: \.id) { event in
        Circle()
          .fill(Color.eventColor(named: event.sourceEvent.color))
          .frame(width: 5, height: 5)
      }
    }
  }
}
