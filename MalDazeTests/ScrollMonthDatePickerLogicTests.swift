import XCTest
@testable import MalDaze

final class ScrollMonthDatePickerLogicTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.locale = Locale(identifier: "zh_CN")
        cal.firstWeekday = 1
        calendar = cal
    }

    func testMonthKeyFormatsYearAndMonth() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 9)))
        XCTAssertEqual(ScrollMonthDatePickerLogic.monthKey(for: date, calendar: calendar), "2026-06")
    }

    func testMonthStartsProducesSymmetricRange() throws {
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        let months = ScrollMonthDatePickerLogic.monthStarts(
            around: anchor,
            radius: 12,
            calendar: calendar
        )
        XCTAssertEqual(months.count, 25)
        XCTAssertEqual(
            ScrollMonthDatePickerLogic.monthKey(for: months.first!, calendar: calendar),
            "2025-06"
        )
        XCTAssertEqual(
            ScrollMonthDatePickerLogic.monthKey(for: months.last!, calendar: calendar),
            "2027-06"
        )
    }

    func testJune2026GridContainsThirtyInMonthDays() throws {
        let monthStart = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let cells = ScrollMonthDatePickerLogic.dayGrid(for: monthStart, calendar: calendar)
        let inMonth = cells.filter(\.isInDisplayedMonth)
        XCTAssertEqual(inMonth.count, 30)
        XCTAssertEqual(inMonth.first?.dayNumber, 1)
        XCTAssertEqual(inMonth.last?.dayNumber, 30)
    }

    func testJune2026GridLeadingPaddingStartsOnMondayColumn() throws {
        // 2026-06-01 is Monday → one leading Sunday-column cell from May.
        let monthStart = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let cells = ScrollMonthDatePickerLogic.dayGrid(for: monthStart, calendar: calendar)
        XCTAssertFalse(cells.first!.isInDisplayedMonth)
        XCTAssertEqual(cells.first?.dayNumber, 31)
    }

    func testNormalizedSelectionStripsTimeComponent() throws {
        let raw = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 6, day: 9, hour: 15, minute: 42
        )))
        let normalized = ScrollMonthDatePickerLogic.normalizedSelection(raw, calendar: calendar)
        XCTAssertEqual(calendar.component(.hour, from: normalized), 0)
        XCTAssertEqual(calendar.component(.minute, from: normalized), 0)
        XCTAssertEqual(ScrollMonthDatePickerLogic.isoDate(normalized, calendar: calendar), "2026-06-09")
    }

    func testWeekdaySymbolsAreSundayFirstChinese() {
        XCTAssertEqual(
            ScrollMonthDatePickerLogic.weekdaySymbols,
            ["日", "一", "二", "三", "四", "五", "六"]
        )
    }

    func testMergeCalendarDayPreservesTimeComponents() throws {
        let daySource = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 15, hour: 0, minute: 0
        )))
        let timeSource = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 6, day: 9, hour: 14, minute: 30
        )))
        let merged = ScrollMonthDatePickerLogic.mergeCalendarDay(
            from: daySource,
            preservingTimeFrom: timeSource,
            calendar: calendar
        )
        XCTAssertEqual(calendar.component(.year, from: merged), 2026)
        XCTAssertEqual(calendar.component(.month, from: merged), 8)
        XCTAssertEqual(calendar.component(.day, from: merged), 15)
        XCTAssertEqual(calendar.component(.hour, from: merged), 14)
        XCTAssertEqual(calendar.component(.minute, from: merged), 30)
    }
}
