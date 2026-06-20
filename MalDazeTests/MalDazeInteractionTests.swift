import AppKit
import XCTest
@testable import MalDaze

/// 覆盖「开始专注 / 停止计时 / 切模式 / 测试休息 / 引擎休息」的组合，防止状态与霸屏回调不同步。
@MainActor
final class MalDazeInteractionTests: XCTestCase {
    private static let suspendedTimerModeSnapshotKey = MalDazeDefaults.suspendedTimerModeSnapshot
    private static let preferredTimerModeKey = MalDazeDefaults.preferredTimerMode
    private static let autoSuspendedTimerModeToken = "auto"
    private static let manualSuspendedTimerModeToken = "manual"

    override func setUp() {
        super.setUp()
        Self.clearTimerModeDefaults()
    }

    override func tearDown() {
        Self.clearTimerModeDefaults()
        super.tearDown()
    }

    /// `ManualTimerEngine` / `AutoTimerEngine` 通过 `Task { @MainActor }` 投递到 ViewModel；单测需让出一次运行循环再断言。
    private func yieldForMainActorEngineDelivery() {
        let e = expectation(description: "mainActor engine delivery")
        Task { @MainActor in e.fulfill() }
        wait(for: [e], timeout: 2.0)
    }

    private func backingTimer(from engine: AutoTimerEngine) throws -> Timer {
        let child = try XCTUnwrap(
            Mirror(reflecting: engine).children.first { $0.label == "tickTimer" },
            "AutoTimerEngine should keep its scheduled Timer in tickTimer"
        )
        return try XCTUnwrap(Self.optionalTimer(from: child.value))
    }

    private static func optionalTimer(from value: Any) -> Timer? {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            return mirror.children.first?.value as? Timer
        }
        return value as? Timer
    }

    private func localDate(
        year: Int = 2026,
        month: Int = 3,
        day: Int = 19,
        hour: Int,
        minute: Int,
        second: Int = 0
    ) -> Date {
        Calendar.current.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        ))!
    }

    private nonisolated static func clearTimerModeDefaults() {
        ChronoSessionStore.clear()
        UserDefaults.standard.removeObject(forKey: MalDazeDefaults.preferredTimerMode)
    }

    private nonisolated static func clearSuspendedTimerModeSnapshot() {
        UserDefaults.standard.removeObject(forKey: MalDazeDefaults.suspendedTimerModeSnapshot)
    }

    // MARK: - 模式与计时开关

    func testDefaultBootstrapAuto_isChronoActive_blackPet() {
        let mock = MockWindowManager()
        let vm = AppViewModel(windowManager: mock, bootstrapAutoEngine: true)
        XCTAssertEqual(vm.mode, .auto)
        XCTAssertEqual(vm.petDisplayMode, .runningBlack)
        XCTAssertTrue(mock.idleModesApplied.contains(.runningBlack))
    }

    func testPreferredManualModeRestoredOnColdStartWithoutStartingAutoEngine() {
        UserDefaults.standard.set(Self.manualSuspendedTimerModeToken, forKey: Self.preferredTimerModeKey)

        let autoEngine = AutoTimerEngine(restDuration: 60)
        let mock = MockWindowManager()
        let vm = AppViewModel(
            windowManager: mock,
            autoEngine: autoEngine,
            bootstrapAutoEngine: true
        )

        XCTAssertEqual(vm.mode, .manual)
        XCTAssertFalse(autoEngine.isTimerRunning)
        XCTAssertFalse(vm.canStopChronoButton)
        XCTAssertFalse(vm.showResumeChronoButton)
        XCTAssertEqual(vm.petDisplayMode, .pausedWhiteOutline)
        XCTAssertTrue(vm.statusLine.contains("手动模式"))
    }

    func testSetModePersistsPreferredTimerMode() {
        let vm = AppViewModel(windowManager: MockWindowManager(), bootstrapAutoEngine: false)
        vm.setMode(.manual)
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: Self.preferredTimerModeKey),
            Self.manualSuspendedTimerModeToken
        )

        vm.setMode(.auto)
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: Self.preferredTimerModeKey),
            Self.autoSuspendedTimerModeToken
        )
    }

    func testRunningManualFocusSnapshotRestoresRemainingCountdownOnLaunch() {
        let phaseEnd = Date().addingTimeInterval(400)
        let startedAt = Date().addingTimeInterval(-200)
        ChronoSessionStore.save(
            ChronoSessionRecord(
                mode: .manual,
                phase: .manualWorking,
                phaseEnd: phaseEnd,
                pauseKind: .none,
                workSegmentStartedAt: startedAt
            )
        )

        let manual = ManualTimerEngine(workDuration: 600, restDuration: 120)
        let vm = AppViewModel(
            windowManager: MockWindowManager(),
            manualEngine: manual,
            bootstrapAutoEngine: true
        )

        XCTAssertEqual(vm.mode, .manual)
        XCTAssertTrue(vm.canStopChronoButton)
        XCTAssertFalse(vm.showResumeChronoButton)
        XCTAssertGreaterThan(manual.workPhaseRemainingOrZero, 350)
        XCTAssertNotNil(vm.inProgressFocusSegment)
    }

    func testSuspendedManualSnapshotWithPhaseResumesRemainingCountdown() {
        let phaseEnd = Date().addingTimeInterval(300)
        ChronoSessionStore.save(
            ChronoSessionRecord(
                mode: .manual,
                phase: .manualWorking,
                phaseEnd: phaseEnd,
                pauseKind: .user,
                workSegmentStartedAt: Date().addingTimeInterval(-300)
            )
        )

        let manual = ManualTimerEngine(workDuration: 600, restDuration: 120)
        let vm = AppViewModel(
            windowManager: MockWindowManager(),
            manualEngine: manual,
            bootstrapAutoEngine: true
        )
        XCTAssertTrue(vm.showResumeChronoButton)
        XCTAssertFalse(manual.isTimerRunning)

        vm.resumeTimers()

        XCTAssertTrue(manual.isTimerRunning)
        XCTAssertTrue(vm.canStopChronoButton)
        XCTAssertFalse(vm.showResumeChronoButton)
        XCTAssertGreaterThan(manual.workPhaseRemainingOrZero, 250)
    }

    func testBootstrapDisabled_startsPausedUntilSetModeAuto() {
        let mock = MockWindowManager()
        _ = AppViewModel(windowManager: mock, bootstrapAutoEngine: false)
        XCTAssertEqual(mock.idleModesApplied.last, .pausedWhiteOutline)

        let vm2 = AppViewModel(windowManager: mock, bootstrapAutoEngine: false)
        vm2.setMode(.auto)
        XCTAssertEqual(vm2.petDisplayMode, .runningBlack)
    }

    func testStoppedAutoSnapshotRestoresPausedBootstrapWithoutStartingTimer() {
        Self.clearSuspendedTimerModeSnapshot()
        defer { Self.clearSuspendedTimerModeSnapshot() }

        let runningVM = AppViewModel(windowManager: MockWindowManager(), bootstrapAutoEngine: true)
        runningVM.stopTimers()

        XCTAssertEqual(
            UserDefaults.standard.string(forKey: Self.suspendedTimerModeSnapshotKey),
            Self.autoSuspendedTimerModeToken
        )

        let restoredAutoEngine = AutoTimerEngine(restDuration: 60)
        let restoredMock = MockWindowManager()
        let restoredVM = AppViewModel(
            windowManager: restoredMock,
            autoEngine: restoredAutoEngine,
            bootstrapAutoEngine: true
        )

        XCTAssertEqual(restoredVM.mode, .auto)
        XCTAssertFalse(restoredAutoEngine.isTimerRunning)
        XCTAssertFalse(restoredVM.canStopChronoButton)
        XCTAssertTrue(restoredVM.showResumeChronoButton)
        XCTAssertEqual(restoredVM.petDisplayMode, .pausedWhiteOutline)
        XCTAssertEqual(restoredMock.idleModesApplied.last, .pausedWhiteOutline)
    }

    func testStopTimersPersistsStableModeTokens() {
        Self.clearSuspendedTimerModeSnapshot()
        defer { Self.clearSuspendedTimerModeSnapshot() }

        let autoVM = AppViewModel(windowManager: MockWindowManager(), bootstrapAutoEngine: true)
        autoVM.stopTimers()
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: Self.suspendedTimerModeSnapshotKey),
            Self.autoSuspendedTimerModeToken
        )

        Self.clearSuspendedTimerModeSnapshot()
        let manualVM = AppViewModel(windowManager: MockWindowManager(), bootstrapAutoEngine: false)
        manualVM.setMode(.manual)
        manualVM.startManualFocus()
        manualVM.stopTimers()
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: Self.suspendedTimerModeSnapshotKey),
            Self.manualSuspendedTimerModeToken
        )
    }

    func testRestoredAutoSnapshotResumeClearsDefaultsAndRestartsAutoEngine() {
        Self.clearSuspendedTimerModeSnapshot()
        defer { Self.clearSuspendedTimerModeSnapshot() }
        UserDefaults.standard.set(Self.autoSuspendedTimerModeToken, forKey: Self.suspendedTimerModeSnapshotKey)

        let autoEngine = AutoTimerEngine(restDuration: 60)
        let vm = AppViewModel(
            windowManager: MockWindowManager(),
            autoEngine: autoEngine,
            bootstrapAutoEngine: true
        )
        XCTAssertFalse(autoEngine.isTimerRunning)
        XCTAssertTrue(vm.showResumeChronoButton)

        vm.resumeTimers()

        XCTAssertTrue(autoEngine.isTimerRunning)
        XCTAssertTrue(vm.canStopChronoButton)
        XCTAssertFalse(vm.showResumeChronoButton)
        XCTAssertNil(UserDefaults.standard.object(forKey: Self.suspendedTimerModeSnapshotKey))
    }

    func testStoppedManualSnapshotRestoresManualBootstrapAndResumeRestartsManualEngine() {
        Self.clearSuspendedTimerModeSnapshot()
        defer { Self.clearSuspendedTimerModeSnapshot() }

        let runningVM = AppViewModel(windowManager: MockWindowManager(), bootstrapAutoEngine: false)
        runningVM.setMode(.manual)
        runningVM.startManualFocus()
        runningVM.stopTimers()

        XCTAssertEqual(
            UserDefaults.standard.string(forKey: Self.suspendedTimerModeSnapshotKey),
            Self.manualSuspendedTimerModeToken
        )

        let restoredManualEngine = ManualTimerEngine(workDuration: 600, restDuration: 120)
        let restoredAutoEngine = AutoTimerEngine(restDuration: 60)
        let restoredVM = AppViewModel(
            windowManager: MockWindowManager(),
            manualEngine: restoredManualEngine,
            autoEngine: restoredAutoEngine,
            bootstrapAutoEngine: true
        )

        XCTAssertEqual(restoredVM.mode, .manual)
        XCTAssertFalse(restoredManualEngine.isTimerRunning)
        XCTAssertFalse(restoredAutoEngine.isTimerRunning)
        XCTAssertFalse(restoredVM.canStopChronoButton)
        XCTAssertTrue(restoredVM.showResumeChronoButton)

        restoredVM.resumeTimers()

        XCTAssertTrue(restoredManualEngine.isTimerRunning)
        XCTAssertTrue(restoredVM.canStopChronoButton)
        XCTAssertFalse(restoredVM.showResumeChronoButton)
        XCTAssertNil(UserDefaults.standard.object(forKey: Self.suspendedTimerModeSnapshotKey))
    }

    func testInvalidStoppedSnapshotIsClearedAndDefaultAutoBootstrapRuns() {
        Self.clearSuspendedTimerModeSnapshot()
        defer { Self.clearSuspendedTimerModeSnapshot() }
        UserDefaults.standard.set("bogus", forKey: Self.suspendedTimerModeSnapshotKey)

        let autoEngine = AutoTimerEngine(restDuration: 60)
        let vm = AppViewModel(
            windowManager: MockWindowManager(),
            autoEngine: autoEngine,
            bootstrapAutoEngine: true
        )

        XCTAssertEqual(vm.mode, .auto)
        XCTAssertTrue(autoEngine.isTimerRunning)
        XCTAssertTrue(vm.canStopChronoButton)
        XCTAssertFalse(vm.showResumeChronoButton)
        XCTAssertEqual(vm.petDisplayMode, .runningBlack)
        XCTAssertNil(UserDefaults.standard.object(forKey: Self.suspendedTimerModeSnapshotKey))
    }

    func testNonStringStoppedSnapshotIsClearedAndDefaultAutoBootstrapRuns() {
        Self.clearSuspendedTimerModeSnapshot()
        defer { Self.clearSuspendedTimerModeSnapshot() }
        UserDefaults.standard.set(["manual"], forKey: Self.suspendedTimerModeSnapshotKey)

        let autoEngine = AutoTimerEngine(restDuration: 60)
        let vm = AppViewModel(
            windowManager: MockWindowManager(),
            autoEngine: autoEngine,
            bootstrapAutoEngine: true
        )

        XCTAssertEqual(vm.mode, .auto)
        XCTAssertTrue(autoEngine.isTimerRunning)
        XCTAssertTrue(vm.canStopChronoButton)
        XCTAssertFalse(vm.showResumeChronoButton)
        XCTAssertEqual(vm.petDisplayMode, .runningBlack)
        XCTAssertNil(UserDefaults.standard.object(forKey: Self.suspendedTimerModeSnapshotKey))
    }

    func testSetModeClearsStoppedSnapshot() {
        Self.clearSuspendedTimerModeSnapshot()
        defer { Self.clearSuspendedTimerModeSnapshot() }
        UserDefaults.standard.set(Self.manualSuspendedTimerModeToken, forKey: Self.suspendedTimerModeSnapshotKey)

        let vm = AppViewModel(windowManager: MockWindowManager(), bootstrapAutoEngine: false)
        vm.setMode(.auto)

        XCTAssertNil(UserDefaults.standard.object(forKey: Self.suspendedTimerModeSnapshotKey))
    }

    func testStartManualFocusClearsStoppedSnapshot() {
        Self.clearSuspendedTimerModeSnapshot()
        defer { Self.clearSuspendedTimerModeSnapshot() }

        let vm = AppViewModel(windowManager: MockWindowManager(), bootstrapAutoEngine: false)
        vm.setMode(.manual)
        UserDefaults.standard.set(Self.manualSuspendedTimerModeToken, forKey: Self.suspendedTimerModeSnapshotKey)
        vm.startManualFocus()

        XCTAssertNil(UserDefaults.standard.object(forKey: Self.suspendedTimerModeSnapshotKey))
    }

    func testSetManual_isPausedWhiteUntilStartFocus() {
        let mock = MockWindowManager()
        let vm = AppViewModel(windowManager: mock, bootstrapAutoEngine: false)
        vm.setMode(.manual)
        XCTAssertEqual(vm.petDisplayMode, .pausedWhiteOutline)
        vm.startManualFocus()
        XCTAssertEqual(vm.petDisplayMode, .runningBlack)
    }

    func testStopTimers_manualAndAuto_bothPause() {
        let mock = MockWindowManager()
        let vm = AppViewModel(windowManager: mock, bootstrapAutoEngine: false)
        vm.setMode(.manual)
        vm.startManualFocus()
        vm.stopTimers()
        XCTAssertEqual(vm.petDisplayMode, .pausedWhiteOutline)
        XCTAssertTrue(vm.showResumeChronoButton)
        XCTAssertFalse(vm.canStopChronoButton)

        Self.clearTimerModeDefaults()
        let mock2 = MockWindowManager()
        let vm2 = AppViewModel(windowManager: mock2, bootstrapAutoEngine: true)
        XCTAssertEqual(vm2.mode, .auto)
        XCTAssertTrue(vm2.canStopChronoButton)
        vm2.stopTimers()
        XCTAssertEqual(vm2.petDisplayMode, .pausedWhiteOutline)
        XCTAssertTrue(vm2.showResumeChronoButton)
        XCTAssertFalse(vm2.canStopChronoButton)
    }

    func testStopTimers_whenIdle_manual_doesNotOfferResume() {
        let mock = MockWindowManager()
        let vm = AppViewModel(windowManager: mock, bootstrapAutoEngine: false)
        vm.setMode(.manual)
        XCTAssertFalse(vm.canStopChronoButton)
        vm.stopTimers()
        XCTAssertFalse(vm.showResumeChronoButton)
    }

    func testResumeTimers_manual_restartsEngineAndShowsStopAgain() {
        let mock = MockWindowManager()
        let fast = ManualTimerEngine(workDuration: 600, restDuration: 120)
        let vm = AppViewModel(windowManager: mock, manualEngine: fast, bootstrapAutoEngine: false)
        vm.setMode(.manual)
        vm.startManualFocus()
        XCTAssertTrue(fast.isTimerRunning)
        vm.stopTimers()
        XCTAssertFalse(fast.isTimerRunning)
        XCTAssertTrue(vm.showResumeChronoButton)

        vm.resumeTimers()
        XCTAssertTrue(fast.isTimerRunning)
        XCTAssertTrue(vm.canStopChronoButton)
        XCTAssertFalse(vm.showResumeChronoButton)
        XCTAssertEqual(vm.petDisplayMode, .runningBlack)
    }

    func testResumeTimers_auto_restartsEngine() {
        let mock = MockWindowManager()
        let vm = AppViewModel(windowManager: mock, bootstrapAutoEngine: true)
        XCTAssertTrue(vm.canStopChronoButton)
        vm.stopTimers()
        XCTAssertTrue(vm.showResumeChronoButton)

        vm.resumeTimers()
        XCTAssertTrue(vm.canStopChronoButton)
        XCTAssertFalse(vm.showResumeChronoButton)
        yieldForMainActorEngineDelivery()
        XCTAssertEqual(vm.petDisplayMode, .runningBlack)
    }

    func testAppBecomeActiveRealignsActiveAutoTimerStatusLine() {
        var now = localDate(hour: 10, minute: 25)
        let autoEngine = AutoTimerEngine(restDuration: 60, now: { now })
        let vm = AppViewModel(
            windowManager: MockWindowManager(),
            autoEngine: autoEngine,
            bootstrapAutoEngine: true
        )
        yieldForMainActorEngineDelivery()
        XCTAssertTrue(vm.statusLine.contains("10:30"))

        now = localDate(hour: 10, minute: 49)
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        yieldForMainActorEngineDelivery()
        yieldForMainActorEngineDelivery()

        XCTAssertTrue(autoEngine.isTimerRunning)
        XCTAssertFalse(autoEngine.isInScheduledRest)
        XCTAssertTrue(vm.statusLine.contains("11:00"))
    }

    func testWakeNotificationRealignsActiveAutoTimerStatusLine() {
        var now = localDate(hour: 10, minute: 25)
        let autoEngine = AutoTimerEngine(restDuration: 60, now: { now })
        let vm = AppViewModel(
            windowManager: MockWindowManager(),
            autoEngine: autoEngine,
            bootstrapAutoEngine: true
        )
        yieldForMainActorEngineDelivery()
        XCTAssertTrue(vm.statusLine.contains("10:30"))

        now = localDate(hour: 10, minute: 49)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        yieldForMainActorEngineDelivery()
        yieldForMainActorEngineDelivery()

        XCTAssertTrue(autoEngine.isTimerRunning)
        XCTAssertFalse(autoEngine.isInScheduledRest)
        XCTAssertTrue(vm.statusLine.contains("11:00"))
    }

    func testAppBecomeActiveDoesNotRestartUserStoppedAutoTimer() {
        Self.clearSuspendedTimerModeSnapshot()
        defer { Self.clearSuspendedTimerModeSnapshot() }

        var now = localDate(hour: 10, minute: 25)
        let autoEngine = AutoTimerEngine(restDuration: 60, now: { now })
        let vm = AppViewModel(
            windowManager: MockWindowManager(),
            autoEngine: autoEngine,
            bootstrapAutoEngine: true
        )
        yieldForMainActorEngineDelivery()
        vm.stopTimers()
        XCTAssertFalse(autoEngine.isTimerRunning)
        XCTAssertTrue(vm.showResumeChronoButton)
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: Self.suspendedTimerModeSnapshotKey),
            Self.autoSuspendedTimerModeToken
        )

        now = localDate(hour: 10, minute: 49)
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        yieldForMainActorEngineDelivery()
        yieldForMainActorEngineDelivery()

        XCTAssertFalse(autoEngine.isTimerRunning)
        XCTAssertTrue(vm.showResumeChronoButton)
        XCTAssertEqual(vm.statusLine, "自动提醒已暂停。点击「恢复计时」重新对齐整点 / 半点。")
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: Self.suspendedTimerModeSnapshotKey),
            Self.autoSuspendedTimerModeToken
        )
    }

    // MARK: - 注入引擎状态（无 Timer）

    func testManualEngineEmit_enterRestPhase_deliversPresentAsync() {
        let mock = MockWindowManager()
        let fast = ManualTimerEngine(workDuration: 600, restDuration: 600)
        let vm = AppViewModel(windowManager: mock, manualEngine: fast, bootstrapAutoEngine: false)
        vm.setMode(.manual)
        vm.startManualFocus()
        XCTAssertEqual(mock.presentCount, 0)
        fast.testing_enterRestPhase(remaining: 300)
        XCTAssertEqual(mock.presentCount, 0, "引擎 onStateChange 经 Task 投递，同步返回时霸屏尚未触发")
        yieldForMainActorEngineDelivery()
        XCTAssertEqual(mock.presentCount, 1)
        XCTAssertEqual(vm.petDisplayMode, .restingRed)
    }

    func testInjectManualWorking_showsBlackAndNoRest() {
        let mock = MockWindowManager()
        let vm = AppViewModel(windowManager: mock, bootstrapAutoEngine: false)
        vm.setMode(.manual)
        vm.startManualFocus()
        let p0 = mock.presentCount
        vm.testing_injectTimeState(.working(remaining: 100), fromManualEngine: true)
        XCTAssertEqual(vm.petDisplayMode, .runningBlack)
        XCTAssertEqual(mock.presentCount, p0)
    }

    func testInjectManualResting_triggersPresentOnce() {
        let mock = MockWindowManager()
        let vm = AppViewModel(windowManager: mock, bootstrapAutoEngine: false)
        vm.setMode(.manual)
        vm.startManualFocus()
        vm.testing_injectTimeState(.resting(remaining: 200), fromManualEngine: true)
        XCTAssertEqual(mock.presentCount, 1)
        XCTAssertEqual(vm.petDisplayMode, .restingRed)
        vm.testing_injectTimeState(.resting(remaining: 199), fromManualEngine: true)
        XCTAssertEqual(mock.presentCount, 1, "同一轮休息不应重复 present")
    }

    func testInjectManualResting_ignoredWhenAutoMode() {
        let mock = MockWindowManager()
        let vm = AppViewModel(windowManager: mock, bootstrapAutoEngine: false)
        vm.setMode(.auto)
        vm.testing_injectTimeState(.resting(remaining: 200), fromManualEngine: true)
        XCTAssertEqual(mock.presentCount, 0)
    }

    func testInjectAutoResting_triggersPresentInAutoMode() {
        let mock = MockWindowManager()
        let vm = AppViewModel(windowManager: mock, bootstrapAutoEngine: false)
        vm.setMode(.auto)
        vm.testing_injectTimeState(.resting(remaining: 200), fromManualEngine: false)
        XCTAssertEqual(mock.presentCount, 1)
        XCTAssertEqual(vm.petDisplayMode, .restingRed)
    }

    func testWorkingAfterRest_clearsRestPetMode() {
        let mock = MockWindowManager()
        let vm = AppViewModel(windowManager: mock, bootstrapAutoEngine: false)
        vm.setMode(.manual)
        vm.startManualFocus()
        vm.testing_injectTimeState(.resting(remaining: 10), fromManualEngine: true)
        vm.testing_injectTimeState(.working(remaining: 1500), fromManualEngine: true)
        XCTAssertEqual(vm.petDisplayMode, .runningBlack)
    }

    // MARK: - 测试休息与引擎休息交错

    func testTestRestThenFinish_resumesEngineRestOverlay() {
        let mock = MockWindowManager()
        let fast = ManualTimerEngine(workDuration: 600, restDuration: 600)
        let vm = AppViewModel(windowManager: mock, manualEngine: fast, bootstrapAutoEngine: false)
        vm.setMode(.manual)
        vm.startManualFocus()
        fast.testing_enterRestPhase(remaining: 300)
        yieldForMainActorEngineDelivery()
        XCTAssertEqual(mock.presentCount, 1, "引擎进入休息后应 present 霸屏一次")
        XCTAssertTrue(fast.isInRestPhase)

        vm.startTestRestNow()
        XCTAssertGreaterThanOrEqual(mock.presentCount, 2)

        mock.testing_simulateRestPresentationFinished()

        XCTAssertTrue(fast.isInRestPhase, "引擎仍应在休息段内")
        XCTAssertGreaterThanOrEqual(mock.presentCount, 3, "应再次 present 以恢复引擎休息霸屏")
        XCTAssertEqual(vm.petDisplayMode, .restingRed)
    }

    func testTestRestWhileWorking_doesNotSetWasRestingStale() {
        let mock = MockWindowManager()
        let vm = AppViewModel(windowManager: mock, bootstrapAutoEngine: false)
        vm.setMode(.manual)
        vm.startManualFocus()
        vm.testing_injectTimeState(.working(remaining: 100), fromManualEngine: true)

        vm.startTestRestNow()
        mock.testing_simulateRestPresentationFinished()

        XCTAssertEqual(vm.petDisplayMode, .runningBlack)
        XCTAssertEqual(mock.presentCount, 1, "仅测试霸屏一次，结束后不应误触发引擎休息 present")
    }

    // MARK: - 切模式与 dismiss

    func testSetModeWhileResting_clearsTestAndDismisses() {
        let mock = MockWindowManager()
        let vm = AppViewModel(windowManager: mock, bootstrapAutoEngine: false)
        vm.setMode(.manual)
        vm.startTestRestNow()
        let d = mock.dismissCount
        vm.setMode(.auto)
        XCTAssertGreaterThan(mock.dismissCount, d)
        XCTAssertFalse(vm.statusLine.contains("【测试】"))
    }

    func testStartManualFocus_dismissesPendingRest() {
        let mock = MockWindowManager()
        let vm = AppViewModel(windowManager: mock, bootstrapAutoEngine: false)
        vm.setMode(.manual)
        vm.startManualFocus()
        vm.testing_injectTimeState(.resting(remaining: 100), fromManualEngine: true)
        let d = mock.dismissCount
        vm.startManualFocus()
        XCTAssertGreaterThan(mock.dismissCount, d)
    }

    func testEndRestEarlyFromDeskPet_manualSkipsToWork() {
        let mock = MockWindowManager()
        let fast = ManualTimerEngine(workDuration: 600, restDuration: 600)
        let vm = AppViewModel(windowManager: mock, manualEngine: fast, bootstrapAutoEngine: false)
        vm.setMode(.manual)
        vm.startManualFocus()
        fast.testing_enterRestPhase(remaining: 300)
        yieldForMainActorEngineDelivery()
        XCTAssertTrue(fast.isInRestPhase)
        let d = mock.dismissCount
        vm.endRestEarlyFromDeskPet()
        XCTAssertGreaterThan(mock.dismissCount, d)
        XCTAssertFalse(fast.isInRestPhase)
        yieldForMainActorEngineDelivery()
        XCTAssertEqual(vm.petDisplayMode, .runningBlack)
    }

    // MARK: - AutoTimerEngine.nextHalfHourAnchor

    func testAutoAnchorTimerFiringMateriallyLateRealignsInsteadOfResting() throws {
        var now = localDate(hour: 10, minute: 25)
        let engine = AutoTimerEngine(restDuration: 60, now: { now })
        var states: [TimeState] = []
        engine.onStateChange = { states.append($0) }

        engine.start()
        defer { engine.stop() }

        guard case .autoWatching(let initialAnchor) = try XCTUnwrap(states.last) else {
            return XCTFail("Expected AutoTimerEngine to wait for the next anchor")
        }
        XCTAssertEqual(Calendar.current.component(.hour, from: initialAnchor), 10)
        XCTAssertEqual(Calendar.current.component(.minute, from: initialAnchor), 30)

        now = localDate(hour: 10, minute: 49)
        try backingTimer(from: engine).fire()

        XCTAssertFalse(engine.isInScheduledRest)
        XCTAssertFalse(states.contains { state in
            if case .resting = state { return true }
            return false
        })
        guard case .autoWatching(let realignedAnchor) = try XCTUnwrap(states.last) else {
            return XCTFail("Expected stale anchor fire to realign instead of rest")
        }
        XCTAssertEqual(Calendar.current.component(.hour, from: realignedAnchor), 11)
        XCTAssertEqual(Calendar.current.component(.minute, from: realignedAnchor), 0)
    }

    func testAutoAnchorTimerFiringWithinGraceWindowBeginsScheduledRest() throws {
        var now = localDate(hour: 10, minute: 25)
        let engine = AutoTimerEngine(restDuration: 123, now: { now })
        var states: [TimeState] = []
        engine.onStateChange = { states.append($0) }

        engine.start()
        defer { engine.stop() }

        now = localDate(hour: 10, minute: 30, second: 1)
        try backingTimer(from: engine).fire()

        XCTAssertTrue(engine.isInScheduledRest)
        guard case .resting(let remaining) = try XCTUnwrap(states.last) else {
            return XCTFail("Expected on-time anchor fire to enter scheduled rest")
        }
        XCTAssertEqual(remaining, 123, accuracy: 0.1)
    }

    func testAutoStartSchedulesAnchorTimerInsteadOfQuarterSecondPolling() throws {
        let engine = AutoTimerEngine(restDuration: 1)
        var states: [TimeState] = []
        engine.onStateChange = { states.append($0) }

        engine.start()
        defer { engine.stop() }

        let state = try XCTUnwrap(states.first)
        guard case .autoWatching(let anchor) = state else {
            return XCTFail("Expected AutoTimerEngine to enter autoWatching first")
        }
        let delay = anchor.timeIntervalSinceNow
        if delay < 2 {
            throw XCTSkip("Current wall clock is too close to the half-hour anchor for a stable timer fireDate assertion")
        }

        let timer = try backingTimer(from: engine)
        XCTAssertGreaterThan(timer.fireDate.timeIntervalSinceNow, 1, "Waiting for a future anchor should not use the old 0.25s polling interval")
        XCTAssertEqual(timer.fireDate.timeIntervalSince(anchor), 0, accuracy: 0.5)
    }

    func testAutoScheduledRestUsesOneSecondTimerAndSuppressesSameSecondCountdownDuplicates() throws {
        var now = localDate(hour: 10, minute: 25)
        let engine = AutoTimerEngine(restDuration: 2.4, now: { now })
        var states: [TimeState] = []
        engine.onStateChange = { states.append($0) }

        engine.start()
        defer { engine.stop() }
        now = localDate(hour: 10, minute: 30)
        try backingTimer(from: engine).fire()

        XCTAssertTrue(engine.isInScheduledRest)
        guard case .resting(let initialRemaining) = try XCTUnwrap(states.last) else {
            return XCTFail("Expected firing the anchor timer to enter scheduled rest")
        }
        XCTAssertEqual(initialRemaining, 2.4, accuracy: 0.1)

        let restTimer = try backingTimer(from: engine)
        XCTAssertGreaterThan(restTimer.fireDate.timeIntervalSinceNow, 0.75, "Scheduled rest countdown should not keep using the old 0.25s timer cadence")
        XCTAssertLessThanOrEqual(restTimer.fireDate.timeIntervalSinceNow, 1.1)

        let stateCountAfterBeginningRest = states.count
        restTimer.fire()
        restTimer.fire()
        XCTAssertEqual(states.count, stateCountAfterBeginningRest, "Countdown should not emit duplicate .resting states while the displayed whole second is unchanged")
    }

    func testAutoScheduledRestDoesNotSkipNextDisplayedSecondWhenOneSecondTickIsLate() throws {
        var now = localDate(hour: 10, minute: 25)
        let engine = AutoTimerEngine(restDuration: 3, now: { now })
        var displayedSeconds: [Int] = []
        engine.onStateChange = { state in
            if case .resting(let remaining) = state {
                displayedSeconds.append(max(0, Int(floor(remaining))))
            }
        }

        engine.start()
        defer { engine.stop() }
        now = localDate(hour: 10, minute: 30)
        try backingTimer(from: engine).fire()

        XCTAssertEqual(displayedSeconds, [3])
        let firstRestTick = try backingTimer(from: engine)
        now = localDate(hour: 10, minute: 30, second: 1).addingTimeInterval(0.02)
        firstRestTick.fire()

        XCTAssertEqual(displayedSeconds, [3, 2], "A slightly late one-second rest tick should still emit the next displayed second instead of skipping it")
    }

    func testNextHalfHourAnchor_after1025_is1030() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let d = cal.date(from: DateComponents(year: 2026, month: 3, day: 19, hour: 10, minute: 25, second: 30))!
        let anchor = AutoTimerEngine.nextHalfHourAnchor(after: d)
        let h = cal.component(.hour, from: anchor)
        let m = cal.component(.minute, from: anchor)
        XCTAssertEqual(h, 10)
        XCTAssertEqual(m, 30)
    }

    func testNextHalfHourAnchor_exactly1030_is1100() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let d = cal.date(from: DateComponents(year: 2026, month: 3, day: 19, hour: 10, minute: 30, second: 0))!
        let anchor = AutoTimerEngine.nextHalfHourAnchor(after: d)
        let h = cal.component(.hour, from: anchor)
        let m = cal.component(.minute, from: anchor)
        XCTAssertEqual(h, 11)
        XCTAssertEqual(m, 0)
    }
}
