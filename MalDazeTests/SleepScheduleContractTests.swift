import XCTest
@testable import MalDaze

final class SleepScheduleContractTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sleep-contract-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testReadValidContract() throws {
        let url = tempDir.appendingPathComponent("sleep_schedule.json")
        try """
        {
          "schemaVersion": 1,
          "targetBedtime": "23:50",
          "lockBedtime": "23:55",
          "dayType": "training",
          "updatedAt": "2026-06-06T08:00:00-04:00"
        }
        """.write(to: url, atomically: true, encoding: .utf8)

        let contract = try SleepScheduleContractReader(fileURL: url).read()
        XCTAssertEqual(contract.targetBedtime, SleepClockTime(hour: 23, minute: 50))
        XCTAssertEqual(contract.lockBedtime, SleepClockTime(hour: 23, minute: 55))
        XCTAssertEqual(contract.dayType, .training)
        XCTAssertEqual(contract.updatedAt, "2026-06-06T08:00:00-04:00")
    }

    func testMissingDayTypeFails() {
        let url = tempDir.appendingPathComponent("sleep_schedule.json")
        try? """
        {
          "schemaVersion": 1,
          "targetBedtime": "00:00",
          "lockBedtime": "00:05",
          "updatedAt": "2026-06-06T08:00:00-04:00"
        }
        """.write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try SleepScheduleContractReader(fileURL: url).read()) { error in
            guard case SleepScheduleContractError.missingField("dayType") = error else {
                return XCTFail("expected missing dayType, got \(error)")
            }
        }
    }

    func testInvalidDayTypeFails() {
        let url = tempDir.appendingPathComponent("sleep_schedule.json")
        try? """
        {
          "schemaVersion": 1,
          "targetBedtime": "00:00",
          "lockBedtime": "00:05",
          "dayType": "holiday",
          "updatedAt": "2026-06-06T08:00:00-04:00"
        }
        """.write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try SleepScheduleContractReader(fileURL: url).read()) { error in
            guard case SleepScheduleContractError.invalidDayType("holiday") = error else {
                return XCTFail("expected invalid dayType, got \(error)")
            }
        }
    }

    func testFileNotFoundFails() {
        let url = tempDir.appendingPathComponent("missing.json")
        XCTAssertThrowsError(try SleepScheduleContractReader(fileURL: url).read()) { error in
            XCTAssertEqual(error as? SleepScheduleContractError, .fileNotFound)
        }
    }

    func testReadsFixtureJSONDeadlineToLockGap() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/sleep_schedule_fixture.json")
        let contract = try SleepScheduleContractReader(fileURL: url).read()
        XCTAssertEqual(contract.targetBedtime, SleepClockTime(hour: 23, minute: 50))
        XCTAssertEqual(contract.lockBedtime, SleepClockTime(hour: 23, minute: 55))
    }
}

final class SleepReminderPlanTests: XCTestCase {
    private var calendar: Calendar!
    private var timeZone: TimeZone!

    override func setUp() {
        super.setUp()
        timeZone = TimeZone(secondsFromGMT: 0)!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        calendar = cal
    }

    func testPlansShowerOnlyOnTrainingDay() throws {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 6
        comps.day = 6
        comps.hour = 8
        comps.minute = 0
        let now = try XCTUnwrap(calendar.date(from: comps))

        let contract = SleepScheduleContract(
            schemaVersion: 1,
            targetBedtime: SleepClockTime(hour: 23, minute: 50),
            lockBedtime: SleepClockTime(hour: 23, minute: 55),
            dayType: .rest,
            updatedAt: "t"
        )
        let settings = SleepReminderUserSettings(
            remindersEnabled: true,
            lockScreenEnabled: true,
            showerReminderEnabled: true
        )
        let events = SleepReminderPlanBuilder.events(
            contract: contract,
            settings: settings,
            now: now,
            calendar: calendar
        )
        XCTAssertFalse(events.contains(where: { $0.kind == .shower }))
        XCTAssertTrue(events.contains(where: { $0.kind == .deadlineBell }))
        XCTAssertTrue(events.contains(where: { $0.kind == .lockScreen }))
    }

    func testDeadlineBellPrecedesLockByFiveMinutes() throws {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 6
        comps.day = 6
        comps.hour = 20
        comps.minute = 0
        let now = try XCTUnwrap(calendar.date(from: comps))

        let contract = SleepScheduleContract(
            schemaVersion: 1,
            targetBedtime: SleepClockTime(hour: 23, minute: 50),
            lockBedtime: SleepClockTime(hour: 23, minute: 55),
            dayType: .training,
            updatedAt: "fixture"
        )
        let settings = SleepReminderUserSettings(
            remindersEnabled: true,
            lockScreenEnabled: true,
            showerReminderEnabled: true
        )
        let events = SleepReminderPlanBuilder.events(
            contract: contract,
            settings: settings,
            now: now,
            calendar: calendar
        )
        let deadline = try XCTUnwrap(events.first(where: { $0.kind == .deadlineBell }))
        let lock = try XCTUnwrap(events.first(where: { $0.kind == .lockScreen }))
        XCTAssertEqual(lock.fireDate.timeIntervalSince(deadline.fireDate), 5 * 60, accuracy: 1)
    }

    func testMidnightTargetSchedulesNextOccurrence() throws {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 6
        comps.day = 6
        comps.hour = 8
        comps.minute = 0
        let now = try XCTUnwrap(calendar.date(from: comps))

        let contract = SleepScheduleContract(
            schemaVersion: 1,
            targetBedtime: SleepClockTime(hour: 0, minute: 0),
            lockBedtime: SleepClockTime(hour: 0, minute: 5),
            dayType: .training,
            updatedAt: "t"
        )
        let settings = SleepReminderUserSettings(
            remindersEnabled: true,
            lockScreenEnabled: true,
            showerReminderEnabled: true
        )
        let events = SleepReminderPlanBuilder.events(
            contract: contract,
            settings: settings,
            now: now,
            calendar: calendar
        )
        let deadline = try XCTUnwrap(events.first(where: { $0.kind == .deadlineBell }))
        var expected = DateComponents()
        expected.year = 2026
        expected.month = 6
        expected.day = 7
        expected.hour = 0
        expected.minute = 0
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day, .hour, .minute], from: deadline.fireDate), expected)
    }
}

final class SleepReminderScheduleSnapshotTests: XCTestCase {
    func testSnapshotMarksNextEvent() throws {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 6
        comps.day = 6
        comps.hour = 20
        comps.minute = 0
        let readAt = try XCTUnwrap(Calendar.current.date(from: comps))

        let contract = SleepScheduleContract(
            schemaVersion: 1,
            targetBedtime: SleepClockTime(hour: 23, minute: 0),
            lockBedtime: SleepClockTime(hour: 23, minute: 5),
            dayType: .training,
            updatedAt: "2026-06-06T08:00:00-04:00"
        )
        let items = [
            SleepReminderScheduledItem(
                event: SleepReminderEvent(fireDate: readAt.addingTimeInterval(3600), kind: .wrapUp, message: "a"),
                stableID: "wrap",
                state: .pending
            ),
            SleepReminderScheduledItem(
                event: SleepReminderEvent(fireDate: readAt.addingTimeInterval(7200), kind: .deadlineBell, message: "b"),
                stableID: "deadline",
                state: .pending
            ),
        ]

        let snapshot = SleepReminderScheduleSnapshotBuilder.make(
            contract: contract,
            items: items,
            lastReadAt: readAt
        )

        XCTAssertEqual(snapshot.plannedEvents.count, 2)
        XCTAssertTrue(snapshot.plannedEvents[0].isNext)
        XCTAssertFalse(snapshot.plannedEvents[1].isNext)
        XCTAssertEqual(snapshot.targetBedtimeLabel, "23:00")
    }
}

final class SleepReminderReconcilerTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    func testFiredEventSkippedOnRebuild() throws {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 6
        comps.day = 6
        comps.hour = 20
        comps.minute = 0
        let now = try XCTUnwrap(calendar.date(from: comps))

        let contract = SleepScheduleContract(
            schemaVersion: 1,
            targetBedtime: SleepClockTime(hour: 23, minute: 0),
            lockBedtime: SleepClockTime(hour: 23, minute: 5),
            dayType: .training,
            updatedAt: "u1"
        )
        let settings = SleepReminderUserSettings(
            remindersEnabled: true,
            lockScreenEnabled: true,
            showerReminderEnabled: true
        )
        let first = SleepReminderReconciler.buildSchedule(
            contract: contract,
            settings: settings,
            now: now,
            firedIDs: [],
            calendar: calendar
        )
        let washID = try XCTUnwrap(first.first(where: { $0.event.kind == .washUp })?.stableID)

        let second = SleepReminderReconciler.buildSchedule(
            contract: contract,
            settings: settings,
            now: now,
            firedIDs: [washID],
            calendar: calendar
        )
        XCTAssertEqual(second.first(where: { $0.stableID == washID })?.state, .fired)
    }

    func testCatchUpWithinGrace() throws {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 6
        comps.day = 6
        comps.hour = 23
        comps.minute = 30
        comps.second = 30
        let now = try XCTUnwrap(calendar.date(from: comps))

        let contract = SleepScheduleContract(
            schemaVersion: 1,
            targetBedtime: SleepClockTime(hour: 0, minute: 0),
            lockBedtime: SleepClockTime(hour: 0, minute: 5),
            dayType: .rest,
            updatedAt: "u1"
        )
        let settings = SleepReminderUserSettings(
            remindersEnabled: true,
            lockScreenEnabled: true,
            showerReminderEnabled: true
        )
        let items = SleepReminderReconciler.buildSchedule(
            contract: contract,
            settings: settings,
            now: now,
            firedIDs: [],
            grace: 90,
            calendar: calendar
        )
        let wash = items.first(where: { $0.event.kind == .washUp })
        XCTAssertEqual(wash?.state, .catchUpNow)
    }

    func testStableEventIDUsesContractUpdatedAt() {
        let event = SleepReminderEvent(
            fireDate: Date(timeIntervalSince1970: 1_000),
            kind: .washUp,
            message: "m"
        )
        let a = SleepReminderReconciler.stableEventID(contractUpdatedAt: "a", event: event)
        let b = SleepReminderReconciler.stableEventID(contractUpdatedAt: "b", event: event)
        XCTAssertNotEqual(a, b)
    }
}

final class SleepReminderFiredStoreTests: XCTestCase {
    func testPersistsPerContractUpdatedAt() {
        let suite = "SleepReminderFiredStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = SleepReminderFiredStore(defaults: defaults)
        store.save(firedIDs: ["e1"], contractUpdatedAt: "v1")
        XCTAssertEqual(store.loadFiredIDs(for: "v1"), ["e1"])
        XCTAssertTrue(store.loadFiredIDs(for: "v2").isEmpty)
    }
}
