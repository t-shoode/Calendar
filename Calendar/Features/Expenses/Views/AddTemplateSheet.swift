import SwiftData
import SwiftUI

struct AddTemplateSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  @State private var title: String = ""
  @State private var amount: String = ""
  @State private var merchant: String = ""
  @State private var frequency: ExpenseFrequency = .monthly
  @State private var category: ExpenseCategory = .other
  @State private var paymentMethod: PaymentMethod = .card
  @State private var notes: String = ""
  @State private var startDate: Date = Date()
  @State private var amountTolerance: Double = 0.05

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          // Template Details Section
          sectionHeader(Localization.string(.templateDetails))

          VStack(spacing: 12) {
            formField(
              title: Localization.string(.title), text: $title,
              placeholder: Localization.string(.templateTitlePlaceholder))

            formField(
              title: Localization.string(.amount), text: $amount, placeholder: "0.00",
              keyboard: .decimalPad)

            formField(
              title: Localization.string(.merchant), text: $merchant,
              placeholder: Localization.string(.merchantPlaceholder))
          }
          .padding()
          .background(.ultraThinMaterial)
          .cornerRadius(16)
          .glassHalo(cornerRadius: 16)

          // Frequency Section
          sectionHeader(Localization.string(.frequency))

          VStack(spacing: 16) {
            Picker(Localization.string(.frequency), selection: $frequency) {
              ForEach(ExpenseFrequency.allCases.filter { $0 != .oneTime }, id: \.self) { freq in
                Text(freq.displayName).tag(freq)
              }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
              Text(Localization.string(.amountTolerance))
                .font(.subheadline)
                .foregroundColor(.secondary)

              HStack {
                Text("\(Int(amountTolerance * 100))%")
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .frame(width: 40)

                Slider(value: $amountTolerance, in: 0.0...0.30, step: 0.05)
              }
            }

            DatePicker(
              Localization.string(.startDate), selection: $startDate, displayedComponents: .date)
          }
          .padding()
          .background(.ultraThinMaterial)
          .cornerRadius(16)
          .glassHalo(cornerRadius: 16)

          // Category Section
          sectionHeader(Localization.string(.category))

          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
              ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                CategoryButton(
                  category: cat,
                  isSelected: category == cat,
                  onTap: { category = cat }
                )
              }
            }
            .padding(.vertical, 8)
          }

          // Payment Method Section
          Section(Localization.string(.expensePaymentMethod)) {
            HStack(spacing: 12) {
              ForEach(PaymentMethod.allCases, id: \.self) { method in
                Button {
                  withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    paymentMethod = method
                  }
                } label: {
                  HStack(spacing: 8) {
                    Image(systemName: method.icon)
                      .font(.system(size: 18))
                    Text(method.displayName)
                      .font(.system(size: 15, weight: .semibold))
                  }
                  .foregroundColor(paymentMethod == method ? .white : .textSecondary)
                  .frame(maxWidth: .infinity)
                  .frame(height: 48)
                  .background(
                    RoundedRectangle(cornerRadius: 12)
                      .fill(paymentMethod == method ? Color.appAccent : Color.surfaceCard)
                  )
                }
                .buttonStyle(.plain)
              }
            }
          }

          // Notes Section
          sectionHeader(Localization.string(.notes))

          VStack(spacing: 12) {
            TextField(Localization.string(.notesPlaceholder), text: $notes, axis: .vertical)
              .lineLimit(3...6)
          }
          .padding()
          .background(.ultraThinMaterial)
          .cornerRadius(16)
          .glassHalo(cornerRadius: 16)

          Spacer(minLength: 40)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
      }
      .navigationTitle(Localization.string(.addRecurringExpense))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(Localization.string(.cancel)) { dismiss() }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button(Localization.string(.save)) {
            saveTemplate()
          }
          .disabled(title.isEmpty || amount.isEmpty || merchant.isEmpty)
        }
      }
    }
  }

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.system(size: 12, weight: .black))
      .tracking(1)
      .foregroundColor(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.leading, 4)
  }

  private func formField(
    title: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.subheadline)
        .foregroundColor(.secondary)

      TextField(placeholder, text: text)
        .font(.body)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .keyboardType(keyboard)
    }
  }

  private func saveTemplate() {
    guard let amountValue = Double(amount), amountValue > 0 else { return }

    let template = RecurringExpenseTemplate(
      title: title,
      amount: amountValue,
      amountTolerance: amountTolerance,
      categories: [category],
      paymentMethod: paymentMethod,
      currency: .uah,
      merchant: merchant.isEmpty ? title : merchant,
      notes: notes.isEmpty ? nil : notes,
      frequency: frequency,
      startDate: startDate,
      occurrenceCount: 1
    )

    modelContext.insert(template)
    do {
      try modelContext.save()
    } catch {
      ErrorPresenter.presentOnMain(error)
    }

    // Generate expenses immediately for the new template
    RecurringExpenseService.shared.generateRecurringExpenses(context: modelContext)

    dismiss()
  }
}

struct CategoryButton: View {
  let category: ExpenseCategory
  let isSelected: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 6) {
        Image(systemName: category.icon)
          .font(.system(size: 20))
          .foregroundColor(isSelected ? .white : category.color)

        Text(category.displayName)
          .font(.caption)
          .foregroundColor(isSelected ? .white : .primary)
          .lineLimit(1)
      }
      .frame(width: 72, height: 64)
      .background(isSelected ? category.color : Color(.systemGray6))
      .cornerRadius(12)
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  AddTemplateSheet()
}
