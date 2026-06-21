import XCTest
@testable import MalDaze

@MainActor
final class FocusSessionStoreTests: XCTestCase {
    private var fileURL: URL!
    private var calendar: Calendar!

    override func setUp() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusSessionStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("focus-sessions.json")
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    override func tearDown() async throws {
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }
    }

    private func makeStore() -> FocusSessionStore {
        FocusSessionStore(fileURL: fileURL)
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        ))!
    }

    func testBootstrapCreatesEmptyFileOnFirstAppend() throws {
        let store = makeStore()
        let started = date(year: 2026, month: 6, day: 20, hour: 14, minute: 0)
        let ended = date(year: 2026, month: 6, day: 20, hour: 14, minute: 25)
        let session = try store.appendFinalized(startedAt: started, endedAt: ended, source: .completed, calendar: calendar)

        XCTAssertEqual(session.durationSeconds, 25 * 60)
        XCTAssertEqual(session.durationMinutes, 25)
        XCTAssertEqual(session.source, .completed)
        XCTAssertEqual(session.date, "2026-06-20")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testAppendPreservesOlderSessionsWithoutPurge() throws {
        let store = makeStore()
        let oldStarted = date(year: 2026, month: 6, day: 18, hour: 10, minute: 0)
        let oldEnded = date(year: 2026, month: 6, day: 18, hour: 10, minute: 25)
        _ = try store.appendFinalized(startedAt: oldStarted, endedAt: oldEnded, source: .completed, calendar: calendar)

        let newStarted = date(year: 2026, month: 6, day: 20, hour: 14, minute: 0)
        let newEnded = date(year: 2026, month: 6, day: 20, hour: 14, minute: 15)
        _ = try store.appendFinalized(
            startedAt: newStarted,
            endedAt: newEnded,
            source: .stoppedEarly,
            calendar: calendar
        )

        let reloaded = makeStore()
        reloaded.loadIfNeeded()
        XCTAssertEqual(reloaded.allSessions.count, 2)
        XCTAssertEqual(reloaded.allSessions.map(\.date).sorted(), ["2026-06-18", "2026-06-20"])
    }

    func testTodaySessionsFilterAndSort() throws {
        let store = makeStore()
        let today = date(year: 2026, month: 6, day: 20, hour: 12, minute: 0)
        let earlier = date(year: 2026, month: 6, day: 20, hour: 9, minute: 0)
        let later = date(year: 2026, month: 6, day: 20, hour: 15, minute: 0)
        let yesterday = date(year: 2026, month: 6, day: 19, hour: 15, minute: 0)

        _ = try store.appendFinalized(
            startedAt: earlier,
            endedAt: earlier.addingTimeInterval(25 * 60),
            source: .completed,
            calendar: calendar
        )
        _ = try store.appendFinalized(
            startedAt: later,
            endedAt: later.addingTimeInterval(25 * 60),
            source: .completed,
            calendar: calendar
        )
        _ = try store.appendFinalized(
            startedAt: yesterday,
            endedAt: yesterday.addingTimeInterval(25 * 60),
            source: .completed,
            calendar: calendar
        )

        let todaySessions = store.todaySessions(calendar: calendar, now: today)
        XCTAssertEqual(todaySessions.count, 2)
        XCTAssertEqual(todaySessions[0].startedAt, later)
        XCTAssertEqual(todaySessions[1].startedAt, earlier)
        XCTAssertEqual(store.todayFinalizedMinutes(calendar: calendar, now: today), 50)
        XCTAssertEqual(store.todaySessionCount(calendar: calendar, now: today), 2)
        XCTAssertEqual(store.todayPomodoroCount(calendar: calendar, now: today), 2)
    }

    func testEarlyStopDurationUsesActualElapsedMinutes() throws {
        let store = makeStore()
        let started = date(year: 2026, month: 6, day: 20, hour: 14, minute: 0)
        let ended = date(year: 2026, month: 6, day: 20, hour: 14, minute: 15)
        let session = try store.appendFinalized(
            startedAt: started,
            endedAt: ended,
            source: .stoppedEarly,
            calendar: calendar
        )
        XCTAssertEqual(session.durationSeconds, 15 * 60)
        XCTAssertEqual(session.durationMinutes, 15)
        XCTAssertEqual(session.source, .stoppedEarly)
    }

    func testSubMinuteSessionStoresSecondsWithoutInflatingMinutes() throws {
        let store = makeStore()
        let started = date(year: 2026, month: 6, day: 20, hour: 15, minute: 25, second: 10)
        let ended = date(year: 2026, month: 6, day: 20, hour: 15, minute: 25, second: 13)
        let session = try store.appendFinalized(
            startedAt: started,
            endedAt: ended,
            source: .stoppedEarly,
            calendar: calendar
        )
        XCTAssertEqual(session.durationSeconds, 3)
        XCTAssertEqual(session.durationMinutes, 0)
    }

    func testRapidSessionsAggregateSecondsNotInflatedMinutes() throws {
        let store = makeStore()
        let base = date(year: 2026, month: 6, day: 20, hour: 15, minute: 25, second: 0)
        for offset in 0..<10 {
            let started = base.addingTimeInterval(TimeInterval(offset * 2))
            let ended = started.addingTimeInterval(3)
            _ = try store.appendFinalized(
                startedAt: started,
                endedAt: ended,
                source: .stoppedEarly,
                calendar: calendar
            )
        }
        let today = date(year: 2026, month: 6, day: 20, hour: 15, minute: 30)
        XCTAssertEqual(store.todaySessionCount(calendar: calendar, now: today), 10)
        XCTAssertEqual(store.todayPomodoroCount(calendar: calendar, now: today), 0)
        XCTAssertEqual(store.todayFinalizedSeconds(calendar: calendar, now: today), 30)
        XCTAssertEqual(store.todayFinalizedMinutes(calendar: calendar, now: today), 0)
    }

    func testOnlyCompletedSessionsCountAsPomodoros() throws {
        let store = makeStore()
        let today = date(year: 2026, month: 6, day: 20, hour: 16, minute: 0)
        let completedStart = date(year: 2026, month: 6, day: 20, hour: 9, minute: 0)
        _ = try store.appendFinalized(
            startedAt: completedStart,
            endedAt: completedStart.addingTimeInterval(25 * 60),
            source: .completed,
            calendar: calendar
        )
        let earlyStart = date(year: 2026, month: 6, day: 20, hour: 10, minute: 0)
        _ = try store.appendFinalized(
            startedAt: earlyStart,
            endedAt: earlyStart.addingTimeInterval(5 * 60),
            source: .stoppedEarly,
            calendar: calendar
        )

        XCTAssertEqual(store.todaySessionCount(calendar: calendar, now: today), 2)
        XCTAssertEqual(store.todayPomodoroCount(calendar: calendar, now: today), 1)
        XCTAssertEqual(store.todayFinalizedMinutes(calendar: calendar, now: today), 30)
        XCTAssertEqual(store.todayCompletedMinutes(calendar: calendar, now: today), 25)
    }

    func testTodayCompletedMinutesExcludesStoppedEarly() throws {
        let store = makeStore()
        let today = date(year: 2026, month: 6, day: 20, hour: 16, minute: 0)
        let completedStart = date(year: 2026, month: 6, day: 20, hour: 9, minute: 0)
        _ = try store.appendFinalized(
            startedAt: completedStart,
            endedAt: completedStart.addingTimeInterval(25 * 60),
            source: .completed,
            calendar: calendar
        )
        let earlyStart = date(year: 2026, month: 6, day: 20, hour: 10, minute: 0)
        _ = try store.appendFinalized(
            startedAt: earlyStart,
            endedAt: earlyStart.addingTimeInterval(15 * 60),
            source: .stoppedEarly,
            calendar: calendar
        )

        XCTAssertEqual(store.todayCompletedMinutes(calendar: calendar, now: today), 25)
        XCTAssertEqual(store.todayPomodoroCount(calendar: calendar, now: today), 1)
    }

    func testZeroDurationSessionIsRejected() {
        let store = makeStore()
        let instant = date(year: 2026, month: 6, day: 20, hour: 15, minute: 25)
        XCTAssertThrowsError(
            try store.appendFinalized(
                startedAt: instant,
                endedAt: instant,
                source: .stoppedEarly,
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(error as? FocusSessionStoreError, .writeFailed)
        }
    }

    func testUpdateSessionRewritesStartedAndEndedAt() throws {
        let store = makeStore()
        let started = date(year: 2026, month: 6, day: 20, hour: 14, minute: 0)
        let ended = date(year: 2026, month: 6, day: 20, hour: 14, minute: 25)
        let session = try store.appendFinalized(
            startedAt: started,
            endedAt: ended,
            source: .completed,
            calendar: calendar
        )

        let newStarted = date(year: 2026, month: 6, day: 20, hour: 15, minute: 0)
        let newEnded = date(year: 2026, month: 6, day: 20, hour: 15, minute: 18)
        let updated = try store.updateSession(
            id: session.id,
            startedAt: newStarted,
            endedAt: newEnded,
            calendar: calendar
        )

        XCTAssertEqual(updated.startedAt, newStarted)
        XCTAssertEqual(updated.endedAt, newEnded)
        XCTAssertEqual(updated.durationSeconds, 18 * 60)
        XCTAssertEqual(store.allSessions.count, 1)
    }

    func testDeleteSessionRemovesRecord() throws {
        let store = makeStore()
        let started = date(year: 2026, month: 6, day: 20, hour: 14, minute: 0)
        let ended = date(year: 2026, month: 6, day: 20, hour: 14, minute: 25)
        let session = try store.appendFinalized(
            startedAt: started,
            endedAt: ended,
            source: .completed,
            calendar: calendar
        )

        try store.deleteSession(id: session.id)

        XCTAssertTrue(store.allSessions.isEmpty)
        XCTAssertThrowsError(try store.deleteSession(id: session.id)) { error in
            XCTAssertEqual(error as? FocusSessionStoreError, .notFound)
        }
    }

    func testLegacyMinuteOnlyRecordsDecodeToSeconds() throws {
        let legacyJSON = """
        {
          "schemaVersion": 1,
          "sessions": [
            {
              "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
              "date": "2026-06-20",
              "startedAt": "2026-06-20T14:00:00Z",
              "endedAt": "2026-06-20T14:25:00Z",
              "durationMinutes": 25,
              "source": "completed",
              "labels": []
            }
          ]
        }
        """.data(using: .utf8)!
        try legacyJSON.write(to: fileURL)
        let store = makeStore()
        store.loadIfNeeded()
        XCTAssertEqual(store.allSessions.count, 1)
        XCTAssertEqual(store.allSessions[0].durationSeconds, 25 * 60)
        XCTAssertEqual(store.allSessions[0].durationMinutes, 25)
    }
}
