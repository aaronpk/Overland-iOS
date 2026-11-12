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

    // For a settings screen: a stack in a scroll view, moved into the right half and kept out of the
    // area on the right that the status bar and the tab bar use when unfolded
    @objc static func rightHalfConstraints(stack: UIView, scrollView: UIScrollView, safeArea: UILayoutGuide) -> [NSLayoutConstraint] {
        return [
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -20),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ]
    }
}
