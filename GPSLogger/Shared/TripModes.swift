//
//  TripModes.swift
//  Overland
//
//  The list of trip modes, in the order the picker shows them. A mode's ID is what servers receive
//  as trip_mode, so it never changes once a mode exists; the name and symbol are only for display.
//  The list is stored in the App Group so the widget extension can show names and symbols.
//  Compiled into both targets.
//

import Foundation
import UIKit

struct TripMode: Codable, Equatable {
    let id: String
    var name: String
    // An SF Symbol name, or one of the custom symbols in TripModes.xcassets
    var symbol: String
    // The Tracker map zooms in closer for slower modes
    var closeZoom: Bool
    // Other names Siri and Shortcuts accept for this mode
    var synonyms: [String] = []
    // The Apple Health workout this mode's trips are saved as, a key in HealthWorkout.all, or nil
    var healthWorkout: String? = nil

    static let defaults: [TripMode] = [
        TripMode(id: "walk", name: "Walk", symbol: "figure.walk", closeZoom: true, synonyms: ["Walking", "Hike"], healthWorkout: "walking"),
        TripMode(id: "run", name: "Run", symbol: "figure.run", closeZoom: true, synonyms: ["Running", "Jog"], healthWorkout: "running"),
        TripMode(id: "bicycle", name: "Bicycle", symbol: "bicycle", closeZoom: true, synonyms: ["Bike", "Cycling", "Cycle"], healthWorkout: "cycling"),
        TripMode(id: "ebike", name: "E-Bike", symbol: "overland.ebike", closeZoom: true, synonyms: ["Ebike", "Electric Bike", "Electric Bicycle"]),
        TripMode(id: "car", name: "Car", symbol: "car.fill", closeZoom: false, synonyms: ["Drive", "Driving"]),
        TripMode(id: "taxi", name: "Taxi", symbol: "overland.taxi", closeZoom: false),
        TripMode(id: "bus", name: "Bus", symbol: "bus.fill", closeZoom: false),
        TripMode(id: "tram", name: "Tram", symbol: "tram.fill", closeZoom: false, synonyms: ["Streetcar", "Light Rail"]),
        TripMode(id: "train", name: "Train", symbol: "train.side.front.car", closeZoom: false, synonyms: ["Rail"]),
        TripMode(id: "metro", name: "Metro", symbol: "tram.fill.tunnel", closeZoom: false, synonyms: ["Subway", "Underground"]),
        TripMode(id: "gondola", name: "Gondola", symbol: "cablecar.fill", closeZoom: false, synonyms: ["Cable Car"]),
        TripMode(id: "monorail", name: "Monorail", symbol: "lightrail.fill", closeZoom: false),
        TripMode(id: "sleigh", name: "Sleigh", symbol: "snowflake", closeZoom: false),
        TripMode(id: "plane", name: "Plane", symbol: "airplane", closeZoom: false, synonyms: ["Flight", "Flying"]),
        TripMode(id: "boat", name: "Boat", symbol: "sailboat.fill", closeZoom: false, synonyms: ["Ferry", "Sailing"]),
        TripMode(id: "scooter", name: "Scooter", symbol: "scooter", closeZoom: true),
    ]
}

@objc(GLTripModeStore) final class TripModeStore: NSObject {
    private static let defaultsKey = "TripModes"
    // Used for a mode that isn't in the list, such as one deleted during a trip
    private static let unknownSymbol = "location.fill"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: SharedTripState.appGroup) }

    static var modes: [TripMode] {
        guard let data = defaults?.data(forKey: defaultsKey),
              let modes = try? JSONDecoder().decode([TripMode].self, from: data), !modes.isEmpty else {
            return TripMode.defaults
        }
        return modes
    }

    static func mode(_ id: String?) -> TripMode? {
        modes.first { $0.id == id }
    }

    @objc static var allModeIDs: [String] {
        modes.map(\.id)
    }

    // The mode used when none has been chosen yet, or the chosen one was removed
    @objc static var defaultModeID: String {
        contains("bicycle") ? "bicycle" : modes[0].id
    }

    @objc(containsModeID:) static func contains(_ id: String?) -> Bool {
        mode(id) != nil
    }

    @objc(nameForModeID:) static func name(_ id: String) -> String {
        mode(id)?.name ?? id
    }

    @objc(symbolForModeID:) static func symbol(_ id: String) -> String {
        mode(id)?.symbol ?? unknownSymbol
    }

    // SF Symbols has no e-bike or taxi, so TripModes.xcassets has custom symbols for those.
    // Their names start with "overland." so they're loaded from the asset catalog.
    @objc(isCustomSymbol:) static func isCustomSymbol(_ symbol: String) -> Bool {
        symbol.hasPrefix("overland.")
    }

    @objc(imageForSymbol:) static func image(symbol: String) -> UIImage? {
        isCustomSymbol(symbol) ? UIImage(named: symbol) : UIImage(systemName: symbol)
    }

    @objc(closeZoomForModeID:) static func closeZoom(_ id: String) -> Bool {
        mode(id)?.closeZoom ?? false
    }

    static func healthWorkout(_ id: String) -> String? {
        mode(id)?.healthWorkout
    }
}
