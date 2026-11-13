//
//  DriveSyncAccount.swift
//  ManicEmu
//
//  Manic MP: the Google account behind the memory-card sync (BP-D23,
//  BP-I44). Sign-in is ASWebAuthenticationSession with PKCE against the
//  fork's own iOS OAuth client; the refresh token lives in the keychain and
//  nowhere else. Separate from upstream's Google Drive import service on
//  purpose: that one signs in with upstream's client id and the read-only
//  scope, and its row is left exactly as upstream ships it.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import AuthenticationServices
import KeychainAccess

actor DriveSyncAccount {
    static let shared = DriveSyncAccount()
    /// Posted on the main queue after sign-in, sign-out or a lost session.
    static let didChange = Notification.Name("ManicDriveSyncAccountDidChange")

    private static let keychainKey = "google-credentials"
    private static let clientIDOverrideKey = "DriveSyncClientID"
    private static let accountNameKey = "DriveSyncAccountName"
    private static let signedInKey = "DriveSyncSignedIn"

    private let keychain = Keychain(service: (Bundle.main.bundleIdentifier ?? "com.globocodes.manicemu") + ".drivesync")
        .accessibility(.afterFirstUnlock)
    private var cached: GoogleCredentials?
    private var refreshing: Task<GoogleCredentials, Error>?

    // MARK: Client id

    /// The id compiled into this build from Config-Local.xcconfig, if any.
    nonisolated static var builtInClientID: GoogleClientID? {
        GoogleClientID(Bundle.main.object(forInfoDictionaryKey: "ManicGoogleClientID") as? String)
    }

    /// The id pasted into Settings; wins over the built-in one.
    nonisolated static var clientIDOverride: String? {
        get { UserDefaults.standard.string(forKey: clientIDOverrideKey) }
        set {
            if let newValue, GoogleClientID(newValue) != nil {
                UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: clientIDOverrideKey)
            } else {
                UserDefaults.standard.removeObject(forKey: clientIDOverrideKey)
            }
        }
    }

    nonisolated static var clientID: GoogleClientID? {
        GoogleClientID(clientIDOverride) ?? builtInClientID
    }

    // MARK: State the UI reads without waiting

    nonisolated static var isSignedIn: Bool {
        UserDefaults.standard.bool(forKey: signedInKey)
    }

    nonisolated static var accountName: String? {
        UserDefaults.standard.string(forKey: accountNameKey)
    }

    private func publish(signedIn: Bool, name: String?) {
        UserDefaults.standard.set(signedIn, forKey: Self.signedInKey)
        if let name {
            UserDefaults.standard.set(name, forKey: Self.accountNameKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.accountNameKey)
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didChange, object: nil)
        }
    }

    // MARK: Tokens

    private func load() -> GoogleCredentials? {
        if let cached { return cached }
        guard let data = try? keychain.getData(Self.keychainKey),
              let credentials = try? JSONDecoder.driveSync.decode(GoogleCredentials.self, from: data) else {
            return nil
        }
        cached = credentials
        return credentials
    }

    private func store(_ credentials: GoogleCredentials?) {
        cached = credentials
        if let credentials, let data = try? JSONEncoder.driveSync.encode(credentials) {
            try? keychain.set(data, key: Self.keychainKey)
        } else {
            try? keychain.remove(Self.keychainKey)
        }
    }

    /// A bearer token for Drive, renewed when it is about to expire or when
    /// Drive has just refused the current one.
    func accessToken(forceRefresh: Bool) async throws -> String {
        guard let client = Self.clientID else { throw DriveSyncError.notConfigured }
        guard let credentials = load() else {
            // The keychain does not survive a change of signing team; say so
            // instead of failing every sync quietly.
            if Self.isSignedIn { publish(signedIn: false, name: nil) }
            throw DriveSyncError.notSignedIn
        }
        if credentials.isFresh(), !forceRefresh {
            return credentials.accessToken
        }
        if let refreshing {
            return try await refreshing.value.accessToken
        }
        let task = Task { try await GoogleOAuth.refresh(credentials, client: client) }
        refreshing = task
        defer { refreshing = nil }
        do {
            let renewed = try await task.value
            store(renewed)
            Log.debug("[Drive Sync] access token renewed, good until \(renewed.expires)")
            return renewed.accessToken
        } catch DriveSyncError.notSignedIn {
            // Google no longer honours the refresh token.
            store(nil)
            publish(signedIn: false, name: nil)
            throw DriveSyncError.notSignedIn
        }
    }

    func signOut() {
        store(nil)
        publish(signedIn: false, name: nil)
    }

    /// Runs the browser sign-in and keeps the result.
    func signIn() async throws {
        guard let client = Self.clientID else { throw DriveSyncError.notConfigured }
        let pkce = GoogleOAuth.PKCE()
        let state = UUID().uuidString
        let callback = try await DriveSyncWebSignIn.run(url: GoogleOAuth.authorizationURL(client: client, pkce: pkce, state: state),
                                                        callbackScheme: client.callbackScheme)
        let code = try GoogleOAuth.code(fromCallback: callback, state: state)
        var credentials = try await GoogleOAuth.exchange(code: code, client: client, pkce: pkce)
        credentials.accountName = await GoogleOAuth.accountName(accessToken: credentials.accessToken)
        store(credentials)
        publish(signedIn: true, name: credentials.accountName ?? "Google account")
    }
}

/// The system sign-in sheet. It catches the redirect on the client's own URL
/// scheme by itself, so the scheme does not have to be declared in Info.plist.
@MainActor
enum DriveSyncWebSignIn {
    private static var current: ASWebAuthenticationSession?
    private static let anchor = Anchor()

    private final class Anchor: NSObject, ASWebAuthenticationPresentationContextProviding {
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            ApplicationSceneDelegate.applicationWindow ?? ASPresentationAnchor()
        }
    }

    static func run(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callback, error in
                Task { @MainActor in current = nil }
                if let callback {
                    continuation.resume(returning: callback)
                } else {
                    continuation.resume(throwing: error ?? DriveSyncError.badResponse("sign-in"))
                }
            }
            session.presentationContextProvider = anchor
            session.prefersEphemeralWebBrowserSession = false
            current = session
            if !session.start() {
                current = nil
                continuation.resume(throwing: DriveSyncError.badResponse("the sign-in sheet did not open"))
            }
        }
    }
}
