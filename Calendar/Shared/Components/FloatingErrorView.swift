import SwiftUI

struct FloatingErrorView: View {
  @State private var message: String? = nil

  var body: some View {
    Group {
      if let msg = message {
        VStack {
          HStack(alignment: .center, spacing: 12) {
            ZStack {
              Circle()
                .fill(Color.red.opacity(0.12))
                .frame(width: 28, height: 28)
              Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.red)
            }

            Text(msg)
              .foregroundColor(.textPrimary)
              .font(Typography.subheadline.weight(.semibold))
              .lineLimit(2)
              .multilineTextAlignment(.leading)

            Spacer()

            Button(action: { message = nil }) {
              Image(systemName: "xmark")
                .foregroundColor(.textSecondary)
                .font(.system(size: 13, weight: .black))
            }
            .buttonStyle(.plain)
            .pressableScale(0.9)
          }
          .softCard(cornerRadius: 14, padding: 12, shadow: true)
          .padding(.top, 12)
          .padding(.horizontal, 16)

          Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.26, dampingFraction: 0.86), value: msg)
        .onTapGesture { message = nil }
#if os(iOS)
        .sensoryFeedback(.error, trigger: msg)
#endif
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .appErrorOccurred)) { note in
      if let msg = note.userInfo?["message"] as? String {
        withAnimation { message = msg }
        Task { @MainActor in
          try? await Task.sleep(nanoseconds: 5_000_000_000)
          withAnimation { message = nil }
        }
      }
    }
  }
}
