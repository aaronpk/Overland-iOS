//
//  TripControls.swift
//  OverlandLiveActivity
//
//  Controls for Control Center, the Lock Screen and the Action button (iOS 18+). They read the
//  trip state the app shares in the App Group, and their intents run in the app.
//

import AppIntents
import SwiftUI
import WidgetKit

// Controls can only show symbol images, so each trip mode has an SF Symbol
enum TripModeSymbol {
    static func name(_ mode: String) -> String {
        switch mode {
        case "walk": return "figure.walk"
        case "run": return "figure.run"
        case "bicycle": return "bicycle"
        case "car", "taxi": return "car.fill"
        case "bus": return "bus.fill"
        case "tram": return "tram.fill"
        case "train": return "train.side.front.car"
        case "metro": return "tram.fill.tunnel"
        case "gondola": return "cablecar.fill"
        case "monorail": return "lightrail.fill"
        case "sleigh": return "snowflake"
        case "plane": return "airplane"
        case "boat": return "sailboat.fill"
        case "scooter": return "scooter"
        default: return "location.fill"
        }
    }
}

@available(iOS 18.0, *)
struct TripControl: ControlWidget {
    struct Value {
        var tripInProgress: Bool
        var mode: String
    }

    struct Provider: ControlValueProvider {
        var previewValue: Value {
            Value(tripInProgress: false, mode: "bicycle")
        }

        func currentValue() async throws -> Value {
            let state = SharedTripState.read()
            return Value(tripInProgress: state.tripInProgress, mode: state.tripMode)
        }
    }

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.aaronpk.overland.TripControl", provider: Provider()) { value in
            ControlWidgetToggle(isOn: value.tripInProgress, action: ToggleTripIntent()) {
                Label("Trip", systemImage: TripModeSymbol.name(value.mode))
            } valueLabel: { isOn in
                Text(isOn ? "\(TripFormat.modeName(value.mode)) Trip" : "Start \(TripFormat.modeName(value.mode))")
            }
            .tint(.green)
        }
        .displayName("Overland Trip")
        .description("Starts a trip in the last trip mode, or ends the trip in progress.")
    }
}

@available(iOS 18.0, *)
struct SendNowControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.aaronpk.overland.SendNowControl") {
            ControlWidgetButton(action: SendNowIntent()) {
                Label("Send Now", systemImage: "arrow.up.circle")
            }
        }
        .displayName("Send Overland Data")
        .description("Sends the location data waiting in Overland's queue now.")
    }
}
