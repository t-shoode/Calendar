import SwiftUI

struct AddEventView: View {
  @Environment(\.dismiss) private var dismiss

  let date: Date
  let eventOccurrence: EventOccurrence?
  let onSave: (String, String?, String, Date, TimeInterval?, RecurrenceType?, Int, Date?) -> Void
  let onDelete: (() -> Void)?

  @State private var title: String = ""
  @State private var notes: String = ""
  @State private var selectedColor: String = "blue"
  @State private var selectedDate: Date = Date()
  @State private var reminderSelection: TimeInterval = 0
  @State private var recurrenceType: RecurrenceType?
  @State private var recurrenceInterval: Int = 1
  @State private var recurrenceEndDate: Date?

  // ... colors ...
  private let colors = ["blue", "green", "orange", "red", "purple", "pink", "yellow"]

  private var reminders: [(String, TimeInterval)] {
    [
      (Localization.string(.none), 0),
      (Localization.string(.atTimeOfEvent), 0.1),
      (Localization.string(.minutesBefore(15)), 15 * 60),
      (Localization.string(.minutesBefore(30)), 30 * 60),
      (Localization.string(.hoursBefore(1)), 60 * 60),
      (Localization.string(.hoursBefore(2)), 2 * 60 * 60),
      (Localization.string(.daysBefore(1)), 24 * 60 * 60),
    ]
  }

  init(
    date: Date, eventOccurrence: EventOccurrence? = nil,
    onSave: @escaping (String, String?, String, Date, TimeInterval?, RecurrenceType?, Int, Date?) -> Void,
    onDelete: (() -> Void)? = nil
  ) {
    self.date = date
    self.eventOccurrence = eventOccurrence
    self.onSave = onSave
    self.onDelete = onDelete

    if let occurrence = eventOccurrence {
      let event = occurrence.sourceEvent
      _title = State(initialValue: event.title)
      _notes = State(initialValue: event.notes ?? "")
      _selectedColor = State(initialValue: event.color)
      _selectedDate = State(initialValue: occurrence.occurrenceDate)
      _reminderSelection = State(initialValue: event.reminderInterval ?? 0)
      _recurrenceType = State(initialValue: event.recurrenceTypeEnum)
      _recurrenceInterval = State(initialValue: event.recurrenceInterval ?? 1)
      _recurrenceEndDate = State(initialValue: event.recurrenceEndDate)
    } else {
      _selectedDate = State(initialValue: date)
    }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section(eventOccurrence == nil ? Localization.string(.newEvent) : Localization.string(.editEvent)) {
          TextField(Localization.string(.title), text: $title)

          if #available(iOS 16.0, *) {
            TextField(Localization.string(.notes), text: $notes, axis: .vertical)
              .lineLimit(3...6)
          } else {
            TextField(Localization.string(.notes), text: $notes)
          }
        }

        Section(Localization.string(.date)) {
          DatePicker(
            Localization.string(.date), selection: $selectedDate,
            displayedComponents: [.date, .hourAndMinute])

          Picker(Localization.string(.reminder), selection: $reminderSelection) {
            ForEach(reminders, id: \.1) { label, value in
              Text(label).tag(value)
            }
          }
        }

        Section(Localization.string(.recurring)) {
          RecurrencePicker(
            recurrenceType: $recurrenceType,
            interval: $recurrenceInterval,
            endDate: $recurrenceEndDate
          )
        }

        Section(Localization.string(.color)) {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
              ForEach(colors, id: \.self) { color in
                ColorCircle(color: color, isSelected: selectedColor == color) {
                  selectedColor = color
                }
              }
            }
            .padding(.horizontal, 4)
          }
        }

        if let onDelete = onDelete {
          Section {
            Button(role: .destructive) {
              onDelete()
              dismiss()
            } label: {
              HStack {
                Spacer()
                Text(Localization.string(.delete))
                Spacer()
              }
            }
          }
        }
      }
      .navigationTitle(
        eventOccurrence == nil ? Localization.string(.newEvent) : Localization.string(.editEvent)
      )
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(Localization.string(.cancel)) {
            dismiss()
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button(Localization.string(.save)) {
            let reminder = reminderSelection == 0 ? nil : reminderSelection
            onSave(
              title,
              notes.isEmpty ? nil : notes,
              selectedColor,
              selectedDate,
              reminder,
              recurrenceType,
              recurrenceInterval,
              recurrenceType == nil ? nil : recurrenceEndDate
            )
            dismiss()
          }
          .disabled(title.isEmpty)
        }
      }
    }
  }
}

struct ColorCircle: View {
  let color: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Circle()
        .fill(Color.eventColor(named: color))
        .frame(width: 40, height: 40)
        .overlay(
          Circle()
            .stroke(Color.backgroundPrimary, lineWidth: isSelected ? 3 : 0)
        )
    }
    .buttonStyle(.plain)
  }
}
