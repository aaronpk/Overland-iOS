//
//  MapPath.swift
//  Overland
//
//  The path lines on the Tracker map: green for every point recorded today, red on top for the
//  points that haven't been sent yet. Sent points are deleted from the queue, so today's points
//  are kept in a small file of their own, for the map only, and deleted the next day.
//  GLManager says which points were queued and sent in its notifications.
//

import CoreLocation
import MapKit
import UIKit

struct PathPoint: Equatable {
    let time: TimeInterval
    let latitude: Double
    let longitude: Double

    init(time: TimeInterval, latitude: Double, longitude: Double) {
        self.time = time
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ location: CLLocation) {
        self.init(time: location.timestamp.timeIntervalSince1970,
                  latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

// Turns points into the lines and dots that are drawn
enum PathBuilder {
    // Points further apart than both of these are a gap in tracking, such as a pause or
    // significant-change updates, so they aren't joined by a line across the map
    static let gapDistance: CLLocationDistance = 100
    static let gapTime: TimeInterval = 2 * 60
    // Points closer than this to the last point kept add nothing to the line
    static let thinDistance: CLLocationDistance = 5

    struct Path {
        var lines: [[CLLocationCoordinate2D]] = []
        // Points with no neighbor close enough to draw a line to
        var dots: [CLLocationCoordinate2D] = []
    }

    static func build(_ points: [PathPoint]) -> Path {
        let sorted = points.sorted { $0.time < $1.time }
        var path = Path()
        var segment: [CLLocationCoordinate2D] = []
        var last: (point: PathPoint, mapPoint: MKMapPoint)?

        func finishSegment() {
            if segment.count > 1 {
                path.lines.append(segment)
            } else if let only = segment.first {
                path.dots.append(only)
            }
            segment = []
        }

        for point in sorted {
            let mapPoint = MKMapPoint(point.coordinate)
            if let last {
                let distance = last.mapPoint.distance(to: mapPoint)
                if distance > gapDistance && point.time - last.point.time > gapTime {
                    finishSegment()
                } else if distance < thinDistance {
                    continue
                }
            }
            segment.append(point.coordinate)
            last = (point, mapPoint)
        }
        finishSegment()
        return path
    }
}

@objc(GLMapPath) final class MapPath: NSObject {
    @objc static let shared = MapPath()

    // Posted on the main queue when the lines should be redrawn, at most every few seconds
    static let changedNotification = Notification.Name("GLMapPathChanged")
    private static let changedInterval: TimeInterval = 5

    private static let recordSize = 3 * MemoryLayout<Double>.size

    private var started = false
    // The local day today's file is for
    private var day = ""
    private(set) var today: [PathPoint] = []
    // Unsent points by their queue key
    private var unsent: [String: PathPoint] = [:]

    private var lastChanged = Date.distantPast
    private var changeScheduled = false

    var unsentPoints: [PathPoint] { Array(unsent.values) }

    // Today's points since local midnight, as of now
    var todayPoints: [PathPoint] {
        let midnight = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        return today.filter { $0.time >= midnight }
    }

    // Called at launch, so points are recorded while the app runs in the background too
    @objc func start() {
        guard !started else { return }
        started = true

        let isNewDay = loadToday()
        let manager: GLManager = GLManager.shared()
        manager.queuedLocations { [self] keys, locations in
            let locations = locations ?? []
            for (key, location) in zip(keys ?? [], locations) {
                unsent[key] = PathPoint(location)
            }
            // After an update, or the first launch of the day, start today's line with the
            // points still in the queue
            if isNewDay {
                let midnight = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
                append(locations.map(PathPoint.init).filter { $0.time >= midnight })
            }
        }

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(newData(_:)), name: Notification.Name(GLNewDataNotification), object: nil)
        center.addObserver(self, selector: #selector(sendingFinished(_:)), name: Notification.Name(GLSendingFinishedNotification), object: nil)
        // Posted at midnight, among other times
        center.addObserver(self, selector: #selector(dayMayHaveChanged), name: UIApplication.significantTimeChangeNotification, object: nil)
    }

    @objc private func newData(_ notification: Notification) {
        guard let locations = notification.userInfo?[GLNewDataLocationsKey] as? [CLLocation],
              let keys = notification.userInfo?[GLNewDataQueueKeysKey] as? [String] else { return }
        if Self.dayString(Date()) != day {
            _ = loadToday()
        }

        let manager: GLManager = GLManager.shared()
        let loggingMode = manager.tripInProgress() ? manager.loggingModeDuringTrip : manager.loggingMode
        if loggingMode == kGLLoggingModeOnlyLatest || loggingMode == kGLLoggingModeOwntracks {
            // The queue only ever holds the newest point in these modes
            unsent.removeAll()
        }
        let points = locations.map(PathPoint.init)
        for (key, point) in zip(keys, points) {
            unsent[key] = point
        }
        append(points)
        changed()
    }

    @objc private func sendingFinished(_ notification: Notification) {
        if let keys = notification.userInfo?[GLSentQueueKeysKey] as? [String] {
            for key in keys {
                unsent.removeValue(forKey: key)
            }
        }
        checkQueueEmpty()
        changed()
    }

    // The queue can be emptied without a send, such as by deleting all data
    func checkQueueEmpty() {
        let manager: GLManager = GLManager.shared()
        manager.numberOfLocations(inQueue: { [self] count in
            DispatchQueue.main.async { [self] in
                if count == 0 && !unsent.isEmpty {
                    unsent.removeAll()
                    changed()
                }
            }
        })
    }

    @objc private func dayMayHaveChanged() {
        DispatchQueue.main.async { [self] in
            if Self.dayString(Date()) != day {
                _ = loadToday()
                changed()
            }
        }
    }

    // Redraws right away if it's been a while, otherwise once the interval is up
    private func changed() {
        guard !changeScheduled else { return }
        let wait = MapPath.changedInterval - Date().timeIntervalSince(lastChanged)
        if wait <= 0 {
            lastChanged = Date()
            NotificationCenter.default.post(name: MapPath.changedNotification, object: self)
            return
        }
        changeScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [self] in
            changeScheduled = false
            lastChanged = Date()
            NotificationCenter.default.post(name: MapPath.changedNotification, object: self)
        }
    }

    // MARK: Today's file

    private static var directory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("MapPath", isDirectory: true)
    }

    private static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private var fileURL: URL? { MapPath.directory?.appendingPathComponent("\(day).bin") }

    // Loads today's file and deletes the others. Returns true if today's file didn't exist yet.
    private func loadToday() -> Bool {
        day = Self.dayString(Date())
        today = []
        guard let directory = MapPath.directory, let fileURL else { return true }
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        for file in (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        where file.lastPathComponent != fileURL.lastPathComponent {
            try? fileManager.removeItem(at: file)
        }

        guard let data = try? Data(contentsOf: fileURL) else { return true }
        let count = data.count / MapPath.recordSize
        today.reserveCapacity(count)
        data.withUnsafeBytes { buffer in
            for i in 0..<count {
                let offset = i * MapPath.recordSize
                today.append(PathPoint(time: buffer.loadUnaligned(fromByteOffset: offset, as: Double.self),
                                       latitude: buffer.loadUnaligned(fromByteOffset: offset + 8, as: Double.self),
                                       longitude: buffer.loadUnaligned(fromByteOffset: offset + 16, as: Double.self)))
            }
        }
        return false
    }

    private func append(_ points: [PathPoint]) {
        guard !points.isEmpty else { return }
        today.append(contentsOf: points)
        guard let fileURL else { return }

        var data = Data(capacity: points.count * MapPath.recordSize)
        for point in points {
            for value in [point.time, point.latitude, point.longitude] {
                withUnsafeBytes(of: value) { data.append(contentsOf: $0) }
            }
        }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: fileURL)
        }
    }
}

// MARK: - Drawing

// Dots for points that are too far from their neighbors to join with a line. One overlay holds
// them all, since an overlay per point gets slow.
final class PathDotsOverlay: NSObject, MKOverlay {
    let points: [MKMapPoint]
    let boundingMapRect: MKMapRect

    init(_ coordinates: [CLLocationCoordinate2D]) {
        points = coordinates.map(MKMapPoint.init)
        let bounds = points.reduce(MKMapRect.null) { rect, point in
            rect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
        }
        // With room for the edges of the dots, which are drawn the same size at every zoom, so
        // the map doesn't cut them off
        let margin = MKMapRect.world.width / 2000
        boundingMapRect = bounds.insetBy(dx: -margin, dy: -margin)
    }

    var coordinate: CLLocationCoordinate2D { MKMapPoint(x: boundingMapRect.midX, y: boundingMapRect.midY).coordinate }
}

final class PathDotsRenderer: MKOverlayRenderer {
    private let color: UIColor
    private static let radius: CGFloat = 3.5

    init(overlay: PathDotsOverlay, color: UIColor) {
        self.color = color
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = overlay as? PathDotsOverlay else { return }
        // The same size on screen at every zoom
        let radius = Double(PathDotsRenderer.radius / zoomScale)
        let visible = mapRect.insetBy(dx: -radius, dy: -radius)
        context.setFillColor(color.cgColor)
        for point in overlay.points where visible.contains(point) {
            let center = self.point(for: point)
            context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
    }
}

// Shows the path lines on a map view. The map's delegate passes rendererFor overlay calls here.
@objc(GLMapPathOverlays) final class MapPathOverlays: NSObject {
    private weak var mapView: MKMapView?
    private var overlays: [MKOverlay] = []
    private var colors: [ObjectIdentifier: UIColor] = [:]
    private var generation = 0

    static let todayColor = UIColor.systemGreen
    static let unsentColor = UIColor.systemRed
    private static let lineWidth: CGFloat = 4

    @objc init(mapView: MKMapView) {
        self.mapView = mapView
        super.init()
    }

    // Starts drawing the lines and keeping them up to date
    @objc func attach() {
        NotificationCenter.default.addObserver(self, selector: #selector(update), name: MapPath.changedNotification, object: nil)
        MapPath.shared.checkQueueEmpty()
        update()
    }

    @objc func detach() {
        NotificationCenter.default.removeObserver(self, name: MapPath.changedNotification, object: nil)
        generation += 1
    }

    var hasUnsentPoints: Bool { !MapPath.shared.unsentPoints.isEmpty }

    @objc func update() {
        let today = MapPath.shared.todayPoints
        let unsent = MapPath.shared.unsentPoints
        generation += 1
        let thisGeneration = generation
        DispatchQueue.global(qos: .userInitiated).async {
            let todayPath = PathBuilder.build(today)
            let unsentPath = PathBuilder.build(unsent)
            DispatchQueue.main.async { [self] in
                guard thisGeneration == generation else { return }
                show([(todayPath, MapPathOverlays.todayColor), (unsentPath, MapPathOverlays.unsentColor)])
            }
        }
    }

    // The bounds of the lines and dots, for zooming to fit them
    var pathRect: MKMapRect {
        overlays.reduce(MKMapRect.null) { rect, overlay in
            if let dots = overlay as? PathDotsOverlay {
                return dots.points.reduce(rect) { $0.union(MKMapRect(origin: $1, size: MKMapSize(width: 0, height: 0))) }
            }
            return rect.union(overlay.boundingMapRect)
        }
    }

    private func show(_ paths: [(PathBuilder.Path, UIColor)]) {
        guard let mapView else { return }
        var newOverlays: [MKOverlay] = []
        var newColors: [ObjectIdentifier: UIColor] = [:]
        for (path, color) in paths {
            if !path.lines.isEmpty {
                let line = MKMultiPolyline(path.lines.map { MKPolyline(coordinates: $0, count: $0.count) })
                newOverlays.append(line)
                newColors[ObjectIdentifier(line)] = color
            }
            if !path.dots.isEmpty {
                let dots = PathDotsOverlay(path.dots)
                newOverlays.append(dots)
                newColors[ObjectIdentifier(dots)] = color
            }
        }
        // Add the new lines before removing the old ones, so they don't flicker
        let oldOverlays = overlays
        colors.merge(newColors) { $1 }
        mapView.addOverlays(newOverlays, level: .aboveRoads)
        mapView.removeOverlays(oldOverlays)
        overlays = newOverlays
        colors = newColors
    }

    @objc func renderer(for overlay: MKOverlay) -> MKOverlayRenderer? {
        guard let color = colors[ObjectIdentifier(overlay)] else { return nil }
        if let line = overlay as? MKMultiPolyline {
            let renderer = MKMultiPolylineRenderer(multiPolyline: line)
            renderer.strokeColor = color
            renderer.lineWidth = MapPathOverlays.lineWidth
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }
        if let dots = overlay as? PathDotsOverlay {
            return PathDotsRenderer(overlay: dots, color: color)
        }
        return nil
    }
}
