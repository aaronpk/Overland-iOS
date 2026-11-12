//
//  SharedStateObserver.swift
//  Overland
//
//  Keeps SharedTripState up to date for the widgets and controls, and the Home Screen quick actions
//  up to date with the trip. It only watches what GLManager already broadcasts, its notifications
//  and the settings it saves, so GLManager doesn't need to know about widgets.
//

import UIKit
import WidgetKit

@objc final class SharedStateObserver: NSObject {
    @objc static let shared = SharedStateObserver()

    // The settings GLManager saves when tracking turns on or off, a trip starts or ends, or the
    // trip mode changes
    private let watchedDefaults = [GLTrackingStateDefaultsName, GLTripStartTimeDefaultsName,
                                   GLTripModeDefaultsName]

    private var started = false
    private var refreshScheduled = false

    @objc func start() {
        guard !started else { return }
        started = true

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(stateChanged),
                           name: Notification.Name(GLSettingsChangedNotification), object: nil)
        center.addObserver(self, selector: #selector(stateChanged),
                           name: UIApplication.didEnterBackgroundNotification, object: nil)
        for key in watchedDefaults {
            UserDefaults.standard.addObserver(self, forKeyPath: key, options: [], context: nil)
        }

        refresh()

        // Widgets keep showing what they last drew until something reloads them, so after an
        // update they'd show the old version's layout until the next trip or tracking change.
        // The app starts only a few times a day, so this costs little of the reload budget.
        WidgetCenter.shared.reloadAllTimelines()
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadAllControls()
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        stateChanged()
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

    // Called by the intents right after they start or end a trip. A widget or control reloads as
    // soon as its intent finishes, before the usual refresh, so this updates the snapshot now.
    // Ending a trip finishes in the background, so GLManager may still report the trip until then.
    func tripChanged(inProgress: Bool) {
        let manager: GLManager = GLManager.shared()
        var state = SharedTripState.read()
        state.tripStart = inProgress ? (manager.currentTripStart() ?? Date()) : nil
        state.tripMode = manager.currentTripMode ?? state.tripMode
        state.trackingEnabled = manager.trackingEnabled
        state.updatedAt = Date()
        save(state)
        stateChanged()
    }

    @objc func refresh() {
        let manager: GLManager = GLManager.shared()
        var state = SharedTripState()
        state.trackingEnabled = manager.trackingEnabled
        state.tripMode = manager.currentTripMode ?? state.tripMode
        if manager.tripInProgress() {
            state.tripStart = manager.currentTripStart()
        }

        // The Home Screen quick actions show Stop Trip during a trip, so they change with it too
        GLTripActions.updateQuickActions()

        save(state)
    }

    private func save(_ state: SharedTripState) {
        let old = SharedTripState.read()
        state.write()

        if old.trackingEnabled != state.trackingEnabled
            || old.tripStart != state.tripStart
            || old.tripMode != state.tripMode {
            WidgetCenter.shared.reloadAllTimelines()
            if #available(iOS 18.0, *) {
                ControlCenter.shared.reloadAllControls()
            }
        }
    }
}
