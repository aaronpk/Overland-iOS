//
//  SharedStateObserver.swift
//  Overland
//
//  Keeps SharedTripState up to date for the widgets and controls. It only watches what GLManager
//  already broadcasts, its notifications and the settings it saves, so GLManager doesn't need to
//  know about widgets.
//

import UIKit
import WidgetKit

@objc final class SharedStateObserver: NSObject {
    @objc static let shared = SharedStateObserver()

    // The settings GLManager saves when tracking turns on or off, a trip starts or ends, the trip
    // mode changes, or data is sent
    private let watchedDefaults = [GLTrackingStateDefaultsName, GLTripStartTimeDefaultsName,
                                   GLTripModeDefaultsName, GLLastSentDateDefaultsName]
    // New points change the queue count and trip distance, but arrive often, so they only
    // refresh the snapshot this often
    private let newDataRefreshInterval: TimeInterval = 60
    // Widget reloads from the background count against a daily budget, so changes to only the
    // counts and dates reload widgets this often. Trip and tracking changes reload right away.
    private let minorReloadInterval: TimeInterval = 15 * 60

    private var started = false
    private var refreshScheduled = false
    private var lastRefresh = Date.distantPast
    private var lastMinorReload = Date.distantPast

    @objc func start() {
        guard !started else { return }
        started = true

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(stateChanged),
                           name: Notification.Name(GLSendingFinishedNotification), object: nil)
        center.addObserver(self, selector: #selector(stateChanged),
                           name: Notification.Name(GLSettingsChangedNotification), object: nil)
        center.addObserver(self, selector: #selector(stateChanged),
                           name: UIApplication.didEnterBackgroundNotification, object: nil)
        center.addObserver(self, selector: #selector(newData),
                           name: Notification.Name(GLNewDataNotification), object: nil)
        for key in watchedDefaults {
            UserDefaults.standard.addObserver(self, forKeyPath: key, options: [], context: nil)
        }

        refresh()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        stateChanged()
    }

    @objc private func newData() {
        if Date().timeIntervalSince(lastRefresh) >= newDataRefreshInterval {
            stateChanged()
        }
    }

    // Changes often arrive together, such as a trip ending and the send that follows it, so wait
    // a moment and refresh once
    @objc func stateChanged() {
        DispatchQueue.main.async { [self] in
            guard !refreshScheduled else { return }
            refreshScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
                refreshScheduled = false
                refresh()
            }
        }
    }

    @objc func refresh() {
        let manager: GLManager = GLManager.shared()
        var state = SharedTripState()
        state.trackingEnabled = manager.trackingEnabled
        state.tripMode = manager.currentTripMode ?? state.tripMode
        if manager.tripInProgress() {
            state.tripStart = manager.currentTripStart()
            state.tripDistance = max(0, manager.currentTripDistance())
        }
        state.lastSentDate = manager.lastSentDate
        state.lastSendError = manager.lastSendErrorTitle

        manager.numberOfLocations(inQueue: { count in
            DispatchQueue.main.async { [self] in
                state.queueCount = count
                save(state)
            }
        })
    }

    private func save(_ state: SharedTripState) {
        let old = SharedTripState.read()
        state.write()
        lastRefresh = Date()

        let tripOrTrackingChanged = old.trackingEnabled != state.trackingEnabled
            || old.tripStart != state.tripStart
            || old.tripMode != state.tripMode
            || old.lastSendError != state.lastSendError
        let countsChanged = old.queueCount != state.queueCount
            || old.lastSentDate != state.lastSentDate
            || old.tripDistance != state.tripDistance

        if tripOrTrackingChanged {
            WidgetCenter.shared.reloadAllTimelines()
            if #available(iOS 18.0, *) {
                ControlCenter.shared.reloadAllControls()
            }
        } else if countsChanged {
            // Reloads while the app is open don't count against the budget
            let appIsActive = UIApplication.shared.applicationState == .active
            if appIsActive || Date().timeIntervalSince(lastMinorReload) >= minorReloadInterval {
                lastMinorReload = Date()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
