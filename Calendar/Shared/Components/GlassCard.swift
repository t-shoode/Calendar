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
          .fill(AppPalette.cardFill.opacity(materialOpacity))
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(AppPalette.sectionBorder, lineWidth: 0.7)
      )
      .shadow(color: AppPalette.subtleShadow, radius: AppElevation.low, x: 0, y: 2)
  }

  private var materialOpacity: Double {
    switch material {
    case .ultraThin:
      return 0.95
    case .thin:
      return 0.98
    case .regular:
      return 1
    }
  }
}
