//
//  StatusWidget.swift
//  OverlandLiveActivity
//
//  A Home Screen and Lock Screen widget showing whether Overland is tracking, or the trip in
//  progress. It reads the state the app shares in the App Group, and the app reloads it when the
//  state changes. It only shows what stays the same until the app reloads it, or counts up on its
//  own like the trip timer. The app can only reload it every so often from the background, so
//  anything else, like the distance or the last send, looks stuck next to the timer.
//

import AppIntents
import SwiftUI
import WidgetKit

struct StatusEntry: TimelineEntry {
    let date: Date
    let state: SharedTripState
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        var state = SharedTripState()
        state.trackingEnabled = true
        return StatusEntry(date: Date(), state: state)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : StatusEntry(date: Date(), state: SharedTripState.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        // The timer updates on its own. The app reloads the widget when anything else changes,
        // and this picks up anything that was missed.
        let entry = StatusEntry(date: Date(), state: SharedTripState.read())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
    }
}

struct StatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.aaronpk.overland.StatusWidget", provider: StatusProvider()) { entry in
            StatusWidgetView(state: entry.state)
                .widgetBackground()
        }
        .configurationDisplayName("Overland")
        .description("Shows whether Overland is tracking, or the trip in progress.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct StatusWidgetView: View {
    @Environment(\.widgetFamily) var family
    let state: SharedTripState

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        default:
            VStack(alignment: .leading, spacing: 10) {
                status
                TripButton(state: state)
            }
        }
    }

    // The trip and its timer, or whether tracking is on
    private var status: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if state.tripInProgress {
                    TripModeIcon(mode: state.tripMode)
                        .frame(width: 22, height: 22)
                    Text(TripFormat.modeName(state.tripMode))
                        .font(.headline)
                        .lineLimit(1)
                } else {
                    Image(systemName: state.trackingEnabled ? "location.fill" : "location.slash")
                        .foregroundStyle(state.trackingEnabled ? .green : .secondary)
                    Text(state.trackingEnabled ? "Tracking" : "Not Tracking")
                        .font(.headline)
                        .lineLimit(1)
                }
            }
            // On a tinted Home Screen, the header and buttons take the tint color
            .widgetAccentable()
            if let start = state.tripStart {
                ElapsedTime(start: start, alignment: .leading)
                    .font(.title2.bold())
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let start = state.tripStart {
                Label { Text(TripFormat.modeName(state.tripMode)) } icon: { Image(tripMode: state.tripMode) }
                    .font(.headline)
                ElapsedTime(start: start, alignment: .leading)
            } else {
                Label(state.trackingEnabled ? "Tracking" : "Not Tracking",
                      systemImage: state.trackingEnabled ? "location.fill" : "location.slash")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                if let start = state.tripStart {
                    Image(tripMode: state.tripMode)
                    Text(start, style: .timer)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                } else {
                    Image(systemName: state.trackingEnabled ? "location.fill" : "location.slash")
                }
            }
            .padding(4)
        }
    }

    @ViewBuilder
    private var inline: some View {
        if let start = state.tripStart {
            Label {
                Text(start, style: .timer)
            } icon: {
                Image(tripMode: state.tripMode)
            }
        } else {
            Label(state.trackingEnabled ? "Tracking" : "Not tracking",
                  systemImage: state.trackingEnabled ? "location.fill" : "location.slash")
        }
    }
}

// Ends the trip in progress, or starts one in the app's selected trip mode or the mode used before
// it. Buttons in widgets need iOS 17.
struct TripButton: View {
    let state: SharedTripState

    var body: some View {
        if #available(iOS 17.0, *) {
            if state.tripInProgress {
                Button(intent: EndTripIntent()) {
                    Label("End Trip", systemImage: "stop.fill")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .widgetAccentable()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                VStack(spacing: 6) {
                    StartTripButton(mode: state.tripMode)
                        .buttonStyle(.borderedProminent)
                    if let other = state.otherTripMode {
                        StartTripButton(mode: other)
                            .buttonStyle(.bordered)
                    }
                }
                .tint(.green)
            }
        }
    }
}

// Shows the mode's icon and name, so it's clear what kind of trip each button starts
@available(iOS 17.0, *)
struct StartTripButton: View {
    let mode: String

    var body: some View {
        Button(intent: StartTripIntent(mode: TripModeEntity(id: mode))) {
            Label {
                Text(TripFormat.modeName(mode))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } icon: {
                Image(tripMode: mode)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }
            .font(.caption.bold())
            .frame(maxWidth: .infinity)
            .widgetAccentable()
        }
    }
}

extension View {
    func widgetBackground() -> some View {
        modifier(WidgetBackground())
    }
}

// iOS 17 widgets need a container background, which isn't available before iOS 17. Lock Screen
// widgets get their background from the system.
struct WidgetBackground: ViewModifier {
    @Environment(\.widgetFamily) var family

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(.fill.tertiary, for: .widget)
        } else if family == .systemSmall {
            content.padding().background(Color(.systemBackground))
        } else {
            content
        }
    }
}
