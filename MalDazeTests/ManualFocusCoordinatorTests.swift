import XCTest
@testable import MalDaze

@MainActor
final class ManualFocusCoordinatorTests: XCTestCase {
    private var fileURL: URL!
    private var calendar: Calendar!

    override func setUp() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ManualFocusCoordinatorTests-\(UUID().uuidString)", isDirectory: true)
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

    private func makeCoordinator() -> ManualFocusCoordinator {
        let store = FocusSessionStore(fileURL: fileURL)
        store.loadIfNeeded()
        return ManualFocusCoordinator(store: store)
    }

    private func date(hour: Int, minute: Int, second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 20, hour: hour, minute: minute, second: second))!
    }

    func testWorkStartedDoesNotAppendSession() {
        let coordinator = makeCoordinator()
        let start = date(hour: 14, minute: 0)
        let end = start.addingTimeInterval(25 * 60)
        coordinator.handle(.workStarted(start: start, end: end), calendar: calendar)

        let store = FocusSessionStore(fileURL: fileURL)
        store.loadIfNeeded()
        XCTAssertTrue(store.allSessions.isEmpty)
    }

    func testWorkCompletedAppendsCompletedSession() throws {
        let coordinator = makeCoordinator()
        let start = date(hour: 14, minute: 0)
        let end = date(hour: 14, minute: 25)
        coordinator.handle(.workStarted(start: start, end: end), calendar: calendar)
        coordinator.handle(.workCompleted(start: start, end: end), calendar: calendar)

        let store = FocusSessionStore(fileURL: fileURL)
        store.loadIfNeeded()
        XCTAssertEqual(store.allSessions.count, 1)
        XCTAssertEqual(store.allSessions[0].source, .completed)
        XCTAssertEqual(store.allSessions[0].durationSeconds, 25 * 60)
    }

    func testAbandonCurrentWorkPhaseAppendsStoppedEarly() throws {
        let coordinator = makeCoordinator()
        let manual = ManualTimerEngine(workDuration: 25 * 60, restDuration: 5 * 60)
        let start = date(hour: 14, minute: 0)
        let end = start.addingTimeInterval(25 * 60)
        coordinator.handle(.workStarted(start: start, end: end), calendar: calendar)

        let abandonAt = date(hour: 14, minute: 10)
        coordinator.abandonCurrentWorkPhase(now: abandonAt, manualEngine: manual, calendar: calendar)

        let store = FocusSessionStore(fileURL: fileURL)
        store.loadIfNeeded()
        XCTAssertEqual(store.allSessions.count, 1)
        XCTAssertEqual(store.allSessions[0].source, .stoppedEarly)
        XCTAssertEqual(store.allSessions[0].durationSeconds, 10 * 60)
    }

    func testRestStartedClearsInProgressProjection() throws {
        let coordinator = makeCoordinator()
        let manual = ManualTimerEngine(workDuration: 25 * 60, restDuration: 5 * 60)
        manual.start()

        let start = try XCTUnwrap(manual.currentWorkPhase?.startedAt)
        let end = try XCTUnwrap(manual.currentWorkPhase?.endsAt)
        coordinator.handle(.workStarted(start: start, end: end), calendar: calendar)

        let now = start.addingTimeInterval(60)
        XCTAssertNotNil(
            coordinator.inProgressProjection(now: now, manualEngine: manual, isManualSessionActive: true)
        )

        manual.testing_enterRestPhase(remaining: 5 * 60)
        coordinator.handle(.workCompleted(start: start, end: end), calendar: calendar)
        coordinator.handle(.restStarted(end: Date().addingTimeInterval(5 * 60)), calendar: calendar)
        XCTAssertNil(
            coordinator.inProgressProjection(now: now, manualEngine: manual, isManualSessionActive: true)
        )
    }

    func testInProgressProjectionCapsElapsedAtEndsAt() throws {
        let coordinator = makeCoordinator()
        let manual = ManualTimerEngine(workDuration: 25 * 60, restDuration: 5 * 60)
        manual.start()

        let phase = try XCTUnwrap(manual.currentWorkPhase)
        coordinator.handle(.workStarted(start: phase.startedAt, end: phase.endsAt), calendar: calendar)

        let afterEnd = phase.endsAt.addingTimeInterval(120)
        let projection = coordinator.inProgressProjection(
            now: afterEnd,
            manualEngine: manual,
            isManualSessionActive: true
        )
        XCTAssertEqual(projection?.elapsedSeconds, 25 * 60)
        XCTAssertEqual(projection?.remainingSeconds, 0)
    }
}
