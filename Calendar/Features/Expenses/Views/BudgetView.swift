import SwiftData
import SwiftUI

struct BudgetView: View {
  let templates: [RecurringExpenseTemplate]
  let expenses: [Expense]
  let viewModel: ExpenseViewModel

  @Environment(\.modelContext) private var modelContext
  @Query(sort: \BudgetLimit.updatedAt, order: .reverse) private var budgetLimits: [BudgetLimit]
  @State private var editingTemplate: RecurringExpenseTemplate?
  @State private var editingBudgetLimit: BudgetLimit?
  @State private var showingBudgetEditor = false

  private var activeTemplates: [RecurringExpenseTemplate] {
    templates.filter { $0.isActive && !$0.isCurrentlyPaused }
  }

  private var pausedTemplates: [RecurringExpenseTemplate] {
    templates.filter { $0.isActive && $0.isCurrentlyPaused }
  }

  private var inactiveTemplates: [RecurringExpenseTemplate] {
    templates.filter { !$0.isActive }
  }

  private var monthlyTotal: Double {
    activeTemplates
      .filter { $0.frequency == .monthly || $0.frequency == .yearly }
      .reduce(0) { total, template in
        let amountUAH = viewModel.amountInUAH(template)
        if template.frequency == .yearly {
          return total + (amountUAH / 12)
        }
        return total + amountUAH
      }
  }

  private var weeklyTotal: Double {
    activeTemplates
      .filter { $0.frequency == .weekly }
      .reduce(0) { $0 + viewModel.amountInUAH($1) }
  }

  private var yearlyTotal: Double {
    activeTemplates.reduce(0) { total, template in
      let amountUAH = viewModel.amountInUAH(template)
      switch template.frequency {
      case .weekly:
        return total + (amountUAH * 52)
      case .monthly:
        return total + (amountUAH * 12)
      case .yearly:
        return total + amountUAH
      default:
        return total
      }
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        HStack {
          Text(Localization.string(.expenseBudget))
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.textPrimary)
          Spacer()
        }

        budgetsSection

        // Summary Cards
        HStack(spacing: 12) {
          BudgetSummaryCard(
            title: Localization.string(.expensePeriodMonthly),
            amount: monthlyTotal,
            icon: "calendar",
            color: .blue
          )

          BudgetSummaryCard(
            title: Localization.string(.expensePeriodWeekly),
            amount: weeklyTotal,
            icon: "arrow.2.circlepath",
            color: .green
          )
        }

        BudgetSummaryCard(
          title: Localization.string(.yearlyProjection),
          amount: yearlyTotal,
          icon: "chart.line.uptrend.xyaxis",
          color: .purple
        )

        // Active Templates
        if !activeTemplates.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Text(Localization.string(.activeRecurringX(activeTemplates.count)))
                .font(.headline)

              Spacer()

              Button {
                generateMissingExpenses()
              } label: {
                Image(systemName: "arrow.clockwise")
                  .foregroundColor(.appAccent)
              }
            }

            ForEach(activeTemplates) { template in
              // Prefer the nearest generated Expense date (>= today); fallback to the template's next due date from today
              let todayStart = Calendar.current.startOfDay(for: Date())
              let futureGenerated = expenses.filter {
                $0.templateId == template.id && $0.isGenerated && $0.date >= todayStart
              }
              let nextGeneratedDate = futureGenerated.min(by: { $0.date < $1.date })?.date
              let displayNext = nextGeneratedDate ?? template.nextDueDate(from: Date())

              TemplateRow(
                template: template,
                nextDate: displayNext,
                onPause: { pauseTemplate(template) },
                onEdit: { editTemplate(template) },
                onDelete: { deleteTemplate(template) }
              )
            }
          }
        }

        // Paused Templates
        if !pausedTemplates.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            Text(Localization.string(.pausedX(pausedTemplates.count)))
              .font(.headline)
              .foregroundColor(.secondary)

            ForEach(pausedTemplates) { template in
              let todayStart = Calendar.current.startOfDay(for: Date())
              let futureGenerated = expenses.filter {
                $0.templateId == template.id && $0.isGenerated && $0.date >= todayStart
              }
              let nextGeneratedDate = futureGenerated.min(by: { $0.date < $1.date })?.date
              let displayNext = nextGeneratedDate ?? template.nextDueDate(from: Date())

              TemplateRow(
                template: template,
                nextDate: displayNext,
                onResume: { resumeTemplate(template) },
                onEdit: { editTemplate(template) },
                onDelete: { deleteTemplate(template) }
              )
              .opacity(0.6)
            }
          }
        }

        // Inactive Templates
        if !inactiveTemplates.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            Text(Localization.string(.inactiveX(inactiveTemplates.count)))
              .font(.headline)
              .foregroundColor(.secondary)

            ForEach(inactiveTemplates) { template in
              let todayStart = Calendar.current.startOfDay(for: Date())
              let futureGenerated = expenses.filter {
                $0.templateId == template.id && $0.isGenerated && $0.date >= todayStart
              }
              let nextGeneratedDate = futureGenerated.min(by: { $0.date < $1.date })?.date
              let displayNext = nextGeneratedDate ?? template.nextDueDate(from: Date())

              TemplateRow(
                template: template,
                nextDate: displayNext,
                onActivate: { activateTemplate(template) },
                onEdit: { editTemplate(template) },
                onDelete: { deleteTemplate(template) }
              )
              .opacity(0.5)
            }
          }
        }

        if templates.isEmpty {
          VStack(spacing: 16) {
            Image(systemName: "repeat")
              .font(.system(size: 48))
              .foregroundColor(.secondary)

            Text(Localization.string(.expenseNoRecurringExpenses))
              .font(.headline)

            Text(Localization.string(.uploadCSV))
              .font(.caption)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
          }
          .padding(.top, 60)
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 120)
    }
    .sheet(item: $editingTemplate) { template in
      EditTemplateSheet(template: template)
    }
    .sheet(isPresented: $showingBudgetEditor) {
      BudgetLimitEditSheet(limit: editingBudgetLimit) {
        category, amount, rolloverEnabled, dailyBudgetEnabled in
        saveBudgetLimit(
          category: category,
          amount: amount,
          rolloverEnabled: rolloverEnabled,
          dailyBudgetEnabled: dailyBudgetEnabled
        )
      }
    }
    .onAppear {
      recomputeBudgets()
    }
    .onChange(of: expenses.count) { _, _ in
      recomputeBudgets()
    }
    .onChange(of: budgetLimits.count) { _, _ in
      recomputeBudgets()
    }
  }

  private var budgetsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(Localization.string(.budgets))
          .font(.headline)

        Spacer()

        Menu {
          ForEach(BudgetProfilePreset.allCases) { preset in
            Button(preset.title) {
              applyBudgetPreset(preset)
            }
          }
        } label: {
          Label(Localization.string(.templates), systemImage: "square.grid.2x2")
            .font(.system(size: 13, weight: .semibold))
        }

        Button {
          editingBudgetLimit = nil
          showingBudgetEditor = true
        } label: {
          Label(Localization.string(.add), systemImage: "plus.circle.fill")
            .font(.system(size: 13, weight: .semibold))
        }
      }

        if budgetLimits.isEmpty {
          Text(Localization.string(.noBudgetsYet))
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .softCard(cornerRadius: 12, padding: 16, shadow: false)
        } else {
          ForEach(budgetLimits) { limit in
            budgetProgressRow(for: limit)
        }
      }
    }
  }

  @ViewBuilder
  private func budgetProgressRow(for limit: BudgetLimit) -> some View {
    let spent = BudgetService.shared.spentUAH(
      for: limit.category,
      expenses: expenses,
      in: limit.periodEnum
    )
    let effectiveBudget = BudgetService.shared.effectiveBudgetUAH(for: limit)
    let remaining = BudgetService.shared.remainingBudgetUAH(for: limit, expenses: expenses)
    let remainingPerDay = BudgetService.shared.remainingPerDayUAH(for: limit, expenses: expenses)
    let ratio = effectiveBudget > 0 ? spent / effectiveBudget : 0
    let clampedRatio = min(max(ratio, 0), 1)
    let progressColor: Color = ratio >= 1 ? .red : (ratio >= 0.8 ? .orange : .green)

    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label(limit.category.displayName, systemImage: limit.category.icon)
          .font(.system(size: 14, weight: .semibold))

        Spacer()

        Text("\(Currency.uah.symbol)\(String(format: "%.0f", spent)) / \(Currency.uah.symbol)\(String(format: "%.0f", effectiveBudget))")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.secondary)
      }

      ProgressView(value: clampedRatio)
        .tint(progressColor)

      HStack {
        Text(Localization.string(.budgetUsedPercent(Int((clampedRatio * 100).rounded()))))
          .font(.system(size: 12))
          .foregroundColor(.secondary)

        Spacer()

        Button(Localization.string(.edit)) {
          editingBudgetLimit = limit
          showingBudgetEditor = true
        }
        .font(.system(size: 12, weight: .semibold))

        Button(Localization.string(.delete), role: .destructive) {
          deleteBudgetLimit(limit)
        }
        .font(.system(size: 12, weight: .semibold))
      }

      VStack(alignment: .leading, spacing: 4) {
        if limit.rolloverEnabled {
          Text(
            Localization.string(
              .budgetRolloverAmount(
                "+\(Currency.uah.symbol)\(String(format: "%.0f", limit.rolloverAmountUAH))"
              )
            )
          )
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(.secondary)
        }

        Text(
          Localization.string(
            .budgetRemainingAmount(
              "\(Currency.uah.symbol)\(String(format: "%.0f", remaining))"
            )
          )
        )
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(remaining < 0 ? .red : .secondary)

        if limit.dailyBudgetEnabled {
          Text(
            Localization.string(
              .budgetPerDayAmount(
                "\(Currency.uah.symbol)\(String(format: "%.0f", remainingPerDay))"
              )
            )
          )
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(remainingPerDay < 0 ? .red : .secondary)
        }
      }
    }
    .padding(14)
    .softCard(cornerRadius: 12, padding: 14, shadow: false)
  }

  private func pauseTemplate(_ template: RecurringExpenseTemplate) {
    template.isPaused = true
    template.pausedUntil = nil
    do {
      try modelContext.save()
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
  }

  private func resumeTemplate(_ template: RecurringExpenseTemplate) {
    template.isPaused = false
    template.pausedUntil = nil
    do {
      try modelContext.save()
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
  }

  private func activateTemplate(_ template: RecurringExpenseTemplate) {
    template.isActive = true
    template.isPaused = false
    template.pausedUntil = nil
    do {
      try modelContext.save()
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
  }

  private func editTemplate(_ template: RecurringExpenseTemplate) {
    editingTemplate = template
  }

  private func deleteTemplate(_ template: RecurringExpenseTemplate) {
    // Ask user if they want to keep history
    modelContext.delete(template)
    do {
      try modelContext.save()
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
  }

  private func generateMissingExpenses() {
    RecurringExpenseService.shared.generateRecurringExpenses(context: modelContext)
  }

  private func saveBudgetLimit(
    category: ExpenseCategory,
    amount: Double,
    rolloverEnabled: Bool,
    dailyBudgetEnabled: Bool
  ) {
    if let editingBudgetLimit {
      editingBudgetLimit.categoryRawValue = category.rawValue
      editingBudgetLimit.amountUAH = amount
      editingBudgetLimit.rolloverEnabled = rolloverEnabled
      editingBudgetLimit.dailyBudgetEnabled = dailyBudgetEnabled
      editingBudgetLimit.updatedAt = Date()
    } else {
      let existing = budgetLimits.first(where: { $0.category == category && $0.periodEnum == .monthly })
      if let existing {
        existing.amountUAH = amount
        existing.rolloverEnabled = rolloverEnabled
        existing.dailyBudgetEnabled = dailyBudgetEnabled
        existing.updatedAt = Date()
      } else {
        let limit = BudgetLimit(
          category: category,
          amountUAH: amount,
          period: .monthly,
          rolloverEnabled: rolloverEnabled,
          dailyBudgetEnabled: dailyBudgetEnabled
        )
        modelContext.insert(limit)
      }
    }

    do {
      try modelContext.save()
      recomputeBudgets()
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
  }

  private func applyBudgetPreset(_ preset: BudgetProfilePreset) {
    let baseline = max(monthlyTotal, 30_000)
    do {
      try BudgetService.shared.applyPreset(
        profile: preset,
        monthlyBudgetUAH: baseline,
        limits: budgetLimits,
        context: modelContext
      )
      recomputeBudgets()
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
  }

  private func recomputeBudgets() {
    do {
      try BudgetService.shared.refreshRollover(
        limits: budgetLimits,
        expenses: expenses,
        context: modelContext
      )
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
    BudgetService.shared.evaluateBudgets(limits: budgetLimits, expenses: expenses)
  }

  private func deleteBudgetLimit(_ limit: BudgetLimit) {
    modelContext.delete(limit)
    do {
      try modelContext.save()
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
  }
}

struct BudgetSummaryCard: View {
  let title: String
  let amount: Double
  let icon: String
  let color: Color

  var body: some View {
    VStack(spacing: 8) {
      HStack {
        Image(systemName: icon)
          .foregroundColor(color)
        Spacer()
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("\(Currency.uah.symbol)\(String(format: "%.0f", amount))")
          .font(.title2.bold())
          .foregroundColor(.primary)

        Text(title)
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .softCard(cornerRadius: 12, padding: 14, shadow: false)
  }
}

struct BudgetLimitEditSheet: View {
  let limit: BudgetLimit?
  let onSave: (ExpenseCategory, Double, Bool, Bool) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var category: ExpenseCategory = .other
  @State private var amountText: String = ""
  @State private var rolloverEnabled = false
  @State private var dailyBudgetEnabled = false

  var body: some View {
    NavigationStack {
      Form {
        Picker(Localization.string(.expenseCategory), selection: $category) {
          ForEach(ExpenseCategory.allCases) { item in
            Text(item.displayName).tag(item)
          }
        }

        TextField(Localization.string(.expenseAmount), text: $amountText)
          .keyboardType(.decimalPad)

        Toggle(Localization.string(.budgetEnableRollover), isOn: $rolloverEnabled)
        Toggle(Localization.string(.budgetDailyTarget), isOn: $dailyBudgetEnabled)
      }
      .navigationTitle(limit == nil ? Localization.string(.addBudget) : Localization.string(.editBudget))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(Localization.string(.cancel)) {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(Localization.string(.save)) {
            let sanitized = amountText.replacingOccurrences(of: ",", with: ".")
            let amount = Double(sanitized) ?? 0
            onSave(category, amount, rolloverEnabled, dailyBudgetEnabled)
            dismiss()
          }
          .disabled((Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0)
        }
      }
      .onAppear {
        if let limit {
          category = limit.category
          amountText = String(format: "%.0f", limit.amountUAH)
          rolloverEnabled = limit.rolloverEnabled
          dailyBudgetEnabled = limit.dailyBudgetEnabled
        }
      }
    }
  }
}

struct TemplateRow: View {
  let template: RecurringExpenseTemplate
  var nextDate: Date? = nil
  var onPause: (() -> Void)?
  var onResume: (() -> Void)?
  var onActivate: (() -> Void)?
  var onEdit: (() -> Void)?
  var onDelete: (() -> Void)?

  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(template.primaryCategory.color.opacity(0.2))
          .frame(width: 40, height: 40)

        Image(systemName: template.primaryCategory.icon)
          .foregroundColor(template.primaryCategory.color)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(template.title)
          .font(.subheadline.bold())

        HStack(spacing: 6) {
          Text("\(template.currencyEnum.symbol)\(String(format: "%.2f", template.amount))")
            .font(.caption)
            .foregroundColor(.secondary)

          Text("•")
            .font(.caption)
            .foregroundColor(.secondary)

          Text(template.frequency.displayName)
            .font(.caption)
            .foregroundColor(.secondary)

          let displayNextDate = nextDate ?? template.nextDueDate(from: Date())
          if let nextDateToShow = displayNextDate {
            Text("•")
              .font(.caption)
              .foregroundColor(.secondary)

            Text(Localization.string(.nextOccurrence(formatDate(nextDateToShow))))
              .font(.caption)
              .foregroundColor(.appAccent)
          }
        }
      }

      Spacer()

      // Actions
      Menu {
        if onPause != nil {
          Button(action: onPause!) {
            Label(Localization.string(.pause), systemImage: "pause.circle")
          }
        }

        if onResume != nil {
          Button(action: onResume!) {
            Label(Localization.string(.resume), systemImage: "play.circle")
          }
        }

        if onActivate != nil {
          Button(action: onActivate!) {
            Label(Localization.string(.activate), systemImage: "checkmark.circle")
          }
        }

        if onEdit != nil {
          Button(action: onEdit!) {
            Label(Localization.string(.edit), systemImage: "pencil")
          }
        }

        if onDelete != nil {
          Button(role: .destructive, action: onDelete!) {
            Label(Localization.string(.delete), systemImage: "trash")
          }
        }
      } label: {
        Image(systemName: "ellipsis.circle")
          .foregroundColor(.secondary)
      }
    }
    .softCard(cornerRadius: 12, padding: 12, shadow: true)
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd MMM"
    return formatter.string(from: date)
  }
}

#Preview {
  BudgetView(
    templates: [],
    expenses: [],
    viewModel: ExpenseViewModel()
  )
}
