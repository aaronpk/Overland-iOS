//
//  ReducedResourceSending.swift
//  Overland
//
//  On iOS 27, the system can ask apps to scale back non-essential work. While it does, automatic
//  sends happen at most every 5 minutes. Points are still recorded as usual, and Send Now still
//  sends right away. GLManager asks minimumSendInterval before each automatic send.
//

import Foundation
import UIKit

@objc(GLReducedResourceSending) final class ReducedResourceSending: NSObject {
    @objc static let shared = ReducedResourceSending()

    // Posted on the main queue when the system's preference changes
    @objc static let changedNotification = Notification.Name("GLReducedResourceSendingChanged")

    private static let reducedInterval: TimeInterval = 300

    private override init() {
        super.init()
        if #available(iOS 27.0, *) {
            NotificationCenter.default.addObserver(forName: UIApplication.systemPrefersReducedResourceUsageDidChangeNotification, object: nil, queue: .main) { _ in
                NSLog("System prefers reduced resource usage: %@", UIApplication.shared.systemPrefersReducedResourceUsage ? "yes" : "no")
                NotificationCenter.default.post(name: ReducedResourceSending.changedNotification, object: nil)
            }
        }
    }

    // The shortest time between automatic sends right now, or 0 for no limit beyond the setting
    @objc var minimumSendInterval: TimeInterval {
        if #available(iOS 27.0, *), UIApplication.shared.systemPrefersReducedResourceUsage {
            return ReducedResourceSending.reducedInterval
        }
        return 0
    }

    // Whether automatic sends are less frequent than the send interval setting right now, so the
    // Tracker can say why
    @objc var slowingSends: Bool {
        let manager: GLManager = GLManager.shared()
        let interval = manager.sendingInterval?.doubleValue ?? -1
        return interval >= 0 && interval < minimumSendInterval
    }
}
