//
//  DriveSync.swift
//  ManicEmu
//
//  Manic MP: where the memory-card sync meets the app (BP-D22, BP-I46).
//
//    before a GameCube title boots   pull, blocking, with the conflict and
//                                    "open on another device" questions
//    when the play view goes away    push (the card is read again at +15 s
//                                    and +45 s: the core can flush late)
//    entering the background         push without questions, mid-play too
//    launch / back to the foreground push whatever an earlier attempt left
//
//  One sync runs at a time, never while a game is on screen except for the
//  background push, which only reads the card. Every pull and push leaves a
//  line in Documents/Netplay Logs/Manic MP sessions.log.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

@MainActor
final class DriveSync {
    static let shared = DriveSync()
    /// Posted when a sync finishes or the switch changes.
    static let statusDidChange = Notification.Name("ManicDriveSyncStatusDidChange")

    private static let enabledKey = "DriveSyncEnabled"
    private static let deviceIDKey = "DriveSyncDeviceID"
    private static let lastResultKey = "DriveSyncLastResult"
    /// The core flushes the GCI folder as it stops, sometimes after the play
    /// view is gone (the same reason ACNotificationScheduler reads it thrice).
    private static let sessionEndDelays: [TimeInterval] = [2, 15, 45]

    private var engine: GameCubeCardSync?
    private var queue: Task<Void, Never>?
    private var isSyncing = false

    private init() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in DriveSync.shared.didEnterBackground() }
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in DriveSync.shared.pushLeftovers(reason: "foreground") }
        }
    }

    // MARK: State

    /// The switch in Settings. On by default once signed in.
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            NotificationCenter.default.post(name: Self.statusDidChange, object: nil)
        }
    }

    /// Signed in, configured and switched on.
    var isActive: Bool {
        isEnabled && DriveSyncAccount.isSignedIn && DriveSyncAccount.clientID != nil
    }

    private(set) var lastResult: String? {
        get { UserDefaults.standard.string(forKey: Self.lastResultKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.lastResultKey)
            NotificationCenter.default.post(name: Self.statusDidChange, object: nil)
        }
    }

    var lastSync: Date? {
        DriveSyncLedger.load(from: Self.ledgerURL).lastSync
    }

    private static var ledgerURL: URL {
        URL(fileURLWithPath: R.Path.Library).appendingPathComponent("Application Support/DriveSync/ledger.json")
    }

    private static var deviceID: String {
        if let id = UserDefaults.standard.string(forKey: deviceIDKey) { return id }
        let id = UUID().uuidString.lowercased()
        UserDefaults.standard.set(id, forKey: deviceIDKey)
        return id
    }

    private func currentEngine() -> GameCubeCardSync {
        if let engine { return engine }
        let remote = GoogleDriveClient { forceRefresh in
            try await DriveSyncAccount.shared.accessToken(forceRefresh: forceRefresh)
        }
        let created = GameCubeCardSync(store: DriveSyncStore(remote: remote),
                                       gcUser: URL(fileURLWithPath: R.Path.Dolphin).appendingPathComponent("User/GC"),
                                       ledgerURL: Self.ledgerURL,
                                       deviceID: Self.deviceID,
                                       deviceName: UIDevice.current.name)
        engine = created
        return created
    }

    /// Runs `work` after whatever sync is already under way.
    private func enqueue(_ work: @escaping @MainActor () async -> Void) {
        let previous = queue
        queue = Task { @MainActor in
            await previous?.value
            self.isSyncing = true
            await work()
            self.isSyncing = false
        }
    }

    private static func log(_ line: String) {
        Log.debug("[Drive Sync] \(line)")
        let folder = R.Path.Document.appendingPathComponent("Netplay Logs")
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let path = folder.appendingPathComponent("Manic MP sessions.log")
        let entry = "\(ISO8601DateFormatter().string(from: Date())) ------ Drive sync | \(line)\n"
        guard let data = entry.data(using: .utf8) else { return }
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: path, contents: data)
        }
    }

    private static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private static func time(_ date: Date?) -> String {
        guard let date else { return "an unknown time" }
        let formatter = DateFormatter()
        formatter.dateStyle = Calendar.current.isDateInToday(date) ? .none : .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: Account

    /// Sign in, create the Drive folder and run a first sync.
    func signIn(completion: @escaping (Error?) -> Void) {
        Task { @MainActor in
            do {
                try await DriveSyncAccount.shared.signIn()
                engine = nil
                try await currentEngine().ensureRemoteFolder()
                isEnabled = true
                Self.log("signed in as \(DriveSyncAccount.accountName ?? "?"), folder \"\(DriveSyncStore.rootName)\" ready")
                completion(nil)
                syncNow()
            } catch {
                Self.log("sign-in failed: \(Self.describe(error))")
                completion(error)
            }
        }
    }

    /// Forgets the account and what this device had in common with it; the
    /// cards on the device and in Drive stay where they are.
    func signOut() {
        Task { @MainActor in
            await DriveSyncAccount.shared.signOut()
            engine = nil
            try? FileManager.default.removeItem(at: Self.ledgerURL)
            lastResult = nil
            Self.log("signed out")
        }
    }

    // MARK: Questions

    /// "Both sides changed": two buttons and no way around them.
    private func ask(_ conflict: DriveSyncConflict) async -> DriveSyncResolution {
        let other = conflict.remoteDevice ?? "another device"
        let file = (conflict.path as NSString).lastPathComponent
        return await withCheckedContinuation { continuation in
            UIView.makeAlert(title: "Two different saves",
                             detail: "\(file)\n\nThis \(UIDevice.current.model) saved it at \(Self.time(conflict.localModified)), and \(other) saved it at \(Self.time(conflict.remoteModified)), since the two last synced. Keep which one? The other stays in the history folder.",
                             cancelTitle: "Keep the one from \(other)",
                             confirmTitle: "Keep this \(UIDevice.current.model)'s",
                             enableForceHide: false,
                             hideAction: { type in
                switch type {
                case .cancel: continuation.resume(returning: .keepRemote)
                case .confirm: continuation.resume(returning: .keepLocal)
                case .other: continuation.resume(returning: .later)
                }
            })
        }
    }

    /// A yes/no sheet; true for the confirm button.
    private func confirm(title: String, detail: String, cancel: String, confirm: String) async -> Bool {
        await withCheckedContinuation { continuation in
            UIView.makeAlert(title: title, detail: detail, cancelTitle: cancel, confirmTitle: confirm, enableForceHide: false, hideAction: { type in
                continuation.resume(returning: type == .confirm)
            })
        }
    }

    /// Takes the spinner down and returns once it is gone (at once when none
    /// is up), so a sheet shown next is not stacked under it.
    private func hideSpinner() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UIView.hideLoading { continuation.resume() }
        }
    }

    // MARK: Before boot

    /// Called from `PlayViewController.startGame` for every game. GameCube
    /// titles wait here for the pull; `proceed` runs when the game may boot
    /// and is dropped when the operator cancels.
    func prepareToPlay(game: Game, proceed: @escaping () -> Void) {
        guard isActive, game.gameType == .ngc else {
            proceed()
            return
        }
        let title = game.displayName
        UIView.makeLoading(timeout: 120)
        enqueue {
            let engine = self.currentEngine()
            let result: Result<(DriveSyncReport, [DriveSyncDeviceRecord]), Error>
            do {
                let report = try await engine.reconcile(resolve: { conflict in
                    await DriveSync.shared.hideSpinner()
                    return await DriveSync.shared.ask(conflict)
                })
                result = .success((report, try await engine.otherDevicesPlaying()))
            } catch {
                result = .failure(error)
            }
            await self.hideSpinner()

            switch result {
            case .failure(let error):
                Self.log("pull before \(title) failed: \(Self.describe(error))")
                self.lastResult = "Pull failed: \(Self.describe(error))"
                let signedOut = (error as? DriveSyncError) == .notSignedIn
                let detail = signedOut
                    ? "Google asks you to sign in again (Settings, Google Drive sync). The save on this device may be older than the one in Drive."
                    : "\(Self.describe(error))\n\nThe save on this device may be older than the one in Drive. If you play now and the other device has played since, you will be asked which save to keep."
                if await self.confirm(title: "Google Drive was not reached", detail: detail, cancel: R.string.localizable.cancelTitle(), confirm: "Play with the local copy") {
                    Self.log("\(title) started with the local copy")
                    proceed()
                }

            case .success((let report, let others)):
                Self.log("pull before \(title): \(report.logLine)")
                self.lastResult = "Pulled: \(report.logLine)"
                if !report.unresolved.isEmpty {
                    UIView.makeToast(message: "The save was not chosen, so \(title) was not started.", duration: 5)
                    return
                }
                if let other = others.first {
                    let detail = "\(other.game ?? "A GameCube game") is open on \(other.deviceName) since \(Self.time(other.since)). If it is still being played there, the two saves will split and you will be asked to pick one."
                    guard await self.confirm(title: "Open on another device", detail: detail, cancel: R.string.localizable.cancelTitle(), confirm: "Play here anyway") else {
                        return
                    }
                    Self.log("\(title) started over the lease of \(other.deviceName)")
                }
                // Best effort: the lease is a warning for the other device,
                // not a reason to keep this one from playing.
                try? await engine.writeLease(playing: true, game: title)
                if !report.downloaded.isEmpty {
                    UIView.makeToast(message: "Loaded the newer save from Google Drive.", duration: 4)
                }
                proceed()
            }
        }
    }

    // MARK: After play

    /// From the play view as it goes away, for every game.
    func playSessionEnded(game: Game) {
        guard isActive, game.gameType == .ngc else { return }
        let title = game.displayName
        for delay in Self.sessionEndDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.push(reason: "after \(title) +\(Int(delay))s", askOnConflict: true, announce: true)
            }
        }
    }

    /// From launch and each return to the foreground: a push that failed or
    /// never ran (no network, a crash mid-play) is sent now.
    func pushLeftovers(reason: String) {
        push(reason: reason, askOnConflict: false, announce: false)
    }

    private func didEnterBackground() {
        guard isActive else { return }
        var background = UIBackgroundTaskIdentifier.invalid
        background = UIApplication.shared.beginBackgroundTask(withName: "Manic Drive sync") {
            UIApplication.shared.endBackgroundTask(background)
            background = .invalid
        }
        push(reason: "background", askOnConflict: false, announce: false, evenWhilePlaying: true) {
            if background != .invalid {
                UIApplication.shared.endBackgroundTask(background)
                background = .invalid
            }
        }
    }

    private func push(reason: String, askOnConflict: Bool, announce: Bool, evenWhilePlaying: Bool = false, finished: (() -> Void)? = nil) {
        guard isActive else {
            finished?()
            return
        }
        enqueue {
            defer { finished?() }
            let playing = PlayViewController.isGaming
            if playing && !evenWhilePlaying { return }
            let engine = self.currentEngine()
            let leaseHeld = await engine.ledger.leaseHeld
            let changed = await engine.hasLocalChanges()
            // Nothing new on this device and no lease to give back: no request.
            guard changed || (leaseHeld && !playing) else { return }
            do {
                var report = DriveSyncReport()
                if changed {
                    let interactive = askOnConflict && UIApplication.shared.applicationState == .active
                    let asker: @Sendable (DriveSyncConflict) async -> DriveSyncResolution = { await DriveSync.shared.ask($0) }
                    report = try await engine.reconcile(resolve: interactive ? asker : nil)
                }
                if leaseHeld && !playing {
                    try await engine.writeLease(playing: false, game: nil)
                }
                Self.log("push (\(reason)): \(report.logLine)")
                self.lastResult = "Pushed: \(report.logLine)"
                if announce {
                    if !report.uploaded.isEmpty {
                        UIView.makeToast(message: "Saved to Google Drive.", duration: 3)
                    } else if !report.unresolved.isEmpty {
                        UIView.makeToast(message: "Not sent to Google Drive: another device saved too. You will be asked which save to keep the next time you play.", duration: 6)
                    }
                }
            } catch {
                Self.log("push (\(reason)) failed: \(Self.describe(error))")
                self.lastResult = "Push failed: \(Self.describe(error))"
                if announce {
                    UIView.makeToast(message: "Not saved to Google Drive yet: \(Self.describe(error)) It is sent the next time Manic opens with a connection.", duration: 6)
                }
            }
        }
    }

    // MARK: On demand

    /// "Sync now" in Settings.
    func syncNow() {
        guard isActive else { return }
        enqueue {
            guard !PlayViewController.isGaming else { return }
            do {
                let report = try await self.currentEngine().reconcile(resolve: { await DriveSync.shared.ask($0) })
                Self.log("sync now: \(report.logLine)")
                self.lastResult = "Synced: \(report.logLine)"
                UIView.makeToast(message: report.changedSomething ? "Synced with Google Drive: \(report.uploaded.count) sent, \(report.downloaded.count) received." : "Already in sync with Google Drive.", duration: 4)
            } catch {
                Self.log("sync now failed: \(Self.describe(error))")
                self.lastResult = "Sync failed: \(Self.describe(error))"
                UIView.makeToast(message: "Sync failed: \(Self.describe(error))", duration: 6)
            }
        }
    }
}
