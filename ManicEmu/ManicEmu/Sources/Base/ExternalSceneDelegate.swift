//
//  ExternalSceneDelegate.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/9.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import RealmSwift

/// 连接屏幕镜像的时候使用这个场景
class ExternalSceneDelegate: UIResponder, UIWindowSceneDelegate {
    static var isAirPlaying = false
    var window: UIWindow?
    private var settingsUpdateToken: Any? = nil
    private var membershipNotification: Any? = nil
    private var startPlayGameNotification: Any? = nil
    private var stopPlayGameNotification: Any? = nil
    static weak var airPlayViewController: AirPlayViewController?
    static weak var externalWindow: UIWindow?
    /// Manic MP: what the "AirPlay 720p Stream" setting did to the screen connected now, for the Diagnostics Log.
    static var streamModeNote: String?
    /// Manic MP: true once this app run has moved an external screen off its preferred mode.
    private static var loweredScreenMode = false
    private var screenModeNotification: Any? = nil

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene {
            ExternalSceneDelegate.isAirPlaying = true
            // Manic MP: the screen's mode is chosen before the game window exists, so the window is laid out once.
            let modesBefore = PlayDiagnosticsLogger.screenModes(windowScene.screen)
            let streamModeNote = Self.applyStreamMode(to: windowScene.screen)
            ExternalSceneDelegate.streamModeNote = streamModeNote
            window = UIWindow(windowScene: windowScene)
            ExternalSceneDelegate.externalWindow = window
            window?.tintColor = R.Color.Main
            let airPlayViewController = AirPlayViewController()
            window?.rootViewController = airPlayViewController
            ExternalSceneDelegate.airPlayViewController = airPlayViewController
            window?.makeKeyAndVisible()
            updateScene()
            // Manic MP: the Diagnostics Log (while a logged game runs) says when the external screen came and went.
            PlayDiagnosticsLogger.shared.log("AirPlay", "external screen connected: \(PlayDiagnosticsLogger.screenFacts(windowScene.screen)); \(modesBefore); game window \(window?.isHidden == false ? "shown" : "hidden") (member \(PurchaseManager.isMember), AirPlay setting \(Settings.defalut.airPlay ? "on" : "off"))")
            PlayDiagnosticsLogger.shared.log("AirPlay", streamModeNote)
            screenModeNotification = NotificationCenter.default.addObserver(forName: UIScreen.modeDidChangeNotification, object: windowScene.screen, queue: .main) { notification in
                guard let screen = notification.object as? UIScreen else { return }
                PlayDiagnosticsLogger.shared.log("AirPlay", "external screen mode changed: \(PlayDiagnosticsLogger.screenFacts(screen)); \(PlayDiagnosticsLogger.screenModes(screen))")
            }
            //监听设置airPlay开关
            settingsUpdateToken = Settings.defalut.observe(keyPaths: [\Settings.airPlay]) { [weak self] change in
                guard let self = self else { return }
                switch change {
                case .change(_, _):
                    Log.debug("airPlay开关变化，更新Scene")
                    self.updateScene()
                default:
                    break
                }
            }
            
            //监听会员资格变化
            membershipNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.MembershipChange, object: nil, queue: .main) { [weak self] notification in
                self?.updateScene()
            }
            //监听开始游戏
            startPlayGameNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.StartPlayGame, object: nil, queue: .main) { [weak self] notification in
                self?.updateScene()
            }
            //监听结束游戏
            stopPlayGameNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.StopPlayGame, object: nil, queue: .main) { [weak self] notification in
                self?.updateScene()
            }
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        if let screen = (scene as? UIWindowScene)?.screen {
            PlayDiagnosticsLogger.shared.log("AirPlay", "external screen disconnected: \(PlayDiagnosticsLogger.screenFacts(screen))")
        } else {
            PlayDiagnosticsLogger.shared.log("AirPlay", "external screen disconnected")
        }
        window?.isHidden = true
        window?.removeFromSuperview()
        window = nil
        settingsUpdateToken = nil
        if let membershipNotification = membershipNotification {
            NotificationCenter.default.removeObserver(membershipNotification)
        }
        if let startPlayGameNotification = startPlayGameNotification {
            NotificationCenter.default.removeObserver(startPlayGameNotification)
        }
        if let stopPlayGameNotification = stopPlayGameNotification {
            NotificationCenter.default.removeObserver(stopPlayGameNotification)
        }
        membershipNotification = nil
        if let screenModeNotification = screenModeNotification {
            NotificationCenter.default.removeObserver(screenModeNotification)
        }
        screenModeNotification = nil
        ExternalSceneDelegate.streamModeNote = nil
        ExternalSceneDelegate.isAirPlaying = false
    }

    /// Manic MP: the app setting "AirPlay 720p Stream". With it on, the external
    /// screen is asked for its smallest mode at or above 1280x720, so the AirPlay
    /// picture is lighter to encode, send and decode; the game view and its
    /// swapchain follow the window (960x720 px for a 4:3 core at 720p). An
    /// external screen may list a single mode, and then there is nothing to ask
    /// for. Returns the sentence the Diagnostics Log prints. Main thread.
    private static func applyStreamMode(to screen: UIScreen) -> String {
        let wanted = Settings.defalut.getExtraBool(key: ExtraKey.airPlayLowRes.rawValue) ?? false
        let before = screen.currentMode
        let modes = screen.availableModes
        guard wanted else {
            if loweredScreenMode, let preferred = screen.preferredMode, !PlayDiagnosticsLogger.sameMode(preferred, before) {
                screen.currentMode = preferred
                loweredScreenMode = false
                return "720p stream setting off: screen mode put back to \(PlayDiagnosticsLogger.modeName(preferred)) (was \(PlayDiagnosticsLogger.modeName(before)))"
            }
            loweredScreenMode = false
            return "720p stream setting off: screen mode left at \(PlayDiagnosticsLogger.modeName(before))"
        }
        let candidates = modes.filter { $0.size.width >= 1280 && $0.size.height >= 720 }
        guard let smallest = candidates.min(by: { $0.size.width * $0.size.height < $1.size.width * $1.size.height }) else {
            return "720p stream setting on: the screen lists no mode at or above 1280x720 (\(modes.count) listed), nothing changed"
        }
        if PlayDiagnosticsLogger.sameMode(smallest, before) {
            if modes.count <= 1 {
                return "720p stream setting on: the screen offers only \(PlayDiagnosticsLogger.modeName(before)), nothing to change"
            }
            return "720p stream setting on: \(PlayDiagnosticsLogger.modeName(before)) is already the smallest mode at or above 1280x720, nothing changed"
        }
        screen.currentMode = smallest
        loweredScreenMode = true
        return "720p stream setting on: asked the screen for \(PlayDiagnosticsLogger.modeName(smallest)) (was \(PlayDiagnosticsLogger.modeName(before))); the screen now reports \(PlayDiagnosticsLogger.modeName(screen.currentMode)), \(PlayDiagnosticsLogger.screenFacts(screen))"
    }
    
    private func updateScene() {
        if PurchaseManager.isMember, Settings.defalut.airPlay, PlayViewController.isGaming, PlayViewController.enableAirplay {
            window?.isHidden = false
        } else {
            // Mirror the phone instead
            window?.isHidden = true
        }
    }
}
