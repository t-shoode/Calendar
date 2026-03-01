import SwiftUI

struct TimerControls: View {
  let isRunning: Bool
  let isPaused: Bool
  let onPlay: () -> Void
  let onPause: () -> Void
  let onReset: () -> Void
  let onStop: () -> Void

  var body: some View {
    HStack(spacing: 16) {
      ControlButton(icon: "arrow.counterclockwise", action: onReset)

      if isRunning && !isPaused {
        ControlButton(icon: "pause.fill", size: 80, isPrimary: true, action: onPause)
      } else {
        ControlButton(icon: "play.fill", size: 80, isPrimary: true, action: onPlay)
      }

      ControlButton(icon: "stop.fill", action: onStop)
    }
  }
}

struct ControlButton: View {
  let icon: String
  var size: CGFloat = 60
  var isPrimary: Bool = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: size * 0.35, weight: .semibold))
        .frame(width: size, height: size)
        .foregroundColor(isPrimary ? .white : .textPrimary)
        .background(backgroundView)
    }
    .buttonStyle(.plain)
    .scaleEffect(1.0)
    .pressableScale()
  }

  @ViewBuilder
  private var backgroundView: some View {
    if isPrimary {
      Color.accentColor
        .clipShape(Circle())
        .shadow(color: Color.accentColor.opacity(0.2), radius: 8, x: 0, y: 4)
    } else {
      Circle()
        .fill(Color.secondaryFill.opacity(0.78))
        .overlay(
          Circle()
            .stroke(Color.border.opacity(0.2), lineWidth: 0.7)
        )
    }
  }
}

struct PressableScale: ViewModifier {
  let scale: CGFloat
  let animation: Animation
  @GestureState private var isPressed = false

  func body(content: Content) -> some View {
    content
      .scaleEffect(isPressed ? scale : 1.0)
      .brightness(isPressed ? -0.02 : 0)
      .animation(animation, value: isPressed)
      .simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .updating($isPressed) { _, state, _ in
            state = true
          }
      )
  }
}

extension View {
  func pressableScale(
    _ scale: CGFloat = 0.95,
    animation: Animation = .spring(response: 0.22, dampingFraction: 0.82)
  ) -> some View {
    modifier(PressableScale(scale: scale, animation: animation))
  }
}
