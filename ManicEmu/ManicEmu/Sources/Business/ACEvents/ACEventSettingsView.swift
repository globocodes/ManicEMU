//
//  ACEventSettingsView.swift
//  ManicEmu
//
//  The sheet behind "Event notifications" in an Animal Crossing (GAFE01)
//  game's options: on / off with the permission flow, the reminder times,
//  a test notification, and one switch per event.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import ProHUD

/// One list row: an ASListItemView in the sheet's rounded container.
class ACEventSettingCell: UICollectionViewCell {
    var didSwitchValueChange: ((Bool) -> Void)? = nil

    private lazy var itemView: ASListItemView = {
        let view = ASListItemView()
        view.didActionOccurred = { [weak self] style, value in
            guard let self,
                  case .switch = style,
                  let value = value as? Bool else { return }
            self.didSwitchValueChange?(value)
        }
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        let container: UIView = {
            let view = UIView()
            view.backgroundColor = R.Color.BackgroundSecondary
            view.layerCornerRadius = R.Size.CornerRadiusMedium
            return view
        }()

        container.addSubview(itemView)
        itemView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.bottom.equalToSuperview()
        }

        addSubview(container)
        container.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSwitch(icon: ASIcon, title: String, isOn: Bool) {
        itemView.styles = [
            .icon(icon),
            .title(.largeText(title)),
            .switch(.init(state: isOn ? .on : .off)),
        ]
    }

    func setChevron(icon: ASIcon, title: String, value: String?) {
        itemView.styles = [
            .icon(icon),
            .title(.largeText(title)),
            .chevron(.init(title: value)),
        ]
    }
}

class ACEventSettingsView: BaseView {

    private enum Section: Int, CaseIterable {
        case notifications
        case events
    }

    private enum NotificationRow: Int, CaseIterable {
        case enabled
        case leadTime
        case beforeTime
        case test
    }

    private lazy var navigationView: ASNavigationView = {
        let view = ASNavigationView(.defaultNavigation(title: "Event notifications",
                                                       titleIcon: .symbol(.bell)))
        view.didTapClose = { [weak self] in
            guard let self = self else { return }
            self.hide()
        }
        return view
    }()

    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: ACEventSettingCell.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withClass: BackgroundColorHaderReusableView.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withClass: BackgroundColorDetailFooterReusableView.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.isFocusable = true
        view.contentInset = .insets(bottom: R.Size.ContentInsetBottom)
        return view
    }()

    var game: Game
    private let settings = ACEventSettings.shared
    private let scheduler = ACNotificationScheduler.shared
    private let eventKinds = ACEventKind.fixedKinds

    private var hideCompletion: (() -> Void)? = nil

    required init?(parameters: Any...) {
        guard let game = parameters.compactMap({ $0 as? Game }).first else { return nil }
        self.game = game
        super.init(frame: .zero)

        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            make.height.equalTo(R.Size.NavigationHeight)
        }

        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.top.equalTo(navigationView.snp.bottom)
            make.bottom.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                              heightDimension: .absolute(R.Size.ItemHeightLarge)),
                                                           subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                          leading: R.Size.ContentSpaceMedium,
                                                          bottom: 0,
                                                          trailing: R.Size.ContentSpaceMedium)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = R.Size.ContentSpaceTiny
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: R.Size.ContentSpaceSmall, trailing: 0)

            let headerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                            heightDimension: .absolute(44)),
                                                                         elementKind: UICollectionView.elementKindSectionHeader,
                                                                         alignment: .top)
            let footerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                            heightDimension: .estimated(44)),
                                                                         elementKind: UICollectionView.elementKindSectionFooter,
                                                                         alignment: .bottom)
            section.boundarySupplementaryItems = [headerItem, footerItem]
            return section
        }
        return layout
    }

    // MARK: Actions

    private func toggleEnabled(_ on: Bool) {
        scheduler.setEnabled(on) { [weak self] result in
            guard let self else { return }
            if case .denied = result {
                UIView.makeAlert(title: "Notifications are off for Manic",
                                 detail: "Allow notifications for Manic EMU in iOS Settings, then turn event notifications on again.",
                                 cancelTitle: R.string.localizable.cancelTitle(),
                                 confirmTitle: "Open Settings",
                                 confirmAction: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                })
            } else if case .failed(let error) = result {
                UIView.makeToast(message: "Could not ask for permission: \(error.localizedDescription)")
            }
            self.collectionView.reloadData()
        }
    }

    private func pickLeadTime() {
        let options = ACEventSettings.leadOptions
        ChevronSheetView.show(title: "Reminder time on the day",
                              stringOptions: options.map { ACEventSettings.leadText($0) },
                              groupTogether: true,
                              completion: { [weak self] index in
            guard let self, let index else { return }
            self.settings.leadMinutes = options[index]
            self.collectionView.reloadData()
            self.scheduler.rebuildIfEnabled(reason: "lead time")
        })
    }

    private func pickBeforeTime() {
        let options = ACEventSettings.beforeOptions
        ChevronSheetView.show(title: "Before a timed event",
                              stringOptions: options.map { ACEventSettings.beforeText($0) },
                              groupTogether: true,
                              completion: { [weak self] index in
            guard let self, let index else { return }
            self.settings.beforeMinutes = options[index]
            self.collectionView.reloadData()
            self.scheduler.rebuildIfEnabled(reason: "before time")
        })
    }

    private func sendTest() {
        scheduler.sendTestNotification { result in
            switch result {
            case .granted:
                UIView.makeToast(message: "A test notification arrives in a few seconds. Lock the iPad or switch apps to see it on the Lock Screen.", duration: 5)
            case .denied:
                UIView.makeAlert(title: "Notifications are off for Manic",
                                 detail: "Allow notifications for Manic EMU in iOS Settings, then try again.",
                                 cancelTitle: R.string.localizable.cancelTitle(),
                                 confirmTitle: "Open Settings",
                                 confirmAction: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                })
            case .failed(let error):
                UIView.makeToast(message: "Could not send: \(error.localizedDescription)")
            }
        }
    }
}

extension ACEventSettingsView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return Section.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .notifications: return NotificationRow.allCases.count
        case .events: return eventKinds.count
        case .none: return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: ACEventSettingCell.self, for: indexPath)
        cell.didSwitchValueChange = nil
        switch Section(rawValue: indexPath.section) {
        case .notifications:
            switch NotificationRow(rawValue: indexPath.row) {
            case .enabled:
                cell.setSwitch(icon: .symbol(.bell), title: "Notify me about events", isOn: settings.isEnabled)
                cell.didSwitchValueChange = { [weak self] on in
                    self?.toggleEnabled(on)
                }
            case .leadTime:
                cell.setChevron(icon: .symbol(.clock), title: "Reminder time on the day", value: ACEventSettings.leadText(settings.leadMinutes))
            case .beforeTime:
                cell.setChevron(icon: .symbol(.timer), title: "Before a timed event", value: ACEventSettings.beforeText(settings.beforeMinutes))
            case .test:
                cell.setChevron(icon: .symbol(.paperplane), title: "Send a test notification", value: nil)
            case .none:
                break
            }
        case .events:
            let kind = eventKinds[indexPath.row]
            cell.setSwitch(icon: .symbol(.calendar), title: kind.settingsName, isOn: !settings.isMuted(kind))
            cell.didSwitchValueChange = { [weak self] on in
                guard let self else { return }
                self.settings.setMuted(kind, !on)
                self.scheduler.rebuildIfEnabled(reason: "mute")
            }
        case .none:
            break
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: BackgroundColorHaderReusableView.self, for: indexPath)
            header.titleLabel.text = Section(rawValue: indexPath.section) == .events ? "Events" : "Notifications"
            return header
        } else {
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: BackgroundColorDetailFooterReusableView.self, for: indexPath)
            if Section(rawValue: indexPath.section) == .events {
                footer.titleLabel.text = "Switch an event off to stop its notifications. Visitors the game rolls into your save (Redd, Gracie, Saharah, Katrina, Wendell, the sales, Gulliver) come in a later build."
            } else {
                footer.titleLabel.text = "Manic posts a notification on the day of each fixed Animal Crossing event (Joan on Sundays, K.K. on Saturdays, the festivals and the seasons) and another shortly before a timed one starts. Dates follow this device's clock, which is the game's clock. Nothing leaves the device."
            }
            return footer
        }
    }
}

extension ACEventSettingsView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard Section(rawValue: indexPath.section) == .notifications else { return }
        switch NotificationRow(rawValue: indexPath.row) {
        case .leadTime: pickLeadTime()
        case .beforeTime: pickBeforeTime()
        case .test: sendTest()
        default: break
        }
    }
}

extension ACEventSettingsView: ShowableView {
    static func show(game: Game, hideCompletion: (() -> Void)? = nil) {
        Self.show(parameters: game)?.hideCompletion = hideCompletion
    }

    func didHide() {
        hideCompletion?()
    }
}
