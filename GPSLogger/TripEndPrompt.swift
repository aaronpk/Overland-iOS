//
//  TripEndPrompt.swift
//  Overland
//
//  "Ask to End Trip When Stopped" in Trip Settings. During a trip, notices when the phone has
//  stopped moving and sends a notification asking whether to end the trip. Its End Trip action
//  (handled in GLManager) ends the trip at the time the phone stopped, not when it's tapped.
//

import CoreLocation
import CoreMotion
import Foundation
import UserNotifications

// Decides when the phone has stopped. The thresholds are fixed, so the setting is a single switch.
struct StopDetector {
    // How far the phone can wander and still count as stopped, such as walking around a house
    static let radius: CLLocationDistance = 75
    static let maxAccuracy: CLLocationAccuracy = 100
    static let stopDuration: TimeInterval = 5 * 60
    // Without motion data there's no way to tell a stop from a traffic jam, so wait longer
    static let stopDurationWithoutMotion: TimeInterval = 10 * 60

    enum Result: Equatable {
        case none
        // The phone stopped at this location and time
        case stopped(CLLocation)
        // The phone moved on after a stop it was asked about
        case movedOn
    }

    // The first location of the current stop
    private(set) var start: CLLocation?
    private var sawStationary = false
    private var prompted = false

    // stationary: the motion sensors report only stationary. inVehicle: driving or cycling is
    // reported with medium or high confidence.
    mutating func update(location: CLLocation?, now: Date, hasMotion: Bool,
                         stationary: Bool, inVehicle: Bool) -> Result {
        guard let location, location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= StopDetector.maxAccuracy else {
            return .none
        }

        // Somewhere new: this could be the start of a stop
        guard let start, location.distance(from: start) <= StopDetector.radius else {
            let wasPrompted = prompted
            self.start = location
            sawStationary = stationary
            prompted = false
            return wasPrompted ? .movedOn : .none
        }

        if stationary {
            sawStationary = true
        }
        if prompted {
            return .none
        }

        // Locations arrive less often while the phone is still, so time the stop with the clock
        let stoppedFor = now.timeIntervalSince(start.timestamp)
        let stopped = hasMotion
            ? stoppedFor >= StopDetector.stopDuration && sawStationary && !inVehicle
            : stoppedFor >= StopDetector.stopDurationWithoutMotion
        if stopped {
            prompted = true
            return .stopped(start)
        }
        return .none
    }

    mutating func reset() {
        start = nil
        sawStationary = false
        prompted = false
    }
}

@objc(GLTripEndPrompt) final class TripEndPrompt: NSObject {
    @objc static let shared = TripEndPrompt()

    private static let notificationID = "GLLocalNotificationEndTripWhenStopped"
    private static let checkInterval: TimeInterval = 30

    private var detector = StopDetector()
    private var timer: Timer?
    private var started = false

    @objc var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: GLTripAskToEndWhenStoppedDefaultsName) }
        set {
            UserDefaults.standard.set(newValue, forKey: GLTripAskToEndWhenStoppedDefaultsName)
            if newValue {
                // The prompt only needs permission for notifications, not the "Enable
                // notifications" setting, which is for the paused and resumed messages
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
            update()
        }
    }

    // Called at launch. Starts and stops watching as trips start and end.
    @objc func start() {
        guard !started else { return }
        started = true

        UserDefaults.standard.addObserver(self, forKeyPath: GLTripStartTimeDefaultsName, options: [], context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: GLTripAskToEndWhenStoppedDefaultsName, options: [], context: nil)
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(check), name: Notification.Name(GLNewDataNotification), object: nil)
        center.addObserver(self, selector: #selector(check), name: Notification.Name(GLNewActivityNotification), object: nil)
        update()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async { [self] in
            update()
        }
    }

    private var watching: Bool {
        let manager: GLManager = GLManager.shared()
        return enabled && manager.tripInProgress()
    }

    private func update() {
        if watching {
            if timer == nil {
                detector.reset()
                // The app keeps running in the background during a trip, since location updates
                // are on, but new locations arrive less often once the phone is still
                timer = Timer.scheduledTimer(withTimeInterval: TripEndPrompt.checkInterval, repeats: true) { [weak self] _ in
                    self?.check()
                }
            }
        } else if timer != nil {
            timer?.invalidate()
            timer = nil
            detector.reset()
            withdrawPrompt()
        }
    }

    @objc private func check() {
        guard watching else { return }
        let manager: GLManager = GLManager.shared()
        let motion = manager.lastMotion
        let hasMotion = CMMotionActivityManager.isActivityAvailable()
            && CMMotionActivityManager.authorizationStatus() == .authorized
            && motion != nil
        let stationary = motion.map { $0.stationary && !$0.walking && !$0.running && !$0.cycling && !$0.automotive } ?? false
        let inVehicle = motion.map { ($0.automotive || $0.cycling) && $0.confidence != .low } ?? false

        switch detector.update(location: manager.lastDeviceLocation, now: Date(), hasMotion: hasMotion,
                               stationary: stationary, inVehicle: inVehicle) {
        case .stopped(let location):
            sendPrompt(stoppedAt: location, tripStart: manager.currentTripStart())
        case .movedOn:
            withdrawPrompt()
        case .none:
            break
        }
    }

    private func sendPrompt(stoppedAt location: CLLocation, tripStart: Date?) {
        guard let tripStart else { return }
        let time = DateFormatter.localizedString(from: location.timestamp, dateStyle: .none, timeStyle: .short)

        let content = UNMutableNotificationContent()
        content.title = "End Trip?"
        content.body = "It looks like you stopped at \(time). End the trip then?"
        content.sound = .default
        content.categoryIdentifier = GLNotificationCategoryTripName
        content.userInfo = [
            GLEndTripPromptTripStartKey: tripStart.timeIntervalSince1970,
            GLEndTripPromptStoppedAtKey: location.timestamp.timeIntervalSince1970,
            GLEndTripPromptLatitudeKey: location.coordinate.latitude,
            GLEndTripPromptLongitudeKey: location.coordinate.longitude,
            GLEndTripPromptAccuracyKey: location.horizontalAccuracy,
        ]
        let request = UNNotificationRequest(identifier: TripEndPrompt.notificationID, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("Couldn't ask to end the trip: %@", error.localizedDescription)
            }
        }
    }

    // The phone moved on, or the trip ended some other way, so the prompt no longer applies
    private func withdrawPrompt() {
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [TripEndPrompt.notificationID])
        center.removePendingNotificationRequests(withIdentifiers: [TripEndPrompt.notificationID])
    }
}
