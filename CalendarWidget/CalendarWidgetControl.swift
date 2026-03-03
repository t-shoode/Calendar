//
//  CalendarWidgetControl.swift
//  CalendarWidget
//
//  Created by Taras Khanchuk on 04.02.2026.
//

import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct CalendarWidgetControl: ControlWidget {
    static let kind: String = "Shoode.Calendar.CalendarWidget"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "Start Timer",
                isOn: value.isRunning,
                action: StartTimerIntent(value.name)
            ) { isRunning in
                Label(isRunning ? "On" : "Off", systemImage: "timer")
            }
        }
        .displayName("Timer")
        .description("A an example control that runs a timer.")
    }
}

extension CalendarWidgetControl {
    struct Value {
        var isRunning: Bool
        var name: String
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: TimerConfiguration) -> Value {
            CalendarWidgetControl.Value(isRunning: false, name: configuration.timerName)
        }

        func currentValue(configuration: TimerConfiguration) async throws -> Value {
            let defaults = UserDefaults(suiteName: "group.com.shoode.calendar") ?? .standard
            let isRunning = defaults.bool(forKey: "countdown.isRunning")
            return CalendarWidgetControl.Value(isRunning: isRunning, name: configuration.timerName)
        }
    }
}

struct TimerConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Timer Name Configuration"

    @Parameter(title: "Timer Name", default: "Timer")
    var timerName: String
}

struct StartTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Start a timer"

    @Parameter(title: "Timer Name")
    var name: String

    @Parameter(title: "Timer is running")
    var value: Bool

    init() {}

    init(_ name: String) {
        self.name = name
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.shoode.calendar") ?? .standard

        if value {
            let payload = ShortcutPayload(kind: "startTimer", amount: 300)
            if let data = try? JSONEncoder().encode(payload) {
                defaults.set(data, forKey: "shortcuts.pending.action")
            }
            defaults.set(true, forKey: "hasActiveTimer")
        } else {
            defaults.set(false, forKey: "countdown.isRunning")
            defaults.set(false, forKey: "hasActiveTimer")
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "CalendarWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "CombinedWidget")
        return .result()
    }
}

private struct ShortcutPayload: Codable {
    let kind: String
    let title: String? = nil
    let amount: Double?
    let merchant: String? = nil
    let notes: String? = nil
    let targetTab: String? = nil
}
