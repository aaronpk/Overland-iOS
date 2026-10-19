//
//  OverlandLiveActivityBundle.swift
//  OverlandLiveActivity
//

import SwiftUI
import WidgetKit

@main
struct OverlandLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        TripLiveActivityWidget()
        if #available(iOS 18.0, *) {
            TripControl()
            SendNowControl()
        }
    }
}
