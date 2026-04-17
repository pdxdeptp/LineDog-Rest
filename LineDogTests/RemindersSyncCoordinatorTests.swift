import XCTest
@testable import LineDog

@MainActor
final class RemindersSyncCoordinatorTests: XCTestCase {
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "RemindersSyncCoordinatorTests.\(UUID().uuidString)")!
    }

    override func tearDown() {
        testDefaults = nil
        super.tearDown()
    }

    func testReloadWithoutSelectedList_doesNotCallFetch() async {
        let mock = MockRemindersEventStoreBacking()
        let pref = RemindersSelectedListPreference(defaults: testDefaults)
        pref.selectedCalendarIdentifier = nil
        let c = RemindersSyncCoordinator(backing: mock, preference: pref, debounceInterval: 0.05)
        await c.reloadFromEventKit()
        XCTAssertEqual(mock.fetchCallCount, 0)
        XCTAssertTrue(c.items.isEmpty)
    }

    func testFetchPassesSelectedCalendarIdToBacking() async {
        let mock = MockRemindersEventStoreBacking()
        let pref = RemindersSelectedListPreference(defaults: testDefaults)
        pref.selectedCalendarIdentifier = "list-alpha"
        mock.fetchResult = [
            ReminderDisplayItem(calendarItemIdentifier: "e1", title: "One")
        ]
        let c = RemindersSyncCoordinator(backing: mock, preference: pref, debounceInterval: 0.05)
        await c.reloadFromEventKit()
        XCTAssertEqual(mock.lastFetchedCalendarId, "list-alpha")
        XCTAssertEqual(mock.fetchCallCount, 1)
        XCTAssertEqual(c.items.count, 1)
        XCTAssertEqual(c.items.first?.title, "One")
    }

    func testDebounce_coalescesRapidExternalChangeSignals() async {
        let mock = MockRemindersEventStoreBacking()
        let pref = RemindersSelectedListPreference(defaults: testDefaults)
        pref.selectedCalendarIdentifier = "cal"
        mock.fetchResult = []
        let c = RemindersSyncCoordinator(backing: mock, preference: pref, debounceInterval: 0.05)
        await c.reloadFromEventKit()
        XCTAssertEqual(mock.fetchCallCount, 1)

        c.scheduleReloadFromExternalChange()
        c.scheduleReloadFromExternalChange()
        c.scheduleReloadFromExternalChange()
        XCTAssertEqual(mock.fetchCallCount, 1)

        try? await Task.sleep(nanoseconds: 90_000_000)
        XCTAssertEqual(mock.fetchCallCount, 2)
    }

    func testOptimisticComplete_removesItemBeforeAsyncSaveFinishes() async {
        let mock = MockRemindersEventStoreBacking()
        let pref = RemindersSelectedListPreference(defaults: testDefaults)
        pref.selectedCalendarIdentifier = "cal"
        let item = ReminderDisplayItem(calendarItemIdentifier: "r1", title: "Task")
        mock.fetchResult = [item]
        mock.completeDelayNanos = 200_000_000

        let c = RemindersSyncCoordinator(backing: mock, preference: pref, debounceInterval: 0.05)
        await c.reloadFromEventKit()
        XCTAssertEqual(c.items.count, 1)

        async let completeTask: Void = c.markComplete(id: "r1")
        try? await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertTrue(c.items.isEmpty, "应立刻从内存队列消失（乐观 UI）")
        await completeTask
        XCTAssertEqual(mock.completeCallOrder, ["r1"])
    }

    func testOptimisticComplete_onSaveFailure_restoresViaReload() async {
        let mock = MockRemindersEventStoreBacking()
        let pref = RemindersSelectedListPreference(defaults: testDefaults)
        pref.selectedCalendarIdentifier = "cal"
        let item = ReminderDisplayItem(calendarItemIdentifier: "r1", title: "Task")
        mock.fetchResult = [item]
        mock.completeErrors["r1"] = NSError(domain: "test", code: 1)

        let c = RemindersSyncCoordinator(backing: mock, preference: pref, debounceInterval: 0.05)
        await c.reloadFromEventKit()
        await c.markComplete(id: "r1")
        XCTAssertEqual(c.items.count, 1)
        XCTAssertEqual(c.items.first?.id, "r1")
    }

    func testRemindersDefaultListResolver_prefersChineseDefaultName() {
        let lists = [
            RemindersCalendarDescriptor(calendarIdentifier: "w", title: "工作"),
            RemindersCalendarDescriptor(calendarIdentifier: "d", title: "提醒事项")
        ]
        XCTAssertEqual(RemindersDefaultListResolver.preferredCalendarId(from: lists), "d")
    }

    func testRemindersDefaultListResolver_fallsBackToRemindersEnglish() {
        let lists = [
            RemindersCalendarDescriptor(calendarIdentifier: "w", title: "Work"),
            RemindersCalendarDescriptor(calendarIdentifier: "e", title: "Reminders")
        ]
        XCTAssertEqual(RemindersDefaultListResolver.preferredCalendarId(from: lists), "e")
    }

    func testDeleteReminder_callsBackingAndReloads() async {
        let mock = MockRemindersEventStoreBacking()
        let pref = RemindersSelectedListPreference(defaults: testDefaults)
        pref.selectedCalendarIdentifier = "cal"
        let item = ReminderDisplayItem(calendarItemIdentifier: "d1", title: "Del")
        mock.fetchResult = [item]
        let c = RemindersSyncCoordinator(backing: mock, preference: pref, debounceInterval: 0.05)
        await c.reloadFromEventKit()
        XCTAssertEqual(mock.fetchCallCount, 1)
        XCTAssertEqual(c.items.count, 1)

        await c.deleteReminder(id: "d1")
        XCTAssertEqual(mock.deleteCallOrder, ["d1"])
        XCTAssertEqual(mock.fetchCallCount, 2)
        XCTAssertTrue(c.items.isEmpty)
    }

    func testDeleteReminder_onFailure_restoresViaReload() async {
        let mock = MockRemindersEventStoreBacking()
        let pref = RemindersSelectedListPreference(defaults: testDefaults)
        pref.selectedCalendarIdentifier = "cal"
        let item = ReminderDisplayItem(calendarItemIdentifier: "d1", title: "Del")
        mock.fetchResult = [item]
        mock.deleteErrors["d1"] = NSError(domain: "t", code: 2)
        let c = RemindersSyncCoordinator(backing: mock, preference: pref, debounceInterval: 0.05)
        await c.reloadFromEventKit()
        await c.deleteReminder(id: "d1")
        XCTAssertEqual(c.items.count, 1)
        XCTAssertEqual(c.items.first?.id, "d1")
    }

    func testSaveReminderDetail_callsBackingAndReloads() async throws {
        let mock = MockRemindersEventStoreBacking()
        let pref = RemindersSelectedListPreference(defaults: testDefaults)
        pref.selectedCalendarIdentifier = "cal"
        let item = ReminderDisplayItem(calendarItemIdentifier: "s1", title: "Old")
        mock.fetchResult = [item]
        let c = RemindersSyncCoordinator(backing: mock, preference: pref, debounceInterval: 0.05)
        await c.reloadFromEventKit()
        XCTAssertEqual(mock.fetchCallCount, 1)

        var detail = try await c.loadReminderDetail(calendarItemIdentifier: "s1")
        XCTAssertEqual(mock.loadCallOrder, ["s1"])
        detail.title = "New"
        try await c.saveReminderDetail(detail)
        XCTAssertEqual(mock.savedDetails.count, 1)
        XCTAssertEqual(mock.savedDetails.first?.title, "New")
        XCTAssertEqual(mock.fetchCallCount, 2)
        XCTAssertEqual(c.items.first?.title, "New")
    }
}
