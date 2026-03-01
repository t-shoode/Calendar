import Foundation
import SwiftData

@Model
final class FXRate {
  var id: UUID
  var currency: String
  var rateToUAH: Double
  var source: String
  var isManual: Bool
  var updatedAt: Date

  init(currency: Currency, rateToUAH: Double, source: String, isManual: Bool = false) {
    self.id = UUID()
    self.currency = currency.rawValue
    self.rateToUAH = rateToUAH
    self.source = source
    self.isManual = isManual
    self.updatedAt = Date()
  }
}
