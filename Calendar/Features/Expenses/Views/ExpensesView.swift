import SwiftData
import SwiftUI
#if os(iOS)
  import UIKit
#endif

struct ExpensesView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Expense.date) private var expenses: [Expense]
  @Query(sort: \MonobankConnection.updatedAt, order: .reverse) private var monobankConnections:
    [MonobankConnection]
  @Query(sort: \MonobankAccount.updatedAt, order: .reverse) private var monobankAccounts:
    [MonobankAccount]
  @Query(sort: \MonobankStatementItem.transactionTime, order: .reverse)
  private var monobankStatementItems: [MonobankStatementItem]
  @Query(sort: \RecurringExpenseTemplate.createdAt) private var templates:
    [RecurringExpenseTemplate]
  @Query(
    filter: #Predicate<DuplicateSuggestion> { $0.status == "pending" },
    sort: \DuplicateSuggestion.createdAt,
    order: .reverse
  ) private var pendingDuplicateSuggestions: [DuplicateSuggestion]
  @Query(
    filter: #Predicate<MonobankConflict> { $0.status == "pending" },
    sort: \MonobankConflict.createdAt,
    order: .reverse
  ) private var pendingMonobankConflicts: [MonobankConflict]

  @State private var selectedSegment: ExpenseSegment = .bank
  @State private var showingAddExpense = false
  @State private var editingExpense: Expense? = nil
  @State private var showingCSVImport = false
  @State private var showingClearConfirmation = false
  @State private var showingAddTemplate = false
  @State private var showingSettings = false
  @State private var showingMonobankSheet = false
  @State private var monobankToken: String = ""
  @State private var monobankIsSyncing = false
  @State private var monobankMessage: String?
  @State private var monobankRecurringSuggestions: [TemplateSuggestion] = []
  @State private var selectedRecurringSuggestionIds: Set<UUID> = []
  @State private var customSuggestionFrequencies: [UUID: ExpenseFrequency] = [:]
  @AppStorage("dismissedRecurringSuggestionSignatures")
  private var dismissedRecurringSuggestionSignaturesData: Data = Data()
  @State private var showingBudgetAddPicker = false
  @State private var selectedBankAccountId: String?

  private let patternDetectionService = PatternDetectionService()
  private let csvImportService = CSVImportService()

  private let viewModel = ExpenseViewModel()

  enum ExpenseSegment: String, CaseIterable {
    case bank = "Bank"
    case budget = "Budget"
    case forecast = "Forecast"
    case insights = "Insights"

    var displayName: String {
      switch self {
      case .bank: return Localization.string(.tabExpenses)
      case .budget: return Localization.string(.expenseBudget)
      case .forecast: return Localization.string(.forecast)
      case .insights: return Localization.string(.expenseInsights)
      }
    }
  }

  private var monobankConnection: MonobankConnection? {
    monobankConnections.first
  }

  private var selectedBankAccount: MonobankAccount? {
    guard let selectedBankAccountId else { return nil }
    return monobankAccounts.first(where: { $0.accountId == selectedBankAccountId })
  }

  private var selectedMonobankAccounts: [MonobankAccount] {
    monobankAccounts
      .filter { $0.isSelected }
      .sorted {
        if $0.isPinned != $1.isPinned {
          return $0.isPinned && !$1.isPinned
        }
        return $0.updatedAt > $1.updatedAt
      }
  }

  private var pinnedMonobankAccounts: [MonobankAccount] {
    selectedMonobankAccounts.filter { $0.isPinned }
  }

  private var trendAccounts: [MonobankAccount] {
    pinnedMonobankAccounts.isEmpty ? selectedMonobankAccounts : pinnedMonobankAccounts
  }

  private var pinnedBalanceSummaries: [String] {
    guard !pinnedMonobankAccounts.isEmpty else { return [] }

    var totalsByCurrency: [Int: Int64] = [:]
    for account in pinnedMonobankAccounts {
      totalsByCurrency[account.currencyCode, default: 0] += account.balanceMinor
    }

    return totalsByCurrency.keys.sorted().map { code in
      let totalMinor = totalsByCurrency[code, default: 0]
      let totalMajor = Double(totalMinor) / 100.0
      return "\(currencySymbol(for: code))\(String(format: "%.2f", totalMajor))"
    }
  }

  private var pinnedTrendSummaries: [String] {
    guard !trendAccounts.isEmpty else { return [] }

    let delta7 = aggregateBalanceDelta(daysBack: 7)
    let delta30 = aggregateBalanceDelta(daysBack: 30)

    return delta7.keys.sorted().map { code in
      let delta7Value = delta7[code, default: 0]
      let delta30Value = delta30[code, default: 0]
      return "7d \(formatSignedAmount(delta7Value, currencyCode: code)) • 30d \(formatSignedAmount(delta30Value, currencyCode: code))"
    }
  }

  private var sanitizedMonobankToken: String {
    monobankToken.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var filteredBankExpenses: [Expense] {
    filteredExpenses.filter { $0.externalSource == "monobank" }
  }

  private var filteredExpenses: [Expense] {
    expenses.sorted { $0.date > $1.date }
  }

  private var accentForeground: Color {
    colorScheme == .dark ? .backgroundPrimary : .white
  }

  var body: some View {
    VStack(spacing: 0) {
      // Header with Segment Picker
      VStack(spacing: 14) {
        HStack {
          Text(Localization.string(.tabExpenses))
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(.textPrimary)

          Spacer()

          HStack(spacing: 10) {
            Button {
              showingSettings = true
            } label: {
              Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.textSecondary)
            }
            .softControl(cornerRadius: 12, padding: 7)

            Button {
              showingAddTemplate = true
            } label: {
              Image(systemName: "repeat.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.appAccent)
            }
            .softControl(cornerRadius: 12, padding: 7)

            Menu {
              Button {
                showingMonobankSheet = true
              } label: {
                Label(Localization.string(.monobankTitle), systemImage: "building.columns")
              }

              Button {
                showingCSVImport = true
              } label: {
                Label(Localization.string(.importFromBank), systemImage: "arrow.down.doc")
              }

              Button(role: .destructive) {
                showingClearConfirmation = true
              } label: {
                Label(Localization.string(.clearAll), systemImage: "trash")
              }
            } label: {
              Image(systemName: "ellipsis.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.appAccent)
            }
            .softControl(cornerRadius: 12, padding: 7)
          }
        }

        // Segment Picker
        HStack(spacing: 0) {
          ForEach(ExpenseSegment.allCases, id: \.self) { segment in
            Button {
              withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedSegment = segment
              }
            } label: {
              Text(segment.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selectedSegment == segment ? accentForeground : .textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(selectedSegment == segment ? Color.appAccent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .buttonStyle(.plain)
          }
        }
        .padding(4)
        .softControl(cornerRadius: 14, padding: 4)

      }
      .padding(.horizontal, 20)
      .padding(.top, 4)
      .padding(.bottom, 10)

      // Content based on selected segment
      Group {
        switch selectedSegment {
        case .bank:
          HistoryView(
            expenses: filteredBankExpenses,
            allExpensesForLookup: filteredBankExpenses,
            duplicateSuggestions: pendingDuplicateSuggestions,
            monobankConflicts: pendingMonobankConflicts,
            bankHeader: AnyView(bankHeaderSection),
            recurringSuggestions: monobankRecurringSuggestions,
            selectedRecurringSuggestionIds: selectedRecurringSuggestionIds,
            customSuggestionFrequencies: customSuggestionFrequencies,
            viewModel: viewModel,
            onEdit: { expense in
              editingExpense = expense
              showingAddExpense = true
            },
            onMergeDuplicate: { suggestion in
              do {
                try DuplicateDetectionService.shared.mergeSuggestion(
                  suggestion, context: modelContext)
              } catch {
                ErrorPresenter.shared.present(error)
              }
            },
            onDismissDuplicate: { suggestion in
              do {
                try DuplicateDetectionService.shared.dismissSuggestion(
                  suggestion, context: modelContext)
              } catch {
                ErrorPresenter.shared.present(error)
              }
            },
            onKeepLocalConflict: { conflict in
              do {
                try MonobankSyncService.shared.resolveConflictKeepLocal(
                  conflict, context: modelContext)
              } catch {
                ErrorPresenter.shared.present(error)
              }
            },
            onUseServerConflict: { conflict in
              do {
                try MonobankSyncService.shared.resolveConflictUseServer(
                  conflict, context: modelContext)
                refreshMonobankRecurringSuggestions()
              } catch {
                ErrorPresenter.shared.present(error)
              }
            },
            onToggleSuggestion: { suggestionId in
              toggleRecurringSuggestion(suggestionId)
            },
            onSuggestionFrequencyChange: { suggestionId, frequency in
              customSuggestionFrequencies[suggestionId] = frequency
            },
            onCreateRecurringTemplates: {
              createRecurringTemplatesFromSuggestions()
            },
            onDismissRecurringSuggestion: { suggestion in
              dismissRecurringSuggestion(suggestion)
            }
          )
        case .budget:
          BudgetView(
            templates: templates,
            expenses: expenses,
            viewModel: viewModel
          )
        case .forecast:
          ForecastView(
            expenses: expenses,
            templates: templates
          )
        case .insights:
          InsightsView(
            expenses: expenses,
            viewModel: viewModel
          )
        }
      }
    }
    .overlay(alignment: .bottomTrailing) {
      if selectedSegment == .budget {
        Button(action: {
          showingBudgetAddPicker = true
        }) {
          Image(systemName: "plus")
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(accentForeground)
            .frame(width: 52, height: 52)
            .background(Color.appAccent)
            .clipShape(Circle())
            .shadow(color: Color.appAccent.opacity(0.25), radius: 10, x: 0, y: 5)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
      }
    }
    .sheet(isPresented: $showingAddExpense) {
      AddExpenseSheet(
        expense: editingExpense,
        onSave: {
          title, amount, date, category, paymentMethod, currency, merchant, notes, isIncome in
          do {
            if let expense = editingExpense {
              try viewModel.updateExpense(
                expense, title: title, amount: amount, date: date, category: category,
                paymentMethod: paymentMethod, currency: currency, merchant: merchant, notes: notes,
                isIncome: isIncome,
                context: modelContext)
            } else {
              try viewModel.addExpense(
                title: title, amount: amount, date: date, category: category,
                paymentMethod: paymentMethod, currency: currency, merchant: merchant, notes: notes,
                isIncome: isIncome,
                context: modelContext)
            }
          } catch {
            ErrorPresenter.shared.present(error)
          }
        },
        onDelete: {
          if let expense = editingExpense {
            do {
              try viewModel.deleteExpense(expense, context: modelContext)
            } catch {
              ErrorPresenter.shared.present(error)
            }
          }
        }
      )
    }
    .sheet(isPresented: $showingCSVImport) {
      CSVImportView()
    }
    .sheet(isPresented: $showingMonobankSheet) {
      MonobankConnectionSheet(
        token: $monobankToken,
        isSyncing: $monobankIsSyncing,
        message: $monobankMessage,
        isConnected: monobankConnection?.isConnected ?? false,
        onConnect: connectMonobank,
        onSync: syncMonobank,
        onDisconnect: disconnectMonobank
      )
    }
    .sheet(isPresented: $showingAddTemplate) {
      AddTemplateSheet()
    }
    .sheet(isPresented: $showingSettings) {
      SettingsSheet(isPresented: $showingSettings)
    }
    .fullScreenCover(
      isPresented: Binding(
        get: { selectedBankAccountId != nil },
        set: { isPresented in
          if !isPresented {
            selectedBankAccountId = nil
          }
        }
      )
    ) {
      if let selectedBankAccount {
        BankCardDetailsSheet(
          account: selectedBankAccount,
          cardTitle: bankCardTitle(for: selectedBankAccount),
          cardNumber: bankCardNumber(for: selectedBankAccount),
          balance: bankCardBalance(for: selectedBankAccount),
          currencySymbol: currencySymbol(for: selectedBankAccount.currencyCode),
          subtitle: bankCardDateLabel(for: selectedBankAccount),
          theme: bankCardTheme(for: selectedBankAccount),
          statements: accountStatements(for: selectedBankAccount),
          onPinToggle: {
            togglePinnedAccount(selectedBankAccount)
          },
          onSyncNow: {
            syncMonobank()
          },
          onThemeSelected: { theme in
            setTheme(theme, for: selectedBankAccount)
          },
          onRemoveKeepImported: {
            removeBankCard(selectedBankAccount, deleteImportedExpenses: false)
          },
          onRemoveDeleteImported: {
            removeBankCard(selectedBankAccount, deleteImportedExpenses: true)
          }
        )
      } else {
        Color.backgroundPrimary
          .ignoresSafeArea()
          .overlay {
            ProgressView()
              .controlSize(.large)
          }
          .task {
            selectedBankAccountId = nil
          }
      }
    }
    .confirmationDialog(
      Localization.string(.clearAllDataPrompt),
      isPresented: $showingClearConfirmation,
      titleVisibility: .visible
    ) {
      Button(Localization.string(.clearAllExpensesConfirm), role: .destructive) {
        clearAllExpenses()
      }
      Button(Localization.string(.clearAllTemplatesConfirm), role: .destructive) {
        clearAllTemplates()
      }
      Button(Localization.string(.clearEverythingConfirm), role: .destructive) {
        clearAllExpenses()
        clearAllTemplates()
      }
      Button(Localization.string(.cancel), role: .cancel) {}
    } message: {
      Text(Localization.string(.cannotBeUndone))
    }
    .confirmationDialog(
      Localization.string(.expenseAdd),
      isPresented: $showingBudgetAddPicker,
      titleVisibility: .visible
    ) {
      Button(Localization.string(.expenseAdd)) {
        editingExpense = nil
        showingAddExpense = true
      }
      Button(Localization.string(.addRecurringExpense)) {
        showingAddTemplate = true
      }
      Button(Localization.string(.cancel), role: .cancel) {}
    }
    .onAppear {
      DuplicateDetectionService.shared.refreshSuggestions(context: modelContext)
      preloadStoredMonobankToken()
      refreshMonobankRecurringSuggestions()
    }
    .onChange(of: expenses.count) { _, _ in
      DuplicateDetectionService.shared.refreshSuggestions(context: modelContext)
      refreshMonobankRecurringSuggestions()
    }
    .onReceive(
      NotificationCenter.default.publisher(for: Constants.WidgetAction.quickAddExpenseNotification)
    ) { _ in
      editingExpense = nil
      showingAddExpense = true
    }
    .onReceive(
      NotificationCenter.default.publisher(for: Constants.WidgetAction.openPinnedBankCardNotification)
    ) { _ in
      let targetAccount = pinnedMonobankAccounts.first ?? selectedMonobankAccounts.first
      selectedBankAccountId = targetAccount?.accountId
    }
    .navigationBarHidden(true)
    .safeAreaPadding(.top, 4)
  }

  private func clearAllExpenses() {
    for expense in expenses {
      modelContext.delete(expense)
    }
    do {
      try modelContext.save()
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
  }

  private func clearAllTemplates() {
    for template in templates {
      modelContext.delete(template)
    }
    do {
      try modelContext.save()
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
  }

  private var bankHeaderSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(Localization.string(.monobankTitle))
          .font(.system(size: 18, weight: .bold))
          .foregroundColor(.textPrimary)

        Spacer()

        Label(
          (monobankConnection?.isConnected ?? false)
            ? Localization.string(.monobankConnected) : Localization.string(.monobankDisconnected),
          systemImage: (monobankConnection?.isConnected ?? false) ? "checkmark.circle.fill" : "xmark.circle"
        )
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor((monobankConnection?.isConnected ?? false) ? .green : .textSecondary)
        .softChip()

        if monobankIsSyncing {
          ProgressView()
            .controlSize(.small)
        }
      }

      if selectedMonobankAccounts.isEmpty {
        Text(Localization.string(.expenseNoExpenses))
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        if !pinnedBalanceSummaries.isEmpty {
          HStack(spacing: 10) {
            Label(Localization.string(.pinned), systemImage: "pin.fill")
              .font(.system(size: 12, weight: .semibold))
              .foregroundColor(.textSecondary)

            Spacer()

            ForEach(pinnedBalanceSummaries, id: \.self) { summary in
              Text(summary)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.textPrimary)
            }
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 10)
          .softControl(cornerRadius: 12, padding: 6)
        }

        if !pinnedTrendSummaries.isEmpty {
          VStack(alignment: .leading, spacing: 4) {
            Text(Localization.string(.pinnedTrend))
              .font(.system(size: 12, weight: .semibold))
              .foregroundColor(.textSecondary)

            ForEach(pinnedTrendSummaries, id: \.self) { summary in
              Text(summary)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 12)
          .padding(.vertical, 10)
          .softControl(cornerRadius: 12, padding: 6)
        }

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
            ForEach(selectedMonobankAccounts, id: \.id) { account in
              Button {
                selectedBankAccountId = account.accountId
                triggerImpactHaptic()
              } label: {
                BankCardTile(
                  title: bankCardTitle(for: account),
                  number: bankCardNumber(for: account),
                  balance: bankCardBalance(for: account),
                  currencySymbol: currencySymbol(for: account.currencyCode),
                  subtitle: bankCardDateLabel(for: account),
                  theme: bankCardTheme(for: account),
                  isPinned: account.isPinned
                )
              }
              .buttonStyle(.plain)
              .contextMenu {
                Button {
                  togglePinnedAccount(account)
                  triggerImpactHaptic(style: .light)
                } label: {
                  Label(
                    account.isPinned ? Localization.string(.unpin) : Localization.string(.pin),
                    systemImage: account.isPinned ? "pin.slash" : "pin")
                }

                Button {
                  syncMonobank()
                  triggerImpactHaptic(style: .light)
                } label: {
                  Label(Localization.string(.monobankSyncNow), systemImage: "arrow.triangle.2.circlepath")
                }

                Button(role: .destructive) {
                  removeBankCard(account, deleteImportedExpenses: false)
                  triggerImpactHaptic(style: .rigid)
                } label: {
                  Label(Localization.string(.monobankRemoveCard), systemImage: "minus.circle")
                }
              }
            }
          }
          .padding(.horizontal, 2)
          .padding(.vertical, 4)
        }
      }

      if let monobankMessage {
        Text(monobankMessage)
          .font(.system(size: 12))
          .foregroundColor(.textSecondary)
      }
    }
    .softCard(cornerRadius: 16, padding: 16, shadow: false)
  }

  private func refreshMonobankRecurringSuggestions() {
    let bankTransactions: [CSVTransaction] = filteredBankExpenses.map { expense in
      CSVTransaction(
        date: expense.date,
        merchant: expense.merchant ?? expense.title,
        amount: expense.isIncome ? abs(expense.amount) : -abs(expense.amount),
        currency: expense.currencyEnum,
        rawData: [:]
      )
    }

    let detected = patternDetectionService.detectPatterns(from: bankTransactions)
    let filtered = filterExistingTemplates(suggestions: detected)

    monobankRecurringSuggestions = filtered
    selectedRecurringSuggestionIds = Set(filtered.filter { $0.confidence >= 0.8 }.map { $0.id })
  }

  private func filterExistingTemplates(suggestions: [TemplateSuggestion]) -> [TemplateSuggestion] {
    let dismissedSignatures = dismissedRecurringSuggestionSignatures

    return suggestions.filter { suggestion in
      let stableSignature = recurringSuggestionSignature(for: suggestion)
      let legacySignature = recurringSuggestionLegacySignature(for: suggestion)
      if dismissedSignatures.contains(stableSignature) || dismissedSignatures.contains(legacySignature)
      {
        return false
      }

      let normalizedSuggestion = patternDetectionService.normalizeMerchant(suggestion.merchant)
      for template in templates {
        let normalizedTemplate = patternDetectionService.normalizeMerchant(template.merchant)
        guard normalizedSuggestion == normalizedTemplate else { continue }
        guard template.isIncome == suggestion.isIncome else { continue }

        let tolerance = suggestion.suggestedAmount * 0.20
        guard abs(suggestion.suggestedAmount - template.amount) <= tolerance else { continue }
        guard suggestion.frequency == template.frequency else { continue }
        return false
      }
      return true
    }
  }

  private func recurringSuggestionSignature(for suggestion: TemplateSuggestion) -> String {
    let normalizedMerchant = patternDetectionService.normalizeMerchant(suggestion.merchant)
    // Bucket by 25 UAH so dismissal survives small average amount drift between sync runs.
    let amountBucket = Int((suggestion.suggestedAmount / 25.0).rounded())
    return [
      normalizedMerchant,
      suggestion.isIncome ? "income" : "expense",
      "b\(amountBucket)",
    ].joined(separator: "|")
  }

  private func recurringSuggestionLegacySignature(for suggestion: TemplateSuggestion) -> String {
    let normalizedMerchant = patternDetectionService.normalizeMerchant(suggestion.merchant)
    let roundedAmount = Int((suggestion.suggestedAmount * 100.0).rounded())
    return [
      normalizedMerchant,
      suggestion.frequency.rawValue,
      suggestion.isIncome ? "income" : "expense",
      "\(roundedAmount)",
    ].joined(separator: "|")
  }

  private func dismissRecurringSuggestion(_ suggestion: TemplateSuggestion) {
    let signature = recurringSuggestionSignature(for: suggestion)
    let legacySignature = recurringSuggestionLegacySignature(for: suggestion)
    var signatures = dismissedRecurringSuggestionSignatures
    if signatures.contains(signature) || signatures.contains(legacySignature) {
      return
    }

    signatures.insert(signature)
    signatures.insert(legacySignature)
    dismissedRecurringSuggestionSignatures = signatures
    selectedRecurringSuggestionIds.remove(suggestion.id)
    customSuggestionFrequencies.removeValue(forKey: suggestion.id)
    refreshMonobankRecurringSuggestions()
  }

  private var dismissedRecurringSuggestionSignatures: Set<String> {
    get {
      guard
        let decoded = try? JSONDecoder().decode(
          [String].self, from: dismissedRecurringSuggestionSignaturesData)
      else {
        return []
      }
      return Set(decoded)
    }
    nonmutating set {
      let payload = Array(newValue).sorted()
      dismissedRecurringSuggestionSignaturesData = (try? JSONEncoder().encode(payload)) ?? Data()
    }
  }

  private func toggleRecurringSuggestion(_ suggestionId: UUID) {
    if selectedRecurringSuggestionIds.contains(suggestionId) {
      selectedRecurringSuggestionIds.remove(suggestionId)
    } else {
      selectedRecurringSuggestionIds.insert(suggestionId)
    }
  }

  private func createRecurringTemplatesFromSuggestions() {
    let selected = monobankRecurringSuggestions.filter {
      selectedRecurringSuggestionIds.contains($0.id)
    }
    guard !selected.isEmpty else { return }

    let modified = selected.map { suggestion -> TemplateSuggestion in
      guard let customFrequency = customSuggestionFrequencies[suggestion.id] else {
        return suggestion
      }
      return TemplateSuggestion(
        merchant: suggestion.merchant,
        amount: suggestion.amount,
        frequency: customFrequency,
        occurrences: suggestion.occurrences,
        categories: suggestion.categories,
        suggestedAmount: suggestion.suggestedAmount,
        confidence: suggestion.confidence,
        isIncome: suggestion.isIncome
      )
    }

    _ = csvImportService.createTemplates(from: modified, context: modelContext)

    do {
      try modelContext.save()
      monobankMessage = Localization.string(.createTemplates)
      refreshMonobankRecurringSuggestions()
    } catch {
      monobankMessage = error.localizedDescription
    }
  }

  private func bankCardTitle(for account: MonobankAccount) -> String {
    let loweredCashback = (account.cashbackType ?? "").lowercased()
    if loweredCashback.contains("white") {
      return "White Card"
    }
    if loweredCashback.contains("platinum") {
      return "Platinum Card"
    }
    if loweredCashback.contains("black") {
      return "Black Card"
    }
    if loweredCashback.contains("iron") {
      return "Iron Card"
    }
    return "Monobank Card"
  }

  private func bankCardNumber(for account: MonobankAccount) -> String {
    if let pan = account.maskedPan.first, !pan.isEmpty {
      return pan
    }
    return "•••• \(String(account.accountId.suffix(4)))"
  }

  private func bankCardBalance(for account: MonobankAccount) -> String {
    String(format: "%.2f", Double(account.balanceMinor) / 100.0)
  }

  private func bankCardDateLabel(for account: MonobankAccount) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter.string(from: account.updatedAt)
  }

  private func connectMonobank() {
    monobankIsSyncing = true
    monobankMessage = nil
    let token = sanitizedMonobankToken

    Task {
      do {
        try MonobankSyncService.shared.setConsent(true, context: modelContext)
        try MonobankSyncService.shared.saveToken(token, context: modelContext)
        _ = try await MonobankSyncService.shared.sync(context: modelContext, token: token)
        await MainActor.run {
          monobankIsSyncing = false
          monobankMessage = Localization.string(.monobankConnectedAndSynced)
          refreshMonobankRecurringSuggestions()
        }
      } catch {
        await MainActor.run {
          monobankIsSyncing = false
          monobankMessage = error.localizedDescription
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
          refreshMonobankRecurringSuggestions()
        }
      } catch {
        await MainActor.run {
          monobankIsSyncing = false
          monobankMessage = error.localizedDescription
        }
      }
    }
  }

  private func disconnectMonobank() {
    do {
      try MonobankSyncService.shared.disconnect(
        context: modelContext,
        hardDeleteImportedExpenses: false
      )
      monobankMessage = Localization.string(.monobankDisconnectedMessage)
      refreshMonobankRecurringSuggestions()
    } catch {
      monobankMessage = error.localizedDescription
    }
  }

  private func togglePinnedAccount(_ account: MonobankAccount) {
    account.isPinned.toggle()
    if account.isPinned {
      account.isSelected = true
    }
    account.updatedAt = Date()
    triggerImpactHaptic(style: .light)
    persistSelectedMonobankAccounts()
  }

  private func setTheme(_ theme: BankCardTheme, for account: MonobankAccount) {
    account.cardTheme = theme.rawValue
    account.themeVersion = "2026.03.palette.v1"
    account.updatedAt = Date()
    triggerImpactHaptic(style: .light)
    do {
      try modelContext.save()
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
  }

  private func removeBankCard(_ account: MonobankAccount, deleteImportedExpenses: Bool) {

    account.isSelected = false
    account.isPinned = false
    account.updatedAt = Date()

    if deleteImportedExpenses {
      do {
        let accountId = account.accountId
        let statements = try modelContext.fetch(
          FetchDescriptor<MonobankStatementItem>(
            predicate: #Predicate { item in
              item.accountId == accountId
            })
        )
        let statementIds = Set(statements.map { $0.statementId })
        if !statementIds.isEmpty {
          let source = "monobank"
          let importedExpenses = try modelContext.fetch(
            FetchDescriptor<Expense>(
              predicate: #Predicate { expense in
                expense.externalSource == source
              })
          )
          for expense in importedExpenses {
            if let externalId = expense.externalId, statementIds.contains(externalId) {
              modelContext.delete(expense)
            }
          }
        }
      } catch {
        ErrorPresenter.presentOnMain(error)
      }
    }

    selectedBankAccountId = nil
    triggerImpactHaptic(style: .rigid)
    persistSelectedMonobankAccounts()
    refreshMonobankRecurringSuggestions()
  }

  private func persistSelectedMonobankAccounts() {
    monobankConnection?.selectedAccountIds = selectedMonobankAccounts.map { $0.accountId }
    monobankConnection?.updatedAt = Date()
    do {
      try modelContext.save()
      try MonobankSyncService.shared.syncSelectedBalancesToWidget(context: modelContext)
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
  }

  private func bankCardTheme(for account: MonobankAccount) -> BankCardTheme {
    let explicit = BankCardTheme(rawValue: account.cardTheme) ?? .auto
    guard explicit == .auto else { return explicit }

    let loweredCashback = (account.cashbackType ?? "").lowercased()
    if loweredCashback.contains("black") {
      return .black
    }
    if loweredCashback.contains("white") {
      return .white
    }
    if loweredCashback.contains("platinum") {
      return .platinum
    }
    if loweredCashback.contains("iron") {
      return .iron
    }
    return .auto
  }

  private func accountStatements(for account: MonobankAccount) -> [MonobankStatementItem] {
    monobankStatementItems
      .filter { $0.accountId == account.accountId }
      .sorted { $0.transactionTime > $1.transactionTime }
  }

  private func aggregateBalanceDelta(daysBack: Int) -> [Int: Double] {
    guard !trendAccounts.isEmpty else { return [:] }
    let cutoff = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()

    var totalsByCurrency: [Int: Double] = [:]
    for account in trendAccounts {
      let baselineMinor = monobankStatementItems
        .filter { $0.accountId == account.accountId && $0.transactionTime <= cutoff }
        .max(by: { $0.transactionTime < $1.transactionTime })?
        .balanceMinor ?? account.balanceMinor

      let deltaMajor = Double(account.balanceMinor - baselineMinor) / 100.0
      totalsByCurrency[account.currencyCode, default: 0] += deltaMajor
    }

    return totalsByCurrency
  }

  private func formatSignedAmount(_ amount: Double, currencyCode: Int) -> String {
    let sign = amount >= 0 ? "+" : "-"
    return "\(sign)\(currencySymbol(for: currencyCode))\(String(format: "%.0f", abs(amount)))"
  }

  private func triggerImpactHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
    #if os(iOS)
      let generator = UIImpactFeedbackGenerator(style: style)
      generator.prepare()
      generator.impactOccurred()
    #endif
  }

  private func preloadStoredMonobankToken() {
    guard monobankToken.isEmpty else { return }
    let storedToken = (try? MonobankKeychainStore.shared.loadToken()) ?? nil
    if let storedToken, !storedToken.isEmpty {
      monobankToken = storedToken
    }
  }

  private func currencySymbol(for code: Int) -> String {
    switch code {
    case 840: return "$"
    case 978: return "€"
    case 980: return "₴"
    default: return "₴"
    }
  }
}

// MARK: - History View

struct HistoryView: View {
  let expenses: [Expense]
  let allExpensesForLookup: [Expense]
  let duplicateSuggestions: [DuplicateSuggestion]
  let monobankConflicts: [MonobankConflict]
  let bankHeader: AnyView?
  let recurringSuggestions: [TemplateSuggestion]
  let selectedRecurringSuggestionIds: Set<UUID>
  let customSuggestionFrequencies: [UUID: ExpenseFrequency]
  let viewModel: ExpenseViewModel
  let onEdit: (Expense) -> Void
  let onMergeDuplicate: (DuplicateSuggestion) -> Void
  let onDismissDuplicate: (DuplicateSuggestion) -> Void
  let onKeepLocalConflict: (MonobankConflict) -> Void
  let onUseServerConflict: (MonobankConflict) -> Void
  let onToggleSuggestion: (UUID) -> Void
  let onSuggestionFrequencyChange: (UUID, ExpenseFrequency) -> Void
  let onCreateRecurringTemplates: () -> Void
  let onDismissRecurringSuggestion: (TemplateSuggestion) -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        if let bankHeader {
          bankHeader
        }

        if !duplicateSuggestions.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
              Text(Localization.string(.duplicateSuggestionsX(duplicateSuggestions.count)))
                .font(.system(size: 13, weight: .semibold))
              Spacer()
            }

            ForEach(duplicateSuggestions) { suggestion in
              DuplicateSuggestionRow(
                suggestion: suggestion,
                expenses: expenses,
                onMerge: { onMergeDuplicate(suggestion) },
                onDismiss: { onDismissDuplicate(suggestion) }
              )
            }
          }
          .softCard(cornerRadius: 12, padding: 14, shadow: false)
        }

        if !monobankConflicts.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Image(systemName: "building.columns.fill")
                .foregroundColor(.orange)
              Text(Localization.string(.monobankConflictsCount(monobankConflicts.count)))
                .font(.system(size: 13, weight: .semibold))
              Spacer()
            }

            ForEach(monobankConflicts, id: \.id) { conflict in
              MonobankConflictRow(
                conflict: conflict,
                expenses: allExpensesForLookup,
                onKeepLocal: { onKeepLocalConflict(conflict) },
                onUseServer: { onUseServerConflict(conflict) }
              )
            }
          }
          .softCard(cornerRadius: 12, padding: 14, shadow: false)
        }

        if !recurringSuggestions.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Image(systemName: "repeat.circle.fill")
                .foregroundColor(.appAccent)
              Text(Localization.string(.recurringPatternsDetected))
                .font(.system(size: 13, weight: .semibold))
              Spacer()
              Button(Localization.string(.createTemplatesX(selectedRecurringSuggestionIds.count))) {
                onCreateRecurringTemplates()
              }
              .disabled(selectedRecurringSuggestionIds.isEmpty)
              .font(.system(size: 11, weight: .semibold))
              .softControl(cornerRadius: 8, padding: 6)
            }

            ForEach(recurringSuggestions) { suggestion in
              TemplateSuggestionCard(
                suggestion: suggestion,
                isSelected: selectedRecurringSuggestionIds.contains(suggestion.id),
                customFrequency: customSuggestionFrequencies[suggestion.id],
                onToggle: { onToggleSuggestion(suggestion.id) },
                onFrequencyChange: { frequency in
                  onSuggestionFrequencyChange(suggestion.id, frequency)
                },
                onDismiss: {
                  onDismissRecurringSuggestion(suggestion)
                }
              )
            }
          }
          .softCard(cornerRadius: 12, padding: 14, shadow: false)
        }

        if expenses.isEmpty {
          VStack(spacing: 20) {
            Image(systemName: "creditcard")
              .font(.system(size: 48))
              .foregroundColor(.textTertiary)
            Text(Localization.string(.expenseNoExpenses))
              .font(.body)
              .foregroundColor(.textSecondary)
          }
          .padding(.top, 40)
        } else {
          ForEach(viewModel.groupedByDate(expenses: expenses), id: \.date) { group in
            VStack(alignment: .leading, spacing: 12) {
              Text(group.date.formatted(date: .abbreviated, time: .omitted).uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textTertiary)
                .padding(.leading, 4)

              ForEach(group.expenses, id: \.id) { expense in
                ExpenseRow(expense: expense)
                  .onTapGesture {
                    onEdit(expense)
                  }
              }
            }
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 92)
    }
  }
}

private struct MonobankConflictRow: View {
  let conflict: MonobankConflict
  let expenses: [Expense]
  let onKeepLocal: () -> Void
  let onUseServer: () -> Void

  private var linkedExpense: Expense? {
    expenses.first(where: { $0.id == conflict.expenseId })
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(Localization.string(.monobankConflictTitle))
        .font(.system(size: 12, weight: .bold))

      if let linkedExpense {
        Text(
          "\(linkedExpense.title) • \(Currency.uah.symbol)\(String(format: "%.0f", linkedExpense.currencyEnum.convertToUAH(linkedExpense.amount)))"
        )
        .font(.system(size: 12))
        .foregroundColor(.secondary)
      }

      Text(conflict.reason)
        .font(.system(size: 11))
        .foregroundColor(.secondary)

      Text(Localization.string(.monobankStatementId(conflict.statementId)))
        .font(.system(size: 11))
        .foregroundColor(.textTertiary)

      HStack {
        Button(Localization.string(.monobankKeepLocal)) {
          onKeepLocal()
        }
        .font(.system(size: 12, weight: .semibold))
        .softControl(cornerRadius: 8, padding: 6)

        Spacer()

        Button(Localization.string(.monobankUseBank)) {
          onUseServer()
        }
        .font(.system(size: 12, weight: .semibold))
        .softControl(cornerRadius: 8, padding: 6)
      }
    }
    .padding(10)
    .softCard(cornerRadius: 10, padding: 10, shadow: false)
  }
}

private struct DuplicateSuggestionRow: View {
  let suggestion: DuplicateSuggestion
  let expenses: [Expense]
  let onMerge: () -> Void
  let onDismiss: () -> Void

  private var expenseA: Expense? {
    expenses.first(where: { $0.id == suggestion.expenseIdA })
  }

  private var expenseB: Expense? {
    expenses.first(where: { $0.id == suggestion.expenseIdB })
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(Localization.string(.possibleDuplicate))
        .font(.system(size: 12, weight: .bold))

      if let expenseA, let expenseB {
        Text(
          "\(expenseA.title) • \(Currency.uah.symbol)\(String(format: "%.0f", expenseA.currencyEnum.convertToUAH(expenseA.amount)))"
        )
        .font(.system(size: 12))
        .foregroundColor(.secondary)
        Text(
          "\(expenseB.title) • \(Currency.uah.symbol)\(String(format: "%.0f", expenseB.currencyEnum.convertToUAH(expenseB.amount)))"
        )
        .font(.system(size: 12))
        .foregroundColor(.secondary)
      }

      HStack {
        Button(Localization.string(.merge)) {
          onMerge()
        }
        .font(.system(size: 12, weight: .semibold))
        .softControl(cornerRadius: 8, padding: 6)

        Spacer()

        Button(Localization.string(.dismiss)) {
          onDismiss()
        }
        .font(.system(size: 12, weight: .semibold))
        .softControl(cornerRadius: 8, padding: 6)
      }
    }
    .padding(10)
    .softCard(cornerRadius: 10, padding: 10, shadow: false)
  }
}

private struct BankCardTile: View {
  let title: String
  let number: String
  let balance: String
  let currencySymbol: String
  let subtitle: String
  let theme: BankCardTheme
  let isPinned: Bool

  var body: some View {
    let palette = theme.palette

    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(title)
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(palette.primaryText)
          .lineLimit(1)

        Spacer(minLength: 8)

        Text(subtitle)
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(palette.secondaryText)

        if isPinned {
          Image(systemName: "pin.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(palette.primaryText.opacity(0.9))
        }
      }

      Spacer(minLength: 0)

      Text(number)
        .font(.system(size: 14, weight: .medium, design: .monospaced))
        .foregroundColor(palette.primaryText.opacity(0.95))

      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text(currencySymbol)
          .font(.system(size: 16, weight: .bold))
          .foregroundColor(palette.primaryText)

        Text(balance)
          .font(.system(size: 26, weight: .bold))
          .foregroundColor(palette.primaryText)
      }
    }
    .padding(16)
    .frame(width: 252, height: 164)
    .background(palette.fill)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(palette.border, lineWidth: 0.8)
    )
    .shadow(color: palette.shadow, radius: 7, x: 0, y: 3)
  }
}

private struct BankCardPalette {
  let fill: Color
  let primaryText: Color
  let secondaryText: Color
  let border: Color
  let shadow: Color
}

private enum BankCardTheme: String, CaseIterable, Identifiable {
  case auto
  case black
  case white
  case platinum
  case iron

  var id: String { rawValue }

  var palette: BankCardPalette {
    let lightText = Color(red: 233 / 255, green: 237 / 255, blue: 245 / 255)  // #E9EDF5
    let darkText = Color(red: 30 / 255, green: 36 / 255, blue: 48 / 255)  // #1E2430

    switch self {
    case .auto:
      return ironPalette
    case .black:
      let bg = Color(red: 75 / 255, green: 82 / 255, blue: 99 / 255)  // #4B5263
      let primary = Self.contrastGuard(preferred: lightText, background: bg)
      return BankCardPalette(
        fill: bg,
        primaryText: primary,
        secondaryText: primary.opacity(0.82),
        border: Color.white.opacity(0.16),
        shadow: Color.black.opacity(0.22)
      )
    case .white:
      let bg = Color(red: 247 / 255, green: 248 / 255, blue: 251 / 255)  // #F7F8FB
      let primary = Self.contrastGuard(preferred: darkText, background: bg)
      return BankCardPalette(
        fill: bg,
        primaryText: primary,
        secondaryText: primary.opacity(0.76),
        border: Color(red: 215 / 255, green: 220 / 255, blue: 231 / 255).opacity(0.95),  // #D7DCE7
        shadow: Color.black.opacity(0.08)
      )
    case .platinum:
      let bg = Color(red: 243 / 255, green: 168 / 255, blue: 175 / 255)  // #F3A8AF
      let preferred = Color(red: 76 / 255, green: 70 / 255, blue: 80 / 255)  // #4C4650
      let primary = Self.contrastGuard(preferred: preferred, background: bg)
      return BankCardPalette(
        fill: bg,
        primaryText: primary,
        secondaryText: primary.opacity(0.78),
        border: Color.white.opacity(0.28),
        shadow: Color(red: 76 / 255, green: 70 / 255, blue: 80 / 255).opacity(0.16)
      )
    case .iron:
      return ironPalette
    }
  }

  private var ironPalette: BankCardPalette {
      let bg = Color(red: 201 / 255, green: 203 / 255, blue: 209 / 255)  // #C9CBD1
      let preferred = Color(red: 90 / 255, green: 95 / 255, blue: 105 / 255)  // #5A5F69
      let primary = Self.contrastGuard(preferred: preferred, background: bg)
      return BankCardPalette(
        fill: bg,
        primaryText: primary,
        secondaryText: primary.opacity(0.78),
        border: Color.white.opacity(0.28),
        shadow: Color.black.opacity(0.12)
      )
  }

  private static func contrastGuard(preferred: Color, background: Color) -> Color {
    #if os(iOS)
      let preferredRatio = contrastRatio(UIColor(preferred), UIColor(background))
      if preferredRatio >= 4.5 {
        return preferred
      }

      let white = UIColor.white
      let black = UIColor.black
      let whiteRatio = contrastRatio(white, UIColor(background))
      let blackRatio = contrastRatio(black, UIColor(background))
      return whiteRatio >= blackRatio ? Color.white : Color.black
    #else
      return preferred
    #endif
  }

  #if os(iOS)
    private static func contrastRatio(_ first: UIColor, _ second: UIColor) -> Double {
      let l1 = relativeLuminance(first)
      let l2 = relativeLuminance(second)
      let lighter = max(l1, l2)
      let darker = min(l1, l2)
      return (lighter + 0.05) / (darker + 0.05)
    }

    private static func relativeLuminance(_ color: UIColor) -> Double {
      var red: CGFloat = 0
      var green: CGFloat = 0
      var blue: CGFloat = 0
      var alpha: CGFloat = 0
      color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

      func channel(_ value: CGFloat) -> Double {
        let normalized = Double(value)
        if normalized <= 0.03928 {
          return normalized / 12.92
        }
        return pow((normalized + 0.055) / 1.055, 2.4)
      }

      let r = channel(red)
      let g = channel(green)
      let b = channel(blue)
      return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
  #endif

  var label: String {
    switch self {
    case .auto:
      return Localization.string(.monobankThemeAuto)
    case .black:
      return Localization.string(.monobankThemeBlack)
    case .white:
      return Localization.string(.monobankThemeWhite)
    case .platinum:
      return Localization.string(.monobankThemePlatinum)
    case .iron:
      return Localization.string(.monobankThemeIron)
    }
  }
}

private struct BankCardDetailsSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var showingRemoveConfirmation = false
  @State private var merchantQuery = ""
  @State private var minAmountText = ""
  @State private var maxAmountText = ""
  @State private var fromDate: Date
  @State private var toDate: Date

  let account: MonobankAccount
  let cardTitle: String
  let cardNumber: String
  let balance: String
  let currencySymbol: String
  let subtitle: String
  let theme: BankCardTheme
  let statements: [MonobankStatementItem]
  let onPinToggle: () -> Void
  let onSyncNow: () -> Void
  let onThemeSelected: (BankCardTheme) -> Void
  let onRemoveKeepImported: () -> Void
  let onRemoveDeleteImported: () -> Void

  init(
    account: MonobankAccount,
    cardTitle: String,
    cardNumber: String,
    balance: String,
    currencySymbol: String,
    subtitle: String,
    theme: BankCardTheme,
    statements: [MonobankStatementItem],
    onPinToggle: @escaping () -> Void,
    onSyncNow: @escaping () -> Void,
    onThemeSelected: @escaping (BankCardTheme) -> Void,
    onRemoveKeepImported: @escaping () -> Void,
    onRemoveDeleteImported: @escaping () -> Void
  ) {
    self.account = account
    self.cardTitle = cardTitle
    self.cardNumber = cardNumber
    self.balance = balance
    self.currencySymbol = currencySymbol
    self.subtitle = subtitle
    self.theme = theme
    self.statements = statements
    self.onPinToggle = onPinToggle
    self.onSyncNow = onSyncNow
    self.onThemeSelected = onThemeSelected
    self.onRemoveKeepImported = onRemoveKeepImported
    self.onRemoveDeleteImported = onRemoveDeleteImported

    let latest = statements.map(\.transactionTime).max() ?? Date()
    let defaultFrom = Calendar.current.date(byAdding: .day, value: -30, to: latest) ?? latest
    _fromDate = State(initialValue: defaultFrom)
    _toDate = State(initialValue: latest)
  }

  private var filteredStatements: [MonobankStatementItem] {
    let normalizedQuery = merchantQuery
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    let minimum = parseAmount(minAmountText)
    let maximum = parseAmount(maxAmountText)

    let start = Calendar.current.startOfDay(
      for: min(fromDate, toDate)
    )
    let endDay = max(fromDate, toDate)
    let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDay) ?? endDay

    return statements
      .filter { item in
        if !normalizedQuery.isEmpty {
          let searchableText = [
            item.counterName ?? "",
            item.descriptionText,
            item.comment ?? "",
          ]
          .joined(separator: " ")
          .lowercased()
          guard searchableText.contains(normalizedQuery) else { return false }
        }

        let operationAmount = abs(Double(item.operationAmountMinor) / 100.0)
        if let minimum, operationAmount < minimum { return false }
        if let maximum, operationAmount > maximum { return false }

        guard item.transactionTime >= start, item.transactionTime <= end else { return false }
        return true
      }
      .sorted { $0.transactionTime > $1.transactionTime }
  }

  private func parseAmount(_ value: String) -> Double? {
    let normalized = value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: ",", with: ".")
    guard !normalized.isEmpty else { return nil }
    return Double(normalized)
  }

  private func signedAmount(for item: MonobankStatementItem) -> String {
    let sign = item.operationAmountMinor >= 0 ? "+" : "-"
    let major = abs(Double(item.operationAmountMinor) / 100.0)
    return "\(sign)\(currencySymbol)\(String(format: "%.2f", major))"
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          BankCardTile(
            title: cardTitle,
            number: cardNumber,
            balance: balance,
            currencySymbol: currencySymbol,
            subtitle: subtitle,
            theme: theme,
            isPinned: account.isPinned
          )

          HStack(spacing: 10) {
            Button {
              onPinToggle()
            } label: {
              Label(
                account.isPinned ? Localization.string(.unpin) : Localization.string(.pin),
                systemImage: account.isPinned ? "pin.slash" : "pin"
              )
              .font(.system(size: 13, weight: .semibold))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
            }
            .softControl(cornerRadius: 10, padding: 8)

            Button {
              onSyncNow()
            } label: {
              Label(Localization.string(.monobankSyncNow), systemImage: "arrow.clockwise")
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .softControl(cornerRadius: 10, padding: 8)
          }

          VStack(alignment: .leading, spacing: 10) {
            Text(Localization.string(.monobankCardTheme))
              .font(.system(size: 13, weight: .semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
              ForEach(BankCardTheme.allCases) { option in
                Button {
                  onThemeSelected(option)
                } label: {
                  HStack {
                    Text(option.label)
                      .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    if theme == option {
                      Image(systemName: "checkmark.circle.fill")
                    }
                  }
                  .foregroundColor(.primary)
                  .padding(10)
                  .background(Color.secondaryFill)
                  .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
              }
            }
          }
          .softCard(cornerRadius: 12, padding: 12, shadow: false)

          VStack(alignment: .leading, spacing: 10) {
            Text(Localization.string(.monobankTransactions))
              .font(.system(size: 13, weight: .semibold))

              TextField(Localization.string(.search), text: $merchantQuery)
              .textFieldStyle(.roundedBorder)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled(true)

            HStack(spacing: 10) {
              TextField(Localization.string(.monobankMinAmount), text: $minAmountText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

              TextField(Localization.string(.monobankMaxAmount), text: $maxAmountText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
            }

            DatePicker(
              Localization.string(.monobankFrom),
              selection: $fromDate,
              displayedComponents: .date
            )
            .font(.system(size: 13, weight: .medium))

            DatePicker(
              Localization.string(.monobankTo),
              selection: $toDate,
              displayedComponents: .date
            )
            .font(.system(size: 13, weight: .medium))
          }
          .softCard(cornerRadius: 12, padding: 12, shadow: false)

          VStack(alignment: .leading, spacing: 10) {
            Text(Localization.string(.monobankItemsCount(filteredStatements.count)))
              .font(.system(size: 12, weight: .semibold))
              .foregroundColor(.secondary)

            if filteredStatements.isEmpty {
              Text(Localization.string(.monobankNoTransactionsForFilters))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            } else {
              LazyVStack(spacing: 8) {
                ForEach(filteredStatements, id: \.id) { item in
                  HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                      Text(item.counterName ?? item.descriptionText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                      Text(item.descriptionText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                      Text(
                        item.transactionTime.formatted(
                          date: .abbreviated,
                          time: .shortened
                        )
                      )
                      .font(.system(size: 10, weight: .medium))
                      .foregroundColor(.textTertiary)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 4) {
                      Text(signedAmount(for: item))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(item.operationAmountMinor >= 0 ? .green : .red)

                      Text(
                        "Bal \(currencySymbol)\(String(format: "%.2f", Double(item.balanceMinor) / 100.0))"
                      )
                      .font(.system(size: 10, weight: .medium))
                      .foregroundColor(.secondary)
                    }
                  }
                  .padding(10)
                  .background(Color.secondaryFill)
                  .clipShape(RoundedRectangle(cornerRadius: 10))
                }
              }
            }
          }
          .softCard(cornerRadius: 12, padding: 12, shadow: false)

          Button(role: .destructive) {
            showingRemoveConfirmation = true
          } label: {
            Label(Localization.string(.monobankRemoveCard), systemImage: "minus.circle")
              .font(.system(size: 14, weight: .semibold))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
          }
          .softControl(cornerRadius: 10, padding: 8)
        }
        .padding(20)
      }
      .background(Color.backgroundPrimary.ignoresSafeArea())
      .navigationTitle(Localization.string(.monobankCardDetails))
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(Localization.string(.cancel)) {
            dismiss()
          }
        }
      }
      .confirmationDialog(
        Localization.string(.monobankRemoveCardTitle),
        isPresented: $showingRemoveConfirmation,
        titleVisibility: .visible
      ) {
        Button(Localization.string(.monobankRemoveCardKeepImported)) {
          onRemoveKeepImported()
          dismiss()
        }
        Button(Localization.string(.monobankRemoveCardDeleteImported), role: .destructive) {
          onRemoveDeleteImported()
          dismiss()
        }
        Button(Localization.string(.cancel), role: .cancel) {}
      } message: {
        Text(Localization.string(.monobankRemoveCardPrompt))
      }
    }
  }
}

private struct MonobankConnectionSheet: View {
  @Binding var token: String
  @Binding var isSyncing: Bool
  @Binding var message: String?
  let isConnected: Bool
  let onConnect: () -> Void
  let onSync: () -> Void
  let onDisconnect: () -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        SecureField(Localization.string(.monobankPasteToken), text: $token)
          .textFieldStyle(.roundedBorder)

        HStack(spacing: 10) {
          Button(Localization.string(.monobankConnect)) {
            onConnect()
          }
          .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSyncing)
          .softControl(cornerRadius: 10, padding: 8)

          Button(Localization.string(.monobankSyncNow)) {
            onSync()
          }
          .disabled(!isConnected || isSyncing)
          .softControl(cornerRadius: 10, padding: 8)

          Button(Localization.string(.monobankDisconnect), role: .destructive) {
            onDisconnect()
          }
          .disabled(!isConnected || isSyncing)
          .softControl(cornerRadius: 10, padding: 8)
        }

        if isSyncing {
          ProgressView(Localization.string(.monobankSyncing))
        }

        if let message {
          Text(message)
            .font(.system(size: 12))
            .foregroundColor(.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        Spacer()
      }
      .padding(20)
      .navigationTitle(Localization.string(.monobankTitle))
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(Localization.string(.cancel)) {
            dismiss()
          }
        }
      }
    }
  }
}

#Preview {
  ExpensesView()
}
