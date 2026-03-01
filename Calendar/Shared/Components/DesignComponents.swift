import SwiftUI

struct MeshGradientView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.12))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(x: 180, y: -260)

            Circle()
                .fill(Color.eventBlue.opacity(colorScheme == .dark ? 0.18 : 0.1))
                .frame(width: 380, height: 380)
                .blur(radius: 95)
                .offset(x: -180, y: 300)
        }
        .ignoresSafeArea()
    }

    private var backgroundGradient: [Color] {
        if colorScheme == .dark {
            return Color.atmosphereNight
        }
        return Color.atmosphereBlue
    }
}

struct GlassHaloModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        colorScheme == .dark
                        ? Color.white.opacity(0.12)
                        : Color.black.opacity(0.08),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: Color.shadowColor, radius: 8, x: 0, y: 4)
    }
}

extension View {
    func glassHalo(cornerRadius: CGFloat = Spacing.cardRadius) -> some View {
        modifier(GlassHaloModifier(cornerRadius: cornerRadius))
    }
}
