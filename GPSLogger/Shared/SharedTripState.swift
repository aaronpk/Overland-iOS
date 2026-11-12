//
//  SharedTripState.swift
//  Overland
//
//  A snapshot of the app's state for the widgets and controls. They run in the extension's
//  process and can't read the app's settings, so the app writes this to the App Group and the
//  extension reads it. Compiled into both targets.
//

import Foundation

struct SharedTripState: Codable, Equatable {
    static let appGroup = "group.com.aaronpk.overland"
    private static let defaultsKey = "SharedTripState"

    var trackingEnabled = false
    // Set while a trip is in progress
    var tripStart: Date?
    var tripMode = TripModeStore.defaultModeID
    // The mode that was selected before tripMode, for the widget's second Start button
    var previousTripMode: String?
    var updatedAt = Date()

    var tripInProgress: Bool { tripStart != nil }

    // The mode for the second Start button: the previous mode, or the first other mode until
    // there is one, such as right after installing, or if it was deleted
    var otherTripMode: String? {
        if let previous = previousTripMode, previous != tripMode, TripModeStore.contains(previous) {
            return previous
        }
        return TripModeStore.modes.first { $0.id != tripMode }?.id
    }

    // When the mode changed since the old state, the old mode becomes the previous one
    mutating func keepPreviousTripMode(from old: SharedTripState) {
        let previous = old.tripMode != tripMode ? old.tripMode : old.previousTripMode
        previousTripMode = previous != tripMode ? previous : nil
    }

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func read() -> SharedTripState {
        guard let data = defaults?.data(forKey: defaultsKey),
              let state = try? JSONDecoder().decode(SharedTripState.self, from: data) else {
            return SharedTripState()
        }
        return state
    }

    func write() {
        if let data = try? JSONEncoder().encode(self) {
            SharedTripState.defaults?.set(data, forKey: SharedTripState.defaultsKey)
        }
    }
}
