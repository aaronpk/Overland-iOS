//
//  OverlandAppIntents.swift
//  Overland
//
//  The intents only used from Shortcuts and Siri, and the phrases Siri recognizes. The trip
//  intents that widgets also use are in Shared/TripIntents.swift.
//

import AppIntents
import CoreLocation
import Foundation

@available(iOS 17.0, *)
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

@available(iOS 17.0, *)
struct SetTripModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Trip Mode"
    static var description = IntentDescription("Sets the mode for the next trip, without starting it. During a trip, it changes the mode of the trip in progress.")

    @Parameter(title: "Mode")
    var mode: TripModeEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Set the trip mode to \(\.$mode)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager: GLManager = GLManager.shared()
        manager.currentTripMode = mode.id
        SharedStateObserver.shared.stateChanged()
        let name = TripIntentText.modeName(mode.id)
        return .result(dialog: manager.tripInProgress() ? "Changed this trip to \(name)." : "The next trip will be \(name).")
    }
}

// The activity types in Trip Settings, which tell iOS how to track the trip
@available(iOS 17.0, *)
enum TripActivityTypeAppEnum: String, AppEnum {
    case other, car, fitness, navigation, airplane, boat

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Activity Type"

    static var caseDisplayRepresentations: [TripActivityTypeAppEnum: DisplayRepresentation] = [
        .other: "Other",
        .car: "Car",
        .fitness: "Fitness",
        .navigation: "Other Navigation",
        .airplane: "Airplane",
        .boat: "Boat",
    ]

    var activityType: CLActivityType? {
        switch self {
        case .other: return .other
        case .car: return .automotiveNavigation
        case .fitness: return .fitness
        case .navigation: return .otherNavigation
        case .airplane: return .airborne
        case .boat:
            if #available(iOS 27.0, *) {
                return .maritime
            }
            return nil
        }
    }
}

@available(iOS 17.0, *)
struct SetTripActivityTypeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Trip Activity Type"
    static var description = IntentDescription("Sets the activity type Overland gives iOS during trips, the same as in Trip Settings. It applies from the next trip.")

    @Parameter(title: "Activity Type")
    var activityType: TripActivityTypeAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Set the trip activity type to \(\.$activityType)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let type = activityType.activityType else {
            return .result(dialog: "The Boat activity type needs iOS 27 or later.")
        }
        GLManager.shared().activityTypeDuringTrip = type
        return .result(dialog: "Trips will use the \(String(localized: TripActivityTypeAppEnum.caseDisplayRepresentations[activityType]!.title)) activity type, starting with the next trip.")
    }
}

// The location accuracy choices in Trip Settings
@available(iOS 17.0, *)
enum TripAccuracyAppEnum: String, AppEnum {
    case navigation, best, tenMeters, hundredMeters, kilometer, threeKilometers

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Location Accuracy"

    static var caseDisplayRepresentations: [TripAccuracyAppEnum: DisplayRepresentation] = [
        .navigation: "Best for Navigation",
        .best: "Best",
        .tenMeters: "10 Meters",
        .hundredMeters: "100 Meters",
        .kilometer: "1 Kilometer",
        .threeKilometers: "3 Kilometers",
    ]

    var accuracy: CLLocationAccuracy {
        switch self {
        case .navigation: return kCLLocationAccuracyBestForNavigation
        case .best: return kCLLocationAccuracyBest
        case .tenMeters: return kCLLocationAccuracyNearestTenMeters
        case .hundredMeters: return kCLLocationAccuracyHundredMeters
        case .kilometer: return kCLLocationAccuracyKilometer
        case .threeKilometers: return kCLLocationAccuracyThreeKilometers
        }
    }
}

@available(iOS 17.0, *)
struct SetTripAccuracyIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Trip Location Accuracy"
    static var description = IntentDescription("Sets how accurate Overland's location tracking is during trips, the same as in Trip Settings. During a trip, it applies right away.")

    @Parameter(title: "Accuracy")
    var accuracy: TripAccuracyAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Set the trip location accuracy to \(\.$accuracy)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager: GLManager = GLManager.shared()
        manager.desiredAccuracyDuringTrip = accuracy.accuracy
        let name = String(localized: TripAccuracyAppEnum.caseDisplayRepresentations[accuracy]!.title)
        return .result(dialog: manager.tripInProgress() ? "This trip now uses \(name) accuracy." : "Trips will use \(name) accuracy.")
    }
}

@available(iOS 17.0, *)
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

    // Matches the app icon
    static var shortcutTileColor: ShortcutTileColor = .orange
}
