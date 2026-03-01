import SwiftUI

struct FloatingTabBar: View {
  @Binding var selectedTab: AppState.Tab?
  @Namespace private var tabSelection

  var body: some View {
    content
#if os(iOS)
      .sensoryFeedback(.selection, trigger: selectedTab)
#endif
  }

  private var content: some View {
    HStack(spacing: 6) {
      ForEach(AppState.Tab.allCases) { tab in
        let isSelected = selectedTab == tab
        Button {
          withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
            selectedTab = tab
          }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: tabIcon(for: tab))
              .font(.system(size: 14, weight: .semibold))
              .symbolEffect(.bounce, value: isSelected)
            if isSelected {
              Text(tabTitle(for: tab))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
          }
          .foregroundColor(isSelected ? .white : .textSecondary)
          .frame(maxWidth: .infinity, minHeight: 38)
          .padding(.horizontal, isSelected ? 10 : 4)
          .background(alignment: .center) {
            if isSelected {
              RoundedRectangle(cornerRadius: 14)
                .fill(Color.accentColor)
                .matchedGeometryEffect(id: "selected-tab", in: tabSelection)
            }
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pressableScale(0.96, animation: .spring(response: 0.2, dampingFraction: 0.84))
      }
    }
    .padding(6)
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
