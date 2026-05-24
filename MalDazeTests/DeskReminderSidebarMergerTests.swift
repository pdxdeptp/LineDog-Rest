import EventKit
import XCTest
@testable import MalDaze

final class DeskReminderSidebarMergerTests: XCTestCase {
    func testMergeSortsUpcomingWindowItemsByDueDateAndDedupes() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let d1 = cal.date(from: DateComponents(year: 2026, month: 3, day: 22, hour: 10, minute: 0))!
        let d2 = cal.date(from: DateComponents(year: 2026, month: 3, day: 21, hour: 15, minute: 0))!
        let a = ReminderDisplayItem(calendarItemIdentifier: "a", title: "Later", dueDate: d1, hasRoutineTag: false)
        let b = ReminderDisplayItem(calendarItemIdentifier: "b", title: "Sooner", dueDate: d2, hasRoutineTag: true)
        let merged = DeskReminderSidebarMerger.mergedDisplayItems(routineToday: [b], nonRoutineUpcomingWindow: [a])
        XCTAssertEqual(merged.map { $0.id }, ["b", "a"])
    }

    func testEventKitSidebarMappingPreservesPlainNotesAndStripsStandaloneRoutineMarker() {
        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = "浇花"
        reminder.notes = "阳台那盆\n#日常\n别忘了换水"

        let item = EventKitRemindersBacking.mapReminder(reminder)

        XCTAssertTrue(item.hasRoutineTag)
        XCTAssertEqual(item.notesPlain, "阳台那盆\n别忘了换水")
    }

    func testDisplayItemCanRepresentReminderWithoutNotes() {
        let item = ReminderDisplayItem(calendarItemIdentifier: "no-notes", title: "站起来走走")

        XCTAssertEqual(item.notesPlain, "")
    }
}
