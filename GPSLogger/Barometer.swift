//
//  Barometer.swift
//  Overland
//
//  Barometric pressure and absolute altitude for location records. These run while tracking is on,
//  and need a barometer and Motion & Fitness access, the same as the motion activity in records.
//  A point only gets a reading from within 30 seconds of its own time, so a point from a
//  significant-change wake-up doesn't get a stale one.
//

import CoreMotion
import Foundation

@objc(GLBarometer) final class Barometer: NSObject {
    @objc static let shared = Barometer()

    // How far a reading can be from a point's time and still be included with it
    private static let maxReadingAge: TimeInterval = 30
    // Long enough to cover a batch of deferred background locations
    private static let keepReadingsFor: TimeInterval = 600

    private struct Reading {
        let date: Date
        let values: [String: NSNumber]
    }

    private let altimeter = CMAltimeter()
    private var pressureReadings: [Reading] = []
    private var altitudeReadings: [Reading] = []
    private var running = false

    // Tracking is enabled again at times like the end of a trip, so this keeps the readings it has
    @objc func start() {
        guard !running else { return }
        running = true
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                // kPa, to the nearest pascal
                let pressure = (data.pressure.doubleValue * 1000).rounded() / 1000
                self.pressureReadings = Self.adding(Reading(date: Date(), values: ["pressure": NSNumber(value: pressure)]), to: self.pressureReadings)
            }
        }
        if CMAltimeter.isAbsoluteAltitudeAvailable() {
            altimeter.startAbsoluteAltitudeUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                let values = [
                    "absolute_altitude": NSNumber(value: (data.altitude * 10).rounded() / 10),
                    "absolute_altitude_accuracy": NSNumber(value: (data.accuracy * 10).rounded() / 10),
                ]
                self.altitudeReadings = Self.adding(Reading(date: Date(), values: values), to: self.altitudeReadings)
            }
        }
    }

    @objc func stop() {
        running = false
        altimeter.stopRelativeAltitudeUpdates()
        altimeter.stopAbsoluteAltitudeUpdates()
        pressureReadings = []
        altitudeReadings = []
    }

    // The properties to add to a location record at this time, or none without a recent reading.
    // The date is optional because GLManager builds records from a nil location before the first
    // fix, such as right after the phone restarts, and a nil NSDate can't become a Date.
    @objc(propertiesForDate:) func properties(for date: Date?) -> [String: NSNumber] {
        guard let date else { return [:] }
        var properties: [String: NSNumber] = [:]
        for reading in [Self.nearest(to: date, in: pressureReadings), Self.nearest(to: date, in: altitudeReadings)] {
            properties.merge(reading?.values ?? [:]) { current, _ in current }
        }
        return properties
    }

    // In kPa, for the OwnTracks format's "p"
    @objc(pressureForDate:) func pressure(for date: Date?) -> NSNumber? {
        guard let date else { return nil }
        return Self.nearest(to: date, in: pressureReadings)?.values["pressure"]
    }

    private static func adding(_ reading: Reading, to readings: [Reading]) -> [Reading] {
        let cutoff = reading.date.addingTimeInterval(-keepReadingsFor)
        return readings.filter { $0.date >= cutoff } + [reading]
    }

    private static func nearest(to date: Date, in readings: [Reading]) -> Reading? {
        guard let reading = readings.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) else {
            return nil
        }
        return abs(reading.date.timeIntervalSince(date)) <= maxReadingAge ? reading : nil
    }
}
