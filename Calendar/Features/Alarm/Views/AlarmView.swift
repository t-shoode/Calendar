import SwiftData
import SwiftUI

struct AlarmView: View {
  @StateObject private var viewModel = AlarmViewModel()
  @Query private var alarms: [Alarm]
  @State private var showingTimePicker = false

  var body: some View {
    VStack(spacing: 24) {
      if let alarm = alarms.first {
        AlarmCard(alarm: alarm, viewModel: viewModel)
      } else {
        EmptyAlarmView(onAdd: { showingTimePicker = true })
      }

      Spacer()
    }
    .padding(.horizontal, 20)
    .padding(.top, 12)
    .sheet(isPresented: $showingTimePicker) {
      TimePickerView { time in
        viewModel.createAlarm(time: time, context: modelContext)
        showingTimePicker = false
      }
    }
  }

  @Environment(\.modelContext) private var modelContext
}

struct AlarmCard: View {
  let alarm: Alarm
  @ObservedObject var viewModel: AlarmViewModel
  @State private var showingTimePicker = false

  var body: some View {
    VStack(spacing: 20) {
      HStack {
        Image(systemName: "alarm.fill")
          .font(.system(size: 40))
          .foregroundColor(.accentColor)

        Spacer()

        AlarmToggle(
          isOn: Binding(
            get: { alarm.isEnabled },
            set: { _ in viewModel.toggleAlarm(alarm: alarm, context: modelContext) }
          ))
      }

      Button(action: { showingTimePicker = true }) {
        Text(Formatters.timeFormatter.string(from: alarm.time))
          .font(.system(size: 72, weight: .light, design: .rounded))
          .foregroundColor(alarm.isEnabled ? .primary : .secondary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(
        Localization.string(.alarmTime(Formatters.timeFormatter.string(from: alarm.time)))
      )
      .accessibilityHint("Double tap to edit alarm time")

      if alarm.isEnabled {
        Text(viewModel.timeRemainingText(for: alarm))
          .font(.system(size: 16))
          .foregroundColor(.secondary)
          .accessibilityLabel(viewModel.timeRemainingText(for: alarm))
      }

      HStack(spacing: 12) {
        GlassButton(title: Localization.string(.edit), icon: "pencil") {
          showingTimePicker = true
        }
        .accessibilityLabel(Localization.string(.edit))

        GlassButton(title: Localization.string(.delete), icon: "trash", isPrimary: true) {
          viewModel.deleteAlarm(alarm: alarm, context: modelContext)
        }
        .accessibilityLabel(Localization.string(.delete))
      }
    }
    .softCard(cornerRadius: 18, padding: 20, shadow: true)
    .sheet(isPresented: $showingTimePicker) {
      TimePickerView(initialTime: alarm.time) { time in
        alarm.time = time
        do {
          try modelContext.save()
        } catch {
          ErrorPresenter.presentOnMain(error)
        }
        if alarm.isEnabled {
          NotificationService.shared.cancelAlarmNotifications()
          NotificationService.shared.scheduleAlarmNotification(date: time)
        }
        showingTimePicker = false
      }
    }
  }

  @Environment(\.modelContext) private var modelContext
}

struct EmptyAlarmView: View {
  let onAdd: () -> Void

  var body: some View {
    VStack(spacing: 32) {
      ZStack {
        RoundedRectangle(cornerRadius: 36, style: .continuous)
          .fill(Color.accentColor.opacity(0.1))
          .frame(width: 140, height: 140)
          .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
              .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
          )

        Image(systemName: "alarm.fill")
          .font(.system(size: 64))
          .foregroundColor(.accentColor)
          .shadow(color: Color.accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
      }
      .padding(.bottom, 10)
      .accessibilityHidden(true)

      VStack(spacing: 12) {
        Text(Localization.string(.noAlarmSet))
          .font(.title2.weight(.bold))
          .foregroundColor(.primary)

        Text(Localization.string(.tapToSetAlarm))
          .font(.body)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 40)
      }

      Button(action: onAdd) {
        HStack {
          Image(systemName: "plus")
            .font(.headline)
          Text(Localization.string(.setAlarm))
            .font(.headline)
        }
        .foregroundColor(.white)
        .frame(height: 50)
        .padding(.horizontal, 32)
        .background(
          Capsule()
            .fill(Color.accentColor)
            .shadow(color: Color.accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
        )
      }
      .buttonStyle(.plain)
      .padding(.top, 20)
      .accessibilityLabel(Localization.string(.setAlarm))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}
