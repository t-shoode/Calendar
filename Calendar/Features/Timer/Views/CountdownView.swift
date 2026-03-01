import SwiftUI

struct CountdownView: View {
  @ObservedObject var viewModel: TimerViewModel
  let presets: [TimerPreset]

  var body: some View {
    VStack {
      TimerDisplay(
        remainingTime: viewModel.remainingTime, isRunning: viewModel.isRunning,
        isStopwatch: viewModel.isStopwatch
      )
      .padding(.bottom, 16)

      TimerControls(
        isRunning: viewModel.isRunning,
        isPaused: viewModel.isPaused,
        onPlay: {
          if viewModel.isPaused {
            viewModel.resumeTimer()
          } else if viewModel.remainingTime > 0 && !viewModel.isRunning {
            viewModel.startTimer(duration: viewModel.remainingTime)
          } else if let preset = viewModel.selectedPreset {
            viewModel.startTimer(duration: preset.duration)
          } else {
            viewModel.startStopwatch()
          }
        },
        onPause: {
          viewModel.pauseTimer()
        },
        onReset: {
          if viewModel.isStopwatch {
            viewModel.stopTimer()
          } else {
            viewModel.resetTimer()
          }
        },
        onStop: {
          viewModel.stopTimer()
          viewModel.selectedPreset = nil
        }
      )
      .padding(.bottom, 20)
      .softCard(cornerRadius: 24, padding: 14, shadow: false)
      .padding(.horizontal, 24)

      if !viewModel.isRunning && !viewModel.isPaused && !presets.isEmpty {
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text(Localization.string(.timer))
              .font(.system(size: 12, weight: .semibold, design: .rounded))
              .foregroundColor(.textTertiary)
            Spacer()
          }

          PresetsGrid(presets: presets) { preset in
            viewModel.stopTimer()
            viewModel.selectedPreset = preset
            viewModel.startTimer(duration: preset.duration)
          }
        }
        .softCard(cornerRadius: 18, padding: 14, shadow: false)
        .padding(.horizontal, 20)
      }
    }
    .frame(maxWidth: .infinity, alignment: .top)
    .padding(.bottom, 8)
  }
}
