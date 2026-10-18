//
//  TripLiveActivityController.swift
//  Overland
//
//  Shows the active trip as a Live Activity. GLManager calls this from Objective-C,
//  so it's available on every iOS version and does nothing before iOS 16.2.
//

import ActivityKit
import Foundation

@objc final class TripLiveActivityController: NSObject {
    @objc static let shared = TripLiveActivityController()

    // Location updates arrive about once a second during a trip. Throttle updates to stay
    // within the system's Live Activity update budget. The elapsed time ticks on its own.
    private let minimumUpdateInterval: TimeInterval = 15
    private var lastUpdate = Date.distantPast

    // Activity<TripActivityAttributes>, which can't be the declared type of a stored
    // property while the app supports iOS versions without ActivityKit
    private var currentActivity: Any?

    @objc(startTripAt:mode:distance:speed:)
    func startTrip(at start: Date, mode: String, distance: Double, speed: Double) {
        guard #available(iOS 16.2, *) else { return }

        endAllActivities(content: nil, dismissalPolicy: .immediate)

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            NSLog("Live Activities are disabled in Settings, not showing the trip")
            return
        }

        do {
            currentActivity = try Activity.request(
                attributes: TripActivityAttributes(tripStart: start),
                content: content(mode: mode, distance: distance, speed: speed),
                pushType: nil)
            lastUpdate = Date()
        } catch {
            NSLog("Couldn't start the trip Live Activity: %@", error.localizedDescription)
        }
    }

    @objc(updateWithMode:distance:speed:force:)
    func update(mode: String, distance: Double, speed: Double, force: Bool) {
        guard #available(iOS 16.2, *),
              let activity = currentActivity as? Activity<TripActivityAttributes> else { return }

        if !force && Date().timeIntervalSince(lastUpdate) < minimumUpdateInterval {
            return
        }
        lastUpdate = Date()

        let content = content(mode: mode, distance: distance, speed: speed)
        Task {
            await activity.update(content)
        }
    }

    @objc(endTripWithMode:distance:speed:)
    func endTrip(mode: String, distance: Double, speed: Double) {
        guard #available(iOS 16.2, *) else { return }
        endAllActivities(content: content(mode: mode, distance: distance, speed: speed), dismissalPolicy: .default)
    }

    // Called on launch. Reattaches to the activity for the trip in progress, starting one if
    // it's missing, or ends leftover activities if no trip is in progress (e.g. after a crash).
    // Pass a nil start date when there is no trip in progress.
    @objc(syncWithTripStart:mode:distance:speed:)
    func sync(tripStart: Date?, mode: String, distance: Double, speed: Double) {
        guard #available(iOS 16.2, *) else { return }

        guard let tripStart else {
            endAllActivities(content: nil, dismissalPolicy: .immediate)
            return
        }

        let activities = Activity<TripActivityAttributes>.activities
        guard let existing = activities.first(where: { abs($0.attributes.tripStart.timeIntervalSince(tripStart)) < 1 }) else {
            startTrip(at: tripStart, mode: mode, distance: distance, speed: speed)
            return
        }

        for activity in activities where activity.id != existing.id {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        currentActivity = existing
        update(mode: mode, distance: distance, speed: speed, force: true)
    }

    @available(iOS 16.2, *)
    private func content(mode: String, distance: Double, speed: Double) -> ActivityContent<TripActivityAttributes.ContentState> {
        let state = TripActivityAttributes.ContentState(mode: mode, distance: max(distance, 0), speed: max(speed, 0))
        return ActivityContent(state: state, staleDate: nil)
    }

    @available(iOS 16.2, *)
    private func endAllActivities(content: ActivityContent<TripActivityAttributes.ContentState>?, dismissalPolicy: ActivityUIDismissalPolicy) {
        currentActivity = nil
        for activity in Activity<TripActivityAttributes>.activities {
            Task {
                await activity.end(content, dismissalPolicy: dismissalPolicy)
            }
        }
    }
}
