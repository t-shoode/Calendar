import SwiftData
import SwiftUI

struct ForecastView: View {
  enum ForecastWindow: Int, CaseIterable, Identifiable {
    case days30 = 30
    case days60 = 60
    case days90 = 90

    var id: Int { rawValue }

    var title: String {
      "\(rawValue)d"
    }
  }

  let expenses: [Expense]
  let templates: [RecurringExpenseTemplate]

  @Environment(\.modelContext) private var modelContext
  @Query(sort: \BillItem.updatedAt, order: .reverse) private var bills: [BillItem]
  @Query(sort: \WhatIfScenario.createdAt, order: .reverse) private var scenarios: [WhatIfScenario]
  @State private var selectedWindow: ForecastWindow = .days30
  @State private var selectedScenario: ForecastScenario = .baseline
  @State private var forecastDays: [ForecastDay] = []
  @State private var confidenceBands: [ForecastConfidenceBand] = []
  @State private var whatIfTitle = ""
  @State private var whatIfDeltaExpense = ""
  @State private var whatIfDeltaIncome = ""

  private var adjustedForecastDays: [ForecastDay] {
    ForecastService.shared.applyWhatIf(
      to: forecastDays,
      deltaExpensesUAH: normalizedDouble(whatIfDeltaExpense),
      deltaIncomeUAH: normalizedDouble(whatIfDeltaIncome)
    )
  }

  private var monthlyTotals: [(month: String, expense: Double, income: Double, net: Double)] {
    let grouped = Dictionary(grouping: adjustedForecastDays) {
      DateFormatter.monthYear.string(from: $0.date)
    }
    return grouped.keys.sorted().map { key in
      let rows = grouped[key] ?? []
      let expense = rows.reduce(0) { $0 + $1.expensesUAH }
      let income = rows.reduce(0) { $0 + $1.incomeUAH }
      return (month: key, expense: expense, income: income, net: income - expense)
    }
  }

  private var confidenceTotals: (low: Double, high: Double) {
    let low = confidenceBands.reduce(0) { $0 + $1.lowNetUAH }
    let high = confidenceBands.reduce(0) { $0 + $1.highNetUAH }
    return (low, high)
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        HStack {
          Text(Localization.string(.forecast))
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.textPrimary)
          Spacer()
        }

        Picker(Localization.string(.forecast), selection: $selectedWindow) {
          ForEach(ForecastWindow.allCases) { window in
            Text(window.title).tag(window)
          }
        }
        .pickerStyle(.segmented)
        .softControl(cornerRadius: 12, padding: 4)

        Picker(Localization.string(.forecastScenario), selection: $selectedScenario) {
          ForEach(ForecastScenario.allCases) { scenario in
            Text(scenario.title).tag(scenario)
          }
        }
        .pickerStyle(.segmented)
        .softControl(cornerRadius: 12, padding: 4)

        VStack(alignment: .leading, spacing: 10) {
          Text(Localization.string(.whatIfPlanner))
            .font(.headline)

          TextField(Localization.string(.whatIfScenarioTitle), text: $whatIfTitle)
            .textFieldStyle(.roundedBorder)

          HStack(spacing: 10) {
            TextField(Localization.string(.whatIfExtraExpenses), text: $whatIfDeltaExpense)
              .keyboardType(.decimalPad)
              .textFieldStyle(.roundedBorder)

            TextField(Localization.string(.whatIfExtraIncome), text: $whatIfDeltaIncome)
              .keyboardType(.decimalPad)
              .textFieldStyle(.roundedBorder)
          }

          Button(Localization.string(.save)) {
            saveWhatIfScenario()
          }
          .disabled(
            whatIfTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || (normalizedDouble(whatIfDeltaExpense) == 0 && normalizedDouble(whatIfDeltaIncome) == 0)
          )
          .font(.system(size: 13, weight: .semibold))
          .softControl(cornerRadius: 10, padding: 8)

          if let latestScenario = scenarios.first {
            let summary = "\(latestScenario.title) • E \(Int(latestScenario.deltaExpensesUAH)) • I \(Int(latestScenario.deltaIncomeUAH))"
            Text(
              Localization.string(.whatIfLatest(summary))
            )
            .font(.system(size: 12))
            .foregroundColor(.secondary)
          }
        }
        .softCard(cornerRadius: 12, padding: 16, shadow: false)

        if adjustedForecastDays.isEmpty {
          Text(Localization.string(.forecastNoData))
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .softCard(cornerRadius: 12, padding: 16, shadow: false)
        } else {
          VStack(alignment: .leading, spacing: 10) {
            Text(Localization.string(.forecastConfidenceRange))
              .font(.headline)
            let lowValue = "\(Currency.uah.symbol)\(String(format: "%.0f", confidenceTotals.low))"
            let highValue = "\(Currency.uah.symbol)\(String(format: "%.0f", confidenceTotals.high))"
            Text(Localization.string(.forecastNetRange(lowValue, highValue)))
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
          }
          .softCard(cornerRadius: 12, padding: 16, shadow: false)

          VStack(alignment: .leading, spacing: 10) {
            Text(Localization.string(.forecastMonthlyTotals))
              .font(.headline)
            ForEach(monthlyTotals, id: \.month) { item in
              HStack {
                Text(item.month)
                  .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(Currency.uah.symbol)\(String(format: "%.0f", item.net))")
                  .font(.system(size: 13, weight: .bold))
                  .foregroundColor(item.net < 0 ? .red : .green)
              }
              .padding(.vertical, 4)
            }
          }
          .softCard(cornerRadius: 12, padding: 16, shadow: false)

          VStack(alignment: .leading, spacing: 10) {
            Text(Localization.string(.forecastDailyTotals))
              .font(.headline)
            ForEach(adjustedForecastDays) { day in
              HStack {
                Text(day.date.formatted(date: .abbreviated, time: .omitted))
                  .font(.system(size: 12))
                  .foregroundColor(.secondary)
                Spacer()
                Text("\(Currency.uah.symbol)\(String(format: "%.0f", day.netUAH))")
                  .font(.system(size: 13, weight: .semibold))
                  .foregroundColor(day.netUAH < 0 ? .red : .green)
              }
            }
          }
          .softCard(cornerRadius: 12, padding: 16, shadow: false)
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 120)
    }
    .onAppear {
      refreshForecast()
    }
    .onChange(of: selectedWindow) { _, _ in
      refreshForecast()
    }
    .onChange(of: selectedScenario) { _, _ in
      refreshForecast()
    }
    .onChange(of: expenses.count) { _, _ in
      refreshForecast()
    }
    .onChange(of: templates.count) { _, _ in
      refreshForecast()
    }
    .onChange(of: bills.count) { _, _ in
      refreshForecast()
    }
  }

  private func refreshForecast() {
    let start = Calendar.current.startOfDay(for: Date())
    forecastDays = ForecastService.shared.forecastDays(
      startDate: start,
      days: selectedWindow.rawValue,
      expenses: expenses.filter { $0.date >= start },
      templates: templates,
      scenario: selectedScenario
    )
    confidenceBands = ForecastService.shared.confidenceBand(
      startDate: start,
      days: selectedWindow.rawValue,
      expenses: expenses,
      templates: templates,
      bills: bills
    )
  }

  private func saveWhatIfScenario() {
    let title = whatIfTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { return }

    do {
      _ = try WhatIfPlannerService.shared.createScenario(
        title: title,
        deltaExpensesUAH: normalizedDouble(whatIfDeltaExpense),
        deltaIncomeUAH: normalizedDouble(whatIfDeltaIncome),
        period: .month,
        context: modelContext
      )
      whatIfTitle = ""
      whatIfDeltaExpense = ""
      whatIfDeltaIncome = ""
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
  }

  private func normalizedDouble(_ value: String) -> Double {
    Double(value.replacingOccurrences(of: ",", with: ".")) ?? 0
  }
}

private extension DateFormatter {
  static let monthYear: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy MMM"
    return formatter
  }()
}
