import SwiftUI

struct AlarmToggle: View {
  @Binding var isOn: Bool

  var body: some View {
    Button(action: { isOn.toggle() }) {
      RoundedRectangle(cornerRadius: 16)
        .fill(isOn ? Color.appAccent : Color.tertiaryFill)
        .frame(width: 52, height: 32)
        .overlay(
          Circle()
            .fill(.white)
            .frame(width: 28, height: 28)
            .offset(x: isOn ? 10 : -10)
            .animation(.spring(response: 0.3), value: isOn)
        )
    }
    .buttonStyle(.plain)
  }
}
