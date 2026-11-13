//
//  DriveSyncSettingView.swift
//  ManicEmu
//
//  Manic MP: Settings → Google Drive sync (BP-I44). The account, the switch,
//  "Sync now", and the Google client id for a build compiled without one.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import ProHUD

class DriveSyncSettingView: BaseView {

    private enum Row: Int, CaseIterable {
        case account
        case enabled
        case syncNow
        case clientID
    }

    private lazy var navigationView: ASNavigationView = {
        var navigation = ASListPage.Navigation.defaultNavigation(title: "Google Drive sync",
                                                                 titleIcon: .symbolImage(R.image.icloudsync_iconSymbols()))
        navigation.enableClose = showClose
        let view = ASNavigationView(navigation)
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
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withClass: BackgroundColorDetailFooterReusableView.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.isFocusable = true
        view.contentInset = .insets(bottom: UIDevice.isPad ? (R.Size.ContentInsetBottom + R.Size.HomeTabBarSize.height + R.Size.ContentSpaceLarge) : R.Size.ContentInsetBottom)
        return view
    }()

    private let showClose: Bool
    private var observers: [NSObjectProtocol] = []

    required init?(parameters: Any...) {
        // `show(parameters:)` hands its own variadic list on as one element.
        let flat = parameters.flatMap { ($0 as? [Any]) ?? [$0] }
        self.showClose = flat.compactMap({ $0 as? Bool }).first ?? true
        super.init(frame: .zero)

        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            if showClose {
                make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            } else {
                make.top.equalToSuperview().offset(R.Size.ContentInsetTop)
            }
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.height.equalTo(R.Size.NavigationHeight)
        }

        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(navigationView.snp.bottom)
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.bottom.equalToSuperview()
        }

        for name in [DriveSyncAccount.didChange, DriveSync.statusDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.collectionView.reloadData()
            })
        }
    }

    convenience init(showClose: Bool = true) {
        self.init(parameters: showClose)!
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func createLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, _ in
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
            section.contentInsets = NSDirectionalEdgeInsets(top: R.Size.ContentSpaceSmall, leading: 0, bottom: R.Size.ContentSpaceSmall, trailing: 0)
            let footer = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                        heightDimension: .estimated(120)),
                                                                     elementKind: UICollectionView.elementKindSectionFooter,
                                                                     alignment: .bottom)
            section.boundarySupplementaryItems = [footer]
            return section
        }
    }

    // MARK: What the rows say

    private var clientIDText: String {
        if GoogleClientID(DriveSyncAccount.clientIDOverride) != nil { return "Set here" }
        if DriveSyncAccount.builtInClientID != nil { return "In this build" }
        return "Not set"
    }

    private var lastSyncText: String? {
        guard let date = DriveSync.shared.lastSync else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var footerText: String {
        var text = "GameCube memory cards are kept in a \"\(DriveSyncStore.rootName)\" folder in your Google Drive. Before a GameCube game starts, Manic loads the newest save from Drive; when you close the game, it sends yours. Play on one device, close the game, and continue on the other. Manic sees only the folder it created, and the last ten versions of every save stay in its history folder."
        if DriveSyncAccount.clientID == nil {
            text += "\n\nThis build has no Google client id. Paste the Client ID of the iOS OAuth client (Google Cloud console, project Manic MP) under Google client id, then sign in."
        }
        if let result = DriveSync.shared.lastResult {
            text += "\n\nLast: \(result)"
        }
        return text
    }

    // MARK: Actions

    private func tapAccount() {
        if DriveSyncAccount.isSignedIn {
            UIView.makeAlert(title: "Sign out of Google Drive?",
                             detail: "Saves stay on this device and in Drive. Syncing stops until you sign in again.",
                             cancelTitle: R.string.localizable.cancelTitle(),
                             confirmTitle: "Sign out",
                             confirmAction: {
                DriveSync.shared.signOut()
            })
            return
        }
        guard DriveSyncAccount.clientID != nil else {
            UIView.makeToast(message: "Set the Google client id first.", duration: 4)
            return
        }
        DriveSync.shared.signIn { error in
            if let error {
                // Closing the sign-in sheet is not worth a message.
                if (error as NSError).domain == "com.apple.AuthenticationServices.WebAuthenticationSession", (error as NSError).code == 1 { return }
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                UIView.makeAlert(title: "Sign-in did not finish", detail: message, cancelTitle: R.string.localizable.confirmTitle())
            } else {
                UIView.makeToast(message: "Signed in. The \"\(DriveSyncStore.rootName)\" folder is in your Google Drive.", duration: 4)
            }
        }
    }

    private func tapSyncNow() {
        guard DriveSync.shared.isActive else {
            UIView.makeToast(message: DriveSyncAccount.isSignedIn ? "Turn sync on first." : "Sign in first.", duration: 3)
            return
        }
        DriveSync.shared.syncNow()
    }

    private func tapClientID() {
        let alert = UIAlertController(title: "Google client id",
                                      message: "The Client ID of the iOS OAuth client for com.globocodes.manicemu. It ends in .apps.googleusercontent.com. Leave empty to use the one in this build.",
                                      preferredStyle: .alert)
        alert.addTextField { field in
            field.text = DriveSyncAccount.clientIDOverride
            field.placeholder = "123456789-abc….apps.googleusercontent.com"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: R.string.localizable.cancelTitle(), style: .cancel))
        alert.addAction(UIAlertAction(title: R.string.localizable.confirmTitle(), style: .default) { [weak self, weak alert] _ in
            let text = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty {
                DriveSyncAccount.clientIDOverride = nil
            } else if GoogleClientID(text) != nil {
                DriveSyncAccount.clientIDOverride = text
            } else {
                UIView.makeToast(message: "That does not look like a Google client id.", duration: 4)
            }
            self?.collectionView.reloadData()
        })
        topViewController()?.present(alert, animated: true)
    }
}

extension DriveSyncSettingView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        Row.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: ACEventSettingCell.self, for: indexPath)
        cell.didSwitchValueChange = nil
        switch Row(rawValue: indexPath.row) {
        case .account:
            if DriveSyncAccount.isSignedIn {
                cell.setChevron(icon: .symbol(.personCropCircle), title: DriveSyncAccount.accountName ?? "Google account", value: "Sign out")
            } else {
                cell.setChevron(icon: .symbol(.personCropCircle), title: "Sign in with Google", value: nil)
            }
        case .enabled:
            cell.setSwitch(icon: .symbol(.arrowTriangle2Circlepath), title: "Sync GameCube saves", isOn: DriveSync.shared.isEnabled)
            cell.didSwitchValueChange = { on in
                DriveSync.shared.isEnabled = on
            }
        case .syncNow:
            cell.setChevron(icon: .symbol(.arrowUpArrowDown), title: "Sync now", value: lastSyncText)
        case .clientID:
            cell.setChevron(icon: .symbol(.key), title: "Google client id", value: clientIDText)
        case .none:
            break
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: BackgroundColorDetailFooterReusableView.self, for: indexPath)
        footer.titleLabel.text = footerText
        return footer
    }
}

extension DriveSyncSettingView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch Row(rawValue: indexPath.row) {
        case .account: tapAccount()
        case .syncNow: tapSyncNow()
        case .clientID: tapClientID()
        default: break
        }
    }
}

extension DriveSyncSettingView: ShowableView {

}
