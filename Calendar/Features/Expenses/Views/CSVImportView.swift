import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct CSVImportView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  @Query(sort: \Expense.date) private var existingExpenses: [Expense]
  @Query(sort: \RecurringExpenseTemplate.createdAt) private var existingTemplates:
    [RecurringExpenseTemplate]

  @State private var showingFilePicker = false
  @State private var importResult: CSVImportResult?
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var selectedSuggestions: Set<UUID> = []
  @State private var customFrequencies: [UUID: ExpenseFrequency] = [:]

  private let importService = CSVImportService()

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

        DispatchQueue.main.async {
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
