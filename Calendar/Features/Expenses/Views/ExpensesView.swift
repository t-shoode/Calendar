import SwiftData
import SwiftUI

struct ExpensesView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Expense.date) private var expenses: [Expense]
  @Query(sort: \RecurringExpenseTemplate.createdAt) private var templates:
    [RecurringExpenseTemplate]
  @Query(
    filter: #Predicate<DuplicateSuggestion> { $0.status == "pending" },
    sort: \DuplicateSuggestion.createdAt,
    order: .reverse
  ) private var pendingDuplicateSuggestions: [DuplicateSuggestion]

  @State private var selectedSegment: ExpenseSegment = .history
  @State private var selectedPeriod: ExpensePeriod = .monthly
  @State private var showingAddExpense = false
  @State private var editingExpense: Expense? = nil
  @State private var showingCSVImport = false
  @State private var showingClearConfirmation = false
  @State private var showingAddTemplate = false

  private let viewModel = ExpenseViewModel()

  enum ExpenseSegment: String, CaseIterable {
    case history = "History"
    case budget = "Budget"
    case forecast = "Forecast"
    case insights = "Insights"

    var displayName: String {
      switch self {
      case .history: return Localization.string(.expenseHistory)
      case .budget: return Localization.string(.expenseBudget)
      case .forecast: return Localization.string(.forecast)
      case .insights: return Localization.string(.expenseInsights)
      }
    }
  }

  enum ExpensePeriod: String, CaseIterable {
    case all, weekly, monthly, yearly
    var displayName: String {
      switch self {
      case .all: return Localization.string(.expensePeriodAll)
      case .weekly: return Localization.string(.expensePeriodWeekly)
      case .monthly: return Localization.string(.expensePeriodMonthly)
      case .yearly: return Localization.string(.expensePeriodYearly)
      }
    }
  }

  private var filteredExpenses: [Expense] {
    var result: [Expense]

    if selectedPeriod == .all {
      // For "All" filter, sort by date descending and limit to prevent crashes
      result = expenses.sorted { $0.date > $1.date }
      if result.count > 100 {
        result = Array(result.prefix(100))
      }
    } else {
      let bounds = periodBounds(for: selectedPeriod)
      result = expenses.filter { $0.date >= bounds.start && $0.date <= bounds.end }
    }
    return result
  }

  // Calculate totals using ALL expenses (not just filtered)
  private var totalExpensesForPeriod: [Expense] {
    if selectedPeriod == .all {
      return expenses
    }
    let bounds = periodBounds(for: selectedPeriod)
    return expenses.filter { $0.date >= bounds.start && $0.date <= bounds.end }
  }

  private func periodBounds(for period: ExpensePeriod) -> (start: Date, end: Date) {
    let calendar = Calendar.current
    let today = Date()

    if period == .all {
      // Return a very wide date range for "All" filter
      let distantPast = calendar.date(byAdding: .year, value: -10, to: today)!
      let distantFuture = calendar.date(byAdding: .year, value: 10, to: today)!
      return (distantPast, distantFuture)
    }

    let interval: DateInterval
    switch period {
    case .weekly:
      interval =
        calendar.dateInterval(of: .weekOfYear, for: today) ?? DateInterval(start: today, end: today)
    case .monthly:
      interval =
        calendar.dateInterval(of: .month, for: today) ?? DateInterval(start: today, end: today)
    case .yearly:
      interval =
        calendar.dateInterval(of: .year, for: today) ?? DateInterval(start: today, end: today)
    default:
      interval = DateInterval(start: today, end: today)
    }
    return (
      interval.start, calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      // Header with Segment Picker
      VStack(spacing: 16) {
        HStack {
          Text(Localization.string(.expenseHeader))
            .font(.system(size: 14, weight: .black))
            .tracking(2)
            .foregroundColor(.textSecondary)

          Spacer()

          HStack(spacing: 16) {
            Button {
              showingAddTemplate = true
            } label: {
              Image(systemName: "plus.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.accentColor)
            }

            Button {
              showingCSVImport = true
            } label: {
              Image(systemName: "arrow.down.doc")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.accentColor)
            }

            Button {
              showingClearConfirmation = true
            } label: {
              Image(systemName: "trash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.red)
            }
          }
        }

        // Segment Picker
        HStack(spacing: 0) {
          ForEach(ExpenseSegment.allCases, id: \.self) { segment in
            Button {
              withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedSegment = segment
              }
            } label: {
              Text(segment.displayName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(selectedSegment == segment ? .white : .textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(selectedSegment == segment ? Color.accentColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
          }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .glassHalo(cornerRadius: 14)

        // Period picker (only for History segment)
        if selectedSegment == .history {
          HStack(spacing: 0) {
            ForEach(ExpensePeriod.allCases, id: \.self) { period in
              Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                  selectedPeriod = period
                }
              } label: {
                Text(period.displayName)
                  .font(.system(size: 12, weight: .bold))
                  .foregroundColor(selectedPeriod == period ? .white : .textSecondary)
                  .frame(maxWidth: .infinity)
                  .frame(height: 32)
                  .background(
                    selectedPeriod == period ? Color.accentColor.opacity(0.8) : Color.clear
                  )
                  .clipShape(RoundedRectangle(cornerRadius: 8))
              }
              .buttonStyle(.plain)
            }
          }
          .padding(4)
          .background(.ultraThinMaterial.opacity(0.5))
          .clipShape(RoundedRectangle(cornerRadius: 12))
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 10)

      // Content based on selected segment
      Group {
        switch selectedSegment {
        case .history:
          HistoryView(
            expenses: filteredExpenses,
            allExpensesForTotals: totalExpensesForPeriod,
            period: selectedPeriod,
            duplicateSuggestions: pendingDuplicateSuggestions,
            viewModel: viewModel,
            onEdit: { expense in
              editingExpense = expense
              showingAddExpense = true
            },
            onMergeDuplicate: { suggestion in
              do {
                try DuplicateDetectionService.shared.mergeSuggestion(suggestion, context: modelContext)
              } catch {
                ErrorPresenter.shared.present(error)
              }
            },
            onDismissDuplicate: { suggestion in
              do {
                try DuplicateDetectionService.shared.dismissSuggestion(suggestion, context: modelContext)
              } catch {
                ErrorPresenter.shared.present(error)
              }
            }
          )
        case .budget:
          BudgetView(
            templates: templates,
            expenses: expenses,
            viewModel: viewModel
          )
        case .forecast:
          ForecastView(
            expenses: expenses,
            templates: templates
          )
        case .insights:
          InsightsView(
            expenses: expenses,
            viewModel: viewModel
          )
        }
      }
    }
    .overlay(alignment: .bottomTrailing) {
      Button(action: {
        editingExpense = nil
        showingAddExpense = true
      }) {
        Image(systemName: "plus")
          .font(.system(size: 16, weight: .bold))
          .foregroundColor(.white)
          .frame(width: 40, height: 40)
          .background(Color.accentColor)
          .clipShape(Circle())
          .shadow(color: Color.accentColor.opacity(0.4), radius: 15, x: 0, y: 8)
      }
      .padding(.trailing, 20)
      .padding(.bottom, 80)
    }
    .sheet(isPresented: $showingAddExpense) {
      AddExpenseSheet(
        expense: editingExpense,
        onSave: {
          title, amount, date, category, paymentMethod, currency, merchant, notes, isIncome in
          do {
            if let expense = editingExpense {
              try viewModel.updateExpense(
                expense, title: title, amount: amount, date: date, category: category,
                paymentMethod: paymentMethod, currency: currency, merchant: merchant, notes: notes,
                isIncome: isIncome,
                context: modelContext)
            } else {
              try viewModel.addExpense(
                title: title, amount: amount, date: date, category: category,
                paymentMethod: paymentMethod, currency: currency, merchant: merchant, notes: notes,
                isIncome: isIncome,
                context: modelContext)
            }
          } catch {
            ErrorPresenter.shared.present(error)
          }
        },
        onDelete: {
          if let expense = editingExpense {
            do {
              try viewModel.deleteExpense(expense, context: modelContext)
            } catch {
              ErrorPresenter.shared.present(error)
            }
          }
        }
      )
    }
    .sheet(isPresented: $showingCSVImport) {
      CSVImportView()
    }
    .sheet(isPresented: $showingAddTemplate) {
      AddTemplateSheet()
    }
    .confirmationDialog(
      Localization.string(.clearAllDataPrompt),
      isPresented: $showingClearConfirmation,
      titleVisibility: .visible
    ) {
      Button(Localization.string(.clearAllExpensesConfirm), role: .destructive) {
        clearAllExpenses()
      }
      Button(Localization.string(.clearAllTemplatesConfirm), role: .destructive) {
        clearAllTemplates()
      }
      Button(Localization.string(.clearEverythingConfirm), role: .destructive) {
        clearAllExpenses()
        clearAllTemplates()
      }
      Button(Localization.string(.cancel), role: .cancel) {}
    } message: {
      Text(Localization.string(.cannotBeUndone))
    }
    .onAppear {
      DuplicateDetectionService.shared.refreshSuggestions(context: modelContext)
    }
    .onChange(of: expenses.count) { _, _ in
      DuplicateDetectionService.shared.refreshSuggestions(context: modelContext)
    }
  }

  private func clearAllExpenses() {
    for expense in expenses {
      modelContext.delete(expense)
    }
    do {
      try modelContext.save()
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
  }

  private func clearAllTemplates() {
    for template in templates {
      modelContext.delete(template)
    }
    do {
      try modelContext.save()
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
  }
}

// MARK: - History View

struct HistoryView: View {
  let expenses: [Expense]
  let allExpensesForTotals: [Expense]
  let period: ExpensesView.ExpensePeriod
  let duplicateSuggestions: [DuplicateSuggestion]
  let viewModel: ExpenseViewModel
  let onEdit: (Expense) -> Void
  let onMergeDuplicate: (DuplicateSuggestion) -> Void
  let onDismissDuplicate: (DuplicateSuggestion) -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        if !duplicateSuggestions.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
              Text(Localization.string(.duplicateSuggestionsX(duplicateSuggestions.count)))
                .font(.system(size: 13, weight: .semibold))
              Spacer()
            }

            ForEach(duplicateSuggestions) { suggestion in
              DuplicateSuggestionRow(
                suggestion: suggestion,
                expenses: expenses,
                onMerge: { onMergeDuplicate(suggestion) },
                onDismiss: { onDismissDuplicate(suggestion) }
              )
            }
          }
          .padding(14)
          .background(Color.secondaryFill)
          .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        // Total Amount - split into Expenses and Income columns
        let bounds = periodBounds()
        let expenseTotals = viewModel.multiCurrencyTotalsForPeriod(
          expenses: allExpensesForTotals, start: bounds.start, end: bounds.end, isIncome: false)
        let incomeTotals = viewModel.multiCurrencyTotalsForPeriod(
          expenses: allExpensesForTotals, start: bounds.start, end: bounds.end, isIncome: true)

        VStack(spacing: 16) {
          // Two columns: Expenses | Income
          HStack(spacing: 12) {
            // Expenses column
            VStack(spacing: 4) {
              Text(Localization.string(.expenseExpensesLabel))
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.textTertiary)
                .tracking(2)

              Text("\(Currency.uah.symbol)\(String(format: "%.2f", expenseTotals.uah))")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            Divider()
              .frame(height: 48)

            // Income column
            VStack(spacing: 4) {
              Text(Localization.string(.expenseIncomeLabel))
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.textTertiary)
                .tracking(2)

              Text("\(Currency.uah.symbol)\(String(format: "%.2f", incomeTotals.uah))")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.green)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
          }

          HStack(spacing: 24) {
            // Expenses: USD / EUR
            VStack(spacing: 8) {
              HStack(spacing: 10) {
                VStack(spacing: 2) {
                  Text("$")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.textTertiary)
                  Text(String(format: "%.2f", expenseTotals.usd))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.textSecondary)
                }

                VStack(spacing: 2) {
                  Text("€")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.textTertiary)
                  Text(String(format: "%.2f", expenseTotals.eur))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.textSecondary)
                }
              }
            }

            Divider()
              .frame(height: 48)

            // Income: USD / EUR
            VStack(spacing: 8) {
              HStack(spacing: 10) {
                VStack(spacing: 2) {
                  Text("$")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.textTertiary)
                  Text(String(format: "%.2f", incomeTotals.usd))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.textSecondary)
                }

                VStack(spacing: 2) {
                  Text("€")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.textTertiary)
                  Text(String(format: "%.2f", incomeTotals.eur))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.textSecondary)
                }
              }
            }
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
          ZStack {
            Circle()
              .fill(Color.accentColor.opacity(0.1))
              .frame(width: 200, height: 200)
              .blur(radius: 50)
          }
        )

        if expenses.isEmpty {
          VStack(spacing: 20) {
            Image(systemName: "creditcard")
              .font(.system(size: 48))
              .foregroundColor(.textTertiary)
            Text(Localization.string(.expenseNoExpenses))
              .font(.body)
              .foregroundColor(.textSecondary)
          }
          .padding(.top, 40)
        } else {
          ForEach(viewModel.groupedByDate(expenses: expenses), id: \.date) { group in
            VStack(alignment: .leading, spacing: 12) {
              Text(group.date.formatted(date: .abbreviated, time: .omitted).uppercased())
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.textTertiary)
                .padding(.leading, 4)

              ForEach(group.expenses, id: \.id) { expense in
                ExpenseRow(expense: expense)
                  .onTapGesture {
                    onEdit(expense)
                  }
              }
            }
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 120)
    }
  }

  private func periodBounds() -> (start: Date, end: Date) {
    let calendar = Calendar.current
    let today = Date()

    if period == .all {
      let distantPast = calendar.date(byAdding: .year, value: -10, to: today)!
      let distantFuture = calendar.date(byAdding: .year, value: 10, to: today)!
      return (distantPast, distantFuture)
    }

    let interval: DateInterval
    switch period {
    case .weekly:
      interval =
        calendar.dateInterval(of: .weekOfYear, for: today) ?? DateInterval(start: today, end: today)
    case .monthly:
      interval =
        calendar.dateInterval(of: .month, for: today) ?? DateInterval(start: today, end: today)
    case .yearly:
      interval =
        calendar.dateInterval(of: .year, for: today) ?? DateInterval(start: today, end: today)
    default:
      interval = DateInterval(start: today, end: today)
    }
    return (
      interval.start, calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
    )
  }
}

private struct DuplicateSuggestionRow: View {
  let suggestion: DuplicateSuggestion
  let expenses: [Expense]
  let onMerge: () -> Void
  let onDismiss: () -> Void

  private var expenseA: Expense? {
    expenses.first(where: { $0.id == suggestion.expenseIdA })
  }

  private var expenseB: Expense? {
    expenses.first(where: { $0.id == suggestion.expenseIdB })
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(Localization.string(.possibleDuplicate))
        .font(.system(size: 12, weight: .bold))

      if let expenseA, let expenseB {
        Text("\(expenseA.title) • \(Currency.uah.symbol)\(String(format: "%.0f", expenseA.currencyEnum.convertToUAH(expenseA.amount)))")
          .font(.system(size: 12))
          .foregroundColor(.secondary)
        Text("\(expenseB.title) • \(Currency.uah.symbol)\(String(format: "%.0f", expenseB.currencyEnum.convertToUAH(expenseB.amount)))")
          .font(.system(size: 12))
          .foregroundColor(.secondary)
      }

      HStack {
        Button(Localization.string(.merge)) {
          onMerge()
        }
        .font(.system(size: 12, weight: .semibold))

        Spacer()

        Button(Localization.string(.dismiss)) {
          onDismiss()
        }
        .font(.system(size: 12, weight: .semibold))
      }
    }
    .padding(10)
    .background(Color.primaryFill.opacity(0.5))
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }
}

#Preview {
  ExpensesView()
}
