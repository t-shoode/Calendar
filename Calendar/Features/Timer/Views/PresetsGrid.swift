import SwiftUI

struct PresetsGrid: View {
  let presets: [TimerPreset]
  let onSelect: (TimerPreset) -> Void

  private let columns = [
    GridItem(.flexible()),
    GridItem(.flexible()),
    GridItem(.flexible()),
    GridItem(.flexible()),
  ]

  var body: some View {
    LazyVGrid(columns: columns, spacing: 12) {
      ForEach(presets.sorted(by: { $0.order < $1.order })) { preset in
        PresetButton(preset: preset) {
          onSelect(preset)
        }
      }
    }
    .padding(.horizontal)
  }
}

struct PresetButton: View {
  let preset: TimerPreset
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 2) {
        Text("\(Int(preset.duration / 60))")
          .font(.system(size: 22, weight: .bold))
          .foregroundColor(.textPrimary)
        Text(Localization.string(.minutesUnit).uppercased())
          .font(.system(size: 11, weight: .semibold))
          .tracking(0.8)
          .foregroundColor(.textSecondary)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 42)
      .softControl(cornerRadius: 14, padding: 10)
    }
    .buttonStyle(.plain)
  }
}
