import SwiftUI

struct TimerDisplay: View {
  let remainingTime: TimeInterval
  let isRunning: Bool
  let isPaused: Bool
  var isStopwatch: Bool = false
  var totalDuration: TimeInterval = 0

  private var formattedTime: String {
    Formatters.formatTimerDuration(remainingTime)
  }

  private var progress: Double {
    if isStopwatch {
      return (isRunning || isPaused || remainingTime > 0) ? 1.0 : 0
    }
    guard totalDuration > 0 else { return 0 }
    return min(max(1.0 - (remainingTime / totalDuration), 0), 1)
  }

  var body: some View {
    ZStack {
      Circle()
        .fill(Color.surfaceCard)

      Circle()
        .stroke(Color.border.opacity(0.28), lineWidth: 1)

      Circle()
        .stroke(Color.textTertiary.opacity(0.2), lineWidth: 8)

      if progress > 0.001 {
        Circle()
          .trim(from: 0, to: progress)
          .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
          .rotationEffect(.degrees(-90))
          .animation(.easeOut(duration: 0.25), value: progress)
      }

      VStack(spacing: 8) {
        Text(formattedTime)
          .font(.system(size: 64, weight: .black))
          .foregroundColor(.textPrimary)
          .monospacedDigit()

        if isRunning || isPaused {
          Text(isStopwatch ? "ELAPSED" : "REMAINING")
            .font(.system(size: 10, weight: .semibold))
            .tracking(2)
            .foregroundColor(.textTertiary)
        }
      }
    }
    .frame(width: 264, height: 264)
    .accessibilityLabel(Localization.string(.timeRemaining(formattedTime)))
  }
}
