import SwiftData
import SwiftUI
import UniformTypeIdentifiers

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
  @Query(sort: \NotificationPreferences.updatedAt, order: .reverse) private var notificationPrefs:
    [NotificationPreferences]
  @Query(sort: \OnboardingState.lastUpdatedAt, order: .reverse) private var onboardingStates:
    [OnboardingState]
  @Query(sort: \BillItem.updatedAt, order: .reverse) private var bills: [BillItem]
  @Query(sort: \RecurringExpenseTemplate.updatedAt, order: .reverse) private var templates:
    [RecurringExpenseTemplate]
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
  @State private var notificationTodo = true
  @State private var notificationEvent = true
  @State private var notificationBudget = true
  @State private var notificationSubscription = true
  @State private var notificationBill = true
  @State private var notificationCashflow = true
  @State private var notificationTimer = true
  @State private var notificationAlarm = true
  @State private var quietHoursEnabled = false
  @State private var quietStartHour = 22
  @State private var quietEndHour = 8
  @State private var digestEnabled = false
  @State private var digestHour = 9
  @State private var throttleMinutes = 5
  @State private var backupPassphrase = ""
  @State private var backupStatusMessage: String?
  @State private var showBackupExporter = false
  @State private var showBackupImporter = false
  @State private var backupDocument: BackupFileDocument?
  @State private var calendarExportDocument: CalendarExportDocument?
  @State private var showCalendarExporter = false

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
          onboardingSection
        }

        Section {
          notificationsSection
        }

        Section {
          shortcutsSection
        }

        Section {
          fxSection
        }

        Section {
          backupAndExportSection
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
    .fileExporter(
      isPresented: $showBackupExporter,
      document: backupDocument,
      contentType: .data,
      defaultFilename: "\(Constants.Backup.defaultFilenamePrefix)-\(Date().formatted(date: .numeric, time: .omitted))"
    ) { result in
      switch result {
      case .success:
        backupStatusMessage = "Backup exported"
      case .failure(let error):
        backupStatusMessage = error.localizedDescription
      }
    }
    .fileExporter(
      isPresented: $showCalendarExporter,
      document: calendarExportDocument,
      contentType: .data,
      defaultFilename: "calendar-export-\(Date().formatted(date: .numeric, time: .omitted)).ics"
    ) { result in
      switch result {
      case .success:
        backupStatusMessage = "Calendar export created"
      case .failure(let error):
        backupStatusMessage = error.localizedDescription
      }
    }
    .fileImporter(
      isPresented: $showBackupImporter,
      allowedContentTypes: [.data],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        guard let url = urls.first else { return }
        importBackup(from: url)
      case .failure(let error):
        backupStatusMessage = error.localizedDescription
      }
    }
    .task {
      await FXRateService.shared.refreshRatesIfNeeded(context: modelContext)
      preloadStoredMonobankToken()
      normalizeMonobankConnections()
      syncMonobankSettingsStateFromModel()
      loadNotificationPreferences()
    }
    .onChange(of: monobankConnections.count) { _, _ in
      syncMonobankSettingsStateFromModel()
    }
    .onChange(of: notificationPrefs.count) { _, _ in
      loadNotificationPreferences()
    }
  }

  private var onboardingSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Onboarding")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.secondary)

      VStack(spacing: 0) {
        SettingsRow(
          title: "Status",
          value: (onboardingStates.first?.hasCompleted ?? false) ? "Completed" : "Not completed"
        )
        Divider().padding(.leading, 16)
        Button("Run onboarding again") {
          let defaults = UserDefaults(suiteName: Constants.Storage.appGroupIdentifier) ?? .standard
          defaults.set(true, forKey: Constants.Onboarding.forceRunFlagKey)
          isPresented = false
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .buttonStyle(.plain)
      }
      .background(Color.secondaryFill)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  private var notificationsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Notifications")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.secondary)

      VStack(spacing: 0) {
        Toggle("Todos", isOn: $notificationTodo).padding(.horizontal, 16).padding(.vertical, 10)
          .onChange(of: notificationTodo) { _, _ in saveNotificationPreferences() }
        Divider().padding(.leading, 16)
        Toggle("Events", isOn: $notificationEvent).padding(.horizontal, 16).padding(.vertical, 10)
          .onChange(of: notificationEvent) { _, _ in saveNotificationPreferences() }
        Divider().padding(.leading, 16)
        Toggle("Budget alerts", isOn: $notificationBudget).padding(.horizontal, 16).padding(.vertical, 10)
          .onChange(of: notificationBudget) { _, _ in saveNotificationPreferences() }
        Divider().padding(.leading, 16)
        Toggle("Subscriptions", isOn: $notificationSubscription).padding(.horizontal, 16).padding(.vertical, 10)
          .onChange(of: notificationSubscription) { _, _ in saveNotificationPreferences() }
        Divider().padding(.leading, 16)
        Toggle("Bills", isOn: $notificationBill).padding(.horizontal, 16).padding(.vertical, 10)
          .onChange(of: notificationBill) { _, _ in saveNotificationPreferences() }
        Divider().padding(.leading, 16)
        Toggle("Cashflow", isOn: $notificationCashflow).padding(.horizontal, 16).padding(.vertical, 10)
          .onChange(of: notificationCashflow) { _, _ in saveNotificationPreferences() }
        Divider().padding(.leading, 16)
        Toggle("Timer", isOn: $notificationTimer).padding(.horizontal, 16).padding(.vertical, 10)
          .onChange(of: notificationTimer) { _, _ in saveNotificationPreferences() }
        Divider().padding(.leading, 16)
        Toggle("Alarm", isOn: $notificationAlarm).padding(.horizontal, 16).padding(.vertical, 10)
          .onChange(of: notificationAlarm) { _, _ in saveNotificationPreferences() }
        Divider().padding(.leading, 16)
        Toggle("Quiet hours", isOn: $quietHoursEnabled).padding(.horizontal, 16).padding(.vertical, 10)
          .onChange(of: quietHoursEnabled) { _, _ in saveNotificationPreferences() }

        if quietHoursEnabled {
          Divider().padding(.leading, 16)
          HStack {
            Text("Quiet from")
            Spacer()
            Picker("Start", selection: $quietStartHour) {
              ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour)).tag(hour)
              }
            }
            .pickerStyle(.menu)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .onChange(of: quietStartHour) { _, _ in saveNotificationPreferences() }

          Divider().padding(.leading, 16)
          HStack {
            Text("Quiet until")
            Spacer()
            Picker("End", selection: $quietEndHour) {
              ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour)).tag(hour)
              }
            }
            .pickerStyle(.menu)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .onChange(of: quietEndHour) { _, _ in saveNotificationPreferences() }
        }

        Divider().padding(.leading, 16)
        Toggle("Daily digest", isOn: $digestEnabled).padding(.horizontal, 16).padding(.vertical, 10)
          .onChange(of: digestEnabled) { _, _ in saveNotificationPreferences() }

        if digestEnabled {
          Divider().padding(.leading, 16)
          HStack {
            Text("Digest hour")
            Spacer()
            Picker("Digest hour", selection: $digestHour) {
              ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour)).tag(hour)
              }
            }
            .pickerStyle(.menu)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .onChange(of: digestHour) { _, _ in saveNotificationPreferences() }
        }

        Divider().padding(.leading, 16)
        HStack {
          Text("Throttle (minutes)")
          Spacer()
          Stepper(value: $throttleMinutes, in: 1...60) {
            Text("\(throttleMinutes)")
              .foregroundColor(.secondary)
          }
          .fixedSize()
          .onChange(of: throttleMinutes) { _, _ in saveNotificationPreferences() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
      }
      .background(Color.secondaryFill)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  private var shortcutsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Shortcuts & Siri")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.secondary)

      VStack(alignment: .leading, spacing: 8) {
        Text("Available commands:")
          .font(.system(size: 13, weight: .semibold))
        Text("• Add expense in Calendar")
        Text("• Add todo in Calendar")
        Text("• Start timer in Calendar")
        Text("• Open tab in Calendar")
        Text("• Quick capture in Calendar")
      }
      .font(.system(size: 12))
      .foregroundColor(.secondary)
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.secondaryFill)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  private var backupAndExportSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Backup & Export")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.secondary)

      VStack(spacing: 10) {
        SecureField("Passphrase", text: $backupPassphrase)
          .textFieldStyle(.roundedBorder)
          .padding(.horizontal, 16)
          .padding(.top, 12)

        HStack {
          Button("Export encrypted backup") {
            exportEncryptedBackup()
          }
          .disabled(backupPassphrase.count < 6)
          .buttonStyle(.plain)

          Spacer()

          Button("Import backup") {
            showBackupImporter = true
          }
          .disabled(backupPassphrase.count < 6)
          .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)

        Divider().padding(.leading, 16)

        HStack {
          Button("Export Calendar (.ics)") {
            exportCalendarICS()
          }
          .buttonStyle(.plain)
          Spacer()
          Text("\(templates.count) templates • \(bills.count) bills")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)

        if let backupStatusMessage {
          Divider().padding(.leading, 16)
          Text(backupStatusMessage)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
      }
      .background(Color.secondaryFill)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  private func loadNotificationPreferences() {
    let prefs = NotificationPreferencesService.shared.current(context: modelContext)
    notificationTodo = prefs.todoEnabled
    notificationEvent = prefs.eventEnabled
    notificationBudget = prefs.budgetEnabled
    notificationSubscription = prefs.subscriptionEnabled
    notificationBill = prefs.billEnabled
    notificationCashflow = prefs.cashflowEnabled
    notificationTimer = prefs.timerEnabled
    notificationAlarm = prefs.alarmEnabled
    quietHoursEnabled = prefs.quietHoursEnabled
    quietStartHour = prefs.quietStartHour
    quietEndHour = prefs.quietEndHour
    digestEnabled = prefs.digestEnabled
    digestHour = prefs.digestHour
    throttleMinutes = prefs.throttleMinutes
  }

  private func saveNotificationPreferences() {
    let prefs = NotificationPreferencesService.shared.current(context: modelContext)
    prefs.todoEnabled = notificationTodo
    prefs.eventEnabled = notificationEvent
    prefs.budgetEnabled = notificationBudget
    prefs.subscriptionEnabled = notificationSubscription
    prefs.billEnabled = notificationBill
    prefs.cashflowEnabled = notificationCashflow
    prefs.timerEnabled = notificationTimer
    prefs.alarmEnabled = notificationAlarm
    prefs.quietHoursEnabled = quietHoursEnabled
    prefs.quietStartHour = quietStartHour
    prefs.quietEndHour = quietEndHour
    prefs.digestEnabled = digestEnabled
    prefs.digestHour = digestHour
    prefs.throttleMinutes = throttleMinutes
    prefs.updatedAt = Date()

    do {
      try modelContext.save()
      NotificationPreferencesService.shared.syncToDefaults(prefs)
    } catch {
      ErrorPresenter.shared.present(error)
    }
  }

  private func exportEncryptedBackup() {
    do {
      let payload = try BackupRestoreService.shared.createBackup(
        context: modelContext,
        passphrase: backupPassphrase
      )
      backupDocument = BackupFileDocument(data: payload)
      showBackupExporter = true
    } catch {
      backupStatusMessage = error.localizedDescription
    }
  }

  private func importBackup(from url: URL) {
    do {
      guard url.startAccessingSecurityScopedResource() else {
        backupStatusMessage = "Cannot access selected file."
        return
      }
      defer { url.stopAccessingSecurityScopedResource() }
      let data = try Data(contentsOf: url)
      try BackupRestoreService.shared.restoreBackup(
        data,
        context: modelContext,
        passphrase: backupPassphrase
      )
      backupStatusMessage = "Backup restored"
    } catch {
      backupStatusMessage = error.localizedDescription
    }
  }

  private func exportCalendarICS() {
    let data = CalendarExportService.shared.exportRecurringExpensesAndBills(
      templates: templates,
      bills: bills,
      from: Date(),
      days: 180
    )
    calendarExportDocument = CalendarExportDocument(data: data)
    showCalendarExporter = true
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

private struct BackupFileDocument: FileDocument {
  static var readableContentTypes: [UTType] = [.data]
  static var writableContentTypes: [UTType] = [.data]

  var data: Data

  init(data: Data = Data()) {
    self.data = data
  }

  init(configuration: ReadConfiguration) throws {
    data = configuration.file.regularFileContents ?? Data()
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}

private struct CalendarExportDocument: FileDocument {
  static var readableContentTypes: [UTType] = [.data]
  static var writableContentTypes: [UTType] = [.data]

  var data: Data

  init(data: Data = Data()) {
    self.data = data
  }

  init(configuration: ReadConfiguration) throws {
    data = configuration.file.regularFileContents ?? Data()
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}
