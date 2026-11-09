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
                        IfIslandIsWide {
                            Text(TripFormat.modeName(context.state.mode))
                                .font(.headline)
                        }
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
                            IfIslandIsWide {
                                TripStat(value: TripFormat.distance(context.state.distance), unit: TripFormat.distanceUnit)
                            }
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

// Leaves its content out when the Dynamic Island is narrower than usual (iOS 27), so the mode
// name and distance don't crowd out the time and speed
struct IfIslandIsWide<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 27.0, *) {
            NarrowIslandAware(content: content)
        } else {
            content
        }
    }
}

@available(iOS 27.0, *)
private struct NarrowIslandAware<Content: View>: View {
    @Environment(\.isDynamicIslandLimitedInWidth) private var limitedInWidth
    let content: Content

    var body: some View {
        if !limitedInWidth {
            content
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

// Sends the queued data now, or opens the app to end the trip, from the Lock Screen or Dynamic
// Island. Buttons in Live Activities need iOS 17.
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

                // Opens the app, which asks before ending the trip, so a stray tap can't end it
                Link(destination: URL(string: "overland://end-trip")!) {
                    Label("End Trip", systemImage: "stop.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(.red, in: Capsule())
                }
            }
        }
    }
}
