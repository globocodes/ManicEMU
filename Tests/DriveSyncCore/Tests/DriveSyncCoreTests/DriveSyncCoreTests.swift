//
//  DriveSyncCoreTests.swift
//
//  The memory-card sync against an in-memory Drive: two "devices" (two local
//  folders, two ledgers) sharing one remote.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import XCTest
@testable import DriveSyncCore

/// Drive in a dictionary. Counts calls so a test can say "nothing was sent".
final class FakeDrive: DriveRemote, @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String: DriveEntry] = [:]
    private var contents: [String: Data] = [:]
    private var nextID = 1
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)
    private(set) var uploads = 0
    private(set) var downloads = 0
    private(set) var lists = 0
    /// Bytes handed out instead of the real content, to play a damaged download.
    var corruptDownloads = false

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    private func tick() -> Date {
        clock = clock.addingTimeInterval(1)
        return clock
    }

    private func newID() -> String {
        defer { nextID += 1 }
        return "id\(nextID)"
    }

    func listAll() async throws -> [DriveEntry] {
        locked {
            lists += 1
            return Array(entries.values)
        }
    }

    func createFolder(name: String, parentID: String?) async throws -> DriveEntry {
        locked {
            let now = tick()
            let entry = DriveEntry(id: newID(), name: name, parentID: parentID ?? "my-drive", isFolder: true, md5: nil, modified: now, created: now, size: nil)
            entries[entry.id] = entry
            return entry
        }
    }

    func createFile(name: String, parentID: String, data: Data, modified: Date?, properties: [String: String]) async throws -> DriveEntry {
        locked {
            uploads += 1
            let now = tick()
            let entry = DriveEntry(id: newID(), name: name, parentID: parentID, isFolder: false, md5: DriveSyncHash.md5(data), modified: modified ?? now, created: now, size: Int64(data.count), properties: properties)
            entries[entry.id] = entry
            contents[entry.id] = data
            return entry
        }
    }

    func updateFile(id: String, data: Data, modified: Date?, properties: [String: String]) async throws -> DriveEntry {
        try locked {
            guard var entry = entries[id] else { throw DriveSyncError.http(404, "no such file") }
            uploads += 1
            entry.md5 = DriveSyncHash.md5(data)
            entry.modified = modified ?? tick()
            entry.size = Int64(data.count)
            entry.properties.merge(properties) { _, new in new }
            entries[id] = entry
            contents[id] = data
            return entry
        }
    }

    func download(id: String) async throws -> Data {
        try locked {
            guard let data = contents[id] else { throw DriveSyncError.http(404, "no such file") }
            downloads += 1
            return corruptDownloads ? Data(data.dropLast(7)) : data
        }
    }

    func copy(id: String, name: String, parentID: String) async throws -> DriveEntry {
        try locked {
            guard var entry = entries[id], let data = contents[id] else { throw DriveSyncError.http(404, "no such file") }
            entry.id = newID()
            entry.name = name
            entry.parentID = parentID
            entry.created = tick()
            entries[entry.id] = entry
            contents[entry.id] = data
            return entry
        }
    }

    func delete(id: String) async throws {
        locked {
            entries[id] = nil
            contents[id] = nil
        }
    }

    // Inspection

    func path(of entry: DriveEntry) -> String {
        var parts = [entry.name]
        var current = entry.parentID
        while let id = current, let parent = entries[id] {
            parts.insert(parent.name, at: 0)
            current = parent.parentID
        }
        return parts.joined(separator: "/")
    }

    var filePaths: [String] {
        locked { entries.values.filter { !$0.isFolder }.map(path(of:)).sorted() }
    }

    func entry(at path: String) -> DriveEntry? {
        locked { entries.values.first { self.path(of: $0) == path } }
    }

    func content(at path: String) -> Data? {
        locked { entries.values.first { self.path(of: $0) == path }.flatMap { contents[$0.id] } }
    }
}

final class DriveSyncCoreTests: XCTestCase {
    static let town = "USA/Card A/01-GAFE-DobutsunomoriP_MURA.gci"
    static let remoteTown = "Manic MP/gc/USA/Card A/01-GAFE-DobutsunomoriP_MURA.gci"

    var scratch: URL!
    var drive: FakeDrive!

    override func setUp() {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent("drivesync-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        drive = FakeDrive()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: scratch)
    }

    /// A device: its own GCI folder and ledger, on the shared fake Drive.
    struct Device {
        let name: String
        let gcUser: URL
        let ledgerURL: URL
        let sync: GameCubeCardSync

        func write(_ data: Data, _ path: String = DriveSyncCoreTests.town) throws {
            let url = gcUser.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
        }

        func read(_ path: String = DriveSyncCoreTests.town) -> Data? {
            try? Data(contentsOf: gcUser.appendingPathComponent(path))
        }

        var history: [String] {
            let folder = gcUser.appendingPathComponent(".history/USA/Card A")
            return ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted()
        }
    }

    func device(_ name: String) -> Device {
        let home = scratch.appendingPathComponent(name)
        let gcUser = home.appendingPathComponent("dolphin-emu/User/GC")
        let ledgerURL = home.appendingPathComponent("ledger.json")
        try? FileManager.default.createDirectory(at: gcUser, withIntermediateDirectories: true)
        let sync = GameCubeCardSync(store: DriveSyncStore(remote: drive), gcUser: gcUser, ledgerURL: ledgerURL, deviceID: "id-\(name)", deviceName: name)
        return Device(name: name, gcUser: gcUser, ledgerURL: ledgerURL, sync: sync)
    }

    /// A well-formed GCI: the header and `blocks` blocks of one byte value.
    func card(_ fill: UInt8, blocks: Int = 2) -> Data {
        Data(repeating: fill, count: GCIFile.headerSize + blocks * GCIFile.blockSize)
    }

    // MARK: The ordinary round trip

    func testFirstDeviceUploadsAndSecondDownloads() async throws {
        let ipad = device("GloboPad")
        let iphone = device("GloboPhone")
        try ipad.write(card(1))

        let pushed = try await ipad.sync.reconcile(resolve: nil)
        XCTAssertEqual(pushed.uploaded, [Self.town])
        XCTAssertEqual(drive.filePaths, [Self.remoteTown])
        XCTAssertEqual(drive.entry(at: Self.remoteTown)?.properties["device"], "GloboPad")

        let pulled = try await iphone.sync.reconcile(resolve: nil)
        XCTAssertEqual(pulled.downloaded, [Self.town])
        XCTAssertEqual(iphone.read(), card(1))
        XCTAssertTrue(iphone.history.isEmpty, "nothing was replaced, so nothing goes to history")
    }

    func testPlayOnOneDeviceContinuesOnTheOtherAndBack() async throws {
        let ipad = device("GloboPad")
        let iphone = device("GloboPhone")
        try ipad.write(card(1))
        _ = try await ipad.sync.reconcile(resolve: nil)
        _ = try await iphone.sync.reconcile(resolve: nil)

        // Played on the iPhone.
        try iphone.write(card(2))
        let pushed = try await iphone.sync.reconcile(resolve: nil)
        XCTAssertEqual(pushed.uploaded, [Self.town])
        XCTAssertEqual(drive.content(at: Self.remoteTown), card(2))

        // The iPad boots: it gets the iPhone's town and keeps its own old copy.
        let pulled = try await ipad.sync.reconcile(resolve: { _ in
            XCTFail("one side changed: nobody is asked")
            return .later
        })
        XCTAssertEqual(pulled.downloaded, [Self.town])
        XCTAssertEqual(ipad.read(), card(2))
        XCTAssertEqual(ipad.history.count, 1)
        XCTAssertEqual(try Data(contentsOf: ipad.gcUser.appendingPathComponent(".history/USA/Card A/\(ipad.history[0])")), card(1))

        // And back.
        try ipad.write(card(3))
        _ = try await ipad.sync.reconcile(resolve: nil)
        _ = try await iphone.sync.reconcile(resolve: nil)
        XCTAssertEqual(iphone.read(), card(3))
    }

    func testInSyncSendsNothing() async throws {
        let ipad = device("GloboPad")
        try ipad.write(card(1))
        _ = try await ipad.sync.reconcile(resolve: nil)
        let uploads = drive.uploads

        let again = try await ipad.sync.reconcile(resolve: nil)
        XCTAssertEqual(again.unchanged, 1)
        XCTAssertFalse(again.changedSomething)
        XCTAssertEqual(drive.uploads, uploads)
        XCTAssertEqual(drive.downloads, 0)
    }

    func testUploadReplacesInPlaceAndArchivesTheOldVersion() async throws {
        let ipad = device("GloboPad")
        try ipad.write(card(1))
        _ = try await ipad.sync.reconcile(resolve: nil)
        let firstID = drive.entry(at: Self.remoteTown)?.id

        try ipad.write(card(2))
        _ = try await ipad.sync.reconcile(resolve: nil)

        XCTAssertEqual(drive.entry(at: Self.remoteTown)?.id, firstID, "the same Drive file, not a second one with the same name")
        let history = drive.filePaths.filter { $0.hasPrefix("Manic MP/history/gc/USA/Card A/") }
        XCTAssertEqual(history.count, 1)
        XCTAssertTrue(history[0].hasSuffix(".globopad"), history[0])
        XCTAssertEqual(drive.content(at: history[0]), card(1))
    }

    func testDownloadedFileCarriesTheSaveTime() async throws {
        let ipad = device("GloboPad")
        let iphone = device("GloboPhone")
        try ipad.write(card(1))
        let saved = Date(timeIntervalSince1970: 1_790_000_000)
        try FileManager.default.setAttributes([.modificationDate: saved], ofItemAtPath: ipad.gcUser.appendingPathComponent(Self.town).path)
        _ = try await ipad.sync.reconcile(resolve: nil)
        _ = try await iphone.sync.reconcile(resolve: nil)

        let attributes = try FileManager.default.attributesOfItem(atPath: iphone.gcUser.appendingPathComponent(Self.town).path)
        XCTAssertEqual((attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0, saved.timeIntervalSince1970, accuracy: 1)
    }

    // MARK: Conflicts

    /// Both devices played offline since they last agreed.
    func bothChanged() async throws -> (Device, Device) {
        let ipad = device("GloboPad")
        let iphone = device("GloboPhone")
        try ipad.write(card(1))
        _ = try await ipad.sync.reconcile(resolve: nil)
        _ = try await iphone.sync.reconcile(resolve: nil)
        try iphone.write(card(2))
        _ = try await iphone.sync.reconcile(resolve: nil)
        try ipad.write(card(3))
        return (ipad, iphone)
    }

    func testBothChangedAsksAndNeverCopiesUnasked() async throws {
        let (ipad, _) = try await bothChanged()

        let background = try await ipad.sync.reconcile(resolve: nil)
        XCTAssertEqual(background.unresolved, [Self.town])
        XCTAssertEqual(ipad.read(), card(3))
        XCTAssertEqual(drive.content(at: Self.remoteTown), card(2))

        let later = try await ipad.sync.reconcile(resolve: { _ in .later })
        XCTAssertEqual(later.unresolved, [Self.town], "the question comes back until it is answered")
    }

    func testConflictNamesTheOtherDevice() async throws {
        let (ipad, _) = try await bothChanged()
        let seen = Box<DriveSyncConflict?>(nil)
        _ = try await ipad.sync.reconcile(resolve: { conflict in
            seen.value = conflict
            return .later
        })
        XCTAssertEqual(seen.value?.path, Self.town)
        XCTAssertEqual(seen.value?.remoteDevice, "GloboPhone")
        XCTAssertNotNil(seen.value?.localModified)
    }

    func testKeepThisDeviceUploadsAndKeepsTheOtherInHistory() async throws {
        let (ipad, iphone) = try await bothChanged()
        let report = try await ipad.sync.reconcile(resolve: { _ in .keepLocal })
        XCTAssertEqual(report.uploaded, [Self.town])
        XCTAssertEqual(drive.content(at: Self.remoteTown), card(3))
        let history = drive.filePaths.filter { $0.contains("/history/") }
        XCTAssertTrue(history.contains { drive.content(at: $0) == card(2) && $0.hasSuffix(".globophone") }, "\(history)")

        // The other device then follows without a question.
        _ = try await iphone.sync.reconcile(resolve: { _ in
            XCTFail("the iPhone did not change again")
            return .later
        })
        XCTAssertEqual(iphone.read(), card(3))
    }

    func testKeepDriveDownloadsAndKeepsThisDeviceInLocalHistory() async throws {
        let (ipad, _) = try await bothChanged()
        let report = try await ipad.sync.reconcile(resolve: { _ in .keepRemote })
        XCTAssertEqual(report.downloaded, [Self.town])
        XCTAssertEqual(ipad.read(), card(2))
        XCTAssertTrue(ipad.history.contains { (try? Data(contentsOf: ipad.gcUser.appendingPathComponent(".history/USA/Card A/\($0)"))) == card(3) })
    }

    func testTwoTownsThatNeverMetAreAConflictNotACopy() async throws {
        let ipad = device("GloboPad")
        let iphone = device("GloboPhone")
        try ipad.write(card(1))
        _ = try await ipad.sync.reconcile(resolve: nil)
        try iphone.write(card(9))

        let report = try await iphone.sync.reconcile(resolve: nil)
        XCTAssertEqual(report.unresolved, [Self.town])
        XCTAssertEqual(iphone.read(), card(9))
        XCTAssertEqual(drive.content(at: Self.remoteTown), card(1))
    }

    // MARK: Guards

    func testHistoryKeepsTheNewestTen() async throws {
        let ipad = device("GloboPad")
        for version in 1...14 {
            try ipad.write(card(UInt8(version)))
            // Distinct save times, so every archived version has its own name.
            let saved = Date(timeIntervalSince1970: 1_790_000_000 + Double(version) * 60)
            try FileManager.default.setAttributes([.modificationDate: saved], ofItemAtPath: ipad.gcUser.appendingPathComponent(Self.town).path)
            _ = try await ipad.sync.reconcile(resolve: nil)
        }
        let history = drive.filePaths.filter { $0.contains("/history/") }
        XCTAssertEqual(history.count, GameCubeCardSync.historyKeep)
        XCTAssertFalse(history.contains { drive.content(at: $0) == card(1) }, "the oldest versions are the ones trimmed")
        XCTAssertTrue(history.contains { drive.content(at: $0) == card(13) })
    }

    func testHalfWrittenLocalCardIsNotUploaded() async throws {
        let ipad = device("GloboPad")
        try ipad.write(Data(repeating: 1, count: 1000))
        let report = try await ipad.sync.reconcile(resolve: nil)
        XCTAssertEqual(report.skipped, [Self.town])
        XCTAssertTrue(drive.filePaths.isEmpty)
    }

    func testDamagedDownloadKeepsTheLocalCard() async throws {
        let ipad = device("GloboPad")
        let iphone = device("GloboPhone")
        try ipad.write(card(1))
        _ = try await ipad.sync.reconcile(resolve: nil)
        _ = try await iphone.sync.reconcile(resolve: nil)
        try ipad.write(card(2))
        _ = try await ipad.sync.reconcile(resolve: nil)

        drive.corruptDownloads = true
        do {
            _ = try await iphone.sync.reconcile(resolve: nil)
            XCTFail("a damaged download is an error")
        } catch let error as DriveSyncError {
            guard case .corruptDownload = error else { return XCTFail("\(error)") }
        }
        XCTAssertEqual(iphone.read(), card(1))

        // Nothing was recorded as synced, so the next good pull still happens.
        drive.corruptDownloads = false
        _ = try await iphone.sync.reconcile(resolve: nil)
        XCTAssertEqual(iphone.read(), card(2))
    }

    func testHasLocalChangesIsTheOfflineCheck() async throws {
        let ipad = device("GloboPad")
        try ipad.write(card(1))
        let before = await ipad.sync.hasLocalChanges()
        XCTAssertTrue(before)
        _ = try await ipad.sync.reconcile(resolve: nil)
        let lists = drive.lists
        let after = await ipad.sync.hasLocalChanges()
        XCTAssertFalse(after)
        XCTAssertEqual(drive.lists, lists, "no request is made to answer it")
        try ipad.write(card(2))
        let changed = await ipad.sync.hasLocalChanges()
        XCTAssertTrue(changed)
    }

    func testEveryRegionAndOnlyCardA() async throws {
        let ipad = device("GloboPad")
        try ipad.write(card(1), "USA/Card A/a.gci")
        try ipad.write(card(2), "EUR/Card A/b.gci")
        try ipad.write(card(3), "USA/Card B/c.gci")
        try ipad.write(card(4), "USA/Card A/notes.txt")
        _ = try await ipad.sync.reconcile(resolve: nil)
        XCTAssertEqual(drive.filePaths, ["Manic MP/gc/EUR/Card A/b.gci", "Manic MP/gc/USA/Card A/a.gci"])
    }

    func testTwoAppFoldersSettleOnTheOldest() async throws {
        let first = try await drive.createFolder(name: "Manic MP", parentID: nil)
        _ = try await drive.createFolder(name: "Manic MP", parentID: nil)
        let ipad = device("GloboPad")
        try ipad.write(card(1))
        _ = try await ipad.sync.reconcile(resolve: nil)
        var parent = drive.entry(at: Self.remoteTown)?.parentID
        var top: String?
        while let id = parent {
            top = id
            parent = (try await drive.listAll()).first { $0.id == id }?.parentID
            if parent == "my-drive" { break }
        }
        XCTAssertEqual(top, first.id)
    }

    // MARK: Leases

    func testLeaseIsSeenByTheOtherDeviceOnly() async throws {
        let ipad = device("GloboPad")
        let iphone = device("GloboPhone")
        try ipad.write(card(1))
        _ = try await ipad.sync.reconcile(resolve: nil)
        try await ipad.sync.writeLease(playing: true, game: "Animal Crossing")
        let held = await ipad.sync.ledger.leaseHeld
        XCTAssertTrue(held)

        _ = try await ipad.sync.reconcile(resolve: nil)
        let own = try await ipad.sync.otherDevicesPlaying()
        XCTAssertTrue(own.isEmpty, "a device does not warn about itself")

        _ = try await iphone.sync.reconcile(resolve: nil)
        let seen = try await iphone.sync.otherDevicesPlaying()
        XCTAssertEqual(seen.map(\.deviceName), ["GloboPad"])
        XCTAssertEqual(seen.first?.game, "Animal Crossing")

        try await ipad.sync.writeLease(playing: false, game: nil)
        _ = try await iphone.sync.reconcile(resolve: nil)
        let cleared = try await iphone.sync.otherDevicesPlaying()
        XCTAssertTrue(cleared.isEmpty)
    }

    func testAStaleLeaseDoesNotWarnForever() async throws {
        let ipad = device("GloboPad")
        let iphone = device("GloboPhone")
        let longAgo = Date().addingTimeInterval(-13 * 60 * 60)
        try await ipad.sync.ensureRemoteFolder()
        try await ipad.sync.writeLease(playing: true, game: "Animal Crossing", now: longAgo)
        _ = try await iphone.sync.reconcile(resolve: nil)
        let seen = try await iphone.sync.otherDevicesPlaying()
        XCTAssertTrue(seen.isEmpty)
    }

    // MARK: The Google side

    func testClientIDAcceptsEitherForm() {
        let full = GoogleClientID("123456789-abcdef0123.apps.googleusercontent.com")
        let short = GoogleClientID("  123456789-abcdef0123\n")
        XCTAssertEqual(full, short)
        XCTAssertEqual(full?.clientID, "123456789-abcdef0123.apps.googleusercontent.com")
        XCTAssertEqual(full?.redirectURI, "com.googleusercontent.apps.123456789-abcdef0123:/oauth2redirect")
        XCTAssertNil(GoogleClientID(""))
        XCTAssertNil(GoogleClientID(nil))
        XCTAssertNil(GoogleClientID("$(MANIC_GOOGLE_CLIENT_ID)"))
        XCTAssertNil(GoogleClientID("not a client id"))
    }

    func testAuthorizationURLAndCallback() throws {
        let client = try XCTUnwrap(GoogleClientID("123456789-abcdef0123"))
        let pkce = GoogleOAuth.PKCE()
        let url = GoogleOAuth.authorizationURL(client: client, pkce: pkce, state: "s1")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first { $0.name == "client_id" }?.value, client.clientID)
        XCTAssertEqual(items.first { $0.name == "code_challenge_method" }?.value, "S256")
        XCTAssertTrue(items.first { $0.name == "scope" }?.value?.contains("drive.file") ?? false)
        XCTAssertFalse(items.first { $0.name == "scope" }?.value?.contains("drive.readonly") ?? true)
        XCTAssertFalse(pkce.challenge.contains("="))

        let good = URL(string: "\(client.redirectURI)?state=s1&code=4/abc")!
        XCTAssertEqual(try GoogleOAuth.code(fromCallback: good, state: "s1"), "4/abc")
        XCTAssertThrowsError(try GoogleOAuth.code(fromCallback: good, state: "other"))
        XCTAssertThrowsError(try GoogleOAuth.code(fromCallback: URL(string: "\(client.redirectURI)?error=access_denied")!, state: "s1"))
    }

    func testDriveEntryDecoding() {
        let entry = GoogleDriveClient.entry(from: [
            "id": "f1", "name": "a.gci", "parents": ["p1"], "mimeType": "application/octet-stream",
            "md5Checksum": "abc", "modifiedTime": "2026-11-13T19:04:11.250Z", "createdTime": "2026-11-13T19:04:11Z",
            "size": "16448", "appProperties": ["device": "GloboPad"],
        ])
        XCTAssertEqual(entry?.parentID, "p1")
        XCTAssertEqual(entry?.size, 16448)
        XCTAssertEqual(entry?.isFolder, false)
        XCTAssertEqual(entry?.properties["device"], "GloboPad")
        XCTAssertNotNil(entry?.modified)
        XCTAssertNotNil(entry?.created)
        let folder = GoogleDriveClient.entry(from: ["id": "d1", "name": "gc", "mimeType": GoogleDriveClient.folderMIME])
        XCTAssertEqual(folder?.isFolder, true)
    }

    func testMultipartBodyCarriesMetadataThenBytes() throws {
        var request = URLRequest(url: URL(string: "https://example.invalid")!)
        try GoogleDriveClient.setMultipart(&request, metadata: ["name": "a.gci"], data: Data([0xDE, 0xAD]))
        let body = try XCTUnwrap(request.httpBody)
        let type = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
        let boundary = try XCTUnwrap(type.components(separatedBy: "boundary=").last)
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("--\(boundary)\r\nContent-Type: application/json"))
        XCTAssertTrue(text.contains("{\"name\":\"a.gci\"}"))
        XCTAssertTrue(body.suffix(Data("\r\n--\(boundary)--\r\n".utf8).count + 2).starts(with: [0xDE, 0xAD]))
    }

    func testGCIShape() {
        XCTAssertTrue(GCIFile.looksValid(card(0, blocks: 57)))
        XCTAssertFalse(GCIFile.looksValid(Data(count: GCIFile.headerSize)))
        XCTAssertFalse(GCIFile.looksValid(Data(count: GCIFile.headerSize + GCIFile.blockSize + 1)))
    }
}

/// A mutable value a @Sendable closure may write in a test.
final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}
