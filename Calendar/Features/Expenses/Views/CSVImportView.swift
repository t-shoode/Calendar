import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct CSVImportView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  @Query(sort: \Expense.date) private var existingExpenses: [Expense]
  @Query(sort: \RecurringExpenseTemplate.createdAt) private var existingTemplates:
    [RecurringExpenseTemplate]
  @Query(sort: \CSVImportMapping.updatedAt, order: .reverse) private var mappings: [CSVImportMapping]

  @State private var showingFilePicker = false
  @State private var showingMappingEditor = false
  @State private var importResult: CSVImportResult?
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var selectedSuggestions: Set<UUID> = []
  @State private var customFrequencies: [UUID: ExpenseFrequency] = [:]
  @State private var selectedCSVData: Data?
  @State private var selectedCSVFileName: String?
  @State private var selectedCSVString: String = ""
  @State private var mappingHeaders: [String] = []
  @State private var mappingDelimiter: String = ","
  @State private var mappingDateFormat: String = "dd.MM.yyyy HH:mm:ss"
  @State private var mappingName: String = "Custom Mapping"
  @State private var mapDateHeader: String = ""
  @State private var mapMerchantHeader: String = ""
  @State private var mapAmountHeader: String = ""
  @State private var mapCurrencyHeader: String = ""
  @State private var mappingSetAsDefault = false
  @State private var mappingPreview: [CSVTransaction] = []
  @State private var mappingInvalidRows = 0

  private let importService = CSVImportService()
  private let mappingService = CSVMappingService.shared

  var body: some View {
    NavigationStack {
      VStack {
        if isLoading {
          ProgressView(Localization.string(.analyzingCSV))
            .scaleEffect(1.2)
        } else if let result = importResult {
          importResultView(result: result)
        } else {
          uploadPromptView
        }
      }
      .navigationTitle(Localization.string(.importFromBank))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(Localization.string(.cancel)) { dismiss() }
        }
      }
      .fileImporter(
        isPresented: $showingFilePicker,
        allowedContentTypes: [.commaSeparatedText, .plainText],
        allowsMultipleSelection: false
      ) { result in
        handleFileSelection(result: result)
      }
      .sheet(isPresented: $showingMappingEditor) {
        mappingEditorSheet
      }
    }
  }

  private var uploadPromptView: some View {
    VStack(spacing: 24) {
      Image(systemName: "doc.text")
        .font(.system(size: 64))
        .foregroundColor(.appAccent)

      Text(Localization.string(.importBankStatement))
        .font(.title2.bold())

      Text(Localization.string(.uploadCSV))
        .multilineTextAlignment(.center)
        .foregroundColor(.secondary)
        .padding(.horizontal)

      Button {
        showingFilePicker = true
      } label: {
        HStack {
          Image(systemName: "folder")
          Text(Localization.string(.selectCSVFile))
        }
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.appAccent)
        .cornerRadius(12)
      }
      .padding(.horizontal)

      Button {
        showingMappingEditor = true
      } label: {
        HStack {
          Image(systemName: "slider.horizontal.3")
          Text("Map columns")
        }
        .font(.subheadline)
        .foregroundColor(.appAccent)
      }

      if let error = errorMessage {
        Text(error)
          .foregroundColor(.red)
          .font(.caption)
          .padding()
      }
    }
    .padding()
  }

  private func importResultView(result: CSVImportResult) -> some View {
    ScrollView {
      VStack(spacing: 16) {
        // Summary stats
        HStack(spacing: 16) {
          StatCard(
            title: Localization.string(.transactions),
            value: "\(result.transactions.count)",
            icon: "doc.text",
            color: .blue
          )

          StatCard(
            title: Localization.string(.duplicates),
            value: "\(result.duplicates.count)",
            icon: "xmark.circle",
            color: .orange
          )
        }

        if !result.suggestions.isEmpty {
          HStack {
            Text(Localization.string(.recurringPatternsDetected))
              .font(.headline)

            Text(Localization.string(.patternsFound) + " (\(result.suggestions.count))")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding(.top)

          Text(Localization.string(.selectPatterns))
            .font(.caption)
            .foregroundColor(.secondary)

          VStack(spacing: 12) {
            ForEach(result.suggestions) { suggestion in
              TemplateSuggestionCard(
                suggestion: suggestion,
                isSelected: selectedSuggestions.contains(suggestion.id),
                customFrequency: customFrequencies[suggestion.id],
                onToggle: {
                  toggleSuggestion(suggestion.id)
                },
                onFrequencyChange: { frequency in
                  customFrequencies[suggestion.id] = frequency
                },
                onDismiss: nil
              )
            }
          }
        }

        Spacer(minLength: 32)

        // Action buttons
        VStack(spacing: 12) {
          Button {
            importSelectedTemplates(result: result)
          } label: {
            HStack {
              Image(systemName: "checkmark.circle.fill")
              Text(Localization.string(.createTemplatesX(selectedSuggestions.count)))
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(selectedSuggestions.isEmpty ? Color.gray : Color.appAccent)
            .cornerRadius(12)
          }
          .disabled(selectedSuggestions.isEmpty)

          Button {
            importAllTransactions(result: result)
          } label: {
            HStack {
              Image(systemName: "arrow.down.doc")
              Text(Localization.string(.importAllTransactions))
            }
            .font(.subheadline)
            .foregroundColor(.appAccent)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.appAccent.opacity(0.1))
            .cornerRadius(12)
          }

          Button {
            importResult = nil
          } label: {
            Text(Localization.string(.importAnotherFile))
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
        }
        .padding(.horizontal)
      }
      .padding()
    }
  }

  private func handleFileSelection(result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      guard let url = urls.first else {
        errorMessage = Localization.string(.noFileSelected)
        return
      }

      loadAndParseCSV(url: url)

    case .failure(let error):
      errorMessage = error.localizedDescription
    }
  }

  private func loadAndParseCSV(url: URL) {
    isLoading = true
    errorMessage = nil

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
          DispatchQueue.main.async {
            self.errorMessage = Localization.string(.cannotAccessFile)
            self.isLoading = false
          }
          return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let data = try Data(contentsOf: url)
        let fileName = url.lastPathComponent
        let csvString = String(data: data, encoding: .utf8) ?? ""

        DispatchQueue.main.async {
          self.selectedCSVData = data
          self.selectedCSVFileName = fileName
          self.selectedCSVString = csvString
          self.mappingHeaders = self.extractHeaders(from: csvString, delimiter: self.mappingDelimiter)
          self.bootstrapMappingDraftIfNeeded()

          self.importResult = self.importService.importCSV(
            csvData: data,
            fileName: fileName,
            existingExpenses: self.existingExpenses,
            existingTemplates: self.existingTemplates,
            context: self.modelContext
          )

          // Auto-select all suggestions with high confidence
          if let result = self.importResult {
            for suggestion in result.suggestions where suggestion.confidence > 0.8 {
              self.selectedSuggestions.insert(suggestion.id)
            }
            if result.transactions.isEmpty && !self.mappingHeaders.isEmpty {
              self.showingMappingEditor = true
            }
          }

          self.isLoading = false
        }

      } catch {
        DispatchQueue.main.async {
          self.errorMessage = Localization.string(.failedToReadFile(error.localizedDescription))
          self.isLoading = false
        }
      }
    }
  }

  private var mappingEditorSheet: some View {
    NavigationStack {
      Form {
        Section("Mapping") {
          TextField("Mapping name", text: $mappingName)
          TextField("Delimiter", text: $mappingDelimiter)
          TextField("Date format", text: $mappingDateFormat)
          Toggle("Set as default", isOn: $mappingSetAsDefault)
        }

        Section("Columns") {
          mappingPicker(title: "Date column", selection: $mapDateHeader)
          mappingPicker(title: "Merchant column", selection: $mapMerchantHeader)
          mappingPicker(title: "Amount column", selection: $mapAmountHeader)
          mappingPicker(title: "Currency column (optional)", selection: $mapCurrencyHeader, allowEmpty: true)
        }

        Section("Preview") {
          if mappingPreview.isEmpty {
            Text("No preview rows yet")
              .foregroundColor(.secondary)
          } else {
            ForEach(mappingPreview.prefix(8)) { row in
              VStack(alignment: .leading, spacing: 2) {
                Text(row.date.formatted(date: .abbreviated, time: .omitted))
                  .font(.system(size: 12, weight: .semibold))
                Text(row.merchant)
                  .font(.system(size: 12))
                Text("\(row.amount, specifier: "%.2f") \(row.currency.displayName)")
                  .font(.system(size: 12))
                  .foregroundColor(.secondary)
              }
              .padding(.vertical, 2)
            }
          }
          Text("Invalid rows: \(mappingInvalidRows)")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        }
      }
      .navigationTitle("CSV Mapping")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            showingMappingEditor = false
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            saveMappingAndRetryImport()
          }
          .disabled(mapDateHeader.isEmpty || mapMerchantHeader.isEmpty || mapAmountHeader.isEmpty)
        }
      }
      .onAppear {
        refreshMappingPreview()
      }
      .onChange(of: mappingDelimiter) { _, _ in
        mappingHeaders = extractHeaders(from: selectedCSVString, delimiter: mappingDelimiter)
        refreshMappingPreview()
      }
      .onChange(of: mappingDateFormat) { _, _ in
        refreshMappingPreview()
      }
      .onChange(of: mapDateHeader) { _, _ in refreshMappingPreview() }
      .onChange(of: mapMerchantHeader) { _, _ in refreshMappingPreview() }
      .onChange(of: mapAmountHeader) { _, _ in refreshMappingPreview() }
      .onChange(of: mapCurrencyHeader) { _, _ in refreshMappingPreview() }
    }
  }

  private func mappingPicker(
    title: String,
    selection: Binding<String>,
    allowEmpty: Bool = false
  ) -> some View {
    Picker(title, selection: selection) {
      if allowEmpty {
        Text("None").tag("")
      }
      ForEach(mappingHeaders, id: \.self) { header in
        Text(header).tag(header)
      }
    }
  }

  private func bootstrapMappingDraftIfNeeded() {
    guard !mappingHeaders.isEmpty else { return }
    if mapDateHeader.isEmpty { mapDateHeader = guessHeader(from: mappingHeaders, contains: ["дата", "date"]) ?? mappingHeaders.first ?? "" }
    if mapMerchantHeader.isEmpty { mapMerchantHeader = guessHeader(from: mappingHeaders, contains: ["деталі", "merchant", "опис", "details"]) ?? mappingHeaders.first ?? "" }
    if mapAmountHeader.isEmpty { mapAmountHeader = guessHeader(from: mappingHeaders, contains: ["сума", "amount", "sum"]) ?? mappingHeaders.first ?? "" }
    if mapCurrencyHeader.isEmpty { mapCurrencyHeader = guessHeader(from: mappingHeaders, contains: ["currency", "валюта"]) ?? "" }
  }

  private func guessHeader(from headers: [String], contains tokens: [String]) -> String? {
    headers.first { header in
      let lower = header.lowercased()
      return tokens.contains { lower.contains($0) }
    }
  }

  private func extractHeaders(from csvString: String, delimiter: String) -> [String] {
    guard let firstLine = csvString.components(separatedBy: .newlines).first else { return [] }
    let sep = delimiter.first ?? ","
    return firstLine
      .split(separator: sep)
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
  }

  private func refreshMappingPreview() {
    guard !selectedCSVString.isEmpty else { return }
    let map: [CSVImportField: String] = [
      .date: mapDateHeader,
      .merchant: mapMerchantHeader,
      .amount: mapAmountHeader,
      .currency: mapCurrencyHeader,
    ].filter { !$0.value.isEmpty }

    guard
      let mapData = try? JSONEncoder().encode(Dictionary(uniqueKeysWithValues: map.map { ($0.key.rawValue, $0.value) })),
      let mapJSON = String(data: mapData, encoding: .utf8)
    else { return }

    let mapping = CSVImportMapping(
      name: mappingName,
      headerFingerprint: mappingService.fingerprint(headers: mappingHeaders),
      delimiter: mappingDelimiter,
      dateFormat: mappingDateFormat,
      fieldMapJSON: mapJSON,
      isDefault: mappingSetAsDefault
    )
    let parsed = mappingService.parseWithMapping(csvString: selectedCSVString, mapping: mapping)
    mappingPreview = parsed.transactions
    mappingInvalidRows = parsed.invalidRows
  }

  private func saveMappingAndRetryImport() {
    guard let data = selectedCSVData, let fileName = selectedCSVFileName else { return }

    let map: [String: String] = [
      CSVImportField.date.rawValue: mapDateHeader,
      CSVImportField.merchant.rawValue: mapMerchantHeader,
      CSVImportField.amount.rawValue: mapAmountHeader,
      CSVImportField.currency.rawValue: mapCurrencyHeader,
    ].filter { !$0.value.isEmpty }

    guard
      let mapData = try? JSONEncoder().encode(map),
      let mapJSON = String(data: mapData, encoding: .utf8)
    else { return }

    if mappingSetAsDefault {
      for existing in mappings where existing.isDefault {
        existing.isDefault = false
      }
    }

    let mapping = CSVImportMapping(
      name: mappingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? "Custom Mapping" : mappingName,
      headerFingerprint: mappingService.fingerprint(headers: mappingHeaders),
      delimiter: mappingDelimiter,
      dateFormat: mappingDateFormat,
      fieldMapJSON: mapJSON,
      isDefault: mappingSetAsDefault
    )
    modelContext.insert(mapping)

    do {
      try modelContext.save()
      importResult = importService.importCSV(
        csvData: data,
        fileName: fileName,
        existingExpenses: existingExpenses,
        existingTemplates: existingTemplates,
        context: modelContext
      )
      if let result = importResult {
        for suggestion in result.suggestions where suggestion.confidence > 0.8 {
          selectedSuggestions.insert(suggestion.id)
        }
      }
      showingMappingEditor = false
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func toggleSuggestion(_ id: UUID) {
    if selectedSuggestions.contains(id) {
      selectedSuggestions.remove(id)
    } else {
      selectedSuggestions.insert(id)
    }
  }

  private func importSelectedTemplates(result: CSVImportResult) {
    let selected = result.suggestions.filter { selectedSuggestions.contains($0.id) }

    // Apply custom frequencies
    var modifiedSuggestions = selected
    for (index, suggestion) in modifiedSuggestions.enumerated() {
      if let customFreq = customFrequencies[suggestion.id] {
        modifiedSuggestions[index] = TemplateSuggestion(
          merchant: suggestion.merchant,
          amount: suggestion.amount,
          frequency: customFreq,
          occurrences: suggestion.occurrences,
          categories: suggestion.categories,
          suggestedAmount: suggestion.suggestedAmount,
          confidence: suggestion.confidence,
          isIncome: suggestion.isIncome
        )
      }
    }

    // Create templates
    _ = importService.createTemplates(from: modifiedSuggestions, context: modelContext)

    // Import all transactions
    importAllTransactions(result: result)
  }

  private func importAllTransactions(result: CSVImportResult) {
    for transaction in result.transactions {
      _ = importService.createExpense(from: transaction, context: modelContext)
    }

    do {
      try modelContext.save()
    } catch {
      ErrorPresenter.presentOnMain(error)
    }
    dismiss()
  }
}

// MARK: - Supporting Views

struct StatCard: View {
  let title: String
  let value: String
  let icon: String
  let color: Color

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundColor(color)

      Text(value)
        .font(.title.bold())
        .foregroundColor(.primary)

      Text(title)
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
}

#Preview {
  CSVImportView()
}
