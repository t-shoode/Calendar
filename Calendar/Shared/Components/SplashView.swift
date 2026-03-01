import SwiftUI

struct SplashView: View {
  @ObservedObject var manager: StartupManager

  var body: some View {
    ZStack {
      MeshGradientView()
        .ignoresSafeArea()

      LinearGradient(
        colors: [Color.black.opacity(0.25), Color.black.opacity(0.52)],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      VStack(spacing: 18) {
        ZStack {
          Circle()
            .fill(Color.accentColor.opacity(0.16))
            .frame(width: 84, height: 84)
          Circle()
            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            .frame(width: 92, height: 92)
          Image(systemName: "calendar")
            .font(.system(size: 34, weight: .bold))
            .foregroundColor(.accentColor)
        }

        VStack(spacing: 8) {
          Text(Localization.string(.splashStarting))
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(.textPrimary)

          Text(
            manager.progressMessage.isEmpty
              ? Localization.string(.splashSyncingWidgets) : manager.progressMessage
          )
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundColor(.textSecondary)
          .multilineTextAlignment(.center)
        }

        ProgressView()
          .tint(.accentColor)
          .scaleEffect(1.1)

        if manager.timedOut {
          Button(action: { manager.continueInBackground() }) {
            Text(Localization.string(.splashContinueInBackground))
              .font(.system(size: 13, weight: .semibold, design: .rounded))
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 40)
              .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .fill(Color.accentColor)
              )
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("ContinueBackgroundButton")
        }

        Text(Localization.string(.splashPreGenerating))
          .font(.system(size: 11, weight: .medium, design: .rounded))
          .foregroundColor(.textTertiary)
          .multilineTextAlignment(.center)
      }
      .softCard(cornerRadius: 22, padding: 22, shadow: true)
      .padding(.horizontal, 28)
      .frame(maxWidth: 420)
      .padding(.top, 12)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("StartupSplashView")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ignoresSafeArea()
    .zIndex(9999)
  }
}
