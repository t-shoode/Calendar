import SwiftData
import SwiftUI

struct ClockView: View {
  @State private var selectedSection: ClockSection = .timer

  enum ClockSection {
    case timer
    case alarm
  }

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Text(Localization.string(.tabClock))
          .font(.system(size: 22, weight: .bold, design: .rounded))
          .foregroundColor(.textPrimary)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 8)

      HStack(spacing: 0) {
          Button {
              withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { selectedSection = .timer }
          } label: {
              Text(Localization.string(.tabTimer))
                  .font(.system(size: 13, weight: .semibold, design: .rounded))
                  .foregroundColor(selectedSection == .timer ? .white : .textSecondary)
                  .frame(maxWidth: .infinity)
                  .frame(height: 36)
                  .background(selectedSection == .timer ? Color.accentColor : Color.clear)
                  .clipShape(RoundedRectangle(cornerRadius: 10))
          }
          .buttonStyle(.plain)
          
          Button {
              withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { selectedSection = .alarm }
          } label: {
              Text(Localization.string(.tabAlarm))
                  .font(.system(size: 13, weight: .semibold, design: .rounded))
                  .foregroundColor(selectedSection == .alarm ? .white : .textSecondary)
                  .frame(maxWidth: .infinity)
                  .frame(height: 36)
                  .background(selectedSection == .alarm ? Color.accentColor : Color.clear)
                  .clipShape(RoundedRectangle(cornerRadius: 10))
          }
          .buttonStyle(.plain)
      }
      .padding(4)
      .softControl(cornerRadius: 14, padding: 4)
      .padding(.horizontal, 20)
      .padding(.top, 10)

      ZStack {
        switch selectedSection {
        case .timer:
          TimerView()
            .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
        case .alarm:
          AlarmView()
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedSection)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .safeAreaPadding(.top, 4)
    .safeAreaPadding(.bottom, 96)
    .background(Color.clear)
  }
}
