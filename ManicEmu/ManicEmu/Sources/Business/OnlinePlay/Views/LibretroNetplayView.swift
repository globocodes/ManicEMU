//
//  LibretroNetplayView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/15.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UIKit

///程序运行周期内有效的联机会话缓存
final class LibretroNetplaySession {
    static let shared = LibretroNetplaySession()
    
    var isHosting = false
    var isConnected = false
    var connectedHost: LibretroHost?
    var internetHosts: [LibretroHost] = []
    var lanHosts: [LibretroHost] = []
    
    var isNetplay: Bool {
        isHosting || isConnected
    }
    
    private init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleNetplayEvent(_:)),
                                               name: Notification.Name(rawValue: "LibretroNetplayEventNotification"),
                                               object: nil)
    }
    
    func isSelected(_ host: LibretroHost) -> Bool {
        guard isConnected, let connectedHost else { return false }
        return Self.identity(of: host) == Self.identity(of: connectedHost)
    }
    
    static func identity(of host: LibretroHost) -> String {
        if host.hostMethod == .MITM {
            return "mitm:\(host.mitmAddress ?? ""):\(host.mitmPort):\(host.mitmSession ?? "")"
        }
        return "\(host.isLan ? "lan" : "wan"):\(host.address ?? ""):\(host.port)"
    }
    
    func clear() {
        isHosting = false
        isConnected = false
        connectedHost = nil
        internetHosts = []
        lanHosts = []
    }
    
    @objc private func handleNetplayEvent(_ notification: Notification) {
        guard let raw = notification.userInfo?["event"] as? Int,
              let event = LibretroNetplayEvent(rawValue: raw) else { return }
        UIView.hideLoading()
        
        switch event {
        case .hostStarted:
            isHosting = true
            isConnected = false
            UIView.makeToast(message: R.string.localizable.startNetplayHost())
            
        case .hostStopped:
            isHosting = false
            UIView.makeToast(message: R.string.localizable.stopNetplayHost())
            
        case .connected:
            isConnected = true
            isHosting = false
            if let info = notification.userInfo?["info"] as? String {
                UIView.makeToast(message: R.string.localizable.connectHostSuccess(info))
            }
            
        case .disconnected:
            isConnected = false
            connectedHost = nil
            UIView.makeToast(message: R.string.localizable.disconnectWithHost())
            
        case .peerConnected:
            if let info = notification.userInfo?["info"] as? String {
                UIView.makeToast(message: R.string.localizable.clientConnectSuccess(info))
            }
            
        case .peerDisconnected:
            if let info = notification.userInfo?["info"] as? String {
                UIView.makeToast(message: R.string.localizable.disconnectWithClient(info))
            }
            
        case .peerJoined:
            if let info = notification.userInfo?["info"] as? String {
                UIView.makeToast(message: R.string.localizable.joinedGameSuccess(info))
            }
            
        case .peerLeft:
            if let info = notification.userInfo?["info"] as? String {
                UIView.makeToast(message: R.string.localizable.leftGameSuccess(info))
            }
            
        @unknown default:
            break
        }
    }
}

class LibretroNetplayView: BaseView {
    ///If the game is not empty, it means it's in a gameplay configuration.
    private let game: Game?
    private var hideCompletion: (() -> Void)? = nil
    private var netplayObserver: NSObjectProtocol?
    
    ///未运行时每一项对应一个独立 section
    private enum IdleItem: Int, CaseIterable {
        case publicAnnounce
        case useRelay
        case password
        case spectator
        case spectatePassword
        /// Manic MP: tuning for the fork's lockstep netplay. Kept last so the stock
        /// items keep their section indices; hidden outside the sideload build.
        case inputLatency
        case checkFrames
        case shareController
        
        static var shown: [IdleItem] {
#if SIDE_LOAD
            return allCases
#else
            return allCases.filter({ !$0.isManicMP })
#endif
        }
        
        var isManicMP: Bool {
            switch self {
            case .inputLatency, .checkFrames, .shareController: return true
            default: return false
            }
        }
        
        var configKey: String {
            switch self {
            case .publicAnnounce: return "netplay_public_announce"
            case .useRelay: return "netplay_use_mitm_server"
            case .password: return "netplay_password"
            case .spectator: return "netplay_start_as_spectator"
            case .spectatePassword: return "netplay_spectate_password"
            case .inputLatency: return "netplay_input_latency_frames_min"
            case .checkFrames: return "netplay_check_frames"
            case .shareController: return "netplay_request_device_p1"
            }
        }
        
        var title: String {
            switch self {
            case .publicAnnounce: return R.string.localizable.publiclyAnnounceNetplay()
            case .useRelay: return R.string.localizable.useRelayServer()
            case .password: return R.string.localizable.serverPassword()
            case .spectator: return R.string.localizable.netplaySpectatorMode()
            case .spectatePassword: return R.string.localizable.serverSpectateOnlyPassword()
            case .inputLatency: return "Input Latency Frames"
            case .checkFrames: return "Desync Check Interval"
            case .shareController: return "Share Controller 1"
            }
        }
        
        var detail: String {
            switch self {
            case .publicAnnounce:
                return R.string.localizable.publiclyAnnounceNetplayDesc()
            case .useRelay:
                return R.string.localizable.useRelayServerDesc()
            case .password:
                return R.string.localizable.serverPasswordDesc()
            case .spectator:
                return R.string.localizable.netplaySpectatorModeDesc()
            case .spectatePassword:
                return R.string.localizable.serverSpectateOnlyPasswordDesc()
            case .inputLatency:
                return "Frames your own input is held back so the other players' input can arrive in time. GameCube netplay never rewinds: too low and the game stutters on every late packet, too high and the controls feel heavy. Use the same value on every device. 3 suits a home network; try 5-8 over the internet."
            case .checkFrames:
                return "Every this many frames the players compare game memory, and a player that has drifted reloads the host's state. 0 turns the check off; use that if the game pauses at regular intervals."
            case .shareController:
                return "Every player drives controller 1 together, for single-player games like Animal Crossing. Turn it on for every device in the session."
            }
        }
        
        var icon: ASIcon {
            switch self {
            case .publicAnnounce: return .symbolImage(R.image.online_iconSymbols())
            case .useRelay: return .symbol(.wifi)
            case .password, .spectatePassword: return .symbolImage(R.image.key_iconSymbols())
            case .spectator: return .symbol(.eye)
            case .inputLatency: return .symbol(.timer)
            case .checkFrames: return .symbol(.sliderHorizontal3)
            case .shareController: return .symbol(.dpadLeftFilled)
            }
        }
        
        var isSwitch: Bool {
            switch self {
            case .publicAnnounce, .useRelay, .spectator, .shareController: return true
            case .password, .spectatePassword, .inputLatency, .checkFrames: return false
            }
        }
        
        /// Non-nil for the items edited as a whole number.
        var integerLimits: (min: Int, max: Int, fallback: Int)? {
            switch self {
            case .inputLatency: return (0, 15, 0)
            case .checkFrames: return (0, 3600, 600)
            default: return nil
            }
        }
        
        /// Everything written when the item changes; the share switch is three
        /// RetroArch settings that only make sense together.
        func configs(isOn: Bool) -> [String: String] {
            guard self == .shareController else {
                return [configKey: isOn ? "true" : "false"]
            }
            /// 2 = OR the digital buttons, 2 = take the larger analog deflection.
            return ["netplay_request_device_p1": isOn ? "true" : "false",
                    "netplay_share_digital": isOn ? "2" : "0",
                    "netplay_share_analog": isOn ? "2" : "0"]
        }
        
        var defaultBool: Bool {
            self == .publicAnnounce
        }
    }
    
    ///运行时 section 类型 用于把动态列表映射回操作
    private enum RuntimeSection {
        case host
        case internet
        case lan
        /// Manic MP: join by address, for hosts no list can show (a tailnet peer).
        case direct
        case disconnect
    }
    
    private static let directAddressKey = "ManicMPNetplayDirectAddress"
    private static let defaultNetplayPort = 55435
    
    private var runtimeSections: [RuntimeSection] = []
    
    private lazy var listView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            self?.handleAction(action)
        }
        return view
    }()
    
    required init?(parameters: Any...) {
        self.game = parameters.compactMap({ $0 as? Game }).first
        super.init(frame: .zero)
        
        addSubview(listView)
        listView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let netplayObserver {
            NotificationCenter.default.removeObserver(netplayObserver)
        }
    }
    
    private var isRuntimeMode: Bool {
        game != nil
    }
    
    private var session: LibretroNetplaySession {
        LibretroNetplaySession.shared
    }
    
    //MARK: - 页面构建
    private func getListPage() -> ASListPage {
        var tools: [ASIcon] = [.symbolImage(R.image.faq_iconSymbols())]
        if let _ = game {
            tools.append(.symbolImage(R.image.ellipsis_iconSymbols()))
        }
        var navigation = ASListPage.Navigation.defaultNavigation(title: R.string.localizable.netplay(),
                                                                 titleIcon: .symbolImage(R.image.online_iconSymbols()),
                                                                 tools: tools)
        navigation.enableClose = true
        return ASListPage(navigation: navigation,
                          sections: isRuntimeMode ? buildRuntimeSections() : buildIdleSections(),
                          backgroundColor: .clear,
                          pageInsets: .insets(top: R.Size.SheetGrabberTopInset))
    }
    
    private func reloadList() {
        listView.updatePage(getListPage())
    }
    
    private func makeHeader(_ detail: String) -> ASListPage.Supplementary {
        .texts([.smallText(detail, numberOfLines: 0)], pin: false)
    }
    
    //MARK: - 未运行游戏
    private func buildIdleSections() -> [ASListPage.Section] {
        IdleItem.shown.enumerated().map { index, item in
            ASListPage.Section(cells: [makeIdleCell(for: item)],
                               header: makeHeader(item.detail))
        }
    }
    
    private func makeIdleCell(for item: IdleItem) -> ASListPage.Cell {
        if item.isSwitch {
            return ASListPage.Cell.iconTitleDetailSwitchCell(icon: item.icon,
                                                             title: item.title,
                                                             state: boolValue(for: item) ? .on : .off,
                                                             enablePressEffect: false)
        }
        if item.integerLimits != nil {
            return .iconTitleDetailChevronCell(icon: item.icon,
                                               title: item.title,
                                               chevronTitle: "\(intValue(for: item))")
        }
        let password = stringValue(for: item)
        return .iconTitleDetailChevronCell(icon: item.icon,
                                           title: item.title,
                                           chevronTitle: password.isEmpty ? nil : password)
    }
    
    private func intValue(for item: IdleItem) -> Int {
        Int(stringValue(for: item)) ?? item.integerLimits?.fallback ?? 0
    }
    
    private func boolValue(for item: IdleItem) -> Bool {
        let value = LibretroCore.sharedInstance().libretroConfigValue(item.configKey)
        if let value {
            return value == "true"
        }
        return item.defaultBool
    }
    
    private func stringValue(for item: IdleItem) -> String {
        LibretroCore.sharedInstance().libretroConfigValue(item.configKey) ?? ""
    }
    
    private func writeConfig(_ key: String, value: String) {
        writeConfigs([key: value])
    }
    
    private func writeConfigs(_ configs: [String: String]) {
        LibretroCore.sharedInstance().updateLibretroConfigs(configs)
        if PlayViewController.isGaming {
            LibretroCore.sharedInstance().updateRuningLibretroConfigs(configs)
        }
        UIDevice.generateHaptic()
    }
    
    //MARK: - 游戏运行中
    private func buildRuntimeSections() -> [ASListPage.Section] {
        runtimeSections = []
        var sections = [ASListPage.Section]()
        
        runtimeSections.append(.host)
        sections.append(ASListPage.Section(cells: [makeHostSwitchCell()],
                                           header: makeHeader(R.string.localizable.startNetplayHostDesc())))
        
        if !session.isHosting {
            runtimeSections.append(.internet)
            var internetCells = [makeRefreshCell(title: R.string.localizable.refreshNetplayHostList())]
            internetCells.append(contentsOf: session.internetHosts.map({ makeHostCell($0) }))
            sections.append(ASListPage.Section(cells: internetCells,
                                               header: makeHeader(R.string.localizable.refreshNetplayHostListDesc())))
            
            runtimeSections.append(.lan)
            var lanCells = [makeRefreshCell(title: R.string.localizable.refreshNetplayLANList())]
            lanCells.append(contentsOf: session.lanHosts.map({ makeHostCell($0) }))
            sections.append(ASListPage.Section(cells: lanCells,
                                               header: makeHeader(R.string.localizable.refreshNetplayLANListDesc())))
#if SIDE_LOAD
            runtimeSections.append(.direct)
            let lastAddress = UserDefaults.standard.string(forKey: Self.directAddressKey)
            sections.append(ASListPage.Section(cells: [
                .iconTitleDetailChevronCell(icon: .symbol(.wifi),
                                            title: "Connect to Address",
                                            chevronTitle: lastAddress)
            ], header: makeHeader("Join a host by address when it is on neither list, such as a device on your Tailscale network: its tailnet IP or name, optionally followed by :port (default \(Self.defaultNetplayPort)). The host must have started hosting first.")))
#endif
        }
        
        if session.isConnected {
            runtimeSections.append(.disconnect)
            sections.append(ASListPage.Section(cells: [
                .iconTitleChevronCell(icon: .symbolImage(R.image.link_iconSymbols()),
                                      title: R.string.localizable.disconnectedNetPlay())
            ], header: makeHeader(R.string.localizable.disconnectFromNetplayHostDesc())))
        }
        
        return sections
    }
    
    private func makeHostSwitchCell() -> ASListPage.Cell {
        return ASListPage.Cell.iconTitleDetailSwitchCell(icon: .symbolImage(R.image.online_iconSymbols()),
                                                         title: R.string.localizable.startNetplayHost(),
                                                         state: session.isHosting ? .on : .off,
                                                         enablePressEffect: false)
    }
    
    private func makeRefreshCell(title: String) -> ASListPage.Cell {
        .iconTitleDetailChevronCell(icon: .symbolImage(R.image.refresh_iconSymbols()),
                                    title: title)
    }
    
    private func makeHostCell(_ host: LibretroHost) -> ASListPage.Cell {
        var styles = [ASListPage.Cell.Style]()
        styles.append(.icon(.symbolImage(R.image.online_iconSymbols())))
        
        var nickname = displayText(host.nickname, fallback: R.string.localizable.unknownHost())
        
        if let country = host.country {
            nickname += "(\(country.uppercased()))"
        }
        
        var subtitleString = R.string.localizable.internet()
        if host.isLan {
            subtitleString = R.string.localizable.laN()
        } else if host.hostMethod == .MITM {
            subtitleString = R.string.localizable.relay()
        }
        
        var subtitle: ASText = .smallText(subtitleString)
        if !host.connectable {
            subtitle.textIcons = [.init(icon: .symbolImage(R.image.non_connect_iconSymbols(),
                                                           colors: [R.Color.Red]),
                                        iconSize: R.Size.IconSizeExtraSmall.height)]
        } else if host.hasPassword || host.hasSpectatePassword {
            subtitle.textIcons = [.init(icon: .symbolImage(R.image.key_iconSymbols(),
                                                           colors: [R.Color.Yellow]),
                                        iconSize: R.Size.IconSizeExtraSmall.height)]
        }
        
        styles.append(.title(.largeText(nickname),
                             subTitle: subtitle))
        
        if let content = host.content {
            styles.append(.detail(.smallText(content)))
        }
        
        styles.append(.button(.iconOnly(icon: .symbolImage(R.image.info_iconSymbols(),
                                                           colors: [R.Color.LabelSecondary]),
                                        iconSize: CGSize(R.Size.ButtonExtraExtraSmall))))
        
        styles.append(.radio(.init(isSelected: session.isSelected(host))))
        return .normal(styles)
    }
    
    private func displayText(_ value: String?, fallback: String = "") -> String {
        guard let value, !value.isEmpty, value != "N/A" else { return fallback }
        if value == "Anonymous" {
            return R.string.localizable.anonymous()
        }
        return value
    }
    
    private func showHostInfo(host: LibretroHost) {
        var detail = host.description.replacingOccurrences(of: "{", with: "")
        detail = detail.replacingOccurrences(of: "}", with: "")
        detail = detail.replacingOccurrences(of: "\"", with: "")
        detail = detail.replacingOccurrences(of: ",", with: "")
        UIView.makeAlert(detail: detail, detailAlignment: .left)
    }
    
    //MARK: - 事件处理
    private func handleAction(_ action: ASListPage.Action) {
        if let navigationValue = action.navigationValue {
            if navigationValue.isTapClose {
                hide()
            } else if let index = navigationValue.tapToolsValue {
                if index == 0 {
                    //info
                    let desc = EmulationCore.libretroCores.filter({ $0.supportNetplay }).reduce("", { result, core in
                        var gameTypesString: String = ""
                        if let gameTypes = core.gameTypes {
                            gameTypesString = "(\(gameTypes.reduce("", { $0 + ($0.isEmpty ? "" : " ") + $1.localizedShortName })))"
                        }
                        return result + (result.isEmpty ? "" : "   ") + core.name + gameTypesString
                    })
                    UIView.makeAlert(detail: R.string.localizable.netplayDesc(desc), cancelTitle: R.string.localizable.gotIt())
                } else if index == 1 {
                    LibretroNetplayView.show()
                }
            }
            return
        }
        
        guard let (indexPath, cellData, subActions) = action.normalItemValue else { return }
        if isRuntimeMode {
            handleRuntimeAction(indexPath: indexPath, cellData: cellData, subActions: subActions)
        } else {
            handleIdleAction(indexPath: indexPath, cellData: cellData, subActions: subActions)
        }
    }
    
    private func handleIdleAction(indexPath: IndexPath,
                                  cellData: ASListPage.Cell,
                                  subActions: (itemStyle: ASListPage.Cell.Style, extraValue: Any?)?) {
        guard let item = IdleItem(rawValue: indexPath.section) else { return }
        if item.isSwitch {
            guard let isOn = subActions?.extraValue as? Bool else { return }
            writeConfigs(item.configs(isOn: isOn))
            listView.updateCellData(cellData.updateNormalSwitch(state: isOn ? .on : .off),
                                    indexPath: indexPath,
                                    reloadView: false)
        } else if let limits = item.integerLimits {
            LimitedTextInputView.show(icon: item.icon,
                                      title: item.title,
                                      detail: item.detail,
                                      text: "\(intValue(for: item))",
                                      placeholder: item.title,
                                      limitedType: .integer(min: limits.min, max: limits.max)) { [weak self] result in
                guard let self, let value = result as? Int else { return }
                var configs = [item.configKey: "\(value)"]
                if item == .inputLatency {
                    /// A fixed latency: RetroArch would otherwise raise it by itself.
                    configs["netplay_input_latency_frames_range"] = "0"
                }
                self.writeConfigs(configs)
                self.listView.updateCellData(cellData.updateNormalChevron(title: "\(value)"),
                                             indexPath: indexPath)
            }
        } else {
            showPasswordEditor(for: item, cellData: cellData, indexPath: indexPath)
        }
    }
    
    private func showPasswordEditor(for item: IdleItem, cellData: ASListPage.Cell, indexPath: IndexPath) {
        LimitedTextInputView.show(icon: item.icon,
                                  title: item.title,
                                  detail: item.detail,
                                  text: stringValue(for: item),
                                  placeholder: item.title,
                                  limitedType: .normal(maxTextSize: 128, emptyEnable: true)) { [weak self] result in
            guard let self, let password = result as? String else { return }
            self.writeConfig(item.configKey, value: password)
            self.listView.updateCellData(cellData.updateNormalChevron(title: password),
                                         indexPath: indexPath)
        }
    }
    
    private func handleRuntimeAction(indexPath: IndexPath,
                                     cellData: ASListPage.Cell,
                                     subActions: (itemStyle: ASListPage.Cell.Style, extraValue: Any?)?) {
        guard runtimeSections.indices.contains(indexPath.section) else { return }
        switch runtimeSections[indexPath.section] {
        case .host:
            guard let isOn = subActions?.extraValue as? Bool else { return }
            toggleHost(isOn: isOn)
        case .internet:
            if indexPath.row == 0 {
                refreshInternetHosts()
            } else if session.internetHosts.indices.contains(indexPath.row - 1) {
                let host = session.internetHosts[indexPath.row - 1]
                if let _ = subActions {
                    showHostInfo(host: host)
                } else {
                    connect(to: host)
                }
            }
        case .lan:
            if indexPath.row == 0 {
                refreshLANHosts()
            } else if session.lanHosts.indices.contains(indexPath.row - 1) {
                let host = session.lanHosts[indexPath.row - 1]
                if let _ = subActions {
                    showHostInfo(host: host)
                } else {
                    connect(to: host)
                }
            }
        case .direct:
            showDirectConnectEditor()
        case .disconnect:
            disconnect()
        }
    }
    
    private func showDirectConnectEditor() {
        LimitedTextInputView.show(icon: .symbol(.wifi),
                                  title: "Connect to Address",
                                  detail: "Tailnet IP or name of the host, optionally followed by :port.",
                                  text: UserDefaults.standard.string(forKey: Self.directAddressKey),
                                  placeholder: "100.x.y.z",
                                  limitedType: .normal(maxTextSize: 255),
                                  keyboadType: .URL) { [weak self] result in
            guard let self, let text = result as? String else { return }
            let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
            var address = input
            var port = Self.defaultNetplayPort
            /// One colon means host:port; more than one is a bare IPv6 address.
            let parts = input.components(separatedBy: ":")
            if parts.count == 2, let parsed = Int(parts[1]), parsed > 0, parsed < 65536 {
                address = parts[0]
                port = parsed
            }
            guard !address.isEmpty else { return }
            UserDefaults.standard.set(input, forKey: Self.directAddressKey)
            let host = LibretroHost()
            host.nickname = address
            host.address = address
            host.port = port
            host.hostMethod = .manual
            host.connectable = true
            self.connect(to: host)
        }
    }
    
    /// ENABLE_HOST needs a live runloop; dismiss first so hideCompletion resumes.
    private func toggleHost(isOn: Bool) {
        UIView.hideAllAlert(completion: {
            if isOn {
                if LibretroCore.sharedInstance().startNetplayHost(Settings.nickname) {
                    LibretroNetplaySession.shared.isHosting = true
                } else {
                    UIView.makeToast(message: R.string.localizable.startNetplayHostFailed())
                }
            } else {
                LibretroCore.sharedInstance().stopNetplayHost()
                LibretroNetplaySession.shared.isHosting = false
                UIDevice.generateHaptic()
            }
        })
    }
    
    private func refreshInternetHosts() {
        UIView.makeLoading(timeout: R.Numbers.WebLoadingViewTimeout)
        LibretroCore.sharedInstance().refreshNetplayHostList { [weak self] hosts in
            UIView.hideLoading()
            guard let self else { return }
            self.applyHostList(hosts, isLAN: false)
        }
    }
    
    private func refreshLANHosts() {
        UIView.makeLoading(timeout: R.Numbers.WebLoadingViewTimeout)
        LibretroCore.sharedInstance().refreshNetplayLANHostList { [weak self] hosts in
            UIView.hideLoading()
            guard let self else { return }
            self.applyHostList(hosts, isLAN: true)
        }
    }
    
    private func applyHostList(_ hosts: [LibretroHost]?, isLAN: Bool) {
        guard let hosts else {
            UIView.makeToast(message: R.string.localizable.refreshNetplayListFailed())
            return
        }
        
        //Filter out hosts that cannot be connected online.
//        hosts = hosts.filter({ $0.connectable })
        
        if hosts.isEmpty {
            if isLAN {
                session.lanHosts = []
            } else {
                session.internetHosts = []
            }
            reloadList()
            UIView.makeToast(message: R.string.localizable.noHostsFound())
            return
        }
        if isLAN {
            session.lanHosts = hosts
        } else {
            session.internetHosts = hosts
        }
        reloadList()
        UIDevice.generateHaptic()
    }
    
    private func connect(to host: LibretroHost) {
        if session.isSelected(host) {
            return
        }
        
        guard host.connectable else {
            UIView.makeToast(message: R.string.localizable.cannotConnectHost())
            return
        }
        
        UIView.hideAllAlert(completion: {
            if LibretroCore.sharedInstance().connect(toNetplayHost: host, nickname: Settings.nickname) {
                LibretroNetplaySession.shared.connectedHost = host
                LibretroNetplaySession.shared.isConnected = true
            } else {
                UIView.makeToast(message: R.string.localizable.connectNetplayHost())
            }
        })
    }
    
    private func disconnect() {
        LibretroCore.sharedInstance().disconnectNetplay()
        session.isConnected = false
        session.connectedHost = nil
        UIDevice.generateHaptic()
        reloadList()
        UIView.makeToast(message: R.string.localizable.disconnectedNetPlay())
    }
}

extension LibretroNetplayView: ShowableView {
    static func show(game: Game?, hideCompletion: (() -> Void)? = nil) {
        if let game, PlayViewController.isGaming {
            Self.show(parameters: game)?.hideCompletion = hideCompletion
        } else {
            Self.show()?.hideCompletion = hideCompletion
        }
    }
    
    func didHide() {
        hideCompletion?()
    }
}
