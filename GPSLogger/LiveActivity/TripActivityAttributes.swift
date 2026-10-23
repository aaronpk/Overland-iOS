//
//  TripActivityAttributes.swift
//  Overland
//
//  Shared by the app and the OverlandLiveActivity widget extension.
//

import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct TripActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        // Trip mode ID, see TripModeStore
        var mode: String
        // Meters
        var distance: Double
        // Meters per second, never negative
        var speed: Double
    }

    var tripStart: Date
}
