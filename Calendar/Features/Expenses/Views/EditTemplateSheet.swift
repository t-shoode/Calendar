import SwiftData
import SwiftUI

struct EditTemplateSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  let template: RecurringExpenseTemplate

  @State private var title: String = ""
  @State private var amount: String = ""
  @State private var merchant: String = ""
  @State private var frequency: ExpenseFrequency = .monthly
  @State private var category: ExpenseCategory = .other
  @State private var paymentMethod: PaymentMethod = .card
  @State private var notes: String = ""
  @State private var amountTolerance: Double = 0.05
  @State private var isActive: Bool = true
  @State private var applyToFutureGenerated: Bool = false
  @State private var affectedCount: Int = 0
  @State private var showUpdateResult: Bool = false
  @State private var lastUpdatedCount: Int = 0
  @State private var lastSkippedCount: Int = 0

  init(template: RecurringExpenseTemplate) {
    self.template = template
    _title = State(initialValue: template.title)
    _amount = State(initialValue: String(format: "%.2f", template.amount))
    _merchant = State(initialValue: template.merchant)
    _frequency = State(initialValue: template.frequency)
    _category = State(initialValue: template.primaryCategory)
    _paymentMethod = State(initialValue: template.paymentMethodEnum)
    _notes = State(initialValue: template.notes ?? "")
    _amountTolerance = State(initialValue: template.amountTolerance)
    _isActive = State(initialValue: template.isActive)
  }

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

            Toggle(Localization.string(.active), isOn: $isActive)
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

          // Apply to future generated expenses (optional)
          VStack(spacing: 8) {
            Toggle(isOn: $applyToFutureGenerated) {
              VStack(alignment: .leading) {
                Text("Apply changes to future generated expenses")
                  .font(.subheadline)
                  .foregroundColor(.primary)
                Text("Manual edits will be preserved")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
            .toggleStyle(SwitchToggleStyle(tint: .appAccent))

            if affectedCount > 0 {
              Text("Will update \(affectedCount) future item\(affectedCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
              Text(Localization.string(.noDataYet))
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          .padding()
          .background(.ultraThinMaterial)
          .cornerRadius(12)
          .glassHalo(cornerRadius: 12)

          Spacer(minLength: 40)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
      }
      .navigationTitle(Localization.string(.editRecurringExpense))
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
      .onAppear {
        // Compute how many future generated items would be affected (preview)
        affectedCount = RecurringExpenseService.shared.countFutureGeneratedExpenses(
          for: template, from: Date(), context: modelContext)
      }
      .alert(isPresented: $showUpdateResult) {
        Alert(
          title: Text("Applied changes"),
          message: Text(
            "Updated \(lastUpdatedCount) item\(lastUpdatedCount == 1 ? "" : "s") — skipped \(lastSkippedCount) manual edit\(lastSkippedCount == 1 ? "" : "s")."
          ),
          primaryButton: .default(Text("Undo")) {
            _ = RecurringExpenseService.shared.undoLastTemplateUpdate(
              templateId: template.id, context: modelContext)
          },
          secondaryButton: .cancel(Text("OK"))
        )
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

    template.title = title
    template.amount = amountValue
    template.merchant = merchant
    template.frequency = frequency
    template.categories = [category.rawValue]
    template.paymentMethod = paymentMethod.rawValue
    template.notes = notes.isEmpty ? nil : notes
    template.amountTolerance = amountTolerance
    template.isActive = isActive
    template.updatedAt = Date()

    do {
      try modelContext.save()
    } catch {
      ErrorPresenter.presentOnMain(error)
    }

    // Regenerate missing occurrences first
    RecurringExpenseService.shared.generateRecurringExpenses(context: modelContext)

    // If user asked — update future generated expenses created from this template
    if applyToFutureGenerated {
      let result = RecurringExpenseService.shared.updateGeneratedExpenses(
        for: template, applyFrom: Date(), context: modelContext)
      lastUpdatedCount = result.updatedCount
      lastSkippedCount = result.skippedManualCount
      showUpdateResult = true
    }

    dismiss()
  }
}

#Preview {
  EditTemplateSheet(
    template: RecurringExpenseTemplate(
      title: "Netflix",
      amount: 149.0,
      merchant: "Netflix",
      frequency: .monthly
    ))
}
