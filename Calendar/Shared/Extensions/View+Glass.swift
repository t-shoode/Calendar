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
          .fill(AppPalette.cardFill)
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(AppPalette.sectionBorder, lineWidth: 0.7)
      )
      .shadow(
        color: shadow ? AppPalette.subtleShadow : .clear,
        radius: shadow ? AppElevation.medium : AppElevation.none,
        x: 0,
        y: shadow ? 3 : 0
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
          .fill(AppPalette.controlFill)
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(AppPalette.sectionBorder, lineWidth: 0.7)
      )
  }
}

private struct SoftChipModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(.horizontal, AppSpacing.xs)
      .padding(.vertical, AppSpacing.xxs)
      .background(
        Capsule()
          .fill(AppPalette.chipFill)
      )
      .overlay(
        Capsule()
          .stroke(AppPalette.sectionBorder, lineWidth: 0.7)
      )
  }
}

struct MinimalCard<Content: View>: View {
  let cornerRadius: CGFloat
  let padding: CGFloat
  let showShadow: Bool
  @ViewBuilder let content: Content

  init(
    cornerRadius: CGFloat = AppRadius.card,
    padding: CGFloat = AppSpacing.md,
    showShadow: Bool = false,
    @ViewBuilder content: () -> Content
  ) {
    self.cornerRadius = cornerRadius
    self.padding = padding
    self.showShadow = showShadow
    self.content = content()
  }

  var body: some View {
    content
      .padding(padding)
      .background(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(AppPalette.cardFill)
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(AppPalette.sectionBorder, lineWidth: 0.7)
      )
      .shadow(
        color: showShadow ? AppPalette.subtleShadow : .clear,
        radius: showShadow ? AppElevation.low : AppElevation.none,
        x: 0,
        y: showShadow ? 2 : 0
      )
  }
}

struct MinimalSection<Header: View, Content: View>: View {
  let spacing: CGFloat
  @ViewBuilder let header: Header
  @ViewBuilder let content: Content

  init(
    spacing: CGFloat = AppSpacing.sm,
    @ViewBuilder header: () -> Header,
    @ViewBuilder content: () -> Content
  ) {
    self.spacing = spacing
    self.header = header()
    self.content = content()
  }

  var body: some View {
    MinimalCard {
      VStack(alignment: .leading, spacing: spacing) {
        header
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct MinimalToolbarButton: View {
  let systemImage: String
  let accessibilityLabel: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.textPrimary)
        .frame(width: 32, height: 32)
        .background(
          RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
            .fill(AppPalette.controlFill)
        )
        .overlay(
          RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
            .stroke(AppPalette.sectionBorder, lineWidth: 0.7)
        )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
  }
}

struct MinimalSegmentedControl: View {
  let titles: [String]
  @Binding var selectedIndex: Int

  var body: some View {
    HStack(spacing: 4) {
      ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
        Button {
          withAnimation(AppMotion.quick) {
            selectedIndex = index
          }
        } label: {
          Text(title)
            .font(Typography.caption.weight(.semibold))
            .foregroundColor(selectedIndex == index ? .backgroundPrimary : .textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
              RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(selectedIndex == index ? Color.appAccent : .clear)
            )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(4)
    .background(
      RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
        .fill(AppPalette.controlFill)
    )
    .overlay(
      RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
        .stroke(AppPalette.sectionBorder, lineWidth: 0.7)
    )
  }
}

struct MinimalListRow<Content: View>: View {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    content
      .padding(.horizontal, AppSpacing.md)
      .padding(.vertical, AppSpacing.sm)
      .background(
        RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
          .fill(AppPalette.controlFill)
      )
      .overlay(
        RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
          .stroke(AppPalette.sectionBorder, lineWidth: 0.7)
      )
  }
}
