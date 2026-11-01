//
//  FullMapViewController.swift
//  Overland
//
//  The Tracker map, full screen, opened from the expand button over the map. It shows the same
//  path lines, and the system's location dot.
//

import MapKit
import UIKit

@objc(GLFullMapViewController) final class FullMapViewController: UIViewController, MKMapViewDelegate {
    private let mapView = MKMapView()
    private let initialRegion: MKCoordinateRegion
    private lazy var pathOverlays = MapPathOverlays(mapView: mapView)
    private let legend = UIStackView()

    @objc init(region: MKCoordinateRegion) {
        initialRegion = region
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // The same look as the Tracker map
        if #available(iOS 16.0, *) {
            mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
        }
        mapView.pointOfInterestFilter = .excludingAll
        mapView.isPitchEnabled = false
        mapView.showsUserLocation = true
        mapView.delegate = self
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)

        let close = makeButton(symbol: "arrow.down.right.and.arrow.up.left", label: "Close Map", action: #selector(close))
        let fit = makeButton(symbol: "point.topleft.down.to.point.bottomright.curvepath", label: "Show Today's Path", action: #selector(fitPath))
        let tracking = MKUserTrackingButton(mapView: mapView)
        tracking.translatesAutoresizingMaskIntoConstraints = false
        let trackingBackground = makeBackground(for: tracking)

        // The map's own compass would sit under these buttons, so it goes below them instead.
        // It only shows while the map is rotated.
        mapView.showsCompass = false
        let compass = MKCompassButton(mapView: mapView)
        compass.compassVisibility = .adaptive

        let controls = UIStackView(arrangedSubviews: [trackingBackground, fit, compass])
        controls.axis = .vertical
        controls.spacing = 10
        controls.alignment = .center
        controls.translatesAutoresizingMaskIntoConstraints = false

        setUpLegend()

        view.addSubview(close)
        view.addSubview(controls)
        view.addSubview(legend)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            close.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            close.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),

            controls.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            controls.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),

            legend.centerYAnchor.constraint(equalTo: close.centerYAnchor),
            legend.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
        ])

        mapView.setRegion(initialRegion, animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        pathOverlays.attach()
        updateLegend()
        NotificationCenter.default.addObserver(self, selector: #selector(updateLegend), name: MapPath.changedNotification, object: nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        pathOverlays.detach()
        NotificationCenter.default.removeObserver(self, name: MapPath.changedNotification, object: nil)
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    @objc private func fitPath() {
        var rect = pathOverlays.pathRect
        if let location = mapView.userLocation.location {
            rect = rect.union(MKMapRect(origin: MKMapPoint(location.coordinate), size: MKMapSize(width: 0, height: 0)))
        }
        guard !rect.isNull else { return }
        // At least a few hundred meters across, so a short path isn't zoomed in all the way
        let minimum = MKMapPointsPerMeterAtLatitude(rect.origin.coordinate.latitude) * 400
        rect = rect.insetBy(dx: min(0, (rect.width - minimum) / 2), dy: min(0, (rect.height - minimum) / 2))
        mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 60, right: 80), animated: true)
    }

    // MARK: Legend

    private func setUpLegend() {
        legend.axis = .horizontal
        legend.spacing = 12
        legend.alignment = .center
        legend.isLayoutMarginsRelativeArrangement = true
        legend.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        legend.translatesAutoresizingMaskIntoConstraints = false
        legend.addArrangedSubview(legendItem("Today", color: MapPathOverlays.todayColor))
        legend.addArrangedSubview(legendItem("Not sent yet", color: MapPathOverlays.unsentColor))
        let background = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        background.layer.cornerRadius = 14
        background.clipsToBounds = true
        background.translatesAutoresizingMaskIntoConstraints = false
        legend.insertSubview(background, at: 0)
        NSLayoutConstraint.activate([
            background.topAnchor.constraint(equalTo: legend.topAnchor),
            background.bottomAnchor.constraint(equalTo: legend.bottomAnchor),
            background.leadingAnchor.constraint(equalTo: legend.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: legend.trailingAnchor),
        ])
    }

    private func legendItem(_ title: String, color: UIColor) -> UIView {
        let swatch = UIView()
        swatch.backgroundColor = color
        swatch.layer.cornerRadius = 2
        swatch.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            swatch.widthAnchor.constraint(equalToConstant: 16),
            swatch.heightAnchor.constraint(equalToConstant: 4),
        ])
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .footnote)
        let item = UIStackView(arrangedSubviews: [swatch, label])
        item.spacing = 6
        item.alignment = .center
        return item
    }

    // Only needed when there's a red line to explain
    @objc private func updateLegend() {
        legend.isHidden = !pathOverlays.hasUnsentPoints
    }

    // MARK: Buttons

    private func makeButton(symbol: String, label: String, action: Selector) -> UIButton {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .glass()
        } else {
            config = .filled()
            config.baseBackgroundColor = .secondarySystemBackground
            config.baseForegroundColor = .tintColor
        }
        config.image = UIImage(systemName: symbol)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        config.cornerStyle = .capsule
        let button = UIButton(configuration: config)
        button.accessibilityLabel = label
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
        ])
        return button
    }

    // MKUserTrackingButton has no background of its own
    private func makeBackground(for tracking: MKUserTrackingButton) -> UIView {
        let background: UIView
        if #available(iOS 26.0, *) {
            let glass = UIVisualEffectView(effect: UIGlassEffect())
            glass.contentView.addSubview(tracking)
            background = glass
        } else {
            background = UIView()
            background.backgroundColor = .secondarySystemBackground
            background.addSubview(tracking)
        }
        background.layer.cornerRadius = 22
        background.clipsToBounds = true
        background.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            background.widthAnchor.constraint(equalToConstant: 44),
            background.heightAnchor.constraint(equalToConstant: 44),
            tracking.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            tracking.centerYAnchor.constraint(equalTo: background.centerYAnchor),
        ])
        return background
    }

    // MARK: MKMapViewDelegate

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        pathOverlays.renderer(for: overlay) ?? MKOverlayRenderer(overlay: overlay)
    }
}
