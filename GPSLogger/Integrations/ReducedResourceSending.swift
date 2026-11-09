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

    private static let reducedInterval: TimeInterval = 300

    private override init() {
        super.init()
        if #available(iOS 27.0, *) {
            NotificationCenter.default.addObserver(forName: UIApplication.systemPrefersReducedResourceUsageDidChangeNotification, object: nil, queue: .main) { _ in
                NSLog("System prefers reduced resource usage: %@", UIApplication.shared.systemPrefersReducedResourceUsage ? "yes" : "no")
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
}
