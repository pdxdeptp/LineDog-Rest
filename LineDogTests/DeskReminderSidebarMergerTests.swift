import XCTest
@testable import LineDog

final class DeskReminderSidebarMergerTests: XCTestCase {
    func testMergeSortsByDueDateAndDedupes() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let d1 = cal.date(from: DateComponents(year: 2026, month: 3, day: 22, hour: 10, minute: 0))!
        let d2 = cal.date(from: DateComponents(year: 2026, month: 3, day: 21, hour: 15, minute: 0))!
        let a = ReminderDisplayItem(calendarItemIdentifier: "a", title: "Later", dueDate: d1, hasRoutineTag: false)
        let b = ReminderDisplayItem(calendarItemIdentifier: "b", title: "Sooner", dueDate: d2, hasRoutineTag: true)
        let merged = DeskReminderSidebarMerger.mergedDisplayItems(routineToday: [b], nonRoutineWeek: [a])
        XCTAssertEqual(merged.map { $0.id }, ["b", "a"])
    }
}
