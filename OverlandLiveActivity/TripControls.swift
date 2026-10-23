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

@available(iOS 18.0, *)
struct TripControl: ControlWidget {
    struct Value {
        var tripInProgress: Bool
        var mode: String
    }

    struct Provider: ControlValueProvider {
        var previewValue: Value {
            Value(tripInProgress: false, mode: TripModeStore.defaultModeID)
        }

        func currentValue() async throws -> Value {
            let state = SharedTripState.read()
            return Value(tripInProgress: state.tripInProgress, mode: state.tripMode)
        }
    }

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.aaronpk.overland.TripControl", provider: Provider()) { value in
            ControlWidgetToggle(isOn: value.tripInProgress, action: ToggleTripIntent()) {
                Label { Text("Trip") } icon: { Image(tripMode: value.mode) }
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
