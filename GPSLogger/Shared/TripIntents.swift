//
//  TripIntents.swift
//  Overland
//
//  The trip actions for Shortcuts, Siri, widgets, controls and the Live Activity. This file is
//  compiled into the app and the widget extension, so the extension's buttons can refer to the
//  intents. On iOS 17+ they're LiveActivityIntents, which the system always runs in the app's
//  process, so the code that calls GLManager is only compiled into the app (OVERLAND_APP).
//

import AppIntents
import Foundation

// A trip mode in Shortcuts and Siri. It's an entity rather than an enum, so modes added in the app
// show up too. The query reads the modes from the App Group, so it works in both targets.
@available(iOS 17.0, *)
struct TripModeEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Trip Mode"
    static var defaultQuery = TripModeQuery()

    let id: String

    var displayRepresentation: DisplayRepresentation {
        let mode = TripModeStore.mode(id)
        return DisplayRepresentation(title: "\(mode?.name ?? id)",
                                     image: .init(systemName: TripModeStore.symbol(id)),
                                     synonyms: (mode?.synonyms ?? []).map { "\($0)" })
    }
}

@available(iOS 17.0, *)
struct TripModeQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [TripModeEntity] {
        identifiers.filter { TripModeStore.contains($0) }.map(TripModeEntity.init)
    }

    func suggestedEntities() async throws -> [TripModeEntity] {
        TripModeStore.modes.map { TripModeEntity(id: $0.id) }
    }

    // Matches the name, the ID or one of the synonyms, such as "bike" for Bicycle
    func entities(matching string: String) async throws -> [TripModeEntity] {
        let query = string.trimmingCharacters(in: .whitespaces).lowercased()
        return TripModeStore.modes
            .filter { mode in
                ([mode.name, mode.id] + mode.synonyms).contains { $0.lowercased() == query }
                    || mode.name.lowercased().contains(query)
            }
            .map { TripModeEntity(id: $0.id) }
    }
}

@available(iOS 17.0, *)
struct StartTripIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Trip"
    #if !OVERLAND_APP
    // The app lists this in Shortcuts. The extension's copy is only for its buttons.
    static var isDiscoverable: Bool { false }
    #endif
    static var description = IntentDescription("Starts a trip in Overland. Tracking turns on for the trip, and back off when the trip ends if it was off before.")

    @Parameter(title: "Mode", description: "Leave empty to use the last trip mode.")
    var mode: TripModeEntity?

    init() {}

    init(mode: TripModeEntity?) {
        self.mode = mode
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Start a \(\.$mode) trip")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        #if OVERLAND_APP
        let manager: GLManager = GLManager.shared()
        if manager.tripInProgress() {
            return .result(dialog: "A \(TripIntentText.modeName(manager.currentTripMode)) trip is already in progress.")
        }
        GLTripActions.startTrip(withMode: mode?.id)
        SharedStateObserver.shared.tripChanged(inProgress: true)
        return .result(dialog: "Started a \(TripIntentText.modeName(manager.currentTripMode)) trip.")
        #else
        return .result(dialog: "")
        #endif
    }
}

@available(iOS 17.0, *)
struct EndTripIntent: AppIntent {
    static var title: LocalizedStringResource = "End Trip"
    #if !OVERLAND_APP
    // The app lists this in Shortcuts. The extension's copy is only for its buttons.
    static var isDiscoverable: Bool { false }
    #endif
    static var description = IntentDescription("Ends the trip in progress in Overland.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        #if OVERLAND_APP
        let manager: GLManager = GLManager.shared()
        if !manager.tripInProgress() {
            return .result(dialog: "There's no trip in progress.")
        }
        let summary = TripIntentText.tripSummary(manager)
        GLTripActions.endTripRestoringTracking()
        SharedStateObserver.shared.tripChanged(inProgress: false)
        return .result(dialog: "Ended the \(summary).")
        #else
        return .result(dialog: "")
        #endif
    }
}

@available(iOS 17.0, *)
struct SendNowIntent: AppIntent {
    static var title: LocalizedStringResource = "Send Data Now"
    #if !OVERLAND_APP
    // The app lists this in Shortcuts. The extension's copy is only for its buttons.
    static var isDiscoverable: Bool { false }
    #endif
    static var description = IntentDescription("Sends the location data waiting in Overland's queue to your server or iCloud Drive now, instead of waiting for the send interval.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        #if OVERLAND_APP
        let manager: GLManager = GLManager.shared()
        if !manager.hasDestination() {
            return .result(dialog: "Overland doesn't have anywhere to send data yet. Set a server URL or choose iCloud Drive in Overland's settings.")
        }
        manager.sendQueueNow()
        return .result(dialog: "Sending Overland's data now.")
        #else
        return .result(dialog: "")
        #endif
    }
}

// The Control Center toggle. Shortcuts already has Start Trip and End Trip, so this one is hidden.
@available(iOS 18.0, *)
struct ToggleTripIntent: SetValueIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "Start or End Trip"
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Trip in Progress")
    var value: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        #if OVERLAND_APP
        if value {
            GLTripActions.startTrip(withMode: nil)
        } else {
            GLTripActions.endTripRestoringTracking()
        }
        SharedStateObserver.shared.tripChanged(inProgress: value)
        #endif
        return .result()
    }
}

// When an intent is tapped in a widget, a control or the Live Activity, these make the system run it
// in the app's process, where it can reach GLManager. Without them it would run in the extension.
@available(iOS 17.0, *)
extension StartTripIntent: LiveActivityIntent {}
@available(iOS 17.0, *)
extension EndTripIntent: LiveActivityIntent {}
@available(iOS 17.0, *)
extension SendNowIntent: LiveActivityIntent {}

#if OVERLAND_APP
enum TripIntentText {
    static func modeName(_ mode: String?) -> String {
        guard let mode = mode else { return "" }
        return TripModeStore.name(mode).lowercased()
    }

    // For example "bicycle trip (23 min, 4.2 km)"
    static func tripSummary(_ manager: GLManager) -> String {
        var parts: [String] = []
        let duration = DateComponentsFormatter()
        duration.allowedUnits = manager.currentTripDuration() >= 3600 ? [.hour, .minute] : [.minute]
        duration.unitsStyle = .short
        if let text = duration.string(from: manager.currentTripDuration()) {
            parts.append(text)
        }
        let meters = manager.currentTripDistance()
        if meters >= 0 {
            parts.append(distance(meters))
        }
        return "\(modeName(manager.currentTripMode)) trip (\(parts.joined(separator: ", ")))"
    }

    static func distance(_ meters: Double) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(from: Measurement(value: meters, unit: UnitLength.meters))
    }
}
#endif
