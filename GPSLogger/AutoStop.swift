//
//  AutoStop.swift
//  Overland
//
//  Auto-stop: when the phone stays within a radius for a while, GLManager stops location updates
//  to save battery, and starts them again once the phone leaves. This holds the settings and
//  decides when to stop and resume. GLManager does the stopping and resuming.
//

import CoreLocation
import Foundation

@objc(GLAutoStop) final class AutoStop: NSObject {
    @objc static let shared = AutoStop()

    private static let radiusKey = "GLAutoStopRadiusDefaults"
    private static let secondsKey = "GLAutoStopSecondsDefaults"
    private static let tripRadiusKey = "GLTripAutoStopRadiusDefaults"
    private static let tripSecondsKey = "GLTripAutoStopSecondsDefaults"

    // Longer during a trip, so stopping at a red light doesn't end the trip
    private static let defaultSeconds = 120
    private static let defaultTripSeconds = 600

    // Points less accurate than this don't count, the same limit the trip distance uses
    private static let maxUsableAccuracy: CLLocationAccuracy = 200

    // The last place the phone moved away from, and when it got there
    private var anchor: CLLocation?
    // Where updates were stopped, and the radius the phone has to leave to start them again
    private var stoppedLocation: CLLocation?
    private var stoppedRadius: CLLocationDistance = 0

    @objc var stopped: Bool { stoppedLocation != nil }

    // Auto-stop is turned on for the current settings, or it stopped the updates. GLManager doesn't
    // show the paused and resumed notifications while it is.
    @objc var active: Bool { currentRadius > 0 || stopped }

    // MARK: Settings

    // Meters, or -1 for off, the default
    @objc var radius: CLLocationDistance {
        get { AutoStop.double(AutoStop.radiusKey) ?? -1 }
        set { UserDefaults.standard.set(newValue, forKey: AutoStop.radiusKey) }
    }

    @objc var seconds: Int {
        get { AutoStop.int(AutoStop.secondsKey) ?? AutoStop.defaultSeconds }
        set { UserDefaults.standard.set(newValue, forKey: AutoStop.secondsKey) }
    }

    @objc var radiusDuringTrip: CLLocationDistance {
        get { AutoStop.double(AutoStop.tripRadiusKey) ?? -1 }
        set { UserDefaults.standard.set(newValue, forKey: AutoStop.tripRadiusKey) }
    }

    @objc var secondsDuringTrip: Int {
        get { AutoStop.int(AutoStop.tripSecondsKey) ?? AutoStop.defaultTripSeconds }
        set { UserDefaults.standard.set(newValue, forKey: AutoStop.tripSecondsKey) }
    }

    private var tripInProgress: Bool {
        let manager: GLManager = GLManager.shared()
        return manager.tripInProgress()
    }

    private var currentRadius: CLLocationDistance { tripInProgress ? radiusDuringTrip : radius }
    private var currentSeconds: Int { tripInProgress ? secondsDuringTrip : seconds }

    // MARK: Stopping and resuming

    // Called with each new location while updates are running. Returns true when the phone has
    // stayed within the radius for long enough, and updates should stop.
    @objc func shouldStop(after location: CLLocation) -> Bool {
        let radius = currentRadius
        guard radius > 0, !stopped else {
            anchor = nil
            return false
        }
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= AutoStop.maxUsableAccuracy else {
            return false
        }
        guard let anchor, location.distance(from: anchor) <= radius else {
            self.anchor = location
            return false
        }
        return location.timestamp.timeIntervalSince(anchor.timestamp) >= Double(currentSeconds)
    }

    @objc func markStopped(at location: CLLocation) {
        stoppedLocation = location
        stoppedRadius = currentRadius
        anchor = nil
    }

    // Called with locations that arrive while updates are stopped, such as significant location
    // changes. Returns true once the phone has left the radius.
    @objc func shouldResume(at location: CLLocation) -> Bool {
        guard let stoppedLocation else { return false }
        return location.distance(from: stoppedLocation) > stoppedRadius
    }

    // Called whenever tracking starts again
    @objc func reset() {
        anchor = nil
        stoppedLocation = nil
    }

    private static func double(_ key: String) -> Double? {
        UserDefaults.standard.object(forKey: key) == nil ? nil : UserDefaults.standard.double(forKey: key)
    }

    private static func int(_ key: String) -> Int? {
        UserDefaults.standard.object(forKey: key) == nil ? nil : UserDefaults.standard.integer(forKey: key)
    }
}
