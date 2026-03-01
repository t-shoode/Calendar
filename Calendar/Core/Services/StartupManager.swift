import Combine
import Foundation
import SwiftData
import SwiftUI
import WidgetKit

@MainActor
final class StartupManager: ObservableObject {
  @Published public private(set) var isRunning: Bool = false
  @Published public private(set) var progressMessage: String = ""
  @Published public private(set) var timedOut: Bool = false

  private let timeout: TimeInterval
  private var timeoutTask: Task<Void, Never>? = nil

  // Minimum visible duration for the splash to avoid a quick flicker
  private let minimumDisplayDuration: TimeInterval
  private var startDate: Date?

  /// Inject a shorter timeout for tests. Default timeout = 120s, minimum display = 2.0s.
  init(timeout: TimeInterval = 120, minimumDisplayDuration: TimeInterval = 2.0) {
    self.timeout = timeout
    self.minimumDisplayDuration = minimumDisplayDuration
  }

  deinit {
    timeoutTask?.cancel()
  }

  /// Start the app startup orchestration. Safe to call from the main thread.
  public func start(using context: ModelContext) {
    guard !isRunning else { return }
    isRunning = true
    timedOut = false
    progressMessage = "Preparing…"

    // Start a timeout monitor (sets `timedOut = true` when elapsed)
    timeoutTask = Task { [weak self] in
      guard let self = self else { return }
      do {
        try await Task.sleep(nanoseconds: UInt64(self.timeout * 1_000_000_000))
        await MainActor.run { self.timedOut = true }
      } catch { /* cancelled */  }
    }

    // Run startup steps using a background ModelContext for SwiftData-heavy work.
    // UI updates remain on MainActor; data work uses a separate ModelContext from the same ModelContainer.
    let container = context.container
    let backgroundContext = ModelContext(container)

    Task.detached(priority: .background) { [weak self] in
      guard let self = self else { return }

      // Record start time on main actor and show initial message
      await MainActor.run {
        self.startDate = Date()
        self.progressMessage = Localization.string(.splashSyncingWidgets)
      }

      // Data-only: prepare widget payloads (background context)
      await MainActor.run {
        EventViewModel().syncEventsToWidget(context: backgroundContext)
      }

      // Generate recurring expenses (background context)
      await MainActor.run { self.progressMessage = Localization.string(.splashGeneratingRecurring) }
      await MainActor.run {
        RecurringExpenseService.shared.generateRecurringExpenses(context: backgroundContext)
      }

      // Cleanup todos (background context)
      await MainActor.run { self.progressMessage = Localization.string(.splashCleaningTodos) }
      await MainActor.run {
        TodoViewModel().cleanupCompletedTodos(context: backgroundContext)
        TodoViewModel().rescheduleAllNotifications(context: backgroundContext)
      }

      // Refresh FX rates (loads cached rates first, then does a daily network refresh if needed)
      await MainActor.run { self.progressMessage = Localization.string(.splashRefreshingFX) }
      await FXRateService.shared.refreshRatesIfNeeded(context: backgroundContext)

      // Weather refresh must run on MainActor (updates @Published)
      await MainActor.run { self.progressMessage = Localization.string(.splashRefreshingWeather) }
      await Task { @MainActor in await WeatherViewModel().refreshIfNeeded() }.value

      // Finalize on main actor
      await MainActor.run {
        self.progressMessage = Localization.string(.splashFinalizing)
      }

      // Reload widgets on main actor so widget timelines see saved changes
      await MainActor.run {
        WidgetCenter.shared.reloadAllTimelines()
      }

      // Ensure minimum display duration: compute on main actor, sleep in background
      let remainingToShow = await MainActor.run { () -> TimeInterval in
        if let started = self.startDate {
          let elapsed = Date().timeIntervalSince(started)
          let remaining = self.minimumDisplayDuration - elapsed
          return remaining > 0 ? remaining : 0
        }
        return 0
      }
      if remainingToShow > 0 {
        try? await Task.sleep(nanoseconds: UInt64(remainingToShow * 1_000_000_000))
      }

      // Done — cancel timeout monitor and clear state on main actor
      await MainActor.run {
        self.timeoutTask?.cancel()
        self.isRunning = false
        self.timedOut = false
        self.progressMessage = ""
        self.startDate = nil
      }
    }
  }

  /// Dismiss the blocking UI while letting startup continue in the background.
  public func continueInBackground() {
    // UI-level dismissal only — startup Task continues to completion.
    isRunning = false
  }
}
