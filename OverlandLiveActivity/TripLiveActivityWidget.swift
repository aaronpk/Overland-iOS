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
                        TripActionButtons()
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
            TripActionButtons()
        }
        .padding()
    }
}

// Ends the trip, or sends the queued data now, from the Lock Screen or Dynamic Island. Buttons in
// Live Activities need iOS 17.
struct TripActionButtons: View {
    var body: some View {
        if #available(iOS 17.0, *) {
            HStack(spacing: 10) {
                Button(intent: SendNowIntent()) {
                    Label("Send Now", systemImage: "arrow.up")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.green)

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
}
