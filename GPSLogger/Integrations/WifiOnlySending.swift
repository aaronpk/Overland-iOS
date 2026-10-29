//
//  WifiOnlySending.swift
//  Overland
//
//  The "Send only on Wi-Fi" setting, and whether the phone is on a connection it applies to.
//  GLManager asks waitingForWifi before each automatic send. Send Now always sends.
//

import Foundation
import Network

@objc(GLWifiOnlySending) final class WifiOnlySending: NSObject {
    @objc static let shared = WifiOnlySending()

    // Posted on the main queue when waitingForWifi may have changed
    @objc static let changedNotification = Notification.Name("GLWifiOnlySendingChanged")

    private static let defaultsKey = "GLSendOnlyOnWifiDefaults"

    private let monitor = NWPathMonitor()
    // Nil until the first path update arrives, shortly after launch
    private var onExpensiveNetwork: Bool?

    private override init() {
        super.init()
        // Updates arrive on the main queue, where GLManager sends from
        monitor.pathUpdateHandler = { [weak self] path in
            // Cellular and personal hotspots are "expensive". Wi-Fi in Low Data Mode is only
            // "constrained", so it still sends.
            self?.onExpensiveNetwork = path.isExpensive
            NotificationCenter.default.post(name: WifiOnlySending.changedNotification, object: nil)
        }
        monitor.start(queue: .main)
    }

    @objc var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: WifiOnlySending.defaultsKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: WifiOnlySending.defaultsKey)
            NotificationCenter.default.post(name: WifiOnlySending.changedNotification, object: nil)
        }
    }

    // Whether automatic sends should wait: the setting is on, the phone is on cellular or a
    // hotspot, and data goes to a server. iCloud Drive uploads are left to iOS, which has its own
    // cellular setting. Also true before the first path update, so a send right at launch can't
    // go out over cellular; it goes out at the next interval instead.
    @objc var waitingForWifi: Bool {
        let manager: GLManager = GLManager.shared()
        return enabled && !manager.savesToICloudDrive && (onExpensiveNetwork ?? true)
    }
}
