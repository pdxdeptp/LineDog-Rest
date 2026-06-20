import XCTest
@testable import MalDaze

final class LearningScheduleDayWindowTests: XCTestCase {
    private func day(_ iso: String) -> HermesScheduleRangeDay {
        HermesScheduleRangeDay(
            date: iso,
            isRestDay: false,
            studyMinutes: 0,
            reviewMinutes: 0,
            budgetStudy: 300,
            budgetReview: 60,
            overCapacity: false,
            tasks: []
        )
    }

    func testEntireRangeShowsAllDays() {
        let days = [day("2026-06-01"), day("2026-06-19"), day("2026-06-30")]
        let result = LearningScheduleDayWindow.entireRange.presentation(for: days)
        XCTAssertEqual(result.visibleDays.map(\.date), ["2026-06-01", "2026-06-19", "2026-06-30"])
        XCTAssertEqual(result.hiddenEarlierDayCount, 0)
    }

    func testStartingAtTodayHidesEarlierDaysInMonth() {
        let days = (1...30).map { day(String(format: "2026-06-%02d", $0)) }
        let result = LearningScheduleDayWindow.startingAt("2026-06-19").presentation(for: days)
        XCTAssertEqual(result.hiddenEarlierDayCount, 18)
        XCTAssertEqual(result.visibleDays.first?.date, "2026-06-19")
        XCTAssertEqual(result.visibleDays.last?.date, "2026-06-30")
    }

    func testStartingAtTomorrowWhenTodayMissingStillStartsAtAnchor() {
        let days = [day("2026-06-18"), day("2026-06-20")]
        let result = LearningScheduleDayWindow.startingAt("2026-06-19").presentation(for: days)
        XCTAssertEqual(result.hiddenEarlierDayCount, 1)
        XCTAssertEqual(result.visibleDays.map(\.date), ["2026-06-20"])
    }

    func testAgendaViewportHeightSubtractsChromeAndEarlierButton() {
        let height = LearningScheduleScrollLayout.agendaViewportHeight(
            totalHeight: 400,
            chromeHeight: 48,
            showsEarlierButton: true
        )
        XCTAssertEqual(height, 400 - 48 - 30 - 10, accuracy: 0.001)
    }
}
