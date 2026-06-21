import XCTest
@testable import MalDaze

@MainActor
final class ManualTimerEnginePhaseReplayTests: XCTestCase {
    func testRestorePersistedPhaseReplaysCompletedWorkBeforeNow() {
        let workDuration: TimeInterval = 600
        let restDuration: TimeInterval = 120
        let manual = ManualTimerEngine(workDuration: workDuration, restDuration: restDuration)
        var events: [ManualPhaseEvent] = []
        manual.onPhaseEvent = { events.append($0) }

        let now = Date()
        let staleWorkEnd = now.addingTimeInterval(-30)
        manual.restorePersistedPhase(end: staleWorkEnd, isRestPhase: false, now: now)

        XCTAssertTrue(events.contains {
            if case .workCompleted = $0 { return true }
            return false
        })
        XCTAssertTrue(events.contains {
            if case .restStarted = $0 { return true }
            return false
        })
        XCTAssertTrue(manual.isInRestPhase)
        XCTAssertTrue(manual.isTimerRunning)
    }

    func testSkipRestPhaseToWorkEmitsRestEndedAndWorkStarted() {
        let manual = ManualTimerEngine(workDuration: 600, restDuration: 120)
        manual.start()
        manual.testing_enterRestPhase(remaining: 90)

        var events: [ManualPhaseEvent] = []
        manual.onPhaseEvent = { events.append($0) }
        manual.skipRestPhaseToWork()

        XCTAssertTrue(events.contains {
            if case .restEnded = $0 { return true }
            return false
        })
        XCTAssertTrue(events.contains {
            if case .workStarted = $0 { return true }
            return false
        })
        XCTAssertFalse(manual.isInRestPhase)
        XCTAssertNotNil(manual.currentWorkPhase)
    }

    func testSkipRestPhaseToWorkStartsNextWorkAtNow() {
        let manual = ManualTimerEngine(workDuration: 600, restDuration: 120)
        manual.start()
        manual.testing_enterRestPhase(remaining: 90)

        let beforeSkip = Date()
        manual.skipRestPhaseToWork()
        let afterSkip = Date()

        guard let phase = manual.currentWorkPhase else {
            XCTFail("Expected active work phase after skip-rest")
            return
        }
        XCTAssertGreaterThanOrEqual(phase.startedAt, beforeSkip.addingTimeInterval(-0.05))
        XCTAssertLessThanOrEqual(phase.startedAt, afterSkip.addingTimeInterval(0.05))
        XCTAssertGreaterThan(phase.endsAt, phase.startedAt)
    }

    func testReconcileThroughMultiplePhasesEmitsOrderedTransitions() {
        let workDuration: TimeInterval = 60
        let restDuration: TimeInterval = 30
        let manual = ManualTimerEngine(workDuration: workDuration, restDuration: restDuration)
        var events: [ManualPhaseEvent] = []
        manual.onPhaseEvent = { events.append($0) }

        let now = Date()
        let veryStaleEnd = now.addingTimeInterval(-(workDuration + restDuration + 10))
        manual.restorePersistedPhase(end: veryStaleEnd, isRestPhase: false, now: now)

        let completedCount = events.filter {
            if case .workCompleted = $0 { return true }
            return false
        }.count
        XCTAssertGreaterThanOrEqual(completedCount, 2)
        XCTAssertTrue(manual.isTimerRunning)
    }
}
