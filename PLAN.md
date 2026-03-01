# Plan: Implement 15 High‑Fit Features (Phased MVP)

**Summary**
- Deliver all 15 features in three phases, each with an MVP scope and clear data models, UI entry points, and services.
- Integrations in scope: Siri/Shortcuts, iCal export, OCR, live FX rates, CSV mapping.
- SwiftData schema changes allowed with migrations.

**Public API / Interface Changes**
- New SwiftData models for: budgets, forecasts, FX rates, shared groups, receipts, attachments, rules, dashboard configs, import mappings, notification prefs.
- New services: `FXRateService`, `BudgetService`, `ForecastService`, `ReceiptOCRService`, `CalendarExportService`, `ShortcutService`, `DuplicateDetectionService`, `ExpenseSplitService`, `NotificationPrefsService`, `CSVMappingService`.
- New view models and views for each feature area (listed below).

---

## Phase 1 (Core Financial Value)

### 1) Budget Limits by Category with Alerts
**MVP**
- Set monthly budget per category.
- Alert when ≥80% and 100% crossed.
**Data**
- `BudgetLimit` model: `id`, `categoryId`, `amountUAH`, `period` (monthly), `createdAt`, `updatedAt`.
**UI**
- Budget tab: new “Budgets” section and edit sheet.
- Per-category progress bar.
**Logic**
- Aggregate expenses in UAH per category for period.
- Schedule local notifications on threshold crossing.
**Tests**
- Budget threshold crossing logic.
- UAH conversion applied to totals.

### 2) Cashflow Forecast (30/60/90 days)
**MVP**
- Forecast from recurring expenses + known scheduled expenses.
- Display daily and monthly totals.
**Data**
- `CashflowForecastCache`: `startDate`, `endDate`, `dailyItems`.
**UI**
- New “Forecast” screen under Expenses.
**Logic**
- Use recurring templates + existing future expenses.
- Summarize per day and per month in UAH.
**Tests**
- Forecast generation includes recurring.
- UAH conversion.

### 3) Duplicate Detection + Merge Suggestions
**MVP**
- Detect near-duplicate expenses (date, amount tolerance, merchant fuzzy match).
- Show merge suggestions; allow dismiss.
**Data**
- `DuplicateSuggestion` model: `expenseIdA`, `expenseIdB`, `score`, `status`.
**UI**
- Banner + list in Expenses with actions.
**Logic**
- Reuse `PatternDetectionService` normalization.
**Tests**
- Scoring thresholds.
- Merge action results.

### 4) Multi‑Currency Live Rates (with Manual Override)
**MVP**
- Fetch live FX daily; allow manual override in settings.
**Data**
- `FXRate` model: `currency`, `rateToUAH`, `source`, `updatedAt`.
**UI**
- Settings: FX rates list, manual override toggle.
**Logic**
- `FXRateService` fetches daily and caches; conversion uses override if set.
**Tests**
- Conversion uses latest rate or override.
- Offline fallback.

---

## Phase 2 (Workflow Efficiency)

### 5) Bulk Edit for Expenses and Templates
**MVP**
- Multi-select expenses/templates; apply category, notes, payment method, tag.
**UI**
- Selection mode in Expenses/Recurring lists.
**Logic**
- Batch updates via SwiftData context.
**Tests**
- Batch update correctness and no partial updates on failure.

### 6) Advanced Recurring Rules
**MVP**
- Add rules: “last business day”, “first Monday”, “nth weekday”.
**Data**
- Extend `RecurringExpenseTemplate` with `ruleType`, `ruleParams`.
**Logic**
- Enhance recurrence generator to support rule types.
**UI**
- Rule picker in Add/Edit Template.
**Tests**
- Rule date computation for edge months.

### 7) Notification Controls per Template
**MVP**
- Per-template toggle and preferred notify time.
**Data**
- Extend `RecurringExpenseTemplate` with `notifyEnabled`, `notifyTime`.
**Logic**
- Scheduling respects template settings.
**UI**
- Toggle/time in template edit.
**Tests**
- Notifications skipped when disabled.

### 8) CSV Import Mapping + Validation Preview
**MVP**
- User maps CSV columns to fields and previews parsed rows.
**Data**
- `CSVImportMapping` model: `name`, `fieldMap`, `delimiter`, `dateFormat`.
**UI**
- Mapping wizard before import.
**Logic**
- `CSVMappingService` applies mapping; preview first N rows.
**Tests**
- Mapping parse accuracy.

### 9) Quick Add via Siri/App Shortcuts
**MVP**
- Add expense and add todo shortcuts.
**Integration**
- App Intents or Siri Shortcuts.
**UI**
- Settings: enable + examples.
**Tests**
- Intent handling creates items correctly.

---

## Phase 3 (Delight + Collaboration)

### 10) Receipt Attachments + OCR
**MVP**
- Attach photo/PDF to expense; extract merchant, amount, date.
**Data**
- `ReceiptAttachment` model: `expenseId`, `fileURL`, `ocrData`, `createdAt`.
**UI**
- Expense detail: attach and review OCR.
**Logic**
- `ReceiptOCRService` using Vision framework.
**Tests**
- OCR parsing validation with fixtures.

### 11) Expense Split & Shared Groups
**MVP**
- Split expense among participants with balances.
**Data**
- `SharedGroup`, `GroupMember`, `SplitExpense`, `SplitShare`.
**UI**
- Group management and expense split editor.
**Logic**
- Balance calculation per member.
**Tests**
- Split calculations and rounding.

### 12) Spending Goals & Streaks
**MVP**
- Monthly goal per category; streak when under limit.
**Data**
- `SpendingGoal` model and streak counter.
**UI**
- Progress + streak badge in Insights.
**Logic**
- Monthly check on period end.
**Tests**
- Streak reset and continuation.

### 13) Custom Analytics Dashboards
**MVP**
- User can add widgets: totals, category pie, trend line.
**Data**
- `DashboardConfig` model.
**UI**
- Drag‑reorderable cards.
**Logic**
- Saved layout restored on launch.
**Tests**
- Config serialization.

### 14) Calendar Sync for Expenses (iCal Export)
**MVP**
- Export upcoming recurring expenses to iCal file.
**Integration**
- `CalendarExportService` to generate `.ics`.
**UI**
- Share/export button.
**Tests**
- iCal format validity.

### 15) Expense Split + Shared Expenses Notifications
**MVP**
- Notify group members when balance changes.
**Integration**
- Local notifications for now; remote later.
**Tests**
- Notification conditions.

---

## Cross‑Cutting Implementation Details

**Data Migration**
- Add new SwiftData models and modify existing templates/expenses.
- Provide migration helpers to set defaults.

**Services**
- Add new services with clear boundaries:
  - `FXRateService` (fetch/cache/override)
  - `BudgetService` (thresholds, summaries)
  - `ForecastService` (future series)
  - `ReceiptOCRService` (Vision)
  - `CalendarExportService` (ICS)
  - `CSVMappingService` (import)
  - `DuplicateDetectionService` (merge)
  - `NotificationPrefsService` (template‑level settings)

**UI Entry Points**
- Expenses tab: Budgets, Forecast, Duplicates, Bulk Edit, Dashboard.
- Settings: FX rates, Shortcuts, CSV Mapping.
- Expense detail: Attachments, Split.

---

## Tests and Scenarios

**Unit tests**
1. FX rate conversion with overrides.
2. Budget threshold notifications.
3. Recurring rules date generation.
4. Forecast computation with recurring + manual.
5. Duplicate scoring and merge.

**Integration tests**
1. CSV mapping preview.
2. OCR attach + parse.
3. Shortcuts intent creation.

**Manual QA**
1. Create budgets and cross thresholds.
2. Generate forecast for 30/60/90 days.
3. Validate multi‑currency conversions.
4. Export iCal and import into Calendar.
5. Attach receipt and confirm OCR fields.

---

## Assumptions and Defaults
- UAH is the base currency.
- OCR uses Vision on-device.
- CSV mapping supports common delimiters and date formats.
- iCal export is one‑way (no sync‑back in MVP).
- Shared groups are local-only MVP (no cloud sync yet).

