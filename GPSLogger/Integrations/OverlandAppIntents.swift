//
//  OverlandAppIntents.swift
//  Overland
//
//  The intents only used from Shortcuts and Siri, and the phrases Siri recognizes. The trip
//  intents that widgets also use are in Shared/TripIntents.swift.
//

import AppIntents
import Foundation

@available(iOS 16.0, *)
struct SetTrackingIntent: AppIntent {
    static var title: LocalizedStringResource = "Turn Tracking On or Off"
    static var description = IntentDescription("Turns Overland's location tracking on or off. Turning it off doesn't end a trip in progress.")

    @Parameter(title: "Tracking", displayName: Bool.IntentDisplayName(true: "On", false: "Off"))
    var enabled: Bool

    init() {}

    init(enabled: Bool) {
        self.enabled = enabled
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Turn tracking \(\.$enabled)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager: GLManager = GLManager.shared()
        if enabled {
            manager.startAllUpdates()
        } else {
            manager.stopAllUpdates()
        }
        SharedStateObserver.shared.stateChanged()
        return .result(dialog: enabled ? "Overland is tracking your location." : "Overland stopped tracking your location.")
    }
}

@available(iOS 16.0, *)
struct GetTripStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Tracking Status"
    static var description = IntentDescription("Tells you whether Overland is tracking, the trip in progress, and how much data is waiting to be sent.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let manager: GLManager = GLManager.shared()
        var sentences: [String] = []

        if manager.tripInProgress() {
            sentences.append("A \(TripIntentText.tripSummary(manager)) is in progress.")
        } else {
            sentences.append(manager.trackingEnabled ? "Tracking is on." : "Tracking is off.")
        }

        let queued = await withCheckedContinuation { continuation in
            manager.numberOfLocations(inQueue: { count in
                continuation.resume(returning: count)
            })
        }
        sentences.append(queued == 1 ? "1 point is waiting to be sent." : "\(queued) points are waiting to be sent.")

        if let error = manager.lastSendErrorTitle {
            sentences.append("The last send failed: \(error).")
        } else if let lastSent = manager.lastSentDate {
            let formatter = RelativeDateTimeFormatter()
            sentences.append("Data was last sent \(formatter.localizedString(for: lastSent, relativeTo: Date())).")
        }

        let status = sentences.joined(separator: " ")
        return .result(value: status, dialog: IntentDialog(stringLiteral: status))
    }
}

@available(iOS 17.0, *)
struct OverlandShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTripIntent(),
            phrases: [
                "Start a trip in \(.applicationName)",
                "Start a \(\.$mode) trip in \(.applicationName)",
                "Start tracking a \(\.$mode) trip with \(.applicationName)",
            ],
            shortTitle: "Start Trip",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: EndTripIntent(),
            phrases: [
                "End my trip in \(.applicationName)",
                "End the \(.applicationName) trip",
                "Stop my trip in \(.applicationName)",
            ],
            shortTitle: "End Trip",
            systemImageName: "stop.circle"
        )
        AppShortcut(
            intent: SendNowIntent(),
            phrases: [
                "Send \(.applicationName) data now",
                "Send my location data with \(.applicationName)",
            ],
            shortTitle: "Send Now",
            systemImageName: "arrow.up.circle"
        )
        AppShortcut(
            intent: GetTripStatusIntent(),
            phrases: [
                "Is \(.applicationName) tracking",
                "Get the \(.applicationName) status",
            ],
            shortTitle: "Tracking Status",
            systemImageName: "location.circle"
        )
    }
}
