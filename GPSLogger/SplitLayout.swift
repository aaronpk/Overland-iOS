//
//  SplitLayout.swift
//  Overland
//
//  Switches a screen between its phone layout and a wide one, such as on an unfolded iPhone Duo,
//  where the fold runs down the middle of a landscape screen. In the wide layout, screens keep their
//  controls in the right half so nothing sits across the fold.
//

import UIKit

@objc(GLSplitLayout) final class SplitLayout: NSObject {
    private static let minimumWidth: CGFloat = 600

    private let phoneConstraints: [NSLayoutConstraint]
    private let wideConstraints: [NSLayoutConstraint]
    private var wide = false

    // The phone constraints start out active, as the storyboard sets them up
    @objc init(phoneConstraints: [NSLayoutConstraint], wideConstraints: [NSLayoutConstraint]) {
        self.phoneConstraints = phoneConstraints
        self.wideConstraints = wideConstraints
    }

    @objc static func isWide(_ size: CGSize) -> Bool {
        return size.width >= minimumWidth && size.width > size.height
    }

    // Call from viewWillLayoutSubviews. It only changes the constraints when the layout changes.
    @objc(updateForSize:) func update(for size: CGSize) {
        let wide = SplitLayout.isWide(size)
        if wide == self.wide {
            return
        }
        self.wide = wide
        if wide {
            NSLayoutConstraint.deactivate(phoneConstraints)
            NSLayoutConstraint.activate(wideConstraints)
        } else {
            NSLayoutConstraint.deactivate(wideConstraints)
            NSLayoutConstraint.activate(phoneConstraints)
        }
    }

    // For a settings screen: a stack in a scroll view, centered at a readable width instead of
    // stretching across the whole screen
    @objc static func centeredConstraints(stack: UIView, scrollView: UIScrollView) -> [NSLayoutConstraint] {
        return [
            stack.widthAnchor.constraint(equalToConstant: 560),
            stack.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ]
    }
}
