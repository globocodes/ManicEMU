//
//  ACSaveReader.swift
//  ManicEmu
//
//  Reads the Animal Crossing (GAFE01) town save off the memory card the
//  libretro Dolphin core keeps under Documents/dolphin-emu/User/GC, for the
//  dates only the save knows: Town Day, the player's birthday, and the
//  visitors the game rolled on its last day load (Redd, Gracie, Saharah,
//  Katrina, Wendell, Nook's sale, Gulliver's weekday).
//
//  Layout, from the game's own sources (ac-decomp 09ca8e8b):
//    m_card.c      the town file "DobutsunomoriP_MURA", 57 blocks (0x72000):
//                  three 0x26000 regions, MISC / MAIN / MAIN_BAK; MAIN and
//                  MAIN_BAK each hold one Save (Save_t padded to a sector);
//                  a copy is good when the flat u16 sum over the whole
//                  region is 0 (mFRm_ReturnCheckSum) and its code is "GAFE".
//    m_common_data.h  Save_t: save_check +0, private_data[4] +0x20 (each
//                  0x2440, birthday at +0x10A4), land_info +0x9120,
//                  event_save_common +0x20554, event_year +0x21398,
//                  town_day +0x2418A.
//    m_event.h/.c  event_save_common: special_event {type, flags},
//                  weekly_event {type, flags}, dates[8] (u16 month << 8 |
//                  day): TODAY, LAST_PLAY, BIRTHDAY, SPECIAL0 (the day the
//                  visitor was rolled), SPECIAL1 (first day), SPECIAL2 (last
//                  day), WEEKLY (Joan's Sunday, K.K.'s Saturday or
//                  Gulliver's weekday), SPECIAL3 (the start hour, 6 unless
//                  the roll chose otherwise). init_special_event rolls one
//                  of SHOP_SALE / DESIGNER / BROKER_SALE / ARTIST /
//                  CARPET_PEDDLER / GYPSY; m_event_schedule.c_inc gives
//                  each its hours.
//
//  Confirmed on the operator's iPad 2026-10-17: the core writes a GCI folder,
//  `USA/Card A/01-GAFE-DobutsunomoriP_MURA.gci` (0x40 header + 0x72000),
//  both copies valid, and the file on disk carried the roll made during the
//  session that had just ended.
//
//  Pure Foundation on purpose, like ACEventCalendar: it runs off the device.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// MARK: - A month and day as the save stores them

/// `mEv_MonthDay`: month << 8 | day.
struct ACMonthDay: Equatable, Hashable, Comparable {
    let month: Int
    let day: Int

    init(month: Int, day: Int) {
        self.month = month
        self.day = day
    }

    /// Nil for the empty slots (0 or 0xFFFF) and anything not a date.
    init?(raw: UInt16) {
        let month = Int(raw >> 8)
        let day = Int(raw & 0xFF)
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        self.init(month: month, day: day)
    }

    var raw: UInt16 { UInt16(month << 8 | day) }

    static func < (a: ACMonthDay, b: ACMonthDay) -> Bool { a.raw < b.raw }
}

// MARK: - What the town save says

/// The parts of one town save the notifications need.
struct ACTownSave: Equatable {
    /// One rolled visitor, as `event_save_common` holds it.
    struct SpecialVisit: Equatable {
        let kind: ACEventKind
        /// The game's event type (`mEv_EVENT_*`), kept for the log.
        let eventType: Int
        /// The day the game rolled it (`SPECIAL0`); the year is `eventYear`.
        let rolledOn: ACMonthDay
        /// First day (`SPECIAL1`) and last day (`SPECIAL2`).
        let start: ACMonthDay
        let end: ACMonthDay
        /// Hour the visitor arrives on the first day (`SPECIAL3`).
        let startHour: Int
        /// Last hour on the last day, inclusive (the game's end time).
        let endHour: Int
    }

    /// The weekly slot: Joan's Sunday, K.K.'s Saturday or Gulliver's weekday.
    struct WeeklyVisit: Equatable {
        let eventType: Int
        let date: ACMonthDay
        var isGulliver: Bool { eventType == ACSaveReader.EventType.dozaemon }
    }

    let townName: String
    let townID: UInt16
    /// The game clock when this copy was written (`save_check.time`).
    let savedAt: DateComponents
    /// The year the special visitor was rolled in (`event_year`).
    let eventYear: Int
    /// The day the game calls today in `dates[TODAY]`.
    let today: ACMonthDay?
    /// Town Day's day of July, or nil when unset.
    let townDay: Int?
    /// The first player's birthday.
    let birthday: ACMonthDay?
    let special: SpecialVisit?
    let weekly: WeeklyVisit?

    /// Which copy of the town file this came from (0 main, 1 backup).
    let copyIndex: Int

    /// The save-driven dates in the form the calendar takes.
    func calendarInfo(calendar: Calendar) -> ACSaveCalendarInfo {
        ACSaveCalendarInfo(townDay: townDay,
                           birthdayMonth: birthday?.month,
                           birthdayDay: birthday?.day,
                           visits: visits(calendar: calendar))
    }

    /// The visitors as dated visits. A visit whose days cannot be placed
    /// on the calendar (a February 30 from a corrupt slot) is dropped.
    func visits(calendar: Calendar) -> [ACVisit] {
        var result: [ACVisit] = []
        if let special {
            // The roll day is in eventYear; the first day is after it, so a
            // wrap past New Year moves the year on, and so does an end day
            // before the start day.
            let startYear = eventYear + (special.start < special.rolledOn ? 1 : 0)
            let endYear = startYear + (special.end < special.start ? 1 : 0)
            if let startDay = Self.date(year: startYear, special.start, calendar: calendar),
               let endDay = Self.date(year: endYear, special.end, calendar: calendar),
               let span = calendar.dateComponents([.day], from: startDay, to: endDay).day, span >= 0 {
                result.append(ACVisit(kind: special.kind,
                                      day: startDay,
                                      startHour: special.startHour,
                                      endHour: special.endHour + 24 * span))
            }
        }
        if let weekly, weekly.isGulliver, let year = Self.weeklyYear(weekly.date, savedAt: savedAt, today: today),
           let day = Self.date(year: year, weekly.date, calendar: calendar) {
            result.append(ACVisit(kind: .gulliver, day: day,
                                  startHour: ACSaveReader.Hours.gulliver.start,
                                  endHour: ACSaveReader.Hours.gulliver.end))
        }
        return result
    }

    /// Gulliver's date is within the week of the save; a January date on
    /// a December save is next year's.
    static func weeklyYear(_ date: ACMonthDay, savedAt: DateComponents, today: ACMonthDay?) -> Int? {
        guard let year = savedAt.year else { return nil }
        let reference = today ?? ACMonthDay(month: savedAt.month ?? 1, day: savedAt.day ?? 1)
        if reference.month == 12, date.month == 1 { return year + 1 }
        if reference.month == 1, date.month == 12 { return year - 1 }
        return year
    }

    static func date(year: Int, _ monthDay: ACMonthDay, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = monthDay.month
        components.day = monthDay.day
        guard let date = calendar.date(from: components) else { return nil }
        // Reject a roll-over (Feb 30 -> Mar 2).
        let check = calendar.dateComponents([.month, .day], from: date)
        guard check.month == monthDay.month, check.day == monthDay.day else { return nil }
        return calendar.startOfDay(for: date)
    }
}

/// One dated visit, ready for the calendar: `endHour` counts on from
/// `startHour` past midnight (17 on the next day is 41).
struct ACVisit: Equatable {
    let kind: ACEventKind
    /// Start of the first day, in the calendar the save was resolved with.
    let day: Date
    let startHour: Int
    let endHour: Int
}

// MARK: - Reader

enum ACSaveReader {
    enum ReadError: Error, Equatable, CustomStringConvertible {
        case noCard
        case notTheTownFile
        case wrongSize(Int)
        case noValidCopy
        case brokenCardImage(String)

        var description: String {
            switch self {
            case .noCard: return "No GameCube memory card with an Animal Crossing town was found."
            case .notTheTownFile: return "The file is not an Animal Crossing town."
            case .wrongSize(let size): return "The town file is \(size) bytes, not \(ACSaveReader.townFileSize)."
            case .noValidCopy: return "Neither copy of the town passed its checksum."
            case .brokenCardImage(let why): return "The memory card image could not be read: \(why)"
            }
        }
    }

    /// Where the town file was found.
    enum CardLocation: Equatable {
        /// Dolphin's GCI folder: one file per save, a 0x40 directory entry
        /// in front of the blocks. What the device uses.
        case gci(URL)
        /// A raw card image (MemoryCardA.USA.raw): header, directory, block
        /// map, blocks.
        case raw(URL)

        var url: URL {
            switch self {
            case .gci(let url), .raw(let url): return url
            }
        }
    }

    static let gameCode = "GAFE"
    static let townFileName = "DobutsunomoriP_MURA"
    static let townFileSize = 0x72000
    static let gciHeaderSize = 0x40
    static let saveSize = 0x26000
    static let copyOffsets = [0x26000, 0x4C000]
    static let blockSize = 0x2000

    enum Offset {
        static let saveCheckCode = 0x04
        static let saveCheckTime = 0x0A
        static let privateData = 0x20
        static let privateSize = 0x2440
        static let privateBirthday = 0x10A4
        static let landInfo = 0x9120
        static let eventSaveCommon = 0x20554
        static let eventYear = 0x21398
        static let townDay = 0x2418A
    }

    /// `mEv_EVENT_*` (enum event_table, 0-based).
    enum EventType {
        static let dozaemon = 68
        static let kabuPeddler = 69
        static let kkSlider = 71
        static let artist = 74
        static let brokerSale = 75
        static let designer = 76
        static let gypsy = 77
        static let shopSale = 78
        static let carpetPeddler = 79

        /// The special-event types the game rolls, by its names: the
        /// "broker" with the tent of goods is Redd (he is also the one
        /// ruled out on the Fireworks Festival), the "artist" with the
        /// wallpapers is Wendell.
        static func visitorKind(_ type: Int) -> ACEventKind? {
            switch type {
            case brokerSale: return .redd
            case artist: return .wendell
            case designer: return .gracie
            case carpetPeddler: return .saharah
            case gypsy: return .katrina
            case shopSale: return .nookSale
            default: return nil
            }
        }
    }

    /// Hours from m_event_schedule.c_inc: the start hour on the first day
    /// comes from the save (SPECIAL3); the last hour on the last day is
    /// fixed per visitor (get_special_event_end_time). A visitor whose
    /// range is one day (the sale) ends the same day.
    enum Hours {
        static func endHour(for kind: ACEventKind) -> Int {
            switch kind {
            case .redd: return 17        // 18:00 until 18:00 the next day
            case .wendell, .gracie, .saharah: return 5   // 6:00 until 6:00 the next day
            case .katrina: return 20     // 21:00 until 21:00 the next day
            case .nookSale: return 23    // from the rolled hour until the shop closes
            default: return 23
            }
        }
        static let gulliver = (start: 6, end: 22)
    }

    // MARK: Finding the card

    /// Looks under Dolphin's `User/GC` for the town: the GCI folder of the
    /// region first (`<region>/Card A/`, then `Card B`), then the raw
    /// images `MemoryCardA.<region>.raw` / `MemoryCardB.<region>.raw`.
    static func locateTownFile(gcUser: URL, region: String = "USA", fileManager: FileManager = .default) -> CardLocation? {
        for slot in ["Card A", "Card B"] {
            let folder = gcUser.appendingPathComponent(region).appendingPathComponent(slot)
            if let names = try? fileManager.contentsOfDirectory(atPath: folder.path) {
                let candidates = names.filter { $0.hasSuffix(".gci") && $0.contains(townFileName) }.sorted()
                for name in candidates {
                    let url = folder.appendingPathComponent(name)
                    if let header = readPrefix(url, count: gciHeaderSize), isTownEntry(header) {
                        return .gci(url)
                    }
                }
            }
        }
        for slot in ["A", "B"] {
            let url = gcUser.appendingPathComponent("MemoryCard\(slot).\(region).raw")
            if fileManager.fileExists(atPath: url.path) {
                return .raw(url)
            }
        }
        return nil
    }

    private static func readPrefix(_ url: URL, count: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        return try? handle.read(upToCount: count)
    }

    /// A directory entry (the GCI header) for the town file.
    static func isTownEntry(_ entry: Data) -> Bool {
        guard entry.count >= gciHeaderSize else { return false }
        let code = String(decoding: entry[entry.startIndex ..< entry.startIndex + 4], as: UTF8.self)
        let nameBytes = entry[entry.startIndex + 8 ..< entry.startIndex + 0x28]
        let name = String(decoding: nameBytes.prefix { $0 != 0 }, as: UTF8.self)
        return code == gameCode && name == townFileName
    }

    // MARK: Reading

    static func readTownSave(gcUser: URL, region: String = "USA") throws -> ACTownSave {
        guard let location = locateTownFile(gcUser: gcUser, region: region) else { throw ReadError.noCard }
        return try readTownSave(at: location)
    }

    static func readTownSave(at location: CardLocation) throws -> ACTownSave {
        let data = try Data(contentsOf: location.url, options: .mappedIfSafe)
        let townFile: Data
        switch location {
        case .gci: townFile = try townFileData(gci: data)
        case .raw: townFile = try townFileData(rawCard: data)
        }
        return try parse(townFile: townFile)
    }

    /// The town file's blocks from a GCI file.
    static func townFileData(gci: Data) throws -> Data {
        guard gci.count >= gciHeaderSize, isTownEntry(gci.prefix(gciHeaderSize)) else { throw ReadError.notTheTownFile }
        let body = gci.dropFirst(gciHeaderSize)
        guard body.count == townFileSize else { throw ReadError.wrongSize(body.count) }
        return Data(body)
    }

    /// The town file's blocks from a raw card image: finds its directory
    /// entry (either directory block) and follows the block map chain.
    static func townFileData(rawCard card: Data) throws -> Data {
        guard card.count >= 5 * blockSize else { throw ReadError.brokenCardImage("shorter than its system blocks") }
        var entry: Data?
        for directoryBlock in [1, 2] {
            let base = directoryBlock * blockSize
            for slot in 0 ..< 127 {
                let start = base + slot * 0x40
                let candidate = card[start ..< start + 0x40]
                if isTownEntry(candidate) {
                    entry = Data(candidate)
                    break
                }
            }
            if entry != nil { break }
        }
        guard let entry else { throw ReadError.noCard }
        let firstBlock = Int(be16(entry, 0x36))
        let blockCount = Int(be16(entry, 0x38))
        guard blockCount * blockSize == townFileSize else { throw ReadError.wrongSize(blockCount * blockSize) }

        // Two block-allocation tables; the one with the higher update
        // counter is current. Take whichever gives a whole chain.
        let batBlocks = [3, 4].sorted { be16(card, $0 * blockSize + 4) > be16(card, $1 * blockSize + 4) }
        var lastFailure = "no block map"
        for bat in batBlocks {
            var chain: [Int] = []
            var block = firstBlock
            var ok = true
            while chain.count < blockCount {
                guard block >= 5, (block + 1) * blockSize <= card.count else { ok = false; lastFailure = "block \(block) is outside the card"; break }
                chain.append(block)
                if chain.count == blockCount { break }
                let next = Int(be16(card, bat * blockSize + 0x0A + (block - 5) * 2))
                guard next != 0xFFFF, next != 0 else { ok = false; lastFailure = "the chain ends after \(chain.count) blocks"; break }
                block = next
            }
            if ok {
                var out = Data(capacity: townFileSize)
                for b in chain { out.append(card[b * blockSize ..< (b + 1) * blockSize]) }
                return out
            }
        }
        throw ReadError.brokenCardImage(lastFailure)
    }

    /// Picks the good copy: main first, then the backup; when both pass,
    /// the one saved later.
    static func parse(townFile: Data) throws -> ACTownSave {
        guard townFile.count == townFileSize else { throw ReadError.wrongSize(townFile.count) }
        var copies: [ACTownSave] = []
        for (index, offset) in copyOffsets.enumerated() {
            let copy = townFile[townFile.startIndex + offset ..< townFile.startIndex + offset + saveSize]
            if let save = parse(save: Data(copy), copyIndex: index) {
                copies.append(save)
            }
        }
        guard let best = copies.max(by: { savedOrder($0.savedAt) < savedOrder($1.savedAt) }) else { throw ReadError.noValidCopy }
        return best
    }

    private static func savedOrder(_ c: DateComponents) -> Int {
        ((((c.year ?? 0) * 13 + (c.month ?? 0)) * 32 + (c.day ?? 0)) * 24 + (c.hour ?? 0)) * 60 + (c.minute ?? 0)
    }

    /// One 0x26000 copy. Nil when its checksum or code is wrong.
    static func parse(save: Data, copyIndex: Int = 0) -> ACTownSave? {
        guard save.count == saveSize, flatSum(save) == 0, be32(save, Offset.saveCheckCode) == 0x47414645 else { return nil }
        let t = Offset.saveCheckTime
        var savedAt = DateComponents()
        savedAt.second = Int(save[save.startIndex + t])
        savedAt.minute = Int(save[save.startIndex + t + 1])
        savedAt.hour = Int(save[save.startIndex + t + 2])
        savedAt.day = Int(save[save.startIndex + t + 3])
        savedAt.month = Int(save[save.startIndex + t + 5])
        savedAt.year = Int(be16(save, t + 6))

        let nameBytes = save[save.startIndex + Offset.landInfo ..< save.startIndex + Offset.landInfo + 8]
        let townName = decodeName(nameBytes)
        let townID = be16(save, Offset.landInfo + 0x0A)

        let birthdayOffset = Offset.privateData + Offset.privateBirthday
        let birthday = ACMonthDay(raw: UInt16(save[save.startIndex + birthdayOffset + 2]) << 8 | UInt16(save[save.startIndex + birthdayOffset + 3]))

        let ev = Offset.eventSaveCommon
        let specialType = Int(save[save.startIndex + ev])
        let weeklyType = Int(save[save.startIndex + ev + 2])
        var dates: [UInt16] = []
        for i in 0 ..< 8 { dates.append(be16(save, ev + 4 + i * 2)) }
        let eventYear = Int(Int16(bitPattern: be16(save, Offset.eventYear)))
        let townDayRaw = Int(save[save.startIndex + Offset.townDay])
        let townDay = (1...31).contains(townDayRaw) ? townDayRaw : nil

        var special: ACTownSave.SpecialVisit? = nil
        if let kind = EventType.visitorKind(specialType),
           let rolledOn = ACMonthDay(raw: dates[3]),
           let start = ACMonthDay(raw: dates[4]),
           let end = ACMonthDay(raw: dates[5]) {
            let startHour = Int(dates[7] & 0xFF)
            special = ACTownSave.SpecialVisit(kind: kind,
                                              eventType: specialType,
                                              rolledOn: rolledOn,
                                              start: start,
                                              end: end,
                                              startHour: (0...23).contains(startHour) ? startHour : 6,
                                              endHour: Hours.endHour(for: kind))
        }
        var weekly: ACTownSave.WeeklyVisit? = nil
        if let date = ACMonthDay(raw: dates[6]) {
            weekly = ACTownSave.WeeklyVisit(eventType: weeklyType, date: date)
        }

        return ACTownSave(townName: townName,
                          townID: townID,
                          savedAt: savedAt,
                          eventYear: eventYear,
                          today: ACMonthDay(raw: dates[0]),
                          townDay: townDay,
                          birthday: birthday,
                          special: special,
                          weekly: weekly,
                          copyIndex: copyIndex)
    }

    /// The game's font uses ASCII codes for letters, digits and the space;
    /// anything else (its own symbols) shows as "?".
    static func decodeName(_ bytes: Data) -> String {
        var out = ""
        for b in bytes {
            switch b {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x20: out.append(Character(UnicodeScalar(b)))
            default: out.append("?")
            }
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    /// `mFRm_ReturnCheckSum`: the u16 big-endian sum over the copy, 0 when good.
    static func flatSum(_ data: Data) -> UInt16 {
        var sum: UInt16 = 0
        data.withUnsafeBytes { raw in
            let n = raw.count / 2
            for i in 0 ..< n {
                sum &+= UInt16(raw[2 * i]) << 8 | UInt16(raw[2 * i + 1])
            }
        }
        return sum
    }

    static func be16(_ data: Data, _ offset: Int) -> UInt16 {
        let i = data.startIndex + offset
        return UInt16(data[i]) << 8 | UInt16(data[i + 1])
    }

    static func be32(_ data: Data, _ offset: Int) -> UInt32 {
        let i = data.startIndex + offset
        return UInt32(data[i]) << 24 | UInt32(data[i + 1]) << 16 | UInt32(data[i + 2]) << 8 | UInt32(data[i + 3])
    }

    // MARK: Wording

    /// "Town Senada, saved Oct 17 at 21:29: Crazy Redd on Tue, Oct 20, 18:00 until 18:00 the next day."
    static func summary(of save: ACTownSave, calendar: Calendar = .current) -> String {
        var text = "Town \(save.townName.isEmpty ? "(unnamed)" : save.townName)"
        var saved = save.savedAt
        saved.calendar = calendar
        if let date = saved.date {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.setLocalizedDateFormatFromTemplate("MMMd HH:mm")
            text += ", saved \(formatter.string(from: date))"
        }
        let visits = save.visits(calendar: calendar)
        if visits.isEmpty {
            text += ": no visitor is rolled yet."
            return text
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEMMMd")
        let parts = visits.map { visit -> String in
            let occurrence = ACEventOccurrence(kind: visit.kind, day: visit.day, startHour: visit.startHour, endHour: visit.endHour, isSeasonStart: false, seasonEnd: nil)
            let hours = occurrence.hoursText.map { ", \($0)" } ?? ""
            return "\(visit.kind.displayName) on \(formatter.string(from: visit.day))\(hours)"
        }
        return text + ": " + parts.joined(separator: "; ") + "."
    }
}
