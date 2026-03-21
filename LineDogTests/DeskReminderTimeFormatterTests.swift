import XCTest
@testable import LineDog

final class DeskReminderTimeFormatterTests: XCTestCase {
    private var cal: Calendar!
    private var tz: TimeZone!

    override func setUp() {
        super.setUp()
        tz = TimeZone(identifier: "America/New_York")!
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        cal = c
    }

    func testTodayShowsTimeOnly() {
        var dc = DateComponents(calendar: cal, timeZone: tz, year: 2026, month: 3, day: 21, hour: 15, minute: 5)
        let due = cal.date(from: dc)!
        var nowDc = dc
        nowDc.hour = 10
        let now = cal.date(from: nowDc)!
        let s = DeskReminderTimeFormatter.displayString(dueDate: due, now: now, calendar: cal)
        XCTAssertEqual(s, "15:05")
    }

    func testTomorrowShowsPrefix() {
        var dueDc = DateComponents(calendar: cal, timeZone: tz, year: 2026, month: 3, day: 22, hour: 10, minute: 0)
        let due = cal.date(from: dueDc)!
        var nowDc = DateComponents(calendar: cal, timeZone: tz, year: 2026, month: 3, day: 21, hour: 12, minute: 0)
        let now = cal.date(from: nowDc)!
        let s = DeskReminderTimeFormatter.displayString(dueDate: due, now: now, calendar: cal)
        XCTAssertTrue(s.hasPrefix("明天"))
        XCTAssertTrue(s.contains("10:00"))
    }

    func testLaterInWeekShowsWeekday() {
        var dueDc = DateComponents(calendar: cal, timeZone: tz, year: 2026, month: 3, day: 25, hour: 9, minute: 30)
        let due = cal.date(from: dueDc)!
        var nowDc = DateComponents(calendar: cal, timeZone: tz, year: 2026, month: 3, day: 21, hour: 12, minute: 0)
        let now = cal.date(from: nowDc)!
        let s = DeskReminderTimeFormatter.displayString(dueDate: due, now: now, calendar: cal)
        XCTAssertFalse(s.isEmpty)
        XCTAssertFalse(s.hasPrefix("明天"))
    }

    func testTimeOnlyHHmm() {
        var dc = DateComponents(calendar: cal, timeZone: tz, year: 2026, month: 3, day: 21, hour: 9, minute: 5)
        let due = cal.date(from: dc)!
        XCTAssertEqual(DeskReminderTimeFormatter.timeOnly(dueDate: due, calendar: cal), "09:05")
        XCTAssertEqual(DeskReminderTimeFormatter.timeOnly(dueDate: nil, calendar: cal), "—")
    }

    func testSectionHeaderTodayTomorrowAfterFormats() {
        let todayStart = cal.date(from: DateComponents(calendar: cal, timeZone: tz, year: 2026, month: 3, day: 21))!
        let now = cal.date(from: DateComponents(calendar: cal, timeZone: tz, year: 2026, month: 3, day: 21, hour: 10))!
        let t0 = DeskReminderSectionHeaderFormatter.title(forDayStart: todayStart, now: now, calendar: cal)
        XCTAssertTrue(t0.hasPrefix("今天"))
        XCTAssertTrue(t0.contains("3月21日"))

        let tomorrowStart = cal.date(from: DateComponents(calendar: cal, timeZone: tz, year: 2026, month: 3, day: 22))!
        let t1 = DeskReminderSectionHeaderFormatter.title(forDayStart: tomorrowStart, now: now, calendar: cal)
        XCTAssertTrue(t1.hasPrefix("明天"))
        XCTAssertTrue(t1.contains("3月22日"))

        let afterStart = cal.date(from: DateComponents(calendar: cal, timeZone: tz, year: 2026, month: 3, day: 23))!
        let t2 = DeskReminderSectionHeaderFormatter.title(forDayStart: afterStart, now: now, calendar: cal)
        XCTAssertTrue(t2.hasPrefix("后天"))
        XCTAssertTrue(t2.contains("3月23日"))

        let farStart = cal.date(from: DateComponents(calendar: cal, timeZone: tz, year: 2026, month: 3, day: 28))!
        let t3 = DeskReminderSectionHeaderFormatter.title(forDayStart: farStart, now: now, calendar: cal)
        XCTAssertTrue(t3.contains("3月28日"))
        XCTAssertFalse(t3.hasPrefix("今天"))
        XCTAssertFalse(t3.hasPrefix("明天"))
        XCTAssertFalse(t3.hasPrefix("后天"))
    }

    func testDayGroupsOrdersByDayAndTime() {
        let a = ReminderDisplayItem(calendarItemIdentifier: "a", title: "晚", dueDate: cal.date(from: DateComponents(calendar: cal, timeZone: tz, year: 2026, month: 3, day: 21, hour: 18, minute: 0)))
        let b = ReminderDisplayItem(calendarItemIdentifier: "b", title: "早", dueDate: cal.date(from: DateComponents(calendar: cal, timeZone: tz, year: 2026, month: 3, day: 21, hour: 8, minute: 0)))
        let c = ReminderDisplayItem(calendarItemIdentifier: "c", title: "明", dueDate: cal.date(from: DateComponents(calendar: cal, timeZone: tz, year: 2026, month: 3, day: 22, hour: 12, minute: 0)))
        let now = cal.date(from: DateComponents(calendar: cal, timeZone: tz, year: 2026, month: 3, day: 21, hour: 10))!
        let sections = DeskReminderDayGroups.sections(items: [c, a, b], now: now, calendar: cal)
        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].items.map(\.title), ["早", "晚"])
        XCTAssertEqual(sections[1].items.map(\.title), ["明"])
    }
}
