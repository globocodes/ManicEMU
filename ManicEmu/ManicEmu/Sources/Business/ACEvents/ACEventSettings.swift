//
//  ACEventSettings.swift
//  ManicEmu
//
//  The operator's choices for Animal Crossing event notifications. They are
//  about one game id (GAFE01) rather than one library entry, so they live in
//  UserDefaults and not on the Game record.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

final class ACEventSettings {
    static let shared = ACEventSettings()

    /// Posted on the main thread after any value changes.
    static let didChange = Notification.Name("ACEventSettingsDidChange")

    /// Day-of reminder times offered, as minutes after midnight.
    static let leadOptions: [Int] = [6 * 60, 7 * 60, 8 * 60, 9 * 60, 10 * 60, 12 * 60]
    /// Minutes before a timed event; 0 is off.
    static let beforeOptions: [Int] = [0, 5, 15, 30, 60]

    static let defaultLeadMinutes = 8 * 60
    static let defaultBeforeMinutes = 15

    private enum Key {
        static let enabled = "ac.events.enabled"
        static let leadMinutes = "ac.events.leadMinutes"
        static let beforeMinutes = "ac.events.beforeMinutes"
        static let mutedKinds = "ac.events.mutedKinds"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The feature switch. Notifications are scheduled only while this is
    /// on and GAFE01 is in the library.
    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled); changed() }
    }

    /// When the day-of reminder fires, as minutes after midnight (8:00 by default).
    var leadMinutes: Int {
        get {
            let value = defaults.object(forKey: Key.leadMinutes) as? Int
            return value ?? Self.defaultLeadMinutes
        }
        set { defaults.set(newValue, forKey: Key.leadMinutes); changed() }
    }

    /// Minutes before a timed event for the second reminder; 0 turns it off.
    var beforeMinutes: Int {
        get {
            let value = defaults.object(forKey: Key.beforeMinutes) as? Int
            return value ?? Self.defaultBeforeMinutes
        }
        set { defaults.set(newValue, forKey: Key.beforeMinutes); changed() }
    }

    /// Events the operator does not want to hear about.
    var mutedKinds: Set<ACEventKind> {
        get {
            let raw = defaults.stringArray(forKey: Key.mutedKinds) ?? []
            return Set(raw.compactMap { ACEventKind(rawValue: $0) })
        }
        set {
            defaults.set(newValue.map { $0.rawValue }.sorted(), forKey: Key.mutedKinds)
            changed()
        }
    }

    func isMuted(_ kind: ACEventKind) -> Bool {
        mutedKinds.contains(kind)
    }

    func setMuted(_ kind: ACEventKind, _ muted: Bool) {
        var kinds = mutedKinds
        if muted { kinds.insert(kind) } else { kinds.remove(kind) }
        mutedKinds = kinds
    }

    // MARK: Labels

    /// "8:00" for a lead time.
    static func leadText(_ minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    /// "15 minutes before", "1 hour before" or "Off".
    static func beforeText(_ minutes: Int) -> String {
        switch minutes {
        case 0: return "Off"
        case 60: return "1 hour before"
        default: return "\(minutes) minutes before"
        }
    }

    private func changed() {
        let post = { NotificationCenter.default.post(name: Self.didChange, object: nil) }
        if Thread.isMainThread { post() } else { DispatchQueue.main.async(execute: post) }
    }
}
