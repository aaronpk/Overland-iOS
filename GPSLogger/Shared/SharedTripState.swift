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
    var tripMode = "bicycle"
    // Meters, as of updatedAt
    var tripDistance: Double = 0
    var queueCount = 0
    var lastSentDate: Date?
    // The title of the last send error, or nil if the last send succeeded
    var lastSendError: String?
    var updatedAt = Date()

    var tripInProgress: Bool { tripStart != nil }

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
