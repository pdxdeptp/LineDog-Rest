import XCTest
@testable import MalDaze

@MainActor
final class ChronoSessionCoordinatorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ChronoSessionStore.clear()
        UserDefaults.standard.removeObject(forKey: MalDazeDefaults.suspendedTimerModeSnapshot)
    }

    override func tearDown() {
        ChronoSessionStore.clear()
        UserDefaults.standard.removeObject(forKey: MalDazeDefaults.suspendedTimerModeSnapshot)
        super.tearDown()
    }

    func testCaptureRunningManualRecordIncludesPhaseEnd() throws {
        let manual = ManualTimerEngine(workDuration: 600, restDuration: 120)
        manual.start()
        let context = ChronoSessionCaptureContext(
            mode: .manual,
            manualEngine: manual,
            autoEngine: AutoTimerEngine(restDuration: 60)
        )
        let record = try XCTUnwrap(ChronoSessionCoordinator().capture(from: context))

        XCTAssertEqual(record.mode, .manual)
        XCTAssertEqual(record.phase, .manualWorking)
        XCTAssertGreaterThan(record.phaseEnd.timeIntervalSinceNow, 500)
    }

    func testRunningRecordBootstrapPlanRestoresImmediately() {
        let phaseEnd = Date().addingTimeInterval(500)
        let record = ChronoSessionRecord(
            mode: .manual,
            phase: .manualWorking,
            phaseEnd: phaseEnd
        )
        let plan = ChronoSessionCoordinator().planBootstrap(
            stored: .record(record),
            preferredMode: .auto
        )
        XCTAssertEqual(plan, .restoreRunning(record))
    }

    func testLegacyModeOnlyTokenIsClearedOnLoad() {
        UserDefaults.standard.set("manual", forKey: MalDazeDefaults.suspendedTimerModeSnapshot)

        let stored = ChronoSessionStore.loadState()
        XCTAssertEqual(stored, .none)
        XCTAssertNil(UserDefaults.standard.object(forKey: MalDazeDefaults.suspendedTimerModeSnapshot))
    }

    func testLegacyUserPausedV2EnvelopeClearsOnLoad() throws {
        struct V2Record: Codable {
            let mode: String
            let phase: String
            let phaseEnd: Date
            let pauseKind: String
        }
        struct V2Envelope: Codable {
            let schemaVersion: Int
            let record: V2Record
        }
        let envelope = V2Envelope(
            schemaVersion: 2,
            record: V2Record(
                mode: "manual",
                phase: "manualWorking",
                phaseEnd: Date().addingTimeInterval(300),
                pauseKind: "user"
            )
        )
        let data = try JSONEncoder().encode(envelope)
        UserDefaults.standard.set(data, forKey: MalDazeDefaults.chronoSessionSnapshot)

        XCTAssertEqual(ChronoSessionStore.loadState(), .none)
        XCTAssertNil(UserDefaults.standard.data(forKey: MalDazeDefaults.chronoSessionSnapshot))
    }

    func testRestoreEnginesUsesWallClockRemaining() {
        let phaseEnd = Date().addingTimeInterval(240)
        let record = ChronoSessionRecord(
            mode: .manual,
            phase: .manualWorking,
            phaseEnd: phaseEnd
        )
        let manual = ManualTimerEngine(workDuration: 600, restDuration: 120)
        ChronoSessionCoordinator().applyEngines(
            record: record,
            manualEngine: manual,
            autoEngine: AutoTimerEngine(restDuration: 60)
        )

        XCTAssertTrue(manual.isTimerRunning)
        XCTAssertGreaterThan(manual.workPhaseRemainingOrZero, 200)
        XCTAssertNotNil(manual.currentWorkPhase)
    }

    func testStopAutoRemindersIntegrationClearsChronoRecord() {
        let vm = AppViewModel(windowManager: MockWindowManager(), bootstrapAutoEngine: true)
        vm.stopAutoReminders()

        XCTAssertEqual(ChronoSessionStore.loadState(), .none)
        XCTAssertFalse(vm.canStopAutoReminders)
    }
}
