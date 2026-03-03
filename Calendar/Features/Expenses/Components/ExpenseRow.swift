import SwiftUI

struct ExpenseRow: View {
  let expense: Expense

  var body: some View {
    HStack(spacing: Spacing.sm) {
      ZStack {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(expense.primaryCategory.color.opacity(0.14))
          .frame(width: 42, height: 42)

        Image(systemName: expense.primaryCategory.icon)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(expense.primaryCategory.color)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(expense.title)
          .font(Typography.body.weight(.semibold))
          .foregroundColor(.textPrimary)
          .lineLimit(1)

        if let merchant = expense.merchant, !merchant.isEmpty {
          Text(merchant)
            .font(Typography.caption)
            .foregroundColor(.textSecondary)
            .lineLimit(1)
        }
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 4) {
        Text("\(expense.currencyEnum.symbol)\(String(format: "%.2f", expense.amount))")
          .font(.system(size: 17, weight: .bold))
          .foregroundColor(expense.isIncome ? .green : .textPrimary)
          .contentTransition(.numericText())

        HStack(spacing: 4) {
          Image(systemName: expense.paymentMethodEnum.icon)
            .font(.system(size: 10))
          Text(expense.paymentMethodEnum.displayName)
            .font(Typography.badge)
        }
        .foregroundColor(.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.secondaryFill.opacity(0.8))
        .clipShape(Capsule())
      }
    }
    .padding(14)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color.surfaceCard.opacity(0.9))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(Color.border.opacity(0.25), lineWidth: 0.7)
    )
    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    .animation(.easeInOut(duration: 0.2), value: expense.amount)
  }
}
