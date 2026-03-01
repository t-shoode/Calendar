import SwiftUI

struct FloatingTabBar: View {
  @Binding var selectedTab: AppState.Tab?
  private let itemSpacing: CGFloat = 6
  private let itemHeight: CGFloat = 44
  private let containerInset: CGFloat = 7

  var body: some View {
    content
#if os(iOS)
      .sensoryFeedback(.selection, trigger: selectedTab)
#endif
  }

  private var content: some View {
    GeometryReader { proxy in
      let tabs = AppState.Tab.allCases
      let tabCount = CGFloat(tabs.count)
      let availableWidth = proxy.size.width - (containerInset * 2) - (itemSpacing * (tabCount - 1))
      let itemWidth = max(0, availableWidth / max(tabCount, 1))
      let selectedIndex = CGFloat(
        tabs.firstIndex(of: selectedTab ?? .calendar) ?? 0
      )

      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(Color.accentColor)
          .frame(width: itemWidth, height: itemHeight)
          .offset(x: containerInset + selectedIndex * (itemWidth + itemSpacing))
          .animation(.spring(response: 0.28, dampingFraction: 0.86), value: selectedTab)

        HStack(spacing: itemSpacing) {
          ForEach(tabs) { tab in
            let isSelected = selectedTab == tab
            Button {
              withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                selectedTab = tab
              }
            } label: {
              Image(systemName: tabIcon(for: tab))
                .font(.system(size: isSelected ? 20 : 18, weight: .semibold))
                .foregroundColor(isSelected ? .white : .textSecondary)
                .frame(width: itemWidth, height: itemHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pressableScale(0.96, animation: .spring(response: 0.2, dampingFraction: 0.84))
            .accessibilityLabel(tabTitle(for: tab))
          }
        }
        .padding(containerInset)
      }
    }
    .frame(height: itemHeight + containerInset * 2)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(Color.surfaceCard.opacity(0.95))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(Color.border.opacity(0.3), lineWidth: 0.7)
    )
    .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
    .padding(.horizontal, 16)
    .padding(.bottom, 8)
  }

  private func tabIcon(for tab: AppState.Tab) -> String {
    switch tab {
    case .calendar: return "calendar.circle.fill"
    case .tasks: return "checkmark.circle.fill"
    case .expenses: return "creditcard.circle.fill"
    case .clock: return "clock"
    case .weather: return "cloud.sun"
    }
  }

  private func tabTitle(for tab: AppState.Tab) -> String {
    switch tab {
    case .calendar:
      return Localization.string(.tabCalendar)
    case .tasks:
      return Localization.string(.tabTodo)
    case .expenses:
      return Localization.string(.tabExpenses)
    case .clock:
      return Localization.string(.tabClock)
    case .weather:
      return Localization.string(.tabWeather)
    }
  }
}
