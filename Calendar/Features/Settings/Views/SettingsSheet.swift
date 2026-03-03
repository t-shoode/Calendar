import SwiftData
import SwiftUI

struct SettingsSheet: View {
  @Binding var isPresented: Bool
  @EnvironmentObject var appState: AppState
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \MonobankConnection.updatedAt, order: .reverse) private var monobankConnections:
    [MonobankConnection]
  @Query(sort: \MonobankAccount.updatedAt, order: .reverse) private var monobankAccounts:
    [MonobankAccount]
  @Query(
    filter: #Predicate<MonobankConflict> { $0.status == "pending" },
    sort: \MonobankConflict.createdAt,
    order: .reverse
  ) private var pendingMonobankConflicts: [MonobankConflict]
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
  @State private var monobankToken: String = ""
  @State private var monobankIsSyncing = false
  @State private var monobankMessage: String?
  @State private var monobankConsentValue = false
  @State private var monobankRangePresetValue = "30d"
  @State private var monobankCustomFromDate = Date().addingTimeInterval(-30 * 24 * 3600)
  @State private var monobankCustomToDate = Date()
  @State private var showDisconnectDialog = false
  @State private var showCountryPicker = false
  @State private var editingFXCurrency: Currency = .usd
  @State private var showFXEditor = false

  private var monobankConnection: MonobankConnection? {
    monobankConnections.first
  }

  private var sanitizedMonobankToken: String {
    monobankToken.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var monobankLastSyncFormatted: String {
    guard let date = monobankConnection?.lastSyncAt else {
      return Localization.string(.monobankNever)
    }
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  private var monobankStatusText: String {
    if monobankConnection?.lastSyncStatus == "unauthorized" {
      return Localization.string(.monobankUnauthorized)
    }
    if monobankConnection?.lastSyncStatus == "error" {
      return Localization.string(.monobankSyncError)
    }
    return (monobankConnection?.isConnected ?? false)
      ? Localization.string(.monobankConnected) : Localization.string(.monobankDisconnected)
  }

  private var monobankTokenStateText: String {
    let storedToken = (try? MonobankKeychainStore.shared.loadToken()) ?? nil
    guard let storedToken, !storedToken.isEmpty else {
      return Localization.string(.monobankTokenMissing)
    }
    return Localization.string(.monobankTokenPresent)
  }

  private var monobankAuthorizationStateText: String {
    if monobankConnection?.lastSyncStatus == "unauthorized" {
      return Localization.string(.monobankUnauthorized)
    }
    return (monobankConnection?.isConnected ?? false)
      ? Localization.string(.monobankConnected) : Localization.string(.monobankDisconnected)
  }

  private var monobankLastErrorText: String {
    guard
      let message = monobankConnection?.lastSyncErrorMessage?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !message.isEmpty
    else {
      return Localization.string(.monobankNoErrors)
    }

    if let date = monobankConnection?.lastSyncErrorAt {
      let formatter = DateFormatter()
      formatter.dateStyle = .short
      formatter.timeStyle = .short
      return "\(formatter.string(from: date)): \(message)"
    }

    return message
  }

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
          monobankSection
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
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .background(Color.clear)
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
      preloadStoredMonobankToken()
      normalizeMonobankConnections()
      syncMonobankSettingsStateFromModel()
    }
    .onChange(of: monobankConnections.count) { _, _ in
      syncMonobankSettingsStateFromModel()
    }
  }

  private var monobankSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(Localization.string(.monobankTitle))
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.secondary)

      VStack(spacing: 0) {
        Toggle(
          Localization.string(.monobankConsent),
          isOn: $monobankConsentValue
        )
        .onChange(of: monobankConsentValue) { _, newValue in
          setMonobankConsent(newValue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        Divider().padding(.leading, 16)

        VStack(alignment: .leading, spacing: 6) {
          Text(Localization.string(.monobankPersonalToken))
            .font(.system(size: 14))
            .padding(.horizontal, 16)
            .padding(.top, 12)

          SecureField(Localization.string(.monobankPasteToken), text: $monobankToken)
            .font(.system(size: 14))
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }

        Divider().padding(.leading, 16)

        HStack {
          Button(
            monobankConnection?.isConnected == true
              ? Localization.string(.monobankReconnect) : Localization.string(.monobankConnect)
          ) {
            connectMonobank()
          }
          .buttonStyle(.plain)
          .disabled(
            (monobankConnection?.hasConsent ?? false) == false || sanitizedMonobankToken.isEmpty)

          Spacer()

          Button(
            monobankIsSyncing
              ? Localization.string(.monobankSyncing) : Localization.string(.monobankSyncNow)
          ) {
            syncMonobank()
          }
          .buttonStyle(.plain)
          .disabled((monobankConnection?.isConnected ?? false) == false || monobankIsSyncing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        Divider().padding(.leading, 16)

        VStack(alignment: .leading, spacing: 8) {
          Text(Localization.string(.monobankImportRange))
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 10)

          Picker(
            Localization.string(.monobankImportRange),
            selection: $monobankRangePresetValue
          ) {
            Text(Localization.string(.monobankRange30Days)).tag("30d")
            Text(Localization.string(.monobankRange90Days)).tag("90d")
            Text(Localization.string(.monobankRange365Days)).tag("365d")
            Text(Localization.string(.monobankRangeCustom)).tag("custom")
          }
          .onChange(of: monobankRangePresetValue) { _, newValue in
            updateMonobankRangePreset(newValue)
          }
          .pickerStyle(.segmented)
          .padding(.horizontal, 16)

          if monobankRangePresetValue == "custom" {
            DatePicker(
              Localization.string(.monobankFrom),
              selection: $monobankCustomFromDate,
              displayedComponents: .date
            )
            .onChange(of: monobankCustomFromDate) { _, newValue in
              updateMonobankCustomDate(from: newValue, to: monobankCustomToDate)
            }
            .padding(.horizontal, 16)

            DatePicker(
              Localization.string(.monobankTo),
              selection: $monobankCustomToDate,
              displayedComponents: .date
            )
            .onChange(of: monobankCustomToDate) { _, newValue in
              updateMonobankCustomDate(from: monobankCustomFromDate, to: newValue)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
          }
        }

        if !monobankAccounts.isEmpty {
          Divider().padding(.leading, 16)

          VStack(alignment: .leading, spacing: 8) {
            Text(Localization.string(.monobankSyncAccounts))
              .font(.system(size: 12, weight: .semibold))
              .foregroundColor(.secondary)
              .padding(.horizontal, 16)
              .padding(.top, 10)

            ForEach(monobankAccounts, id: \.id) { account in
              Toggle(
                isOn: Binding(
                  get: { account.isSelected },
                  set: { newValue in
                    account.isSelected = newValue
                    updateSelectedMonobankAccounts()
                  }
                )
              ) {
                HStack(spacing: 6) {
                  Text("\(account.accountId) (\(currencyLabel(for: account.currencyCode)))")
                    .lineLimit(1)

                  if account.isPinned {
                    Image(systemName: "pin.fill")
                      .font(.system(size: 10, weight: .semibold))
                      .foregroundColor(.appAccent)
                  }
                }
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 4)
            }

            Spacer(minLength: 2)
          }
          .padding(.bottom, 8)
        }

        Divider().padding(.leading, 16)

        SettingsRow(
          title: Localization.string(.monobankStatus),
          value: monobankStatusText)
        Divider().padding(.leading, 16)
        SettingsRow(
          title: Localization.string(.monobankTokenState),
          value: monobankTokenStateText
        )
        Divider().padding(.leading, 16)
        SettingsRow(
          title: Localization.string(.monobankAuthorizationState),
          value: monobankAuthorizationStateText
        )
        Divider().padding(.leading, 16)
        SettingsRow(title: Localization.string(.monobankLastSync), value: monobankLastSyncFormatted)
        Divider().padding(.leading, 16)
        SettingsRow(
          title: Localization.string(.monobankPendingConflicts),
          value: "\(pendingMonobankConflicts.count)"
        )
        Divider().padding(.leading, 16)
        SettingsRow(
          title: Localization.string(.monobankLastError),
          value: monobankLastErrorText
        )

        if let monobankMessage {
          Divider().padding(.leading, 16)
          Text(monobankMessage)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }

        if monobankConnection?.isConnected == true {
          Divider().padding(.leading, 16)
          Button(Localization.string(.monobankDisconnect), role: .destructive) {
            showDisconnectDialog = true
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
      }
      .background(Color.secondaryFill)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .confirmationDialog(
      Localization.string(.monobankDisconnectTitle), isPresented: $showDisconnectDialog
    ) {
      Button(Localization.string(.monobankDisconnectKeepImported), role: .destructive) {
        disconnectMonobank(hardDeleteImportedExpenses: false)
      }
      Button(Localization.string(.monobankDisconnectDeleteImported), role: .destructive) {
        disconnectMonobank(hardDeleteImportedExpenses: true)
      }
      Button(Localization.string(.cancel), role: .cancel) {}
    } message: {
      Text(Localization.string(.monobankDisconnectPrompt))
    }
  }

  private func connectMonobank() {
    monobankIsSyncing = true
    monobankMessage = nil
    let token = sanitizedMonobankToken

    Task {
      do {
        try MonobankSyncService.shared.saveToken(token, context: modelContext)
        _ = try await MonobankSyncService.shared.sync(context: modelContext, token: token)
        await MainActor.run {
          monobankIsSyncing = false
          monobankMessage = Localization.string(.monobankConnectedAndSynced)
        }
      } catch {
        await MainActor.run {
          monobankIsSyncing = false
          if let syncError = error as? MonobankSyncError, syncError == .unauthorized {
            monobankMessage = Localization.string(.monobankUnauthorized)
          } else {
            monobankMessage = error.localizedDescription
          }
        }
      }
    }
  }

  private func syncMonobank() {
    monobankIsSyncing = true
    monobankMessage = nil

    Task {
      do {
        let summary = try await MonobankSyncService.shared.sync(context: modelContext)
        await MainActor.run {
          monobankIsSyncing = false
          monobankMessage = Localization.string(
            .monobankSyncSummary(summary.imported, summary.updated, summary.conflicts))
        }
      } catch {
        await MainActor.run {
          monobankIsSyncing = false
          if let syncError = error as? MonobankSyncError, syncError == .unauthorized {
            monobankMessage = Localization.string(.monobankUnauthorized)
          } else {
            monobankMessage = error.localizedDescription
          }
        }
      }
    }
  }

  private func disconnectMonobank(hardDeleteImportedExpenses: Bool) {
    do {
      try MonobankSyncService.shared.disconnect(
        context: modelContext,
        hardDeleteImportedExpenses: hardDeleteImportedExpenses
      )
      monobankMessage = Localization.string(.monobankDisconnectedMessage)
    } catch {
      monobankMessage = error.localizedDescription
    }
  }

  private func preloadStoredMonobankToken() {
    guard monobankToken.isEmpty else { return }
    let storedToken = (try? MonobankKeychainStore.shared.loadToken()) ?? nil
    if let storedToken, !storedToken.isEmpty {
      monobankToken = storedToken
    }
  }

  private func updateSelectedMonobankAccounts() {
    let connection = getOrCreateMonobankConnectionForWrite()
    for account in monobankAccounts where !account.isSelected {
      account.isPinned = false
    }
    connection.selectedAccountIds = monobankAccounts.filter { $0.isSelected }.map { $0.accountId }
    connection.updatedAt = Date()
    do {
      try modelContext.save()
      try MonobankSyncService.shared.syncSelectedBalancesToWidget(context: modelContext)
    } catch {
      ErrorPresenter.shared.present(error)
    }
  }

  private func updateMonobankRangePreset(_ preset: String) {
    let connection = getOrCreateMonobankConnectionForWrite()
    connection.rangePreset = preset
    connection.updatedAt = Date()
    if preset != "custom" {
      connection.customFromDate = nil
      connection.customToDate = nil
    }
    do {
      try modelContext.save()
    } catch {
      ErrorPresenter.shared.present(error)
    }
  }

  private func updateMonobankCustomDate(from: Date?, to: Date?) {
    let connection = getOrCreateMonobankConnectionForWrite()
    connection.customFromDate = from
    connection.customToDate = to
    connection.rangePreset = "custom"
    connection.updatedAt = Date()
    do {
      try modelContext.save()
    } catch {
      ErrorPresenter.shared.present(error)
    }
  }

  private func currencyLabel(for code: Int) -> String {
    switch code {
    case 840: return "USD"
    case 978: return "EUR"
    case 980: return "UAH"
    default: return "\(code)"
    }
  }

  private func setMonobankConsent(_ enabled: Bool) {
    let connection = getOrCreateMonobankConnectionForWrite()
    guard connection.hasConsent != enabled else { return }
    connection.hasConsent = enabled
    connection.updatedAt = Date()
    do {
      try modelContext.save()
    } catch {
      ErrorPresenter.shared.present(error)
    }
  }

  private func normalizeMonobankConnections() {
    let descriptor = FetchDescriptor<MonobankConnection>(
      sortBy: [SortDescriptor(\MonobankConnection.updatedAt, order: .reverse)]
    )
    guard let all = try? modelContext.fetch(descriptor), all.count > 1 else { return }
    for duplicate in all.dropFirst() {
      modelContext.delete(duplicate)
    }
    do {
      try modelContext.save()
    } catch {
      ErrorPresenter.shared.present(error)
    }
  }

  private func getOrCreateMonobankConnectionForWrite() -> MonobankConnection {
    let descriptor = FetchDescriptor<MonobankConnection>(
      sortBy: [SortDescriptor(\MonobankConnection.updatedAt, order: .reverse)]
    )
    if let existing = try? modelContext.fetch(descriptor).first {
      return existing
    }

    let connection = MonobankConnection()
    modelContext.insert(connection)
    return connection
  }

  private func syncMonobankSettingsStateFromModel() {
    let descriptor = FetchDescriptor<MonobankConnection>(
      sortBy: [SortDescriptor(\MonobankConnection.updatedAt, order: .reverse)]
    )
    guard let connection = try? modelContext.fetch(descriptor).first else {
      monobankConsentValue = false
      monobankRangePresetValue = "30d"
      monobankCustomFromDate = Date().addingTimeInterval(-30 * 24 * 3600)
      monobankCustomToDate = Date()
      return
    }

    monobankConsentValue = connection.hasConsent
    monobankRangePresetValue = connection.rangePreset.isEmpty ? "30d" : connection.rangePreset
    monobankCustomFromDate = connection.customFromDate ?? Date().addingTimeInterval(-30 * 24 * 3600)
    monobankCustomToDate = connection.customToDate ?? Date()
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
            .fxLastUpdated(updatedAt.formatted(date: .abbreviated, time: .shortened)))
        )
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
              ? .secondary : .appAccent
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
        try FXRateService.shared.setManualRate(
          currency: currency, rateToUAH: rate, context: modelContext)
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
        .font(Typography.subheadline)
      Spacer()
      Text(value)
        .font(Typography.subheadline)
        .foregroundColor(.secondary)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}
