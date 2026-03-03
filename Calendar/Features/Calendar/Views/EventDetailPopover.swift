import SwiftUI

struct EventDetailPopover: View {
  let occurrence: EventOccurrence
  let onDismiss: () -> Void
  var onEdit: (() -> Void)?
  var onDelete: (() -> Void)?

  private var event: Event { occurrence.sourceEvent }
  private var date: Date { occurrence.occurrenceDate }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Color category bar at top
      RoundedRectangle(cornerRadius: 0)
        .fill(Color.eventColor(named: event.color))
        .frame(height: 6)

      // Header
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
              Text(event.title)
                .font(Typography.title)
                .foregroundColor(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

              if event.isHoliday {
                Image(systemName: "star.fill")
                  .font(.system(size: 12))
                  .foregroundColor(.eventTeal)
              }
            }

            Text(
              date.formatted(
                .dateTime.weekday(.wide).day().month(.wide).hour().minute()
                  .locale(Localization.locale))
            )
            .font(Typography.caption)
            .foregroundColor(Color.textSecondary)
          }

          Spacer()

          Button(action: onDismiss) {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 24))
              .foregroundColor(Color.textTertiary)
          }
          .buttonStyle(.plain)
        }

        // Reminder badge
        if let reminder = event.reminderInterval, reminder > 0 {
          HStack(spacing: 6) {
            Image(systemName: "bell.fill")
              .font(.system(size: 11))
            Text(reminderLabel(reminder))
              .font(Typography.caption)
          }
          .foregroundColor(Color.textSecondary)
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .background(Color.secondaryFill)
          .clipShape(Capsule())
        }
      }
      .padding(Spacing.md)

      // Notes
      if let notes = event.notes, !notes.isEmpty {
        Divider()
          .padding(.horizontal, Spacing.md)

        ScrollView {
          Text(notes)
            .font(Typography.body)
            .foregroundColor(Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
        }
        .frame(maxHeight: 200)
      }

      // Actions
      Divider()
        .padding(.horizontal, Spacing.md)

      if !event.isHoliday {
        HStack(spacing: Spacing.md) {
          if let onEdit {
            Button(action: onEdit) {
              Label(Localization.string(.edit), systemImage: "pencil")
                .font(Typography.body)
                .fontWeight(.medium)
                .foregroundColor(.appAccent)
            }
            .buttonStyle(.plain)
          }

          Spacer()

          if let onDelete {
            Button(action: onDelete) {
              Label(Localization.string(.delete), systemImage: "trash")
                .font(Typography.body)
                .fontWeight(.medium)
                .foregroundColor(.priorityHigh)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(Spacing.md)
      } else {
        HStack(spacing: 6) {
          Image(systemName: "star.fill")
            .font(.system(size: 12))
            .foregroundColor(.eventTeal)
          Text(Localization.string(.holiday))
            .font(Typography.caption)
            .fontWeight(.medium)
            .foregroundColor(.eventTeal)
        }
        .padding(Spacing.md)
      }
    }
    .background(Color.surfaceElevated)
    .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: Spacing.cardRadius, style: .continuous)
        .stroke(Color.border, lineWidth: 0.5)
    )
    .shadow(color: Color.shadowColor, radius: 20, x: 0, y: 8)
    .padding(.horizontal, 24)
    .frame(maxWidth: 400)
  }

  private func reminderLabel(_ interval: TimeInterval) -> String {
    if interval < 1 { return Localization.string(.atTimeOfEvent) }
    let minutes = Int(interval / 60)
    if minutes < 60 { return Localization.string(.minutesBefore(minutes)) }
    let hours = minutes / 60
    if hours < 24 { return Localization.string(.hoursBefore(hours)) }
    return Localization.string(.daysBefore(hours / 24))
  }
}
