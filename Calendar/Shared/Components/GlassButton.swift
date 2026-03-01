import SwiftUI

struct GlassButton: View {
  let title: String
  let icon: String?
  let action: () -> Void
  let isPrimary: Bool

  init(title: String, icon: String? = nil, isPrimary: Bool = false, action: @escaping () -> Void) {
    self.title = title
    self.icon = icon
    self.isPrimary = isPrimary
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      content
    }
    .buttonStyle(.plain)
    .pressableScale(0.97, animation: .spring(response: 0.24, dampingFraction: 0.8))
  }

  private var content: some View {
    HStack(spacing: Spacing.xs) {
      if let icon = icon {
        Image(systemName: icon)
          .font(.system(size: 14, weight: .semibold))
      }
      Text(title)
        .font(Typography.subheadline.weight(.semibold))
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .foregroundColor(isPrimary ? .white : .textPrimary)
    .background(backgroundView)
  }

  @ViewBuilder
  private var backgroundView: some View {
    if isPrimary {
      RoundedRectangle(cornerRadius: Spacing.smallRadius, style: .continuous)
        .fill(Color.accentColor)
        .shadow(color: Color.accentColor.opacity(0.2), radius: 8, x: 0, y: 4)
    } else {
      RoundedRectangle(cornerRadius: Spacing.smallRadius, style: .continuous)
        .fill(Color.secondaryFill.opacity(0.7))
        .overlay(
          RoundedRectangle(cornerRadius: Spacing.smallRadius, style: .continuous)
            .stroke(Color.border.opacity(0.2), lineWidth: 0.7)
        )
    }
  }
}
