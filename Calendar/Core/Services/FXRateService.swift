import Foundation
import SwiftData

final class FXRateService {
  static let shared = FXRateService()

  private init() {}

  struct RatesResponse: Codable {
    let base: String
    let rates: [String: Double]
    let date: String
  }

  func refreshRatesIfNeeded(context: ModelContext) async {
    do {
      try loadCachedRates(context: context)
      let calendar = Calendar.current
      if let updated = FXRateStore.shared.lastUpdatedAt(), calendar.isDateInToday(updated) {
        return
      }
      try await fetchLatestRates(context: context)
    } catch {
      Logging.log.error("FX rate refresh failed: \(String(describing: error), privacy: .public)")
    }
  }

  func loadCachedRates(context: ModelContext) throws {
    let allRates = try context.fetch(FetchDescriptor<FXRate>())
    var latestUpdate: Date?
    for rate in allRates {
      guard let currency = Currency(rawValue: rate.currency) else { continue }
      FXRateStore.shared.setRateToUAH(
        rate.rateToUAH,
        currency: currency,
        isManual: rate.isManual,
        touchUpdatedAt: false
      )
      if latestUpdate == nil || rate.updatedAt > (latestUpdate ?? .distantPast) {
        latestUpdate = rate.updatedAt
      }
    }
    if let latestUpdate {
      FXRateStore.shared.setLastUpdatedAt(latestUpdate)
    }
  }

  func fetchLatestRates(context: ModelContext) async throws {
    let urlString =
      "https://api.exchangerate.host/latest?base=UAH&symbols=USD,EUR"
    guard let url = URL(string: urlString) else { return }

    let (data, _) = try await URLSession.shared.data(from: url)
    let decoded = try JSONDecoder().decode(RatesResponse.self, from: data)

    let usdRate = decoded.rates["USD"].map { 1 / $0 }
    let eurRate = decoded.rates["EUR"].map { 1 / $0 }

    if let usdRate = usdRate {
      try upsertRate(currency: .usd, rateToUAH: usdRate, source: "exchangerate.host", context: context)
    }
    if let eurRate = eurRate {
      try upsertRate(currency: .eur, rateToUAH: eurRate, source: "exchangerate.host", context: context)
    }

    try context.save()
  }

  func upsertRate(currency: Currency, rateToUAH: Double, source: String, context: ModelContext) throws {
    let descriptor = FetchDescriptor<FXRate>(
      predicate: #Predicate { rate in
        rate.currency == currency.rawValue
      }
    )
    let existing = try context.fetch(descriptor).first

    if let existing = existing {
      if existing.isManual { return }
      existing.rateToUAH = rateToUAH
      existing.source = source
      existing.updatedAt = Date()
      FXRateStore.shared.setRateToUAH(rateToUAH, currency: currency, isManual: false)
    } else {
      let newRate = FXRate(currency: currency, rateToUAH: rateToUAH, source: source, isManual: false)
      context.insert(newRate)
      FXRateStore.shared.setRateToUAH(rateToUAH, currency: currency, isManual: false)
    }
  }

  func setManualRate(currency: Currency, rateToUAH: Double, context: ModelContext) throws {
    let descriptor = FetchDescriptor<FXRate>(
      predicate: #Predicate { rate in
        rate.currency == currency.rawValue
      }
    )
    let existing = try context.fetch(descriptor).first

    if let existing = existing {
      existing.rateToUAH = rateToUAH
      existing.isManual = true
      existing.source = "manual"
      existing.updatedAt = Date()
    } else {
      let newRate = FXRate(currency: currency, rateToUAH: rateToUAH, source: "manual", isManual: true)
      context.insert(newRate)
    }
    FXRateStore.shared.setRateToUAH(rateToUAH, currency: currency, isManual: true)
    try context.save()
  }

  func clearManualRate(currency: Currency, context: ModelContext) throws {
    let descriptor = FetchDescriptor<FXRate>(
      predicate: #Predicate { rate in
        rate.currency == currency.rawValue
      }
    )
    if let existing = try context.fetch(descriptor).first {
      existing.isManual = false
      existing.source = "exchangerate.host"
      existing.updatedAt = Date()
      FXRateStore.shared.setRateToUAH(existing.rateToUAH, currency: currency, isManual: false)
      try context.save()
    }
  }
}
