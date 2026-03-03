import Combine
import SwiftData
import SwiftUI
import WidgetKit

class TimerViewModel: ObservableObject {
  @Published var remainingTime: TimeInterval = 0
  @Published var totalDuration: TimeInterval = 0
  @Published var isRunning: Bool = false
  @Published var isPaused: Bool = false
  @Published var selectedPreset: TimerPreset?
  @Published var workSessions: Int = 0
  @Published var isWorkSession: Bool = true
  @Published var isStopwatch: Bool = false

  private var timer: AnyCancellable?
  private var endTime: Date?
  private var startTime: Date?
  private let timerId: String

  init(id: String = "default") {
    self.timerId = id
    restoreState()
  }

  func startTimer(duration: TimeInterval) {
    remainingTime = duration
    totalDuration = duration
    endTime = Date().addingTimeInterval(duration)
    isRunning = true
    isPaused = false
    isStopwatch = false

    saveState()

    UserDefaults.shared.set(true, forKey: "hasActiveTimer")

    NotificationService.shared.scheduleTimerNotification(duration: duration, identifier: timerId)
    WidgetCenter.shared.reloadTimelines(ofKind: "CalendarWidget")

    startTick()
  }

  func startStopwatch() {
    remainingTime = 0
    totalDuration = 0
    startTime = Date()
    isRunning = true
    isPaused = false
    isStopwatch = true

    saveState()

    UserDefaults.shared.set(true, forKey: "hasActiveTimer")

    WidgetCenter.shared.reloadTimelines(ofKind: "CalendarWidget")

    startTick()
  }

  func pauseTimer() {
    isPaused = true
    timer?.cancel()
    NotificationService.shared.cancelTimerNotifications(identifier: timerId)
    saveState()
  }

  func resumeTimer() {
    isPaused = false
    if isStopwatch {
      startTime = Date().addingTimeInterval(-remainingTime)
      startTick()
    } else {
      endTime = Date().addingTimeInterval(remainingTime)
      NotificationService.shared.scheduleTimerNotification(
        duration: remainingTime, identifier: timerId)
      startTick()
    }
    saveState()
  }

  func stopTimer() {
    isRunning = false
    isPaused = false
    remainingTime = 0
    totalDuration = 0
    timer?.cancel()
    timer = nil
    endTime = nil
    startTime = nil
    isStopwatch = false

    saveState()

    UserDefaults.shared.set(false, forKey: "hasActiveTimer")

    NotificationService.shared.cancelTimerNotifications(identifier: timerId)
    WidgetCenter.shared.reloadTimelines(ofKind: "CalendarWidget")
  }

  func resetTimer() {
    stopTimer()
    if let preset = selectedPreset {
      remainingTime = preset.duration
      totalDuration = preset.duration
      saveState()
    }
  }

  func terminateSession(remaining: TimeInterval) {
    isRunning = false
    isPaused = false
    remainingTime = remaining
    timer?.cancel()
    timer = nil
    endTime = nil
    startTime = nil

    saveState()

    UserDefaults.shared.set(false, forKey: "hasActiveTimer")

    NotificationService.shared.cancelTimerNotifications(identifier: timerId)
    WidgetCenter.shared.reloadTimelines(ofKind: "CalendarWidget")
  }

  private func startTick() {
    timer = Timer.publish(every: 0.1, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        self?.updateTimer()
      }
  }

  private func updateTimer() {
    if isStopwatch {
      guard let startTime = startTime else { return }
      remainingTime = Date().timeIntervalSince(startTime)
    } else {
      guard let endTime = endTime else { return }

      let remaining = endTime.timeIntervalSince(Date())
      if remaining <= 0 {
        remainingTime = 0
        stopTimer()
        AudioService.shared.playTimerEndSound()
      } else {
        remainingTime = remaining
      }
    }
  }

  private func saveState() {
    let defaults = UserDefaults.shared
    defaults.set(remainingTime, forKey: "\(timerId).remainingTime")
    defaults.set(totalDuration, forKey: "\(timerId).totalDuration")
    defaults.set(isRunning, forKey: "\(timerId).isRunning")
    defaults.set(isPaused, forKey: "\(timerId).isPaused")
    defaults.set(workSessions, forKey: "\(timerId).workSessions")
    defaults.set(isWorkSession, forKey: "\(timerId).isWorkSession")
    defaults.set(isStopwatch, forKey: "\(timerId).isStopwatch")

    if let endTime = endTime {
      defaults.set(endTime, forKey: "\(timerId).endTime")
    } else {
      defaults.removeObject(forKey: "\(timerId).endTime")
    }

    if let startTime = startTime {
      defaults.set(startTime, forKey: "\(timerId).startTime")
    } else {
      defaults.removeObject(forKey: "\(timerId).startTime")
    }
  }

  func restoreState() {
    let defaults = UserDefaults.shared
    remainingTime = defaults.double(forKey: "\(timerId).remainingTime")
    totalDuration = defaults.double(forKey: "\(timerId).totalDuration")
    isRunning = defaults.bool(forKey: "\(timerId).isRunning")
    isPaused = defaults.bool(forKey: "\(timerId).isPaused")
    workSessions = defaults.integer(forKey: "\(timerId).workSessions")
    isStopwatch = defaults.bool(forKey: "\(timerId).isStopwatch")

    if defaults.object(forKey: "\(timerId).isWorkSession") != nil {
      isWorkSession = defaults.bool(forKey: "\(timerId).isWorkSession")
    }

    // Backward compatibility for state saved before `totalDuration` existed.
    if !isStopwatch && totalDuration <= 0 && remainingTime > 0 {
      totalDuration = remainingTime
    }

    if isStopwatch {
      if let savedStartTime = defaults.object(forKey: "\(timerId).startTime") as? Date {
        startTime = savedStartTime

        if isRunning && !isPaused {
          remainingTime = Date().timeIntervalSince(savedStartTime)
          startTick()
        }
      }
    } else {
      if let savedEndTime = defaults.object(forKey: "\(timerId).endTime") as? Date {
        endTime = savedEndTime

        if isRunning && !isPaused {
          let currentRemaining = savedEndTime.timeIntervalSince(Date())
          if currentRemaining > 0 {
            remainingTime = currentRemaining
            startTick()
          } else {
            remainingTime = 0
            isRunning = false
            isPaused = false
            endTime = nil
            saveState()
          }
        }
      }
    }
  }
}

extension UserDefaults {
  static var shared: UserDefaults {
    UserDefaults(suiteName: Constants.Storage.appGroupIdentifier) ?? .standard
  }
}
