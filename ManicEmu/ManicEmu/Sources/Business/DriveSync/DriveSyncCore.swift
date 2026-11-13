//
//  DriveSyncCore.swift
//  ManicEmu
//
//  Manic MP: GameCube memory cards kept in the operator's Google Drive, so a
//  town played on the iPad continues on the iPhone (BP-D21, BP-D22, BP-I45,
//  BP-I46; docs/google-drive-save-sync-scoping-2026-09-28.md).
//
//  This file is the whole protocol and none of the app: a remote behind a
//  small interface (`DriveRemote`), a path-addressed store over it
//  (`DriveSyncStore`) and the three-way reconcile of the GCI folder
//  (`GameCubeCardSync`). Pure Foundation + CryptoKit on purpose, like
//  ACSaveReader: Tests/DriveSyncCore runs it on the Mac against a fake
//  remote.
//
//  Drive layout, all inside the one folder the app creates (the `drive.file`
//  scope shows the app nothing else):
//
//    Manic MP/
//      gc/<region>/Card A/<file>.gci     mirrors dolphin-emu/User/GC/<region>/Card A/
//      history/gc/<region>/Card A/<file>.gci.<stamp>.<device>   last 10 per file
//      devices/<device id>.json          one lease + last-sync record per device
//
//  The rule for one file, from three md5s (local L, Drive R, and B = the
//  version this device last had in common with Drive, kept in the ledger):
//
//    L == R                  nothing to do
//    only one side exists    copy it to the other
//    B == L (R moved on)     download; the local copy goes to .history first
//    B == R (L moved on)     upload; the Drive copy goes to history/ first
//    neither                 both sides wrote since they last agreed: ask
//
//  No decision reads a clock. Timestamps are carried for display only.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import CryptoKit

// MARK: - The remote

/// One file or folder as Drive lists it.
struct DriveEntry: Equatable, Sendable {
    var id: String
    var name: String
    var parentID: String?
    var isFolder: Bool
    var md5: String?
    var modified: Date?
    var created: Date?
    var size: Int64?
    /// Drive's per-app key/value store on a file. The sync writes the device
    /// that uploaded a card here, and the lease on a device record, so one
    /// listing answers "who wrote this" and "who is playing" with no download.
    var properties: [String: String] = [:]
}

/// What the sync needs from Google Drive. `GoogleDriveClient` is the real
/// one; the tests use an in-memory fake.
protocol DriveRemote: Sendable {
    /// Every file and folder the app can see that is not in the trash.
    func listAll() async throws -> [DriveEntry]
    /// `parentID` nil creates the folder at the top of My Drive.
    func createFolder(name: String, parentID: String?) async throws -> DriveEntry
    func createFile(name: String, parentID: String, data: Data, modified: Date?, properties: [String: String]) async throws -> DriveEntry
    func updateFile(id: String, data: Data, modified: Date?, properties: [String: String]) async throws -> DriveEntry
    func download(id: String) async throws -> Data
    /// A server-side copy; nothing travels through the device.
    func copy(id: String, name: String, parentID: String) async throws -> DriveEntry
    func delete(id: String) async throws
}

enum DriveSyncError: Error, LocalizedError, Equatable {
    case notSignedIn
    case notConfigured
    case timedOut
    case http(Int, String)
    case badResponse(String)
    case corruptDownload(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Not signed in to Google Drive."
        case .notConfigured: return "No Google client id is set for this build."
        case .timedOut: return "Google Drive did not answer in time."
        case .http(let code, let message): return "Google Drive answered \(code): \(message)"
        case .badResponse(let what): return "Unexpected answer from Google Drive (\(what))."
        case .corruptDownload(let name): return "\(name) arrived damaged from Google Drive; the local copy was kept."
        }
    }
}

// MARK: - Small helpers

enum DriveSyncHash {
    static func md5(_ data: Data) -> String {
        Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum DriveSyncStamp {
    /// Sortable and legal in a file name on every side: 2026-11-13T19-04-11Z.
    static func fileStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss'Z'"
        return formatter.string(from: date)
    }

    /// A device name reduced to what is safe as a file-name suffix.
    static func tag(_ deviceName: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let scalars = deviceName.unicodeScalars.filter { allowed.contains($0) }
        let tag = String(String.UnicodeScalarView(scalars)).lowercased()
        return tag.isEmpty ? "device" : String(tag.prefix(24))
    }
}

/// A GCI file is a 0x40 directory entry followed by whole 0x2000 blocks.
/// Anything else is a file caught mid-write or damaged in transit, and is
/// never copied over a good one.
enum GCIFile {
    static let headerSize = 0x40
    static let blockSize = 0x2000

    static func looksValid(_ data: Data) -> Bool {
        data.count >= headerSize + blockSize && (data.count - headerSize) % blockSize == 0
    }
}

// MARK: - The store: paths over the remote

/// Path-addressed access to the app's Drive folder. One `listAll` builds the
/// tree; every write keeps it current, so a sync is one listing plus the
/// transfers it actually needs.
actor DriveSyncStore {
    static let rootName = "Manic MP"

    private let remote: DriveRemote
    private var entries: [String: DriveEntry] = [:]
    private var loaded = false
    private var rootID: String?

    init(remote: DriveRemote) {
        self.remote = remote
    }

    /// Re-reads the tree from Drive.
    func refresh() async throws {
        let all = try await remote.listAll()
        entries = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        loaded = true
        rootID = pickRoot()
    }

    private func ensureLoaded() async throws {
        if !loaded { try await refresh() }
    }

    /// The app folder: a folder named "Manic MP" whose parent is not one of
    /// the app's own folders. Two devices signing in at the same moment can
    /// each create one; every device then settles on the oldest.
    private func pickRoot() -> String? {
        entries.values
            .filter { $0.isFolder && $0.name == Self.rootName && ($0.parentID.map { entries[$0] == nil } ?? true) }
            .sorted(by: Self.older)
            .first?.id
    }

    private static func older(_ a: DriveEntry, _ b: DriveEntry) -> Bool {
        let left = a.created ?? .distantFuture
        let right = b.created ?? .distantFuture
        return left == right ? a.id < b.id : left < right
    }

    private func children(of parentID: String) -> [DriveEntry] {
        entries.values.filter { $0.parentID == parentID }
    }

    /// Same-name siblings can exist on Drive; the oldest is the one every
    /// device agrees on.
    private func child(named name: String, of parentID: String, folder: Bool) -> DriveEntry? {
        children(of: parentID).filter { $0.name == name && $0.isFolder == folder }.sorted(by: Self.older).first
    }

    private func root(create: Bool) async throws -> String? {
        try await ensureLoaded()
        if let rootID { return rootID }
        guard create else { return nil }
        let folder = try await remote.createFolder(name: Self.rootName, parentID: nil)
        entries[folder.id] = folder
        rootID = folder.id
        return folder.id
    }

    /// The folder at `path` under the app folder; created on the way down
    /// when `create` is set.
    func folderID(_ path: [String], create: Bool) async throws -> String? {
        guard var current = try await root(create: create) else { return nil }
        for name in path {
            if let existing = child(named: name, of: current, folder: true) {
                current = existing.id
            } else if create {
                let folder = try await remote.createFolder(name: name, parentID: current)
                entries[folder.id] = folder
                current = folder.id
            } else {
                return nil
            }
        }
        return current
    }

    /// Makes sure the app folder exists (the sign-in check: it shows up in
    /// the operator's Drive straight away).
    func ensureRoot() async throws {
        _ = try await root(create: true)
    }

    func folders(in path: [String]) async throws -> [DriveEntry] {
        guard let id = try await folderID(path, create: false) else { return [] }
        return children(of: id).filter { $0.isFolder }
    }

    func files(in path: [String]) async throws -> [DriveEntry] {
        guard let id = try await folderID(path, create: false) else { return [] }
        var seen = Set<String>()
        // Oldest first, so a duplicated name resolves the same way everywhere.
        return children(of: id).filter { !$0.isFolder }.sorted(by: Self.older).filter { seen.insert($0.name).inserted }
    }

    func file(_ path: [String]) async throws -> DriveEntry? {
        guard let name = path.last else { return nil }
        guard let id = try await folderID(Array(path.dropLast()), create: false) else { return nil }
        return child(named: name, of: id, folder: false)
    }

    /// Creates the file or replaces its content in place (same Drive id, so
    /// Drive's own version history keeps working too).
    @discardableResult
    func put(_ data: Data, at path: [String], modified: Date?, properties: [String: String] = [:]) async throws -> DriveEntry {
        guard let name = path.last, let parent = try await folderID(Array(path.dropLast()), create: true) else {
            throw DriveSyncError.badResponse("empty path")
        }
        let written: DriveEntry
        if let existing = child(named: name, of: parent, folder: false) {
            var updated = try await remote.updateFile(id: existing.id, data: data, modified: modified, properties: properties)
            if updated.parentID == nil { updated.parentID = parent }
            written = updated
        } else {
            var created = try await remote.createFile(name: name, parentID: parent, data: data, modified: modified, properties: properties)
            if created.parentID == nil { created.parentID = parent }
            written = created
        }
        entries[written.id] = written
        return written
    }

    func get(_ entry: DriveEntry) async throws -> Data {
        try await remote.download(id: entry.id)
    }

    /// Copies `entry` into `folder` under `name` unless that name is already
    /// there, then trims the files starting with `prefix` to the newest
    /// `keep` (names end in a sortable stamp).
    func archive(_ entry: DriveEntry, into folder: [String], as name: String, prefix: String, keep: Int) async throws {
        guard let parent = try await folderID(folder, create: true) else { return }
        if child(named: name, of: parent, folder: false) == nil {
            var copy = try await remote.copy(id: entry.id, name: name, parentID: parent)
            if copy.parentID == nil { copy.parentID = parent }
            entries[copy.id] = copy
        }
        let versions = children(of: parent).filter { !$0.isFolder && $0.name.hasPrefix(prefix) }.sorted { $0.name > $1.name }
        for stale in versions.dropFirst(keep) {
            try? await remote.delete(id: stale.id)
            entries[stale.id] = nil
        }
    }
}

// MARK: - The ledger: what this device last had in common with Drive

/// md5 per card file (relative path) as of the last time this device and
/// Drive held the same bytes. Lives outside Documents so it is never synced
/// or shown in Files; losing it only turns the next difference into a
/// question instead of a silent copy.
struct DriveSyncLedger: Codable, Equatable {
    var base: [String: String] = [:]
    var lastSync: Date?
    /// Set while this device holds the play lease, so a crash mid-play is
    /// noticed at the next launch.
    var leaseHeld: Bool = false

    static func load(from url: URL) -> DriveSyncLedger {
        guard let data = try? Data(contentsOf: url),
              let ledger = try? JSONDecoder.driveSync.decode(DriveSyncLedger.self, from: data) else {
            return DriveSyncLedger()
        }
        return ledger
    }

    func save(to url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder.driveSync.encode(self) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

extension JSONEncoder {
    static var driveSync: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var driveSync: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - Leases

/// `devices/<id>.json`. The same fields ride on the file's Drive properties,
/// which is what other devices read.
struct DriveSyncDeviceRecord: Codable, Equatable, Sendable {
    var deviceID: String
    var deviceName: String
    var playing: Bool
    var since: Date?
    var game: String?
    var lastSync: Date?

    var properties: [String: String] {
        var values = ["deviceName": String(deviceName.prefix(60)), "playing": playing ? "1" : "0"]
        if let since { values["since"] = ISO8601DateFormatter().string(from: since) }
        if let game { values["game"] = String(game.prefix(60)) }
        return values
    }

    init(deviceID: String, deviceName: String, playing: Bool, since: Date?, game: String?, lastSync: Date?) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.playing = playing
        self.since = since
        self.game = game
        self.lastSync = lastSync
    }

    init?(entry: DriveEntry) {
        guard entry.name.hasSuffix(".json") else { return nil }
        deviceID = String(entry.name.dropLast(5))
        deviceName = entry.properties["deviceName"] ?? "another device"
        playing = entry.properties["playing"] == "1"
        since = entry.properties["since"].flatMap { ISO8601DateFormatter().date(from: $0) }
        game = entry.properties["game"]
        lastSync = entry.modified
    }
}

// MARK: - The memory-card sync

struct DriveSyncConflict: Sendable {
    /// `USA/Card A/01-GAFE-DobutsunomoriP_MURA.gci`
    var path: String
    var localModified: Date?
    var remoteModified: Date?
    /// The device that uploaded the Drive version, when it said so.
    var remoteDevice: String?
}

enum DriveSyncResolution: Sendable {
    case keepLocal
    case keepRemote
    /// Leave both as they are; the question comes back at the next sync.
    case later
}

struct DriveSyncReport: Sendable, Equatable {
    var uploaded: [String] = []
    var downloaded: [String] = []
    /// Both sides changed and nobody was asked (or the answer was "later").
    var unresolved: [String] = []
    /// Files left alone because they did not look like a whole GCI.
    var skipped: [String] = []
    var unchanged = 0
    var bytesUp = 0
    var bytesDown = 0
    var seconds: Double = 0

    var changedSomething: Bool { !uploaded.isEmpty || !downloaded.isEmpty }

    /// One line for the session log.
    var logLine: String {
        var parts = ["up \(uploaded.count) (\(bytesUp) B)", "down \(downloaded.count) (\(bytesDown) B)", "same \(unchanged)"]
        if !unresolved.isEmpty { parts.append("conflict \(unresolved.joined(separator: ", "))") }
        if !skipped.isEmpty { parts.append("skipped \(skipped.joined(separator: ", "))") }
        parts.append(String(format: "%.1f s", seconds))
        return parts.joined(separator: ", ")
    }
}

actor GameCubeCardSync {
    /// Dolphin's GCI folder holds one of these per region; only Card A is
    /// used (BP-D21).
    static let slot = "Card A"
    static let historyKeep = 10
    /// A lease older than this is a device that crashed or went offline
    /// mid-play, not one that is still playing.
    static let leaseLifetime: TimeInterval = 12 * 60 * 60

    private let store: DriveSyncStore
    /// `Documents/dolphin-emu/User/GC`
    private let gcUser: URL
    private let ledgerURL: URL
    private let deviceID: String
    private let deviceName: String
    private let fileManager = FileManager.default

    init(store: DriveSyncStore, gcUser: URL, ledgerURL: URL, deviceID: String, deviceName: String) {
        self.store = store
        self.gcUser = gcUser
        self.ledgerURL = ledgerURL
        self.deviceID = deviceID
        self.deviceName = deviceName
    }

    var ledger: DriveSyncLedger { DriveSyncLedger.load(from: ledgerURL) }

    // MARK: Local files

    private var localHistory: URL { gcUser.appendingPathComponent(".history") }

    private func localURL(_ path: String) -> URL { gcUser.appendingPathComponent(path) }

    /// `<region>/Card A/<name>.gci` for every card file on this device.
    private func localCardPaths() -> [String] {
        guard let regions = try? fileManager.contentsOfDirectory(atPath: gcUser.path) else { return [] }
        var paths: [String] = []
        for region in regions where !region.hasPrefix(".") {
            let folder = gcUser.appendingPathComponent(region).appendingPathComponent(Self.slot)
            guard let names = try? fileManager.contentsOfDirectory(atPath: folder.path) else { continue }
            for name in names where name.lowercased().hasSuffix(".gci") {
                paths.append("\(region)/\(Self.slot)/\(name)")
            }
        }
        return paths
    }

    private func modificationDate(_ url: URL) -> Date? {
        (try? fileManager.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    /// True when a card file on this device differs from what was last in
    /// common with Drive. No network: this is the cheap check before a push.
    func hasLocalChanges() -> Bool {
        let base = ledger.base
        for path in localCardPaths() {
            guard let data = try? Data(contentsOf: localURL(path)) else { continue }
            if base[path] != DriveSyncHash.md5(data) { return true }
        }
        return false
    }

    // MARK: Remote files

    private func remotePath(_ path: String) -> [String] { ["gc"] + path.split(separator: "/").map(String.init) }

    private func remoteCards() async throws -> [String: DriveEntry] {
        var cards: [String: DriveEntry] = [:]
        for region in try await store.folders(in: ["gc"]) {
            for file in try await store.files(in: ["gc", region.name, Self.slot]) where file.name.lowercased().hasSuffix(".gci") {
                cards["\(region.name)/\(Self.slot)/\(file.name)"] = file
            }
        }
        return cards
    }

    // MARK: Reconcile

    /// Brings this device and Drive to the same memory cards. `resolve` is
    /// asked only when both sides changed since they last agreed; pass nil
    /// where nobody can be asked (in the background) and the file is left
    /// for the next sync.
    func reconcile(resolve: (@Sendable (DriveSyncConflict) async -> DriveSyncResolution)?) async throws -> DriveSyncReport {
        let started = Date()
        try await store.refresh()
        var ledger = self.ledger
        var report = DriveSyncReport()
        let remote = try await remoteCards()
        let paths = Set(localCardPaths()).union(remote.keys).sorted()

        for path in paths {
            let url = localURL(path)
            let localData = try? Data(contentsOf: url)
            let localMD5 = localData.map(DriveSyncHash.md5)
            let entry = remote[path]
            let remoteMD5 = entry?.md5
            let base = ledger.base[path]

            switch (localData, entry) {
            case (nil, nil):
                continue
            case (let data?, nil):
                if try await upload(data, path: path, replacing: nil, report: &report) {
                    ledger.base[path] = localMD5
                }
            case (nil, let entry?):
                if try await download(entry, path: path, replacing: nil, report: &report) {
                    ledger.base[path] = remoteMD5
                }
            case (let data?, let entry?):
                if localMD5 == remoteMD5 {
                    ledger.base[path] = localMD5
                    report.unchanged += 1
                } else if base == localMD5 {
                    if try await download(entry, path: path, replacing: url, report: &report) {
                        ledger.base[path] = remoteMD5
                    }
                } else if base == remoteMD5 {
                    if try await upload(data, path: path, replacing: entry, report: &report) {
                        ledger.base[path] = localMD5
                    }
                } else {
                    let conflict = DriveSyncConflict(path: path,
                                                     localModified: modificationDate(url),
                                                     remoteModified: entry.modified,
                                                     remoteDevice: entry.properties["device"])
                    switch await resolve?(conflict) ?? .later {
                    case .keepLocal:
                        if try await upload(data, path: path, replacing: entry, report: &report) {
                            ledger.base[path] = localMD5
                        }
                    case .keepRemote:
                        if try await download(entry, path: path, replacing: url, report: &report) {
                            ledger.base[path] = remoteMD5
                        }
                    case .later:
                        report.unresolved.append(path)
                    }
                }
            }
            // Saved per file: a sync cut short keeps what it finished.
            ledger.save(to: ledgerURL)
        }

        ledger.lastSync = Date()
        ledger.save(to: ledgerURL)
        report.seconds = Date().timeIntervalSince(started)
        return report
    }

    private func upload(_ data: Data, path: String, replacing entry: DriveEntry?, report: inout DriveSyncReport) async throws -> Bool {
        guard GCIFile.looksValid(data) else {
            report.skipped.append(path)
            return false
        }
        if let entry {
            // The version about to be replaced stays reachable in history/.
            let name = (path as NSString).lastPathComponent
            let stamp = DriveSyncStamp.fileStamp(entry.modified ?? Date())
            let writer = DriveSyncStamp.tag(entry.properties["device"] ?? "unknown")
            let folder = ["history"] + remotePath(path).dropLast()
            try await store.archive(entry, into: Array(folder), as: "\(name).\(stamp).\(writer)", prefix: "\(name).", keep: Self.historyKeep)
        }
        try await store.put(data, at: remotePath(path), modified: modificationDate(localURL(path)), properties: ["device": String(deviceName.prefix(60))])
        report.uploaded.append(path)
        report.bytesUp += data.count
        return true
    }

    private func download(_ entry: DriveEntry, path: String, replacing existing: URL?, report: inout DriveSyncReport) async throws -> Bool {
        let data = try await store.get(entry)
        guard GCIFile.looksValid(data), entry.md5 == nil || entry.md5 == DriveSyncHash.md5(data) else {
            throw DriveSyncError.corruptDownload((path as NSString).lastPathComponent)
        }
        let url = localURL(path)
        if let existing {
            keepLocalHistory(of: existing, path: path)
        }
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        if let modified = entry.modified {
            // The file reads as old as the save it holds, not as the moment
            // it was downloaded.
            try? fileManager.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        }
        report.downloaded.append(path)
        report.bytesDown += data.count
        return true
    }

    /// `.history/<region>/Card A/<name>.gci.<stamp>`, newest ten per file.
    private func keepLocalHistory(of url: URL, path: String) {
        let folder = localHistory.appendingPathComponent((path as NSString).deletingLastPathComponent)
        let name = url.lastPathComponent
        let stamp = DriveSyncStamp.fileStamp(modificationDate(url) ?? Date())
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let copy = folder.appendingPathComponent("\(name).\(stamp)")
        if !fileManager.fileExists(atPath: copy.path) {
            try? fileManager.copyItem(at: url, to: copy)
        }
        let versions = ((try? fileManager.contentsOfDirectory(atPath: folder.path)) ?? [])
            .filter { $0.hasPrefix("\(name).") }
            .sorted(by: >)
        for stale in versions.dropFirst(Self.historyKeep) {
            try? fileManager.removeItem(at: folder.appendingPathComponent(stale))
        }
    }

    // MARK: Leases

    /// Other devices that say they are playing right now. Reads the tree as
    /// of the last `reconcile`.
    func otherDevicesPlaying(now: Date = Date()) async throws -> [DriveSyncDeviceRecord] {
        try await store.files(in: ["devices"])
            .compactMap(DriveSyncDeviceRecord.init(entry:))
            .filter { $0.deviceID != deviceID && $0.playing }
            .filter { record in
                guard let since = record.since else { return false }
                return now.timeIntervalSince(since) < Self.leaseLifetime
            }
    }

    /// Writes this device's record: `playing` with the game while a session
    /// runs, cleared after the push that follows it.
    func writeLease(playing: Bool, game: String?, now: Date = Date()) async throws {
        var ledger = self.ledger
        let record = DriveSyncDeviceRecord(deviceID: deviceID,
                                           deviceName: deviceName,
                                           playing: playing,
                                           since: playing ? now : nil,
                                           game: playing ? game : nil,
                                           lastSync: ledger.lastSync)
        let data = try JSONEncoder.driveSync.encode(record)
        try await store.put(data, at: ["devices", "\(deviceID).json"], modified: now, properties: record.properties)
        ledger.leaseHeld = playing
        ledger.save(to: ledgerURL)
    }

    /// Creates the app folder if this is the first device to sign in.
    func ensureRemoteFolder() async throws {
        try await store.refresh()
        try await store.ensureRoot()
    }
}
