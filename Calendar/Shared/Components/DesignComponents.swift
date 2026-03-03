import SwiftUI

// Legacy compatibility wrappers. Visual style is now minimal and flat.

struct GlassHaloModifier: ViewModifier {
  let cornerRadius: CGFloat

  func body(content: Content) -> some View {
    content
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(AppPalette.elevatedBorder, lineWidth: 0.7)
      )
  }
}

extension View {
  func glassHalo(cornerRadius: CGFloat = Spacing.cardRadius) -> some View {
    modifier(GlassHaloModifier(cornerRadius: cornerRadius))
  }
}
