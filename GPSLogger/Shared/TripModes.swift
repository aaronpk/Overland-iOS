//
//  TripModes.swift
//  Overland
//
//  The list of trip modes, in the order the picker shows them. A mode's ID identifies it inside the
//  app (the current mode, stats, Shortcuts, widgets), so it never changes once a mode exists. Servers
//  receive its server value, which is the ID unless the user changed it.
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
    // What servers receive as trip_mode and as the trip's mode, or nil to send the ID
    var serverValue: String? = nil

    static let defaults: [TripMode] = [
        // On foot
        TripMode(id: "walk", name: "Walk", symbol: "overland.walk", closeZoom: true, synonyms: ["Walking"], healthWorkout: "walking"),
        TripMode(id: "run", name: "Run", symbol: "overland.run", closeZoom: true, synonyms: ["Running", "Jog"], healthWorkout: "running"),
        TripMode(id: "hike", name: "Hike", symbol: "overland.hike", closeZoom: true, synonyms: ["Hiking"], healthWorkout: "hiking"),
        // Small wheels
        TripMode(id: "bicycle", name: "Bicycle", symbol: "overland.bicycle", closeZoom: true, synonyms: ["Bike", "Cycling", "Cycle"], healthWorkout: "cycling"),
        TripMode(id: "ebike", name: "E-Bike", symbol: "overland.ebike", closeZoom: true, synonyms: ["Ebike", "Electric Bike", "Electric Bicycle"]),
        TripMode(id: "scooter", name: "Scooter", symbol: "overland.scooter", closeZoom: true),
        TripMode(id: "skate", name: "Skate", symbol: "overland.skate", closeZoom: true, synonyms: ["Skating", "Ice Skating", "Roller Skating"], healthWorkout: "skating"),
        // Snow
        TripMode(id: "ski", name: "Ski", symbol: "overland.ski", closeZoom: true, synonyms: ["Skiing"], healthWorkout: "downhillSkiing"),
        TripMode(id: "snowboard", name: "Snowboard", symbol: "overland.snowboard", closeZoom: true, synonyms: ["Snowboarding"], healthWorkout: "snowboarding"),
        TripMode(id: "sleigh", name: "Sleigh", symbol: "overland.sleigh", closeZoom: false),
        // Road
        TripMode(id: "car", name: "Car", symbol: "overland.car", closeZoom: false, synonyms: ["Drive", "Driving"]),
        TripMode(id: "taxi", name: "Taxi", symbol: "overland.taxi", closeZoom: false),
        TripMode(id: "bus", name: "Bus", symbol: "overland.bus", closeZoom: false),
        // Rail and cable
        TripMode(id: "tram", name: "Tram", symbol: "overland.tram", closeZoom: false, synonyms: ["Streetcar", "Light Rail"]),
        TripMode(id: "metro", name: "Metro", symbol: "overland.metro", closeZoom: false, synonyms: ["Subway", "Underground"]),
        TripMode(id: "train", name: "Train", symbol: "overland.train", closeZoom: false, synonyms: ["Rail"]),
        TripMode(id: "monorail", name: "Monorail", symbol: "overland.monorail", closeZoom: false),
        TripMode(id: "gondola", name: "Gondola", symbol: "overland.gondola", closeZoom: false, synonyms: ["Cable Car"]),
        TripMode(id: "funicular", name: "Funicular", symbol: "overland.funicular", closeZoom: false, synonyms: ["Incline", "Cliff Railway"]),
        // Water and air
        TripMode(id: "boat", name: "Boat", symbol: "overland.boat", closeZoom: false, synonyms: ["Ferry", "Sailing"]),
        TripMode(id: "plane", name: "Plane", symbol: "overland.plane", closeZoom: false, synonyms: ["Flight", "Flying"]),
    ]

    // The SF Symbols the built-in modes used before they had their own icons. A saved list that
    // still has one of these gets the mode's own icon instead.
    static let previousSymbols: [String: String] = [
        "walk": "figure.walk",
        "run": "figure.run",
        "hike": "figure.hiking",
        "bicycle": "bicycle",
        "ebike": "bicycle",
        "scooter": "scooter",
        "skate": "figure.skating",
        "ski": "figure.skiing.downhill",
        "snowboard": "figure.snowboarding",
        "sleigh": "snowflake",
        "car": "car.fill",
        "taxi": "car.fill",
        "bus": "bus.fill",
        "tram": "tram.fill",
        "metro": "tram.fill.tunnel",
        "train": "train.side.front.car",
        "monorail": "lightrail.fill",
        "gondola": "cablecar.fill",
        "boat": "sailboat.fill",
        "plane": "airplane",
    ]

    // The built-in modes before Hike, Ski, Snowboard and Skate were added, for lists saved before
    // the app started recording which built-in modes a saved list knew about
    static let originalIDs: Set<String> = ["walk", "run", "bicycle", "ebike", "car", "taxi", "bus", "tram", "train",
                                           "metro", "gondola", "monorail", "sleigh", "plane", "boat", "scooter"]
}

@objc(GLTripModeStore) final class TripModeStore: NSObject {
    private static let defaultsKey = "TripModes"
    // The IDs of the built-in modes when the list was last saved
    static let builtInIDsKey = "TripModesBuiltInIDs"
    // Used for a mode that isn't in the list, such as one deleted during a trip
    private static let unknownSymbol = "location.fill"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: SharedTripState.appGroup) }

    static var modes: [TripMode] {
        guard let data = defaults?.data(forKey: defaultsKey),
              let saved = try? JSONDecoder().decode([TripMode].self, from: data), !saved.isEmpty else {
            return TripMode.defaults
        }
        // Add built-in modes that are newer than the saved list. Ones the list knew about and
        // doesn't have were deleted, so they stay deleted.
        let known = defaults?.stringArray(forKey: builtInIDsKey).map(Set.init) ?? TripMode.originalIDs
        let savedIDs = Set(saved.map(\.id))
        // Built-in modes that still have the SF Symbol they used to have get their own icon
        let modes = saved.map { mode in
            guard TripMode.previousSymbols[mode.id] == mode.symbol,
                  let builtIn = TripMode.defaults.first(where: { $0.id == mode.id }) else { return mode }
            var updated = mode
            updated.symbol = builtIn.symbol
            return updated
        }
        return modes + TripMode.defaults.filter { !known.contains($0.id) && !savedIDs.contains($0.id) }
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

    // A mode removed during a trip keeps sending its ID
    @objc(serverValueForModeID:) static func serverValue(_ id: String) -> String {
        mode(id)?.serverValue ?? id
    }

    // For trip_mode in remote config: the mode that sends this value, or else the mode with this ID
    @objc(modeIDForServerValue:) static func modeID(serverValue value: String) -> String? {
        let modes = self.modes
        return (modes.first { ($0.serverValue ?? $0.id) == value } ?? modes.first { $0.id == value })?.id
    }

    @objc(symbolForModeID:) static func symbol(_ id: String) -> String {
        mode(id)?.symbol ?? unknownSymbol
    }

    // The built-in modes use the app's own symbols in TripModes.xcassets, made from Material Symbols,
    // which can be sent to servers. Their names start with "overland." so they're loaded from the
    // asset catalog. SF Symbols can't be sent, since their license only covers Apple platforms.
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
