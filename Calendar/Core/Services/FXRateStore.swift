import Foundation

final class FXRateStore {
  static let shared = FXRateStore()

  private let defaults: UserDefaults

  private init() {
    defaults = UserDefaults(suiteName: Constants.Storage.appGroupIdentifier) ?? .standard
  }

  func rateToUAH(for currency: Currency) -> Double {
    switch currency {
    case .uah:
      return 1.0
    case .usd:
      return defaults.double(forKey: Constants.FX.rateUSDKey).nonZeroOrDefault(Currency.usd.rateToUAH)
    case .eur:
      return defaults.double(forKey: Constants.FX.rateEURKey).nonZeroOrDefault(Currency.eur.rateToUAH)
    }
  }

  func isManual(currency: Currency) -> Bool {
    switch currency {
    case .uah:
      return false
    case .usd:
      return defaults.bool(forKey: Constants.FX.manualUSDKey)
    case .eur:
      return defaults.bool(forKey: Constants.FX.manualEURKey)
    }
  }

  func setRateToUAH(_ rate: Double, currency: Currency, isManual: Bool, touchUpdatedAt: Bool = true) {
    switch currency {
    case .uah:
      return
    case .usd:
      defaults.set(rate, forKey: Constants.FX.rateUSDKey)
      defaults.set(isManual, forKey: Constants.FX.manualUSDKey)
    case .eur:
      defaults.set(rate, forKey: Constants.FX.rateEURKey)
      defaults.set(isManual, forKey: Constants.FX.manualEURKey)
    }
    if touchUpdatedAt {
      defaults.set(Date(), forKey: Constants.FX.updatedAtKey)
    }
  }

  func lastUpdatedAt() -> Date? {
    defaults.object(forKey: Constants.FX.updatedAtKey) as? Date
  }

  func setLastUpdatedAt(_ date: Date) {
    defaults.set(date, forKey: Constants.FX.updatedAtKey)
  }
}

private extension Double {
  func nonZeroOrDefault(_ fallback: Double) -> Double {
    if self == 0 { return fallback }
    return self
  }
}
