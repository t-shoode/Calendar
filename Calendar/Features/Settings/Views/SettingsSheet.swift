import SwiftUI

struct SettingsSheet: View {
  @Binding var isPresented: Bool
  @EnvironmentObject var appState: AppState
  @Environment(\.modelContext) private var modelContext
  #if DEBUG
    @EnvironmentObject var debugSettings: DebugSettings
  #endif

  // Holiday settings stored in shared UserDefaults
  @AppStorage(
    Constants.Holiday.apiKeyKey,
    store: UserDefaults(suiteName: Constants.Storage.appGroupIdentifier))
  private var holidayApiKey: String = ""

  @AppStorage(
    Constants.Holiday.countryCodeKey,
    store: UserDefaults(suiteName: Constants.Storage.appGroupIdentifier))
  private var holidayCountryCode: String = ""

  @AppStorage(
    Constants.Holiday.countryNameKey,
    store: UserDefaults(suiteName: Constants.Storage.appGroupIdentifier))
  private var holidayCountryName: String = ""

  @AppStorage(
    Constants.Holiday.languageNameKey,
    store: UserDefaults(suiteName: Constants.Storage.appGroupIdentifier))
  private var holidayLanguageName: String = ""

  @AppStorage(
    Constants.Weather.cityKey,
    store: UserDefaults(suiteName: Constants.Storage.appGroupIdentifier))
  private var weatherCity: String = ""

  @State private var isSyncing = false
  @State private var syncMessage: String?
  @State private var showCountryPicker = false
  @State private var editingFXCurrency: Currency = .usd
  @State private var showFXEditor = false

  private var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
  }

  private var buildNumber: String {
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
  }

  private var buildMode: String {
    #if DEBUG
      return "Debug"
    #else
      return "Release"
    #endif
  }

  private var lastSyncDateFormatted: String {
    let defaults = UserDefaults(suiteName: Constants.Storage.appGroupIdentifier)
    guard let date = defaults?.object(forKey: Constants.Holiday.lastSyncDateKey) as? Date else {
      return Localization.string(.holidayNever)
    }
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    formatter.locale = Localization.locale
    return formatter.string(from: date)
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          buildInfoSection
        }

        Section {
          fxSection
        }

        Section {
          holidaySection
        }

        #if DEBUG
          Section {
            debugSection
          }
        #endif
      }
      .navigationTitle(Localization.string(.settings))
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(Localization.string(.cancel)) {
            isPresented = false
          }
        }
      }
    }
    .sheet(isPresented: $showCountryPicker) {
      HolidayCountryPicker(
        apiKey: holidayApiKey,
        selectedCountryCode: $holidayCountryCode,
        selectedCountryName: $holidayCountryName,
        selectedLanguageName: $holidayLanguageName
      )
    }
    .sheet(isPresented: $showFXEditor) {
      FXRateEditorSheet(currency: editingFXCurrency) {
        showFXEditor = false
      }
    }
    .task {
      await FXRateService.shared.refreshRatesIfNeeded(context: modelContext)
    }
  }

  // MARK: - Holiday Section

  private var fxSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(Localization.string(.fxRates))
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.secondary)

      VStack(spacing: 0) {
        ForEach([Currency.usd, Currency.eur], id: \.rawValue) { currency in
          Button {
            editingFXCurrency = currency
            showFXEditor = true
          } label: {
            HStack {
              Text(currency.displayName)
                .font(.system(size: 14))
                .foregroundColor(.primary)

              Spacer()

              let currentRate = FXRateStore.shared.rateToUAH(for: currency)
              Text("\(String(format: "%.2f", currentRate)) \(Currency.uah.displayName)")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

              if FXRateStore.shared.isManual(currency: currency) {
                Text(Localization.string(.manual))
                  .font(.system(size: 11, weight: .bold))
                  .foregroundColor(.orange)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(Color.orange.opacity(0.16))
                  .clipShape(Capsule())
              }

              Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)

          if currency != .eur {
            Divider().padding(.leading, 16)
          }
        }
      }
      .background(Color.secondaryFill)
      .clipShape(RoundedRectangle(cornerRadius: 12))

      if let updatedAt = FXRateStore.shared.lastUpdatedAt() {
        Text(
          Localization.string(
            .fxLastUpdated(updatedAt.formatted(date: .abbreviated, time: .shortened))))
        .font(.system(size: 12))
        .foregroundColor(.secondary)
      }
    }
  }

  private var holidaySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(Localization.string(.holidays))
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.secondary)

      VStack(spacing: 0) {
        // API Key
        VStack(alignment: .leading, spacing: 6) {
          Text(Localization.string(.holidayApiKey))
            .font(.system(size: 14))
            .padding(.horizontal, 16)
            .padding(.top, 12)

          SecureField(Localization.string(.holidayApiKeyPlaceholder), text: $holidayApiKey)
            .font(.system(size: 14))
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }

        Divider().padding(.leading, 16)

        // Country
        Button(action: { showCountryPicker = true }) {
          HStack {
            Text(Localization.string(.holidayCountry))
              .font(.system(size: 14))
              .foregroundColor(.primary)
            Spacer()
            Text(
              holidayCountryName.isEmpty ? Localization.string(.holidayNone) : holidayCountryName
            )
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            Image(systemName: "chevron.right")
              .font(.system(size: 12, weight: .semibold))
              .foregroundColor(.secondary)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        Divider().padding(.leading, 16)

        // Language (read-only)
        SettingsRow(
          title: Localization.string(.holidayLanguage),
          value: holidayLanguageName.isEmpty ? "—" : holidayLanguageName
        )

        Divider().padding(.leading, 16)

        // Sync Now
        HStack {
          Button(action: syncHolidays) {
            HStack(spacing: 6) {
              if isSyncing {
                ProgressView()
                  .scaleEffect(0.8)
              }
              Text(
                isSyncing
                  ? Localization.string(.holidaySyncing) : Localization.string(.holidaySyncNow)
              )
              .font(.system(size: 14, weight: .medium))
            }
          }
          .disabled(isSyncing || holidayApiKey.isEmpty || holidayCountryCode.isEmpty)
          .buttonStyle(.plain)
          .foregroundColor(
            (isSyncing || holidayApiKey.isEmpty || holidayCountryCode.isEmpty)
              ? .secondary : .accentColor
          )

          Spacer()

          if let syncMessage = syncMessage {
            Text(syncMessage)
              .font(.system(size: 12))
              .foregroundColor(
                syncMessage == Localization.string(.holidaySyncSuccess) ? .green : .red)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        Divider().padding(.leading, 16)

        // Last Sync
        SettingsRow(
          title: Localization.string(.holidayLastSync),
          value: lastSyncDateFormatted
        )
      }
      .background(Color.secondaryFill)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }


  private func syncHolidays() {
    isSyncing = true
    syncMessage = nil
    Task {
      do {
        try await HolidayService.shared.syncHolidays(context: modelContext)
        await MainActor.run {
          isSyncing = false
          syncMessage = Localization.string(.holidaySyncSuccess)
        }
      } catch {
        await MainActor.run {
          isSyncing = false
          syncMessage = error.localizedDescription
        }
      }
    }
  }

  // MARK: - Build Info

  private var buildInfoSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(Localization.string(.appInfo))
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.secondary)

      VStack(spacing: 0) {
        SettingsRow(title: Localization.string(.version), value: appVersion)
        Divider().padding(.leading, 16)
        SettingsRow(title: Localization.string(.build), value: buildNumber)
        Divider().padding(.leading, 16)
        SettingsRow(title: Localization.string(.mode), value: buildMode)
      }
      .background(Color.secondaryFill)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  // MARK: - Debug

  #if DEBUG
    private var debugSection: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text(Localization.string(.debugSettings))
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.secondary)

        VStack(spacing: 0) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Theme Override")
              .font(.system(size: 14))
              .padding(.horizontal, 16)
              .padding(.top, 12)

            Picker("", selection: $debugSettings.themeOverride) {
              ForEach(DebugSettings.ThemeOverride.allCases) { theme in
                Text(theme.rawValue).tag(theme)
              }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
          }

          Divider().padding(.leading, 16)

          Toggle(isOn: $debugSettings.showBorders) {
            Text("Show Borders")
              .font(.system(size: 14))
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)

          Divider().padding(.leading, 16)

          Toggle(isOn: $debugSettings.mockDates) {
            Text("Mock Dates")
              .font(.system(size: 14))
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
        .background(Color.secondaryFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
    }
  #endif
}

private struct FXRateEditorSheet: View {
  let currency: Currency
  let onClose: () -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  @State private var manualEnabled = false
  @State private var rateText = ""

  var body: some View {
    NavigationStack {
      Form {
        Toggle(Localization.string(.fxManualOverride), isOn: $manualEnabled)

        TextField(Localization.string(.fxRateToUAH), text: $rateText)
          .keyboardType(.decimalPad)
          .disabled(!manualEnabled)
      }
      .navigationTitle("\(currency.displayName) \(Localization.string(.fxRate))")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(Localization.string(.cancel)) {
            close()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(Localization.string(.save)) {
            save()
          }
        }
      }
      .onAppear {
        manualEnabled = FXRateStore.shared.isManual(currency: currency)
        rateText = String(format: "%.4f", FXRateStore.shared.rateToUAH(for: currency))
      }
    }
  }

  private func save() {
    do {
      if manualEnabled {
        let normalized = rateText.replacingOccurrences(of: ",", with: ".")
        let rate = Double(normalized) ?? 0
        guard rate > 0 else { return }
        try FXRateService.shared.setManualRate(currency: currency, rateToUAH: rate, context: modelContext)
      } else {
        try FXRateService.shared.clearManualRate(currency: currency, context: modelContext)
      }
      close()
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
  }

  private func close() {
    onClose()
    dismiss()
  }
}

struct SettingsRow: View {
  let title: String
  let value: String

  var body: some View {
    HStack {
      Text(title)
        .font(.system(size: 14))
      Spacer()
      Text(value)
        .font(.system(size: 14))
        .foregroundColor(.secondary)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}
