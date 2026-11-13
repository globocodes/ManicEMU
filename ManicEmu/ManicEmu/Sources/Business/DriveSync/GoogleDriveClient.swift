//
//  GoogleDriveClient.swift
//  ManicEmu
//
//  Manic MP: the Google side of the memory-card sync (BP-D23, BP-I44,
//  BP-I45): the OAuth token calls for an iOS client (PKCE, no secret) and
//  the handful of Drive v3 requests `DriveRemote` needs.
//
//  The sync talks to Drive directly instead of through CloudServiceKit's
//  `GoogleDriveServiceProvider`: that provider can only create files (a
//  second upload of a card leaves two files with one name), asks for the
//  read-only scope by default, and has no call that sets `modifiedTime` or
//  the per-file properties the lease uses. Upstream's Google Drive import
//  keeps using CloudServiceKit, untouched.
//
//  Foundation + CryptoKit only, so Tests/DriveSyncCore compiles it on the
//  Mac.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import CryptoKit

// MARK: - Client id

/// The fork's own Google OAuth client (type iOS, bundle id
/// com.globocodes.manicemu). Not a secret, but operator-specific, so it is
/// never in the tracked tree: it comes from `MANIC_GOOGLE_CLIENT_ID` in the
/// untracked Config-Local.xcconfig (through Info.plist) or is pasted once
/// into Settings on a build that was compiled without it (the CI build).
struct GoogleClientID: Equatable, Sendable {
    static let suffix = ".apps.googleusercontent.com"

    /// `<numbers>-<letters>`
    let prefix: String

    /// Accepts the full client id or just its prefix.
    init?(_ raw: String?) {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        if value.hasSuffix(Self.suffix) {
            value = String(value.dropLast(Self.suffix.count))
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        guard !value.isEmpty, value.unicodeScalars.allSatisfy(allowed.contains), value.contains("-") else { return nil }
        prefix = value
    }

    var clientID: String { prefix + Self.suffix }
    /// Google's "iOS URL scheme" for the client; the redirect comes back on it.
    var callbackScheme: String { "com.googleusercontent.apps." + prefix }
    var redirectURI: String { callbackScheme + ":/oauth2redirect" }
}

// MARK: - OAuth

struct GoogleCredentials: Codable, Equatable, Sendable {
    var accessToken: String
    var expires: Date
    var refreshToken: String
    var accountName: String?

    func isFresh(at now: Date = Date()) -> Bool { expires.timeIntervalSince(now) > 60 }
}

enum GoogleOAuth {
    /// Only what the app itself creates in Drive, plus the name shown in
    /// Settings. Both are non-sensitive scopes: no Google review.
    static let scope = "https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/userinfo.profile"
    static let authorizeEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    static let userInfoEndpoint = URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")!

    struct PKCE: Sendable {
        let verifier: String
        let challenge: String

        init() {
            var bytes = [UInt8](repeating: 0, count: 32)
            for index in bytes.indices { bytes[index] = UInt8.random(in: 0...255) }
            verifier = Self.base64URL(Data(bytes))
            challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        }

        static func base64URL(_ data: Data) -> String {
            data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
    }

    static func authorizationURL(client: GoogleClientID, pkce: PKCE, state: String) -> URL {
        var components = URLComponents(url: authorizeEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: client.clientID),
            URLQueryItem(name: "redirect_uri", value: client.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]
        return components.url!
    }

    /// The `code` out of the redirect, or the error Google put there.
    static func code(fromCallback url: URL, state: String) throws -> String {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        if let error = value("error") {
            throw DriveSyncError.http(400, error)
        }
        guard value("state") == state, let code = value("code"), !code.isEmpty else {
            throw DriveSyncError.badResponse("sign-in redirect")
        }
        return code
    }

    static func exchange(code: String, client: GoogleClientID, pkce: PKCE, session: URLSession = .shared) async throws -> GoogleCredentials {
        let json = try await token(form: [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": client.clientID,
            "redirect_uri": client.redirectURI,
            "code_verifier": pkce.verifier,
        ], session: session)
        guard let access = json["access_token"] as? String, let refresh = json["refresh_token"] as? String else {
            throw DriveSyncError.badResponse("token")
        }
        let lifetime = (json["expires_in"] as? Double) ?? 3600
        return GoogleCredentials(accessToken: access, expires: Date().addingTimeInterval(lifetime), refreshToken: refresh, accountName: nil)
    }

    static func refresh(_ credentials: GoogleCredentials, client: GoogleClientID, session: URLSession = .shared) async throws -> GoogleCredentials {
        let json = try await token(form: [
            "grant_type": "refresh_token",
            "refresh_token": credentials.refreshToken,
            "client_id": client.clientID,
        ], session: session)
        guard let access = json["access_token"] as? String else {
            throw DriveSyncError.badResponse("token")
        }
        var renewed = credentials
        renewed.accessToken = access
        renewed.expires = Date().addingTimeInterval((json["expires_in"] as? Double) ?? 3600)
        if let rotated = json["refresh_token"] as? String, !rotated.isEmpty {
            renewed.refreshToken = rotated
        }
        return renewed
    }

    static func accountName(accessToken: String, session: URLSession = .shared) async -> String? {
        var request = URLRequest(url: userInfoEndpoint)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await session.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["name"] as? String
    }

    private static func token(form: [String: String], session: URLSession) async throws -> [String: Any] {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        // URLComponents leaves "+" alone, and a form body reads it as a space.
        request.httpBody = Data((components.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B").utf8)
        let (data, response) = try await session.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            // `invalid_grant` is a refresh token Google no longer honours
            // (revoked, or issued while the consent screen was in Testing).
            if (json["error"] as? String) == "invalid_grant" {
                throw DriveSyncError.notSignedIn
            }
            throw DriveSyncError.http(status, (json["error_description"] as? String) ?? (json["error"] as? String) ?? "token request failed")
        }
        return json
    }
}

// MARK: - Drive v3

/// `DriveRemote` over Drive's REST API. `accessToken(forceRefresh)` hands
/// out the bearer token; a 401 asks once for a fresh one and retries.
struct GoogleDriveClient: DriveRemote {
    static let folderMIME = "application/vnd.google-apps.folder"
    private static let fields = "id,name,parents,mimeType,md5Checksum,modifiedTime,createdTime,size,appProperties"
    private static let api = "https://www.googleapis.com/drive/v3/files"
    private static let upload = "https://www.googleapis.com/upload/drive/v3/files"

    let accessToken: @Sendable (_ forceRefresh: Bool) async throws -> String
    var session: URLSession = GoogleDriveClient.makeSession()

    init(accessToken: @escaping @Sendable (_ forceRefresh: Bool) async throws -> String) {
        self.accessToken = accessToken
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    // MARK: DriveRemote

    func listAll() async throws -> [DriveEntry] {
        var entries: [DriveEntry] = []
        var pageToken: String?
        repeat {
            var components = URLComponents(string: Self.api)!
            components.queryItems = [
                URLQueryItem(name: "q", value: "trashed = false"),
                URLQueryItem(name: "spaces", value: "drive"),
                URLQueryItem(name: "pageSize", value: "1000"),
                URLQueryItem(name: "fields", value: "nextPageToken,files(\(Self.fields))"),
            ]
            if let pageToken {
                components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
            let json = try await object(URLRequest(url: components.url!))
            let files = (json["files"] as? [[String: Any]]) ?? []
            entries.append(contentsOf: files.compactMap(Self.entry(from:)))
            pageToken = json["nextPageToken"] as? String
        } while pageToken != nil
        return entries
    }

    func createFolder(name: String, parentID: String?) async throws -> DriveEntry {
        var metadata: [String: Any] = ["name": name, "mimeType": Self.folderMIME]
        if let parentID { metadata["parents"] = [parentID] }
        var request = URLRequest(url: URL(string: "\(Self.api)?fields=\(Self.fields)")!)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: metadata)
        return try await entry(request)
    }

    func createFile(name: String, parentID: String, data: Data, modified: Date?, properties: [String: String]) async throws -> DriveEntry {
        var metadata: [String: Any] = ["name": name, "parents": [parentID]]
        Self.fill(&metadata, modified: modified, properties: properties)
        var request = URLRequest(url: URL(string: "\(Self.upload)?uploadType=multipart&fields=\(Self.fields)")!)
        request.httpMethod = "POST"
        try Self.setMultipart(&request, metadata: metadata, data: data)
        return try await entry(request)
    }

    func updateFile(id: String, data: Data, modified: Date?, properties: [String: String]) async throws -> DriveEntry {
        var metadata: [String: Any] = [:]
        Self.fill(&metadata, modified: modified, properties: properties)
        var request = URLRequest(url: URL(string: "\(Self.upload)/\(id)?uploadType=multipart&fields=\(Self.fields)")!)
        request.httpMethod = "PATCH"
        try Self.setMultipart(&request, metadata: metadata, data: data)
        return try await entry(request)
    }

    func download(id: String) async throws -> Data {
        try await send(URLRequest(url: URL(string: "\(Self.api)/\(id)?alt=media")!))
    }

    func copy(id: String, name: String, parentID: String) async throws -> DriveEntry {
        var request = URLRequest(url: URL(string: "\(Self.api)/\(id)/copy?fields=\(Self.fields)")!)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["name": name, "parents": [parentID]])
        return try await entry(request)
    }

    func delete(id: String) async throws {
        var request = URLRequest(url: URL(string: "\(Self.api)/\(id)")!)
        request.httpMethod = "DELETE"
        _ = try await send(request)
    }

    // MARK: Requests

    private func send(_ original: URLRequest) async throws -> Data {
        var forceRefresh = false
        while true {
            var request = original
            request.setValue("Bearer \(try await accessToken(forceRefresh))", forHTTPHeaderField: "Authorization")
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch let error as URLError where error.code == .timedOut {
                throw DriveSyncError.timedOut
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 401, !forceRefresh {
                forceRefresh = true
                continue
            }
            guard (200..<300).contains(status) else {
                throw DriveSyncError.http(status, Self.errorMessage(data))
            }
            return data
        }
    }

    private func object(_ request: URLRequest) async throws -> [String: Any] {
        let data = try await send(request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DriveSyncError.badResponse("not an object")
        }
        return json
    }

    private func entry(_ request: URLRequest) async throws -> DriveEntry {
        guard let entry = Self.entry(from: try await object(request)) else {
            throw DriveSyncError.badResponse("file without an id")
        }
        return entry
    }

    // MARK: Encoding

    static func entry(from json: [String: Any]) -> DriveEntry? {
        guard let id = json["id"] as? String, let name = json["name"] as? String else { return nil }
        var size: Int64?
        if let text = json["size"] as? String {
            size = Int64(text)
        } else if let number = json["size"] as? NSNumber {
            size = number.int64Value
        }
        return DriveEntry(id: id,
                          name: name,
                          parentID: (json["parents"] as? [String])?.first,
                          isFolder: (json["mimeType"] as? String) == folderMIME,
                          md5: json["md5Checksum"] as? String,
                          modified: (json["modifiedTime"] as? String).flatMap(date(from:)),
                          created: (json["createdTime"] as? String).flatMap(date(from:)),
                          size: size,
                          properties: (json["appProperties"] as? [String: String]) ?? [:])
    }

    /// RFC 3339 as Drive writes it, with or without fractional seconds.
    static func date(from text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func fill(_ metadata: inout [String: Any], modified: Date?, properties: [String: String]) {
        if let modified { metadata["modifiedTime"] = string(from: modified) }
        if !properties.isEmpty { metadata["appProperties"] = properties }
    }

    /// Drive's `multipart/related` upload: the metadata as JSON, then the bytes.
    static func setMultipart(_ request: inout URLRequest, metadata: [String: Any], data: Data) throws {
        let boundary = "manic-mp-\(UUID().uuidString)"
        var body = Data()
        body.append(Data("--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".utf8))
        body.append(try JSONSerialization.data(withJSONObject: metadata))
        body.append(Data("\r\n--\(boundary)\r\nContent-Type: application/octet-stream\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
    }

    private static func errorMessage(_ data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return String(decoding: data.prefix(200), as: UTF8.self)
    }
}
