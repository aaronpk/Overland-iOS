//
//  TripViews.swift
//  OverlandLiveActivity
//
//  Views and formatting shared by the Live Activity, the widgets and the controls.
//

import SwiftUI

struct TripModeIcon: View {
    let mode: String

    var body: some View {
        Image(systemName: TripModeStore.symbol(mode))
            .resizable()
            .scaledToFit()
            .foregroundStyle(.green)
    }
}

// Counts up from the trip start without needing updates from the app
struct ElapsedTime: View {
    let start: Date

    var body: some View {
        Text(timerInterval: start...Date.distantFuture, countsDown: false)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
    }
}

struct TripStat: View {
    let value: String
    let unit: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// Matches the units and formatting in TrackingViewController
enum TripFormat {
    static var usesMetricSystem: Bool {
        (NSLocale.current as NSLocale).object(forKey: .usesMetricSystem) as? Bool ?? true
    }

    static var distanceUnit: String { usesMetricSystem ? "km" : "mi" }
    static var speedUnit: String { usesMetricSystem ? "km/h" : "mph" }

    static func modeName(_ mode: String) -> String {
        TripModeStore.name(mode)
    }

    static func distance(_ meters: Double) -> String {
        let distance = meters * (usesMetricSystem ? 0.001 : 0.000621371)
        let format: String
        if distance >= 1000 {
            format = "%0.0f"
        } else if distance >= 100 {
            format = "%0.1f"
        } else {
            format = "%0.2f"
        }
        return String(format: format, distance)
    }

    static func speed(_ metersPerSecond: Double) -> String {
        let speed = Int((metersPerSecond * (usesMetricSystem ? 3.6 : 2.23694)).rounded())
        return String(max(speed, 0))
    }
}
