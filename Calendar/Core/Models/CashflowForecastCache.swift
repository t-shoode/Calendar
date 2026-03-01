import Foundation
import SwiftData

struct ForecastDay: Codable, Identifiable {
  let id: String
  let date: Date
  let expensesUAH: Double
  let incomeUAH: Double

  var netUAH: Double {
    incomeUAH - expensesUAH
  }

  init(date: Date, expensesUAH: Double, incomeUAH: Double) {
    let key = ISO8601DateFormatter().string(from: date)
    self.id = key
    self.date = date
    self.expensesUAH = expensesUAH
    self.incomeUAH = incomeUAH
  }
}

@Model
final class CashflowForecastCache {
  var id: UUID
  var startDate: Date
  var endDate: Date
  var payload: Data
  var updatedAt: Date

  init(startDate: Date, endDate: Date, payload: Data) {
    self.id = UUID()
    self.startDate = startDate
    self.endDate = endDate
    self.payload = payload
    self.updatedAt = Date()
  }
}
