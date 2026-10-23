//
//  TripModesViewController.swift
//  Overland
//
//  The Trip Modes screen, where modes are added, edited, reordered and deleted, and the editor for
//  one mode. Opened from Trip Settings and from the trip mode picker.
//

import AppIntents
import UIKit
import WidgetKit

// MARK: - Saving

extension TripModeStore {
    static func save(_ modes: [TripMode]) {
        guard !modes.isEmpty, let data = try? JSONEncoder().encode(modes) else { return }
        UserDefaults(suiteName: SharedTripState.appGroup)?.set(data, forKey: "TripModes")
        modesChanged()
    }

    // Brings back deleted built-in modes and resets the built-in modes' names, symbols and settings.
    // Custom modes are kept, after the built-in ones.
    static func restoreDefaults() {
        let builtInIDs = Set(TripMode.defaults.map(\.id))
        save(TripMode.defaults + modes.filter { !builtInIDs.contains($0.id) })
    }

    // An ID for a new mode, made from its name, such as "kayak" or "e-scooter-2"
    static func newID(forName name: String) -> String {
        let words = name.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let base = words.isEmpty ? "mode" : words.joined(separator: "-")
        var id = base
        var number = 2
        while contains(id) {
            id = "\(base)-\(number)"
            number += 1
        }
        return id
    }

    private static func modesChanged() {
        NotificationCenter.default.post(name: Notification.Name(GLSettingsChangedNotification), object: nil)
        // The snapshot may not change, such as when a mode is renamed, so reload the widgets here
        WidgetCenter.shared.reloadAllTimelines()
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadAllControls()
        }
        if #available(iOS 17.0, *) {
            OverlandShortcuts.updateAppShortcutParameters()
        }
    }
}

// MARK: - List of modes

@objc final class TripModesViewController: UITableViewController {
    private var modes: [TripMode] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Trip Modes"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addMode)),
            editButtonItem,
        ]
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        modes = TripModeStore.modes
        tableView.reloadData()
    }

    @objc private func done() {
        dismiss(animated: true)
    }

    @objc private func addMode() {
        showEditor(for: nil)
    }

    private func showEditor(for mode: TripMode?) {
        navigationController?.pushViewController(TripModeEditViewController(mode: mode), animated: true)
    }

    private func save() {
        TripModeStore.save(modes)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? modes.count : 1
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 0 else { return nil }
        return "Modes are shown in this order in the trip mode picker. Changing a mode's name or icon doesn't change the trip_mode sent to your server."
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        var content = UIListContentConfiguration.valueCell()
        if indexPath.section == 0 {
            let mode = modes[indexPath.row]
            content.image = UIImage(systemName: mode.symbol)
            content.imageProperties.tintColor = .label
            content.text = mode.name
            if let workout = HealthWorkout.forKey(mode.healthWorkout) {
                content.secondaryText = workout.name
                content.secondaryTextProperties.color = .secondaryLabel
            }
            cell.accessoryType = .disclosureIndicator
        } else {
            content = UIListContentConfiguration.cell()
            content.text = "Restore Default Modes"
            content.textProperties.color = view.tintColor
        }
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            showEditor(for: modes[indexPath.row])
        } else {
            confirmRestoreDefaults()
        }
    }

    private func confirmRestoreDefaults() {
        let alert = UIAlertController(title: "Restore Default Modes?",
                                      message: "Deleted built-in modes come back, and the built-in modes' names, icons and settings are reset. Your own modes are kept.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Restore", style: .destructive) { [self] _ in
            TripModeStore.restoreDefaults()
            modes = TripModeStore.modes
            tableView.reloadData()
        })
        present(alert, animated: true)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == 0
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        // There has to be at least one mode
        indexPath.section == 0 && modes.count > 1 ? .delete : .none
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, modes.count > 1 else { return }
        modes.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        save()
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == 0
    }

    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
                            toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        // Keep modes above the Restore row
        if proposedDestinationIndexPath.section != 0 {
            return IndexPath(row: modes.count - 1, section: 0)
        }
        return proposedDestinationIndexPath
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let mode = modes.remove(at: sourceIndexPath.row)
        modes.insert(mode, at: destinationIndexPath.row)
        save()
    }
}

// MARK: - Editing one mode

final class TripModeEditViewController: UITableViewController, UITextFieldDelegate {
    private enum Row {
        case name, symbol, health, zoom, id
    }

    // nil while adding a mode
    private let original: TripMode?
    private var name: String
    private var symbol: String
    private var healthWorkout: String?
    private var closeZoom: Bool
    private let nameField = UITextField()

    private var sections: [[Row]] {
        var sections: [[Row]] = [[.name], [.symbol], [.health], [.zoom]]
        if original != nil {
            sections.append([.id])
        }
        return sections
    }

    init(mode: TripMode?) {
        original = mode
        name = mode?.name ?? ""
        symbol = mode?.symbol ?? "figure.walk"
        healthWorkout = mode?.healthWorkout
        closeZoom = mode?.closeZoom ?? true
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = original == nil ? "New Trip Mode" : original?.name
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))

        nameField.placeholder = "Name, such as Kayak"
        nameField.text = name
        nameField.autocapitalizationType = .words
        nameField.returnKeyType = .done
        nameField.clearButtonMode = .whileEditing
        nameField.delegate = self
        nameField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
        updateSaveButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if original == nil && name.isEmpty {
            nameField.becomeFirstResponder()
        }
    }

    @objc private func nameChanged() {
        name = nameField.text ?? ""
        updateSaveButton()
    }

    private func updateSaveButton() {
        navigationItem.rightBarButtonItem?.isEnabled = !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    @objc private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        var modes = TripModeStore.modes
        if let original = original, let index = modes.firstIndex(where: { $0.id == original.id }) {
            modes[index].name = trimmedName
            modes[index].symbol = symbol
            modes[index].healthWorkout = healthWorkout
            modes[index].closeZoom = closeZoom
        } else {
            modes.append(TripMode(id: TripModeStore.newID(forName: trimmedName), name: trimmedName, symbol: symbol,
                                  closeZoom: closeZoom, healthWorkout: healthWorkout))
        }
        TripModeStore.save(modes)

        // Ask for access to any distance type this workout saves that wasn't asked for before
        if healthWorkout != nil && HealthTripRecorder.shared.isEnabled {
            HealthTripRecorder.shared.requestAuthorization { _ in }
        }
        navigationController?.popViewController(animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section][0] {
        case .name: return "Name"
        case .symbol: return "Icon"
        case .health: return "Apple Health"
        case .zoom: return "Map"
        case .id: return "trip_mode"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch sections[section][0] {
        case .health:
            return HealthTripRecorder.shared.isEnabled
                ? "Trips in this mode are saved to Apple Health as this kind of workout."
                : "Turn on Save to Apple Health in Trip Settings to save trips as workouts."
        case .zoom:
            return "How close the Tracker map zooms in during a trip."
        case .id:
            return "Sent to your server with each point and trip. It stays the same if you rename the mode."
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        switch sections[indexPath.section][indexPath.row] {
        case .name:
            cell.selectionStyle = .none
            nameField.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(nameField)
            NSLayoutConstraint.activate([
                nameField.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                nameField.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                nameField.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                nameField.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
                nameField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            ])
        case .symbol:
            var content = UIListContentConfiguration.valueCell()
            content.text = "Icon"
            content.image = UIImage(systemName: symbol)
            content.imageProperties.tintColor = .label
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
        case .health:
            var content = UIListContentConfiguration.valueCell()
            content.text = "Workout"
            content.secondaryText = HealthWorkout.forKey(healthWorkout)?.name ?? "None"
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
        case .zoom:
            cell.selectionStyle = .none
            var content = UIListContentConfiguration.valueCell()
            content.text = "Zoom"
            cell.contentConfiguration = content
            let control = UISegmentedControl(items: ["Close", "Far"])
            control.selectedSegmentIndex = closeZoom ? 0 : 1
            control.addTarget(self, action: #selector(zoomChanged(_:)), for: .valueChanged)
            cell.accessoryView = control
        case .id:
            cell.selectionStyle = .none
            var content = UIListContentConfiguration.valueCell()
            content.text = original?.id
            content.textProperties.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
            content.textProperties.color = .secondaryLabel
            cell.contentConfiguration = content
        }
        return cell
    }

    @objc private func zoomChanged(_ sender: UISegmentedControl) {
        closeZoom = sender.selectedSegmentIndex == 0
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section][indexPath.row] {
        case .symbol:
            let picker = TripModeSymbolPickerViewController(selected: symbol) { [weak self] symbol in
                self?.symbol = symbol
            }
            navigationController?.pushViewController(picker, animated: true)
        case .health:
            let picker = HealthWorkoutPickerViewController(selected: healthWorkout) { [weak self] key in
                self?.healthWorkout = key
            }
            navigationController?.pushViewController(picker, animated: true)
        default:
            break
        }
    }
}

// MARK: - Choosing a Health workout

final class HealthWorkoutPickerViewController: UITableViewController {
    private var selected: String?
    private let onSelect: (String?) -> Void

    init(selected: String?, onSelect: @escaping (String?) -> Void) {
        self.selected = selected
        self.onSelect = onSelect
        super.init(style: .insetGrouped)
        title = "Workout"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        HealthWorkout.all.count + 1
    }

    // The first row is None
    private func key(at indexPath: IndexPath) -> String? {
        indexPath.row == 0 ? nil : HealthWorkout.all[indexPath.row - 1].key
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        content.text = indexPath.row == 0 ? "None" : HealthWorkout.all[indexPath.row - 1].name
        cell.contentConfiguration = content
        cell.accessoryType = key(at: indexPath) == selected ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selected = key(at: indexPath)
        onSelect(selected)
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - Choosing an icon

final class TripModeSymbolPickerViewController: UICollectionViewController {
    // SF Symbols that suit trip modes. Ones missing on this iOS version are left out.
    private static let groups: [(title: String, symbols: [String])] = [
        ("On Foot", ["figure.walk", "figure.run", "figure.hiking", "figure.stairs", "figure.roll",
                     "figure.roll.runningpace", "figure.walk.motion", "figure.and.child.holdinghands",
                     "dog.fill", "stroller.fill"]),
        ("Wheels", ["bicycle", "figure.outdoor.cycle", "figure.hand.cycling", "scooter", "figure.skateboarding",
                    "figure.skating", "motorcycle.fill", "car.fill", "car.side.fill", "suv.side.fill",
                    "truck.box.fill", "bolt.car.fill", "bus.fill", "bus.doubledecker.fill"]),
        ("Rail", ["tram.fill", "train.side.front.car", "tram.fill.tunnel", "lightrail.fill", "cablecar.fill",
                  "tram.circle.fill"]),
        ("Water", ["sailboat.fill", "ferry.fill", "figure.open.water.swim", "figure.rower",
                   "figure.surfing", "water.waves", "fish.fill"]),
        ("Snow", ["figure.skiing.crosscountry", "figure.skiing.downhill", "figure.snowboarding", "snowflake",
                  "mountain.2.fill"]),
        ("Air", ["airplane", "airplane.departure", "airplane.arrival", "parachute.fill", "balloon.fill"]),
        ("Other", ["figure.equestrian.sports", "figure.golf", "figure.climbing", "tent.fill", "binoculars.fill",
                   "camera.fill", "briefcase.fill", "cart.fill", "house.fill", "building.2.fill", "map.fill",
                   "location.fill", "star.fill", "heart.fill"]),
    ].map { ($0.0, $0.1.filter { UIImage(systemName: $0) != nil }) }.filter { !$0.1.isEmpty }

    private let selected: String
    private let onSelect: (String) -> Void

    init(selected: String, onSelect: @escaping (String) -> Void) {
        self.selected = selected
        self.onSelect = onSelect

        let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .absolute(56), heightDimension: .absolute(56)))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(56)),
                                                       subitems: [item])
        group.interItemSpacing = .flexible(8)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 8
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20)
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(32)),
                                                                 elementKind: UICollectionView.elementKindSectionHeader,
                                                                 alignment: .top)
        section.boundarySupplementaryItems = [header]
        super.init(collectionViewLayout: UICollectionViewCompositionalLayout(section: section))
        title = "Icon"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.register(SymbolCell.self, forCellWithReuseIdentifier: "Cell")
        collectionView.register(UICollectionViewListCell.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: "Header")
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        Self.groups.count
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        Self.groups[section].symbols.count
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                                 at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
        if let header = header as? UICollectionViewListCell {
            var content = UIListContentConfiguration.groupedHeader()
            content.text = Self.groups[indexPath.section].title
            header.contentConfiguration = content
        }
        return header
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! SymbolCell
        let symbol = Self.groups[indexPath.section].symbols[indexPath.item]
        let isSelected = symbol == selected
        cell.imageView.image = UIImage(systemName: symbol)
        cell.imageView.tintColor = isSelected ? .white : .label
        var background = UIBackgroundConfiguration.clear()
        background.backgroundColor = isSelected ? (UIColor(named: "OverlandGreen") ?? .systemGreen) : .secondarySystemGroupedBackground
        background.cornerRadius = 10
        cell.backgroundConfiguration = background
        cell.accessibilityLabel = symbol.replacingOccurrences(of: ".", with: " ")
        cell.accessibilityTraits = isSelected ? [.button, .selected] : .button
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelect(Self.groups[indexPath.section].symbols[indexPath.item])
        navigationController?.popViewController(animated: true)
    }

    private final class SymbolCell: UICollectionViewCell {
        let imageView = UIImageView()

        override init(frame: CGRect) {
            super.init(frame: frame)
            imageView.contentMode = .center
            imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            ])
            isAccessibilityElement = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
