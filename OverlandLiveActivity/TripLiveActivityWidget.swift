//
//  TripLiveActivityWidget.swift
//  OverlandLiveActivity
//

import ActivityKit
import SwiftUI
import WidgetKit

struct TripLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            TripLockScreenView(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        TripModeIcon(mode: context.state.mode)
                            .frame(width: 24, height: 24)
                        Text(TripFormat.modeName(context.state.mode))
                            .font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TripStat(value: TripFormat.speed(context.state.speed), unit: TripFormat.speedUnit)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        HStack {
                            ElapsedTime(start: context.attributes.tripStart)
                                .font(.title2.bold())
                            Spacer()
                            TripStat(value: TripFormat.distance(context.state.distance), unit: TripFormat.distanceUnit)
                        }
                        EndTripButton()
                    }
                }
            } compactLeading: {
                TripModeIcon(mode: context.state.mode)
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                ElapsedTime(start: context.attributes.tripStart)
                    .frame(maxWidth: 56)
            } minimal: {
                TripModeIcon(mode: context.state.mode)
                    .frame(width: 20, height: 20)
            }
        }
    }
}

struct TripLockScreenView: View {
    let attributes: TripActivityAttributes
    let state: TripActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                TripModeIcon(mode: state.mode)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(TripFormat.modeName(state.mode))
                        .font(.headline)
                    ElapsedTime(start: attributes.tripStart)
                        .font(.title2.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    TripStat(value: TripFormat.distance(state.distance), unit: TripFormat.distanceUnit)
                    TripStat(value: TripFormat.speed(state.speed), unit: TripFormat.speedUnit)
                }
            }
            EndTripButton()
        }
        .padding()
    }
}

// Ends the trip from the Lock Screen or Dynamic Island. Buttons in Live Activities need iOS 17.
struct EndTripButton: View {
    var body: some View {
        if #available(iOS 17.0, *) {
            Button(intent: EndTripIntent()) {
                Label("End Trip", systemImage: "stop.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }
}

struct TripModeIcon: View {
    let mode: String

    var body: some View {
        Image(mode)
            .renderingMode(.template)
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
        mode.capitalized
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
