//
//  ACNotificationScheduler.swift
//  ManicEmu
//
//  Local notifications ahead of Animal Crossing (GAFE01) events, so the
//  operator hears about them with the game closed. Local only: nothing is
//  pushed. A rolling 30-day window is kept under 60 pending requests and is
//  rebuilt on launch, on every return to the foreground, at the end of a
//  play session and from a background app refresh.
//
//  The fixed calendar comes from ACEventCalendar. The save-driven dates
//  (Town Day, the birthday, the rolled visitors) arrive through
//  `saveInfo`, which ACSaveReader fills once it exists.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import UIKit
import UserNotifications
import BackgroundTasks
import RealmSwift

final class ACNotificationScheduler: NSObject {
    static let shared = ACNotificationScheduler()

    /// The only game this is about.
    static let gameID = "GAFE01"
    /// Declared in Info.plist under BGTaskSchedulerPermittedIdentifiers.
    static let refreshTaskIdentifier = "com.globocodes.manicemu.ac-events.refresh"
    /// Every request this scheduler owns starts with this; nothing else is touched.
    static let identifierPrefix = "ac-event."
    static let testIdentifier = "ac-event.test"
    static let windowDays = 30
    /// iOS keeps 64 pending requests per app; the rest is headroom.
    static let pendingLimit = 58
    static let threadIdentifier = "ac-events"

    private let center = UNUserNotificationCenter.current()

    /// True once the database can be read on the main thread.
    private var databaseReady = false

    /// Dates only the save knows. Nil until ACSaveReader (BP-AC-I33)
    /// supplies them; the fixed calendar works without them.
    var saveInfo: ACSaveCalendarInfo? = nil

    // MARK: - App hooks

    /// From application(_:didFinishLaunchingWithOptions:). The background
    /// task must be registered before the app finishes launching.
    func applicationDidLaunch() {
        center.delegate = self
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskIdentifier, using: nil) { [weak self] task in
            self?.handleBackgroundRefresh(task)
        }
    }

    /// From the scene, once Database.setup has completed.
    func databaseDidBecomeReady() {
        databaseReady = true
        rebuildIfEnabled(reason: "launch")
    }

    /// From the scene on every return to the foreground.
    func rebuildIfEnabled(reason: String) {
        guard databaseReady, ACEventSettings.shared.isEnabled else { return }
        rebuild(reason: reason)
    }

    /// From the play view as it goes away. The core has flushed the memory
    /// card by then (or is about to), which is what the save-driven read
    /// will depend on; the fixed calendar only needs the clock.
    func playSessionEnded(game: Game) {
        guard game.gameIDForDolphin == Self.gameID, ACEventSettings.shared.isEnabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.rebuild(reason: "session end")
        }
    }

    // MARK: - Library

    /// The GAFE01 entry in the library, if there is one. Reads Realm on the
    /// calling thread.
    static func libraryGame() -> Game? {
        let games = Database.realm.objects(Game.self).where({ !$0.isDeleted && $0.gameType == GameType.ngc })
        return games.first(where: { $0.ensureDolphinGameID() == gameID })
    }

    static var isGameInLibrary: Bool { libraryGame() != nil }

    // MARK: - Permission

    enum PermissionResult {
        case granted
        case denied
        case failed(Error)

        var isGranted: Bool {
            if case .granted = self { return true }
            return false
        }
    }

    /// Asks on first use; afterwards reports what iOS Settings says. The
    /// completion runs on the main thread.
    func requestPermission(completion: @escaping (PermissionResult) -> Void) {
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    DispatchQueue.main.async {
                        if let error { completion(.failed(error)) } else { completion(granted ? .granted : .denied) }
                    }
                }
            case .denied:
                DispatchQueue.main.async { completion(.denied) }
            default:
                DispatchQueue.main.async { completion(.granted) }
            }
        }
    }

    // MARK: - On / off

    /// Turning the feature on asks for permission first; it only stays on
    /// when iOS granted it. Completion on the main thread.
    func setEnabled(_ enabled: Bool, completion: @escaping (PermissionResult?) -> Void) {
        guard enabled else {
            ACEventSettings.shared.isEnabled = false
            removeScheduled()
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshTaskIdentifier)
            completion(nil)
            return
        }
        requestPermission { result in
            if result.isGranted {
                ACEventSettings.shared.isEnabled = true
                self.rebuild(reason: "enabled")
            } else {
                ACEventSettings.shared.isEnabled = false
            }
            completion(result)
        }
    }

    // MARK: - Rebuild

    /// Replaces every pending request of ours with the next 30 days.
    func rebuild(reason: String, completion: (() -> Void)? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.rebuild(reason: reason, completion: completion) }
            return
        }
        let settings = ACEventSettings.shared
        guard settings.isEnabled, Self.isGameInLibrary else {
            Log.debug("[ACEvents] not scheduling (\(reason)): enabled=\(settings.isEnabled)")
            removeScheduled()
            completion?()
            return
        }
        let planned = Self.plan(now: Date(),
                                leadMinutes: settings.leadMinutes,
                                beforeMinutes: settings.beforeMinutes,
                                muted: settings.mutedKinds,
                                save: saveInfo)
        center.getPendingNotificationRequests { pending in
            let ours = pending.map { $0.identifier }.filter { $0.hasPrefix(Self.identifierPrefix) && $0 != Self.testIdentifier }
            self.center.removePendingNotificationRequests(withIdentifiers: ours)
            for item in planned {
                self.center.add(item.request) { error in
                    if let error { Log.error("[ACEvents] add \(item.identifier): \(error)") }
                }
            }
            Log.debug("[ACEvents] rebuilt (\(reason)): \(planned.count) scheduled, \(ours.count) replaced")
            DispatchQueue.main.async { completion?() }
        }
        scheduleBackgroundRefresh()
    }

    /// Removes our pending requests (the feature went off, or GAFE01 left the library).
    func removeScheduled() {
        center.getPendingNotificationRequests { pending in
            let ours = pending.map { $0.identifier }.filter { $0.hasPrefix(Self.identifierPrefix) }
            if !ours.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: ours)
            }
        }
    }

    // MARK: - Planning

    struct PlannedNotification: Equatable {
        let identifier: String
        let fireDate: Date
        let title: String
        let body: String

        var request: UNNotificationRequest {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.threadIdentifier = ACNotificationScheduler.threadIdentifier
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        }
    }

    /// The notifications for the window after `now`, in firing order, at
    /// most `pendingLimit` of them. Each event day gets a day-of reminder
    /// at the lead time while the event is still ahead or on, and a timed
    /// event gets a second one `beforeMinutes` before it starts. An event
    /// that is over before the lead time (Morning Aerobics at 6:00 against
    /// an 8:00 lead) gets its day-of reminder at its start instead, unless
    /// the before-reminder already covers it.
    static func plan(now: Date,
                     leadMinutes: Int,
                     beforeMinutes: Int,
                     muted: Set<ACEventKind>,
                     save: ACSaveCalendarInfo?,
                     calendar: Calendar = .current) -> [PlannedNotification] {
        guard let windowEnd = calendar.date(byAdding: .day, value: windowDays, to: now) else { return [] }
        let occurrences = ACEventCalendar.events(in: DateInterval(start: now, end: windowEnd), save: save, calendar: calendar)
            .filter { !muted.contains($0.kind) }

        var planned: [PlannedNotification] = []
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar
        dayFormatter.dateFormat = "yyyyMMdd"

        for occurrence in occurrences {
            guard let start = occurrence.startDate(calendar: calendar),
                  let end = occurrence.endDate(calendar: calendar),
                  let leadDate = calendar.date(byAdding: .minute, value: leadMinutes, to: occurrence.day) else { continue }
            let key = "\(identifierPrefix)\(occurrence.kind.rawValue).\(dayFormatter.string(from: occurrence.day))"
            let name = occurrence.kind.displayName
            let body = dayBody(for: occurrence, calendar: calendar)

            let beforeIsOn = beforeMinutes > 0 && !occurrence.isAllDay
            if leadDate > now, leadDate < end {
                planned.append(PlannedNotification(identifier: key + ".day", fireDate: leadDate, title: name, body: body))
            } else if leadDate >= end, !beforeIsOn, start > now {
                planned.append(PlannedNotification(identifier: key + ".start", fireDate: start, title: name, body: body))
            }

            if beforeIsOn,
               let beforeDate = calendar.date(byAdding: .minute, value: -beforeMinutes, to: start),
               beforeDate > now {
                planned.append(PlannedNotification(identifier: key + ".before",
                                                   fireDate: beforeDate,
                                                   title: "\(name) starts in \(ACEventSettings.beforeText(beforeMinutes).replacingOccurrences(of: " before", with: ""))",
                                                   body: occurrence.hoursText.map { "Today \($0)" } ?? "Today"))
            }
        }
        planned.sort { $0.fireDate < $1.fireDate }
        return Array(planned.prefix(pendingLimit))
    }

    /// "Today 6:00–12:00", "Today, all day", "Starts today, through Oct 25".
    static func dayBody(for occurrence: ACEventOccurrence, calendar: Calendar) -> String {
        if occurrence.isSeasonStart, let seasonEnd = occurrence.seasonEnd,
           let span = calendar.dateComponents([.day], from: occurrence.day, to: seasonEnd).day, span > 1 {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.setLocalizedDateFormatFromTemplate("MMMd")
            let through = formatter.string(from: seasonEnd)
            if let hours = occurrence.hoursText {
                return "Starts today \(hours), through \(through)"
            }
            return "Starts today, through \(through)"
        }
        if let hours = occurrence.hoursText {
            return "Today \(hours)"
        }
        return "Today, all day"
    }

    // MARK: - Test notification

    /// A notification a few seconds out that names the next fixed event, so
    /// the operator can see one arrive and know what is coming. Asks for
    /// permission first when it has not been asked yet.
    func sendTestNotification(completion: @escaping (PermissionResult) -> Void) {
        requestPermission { result in
            guard result.isGranted else {
                completion(result)
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Animal Crossing event notifications are on"
            content.body = Self.nextEventText(after: Date(), save: self.saveInfo)
            content.sound = .default
            content.threadIdentifier = Self.threadIdentifier
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let request = UNNotificationRequest(identifier: Self.testIdentifier, content: content, trigger: trigger)
            self.center.add(request) { error in
                DispatchQueue.main.async {
                    if let error { completion(.failed(error)) } else { completion(.granted) }
                }
            }
        }
    }

    /// "Next up: Fishing Tourney on Sun, Nov 1, 6:00–18:00".
    static func nextEventText(after date: Date, save: ACSaveCalendarInfo?, calendar: Calendar = .current) -> String {
        let muted = ACEventSettings.shared.mutedKinds
        guard let next = ACEventCalendar.nextEvent(after: date, excluding: muted, save: save, calendar: calendar) else {
            return "No fixed event found in the next year."
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("EEEMMMd")
        let day = formatter.string(from: next.day)
        if let hours = next.hoursText {
            return "Next up: \(next.kind.displayName) on \(day), \(hours)"
        }
        return "Next up: \(next.kind.displayName) on \(day)"
    }

    // MARK: - Background refresh

    /// Asks iOS for a refresh no sooner than twelve hours out; iOS picks the
    /// moment. A refusal (the simulator, Low Power Mode) only means the
    /// window is rebuilt on the next launch or foreground instead.
    func scheduleBackgroundRefresh() {
        guard ACEventSettings.shared.isEnabled else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Log.debug("[ACEvents] background refresh not scheduled: \(error)")
        }
    }

    private func handleBackgroundRefresh(_ task: BGTask) {
        scheduleBackgroundRefresh()
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        rebuild(reason: "background refresh") {
            task.setTaskCompleted(success: true)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension ACNotificationScheduler: UNUserNotificationCenterDelegate {
    /// Our notifications show even while Manic is in front; anything else
    /// keeps the system default.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if notification.request.identifier.hasPrefix(Self.identifierPrefix) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([])
        }
    }

    /// Tapping one opens Manic; nothing more is needed.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
