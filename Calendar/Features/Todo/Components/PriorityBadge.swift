import SwiftUI

struct PriorityBadge: View {
  let priority: Priority

  var body: some View {
    Text(priority.displayName.uppercased())
      .font(.system(size: 10, weight: .semibold))
      .foregroundColor(color)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        Capsule()
          .fill(color.opacity(0.15))
      )
      .overlay(
        Capsule()
          .stroke(color.opacity(0.35), lineWidth: 0.8)
      )
  }

  var color: Color {
    switch priority {
    case .high: return .priorityHigh
    case .medium: return .priorityMedium
    case .low: return .priorityLow
    }
  }
}
