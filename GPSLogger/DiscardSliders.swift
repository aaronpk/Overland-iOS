//
//  DiscardSliders.swift
//  Overland
//
//  Converts between the positions of the Min Distance, Max Accuracy and Min Time sliders on the
//  Settings and Trip Settings screens and the values GLManager stores. The sliders go from 0 to 1,
//  squared, so the short distances and times, which need finer steps, get more of the slider.
//  Values snap to round numbers.
//

import Foundation

@objc(GLDiscardSliders) final class DiscardSliders: NSObject {
    // GLManager stores -1 for "off"
    private static let distanceOff: Double = -1
    private static let maxDistance: Double = 500
    private static let maxAccuracy: Double = 1000
    private static let minSeconds = 1
    private static let maxSeconds = 300

    // MARK: Min distance between points, in meters

    @objc static func sliderValue(forDistance distance: Double) -> Float {
        if distance <= 0 { return 0 }
        return Float((min(distance, maxDistance) / maxDistance).squareRoot())
    }

    @objc static func distance(forSliderValue value: Float) -> Double {
        let meters = maxDistance * Double(value * value)
        if meters < 0.5 { return distanceOff }
        return min(maxDistance, snap(meters, steps: [(10, 1), (100, 5), (.infinity, 10)]))
    }

    @objc static func text(forDistance distance: Double) -> String {
        distance <= 0 ? "Off" : "\(Int(distance)) m"
    }

    // MARK: Max accuracy of points, in meters

    @objc static func sliderValue(forAccuracy accuracy: Double) -> Float {
        if accuracy <= 0 { return 0 }
        return Float((min(accuracy, maxAccuracy) / maxAccuracy).squareRoot())
    }

    @objc static func accuracy(forSliderValue value: Float) -> Double {
        let meters = maxAccuracy * Double(value * value)
        if meters < 0.5 { return distanceOff }
        return min(maxAccuracy, snap(meters, steps: [(10, 1), (100, 5), (500, 10), (.infinity, 50)]))
    }

    // MARK: Min time between points, in seconds

    @objc static func sliderValue(forSeconds seconds: Int) -> Float {
        let range = Double(maxSeconds - minSeconds)
        let clamped = Double(min(max(seconds, minSeconds), maxSeconds) - minSeconds)
        return Float((clamped / range).squareRoot())
    }

    @objc static func seconds(forSliderValue value: Float) -> Int {
        let seconds = Double(minSeconds) + Double(maxSeconds - minSeconds) * Double(value * value)
        return min(maxSeconds, max(minSeconds, Int(snap(seconds, steps: [(10, 1), (60, 5), (.infinity, 15)]))))
    }

    @objc static func text(forSeconds seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) s" }
        let minutes = seconds / 60, rest = seconds % 60
        return rest == 0 ? "\(minutes) min" : "\(minutes) min \(rest) s"
    }

    // Rounds to the step for the range the value is in, e.g. to 5 below 100
    private static func snap(_ value: Double, steps: [(below: Double, step: Double)]) -> Double {
        let step = steps.first { value < $0.below }?.step ?? 1
        return max(step, (value / step).rounded() * step)
    }
}
