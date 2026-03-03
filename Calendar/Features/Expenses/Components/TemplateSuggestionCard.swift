import SwiftUI

struct TemplateSuggestionCard: View {
  let suggestion: TemplateSuggestion
  let isSelected: Bool
  let customFrequency: ExpenseFrequency?
  let onToggle: () -> Void
  let onFrequencyChange: (ExpenseFrequency) -> Void
  let onDismiss: (() -> Void)?

  private var displayFrequency: ExpenseFrequency {
    customFrequency ?? suggestion.frequency
  }

  var body: some View {
    Button(action: onToggle) {
      VStack(alignment: .leading, spacing: 12) {
        // Header
        HStack {
          // Selection indicator
          Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundColor(isSelected ? .appAccent : .secondary)

          VStack(alignment: .leading, spacing: 4) {
            Text(suggestion.merchant)
              .font(.headline)
              .foregroundColor(.primary)

            HStack(spacing: 8) {
              Text("₴\(String(format: "%.2f", suggestion.suggestedAmount))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.appAccent)

              Text("•")
                .foregroundColor(.secondary)

              Text(Localization.string(.detectedXTimes(suggestion.occurrenceCount)))
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }

          Spacer()

          // Confidence badge
          ConfidenceBadge(confidence: suggestion.confidence)

          if let onDismiss {
            Button {
              onDismiss()
            } label: {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
          }
        }

        // Frequency selector
        HStack(spacing: 8) {
          Text(Localization.string(.frequency) + ":")
            .font(.caption)
            .foregroundColor(.secondary)

          ForEach(ExpenseFrequency.allCases.filter { $0 != .oneTime }, id: \.self) { freq in
            Button {
              onFrequencyChange(freq)
            } label: {
              Text(freq.displayName)
                .font(.caption)
                .fontWeight(displayFrequency == freq ? .bold : .regular)
                .foregroundColor(displayFrequency == freq ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                  displayFrequency == freq ? Color.appAccent : Color(.systemGray5)
                )
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
          }
        }

        // Categories
        HStack(spacing: 6) {
          Text(Localization.string(.category) + ":")
            .font(.caption)
            .foregroundColor(.secondary)

          ForEach(suggestion.categories.prefix(3), id: \.self) { category in
            HStack(spacing: 2) {
              Image(systemName: category.icon)
                .font(.caption2)
              Text(category.displayName)
                .font(.caption)
            }
            .foregroundColor(category.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(category.color.opacity(0.1))
            .cornerRadius(4)
          }
        }

        // Occurrence dates preview
        HStack(spacing: 4) {
          Text(Localization.string(.lastOccurrences) + ":")
            .font(.caption2)
            .foregroundColor(.secondary)

          let recentDates = Array(suggestion.occurrences.suffix(3))
          ForEach(recentDates.indices, id: \.self) { index in
            Text(formatDate(recentDates[index]))
              .font(.caption2)
              .foregroundColor(.secondary)

            if index < recentDates.count - 1 {
              Text("•")
                .font(.caption2)
                .foregroundColor(.secondary)
            }
          }
        }
      }
      .padding()
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(isSelected ? Color.appAccent.opacity(0.05) : Color(.systemBackground))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(
            isSelected ? Color.appAccent : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
      )
    }
    .buttonStyle(.plain)
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd MMM"
    formatter.locale = Locale(identifier: "uk_UA")
    return formatter.string(from: date)
  }
}

struct ConfidenceBadge: View {
  let confidence: Double

  private var color: Color {
    switch confidence {
    case 0.8...1.0: return .green
    case 0.6..<0.8: return .yellow
    default: return .orange
    }
  }

  private var label: String {
    switch confidence {
    case 0.8...1.0: return Localization.string(.priorityHigh)
    case 0.6..<0.8: return Localization.string(.priorityMedium)
    default: return Localization.string(.priorityLow)
    }
  }

  var body: some View {
    Text(label)
      .font(.caption2)
      .fontWeight(.medium)
      .foregroundColor(color)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(color.opacity(0.15))
      .cornerRadius(4)
  }
}

#Preview {
  VStack {
    TemplateSuggestionCard(
      suggestion: TemplateSuggestion(
        merchant: "Netflix",
        amount: 149.0,
        frequency: .monthly,
        occurrences: [
          Date().addingTimeInterval(-60 * 24 * 60 * 60),
          Date().addingTimeInterval(-30 * 24 * 60 * 60),
          Date(),
        ],
        categories: [.subscriptions],
        suggestedAmount: 149.0,
        confidence: 0.95
      ),
      isSelected: true,
      customFrequency: nil,
      onToggle: {},
      onFrequencyChange: { _ in },
      onDismiss: nil
    )
  }
  .padding()
}
