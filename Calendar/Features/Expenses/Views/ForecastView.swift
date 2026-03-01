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
  @State private var selectedWindow: ForecastWindow = .days30
  @State private var forecastDays: [ForecastDay] = []

  private var monthlyTotals: [(month: String, expense: Double, income: Double, net: Double)] {
    let grouped = Dictionary(grouping: forecastDays) {
      DateFormatter.monthYear.string(from: $0.date)
    }
    return grouped.keys.sorted().map { key in
      let rows = grouped[key] ?? []
      let expense = rows.reduce(0) { $0 + $1.expensesUAH }
      let income = rows.reduce(0) { $0 + $1.incomeUAH }
      return (month: key, expense: expense, income: income, net: income - expense)
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        Picker(Localization.string(.forecast), selection: $selectedWindow) {
          ForEach(ForecastWindow.allCases) { window in
            Text(window.title).tag(window)
          }
        }
        .pickerStyle(.segmented)

        if forecastDays.isEmpty {
          Text(Localization.string(.forecastNoData))
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.secondaryFill)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
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
          .padding(16)
          .background(Color.secondaryFill)
          .clipShape(RoundedRectangle(cornerRadius: 12))

          VStack(alignment: .leading, spacing: 10) {
            Text(Localization.string(.forecastDailyTotals))
              .font(.headline)
            ForEach(forecastDays) { day in
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
          .padding(16)
          .background(Color.secondaryFill)
          .clipShape(RoundedRectangle(cornerRadius: 12))
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
    .onChange(of: expenses.count) { _, _ in
      refreshForecast()
    }
    .onChange(of: templates.count) { _, _ in
      refreshForecast()
    }
  }

  private func refreshForecast() {
    let start = Calendar.current.startOfDay(for: Date())
    do {
      let cache = try ForecastService.shared.cacheForecast(
        startDate: start,
        days: selectedWindow.rawValue,
        expenses: expenses.filter { $0.date >= start },
        templates: templates,
        context: modelContext
      )
      forecastDays = (try? JSONDecoder().decode([ForecastDay].self, from: cache.payload)) ?? []
    } catch {
      forecastDays = ForecastService.shared.forecastDays(
        startDate: start,
        days: selectedWindow.rawValue,
        expenses: expenses.filter { $0.date >= start },
        templates: templates
      )
    }
  }
}

private extension DateFormatter {
  static let monthYear: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy MMM"
    return formatter
  }()
}
