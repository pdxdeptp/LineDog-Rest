import XCTest
@testable import MalDaze

@MainActor
final class ChronoSessionCoordinatorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ChronoSessionStore.clear()
    }

    override func tearDown() {
        ChronoSessionStore.clear()
        super.tearDown()
    }

    func testCaptureRunningManualRecordIncludesPhaseEnd() throws {
        let manual = ManualTimerEngine(workDuration: 600, restDuration: 120)
        manual.start()
        let startedAt = Date().addingTimeInterval(-30)
        let context = ChronoSessionCaptureContext(
            mode: .manual,
            manualEngine: manual,
            autoEngine: AutoTimerEngine(restDuration: 60),
            workSegmentStartedAt: startedAt,
            wasInManualWorkPhase: true
        )
        let record = try XCTUnwrap(
            ChronoSessionCoordinator().capture(from: context, pauseKind: .none)
        )

        XCTAssertEqual(record.mode, .manual)
        XCTAssertEqual(record.phase, .manualWorking)
        XCTAssertEqual(record.pauseKind, .none)
        XCTAssertGreaterThan(record.phaseEnd.timeIntervalSinceNow, 500)
        XCTAssertEqual(record.workSegmentStartedAt, startedAt)
    }

    func testPersistUserPausedWritesEnvelopeBeforeEngineStop() throws {
        var coordinator = ChronoSessionCoordinator()
        let manual = ManualTimerEngine(workDuration: 600, restDuration: 120)
        manual.start()
        let endBeforeStop = try XCTUnwrap(manual.currentPhaseEnd)
        let context = ChronoSessionCaptureContext(
            mode: .manual,
            manualEngine: manual,
            autoEngine: AutoTimerEngine(restDuration: 60),
            workSegmentStartedAt: Date().addingTimeInterval(-120),
            wasInManualWorkPhase: true
        )

        coordinator.persistUserPaused(from: context)
        manual.stop()

        guard case .record(let stored) = ChronoSessionStore.loadState() else {
            return XCTFail("Expected stored chrono record")
        }
        XCTAssertEqual(stored.pauseKind, .user)
        XCTAssertEqual(stored.phase, .manualWorking)
        XCTAssertEqual(stored.phaseEnd.timeIntervalSince1970, endBeforeStop.timeIntervalSince1970, accuracy: 1)
    }

    func testRunningRecordBootstrapPlanRestoresImmediately() {
        let phaseEnd = Date().addingTimeInterval(500)
        let record = ChronoSessionRecord(
            mode: .manual,
            phase: .manualWorking,
            phaseEnd: phaseEnd,
            pauseKind: .none,
            workSegmentStartedAt: Date().addingTimeInterval(-100)
        )
        let plan = ChronoSessionCoordinator().planBootstrap(
            stored: .record(record),
            preferredMode: .auto
        )
        XCTAssertEqual(plan, .restoreRunning(record))
    }

    func testLegacyModeOnlyTokenMapsToUserPausedModeOnlyPlan() {
        UserDefaults.standard.set("manual", forKey: MalDazeDefaults.suspendedTimerModeSnapshot)
        let plan = ChronoSessionCoordinator().planBootstrap(
            stored: ChronoSessionStore.loadState(),
            preferredMode: .auto
        )
        XCTAssertEqual(plan, .restoreUserPausedModeOnly(ChronoSessionModeOnlyPause(mode: .manual)))
    }

    func testRestoreEnginesUsesWallClockRemaining() {
        let phaseEnd = Date().addingTimeInterval(240)
        let record = ChronoSessionRecord(
            mode: .manual,
            phase: .manualWorking,
            phaseEnd: phaseEnd,
            pauseKind: .user,
            workSegmentStartedAt: Date().addingTimeInterval(-360)
        )
        let manual = ManualTimerEngine(workDuration: 600, restDuration: 120)
        let hints = ChronoSessionCoordinator().applyEngines(
            record: record,
            manualEngine: manual,
            autoEngine: AutoTimerEngine(restDuration: 60)
        )

        XCTAssertTrue(manual.isTimerRunning)
        XCTAssertGreaterThan(manual.workPhaseRemainingOrZero, 200)
        XCTAssertNotNil(hints.workSegmentStartedAt)
    }

    func testStopTimersIntegrationPersistsResumableRecord() {
        let vm = AppViewModel(windowManager: MockWindowManager(), bootstrapAutoEngine: false)
        vm.setMode(.manual)
        vm.startManualFocus()
        vm.stopTimers()

        guard case .record(let stored) = ChronoSessionStore.loadState() else {
            return XCTFail("Expected chrono record after stopTimers")
        }
        XCTAssertEqual(stored.mode, .manual)
        XCTAssertEqual(stored.pauseKind, .user)
        XCTAssertEqual(stored.phase, .manualWorking)
    }
}
