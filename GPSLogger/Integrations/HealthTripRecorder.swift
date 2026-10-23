//
//  HealthTripRecorder.swift
//  Overland
//
//  Saves trips to Apple Health as workouts with their route, for trip modes that have an Apple
//  Health workout type.
//
//  It keeps its own copy of the trip's route, in a file separate from GLManager's queue and trip
//  database, so nothing here can affect the location data Overland sends. During a trip it adds
//  GLManager's latest location each time GLManager reports new data, and it notices trips starting
//  and ending by watching the trip start time GLManager saves. A route file is deleted only after
//  its workout is saved, and route files left from a trip that ended while the app wasn't running
//  are saved the next time it starts.
//

import CoreLocation
import HealthKit

// The Apple Health workouts a trip mode can be saved as. Only outdoor workouts that can have a route.
struct HealthWorkout {
    // Stored in TripMode.healthWorkout, so it never changes
    let key: String
    let name: String
    let activityType: HKWorkoutActivityType
    // The distance sample saved with the workout, or nil to save only the route
    let distanceType: HKQuantityTypeIdentifier?

    static let all: [HealthWorkout] = {
        var all = [
            HealthWorkout(key: "walking", name: "Walking", activityType: .walking, distanceType: .distanceWalkingRunning),
            HealthWorkout(key: "running", name: "Running", activityType: .running, distanceType: .distanceWalkingRunning),
            HealthWorkout(key: "hiking", name: "Hiking", activityType: .hiking, distanceType: .distanceWalkingRunning),
            HealthWorkout(key: "cycling", name: "Cycling", activityType: .cycling, distanceType: .distanceCycling),
            HealthWorkout(key: "handCycling", name: "Hand Cycling", activityType: .handCycling, distanceType: .distanceCycling),
            HealthWorkout(key: "wheelchairWalkPace", name: "Wheelchair Walk Pace", activityType: .wheelchairWalkPace, distanceType: .distanceWheelchair),
            HealthWorkout(key: "wheelchairRunPace", name: "Wheelchair Run Pace", activityType: .wheelchairRunPace, distanceType: .distanceWheelchair),
            HealthWorkout(key: "paddleSports", name: "Paddling", activityType: .paddleSports, distanceType: nil),
            HealthWorkout(key: "rowing", name: "Rowing", activityType: .rowing, distanceType: nil),
            HealthWorkout(key: "sailing", name: "Sailing", activityType: .sailing, distanceType: nil),
            HealthWorkout(key: "surfing", name: "Surfing", activityType: .surfingSports, distanceType: nil),
            HealthWorkout(key: "crossCountrySkiing", name: "Cross-Country Skiing", activityType: .crossCountrySkiing, distanceType: nil),
            HealthWorkout(key: "downhillSkiing", name: "Downhill Skiing", activityType: .downhillSkiing, distanceType: .distanceDownhillSnowSports),
            HealthWorkout(key: "snowboarding", name: "Snowboarding", activityType: .snowboarding, distanceType: .distanceDownhillSnowSports),
            HealthWorkout(key: "skating", name: "Skating", activityType: .skatingSports, distanceType: nil),
            HealthWorkout(key: "equestrian", name: "Horseback Riding", activityType: .equestrianSports, distanceType: nil),
            HealthWorkout(key: "golf", name: "Golf", activityType: .golf, distanceType: nil),
            HealthWorkout(key: "climbing", name: "Climbing", activityType: .climbing, distanceType: nil),
            HealthWorkout(key: "other", name: "Other", activityType: .other, distanceType: nil),
        ]
        // Distance types added in iOS 18
        if #available(iOS 18.0, *) {
            let distanceTypes: [String: HKQuantityTypeIdentifier] = [
                "paddleSports": .distancePaddleSports,
                "rowing": .distanceRowing,
                "crossCountrySkiing": .distanceCrossCountrySkiing,
                "skating": .distanceSkatingSports,
            ]
            all = all.map { workout in
                guard let distanceType = distanceTypes[workout.key] else { return workout }
                return HealthWorkout(key: workout.key, name: workout.name, activityType: workout.activityType,
                                     distanceType: distanceType)
            }
        }
        return all
    }()

    static func forKey(_ key: String?) -> HealthWorkout? {
        all.first { $0.key == key }
    }

    // The workout a trip in this mode is saved as, or nil if it isn't saved
    static func forMode(_ mode: String) -> HealthWorkout? {
        forKey(TripModeStore.healthWorkout(mode))
    }
}

@objc final class HealthTripRecorder: NSObject {
    @objc static let shared = HealthTripRecorder()

    private static let enabledDefaultsKey = "HealthTripRecorderEnabled"
    private static let lastErrorDefaultsKey = "HealthTripRecorderLastError"
    private static let savedTripsDefaultsKey = "HealthTripRecorderSavedTrips"

    private let store = HKHealthStore()
    // Route files are written and read on this queue
    private let queue = DispatchQueue(label: "com.aaronpk.overland.healthtrips")
    private var started = false
    // The start of the trip being recorded, or nil
    private var recordingStart: Date?
    private var lastRecordedTimestamp: Date?
    // GLManager stops reporting the trip distance once the trip ends, so keep the latest
    private var lastTripDistance: CLLocationDistance = 0

    @objc static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    @objc var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledDefaultsKey)
            if newValue {
                syncWithTrip()
            }
        }
    }

    // Why the last workout couldn't be saved, or nil
    @objc var lastError: String? {
        UserDefaults.standard.string(forKey: Self.lastErrorDefaultsKey)
    }

    // MARK: - Authorization

    // Asks to save workouts, routes and distances. The completion runs on the main queue with nil if
    // Overland can save workouts, or a message to show.
    @objc func requestAuthorization(completion: @escaping (String?) -> Void) {
        // Every distance type, so a mode's workout can be changed later without asking again
        var types: Set<HKSampleType> = [HKObjectType.workoutType(), HKSeriesType.workoutRoute()]
        for case let distanceType? in HealthWorkout.all.map(\.distanceType) {
            types.insert(HKQuantityType(distanceType))
        }
        store.requestAuthorization(toShare: types, read: nil) { [self] _, error in
            DispatchQueue.main.async { [self] in
                if let error = error {
                    completion(error.localizedDescription)
                } else if store.authorizationStatus(for: HKObjectType.workoutType()) != .sharingAuthorized {
                    completion("Overland isn't allowed to save workouts. You can allow it in the Health app, under Profile → Apps → Overland.")
                } else {
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Watching trips

    @objc func start() {
        guard !started, Self.isAvailable else { return }
        started = true

        NotificationCenter.default.addObserver(self, selector: #selector(newData),
                                               name: Notification.Name(GLNewDataNotification), object: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: GLTripStartTimeDefaultsName, options: [], context: nil)

        syncWithTrip()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async { [self] in
            syncWithTrip()
        }
    }

    // Starts recording when a trip starts, saves the workout when it ends, and saves any trips
    // left over from before the app last quit
    private func syncWithTrip() {
        let manager: GLManager = GLManager.shared()
        let tripStart = manager.tripInProgress() ? manager.currentTripStart() : nil

        if let recording = recordingStart, recording != tripStart {
            // The trip being recorded ended
            let mode = manager.currentTripMode ?? ""
            let distance = lastTripDistance
            let end = Date()
            recordingStart = nil
            queue.async { [self] in
                finishTrip(start: recording, end: end, mode: mode, distance: distance)
            }
        }

        if let tripStart = tripStart, recordingStart == nil, isEnabled {
            recordingStart = tripStart
            lastRecordedTimestamp = nil
            lastTripDistance = max(0, manager.currentTripDistance())
            let mode = manager.currentTripMode ?? ""
            queue.async { [self] in
                beginRouteFile(start: tripStart, mode: mode)
            }
        }

        let current = recordingStart
        queue.async { [self] in
            saveLeftoverTrips(except: current)
        }
    }

    @objc private func newData() {
        guard let start = recordingStart else { return }
        let manager: GLManager = GLManager.shared()
        lastTripDistance = max(lastTripDistance, manager.currentTripDistance())

        // The device's location, rather than a wifi zone's location standing in for it
        guard let location = manager.lastDeviceLocation ?? manager.lastLocation,
              location.timestamp >= start,
              location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 200 else { return }
        if let last = lastRecordedTimestamp, location.timestamp <= last {
            return
        }
        lastRecordedTimestamp = location.timestamp

        queue.async { [self] in
            appendToRouteFile(start: start, line: Self.encode(location))
        }
    }

    // MARK: - Route files, on the queue

    // Application Support/HealthTrips/<trip start>.jsonl. The first line has the trip mode, and each
    // line after it is a location.
    private var directory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("HealthTrips", isDirectory: true)
    }

    private func routeFile(start: Date) -> URL {
        directory.appendingPathComponent("\(Int(start.timeIntervalSince1970)).jsonl")
    }

    private func beginRouteFile(start: Date, mode: String) {
        let url = routeFile(start: start)
        guard !FileManager.default.fileExists(atPath: url.path) else {
            // The app was relaunched during the trip, so keep adding to it
            return
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let header = (try? JSONSerialization.data(withJSONObject: ["mode": mode])) ?? Data()
        try? (header + Data("\n".utf8)).write(to: url, options: .atomic)
    }

    private func appendToRouteFile(start: Date, line: Data) {
        let url = routeFile(start: start)
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        handle.seekToEndOfFile()
        handle.write(line + Data("\n".utf8))
        try? handle.close()
    }

    private func readRouteFile(_ url: URL) -> (mode: String, locations: [CLLocation])? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var lines = text.split(separator: "\n")
        guard !lines.isEmpty,
              let header = try? JSONSerialization.jsonObject(with: Data(lines.removeFirst().utf8)) as? [String: Any] else {
            return nil
        }
        let locations = lines.compactMap { Self.decode(Data($0.utf8)) }
        return (header["mode"] as? String ?? "", locations)
    }

    private func finishTrip(start: Date, end: Date, mode: String, distance: CLLocationDistance) {
        let url = routeFile(start: start)
        guard isEnabled, HealthWorkout.forMode(mode) != nil, let route = readRouteFile(url) else {
            // Not saved to Health, such as a car trip
            try? FileManager.default.removeItem(at: url)
            return
        }
        save(start: start, end: end, mode: mode, distance: distance, locations: route.locations, file: url)
    }

    private func saveLeftoverTrips(except current: Date?) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for url in files where url.pathExtension == "jsonl" {
            guard let seconds = TimeInterval(url.deletingPathExtension().lastPathComponent) else { continue }
            let start = Date(timeIntervalSince1970: seconds)
            if let current = current, Int(current.timeIntervalSince1970) == Int(seconds) {
                continue
            }
            guard isEnabled, let route = readRouteFile(url), HealthWorkout.forMode(route.mode) != nil,
                  let last = route.locations.last else {
                try? FileManager.default.removeItem(at: url)
                continue
            }
            save(start: start, end: last.timestamp, mode: route.mode,
                 distance: Self.distance(of: route.locations), locations: route.locations, file: url)
        }
    }

    // MARK: - Saving workouts

    private func save(start: Date, end: Date, mode: String, distance: CLLocationDistance,
                      locations: [CLLocation], file: URL) {
        let tripID = "overland-trip-\(Int(start.timeIntervalSince1970))"
        var saved = UserDefaults.standard.stringArray(forKey: Self.savedTripsDefaultsKey) ?? []
        guard let workout = HealthWorkout.forMode(mode), end > start, !saved.contains(tripID) else {
            try? FileManager.default.removeItem(at: file)
            return
        }

        // Wait for the save, so trips are saved one at a time
        let done = DispatchSemaphore(value: 0)
        Task {
            defer { done.signal() }
            do {
                try await saveWorkout(workout, tripID: tripID, start: start, end: end,
                                      distance: distance, locations: locations)
                saved.append(tripID)
                UserDefaults.standard.set(Array(saved.suffix(50)), forKey: Self.savedTripsDefaultsKey)
                UserDefaults.standard.removeObject(forKey: Self.lastErrorDefaultsKey)
                try? FileManager.default.removeItem(at: file)
                NSLog("Saved %@ to Apple Health with %d route points", tripID, locations.count)
            } catch {
                // Keep the route file, so it's tried again the next time the app starts
                UserDefaults.standard.set("Couldn't save a trip to Apple Health: \(error.localizedDescription)",
                                          forKey: Self.lastErrorDefaultsKey)
                NSLog("Couldn't save %@ to Apple Health: %@", tripID, error.localizedDescription)
            }
        }
        done.wait()
    }

    private func saveWorkout(_ healthWorkout: HealthWorkout, tripID: String, start: Date, end: Date,
                             distance: CLLocationDistance, locations: [CLLocation]) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = healthWorkout.activityType
        configuration.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: start)
        // Saving a distance type Overland isn't allowed to save would fail the whole workout, which can
        // happen when a mode's workout was changed after Health access was given
        if distance > 0, let identifier = healthWorkout.distanceType,
           store.authorizationStatus(for: HKQuantityType(identifier)) == .sharingAuthorized {
            let distanceType = HKQuantityType(identifier)
            let sample = HKQuantitySample(type: distanceType,
                                          quantity: HKQuantity(unit: .meter(), doubleValue: distance),
                                          start: start, end: end)
            try await builder.addSamples([sample])
        }
        try await builder.addMetadata([
            HKMetadataKeyExternalUUID: tripID,
            HKMetadataKeyIndoorWorkout: false,
        ])
        try await builder.endCollection(at: end)
        guard let workout = try await builder.finishWorkout() else { return }

        let route = locations.filter { $0.timestamp >= start && $0.timestamp <= end }
        guard route.count >= 2 else { return }
        let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
        for chunkStart in stride(from: 0, to: route.count, by: 200) {
            try await routeBuilder.insertRouteData(Array(route[chunkStart..<min(chunkStart + 200, route.count)]))
        }
        try await routeBuilder.finishRoute(with: workout, metadata: nil)
    }

    // MARK: - Encoding locations

    private static func encode(_ location: CLLocation) -> Data {
        let values: [String: Double] = [
            "t": location.timestamp.timeIntervalSince1970,
            "lat": location.coordinate.latitude,
            "lon": location.coordinate.longitude,
            "alt": location.altitude,
            "hacc": location.horizontalAccuracy,
            "vacc": location.verticalAccuracy,
            "spd": location.speed,
            "crs": location.course,
        ]
        return (try? JSONSerialization.data(withJSONObject: values)) ?? Data()
    }

    private static func decode(_ data: Data) -> CLLocation? {
        guard let v = try? JSONSerialization.jsonObject(with: data) as? [String: Double],
              let t = v["t"], let lat = v["lat"], let lon = v["lon"] else { return nil }
        return CLLocation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                          altitude: v["alt"] ?? 0,
                          horizontalAccuracy: v["hacc"] ?? 0,
                          verticalAccuracy: v["vacc"] ?? -1,
                          course: v["crs"] ?? -1,
                          speed: v["spd"] ?? -1,
                          timestamp: Date(timeIntervalSince1970: t))
    }

    private static func distance(of locations: [CLLocation]) -> CLLocationDistance {
        zip(locations, locations.dropFirst()).reduce(0) { $0 + $1.1.distance(from: $1.0) }
    }
}
