//
//  ACEventCalendar.swift
//  ManicEmu
//
//  Animal Crossing (GAFE01) fixed event calendar, transcribed from the game's
//  own schedule table (`event_schedule_data[]` in m_event_schedule.c_inc) and
//  the rules its resolver applies (m_event.c: decode_date, m_weekday2day,
//  add_event_today, update_sports_fair; lb_reki.c: the equinox formulas and
//  the Harvest Moon table). Only the entries the player can see are kept:
//  the rumour, mayor, weather, talk-topic and eligibility rows (Blanca, Wisp,
//  the bridge) are not events anyone needs a notification for, and the
//  randomly rolled visitors (Redd, Gracie, Saharah, Katrina, Wendell, the
//  sales, Gulliver) live in the save and are read by ACSaveReader instead.
//
//  Pure Foundation on purpose: this file has no UIKit or Realm dependency so
//  it can be checked and exercised off the device.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// MARK: - Event kinds

/// One kind of fixed event. The raw value is the stable id the settings use
/// for per-event mutes, so it is never renamed.
enum ACEventKind: String, CaseIterable, Codable {
    case joan
    case kkSlider
    case raffle
    case newYearsDay
    case iglooSeason
    case groundhogDay
    case valentinesDay
    case springSportsFair
    case aprilFoolsDay
    case cherryBlossomFestival
    case cherryBlossomPetals
    case natureDay
    case springCleaning
    case mothersDay
    case camper
    case graduationDay
    case fathersDay
    case fishingTourneyJune
    case fireworks
    case townDay
    case morningAerobics
    case meteorShower
    case foundersDay
    case laborDay
    case fallSportsFair
    case harvestMoon
    case explorersDay
    case mushroomSeason
    case halloween
    case mayorsDay
    case officersDay
    case fishingTourneyNovember
    case harvestFestival
    case saleDay
    case snowDay
    case toyDay
    case jingle
    case newYearsEve
    case snowmanSeason
    case playerBirthday
    // Rolled into the save by the game (ACSaveReader): the special
    // visitors and Gulliver's weekday.
    case redd
    case wendell
    case gracie
    case saharah
    case katrina
    case nookSale
    case gulliver

    /// The name the notification carries.
    var displayName: String {
        switch self {
        case .joan: return "Joan's turnips"
        case .kkSlider: return "K.K. Slider"
        case .raffle: return "Nook's raffle"
        case .newYearsDay: return "New Year's Day"
        case .iglooSeason: return "Igloo season"
        case .groundhogDay: return "Groundhog Day"
        case .valentinesDay: return "Valentine's Day"
        case .springSportsFair: return "Spring Sports Fair"
        case .aprilFoolsDay: return "April Fools' Day"
        case .cherryBlossomFestival: return "Cherry Blossom Festival"
        case .cherryBlossomPetals: return "Cherry blossom petals"
        case .natureDay: return "Nature Day"
        case .springCleaning: return "Spring Cleaning Day"
        case .mothersDay: return "Mother's Day"
        case .camper: return "Camper at the campsite"
        case .graduationDay: return "Graduation Day"
        case .fathersDay: return "Father's Day"
        case .fishingTourneyJune: return "Fishing Tourney"
        case .fireworks: return "Fireworks Show"
        case .townDay: return "Town Day"
        case .morningAerobics: return "Morning Aerobics"
        case .meteorShower: return "Meteor Shower"
        case .foundersDay: return "Founder's Day"
        case .laborDay: return "Labor Day"
        case .fallSportsFair: return "Fall Sports Fair"
        case .harvestMoon: return "Harvest Moon"
        case .explorersDay: return "Explorer's Day"
        case .mushroomSeason: return "Mushroom season"
        case .halloween: return "Halloween"
        case .mayorsDay: return "Mayor's Day"
        case .officersDay: return "Officer's Day"
        case .fishingTourneyNovember: return "Fishing Tourney"
        case .harvestFestival: return "Harvest Festival"
        case .saleDay: return "Sale Day"
        case .snowDay: return "Snow Day"
        case .toyDay: return "Toy Day"
        case .jingle: return "Jingle's visit"
        case .newYearsEve: return "New Year's Eve countdown"
        case .snowmanSeason: return "Snowman season"
        case .playerBirthday: return "Your birthday"
        case .redd: return "Crazy Redd"
        case .wendell: return "Wendell"
        case .gracie: return "Gracie"
        case .saharah: return "Saharah"
        case .katrina: return "Katrina"
        case .nookSale: return "Nook's sale"
        case .gulliver: return "Gulliver"
        }
    }

    /// The label the settings sheet shows (kinds that share a display name
    /// get their month so the mutes stay distinguishable).
    var settingsName: String {
        switch self {
        case .fishingTourneyJune: return "Fishing Tourney (June Sundays)"
        case .fishingTourneyNovember: return "Fishing Tourney (November Sundays)"
        case .joan: return "Joan's turnips (Sundays)"
        case .kkSlider: return "K.K. Slider (Saturdays)"
        case .raffle: return "Nook's raffle (last day of the month)"
        default: return displayName
        }
    }

    /// The kinds the fixed calendar resolves on its own.
    static var fixedKinds: [ACEventKind] {
        allCases.filter { !$0.isSaveDriven }
    }

    /// The kinds only the town save can date: Town Day, the player's
    /// birthday and the visitors the game rolls (ACSaveReader).
    static let saveKinds: [ACEventKind] = [.townDay, .playerBirthday, .redd, .gracie, .saharah, .katrina, .wendell, .nookSale, .gulliver]

    /// The rolled visitors alone.
    static let visitorKinds: [ACEventKind] = [.redd, .gracie, .saharah, .katrina, .wendell, .nookSale, .gulliver]

    var isSaveDriven: Bool { Self.saveKinds.contains(self) }
}

// MARK: - Save-derived dates

/// What the fixed calendar cannot know without the save. Nil means "not
/// known": the rows that need them resolve to nothing. The visits are the
/// visitors the game last rolled (ACTownSave.visits).
struct ACSaveCalendarInfo: Equatable {
    /// Town Day's day of July (`Save_t.town_day`).
    var townDay: Int?
    /// The player's birthday (`Private_c.birthday`).
    var birthdayMonth: Int?
    var birthdayDay: Int?
    /// The rolled visitors, dated.
    var visits: [ACVisit]

    init(townDay: Int? = nil, birthdayMonth: Int? = nil, birthdayDay: Int? = nil, visits: [ACVisit] = []) {
        self.townDay = townDay
        self.birthdayMonth = birthdayMonth
        self.birthdayDay = birthdayDay
        self.visits = visits
    }
}

// MARK: - Occurrences

/// One day on which an event is on, with its hours that day.
struct ACEventOccurrence: Equatable {
    let kind: ACEventKind
    /// Start of the day, in the calendar the resolver was given.
    let day: Date
    /// Inclusive hour the event begins (the game's `start_hour`).
    let startHour: Int
    /// Inclusive last hour the event is on (the game's `end_hour`): an event
    /// with `endHour` 11 runs until 12:00. A visitor who stays past
    /// midnight counts on (Redd's 17 on the next day is 41).
    let endHour: Int
    /// True for a season or a span that this day opens; the resolver reports
    /// only the opening day of those.
    let isSeasonStart: Bool
    /// The last day of a season or span, when `isSeasonStart` is true.
    let seasonEnd: Date?

    /// On from 0:00 through 23:59.
    var isAllDay: Bool { startHour == 0 && endHour == 23 }

    /// The moment the event begins that day.
    func startDate(calendar: Calendar) -> Date? {
        calendar.date(byAdding: .hour, value: startHour, to: day)
    }

    /// The moment the event is over that day (the hour after `endHour`).
    func endDate(calendar: Calendar) -> Date? {
        calendar.date(byAdding: .hour, value: endHour + 1, to: day)
    }

    /// "6:00–12:00", "20:00–0:00", "18:00 until 18:00 the next day", or nil
    /// for an all-day event.
    var hoursText: String? {
        guard !isAllDay else { return nil }
        let end = (endHour + 1) % 24
        if endHour >= 24 {
            let days = (endHour + 1) / 24
            return "\(startHour):00 until \(end):00 \(days == 1 ? "the next day" : "\(days) days later")"
        }
        return "\(startHour):00–\(end):00"
    }
}

// MARK: - Schedule rows

/// A month in a schedule row. `now` is the game's `mEv_SCHEDULE_NOW_MONTH`.
enum ACMonthRule: Equatable {
    case fixed(Int)
    case now
    /// The Harvest Moon's month; the day rule must be `.harvestMoon` too.
    case harvestMoon
}

/// A day in a schedule row. Weekdays are 0 = Sunday … 6 = Saturday, as in
/// the game's `lbRTC_SUNDAY…lbRTC_SATURDAY`.
enum ACDayRule: Equatable {
    case fixed(Int)
    /// `mEv_SCHEDULE_nTH_WEEKDAY(weekday)`, n in 1...5.
    case nthWeekday(Int, weekday: Int)
    /// `mEv_SCHEDULE_LAST_WEEKDAY(weekday)`.
    case lastWeekday(weekday: Int)
    /// `mEv_SCHEDULE_EVERY_WEEKDAY(weekday)`: this week's such day.
    case everyWeekday(weekday: Int)
    /// `mEv_SCHEDULE_DAY_AFTER | mEv_SCHEDULE_nTH_WEEKDAY(weekday)`.
    case dayAfterNthWeekday(Int, weekday: Int)
    case lastDayOfMonth
    /// `mEv_SCHEDULE_TOWN_DAY`: from the save.
    case townDay
    /// The vernal (March) or autumnal (September) equinox, as the game's
    /// `update_sports_fair` computes it.
    case equinox
    /// The Harvest Moon's day; the month rule must be `.harvestMoon` too.
    case harvestMoon
    /// The player's birthday, from the save (`mEv_SAVE_DATE_BIRTHDAY`).
    case birthday
}

struct ACDateRule: Equatable {
    let month: ACMonthRule
    let day: ACDayRule
    let hour: Int

    init(_ month: ACMonthRule, _ day: ACDayRule, hour: Int) {
        self.month = month
        self.day = day
        self.hour = hour
    }
}

/// How the hours of a row apply across its date range: the game's hour flags.
enum ACSpan: Equatable {
    /// No flag: every day in the range runs `start.hour...end.hour`.
    case perDay
    /// `mEv_SCHEDULE_MULTIDAY`: one continuous span from the first day's
    /// start hour to the last day's end hour.
    case continuous
    /// `mEv_SCHEDULE_TODAY`: active on the day loaded with these hours.
    case today
}

struct ACScheduleRow: Equatable {
    let kind: ACEventKind
    let start: ACDateRule
    let end: ACDateRule
    let span: ACSpan

    init(_ kind: ACEventKind, _ start: ACDateRule, _ end: ACDateRule, span: ACSpan = .perDay) {
        self.kind = kind
        self.start = start
        self.end = end
        self.span = span
    }
}

// MARK: - Calendar

enum ACEventCalendar {

    /// `lbRTC_*` weekdays.
    static let sunday = 0, monday = 1, tuesday = 2, wednesday = 3, thursday = 4, friday = 5, saturday = 6

    /// A range of more than this many days is announced once, on its first
    /// day, as a season; shorter ranges are announced every day.
    static let seasonThresholdDays = 3

    /// `event_schedule_data[]`, the rows that are events to the player, in
    /// the table's order. Comments give the original row.
    static let rows: [ACScheduleRow] = [
        // {NOW_MONTH, EVERY_WEEKDAY(SUNDAY), 6} .. {.., 11} KABU_PEDDLER
        ACScheduleRow(.joan, ACDateRule(.now, .everyWeekday(weekday: sunday), hour: 6),
                      ACDateRule(.now, .everyWeekday(weekday: sunday), hour: 11)),
        // {NOW_MONTH, EVERY_WEEKDAY(SATURDAY), 20} .. {.., 23} KK_SLIDER
        ACScheduleRow(.kkSlider, ACDateRule(.now, .everyWeekday(weekday: saturday), hour: 20),
                      ACDateRule(.now, .everyWeekday(weekday: saturday), hour: 23)),
        // {NOW_MONTH, LAST_DAY_OF_MONTH, 0} .. {.., 23} LOTTERY
        ACScheduleRow(.raffle, ACDateRule(.now, .lastDayOfMonth, hour: 0),
                      ACDateRule(.now, .lastDayOfMonth, hour: 23)),
        // {SAVE_MONTH(BIRTHDAY), 0, 0} .. {.., 23} PLAYER_BIRTHDAY
        ACScheduleRow(.playerBirthday, ACDateRule(.now, .birthday, hour: 0),
                      ACDateRule(.now, .birthday, hour: 23)),
        // {DECEMBER, 25, 0} .. {FEBRUARY, 17, 23} SNOWMAN_SEASON
        ACScheduleRow(.snowmanSeason, ACDateRule(.fixed(12), .fixed(25), hour: 0),
                      ACDateRule(.fixed(2), .fixed(17), hour: 23)),
        // {APRIL, 3, 0} .. {APRIL, 8, 23} CHERRY_BLOSSOM_PETALS
        ACScheduleRow(.cherryBlossomPetals, ACDateRule(.fixed(4), .fixed(3), hour: 0),
                      ACDateRule(.fixed(4), .fixed(8), hour: 23)),
        // {JANUARY, 1, 6} .. {JANUARY, 1, 10} NEW_YEARS_DAY
        ACScheduleRow(.newYearsDay, ACDateRule(.fixed(1), .fixed(1), hour: 6),
                      ACDateRule(.fixed(1), .fixed(1), hour: 10)),
        // {JANUARY, 2, TODAY | 10} .. {FEBRUARY, 23, 21} KAMAKURA
        ACScheduleRow(.iglooSeason, ACDateRule(.fixed(1), .fixed(2), hour: 10),
                      ACDateRule(.fixed(2), .fixed(23), hour: 21), span: .today),
        // {FEBRUARY, 2, 7} .. {FEBRUARY, 2, 8} GROUNDHOG_DAY
        ACScheduleRow(.groundhogDay, ACDateRule(.fixed(2), .fixed(2), hour: 7),
                      ACDateRule(.fixed(2), .fixed(2), hour: 8)),
        // {FEBRUARY, 14, 0} .. {FEBRUARY, 14, 23} VALENTINES_DAY
        ACScheduleRow(.valentinesDay, ACDateRule(.fixed(2), .fixed(14), hour: 0),
                      ACDateRule(.fixed(2), .fixed(14), hour: 23)),
        // {MARCH, 19, 9} .. {MARCH, 21, 16} SPRING_EQUINOX, moved to the
        // vernal equinox day by update_sports_fair
        ACScheduleRow(.springSportsFair, ACDateRule(.fixed(3), .equinox, hour: 9),
                      ACDateRule(.fixed(3), .equinox, hour: 16)),
        // {APRIL, 1, 0} .. {APRIL, 1, 23} APRILFOOLS_DAY
        ACScheduleRow(.aprilFoolsDay, ACDateRule(.fixed(4), .fixed(1), hour: 0),
                      ACDateRule(.fixed(4), .fixed(1), hour: 23)),
        // {APRIL, 5, 10} .. {APRIL, 7, 21} CHERRY_BLOSSOM_FESTIVAL
        ACScheduleRow(.cherryBlossomFestival, ACDateRule(.fixed(4), .fixed(5), hour: 10),
                      ACDateRule(.fixed(4), .fixed(7), hour: 21)),
        // {APRIL, 22, 10} .. {APRIL, 22, 17} NATURE_DAY
        ACScheduleRow(.natureDay, ACDateRule(.fixed(4), .fixed(22), hour: 10),
                      ACDateRule(.fixed(4), .fixed(22), hour: 17)),
        // {MAY, 1, 0} .. {MAY, 1, 23} SPRING_CLEANING
        ACScheduleRow(.springCleaning, ACDateRule(.fixed(5), .fixed(1), hour: 0),
                      ACDateRule(.fixed(5), .fixed(1), hour: 23)),
        // {MAY, 2ND_WEEKDAY(SUNDAY), 0} .. {.., 23} MOTHERS_DAY
        ACScheduleRow(.mothersDay, ACDateRule(.fixed(5), .nthWeekday(2, weekday: sunday), hour: 0),
                      ACDateRule(.fixed(5), .nthWeekday(2, weekday: sunday), hour: 23)),
        // {JUNE, EVERY_WEEKDAY(SATURDAY), MULTIDAY | 9} .. {JUNE, EVERY_WEEKDAY(SUNDAY), 14}
        // SUMMER_CAMPER: the resolver special-cases it as the game does
        // (June, July and August; the tent stays until the next day).
        ACScheduleRow(.camper, ACDateRule(.now, .everyWeekday(weekday: saturday), hour: 9),
                      ACDateRule(.now, .everyWeekday(weekday: sunday), hour: 14), span: .continuous),
        // {JUNE, 2ND_WEEKDAY(FRIDAY), 10} .. {.., 17} GRADUATION_DAY
        ACScheduleRow(.graduationDay, ACDateRule(.fixed(6), .nthWeekday(2, weekday: friday), hour: 10),
                      ACDateRule(.fixed(6), .nthWeekday(2, weekday: friday), hour: 17)),
        // {JUNE, 3RD_WEEKDAY(SUNDAY), 0} .. {.., 23} FATHERS_DAY
        ACScheduleRow(.fathersDay, ACDateRule(.fixed(6), .nthWeekday(3, weekday: sunday), hour: 0),
                      ACDateRule(.fixed(6), .nthWeekday(3, weekday: sunday), hour: 23)),
        // {JUNE, EVERY_WEEKDAY(SUNDAY), 6} .. {.., 17} FISHING_TOURNEY_1
        ACScheduleRow(.fishingTourneyJune, ACDateRule(.fixed(6), .everyWeekday(weekday: sunday), hour: 6),
                      ACDateRule(.fixed(6), .everyWeekday(weekday: sunday), hour: 17)),
        // {JULY, 4, 19} .. {JULY, 4, 20} FIREWORKS_SHOW
        ACScheduleRow(.fireworks, ACDateRule(.fixed(7), .fixed(4), hour: 19),
                      ACDateRule(.fixed(7), .fixed(4), hour: 20)),
        // {JULY, TOWN_DAY, 10} .. {JULY, TOWN_DAY, 17} TOWN_DAY
        ACScheduleRow(.townDay, ACDateRule(.fixed(7), .townDay, hour: 10),
                      ACDateRule(.fixed(7), .townDay, hour: 17)),
        // {JULY, 25, TODAY | 6} .. {AUGUST, 31, TODAY | 6} MORNING_AEROBICS
        ACScheduleRow(.morningAerobics, ACDateRule(.fixed(7), .fixed(25), hour: 6),
                      ACDateRule(.fixed(8), .fixed(31), hour: 6), span: .today),
        // {AUGUST, 12, 18} .. {AUGUST, 12, 20} METEOR_SHOWER
        ACScheduleRow(.meteorShower, ACDateRule(.fixed(8), .fixed(12), hour: 18),
                      ACDateRule(.fixed(8), .fixed(12), hour: 20)),
        // {AUGUST, 21, 10} .. {AUGUST, 21, 17} FOUNDERS_DAY
        ACScheduleRow(.foundersDay, ACDateRule(.fixed(8), .fixed(21), hour: 10),
                      ACDateRule(.fixed(8), .fixed(21), hour: 17)),
        // {SEPTEMBER, 1ST_WEEKDAY(MONDAY), 10} .. {.., 17} LABOR_DAY
        ACScheduleRow(.laborDay, ACDateRule(.fixed(9), .nthWeekday(1, weekday: monday), hour: 10),
                      ACDateRule(.fixed(9), .nthWeekday(1, weekday: monday), hour: 17)),
        // {SEPTEMBER, 21, 9} .. {SEPTEMBER, 23, 16} AUTUMN_EQUINOX, moved to
        // the autumnal equinox day by update_sports_fair
        ACScheduleRow(.fallSportsFair, ACDateRule(.fixed(9), .equinox, hour: 9),
                      ACDateRule(.fixed(9), .equinox, hour: 16)),
        // {HARVEST_MOON_DATE | 8, 15, 18} .. {.., 20} HARVEST_MOON_FESTIVAL
        ACScheduleRow(.harvestMoon, ACDateRule(.harvestMoon, .harvestMoon, hour: 18),
                      ACDateRule(.harvestMoon, .harvestMoon, hour: 20)),
        // {OCTOBER, 2ND_WEEKDAY(MONDAY), 10} .. {.., 17} EXPLORERS_DAY
        ACScheduleRow(.explorersDay, ACDateRule(.fixed(10), .nthWeekday(2, weekday: monday), hour: 10),
                      ACDateRule(.fixed(10), .nthWeekday(2, weekday: monday), hour: 17)),
        // {OCTOBER, 15, 0} .. {OCTOBER, 25, 23} MUSHROOM_SEASON
        ACScheduleRow(.mushroomSeason, ACDateRule(.fixed(10), .fixed(15), hour: 0),
                      ACDateRule(.fixed(10), .fixed(25), hour: 23)),
        // {OCTOBER, 31, MULTIDAY | 18} .. {NOVEMBER, 1, 0} HALLOWEEN
        ACScheduleRow(.halloween, ACDateRule(.fixed(10), .fixed(31), hour: 18),
                      ACDateRule(.fixed(11), .fixed(1), hour: 0), span: .continuous),
        // {NOVEMBER, DAY_AFTER | 1ST_WEEKDAY(MONDAY), 10} .. {.., 17} MAYORS_DAY
        ACScheduleRow(.mayorsDay, ACDateRule(.fixed(11), .dayAfterNthWeekday(1, weekday: monday), hour: 10),
                      ACDateRule(.fixed(11), .dayAfterNthWeekday(1, weekday: monday), hour: 17)),
        // {NOVEMBER, 11, 10} .. {NOVEMBER, 11, 17} OFFICERS_DAY
        ACScheduleRow(.officersDay, ACDateRule(.fixed(11), .fixed(11), hour: 10),
                      ACDateRule(.fixed(11), .fixed(11), hour: 17)),
        // {NOVEMBER, EVERY_WEEKDAY(SUNDAY), 6} .. {.., 17} FISHING_TOURNEY_2
        ACScheduleRow(.fishingTourneyNovember, ACDateRule(.fixed(11), .everyWeekday(weekday: sunday), hour: 6),
                      ACDateRule(.fixed(11), .everyWeekday(weekday: sunday), hour: 17)),
        // {NOVEMBER, 4TH_WEEKDAY(THURSDAY), 15} .. {.., 20} HARVEST_FESTIVAL
        ACScheduleRow(.harvestFestival, ACDateRule(.fixed(11), .nthWeekday(4, weekday: thursday), hour: 15),
                      ACDateRule(.fixed(11), .nthWeekday(4, weekday: thursday), hour: 20)),
        // {NOVEMBER, DAY_AFTER | 4TH_WEEKDAY(THURSDAY), 0} .. {.., 23} SALE_DAY
        ACScheduleRow(.saleDay, ACDateRule(.fixed(11), .dayAfterNthWeekday(4, weekday: thursday), hour: 0),
                      ACDateRule(.fixed(11), .dayAfterNthWeekday(4, weekday: thursday), hour: 23)),
        // {DECEMBER, 1, 10} .. {DECEMBER, 1, 17} SNOW_DAY
        ACScheduleRow(.snowDay, ACDateRule(.fixed(12), .fixed(1), hour: 10),
                      ACDateRule(.fixed(12), .fixed(1), hour: 17)),
        // {DECEMBER, 23, 10} .. {DECEMBER, 23, 17} TOY_DAY_SONCHO
        ACScheduleRow(.toyDay, ACDateRule(.fixed(12), .fixed(23), hour: 10),
                      ACDateRule(.fixed(12), .fixed(23), hour: 17)),
        // {DECEMBER, 24, MULTIDAY | 20} .. {DECEMBER, 25, 0} TOY_DAY_JINGLE
        ACScheduleRow(.jingle, ACDateRule(.fixed(12), .fixed(24), hour: 20),
                      ACDateRule(.fixed(12), .fixed(25), hour: 0), span: .continuous),
        // {DECEMBER, 31, MULTIDAY | 23} .. {JANUARY, 1, 0} NEW_YEARS_EVE_COUNTDOWN
        ACScheduleRow(.newYearsEve, ACDateRule(.fixed(12), .fixed(31), hour: 23),
                      ACDateRule(.fixed(1), .fixed(1), hour: 0), span: .continuous),
    ]

    // MARK: Resolver

    /// Every day in `interval` on which a fixed event is on, plus the
    /// save's rolled visitors on their first day. A season (a range longer
    /// than `seasonThresholdDays`, or a continuous span) is reported once,
    /// on its first day. Rows that need the save resolve to nothing when
    /// `save` does not carry their date.
    static func events(in interval: DateInterval,
                       save: ACSaveCalendarInfo? = nil,
                       calendar: Calendar = .current) -> [ACEventOccurrence] {
        var result: [ACEventOccurrence] = []
        var day = calendar.startOfDay(for: interval.start)
        let lastDay = calendar.startOfDay(for: interval.end)
        let visits = save?.visits ?? []
        while day <= lastDay {
            let today = Today(date: day, calendar: calendar)
            for row in rows {
                if let occurrence = resolve(row, on: today, save: save) {
                    result.append(occurrence)
                }
            }
            for visit in visits where visit.day == day {
                result.append(ACEventOccurrence(kind: visit.kind, day: day,
                                                startHour: visit.startHour, endHour: visit.endHour,
                                                isSeasonStart: false, seasonEnd: nil))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    /// The next day on which something fixed happens, from `date` on.
    static func nextEvent(after date: Date,
                          excluding muted: Set<ACEventKind> = [],
                          save: ACSaveCalendarInfo? = nil,
                          calendar: Calendar = .current,
                          lookAheadDays: Int = 400) -> ACEventOccurrence? {
        guard let end = calendar.date(byAdding: .day, value: lookAheadDays, to: date) else { return nil }
        return events(in: DateInterval(start: date, end: end), save: save, calendar: calendar)
            .first { !muted.contains($0.kind) && ($0.endDate(calendar: calendar) ?? $0.day) > date }
    }

    // MARK: Rules

    /// The day the resolver works from: the game's `rtc_time` plus the
    /// month facts `m_weekday2day` keeps in `weekday1st[]`.
    struct Today {
        let date: Date
        let calendar: Calendar
        let year: Int
        let month: Int
        let day: Int
        /// 0 = Sunday … 6 = Saturday.
        let weekday: Int

        init(date: Date, calendar: Calendar) {
            self.date = date
            self.calendar = calendar
            let c = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
            year = c.year ?? 1
            month = c.month ?? 1
            day = c.day ?? 1
            weekday = ((c.weekday ?? 1) - 1 + 7) % 7
        }

        /// `last_day_of_month`, for this year.
        func lastDay(ofMonth m: Int) -> Int {
            ACEventCalendar.lastDay(ofMonth: m, year: year)
        }

        /// `weekday1st[month]`: the weekday of the first of that month, this year.
        func firstWeekday(ofMonth m: Int) -> Int {
            ACEventCalendar.weekday(year: year, month: m, day: 1)
        }
    }

    /// A resolved (month, day) with the game's `month << 8 | day` ordering.
    struct MonthDay: Comparable, Equatable {
        let month: Int
        let day: Int
        var raw: Int { month << 8 | day }
        static func < (a: MonthDay, b: MonthDay) -> Bool { a.raw < b.raw }
    }

    static func resolve(_ row: ACScheduleRow, on today: Today, save: ACSaveCalendarInfo?) -> ACEventOccurrence? {
        if row.kind == .camper {
            return resolveCamper(row, on: today)
        }
        guard let start = decode(row.start, on: today, save: save),
              let end = decode(row.end, on: today, save: save) else { return nil }
        let todayMD = MonthDay(month: today.month, day: today.day)
        guard inRange(todayMD, lower: start, upper: end) else { return nil }

        let rangeDays = daysBetween(start, end, today: today)
        let isSeason = row.span == .continuous || rangeDays > seasonThresholdDays
        if isSeason && todayMD != start {
            return nil
        }

        var startHour = row.start.hour
        var endHour = row.end.hour
        if row.span == .continuous {
            if todayMD != start { startHour = 0 }
            if todayMD != end { endHour = 23 }
        }

        var seasonEnd: Date? = nil
        if isSeason {
            let endYear = end < start ? today.year + 1 : today.year
            seasonEnd = today.calendar.date(from: DateComponents(year: endYear, month: end.month, day: end.day))
        }
        return ACEventOccurrence(kind: row.kind, day: today.date,
                                 startHour: startHour, endHour: endHour,
                                 isSeasonStart: isSeason, seasonEnd: seasonEnd)
    }

    /// `update_schedule_today`'s SUMMER_CAMPER branch: in June, July and
    /// August the tent is up from this week's Saturday 9:00 until the
    /// Sunday 14:00; a Sunday looks back to the Saturday before it.
    private static func resolveCamper(_ row: ACScheduleRow, on today: Today) -> ACEventOccurrence? {
        guard (6...8).contains(today.month), today.weekday == saturday else { return nil }
        let endDay = today.calendar.date(byAdding: .day, value: 1, to: today.date)
        return ACEventOccurrence(kind: .camper, day: today.date,
                                 startHour: row.start.hour, endHour: 23,
                                 isSeasonStart: true, seasonEnd: endDay)
    }

    /// `decode_date` for one end of a row. Nil when the rule cannot be
    /// resolved (a save-driven date without the save, an equinox rule on
    /// the wrong day, a weekly rule whose day is not in the month).
    static func decode(_ rule: ACDateRule, on today: Today, save: ACSaveCalendarInfo?) -> MonthDay? {
        var month: Int
        switch rule.month {
        case .fixed(let m): month = m
        case .now: month = today.month
        case .harvestMoon:
            let hm = harvestMoon(year: today.year)
            return MonthDay(month: hm.month, day: hm.day)
        }

        let day: Int
        switch rule.day {
        case .fixed(let d):
            day = d
        case .nthWeekday(let n, let weekday):
            day = nthWeekday(n, weekday: weekday, month: month, today: today)
        case .lastWeekday(let weekday):
            day = lastWeekday(weekday, month: month, today: today)
        case .everyWeekday(let weekday):
            // m_weekday2day with mEv_SCHEDULE_EVERY_WEEK: this week's such
            // day when the month is the current one, the first such day of a
            // later month, the last such day of an earlier one.
            if month > today.month {
                day = nthWeekday(1, weekday: weekday, month: month, today: today)
            } else if month < today.month {
                day = lastWeekday(weekday, month: month, today: today)
            } else {
                let d = today.day - (today.weekday - weekday)
                if d > today.lastDay(ofMonth: month) {
                    day = lastWeekday(weekday, month: month, today: today)
                } else if d < 1 {
                    // The game's u8 arithmetic wraps this to a day the
                    // range check can never match.
                    return nil
                } else {
                    day = d
                }
            }
        case .dayAfterNthWeekday(let n, let weekday):
            let base = MonthDay(month: month, day: nthWeekday(n, weekday: weekday, month: month, today: today))
            return afterOneDay(base, today: today)
        case .lastDayOfMonth:
            day = today.lastDay(ofMonth: month)
        case .townDay:
            guard let townDay = save?.townDay, townDay >= 1 else { return nil }
            day = townDay
        case .equinox:
            // update_sports_fair: the row is live only on the equinox day
            // itself, in its month.
            let equinoxDay = month == 3 ? vernalEquinoxDay(year: today.year) : autumnalEquinoxDay(year: today.year)
            guard today.month == month, today.day == equinoxDay else { return nil }
            day = equinoxDay
        case .harvestMoon:
            let hm = harvestMoon(year: today.year)
            return MonthDay(month: hm.month, day: hm.day)
        case .birthday:
            guard let bm = save?.birthdayMonth, let bd = save?.birthdayDay, bm >= 1, bd >= 1 else { return nil }
            month = bm
            day = bd
        }
        return MonthDay(month: month, day: day)
    }

    /// `check_date_range`: a lower bound past the upper one wraps the year.
    static func inRange(_ date: MonthDay, lower: MonthDay, upper: MonthDay) -> Bool {
        if lower > upper {
            return lower <= date || date <= upper
        }
        return lower <= date && date <= upper
    }

    /// Days from `start` to `end`, wrapping the year when `end` is earlier.
    static func daysBetween(_ start: MonthDay, _ end: MonthDay, today: Today) -> Int {
        let startOrdinal = dayOfYear(start, year: today.year)
        var endOrdinal = dayOfYear(end, year: today.year)
        if end < start {
            endOrdinal += daysInYear(today.year)
        }
        return endOrdinal - startOrdinal
    }

    /// `after_n_day(date, 1)`.
    static func afterOneDay(_ date: MonthDay, today: Today) -> MonthDay {
        if date.day + 1 > today.lastDay(ofMonth: date.month) {
            return MonthDay(month: date.month == 12 ? 1 : date.month + 1, day: 1)
        }
        return MonthDay(month: date.month, day: date.day + 1)
    }

    /// `m_weekday2day` for week 1...5.
    static func nthWeekday(_ n: Int, weekday: Int, month: Int, today: Today) -> Int {
        let first = today.firstWeekday(ofMonth: month)
        if weekday >= first {
            return 1 + (n - 1) * 7 + (weekday - first)
        }
        return 1 + n * 7 + (weekday - first)
    }

    /// `m_weekday2day` for `mEv_SCHEDULE_LAST_WEEKDAY_OF_MONTH`.
    static func lastWeekday(_ weekday: Int, month: Int, today: Today) -> Int {
        let last = today.lastDay(ofMonth: month)
        let firstOfNext = (last - 1 + today.firstWeekday(ofMonth: month)) % 7 // weekday of the 1st of next month
        if weekday <= firstOfNext {
            return last - (firstOfNext - weekday)
        }
        return last - (firstOfNext - weekday) - 7
    }

    // MARK: Astronomy, as the game computes it

    /// `lbRk_VernalEquinoxDay`: valid 1980 through 2099. The game does this
    /// in single precision, so the same arithmetic is kept here.
    static func vernalEquinoxDay(year: Int) -> Int {
        let y = year - 1980
        return Int(Float(20.8431) + Float(0.242194) * Float(y)) - (y / 4)
    }

    /// `lbRk_AutumnalEquinoxDay`: valid 1980 through 2099.
    static func autumnalEquinoxDay(year: Int) -> Int {
        let y = year - 1980
        return Int(Float(23.2488) + Float(0.242194) * Float(y)) - (y / 4)
    }

    /// `lbRk_HarvestMoonDay`: the game's table for 2002 through 2030, then
    /// the 15th day of the 8th lunisolar month. Past the table the game
    /// converts with its own Japanese almanac, which runs out with its
    /// year range; Foundation's Chinese calendar stands in for it there and
    /// can sit a day off the Japanese reckoning.
    static func harvestMoon(year: Int) -> (month: Int, day: Int) {
        let table: [Int: (Int, Int)] = [
            2002: (9, 21), 2003: (9, 10), 2004: (9, 28), 2005: (9, 18), 2006: (10, 7),
            2007: (9, 26), 2008: (9, 15), 2009: (10, 4), 2010: (9, 23), 2011: (9, 12),
            2012: (9, 30), 2013: (9, 19), 2014: (9, 9), 2015: (9, 28), 2016: (9, 16),
            2017: (10, 5), 2018: (9, 25), 2019: (9, 14), 2020: (10, 1), 2021: (9, 20),
            2022: (9, 10), 2023: (9, 29), 2024: (9, 18), 2025: (10, 7), 2026: (9, 26),
            2027: (9, 15), 2028: (10, 3), 2029: (9, 22), 2030: (9, 11),
        ]
        if let entry = table[year] {
            return (entry.0, entry.1)
        }
        return lunisolarHarvestMoon(year: year) ?? (9, 15)
    }

    /// The Gregorian date of the 15th day of the 8th lunisolar month.
    static func lunisolarHarvestMoon(year: Int) -> (month: Int, day: Int)? {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = gregorian.timeZone
        guard var date = gregorian.date(from: DateComponents(year: year, month: 9, day: 1)),
              let end = gregorian.date(from: DateComponents(year: year, month: 10, day: 31)) else { return nil }
        while date <= end {
            // The first 8/15 after September 1 is the regular eighth month; a
            // leap eighth month follows it (isLeapMonth itself needs iOS 17).
            let c = chinese.dateComponents([.month, .day], from: date)
            if c.month == 8, c.day == 15 {
                let g = gregorian.dateComponents([.month, .day], from: date)
                if let m = g.month, let d = g.day { return (m, d) }
            }
            guard let next = gregorian.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return nil
    }

    // MARK: Gregorian helpers (proleptic, no Calendar needed)

    static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    static func daysInYear(_ year: Int) -> Int { isLeapYear(year) ? 366 : 365 }

    static func lastDay(ofMonth month: Int, year: Int) -> Int {
        switch month {
        case 2: return isLeapYear(year) ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    static func dayOfYear(_ md: MonthDay, year: Int) -> Int {
        var n = md.day
        if md.month > 1 {
            for m in 1..<md.month { n += lastDay(ofMonth: m, year: year) }
        }
        return n
    }

    /// 0 = Sunday … 6 = Saturday (Zeller / Sakamoto).
    static func weekday(year: Int, month: Int, day: Int) -> Int {
        let t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
        let y = month < 3 ? year - 1 : year
        return (y + y / 4 - y / 100 + y / 400 + t[month - 1] + day) % 7
    }
}
