import SwiftData
import SwiftUI

struct InsightsView: View {
  let expenses: [Expense]
  let viewModel: ExpenseViewModel

  @Environment(\.modelContext) private var modelContext
  @Query(sort: \WhatIfScenario.createdAt, order: .reverse) private var scenarios: [WhatIfScenario]
  @Query(sort: \SubscriptionItem.updatedAt, order: .reverse) private var subscriptions:
    [SubscriptionItem]
  @Query(sort: \BillItem.updatedAt, order: .reverse) private var bills: [BillItem]
  @Query(sort: \SavingsGoal.updatedAt, order: .reverse) private var goals: [SavingsGoal]
  @Query(sort: \NetWorthAccount.updatedAt, order: .reverse) private var netWorthAccounts:
    [NetWorthAccount]
  @Query(sort: \TripBudget.updatedAt, order: .reverse) private var trips: [TripBudget]
  @Query(sort: \WeeklyReviewSnapshot.generatedAt, order: .reverse) private var reviews:
    [WeeklyReviewSnapshot]
  @State private var selectedPeriod: InsightsPeriod = .monthly
  @State private var whatIfTitle = ""
  @State private var whatIfExpenseText = ""
  @State private var whatIfIncomeText = ""
  @State private var activeFinancePanel: FinancePanel?

  enum FinancePanel: String, Identifiable {
    case subscriptions
    case bills
    case goals
    case netWorth
    case trips
    case reviews

    var id: String { rawValue }
  }

  enum InsightsPeriod: String, CaseIterable {
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

  private var currentMonthExpenses: [Expense] {
    let calendar = Calendar.current
    let now = Date()
    return expenses.filter {
      calendar.isDate($0.date, equalTo: now, toGranularity: .month)
    }
  }

  private var lastMonthExpenses: [Expense] {
    let calendar = Calendar.current
    guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) else { return [] }
    return expenses.filter {
      calendar.isDate($0.date, equalTo: lastMonth, toGranularity: .month)
    }
  }

  private var filteredForPeriod: [Expense] {
    if selectedPeriod == .all {
      return expenses
    }
    let bounds = periodBounds(for: selectedPeriod)
    return expenses.filter { $0.date >= bounds.start && $0.date <= bounds.end }
  }

  private var categoryBreakdown: [(category: ExpenseCategory, amount: Double, percentage: Double)] {
    let total = filteredForPeriod.reduce(0) { $0 + viewModel.amountInUAH($1) }
    guard total > 0 else { return [] }

    let grouped = Dictionary(grouping: filteredForPeriod) { $0.primaryCategory }
    return grouped.map { (category, expenses) in
      let amount = expenses.reduce(0) { $0 + viewModel.amountInUAH($1) }
      return (category, amount, (amount / total) * 100)
    }.sorted { $0.amount > $1.amount }
  }

  private var topSpendCategories: [(name: String, amount: Double)] {
    categoryBreakdown.prefix(3).map { item in
      (name: item.category.displayName, amount: item.amount)
    }
  }

  private var topSpendMerchants: [(name: String, amount: Double)] {
    let grouped = Dictionary(grouping: filteredForPeriod) { expense in
      let merchant = expense.merchant?.trimmingCharacters(in: .whitespacesAndNewlines)
      return (merchant?.isEmpty == false ? merchant! : expense.title)
    }
    return grouped.map { merchant, expenses in
      (name: merchant, amount: expenses.reduce(0) { $0 + viewModel.amountInUAH($1) })
    }
    .sorted { $0.amount > $1.amount }
    .prefix(3)
    .map { $0 }
  }

  private var anomalies: [SpendAnomaly] {
    let bounds = periodBounds(for: selectedPeriod == .all ? .monthly : selectedPeriod)
    let periodLengthDays = max(
      1,
      Calendar.current.dateComponents([.day], from: bounds.start, to: bounds.end).day ?? 1
    )
    let baselineEnd = Calendar.current.date(byAdding: .day, value: -1, to: bounds.start) ?? bounds.start
    let baselineStart =
      Calendar.current.date(byAdding: .day, value: -periodLengthDays, to: baselineEnd) ?? baselineEnd

    let current = expenses.filter { $0.date >= bounds.start && $0.date <= bounds.end }
    let baseline = expenses.filter { $0.date >= baselineStart && $0.date <= baselineEnd }

    let currentByMerchant = Dictionary(grouping: current) { $0.merchant ?? $0.title }
    let baselineByMerchant = Dictionary(grouping: baseline) { $0.merchant ?? $0.title }

    var result: [SpendAnomaly] = []
    for (merchant, merchantExpenses) in currentByMerchant {
      let currentTotal = merchantExpenses.reduce(0) { $0 + viewModel.amountInUAH($1) }
      let baselineTotal =
        baselineByMerchant[merchant]?.reduce(0) { $0 + viewModel.amountInUAH($1) } ?? 0

      guard currentTotal > 600 else { continue }
      if baselineTotal <= 0, currentTotal > 1200 {
        result.append(
          SpendAnomaly(merchant: merchant, currentAmount: currentTotal, baselineAmount: baselineTotal)
        )
        continue
      }

      guard baselineTotal > 0 else { continue }
      let ratio = currentTotal / baselineTotal
      if ratio >= 1.8 {
        result.append(
          SpendAnomaly(merchant: merchant, currentAmount: currentTotal, baselineAmount: baselineTotal)
        )
      }
    }

    return result.sorted { $0.deltaAmount > $1.deltaAmount }.prefix(5).map { $0 }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        HStack {
          Text(Localization.string(.expenseInsights))
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.textPrimary)
          Spacer()
        }

        HStack(spacing: 0) {
          ForEach(InsightsPeriod.allCases, id: \.self) { period in
            Button {
              withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedPeriod = period
              }
            } label: {
              Text(period.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(selectedPeriod == period ? .white : .textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                  selectedPeriod == period ? Color.appAccent.opacity(0.8) : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
          }
        }
        .padding(4)
        .softControl(cornerRadius: 12, padding: 4)

        totalsCard

        VStack(alignment: .leading, spacing: 10) {
          Text("Finance Modules")
            .font(.system(size: 12, weight: .black))
            .tracking(1)
            .foregroundColor(.secondary)

          financeRow(
            title: "Subscriptions",
            subtitle: "\(subscriptions.filter { $0.isActive }.count) active",
            systemImage: "repeat"
          ) { activeFinancePanel = .subscriptions }

          financeRow(
            title: "Bills",
            subtitle: "\(bills.filter { !$0.isPaid }.count) unpaid",
            systemImage: "doc.text"
          ) { activeFinancePanel = .bills }

          financeRow(
            title: "Savings Goals",
            subtitle: "\(goals.filter { !$0.isArchived }.count) active",
            systemImage: "target"
          ) { activeFinancePanel = .goals }

          financeRow(
            title: "Net Worth",
            subtitle: "\(netWorthAccounts.filter { $0.includeInTotal }.count) accounts",
            systemImage: "chart.line.uptrend.xyaxis"
          ) { activeFinancePanel = .netWorth }

          financeRow(
            title: "Trip Budgets",
            subtitle: "\(trips.filter { $0.isActive }.count) active",
            systemImage: "airplane"
          ) { activeFinancePanel = .trips }

          financeRow(
            title: "Weekly Reviews",
            subtitle: "\(reviews.count) snapshots",
            systemImage: "calendar.badge.clock"
          ) { activeFinancePanel = .reviews }
        }
        .softCard(cornerRadius: 12, padding: 16, shadow: false)

        if !lastMonthExpenses.isEmpty {
          VStack(alignment: .leading, spacing: 16) {
            Text(Localization.string(.spendingTrends))
              .font(.system(size: 12, weight: .black))
              .tracking(1)
              .foregroundColor(.secondary)

            let trends = calculateTrends()
            ForEach(trends.prefix(5), id: \.category) { trend in
              TrendRow(trend: trend)
            }
          }
          .softCard(cornerRadius: 12, padding: 16, shadow: false)
        }

        if !categoryBreakdown.isEmpty {
          VStack(alignment: .leading, spacing: 16) {
            Text(Localization.string(.thisMonthSpending))
              .font(.system(size: 12, weight: .black))
              .tracking(1)
              .foregroundColor(.secondary)

            ForEach(categoryBreakdown, id: \.category) { item in
              CategoryBreakdownRow(
                category: item.category,
                amount: item.amount,
                percentage: item.percentage
              )
            }
          }
          .softCard(cornerRadius: 12, padding: 16, shadow: false)
        }

        if !topSpendCategories.isEmpty || !topSpendMerchants.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            Text(Localization.string(.insightsTopDrivers))
              .font(.system(size: 12, weight: .black))
              .tracking(1)
              .foregroundColor(.secondary)

            ForEach(Array(topSpendCategories.enumerated()), id: \.offset) { _, driver in
              HStack {
                Text(driver.name)
                  .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(Currency.uah.symbol)\(String(format: "%.0f", driver.amount))")
                  .font(.system(size: 12, weight: .medium))
                  .foregroundColor(.secondary)
              }
            }

            ForEach(Array(topSpendMerchants.enumerated()), id: \.offset) { _, driver in
              HStack {
                Text(driver.name)
                  .font(.system(size: 12, weight: .medium))
                  .foregroundColor(.secondary)
                Spacer()
                Text("\(Currency.uah.symbol)\(String(format: "%.0f", driver.amount))")
                  .font(.system(size: 11, weight: .medium))
                  .foregroundColor(.secondary)
              }
            }
          }
          .softCard(cornerRadius: 12, padding: 16, shadow: false)
        }

        if !anomalies.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            Text(Localization.string(.insightsAnomalies))
              .font(.system(size: 12, weight: .black))
              .tracking(1)
              .foregroundColor(.secondary)

            ForEach(anomalies) { anomaly in
              HStack {
                VStack(alignment: .leading, spacing: 3) {
                  Text(anomaly.merchant)
                    .font(.system(size: 13, weight: .semibold))
                  Text(
                    Localization.string(
                      .insightsBaseline(
                        "\(Currency.uah.symbol)\(String(format: "%.0f", anomaly.baselineAmount))"
                      )
                    )
                  )
                  .font(.system(size: 11))
                  .foregroundColor(.secondary)
                }

                Spacer()

                Text("+\(Currency.uah.symbol)\(String(format: "%.0f", anomaly.deltaAmount))")
                  .font(.system(size: 12, weight: .bold))
                  .foregroundColor(.red)
              }
            }
          }
          .softCard(cornerRadius: 12, padding: 16, shadow: false)
        }

        VStack(alignment: .leading, spacing: 10) {
          Text(Localization.string(.insightsWhatIfScenarios))
            .font(.system(size: 12, weight: .black))
            .tracking(1)
            .foregroundColor(.secondary)

          TextField(Localization.string(.whatIfScenarioTitle), text: $whatIfTitle)
            .textFieldStyle(.roundedBorder)

          HStack(spacing: 8) {
            TextField(Localization.string(.whatIfExtraExpenses), text: $whatIfExpenseText)
              .keyboardType(.decimalPad)
              .textFieldStyle(.roundedBorder)

            TextField(Localization.string(.whatIfExtraIncome), text: $whatIfIncomeText)
              .keyboardType(.decimalPad)
              .textFieldStyle(.roundedBorder)
          }

          Button(Localization.string(.save)) {
            saveWhatIfScenario()
          }
          .disabled(
            whatIfTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || (normalizedDouble(whatIfExpenseText) == 0 && normalizedDouble(whatIfIncomeText) == 0)
          )
          .font(.system(size: 13, weight: .semibold))
          .softControl(cornerRadius: 10, padding: 8)

          ForEach(scenarios.prefix(3), id: \.id) { scenario in
            Text(
              "\(scenario.title): E \(Int(scenario.deltaExpensesUAH)) / I \(Int(scenario.deltaIncomeUAH))"
            )
            .font(.system(size: 11))
            .foregroundColor(.secondary)
          }
        }
        .softCard(cornerRadius: 12, padding: 16, shadow: false)

        if expenses.isEmpty {
          VStack(spacing: 16) {
            Image(systemName: "chart.pie")
              .font(.system(size: 48))
              .foregroundColor(.secondary)

            Text(Localization.string(.noDataYet))
              .font(.headline)

            Text(Localization.string(.addExpensesForInsights))
              .font(.caption)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
          }
          .softCard(cornerRadius: 14, padding: 20, shadow: false)
          .padding(.top, 40)
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 120)
    }
    .sheet(item: $activeFinancePanel) { panel in
      switch panel {
      case .subscriptions:
        SubscriptionCenterSheet()
      case .bills:
        BillsDashboardSheet()
      case .goals:
        SavingsGoalsSheet()
      case .netWorth:
        NetWorthSheet()
      case .trips:
        TripBudgetsSheet()
      case .reviews:
        WeeklyReviewsSheet()
      }
    }
  }

  private func financeRow(
    title: String,
    subtitle: String,
    systemImage: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: systemImage)
          .font(.system(size: 14, weight: .semibold))
          .frame(width: 20)
          .foregroundColor(.appAccent)
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.textPrimary)
          Text(subtitle)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(.secondary)
      }
      .padding(.vertical, 3)
    }
    .buttonStyle(.plain)
  }

  private var totalsCard: some View {
    let bounds = periodBounds(for: selectedPeriod)
    let expenseTotals = viewModel.multiCurrencyTotalsForPeriod(
      expenses: filteredForPeriod, start: bounds.start, end: bounds.end, isIncome: false)
    let incomeTotals = viewModel.multiCurrencyTotalsForPeriod(
      expenses: filteredForPeriod, start: bounds.start, end: bounds.end, isIncome: true)

    return VStack(spacing: 16) {
      HStack(spacing: 12) {
        VStack(spacing: 4) {
          Text(Localization.string(.expenseExpensesLabel))
            .font(.system(size: 10, weight: .black))
            .foregroundColor(.textTertiary)
            .tracking(2)

          Text("\(Currency.uah.symbol)\(String(format: "%.2f", expenseTotals.uah))")
            .font(.system(size: 28, weight: .black))
            .foregroundColor(.textPrimary)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity)

        Divider()
          .frame(height: 48)

        VStack(spacing: 4) {
          Text(Localization.string(.expenseIncomeLabel))
            .font(.system(size: 10, weight: .black))
            .foregroundColor(.textTertiary)
            .tracking(2)

          Text("\(Currency.uah.symbol)\(String(format: "%.2f", incomeTotals.uah))")
            .font(.system(size: 28, weight: .black))
            .foregroundColor(.green)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
      }

      HStack(spacing: 24) {
        VStack(spacing: 8) {
          HStack(spacing: 10) {
            VStack(spacing: 2) {
              Text("$")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.textTertiary)
              Text(String(format: "%.2f", expenseTotals.usd))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.textSecondary)
            }

            VStack(spacing: 2) {
              Text("€")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.textTertiary)
              Text(String(format: "%.2f", expenseTotals.eur))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.textSecondary)
            }
          }
        }

        Divider()
          .frame(height: 48)

        VStack(spacing: 8) {
          HStack(spacing: 10) {
            VStack(spacing: 2) {
              Text("$")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.textTertiary)
              Text(String(format: "%.2f", incomeTotals.usd))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.textSecondary)
            }

            VStack(spacing: 2) {
              Text("€")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.textTertiary)
              Text(String(format: "%.2f", incomeTotals.eur))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.textSecondary)
            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity)
    .softCard(cornerRadius: 16, padding: 20, shadow: false)
  }

  private func periodBounds(for period: InsightsPeriod) -> (start: Date, end: Date) {
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
    case .all:
      interval = DateInterval(start: today, end: today)
    }

    return (
      interval.start, calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
    )
  }

  private func calculateTrends() -> [Trend] {
    let currentGrouped = Dictionary(grouping: currentMonthExpenses) { $0.primaryCategory }
    let lastGrouped = Dictionary(grouping: lastMonthExpenses) { $0.primaryCategory }

    var trends: [Trend] = []

    for (category, currentExpenses) in currentGrouped {
      let currentTotal = currentExpenses.reduce(0) { $0 + viewModel.amountInUAH($1) }
      let lastTotal = lastGrouped[category]?.reduce(0) { $0 + viewModel.amountInUAH($1) } ?? 0

      let change: Double
      if lastTotal > 0 {
        change = ((currentTotal - lastTotal) / lastTotal) * 100
      } else {
        change = currentTotal > 0 ? 100 : 0
      }

      trends.append(
        Trend(
          category: category, currentAmount: currentTotal, lastAmount: lastTotal, change: change))
    }

    return trends.sorted { abs($0.change) > abs($1.change) }
  }

  private func saveWhatIfScenario() {
    let title = whatIfTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { return }

    do {
      _ = try WhatIfPlannerService.shared.createScenario(
        title: title,
        deltaExpensesUAH: normalizedDouble(whatIfExpenseText),
        deltaIncomeUAH: normalizedDouble(whatIfIncomeText),
        period: .month,
        context: modelContext
      )
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
  }

  private func normalizedDouble(_ value: String) -> Double {
    Double(value.replacingOccurrences(of: ",", with: ".")) ?? 0
  }
}

struct Trend: Identifiable {
  let id = UUID()
  let category: ExpenseCategory
  let currentAmount: Double
  let lastAmount: Double
  let change: Double
}

struct SpendAnomaly: Identifiable {
  let id = UUID()
  let merchant: String
  let currentAmount: Double
  let baselineAmount: Double

  var deltaAmount: Double {
    max(currentAmount - baselineAmount, 0)
  }
}

struct TrendRow: View {
  let trend: Trend

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: trend.category.icon)
        .foregroundColor(trend.category.color)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 2) {
        Text(trend.category.displayName)
          .font(.subheadline)

        HStack(spacing: 4) {
          Text("\(Currency.uah.symbol)\(String(format: "%.0f", trend.currentAmount))")
            .font(.caption)
            .foregroundColor(.secondary)

          if trend.lastAmount > 0 {
            Text(
              Localization.string(
                .wasAmount("\(Currency.uah.symbol)\(String(format: "%.0f", trend.lastAmount))"))
            )
            .font(.caption2)
            .foregroundColor(.secondary.opacity(0.7))
          }
        }
      }

      Spacer()

      HStack(spacing: 4) {
        Image(systemName: trend.change > 0 ? "arrow.up" : "arrow.down")
          .font(.caption2)

        Text("\(String(format: "%.0f", abs(trend.change)))%")
          .font(.caption.bold())
      }
      .foregroundColor(trend.change > 0 ? .red : .green)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background((trend.change > 0 ? Color.red : Color.green).opacity(0.1))
      .cornerRadius(6)
    }
    .padding(.vertical, 4)
  }
}

struct CategoryBreakdownRow: View {
  let category: ExpenseCategory
  let amount: Double
  let percentage: Double

  var body: some View {
    VStack(spacing: 8) {
      HStack {
        HStack(spacing: 8) {
          Image(systemName: category.icon)
            .foregroundColor(category.color)
            .frame(width: 20)

          Text(category.displayName)
            .font(.subheadline)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 2) {
          Text("\(Currency.uah.symbol)\(String(format: "%.0f", amount))")
            .font(.subheadline.bold())

          Text("\(String(format: "%.1f", percentage))%")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      GeometryReader { geometry in
        RoundedRectangle(cornerRadius: 2)
          .fill(category.color)
          .frame(width: geometry.size.width * (percentage / 100), height: 4)
      }
      .frame(height: 4)
    }
    .padding(.vertical, 4)
  }
}

private struct SubscriptionCenterSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \SubscriptionItem.nextRenewalDate) private var subscriptions: [SubscriptionItem]

  var body: some View {
    NavigationStack {
      List {
        Section("Active Subscriptions") {
          if subscriptions.isEmpty {
            Text("No subscriptions yet")
              .foregroundColor(.secondary)
          } else {
            ForEach(subscriptions) { item in
              HStack {
                VStack(alignment: .leading) {
                  Text(item.name)
                  Text(item.nextRenewalDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(item.amount, specifier: "%.2f") \(item.currency.uppercased())")
                  .font(.system(size: 12, weight: .semibold))
                Toggle("", isOn: Binding(
                  get: { item.isActive },
                  set: { item.isActive = $0; item.updatedAt = Date(); try? modelContext.save() }
                ))
              }
            }
          }
        }
      }
      .navigationTitle("Subscriptions")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Close") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Detect") {
            let candidates = (try? SubscriptionService.shared.detectCandidates(context: modelContext)) ?? []
            for candidate in candidates where subscriptions.contains(where: { $0.id == candidate.id }) == false {
              try? SubscriptionService.shared.save(candidate, context: modelContext)
            }
          }
        }
      }
    }
  }
}

private struct BillsDashboardSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \BillItem.dueDate) private var bills: [BillItem]

  var body: some View {
    NavigationStack {
      List {
        Section("Due & Overdue") {
          ForEach(bills.filter { !$0.isPaid }) { bill in
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(bill.name)
                Text(bill.dueDate.formatted(date: .abbreviated, time: .omitted))
                  .font(.system(size: 11))
                  .foregroundColor(.secondary)
              }
              Spacer()
              Text("\(bill.amount, specifier: "%.2f") \(bill.currency.uppercased())")
                .font(.system(size: 12, weight: .semibold))
              Button("Paid") {
                try? BillService.shared.markPaid(bill, context: modelContext)
              }
              .buttonStyle(.bordered)
              .controlSize(.small)
            }
          }
          if bills.filter({ !$0.isPaid }).isEmpty {
            Text("No unpaid bills")
              .foregroundColor(.secondary)
          }
        }
      }
      .navigationTitle("Bills")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Close") { dismiss() }
        }
      }
    }
  }
}

private struct SavingsGoalsSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \SavingsGoal.updatedAt, order: .reverse) private var goals: [SavingsGoal]

  var body: some View {
    NavigationStack {
      List {
        Section("Goals") {
          if goals.isEmpty {
            Text("No goals yet")
              .foregroundColor(.secondary)
          }
          ForEach(goals) { goal in
            VStack(alignment: .leading, spacing: 6) {
              HStack {
                Text(goal.title)
                Spacer()
                Text("\(goal.currentAmountUAH, specifier: "%.0f") / \(goal.targetAmountUAH, specifier: "%.0f") ₴")
                  .font(.system(size: 12, weight: .semibold))
              }
              ProgressView(value: goal.targetAmountUAH > 0 ? goal.currentAmountUAH / goal.targetAmountUAH : 0)
                .tint(.appAccent)
              HStack {
                Button("+100 ₴") {
                  try? SavingsService.shared.contribute(goal: goal, amountUAH: 100, context: modelContext)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Spacer()
                Text(goal.isArchived ? "Archived" : "Active")
                  .font(.system(size: 11))
                  .foregroundColor(.secondary)
              }
            }
          }
        }
      }
      .navigationTitle("Savings Goals")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Close") { dismiss() }
        }
      }
    }
  }
}

private struct NetWorthSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \NetWorthAccount.updatedAt, order: .reverse) private var accounts: [NetWorthAccount]
  @Query(sort: \NetWorthSnapshot.date, order: .reverse) private var snapshots: [NetWorthSnapshot]

  private var total: Double {
    (try? NetWorthService.shared.totalNetWorthUAH(context: modelContext)) ?? 0
  }

  var body: some View {
    NavigationStack {
      List {
        Section("Summary") {
          HStack {
            Text("Total net worth")
            Spacer()
            Text("\(total, specifier: "%.0f") ₴")
              .font(.system(size: 16, weight: .bold))
          }
          Button("Record snapshot") {
            _ = try? NetWorthService.shared.recordSnapshot(context: modelContext, date: Date())
          }
          if let latest = snapshots.first {
            Text("Last snapshot: \(latest.date.formatted(date: .abbreviated, time: .omitted))")
              .font(.system(size: 11))
              .foregroundColor(.secondary)
          }
        }
        Section("Accounts") {
          ForEach(accounts) { account in
            HStack {
              VStack(alignment: .leading) {
                Text(account.name)
                Text(account.type.capitalized)
                  .font(.system(size: 11))
                  .foregroundColor(.secondary)
              }
              Spacer()
              Text("\(account.balanceUAH, specifier: "%.0f") ₴")
            }
          }
        }
      }
      .navigationTitle("Net Worth")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Close") { dismiss() }
        }
      }
    }
  }
}

private struct TripBudgetsSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \TripBudget.updatedAt, order: .reverse) private var trips: [TripBudget]

  var body: some View {
    NavigationStack {
      List {
        Section("Trip Budgets") {
          if trips.isEmpty {
            Text("No trips yet")
              .foregroundColor(.secondary)
          } else {
            ForEach(trips) { trip in
              VStack(alignment: .leading, spacing: 6) {
                HStack {
                  Text(trip.name)
                  Spacer()
                  Text(trip.isActive ? "Active" : "Inactive")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
                Text("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                  .font(.system(size: 11))
                  .foregroundColor(.secondary)
                if let remaining = try? TripBudgetService.shared.remainingBudgetUAH(context: modelContext, trip: trip) {
                  Text("Remaining: \(remaining, specifier: "%.0f") ₴")
                    .font(.system(size: 12, weight: .semibold))
                }
              }
            }
          }
        }
      }
      .navigationTitle("Trip Budgets")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Close") { dismiss() }
        }
      }
    }
  }
}

private struct WeeklyReviewsSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \WeeklyReviewSnapshot.generatedAt, order: .reverse) private var reviews: [WeeklyReviewSnapshot]

  var body: some View {
    NavigationStack {
      List {
        Section {
          Button("Generate this week review") {
            let calendar = Calendar.current
            let now = Date()
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
              ?? DateInterval(start: now, end: now)
            _ = try? WeeklyReviewService.shared.generateWeeklyReview(
              context: modelContext,
              weekStart: weekInterval.start,
              weekEnd: weekInterval.end
            )
          }
        }

        Section("History") {
          if reviews.isEmpty {
            Text("No snapshots yet")
              .foregroundColor(.secondary)
          } else {
            ForEach(reviews) { review in
              VStack(alignment: .leading, spacing: 4) {
                Text("\(review.weekStart.formatted(date: .abbreviated, time: .omitted)) – \(review.weekEnd.formatted(date: .abbreviated, time: .omitted))")
                Text(review.summaryJSON)
                  .font(.system(size: 11))
                  .foregroundColor(.secondary)
                  .lineLimit(3)
              }
            }
          }
        }
      }
      .navigationTitle("Weekly Reviews")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Close") { dismiss() }
        }
      }
    }
  }
}

#Preview {
  InsightsView(
    expenses: [],
    viewModel: ExpenseViewModel()
  )
}
