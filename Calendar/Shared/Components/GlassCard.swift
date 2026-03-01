import SwiftUI

struct GlassCard<Content: View>: View {
  let content: Content
  let cornerRadius: CGFloat
  let material: MeshGradientMaterial

  enum MeshGradientMaterial {
    case ultraThin
    case thin
    case regular
  }

  init(
    cornerRadius: CGFloat = Spacing.cardRadius,
    material: MeshGradientMaterial = .thin,
    @ViewBuilder content: () -> Content
  ) {
    self.cornerRadius = cornerRadius
    self.material = material
    self.content = content()
  }

  var body: some View {
    content
      .padding(Spacing.cardPadding)
      .background(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(Color.surfaceCard.opacity(materialOpacity))
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(Color.border.opacity(0.3), lineWidth: 0.7)
      )
      .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
  }

  private var materialOpacity: Double {
    switch material {
    case .ultraThin:
      return 0.82
    case .thin:
      return 0.9
    case .regular:
      return 0.98
    }
  }
}
