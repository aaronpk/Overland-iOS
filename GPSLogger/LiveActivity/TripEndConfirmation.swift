//
//  TripEndConfirmation.swift
//  Overland
//
//  The Live Activity's End Trip button opens overland://end-trip, which asks before ending the
//  trip. A Live Activity can't show a confirmation itself, and a stray tap shouldn't end a trip.
//

import UIKit

@objc final class TripEndConfirmation: NSObject {
    @objc static func present(in window: UIWindow?) {
        let manager: GLManager = GLManager.shared()
        // The trip may have ended since the Live Activity was drawn
        guard manager.tripInProgress(), var presenter = window?.rootViewController else { return }
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        if presenter is UIAlertController { return }

        let alert = UIAlertController(title: "End Trip?",
                                      message: "Your \(TripIntentText.tripSummary(manager)) will end.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Keep Going", style: .cancel))
        alert.addAction(UIAlertAction(title: "End Trip", style: .destructive) { _ in
            guard manager.tripInProgress() else { return }
            GLTripActions.endTripRestoringTracking()
            SharedStateObserver.shared.tripChanged(inProgress: false)
        })
        presenter.present(alert, animated: true)
    }
}
