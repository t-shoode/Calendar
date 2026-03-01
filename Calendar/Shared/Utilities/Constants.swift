import Foundation

public struct Constants {
  static let appName = "Calendar"

  struct Timer {
    static let defaultSnoozeDuration: TimeInterval = 5 * 60
  }

  struct UI {
    static let glassCornerRadius: CGFloat = 20
    static let glassCornerRadiusSmall: CGFloat = 12
    static let glassBorderWidth: CGFloat = 0.5
    static let glassBorderOpacity: Double = 0.2
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 20
  }

  struct Storage {
    static let appGroupIdentifier = "group.com.shoode.calendar"
  }



  struct Widget {
    static let weatherDataKey = "widgetWeatherData"
  }

  struct Holiday {
    static let apiBaseURL = "https://calendarific.com/api/v2"
    static let apiKeyKey = "holidayApiKey"
    static let countryCodeKey = "holidayCountryCode"
    static let countryNameKey = "holidayCountryName"
    static let languageCodeKey = "holidayLanguageCode"
    static let languageNameKey = "holidayLanguageName"
    static let lastSyncDateKey = "lastHolidaySyncDate"
    static let countriesCacheKey = "holidayCountriesCache"
    static let holidayColor = "teal"

    /// Maps common country ISO codes to their primary language code + name.
    /// Avoids the premium /languages endpoint on Calendarific.
    static let countryLanguageMap: [String: (code: String, name: String)] = [
      "UA": (code: "uk", name: "Українська"),
      "US": (code: "en", name: "English"),
      "GB": (code: "en", name: "English"),
      "DE": (code: "de", name: "Deutsch"),
      "FR": (code: "fr", name: "Français"),
      "ES": (code: "es", name: "Español"),
      "IT": (code: "it", name: "Italiano"),
      "PT": (code: "pt", name: "Português"),
      "PL": (code: "pl", name: "Polski"),
      "CZ": (code: "cs", name: "Čeština"),
      "NL": (code: "nl", name: "Nederlands"),
      "SE": (code: "sv", name: "Svenska"),
      "NO": (code: "no", name: "Norsk"),
      "DK": (code: "da", name: "Dansk"),
      "FI": (code: "fi", name: "Suomi"),
      "JP": (code: "ja", name: "日本語"),
      "KR": (code: "ko", name: "한국어"),
      "CN": (code: "zh", name: "中文"),
      "IN": (code: "hi", name: "हिन्दी"),
      "BR": (code: "pt", name: "Português"),
      "TR": (code: "tr", name: "Türkçe"),
      "RO": (code: "ro", name: "Română"),
      "HU": (code: "hu", name: "Magyar"),
      "GR": (code: "el", name: "Ελληνικά"),
      "IL": (code: "he", name: "עברית"),
      "SA": (code: "ar", name: "العربية"),
      "CA": (code: "en", name: "English"),
      "AU": (code: "en", name: "English"),
      "AT": (code: "de", name: "Deutsch"),
      "CH": (code: "de", name: "Deutsch"),
      "BE": (code: "nl", name: "Nederlands"),
      "IE": (code: "en", name: "English"),
      "NZ": (code: "en", name: "English"),
      "MX": (code: "es", name: "Español"),
      "AR": (code: "es", name: "Español"),
      "CL": (code: "es", name: "Español"),
      "CO": (code: "es", name: "Español"),
    ]
  }

  struct Weather {
    static let cityKey = "weatherCity"
  }

  struct FX {
    static let rateUSDKey = "fx.rate.usd"
    static let rateEURKey = "fx.rate.eur"
    static let manualUSDKey = "fx.manual.usd"
    static let manualEURKey = "fx.manual.eur"
    static let updatedAtKey = "fx.updatedAt"
  }
}
