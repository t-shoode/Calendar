//
//  AppIntent.swift
//  CalendarWidget
//
//  Created by Taras Khanchuk on 04.02.2026.
//

import WidgetKit
import AppIntents

enum WidgetQuickAction: String, AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Quick Action"
    static let caseDisplayRepresentations: [WidgetQuickAction: DisplayRepresentation] = [
        .quickExpense: "Quick Expense",
        .quickTodo: "Quick Todo",
        .openSettings: "Open Settings",
    ]

    case quickExpense
    case quickTodo
    case openSettings
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Calendar Widget" }
    static var description: IntentDescription { "Configure default quick action for Calendar widget." }

    @Parameter(title: "Default action", default: .quickExpense)
    var quickAction: WidgetQuickAction
}
