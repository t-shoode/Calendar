import SwiftUI

struct TimerDisplay: View {
  let remainingTime: TimeInterval
  let isRunning: Bool
  var isStopwatch: Bool = false

  private var formattedTime: String {
    Formatters.formatTimerDuration(remainingTime)
  }

  private var progress: Double {
    if isStopwatch {
      return 1.0
    }
    // Note: totalDuration should probably come from viewModel, but keeping logic consistent with existing
    let totalDuration: TimeInterval = 3600 
    return 1.0 - (remainingTime / totalDuration)
  }

  var body: some View {
    ZStack {
      Circle()
        .stroke(Color.textTertiary.opacity(0.14), lineWidth: 10)

      Circle()
        .trim(from: 0, to: progress)
        .stroke(
          LinearGradient(
            colors: [.accentColor.opacity(0.6), .accentColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          style: StrokeStyle(lineWidth: 10, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.easeOut(duration: 0.25), value: progress)
        .shadow(color: .accentColor.opacity(0.18), radius: 6, x: 0, y: 0)

      VStack(spacing: 8) {
          Text(formattedTime)
            .font(.system(size: 64, weight: .black, design: .rounded))
            .foregroundColor(.textPrimary)
            .monospacedDigit()
          
          if isRunning {
              Text(isStopwatch ? "ELAPSED" : "REMAINING")
                  .font(.system(size: 10, weight: .semibold, design: .rounded))
                  .tracking(2)
                  .foregroundColor(.textTertiary)
          }
      }
    }
    .frame(width: 250, height: 250)
    .softCard(cornerRadius: 140, padding: 18, shadow: false)
    .accessibilityLabel(Localization.string(.timeRemaining(formattedTime)))
  }
}
