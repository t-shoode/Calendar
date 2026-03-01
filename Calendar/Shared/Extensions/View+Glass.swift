import SwiftUI

extension View {
  /// Conditionally apply a modifier only when the condition is true.
  @ViewBuilder
  func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
    if condition {
      transform(self)
    } else {
      self
    }
  }

  /// Primary app surface used for cards/sections.
  func softCard(
    cornerRadius: CGFloat = 14,
    padding: CGFloat = 12,
    shadow: Bool = true
  ) -> some View {
    modifier(
      SoftCardModifier(
        cornerRadius: cornerRadius,
        padding: padding,
        shadow: shadow
      )
    )
  }

  /// Secondary surface for controls like segmented wrappers and input containers.
  func softControl(cornerRadius: CGFloat = 12, padding: CGFloat = 6) -> some View {
    modifier(SoftControlModifier(cornerRadius: cornerRadius, padding: padding))
  }

  /// Small pill/chip surface for metadata and tags.
  func softChip() -> some View {
    modifier(SoftChipModifier())
  }
}

private struct SoftCardModifier: ViewModifier {
  let cornerRadius: CGFloat
  let padding: CGFloat
  let shadow: Bool

  func body(content: Content) -> some View {
    content
      .padding(padding)
      .background(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(Color.surfaceCard.opacity(0.92))
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(Color.border.opacity(0.24), lineWidth: 0.7)
      )
      .shadow(
        color: shadow ? Color.black.opacity(0.05) : .clear,
        radius: shadow ? 10 : 0,
        x: 0,
        y: shadow ? 4 : 0
      )
  }
}

private struct SoftControlModifier: ViewModifier {
  let cornerRadius: CGFloat
  let padding: CGFloat

  func body(content: Content) -> some View {
    content
      .padding(padding)
      .background(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(Color.secondaryFill.opacity(0.6))
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(Color.border.opacity(0.18), lineWidth: 0.7)
      )
  }
}

private struct SoftChipModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        Capsule()
          .fill(Color.secondaryFill.opacity(0.72))
      )
      .overlay(
        Capsule()
          .stroke(Color.border.opacity(0.18), lineWidth: 0.7)
      )
  }
}
