import SwiftUI

struct HolidayCountryPicker: View {
  let apiKey: String
  @Binding var selectedCountryCode: String
  @Binding var selectedCountryName: String
  @Binding var selectedLanguageName: String

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  @State private var countries: [CalendarificCountry] = []
  @State private var searchText: String = ""
  @State private var isLoading = false
  @State private var errorMessage: String?

  private var filteredCountries: [CalendarificCountry] {
    if searchText.isEmpty { return countries }
    return countries.filter {
      $0.countryName.localizedCaseInsensitiveContains(searchText)
        || $0.isoCode.localizedCaseInsensitiveContains(searchText)
    }
  }

  var body: some View {
    NavigationStack {
      List {
        // "None" option to clear selection
        Button(action: selectNone) {
          HStack {
            Text(Localization.string(.holidayNone))
              .foregroundColor(.primary)
            Spacer()
            if selectedCountryCode.isEmpty {
              Image(systemName: "checkmark")
                .foregroundColor(.appAccent)
            }
          }
        }
        .buttonStyle(.plain)

        if isLoading {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
          .listRowSeparator(.hidden)
        } else if let errorMessage = errorMessage {
          VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
              .font(.system(size: 28))
              .foregroundColor(.orange)
            Text(errorMessage)
              .font(.system(size: 14))
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 20)
          .listRowSeparator(.hidden)
        } else {
          ForEach(filteredCountries) { country in
            Button(action: { selectCountry(country) }) {
              HStack {
                VStack(alignment: .leading, spacing: 2) {
                  Text(country.countryName)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                  Text(country.isoCode)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                }
                Spacer()
                if country.isoCode == selectedCountryCode {
                  Image(systemName: "checkmark")
                    .foregroundColor(.appAccent)
                }
              }
            }
            .buttonStyle(.plain)
          }
        }
      }
      .searchable(text: $searchText, prompt: Localization.string(.holidaySearchCountry))
      .navigationTitle(Localization.string(.holidayCountry))
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(Localization.string(.cancel)) {
            dismiss()
          }
        }
      }
      .onAppear(perform: loadCountries)
    }
  }

  private func loadCountries() {
    // Try cache first
    let cached = HolidayService.shared.cachedCountries()
    if !cached.isEmpty {
      countries = cached
    }

    // If API key available, fetch fresh list
    guard !apiKey.isEmpty else {
      if cached.isEmpty {
        errorMessage = Localization.string(.holidayApiKey)
      }
      return
    }

    isLoading = cached.isEmpty
    Task {
      do {
        let fetched = try await HolidayService.shared.fetchCountries(apiKey: apiKey)
        await MainActor.run {
          countries = fetched
          isLoading = false
          errorMessage = nil
        }
      } catch {
        await MainActor.run {
          isLoading = false
          if countries.isEmpty {
            errorMessage = error.localizedDescription
          }
        }
      }
    }
  }

  private func selectNone() {
    selectedCountryCode = ""
    selectedCountryName = ""
    selectedLanguageName = ""
    // Remove stored language code
    let defaults = UserDefaults(suiteName: Constants.Storage.appGroupIdentifier)
    defaults?.removeObject(forKey: Constants.Holiday.languageCodeKey)

    // Remove all holiday events
    Task {
      await HolidayService.shared.removeAllHolidays(context: modelContext)
    }
    dismiss()
  }

  private func selectCountry(_ country: CalendarificCountry) {
    selectedCountryCode = country.isoCode
    selectedCountryName = country.countryName

    // Auto-detect language
    if let lang = HolidayService.shared.languageForCountry(country.isoCode) {
      selectedLanguageName = lang.name
      let defaults = UserDefaults(suiteName: Constants.Storage.appGroupIdentifier)
      defaults?.set(lang.code, forKey: Constants.Holiday.languageCodeKey)
    } else {
      selectedLanguageName = ""
      let defaults = UserDefaults(suiteName: Constants.Storage.appGroupIdentifier)
      defaults?.removeObject(forKey: Constants.Holiday.languageCodeKey)
    }

    dismiss()
  }
}
