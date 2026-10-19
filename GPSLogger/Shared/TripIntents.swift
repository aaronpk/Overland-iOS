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

@available(iOS 16.0, *)
enum TripModeAppEnum: String, AppEnum {
    // The same identifiers as +[GLManager GLTripModes]
    case walk, run, bicycle, car, taxi, bus, tram, train, metro, gondola, monorail, sleigh, plane, boat, scooter

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Trip Mode"

    static var caseDisplayRepresentations: [TripModeAppEnum: DisplayRepresentation] = [
        .walk: DisplayRepresentation(title: "Walk", image: .init(named: "walk")),
        .run: DisplayRepresentation(title: "Run", image: .init(named: "run")),
        .bicycle: DisplayRepresentation(title: "Bicycle", image: .init(named: "bicycle")),
        .car: DisplayRepresentation(title: "Car", image: .init(named: "car")),
        .taxi: DisplayRepresentation(title: "Taxi", image: .init(named: "taxi")),
        .bus: DisplayRepresentation(title: "Bus", image: .init(named: "bus")),
        .tram: DisplayRepresentation(title: "Tram", image: .init(named: "tram")),
        .train: DisplayRepresentation(title: "Train", image: .init(named: "train")),
        .metro: DisplayRepresentation(title: "Metro", image: .init(named: "metro")),
        .gondola: DisplayRepresentation(title: "Gondola", image: .init(named: "gondola")),
        .monorail: DisplayRepresentation(title: "Monorail", image: .init(named: "monorail")),
        .sleigh: DisplayRepresentation(title: "Sleigh", image: .init(named: "sleigh")),
        .plane: DisplayRepresentation(title: "Plane", image: .init(named: "plane")),
        .boat: DisplayRepresentation(title: "Boat", image: .init(named: "boat")),
        .scooter: DisplayRepresentation(title: "Scooter", image: .init(named: "scooter")),
    ]
}

@available(iOS 16.0, *)
struct StartTripIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Trip"
    #if !OVERLAND_APP
    // The app lists this in Shortcuts. The extension's copy is only for its buttons.
    static var isDiscoverable: Bool { false }
    #endif
    static var description = IntentDescription("Starts a trip in Overland. Tracking turns on for the trip, and back off when the trip ends if it was off before.")

    @Parameter(title: "Mode", description: "Leave empty to use the last trip mode.")
    var mode: TripModeAppEnum?

    init() {}

    init(mode: TripModeAppEnum?) {
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
        GLTripActions.startTrip(withMode: mode?.rawValue)
        SharedStateObserver.shared.tripChanged(inProgress: true)
        return .result(dialog: "Started a \(TripIntentText.modeName(manager.currentTripMode)) trip.")
        #else
        return .result(dialog: "")
        #endif
    }
}

@available(iOS 16.0, *)
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

@available(iOS 16.0, *)
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
        if #available(iOS 16.0, *), let appMode = TripModeAppEnum(rawValue: mode) {
            return String(localized: TripModeAppEnum.caseDisplayRepresentations[appMode]!.title).lowercased()
        }
        return mode
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
