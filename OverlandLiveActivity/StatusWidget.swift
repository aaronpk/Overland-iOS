//
//  StatusWidget.swift
//  OverlandLiveActivity
//
//  A Home Screen and Lock Screen widget showing whether Overland is tracking, the trip in
//  progress, and how much data is waiting to be sent. It reads the state the app shares in the
//  App Group. The app reloads it when the state changes.
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
        state.queueCount = 12
        state.lastSentDate = Date().addingTimeInterval(-300)
        return StatusEntry(date: Date(), state: state)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : StatusEntry(date: Date(), state: SharedTripState.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        // The timer and "sent ago" text update on their own. The app reloads the widget when
        // anything else changes, and this picks up anything that was missed.
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
        .description("Shows whether Overland is tracking, the trip in progress, and the data waiting to be sent.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
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
        case .systemMedium:
            HStack(alignment: .top, spacing: 16) {
                status
                VStack(spacing: 8) {
                    Spacer(minLength: 0)
                    TripButton(state: state)
                    SendNowButton()
                }
                .frame(maxWidth: 130)
            }
        default:
            VStack(alignment: .leading, spacing: 10) {
                status
                TripButton(state: state)
            }
        }
    }

    // The trip, or whether tracking is on, then the queue and when data was last sent
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
                ElapsedTime(start: start)
                    .font(.title2.bold())
                    .multilineTextAlignment(.leading)
                TripStat(value: TripFormat.distance(state.tripDistance), unit: TripFormat.distanceUnit)
            }
            Spacer(minLength: 0)
            // The small widget doesn't have room for these alongside a trip and its button
            if !(family == .systemSmall && state.tripInProgress) {
                queueStatus
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var queueStatus: some View {
        Text("\(state.queueCount) queued")
            .font(.caption)
            .foregroundStyle(.secondary)
        if let error = state.lastSendError {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(2)
        } else if let lastSent = state.lastSentDate {
            LastSentText(date: lastSent)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let start = state.tripStart {
                Label { Text(TripFormat.modeName(state.tripMode)) } icon: { Image(tripMode: state.tripMode) }
                    .font(.headline)
                ElapsedTime(start: start)
                    .multilineTextAlignment(.leading)
                Text("\(TripFormat.distance(state.tripDistance)) \(TripFormat.distanceUnit)")
            } else {
                Label(state.trackingEnabled ? "Tracking" : "Not Tracking",
                      systemImage: state.trackingEnabled ? "location.fill" : "location.slash")
                    .font(.headline)
                Text("\(state.queueCount) queued")
                if state.lastSendError != nil {
                    Text("Couldn't send")
                } else if let lastSent = state.lastSentDate {
                    LastSentText(date: lastSent)
                }
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
                    Text("\(state.queueCount)")
                        .font(.caption.bold())
                        .minimumScaleFactor(0.6)
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
            Label("\(state.trackingEnabled ? "Tracking" : "Not tracking") · \(state.queueCount) queued",
                  systemImage: state.trackingEnabled ? "location.fill" : "location.slash")
        }
    }
}

// How long ago data was last sent, as an up arrow and a time that counts up on its own, such as
// "12 min, 54 sec". The counting text always includes seconds, so it's kept short to fit.
struct LastSentText: View {
    let date: Date

    var body: some View {
        (Text(Image(systemName: "arrow.up")) + Text(" ") + Text(date, style: .relative))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

// Starts a trip in the last trip mode, or ends the trip in progress. Buttons in widgets need iOS 17.
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
                // Shows the mode's icon, so it's clear what kind of trip this starts
                Button(intent: StartTripIntent(mode: TripModeEntity(id: state.tripMode))) {
                    Label {
                        Text("Start")
                    } icon: {
                        Image(tripMode: state.tripMode)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                    }
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .widgetAccentable()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
    }
}

struct SendNowButton: View {
    var body: some View {
        if #available(iOS 17.0, *) {
            Button(intent: SendNowIntent()) {
                Label("Send Now", systemImage: "arrow.up")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .widgetAccentable()
            }
            .buttonStyle(.bordered)
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
        } else if family == .systemSmall || family == .systemMedium {
            content.padding().background(Color(.systemBackground))
        } else {
            content
        }
    }
}
