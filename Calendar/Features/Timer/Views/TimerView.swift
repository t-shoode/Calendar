import SwiftData
import SwiftUI

struct TimerView: View {
  @StateObject private var countdownViewModel = TimerViewModel(id: "countdown")
  @Query private var presets: [TimerPreset]
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 6) {
        CountdownView(viewModel: countdownViewModel, presets: presets)
          .transition(.opacity)
      }
      .frame(maxWidth: .infinity)
      .padding(.top, 8)
      .padding(.bottom, 12)
    }
    .scrollBounceBehavior(.basedOnSize)
    .onAppear {
      if presets.isEmpty {
        for preset in TimerPreset.defaultPresets {
          modelContext.insert(preset)
        }
      }
    }
  }
}
