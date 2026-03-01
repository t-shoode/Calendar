import Foundation
import SwiftData
import SwiftUI

// MARK: - View Mode

enum CalendarViewMode: String, CaseIterable {
  case grid, list, timeline

  var icon: String {
    switch self {
    case .grid: return "square.grid.2x2"
    case .list: return "list.bullet"
    case .timeline: return "clock"
    }
  }
}

struct CalendarView: View {
  @StateObject private var viewModel = CalendarViewModel()
  @StateObject private var todoViewModel = TodoViewModel()
  @Query(sort: \Event.date) private var events: [Event]
  @Query(
    filter: #Predicate<TodoItem> { $0.parentTodo == nil },
    sort: \TodoItem.createdAt)
  private var rootTodos: [TodoItem]
  @Query(sort: \Expense.date) private var expenses: [Expense]
  @Query private var expenseTemplates: [RecurringExpenseTemplate]
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase

  @State private var viewMode: CalendarViewMode = .grid
  @State private var showingAddEvent = false
  @State private var showingDatePicker = false
  @State private var showingSettings = false
  @State private var editingEventOccurrence: EventOccurrence?
  @State private var editingTodo: TodoItem?
  @State private var editingExpense: Expense?
  @State private var detailOccurrence: EventOccurrence?
  @State private var referenceDate: Date = Date()
  @State private var midnightRefreshTask: Task<Void, Never>?

  var body: some View {
    ZStack {
      VStack(spacing: 0) {
        // Month Navigation Header
        MonthHeaderView(
          currentMonth: viewModel.currentMonth,
          viewMode: $viewMode,
          onPrevious: viewModel.moveToPreviousMonth,
          onNext: viewModel.moveToNextMonth,
          onAdd: { showingAddEvent = true },
          onSettings: { showingSettings = true },
          onTitleTap: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
              showingDatePicker.toggle()
            }
          }
        )
        .padding(.top, 10)
        .padding(.bottom, 6)
        .animation(nil, value: viewMode)

        // View Mode Content
        VStack(spacing: 0) {
          switch viewMode {
          case .grid:
            VStack(spacing: 8) {
              WeekdayHeaderView()
                .padding(.top, 12)

              MonthView(
                currentMonth: viewModel.currentMonth,
                selectedDate: viewModel.selectedDate,
                events: eventsForMonth,
                todos: todosForMonth,
                expenses: expensesForMonth,
                effectiveTodoDueDate: effectiveCalendarDueDate(for:),
                onSelectDate: { date in
                  let selectedMonth = Calendar.current.component(.month, from: date)
                  let currentMonth = Calendar.current.component(
                    .month, from: viewModel.currentMonth)
                  if selectedMonth != currentMonth {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                      viewModel.currentMonth = date
                    }
                  }
                  viewModel.selectDate(date)
                  if showingDatePicker {
                    withAnimation { showingDatePicker = false }
                  }
                }
              )
              .frame(height: 310)  // 6 rows with tighter spacing
              .softCard(cornerRadius: 16, padding: 10, shadow: false)

              Spacer(minLength: 0)

              EventListView(
                date: viewModel.selectedDate ?? Date(),
                events: eventsForSelectedDate,
                todos: todosForSelectedDate,
                expenses: expensesForSelectedDate,
                onEdit: { occurrence in detailOccurrence = occurrence },
                onDelete: { occurrence in
                  guard !occurrence.sourceEvent.isHoliday else { return }
                  deleteEvent(occurrence)
                },
                onAdd: { showingAddEvent = true },
                onTodoToggle: { todo in
                  todoViewModel.toggleCompletion(todo, context: modelContext)
                },
                onTodoTap: { todo in editingTodo = todo },
                onExpenseTap: { expense in editingExpense = expense },
                showJumpToToday: !Calendar.current.isDateInToday(viewModel.selectedDate ?? Date())
                  || !Calendar.current.isDate(
                    viewModel.currentMonth, equalTo: Date(), toGranularity: .month),
                onJumpToToday: {
                  withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    let today = Date()
                    viewModel.selectDate(today)
                    viewModel.currentMonth = today
                  }
                }
              )
              .padding(.bottom, 100)  // Space from floating tab bar
            }
            .gesture(
              DragGesture(minimumDistance: 50, coordinateSpace: .local)
                .onEnded { value in
                  let horizontal = value.translation.width
                  let vertical = value.translation.height
                  // Only trigger if horizontal swipe is dominant
                  guard abs(horizontal) > abs(vertical) else { return }
                  withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if horizontal < 0 {
                      viewModel.moveToNextMonth()
                    } else {
                      viewModel.moveToPreviousMonth()
                    }
                  }
                }
            )

          case .list:
            CalendarListView(
              currentMonth: viewModel.currentMonth,
              events: eventsForMonth,
              todos: todosForMonth,
              expenses: expensesForMonth,
              effectiveTodoDueDate: effectiveCalendarDueDate(for:),
              onEventTap: { occurrence in detailOccurrence = occurrence },
              onDateSelect: { date in viewModel.selectDate(date) }
            )

          case .timeline:
            CalendarTimelineView(
              selectedDate: Binding(
                get: { viewModel.selectedDate ?? Date() },
                set: { viewModel.selectedDate = $0 }
              ),
              events: eventsForSelectedDate,
              expenses: expensesForSelectedDate,
              onEventTap: { occurrence in detailOccurrence = occurrence },
              onDateSelect: { date in viewModel.selectDate(date) },
              currentMonth: viewModel.currentMonth
            )
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .blur(radius: showingDatePicker ? 4 : 0)

      // Overlays (DatePicker, Popover etc)
      if showingDatePicker {
        Color.black.opacity(0.1)
          .ignoresSafeArea()
          .onTapGesture { showingDatePicker = false }

        MonthYearPicker(currentMonth: $viewModel.currentMonth, isPresented: $showingDatePicker)
          .transition(.scale.combined(with: .opacity))
          .zIndex(1)
      }
    }
    .navigationBarHidden(true)  // We use custom header
    .sheet(isPresented: $showingAddEvent) {
      AddEventView(date: viewModel.selectedDate ?? Date()) {
        title, notes, color, date, reminderInterval, recurrenceType, recurrenceInterval, recurrenceEndDate in
        addEvent(
          title: title,
          notes: notes,
          color: color,
          date: date,
          reminderInterval: reminderInterval,
          recurrenceType: recurrenceType,
          recurrenceInterval: recurrenceInterval,
          recurrenceEndDate: recurrenceEndDate
        )
      }
    }
    .sheet(isPresented: $showingSettings) {
      SettingsSheet(isPresented: $showingSettings)
    }
    .sheet(item: $editingEventOccurrence) { occurrence in
      AddEventView(
        date: occurrence.occurrenceDate,
        eventOccurrence: occurrence,
        onSave: {
          title, notes, color, date, reminderInterval, recurrenceType, recurrenceInterval,
          recurrenceEndDate in
          eventViewModel.updateEventOccurrence(
            occurrence,
            title: title,
            notes: notes,
            color: color,
            date: date,
            reminderInterval: reminderInterval,
            recurrenceType: recurrenceType,
            recurrenceInterval: recurrenceInterval,
            recurrenceEndDate: recurrenceEndDate,
            scope: .thisAndFuture,
            context: modelContext
          )
        },
        onDelete: {
          deleteEvent(occurrence)
        }
      )
    }
    .overlay {
      if let occurrence = detailOccurrence {
        ZStack {
          Color.black.opacity(0.3)
            .ignoresSafeArea()
            .onTapGesture {
              detailOccurrence = nil
            }

          EventDetailPopover(
            occurrence: occurrence,
            onDismiss: { detailOccurrence = nil },
            onEdit: {
              detailOccurrence = nil
              editingEventOccurrence = occurrence
            },
            onDelete: {
              detailOccurrence = nil
              deleteEvent(occurrence)
            }
          )
        }
      }
    }
    .onAppear {
      refreshReferenceDate()
      scheduleMidnightRefresh()
    }
    .onDisappear {
      midnightRefreshTask?.cancel()
      midnightRefreshTask = nil
    }
    .onChange(of: scenePhase) { _, newValue in
      guard newValue == .active else { return }
      refreshReferenceDate()
      scheduleMidnightRefresh()
    }
  }

  private var eventsForMonth: [EventOccurrence] {
    let startOfMonth = viewModel.currentMonth.startOfMonth
    let endOfMonth = viewModel.currentMonth.endOfMonth
    return EventRecurrenceService.shared.occurrences(
      for: events,
      in: DateInterval(start: startOfMonth, end: endOfMonth)
    )
  }

  private var todosForMonth: [TodoItem] {
    let startOfMonth = viewModel.currentMonth.startOfMonth
    let endOfMonth = viewModel.currentMonth.endOfMonth
    return rootTodos.filter { todo in
      let dueDate = effectiveCalendarDueDate(for: todo)
      return dueDate >= startOfMonth && dueDate <= endOfMonth
    }
  }

  private var eventsForSelectedDate: [EventOccurrence] {
    let dateToCheck = viewModel.selectedDate ?? Date()
    return EventRecurrenceService.shared.occurrences(for: events, on: dateToCheck)
  }

  private var todosForSelectedDate: [TodoItem] {
    let dateToCheck = viewModel.selectedDate ?? Date()
    return rootTodos.filter { todo in
      effectiveCalendarDueDate(for: todo).isSameDay(as: dateToCheck)
    }
  }

  private var expensesForMonth: [Expense] {
    let startOfMonth = viewModel.currentMonth.startOfMonth
    let endOfMonth = viewModel.currentMonth.endOfMonth
    let recurringTemplateIds = Set(expenseTemplates.map { $0.id })

    return expenses.filter {
      guard let templateId = $0.templateId else { return false }
      return $0.date >= startOfMonth && $0.date <= endOfMonth
        && recurringTemplateIds.contains(templateId)
    }
  }

  private var expensesForSelectedDate: [Expense] {
    let dateToCheck = viewModel.selectedDate ?? Date()
    let recurringTemplateIds = Set(expenseTemplates.map { $0.id })

    return expenses.filter {
      guard let templateId = $0.templateId else { return false }
      return $0.date.isSameDay(as: dateToCheck)
        && recurringTemplateIds.contains(templateId)
    }
  }

  private func addEvent(
    title: String,
    notes: String?,
    color: String,
    date: Date,
    reminderInterval: TimeInterval?,
    recurrenceType: RecurrenceType?,
    recurrenceInterval: Int,
    recurrenceEndDate: Date?
  ) {
    eventViewModel.addEvent(
      date: date,
      title: title,
      notes: notes,
      color: color,
      reminderInterval: reminderInterval,
      recurrenceType: recurrenceType,
      recurrenceInterval: recurrenceInterval,
      recurrenceEndDate: recurrenceEndDate,
      context: modelContext
    )
  }

  private func deleteEvent(_ occurrence: EventOccurrence) {
    eventViewModel.deleteEventOccurrence(occurrence, scope: .thisAndFuture, context: modelContext)
  }

  private func effectiveCalendarDueDate(for todo: TodoItem) -> Date {
    todo.dueDate ?? referenceDate.endOfDay
  }

  private func refreshReferenceDate() {
    referenceDate = Date()
  }

  private func scheduleMidnightRefresh() {
    midnightRefreshTask?.cancel()
    midnightRefreshTask = Task {
      while !Task.isCancelled {
        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        let nextMidnight = tomorrow.startOfDay
        let sleepInterval = max(nextMidnight.timeIntervalSince(now), 1)
        let sleepNanoseconds = UInt64(sleepInterval * 1_000_000_000)
        try? await Task.sleep(nanoseconds: sleepNanoseconds)
        if Task.isCancelled { break }
        await MainActor.run { referenceDate = Date() }
      }
    }
  }

  private let eventViewModel = EventViewModel()
}

struct WeekdayHeaderView: View {
  private var adjustedWeekdays: [String] {
    let symbols = Calendar.current.veryShortWeekdaySymbols  // [Sun, Mon, Tue, Wed, Thu, Fri, Sat]
    var week = symbols
    let first = week.removeFirst()
    week.append(first)  // [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
    return week
  }

  var body: some View {
    HStack(spacing: 0) {
      // Use indices as the id because `veryShortWeekdaySymbols` contains duplicate short labels
      // (e.g. "S" appears twice). Relying on index ensures stable/unique identity for SwiftUI.
      ForEach(adjustedWeekdays.indices, id: \.self) { idx in
        let day = adjustedWeekdays[idx]
        Text(day)
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .foregroundColor(Color.textTertiary)
          .frame(maxWidth: .infinity)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .softControl(cornerRadius: 12, padding: 6)
    .padding(.horizontal, 16)
  }
}

struct MonthHeaderView: View {
  let currentMonth: Date
  @Binding var viewMode: CalendarViewMode
  let onPrevious: () -> Void
  let onNext: () -> Void
  let onAdd: () -> Void
  let onSettings: () -> Void
  var onTitleTap: (() -> Void)? = nil

  var body: some View {
    VStack(spacing: 10) {
      HStack(alignment: .center) {
        Button(action: onSettings) {
          Image(systemName: "gearshape.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.textSecondary)
            .frame(width: 36, height: 36)
            .softControl(cornerRadius: 18, padding: 0)
        }
        .buttonStyle(.plain)

        Spacer()

        Button(action: { onTitleTap?() }) {
          HStack(spacing: 6) {
            Text(currentMonth.formattedMonthYear.localizedCapitalized)
              .font(Typography.title.weight(.bold))
              .foregroundColor(Color.textPrimary)

            Image(systemName: "chevron.down")
              .font(.system(size: 11, weight: .bold))
              .foregroundColor(Color.accentColor)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .softControl(cornerRadius: 12, padding: 0)
        }
        .buttonStyle(.plain)

        Spacer()

        Button(action: onAdd) {
          Image(systemName: "plus")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 36, height: 36)
            .background(
              Circle()
                .fill(Color.accentColor)
            )
            .shadow(color: Color.accentColor.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 20)

      HStack {
        HStack(spacing: 4) {
          Button(action: onPrevious) {
            Image(systemName: "chevron.left")
              .font(.system(size: 12, weight: .semibold))
              .frame(width: 28, height: 28)
              .softControl(cornerRadius: 14, padding: 0)
          }
          .buttonStyle(.plain)

          Button(action: onNext) {
            Image(systemName: "chevron.right")
              .font(.system(size: 12, weight: .semibold))
              .frame(width: 28, height: 28)
              .softControl(cornerRadius: 14, padding: 0)
          }
          .buttonStyle(.plain)
        }

        Spacer()

        HStack(spacing: 4) {
          ForEach(CalendarViewMode.allCases, id: \.self) { mode in
            Button {
              withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewMode = mode
              }
            } label: {
              Image(systemName: mode.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(viewMode == mode ? .white : Color.textSecondary)
                .frame(width: 32, height: 28)
                .background(viewMode == mode ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.clear))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
          }
        }
        .softControl(cornerRadius: 10, padding: 4)
      }
      .padding(.horizontal, 20)
    }
  }
}
