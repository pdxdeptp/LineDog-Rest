import XCTest
@testable import MalDaze

/// 合盖取消睡眠霸屏（add-sleep-schedule §3.3）。
@MainActor
final class SleepReminderClamshellTests: XCTestCase {
    private var savedClamshell: Any?
    private var savedMaster: Any?

    override func setUp() {
        super.setUp()
        let ud = UserDefaults.standard
        savedClamshell = ud.object(forKey: MalDazeDefaults.sleepScheduleDismissOnClamshell)
        savedMaster = ud.object(forKey: MalDazeDefaults.sleepScheduleEnabled)
        ud.set(true, forKey: MalDazeDefaults.sleepScheduleDismissOnClamshell)
        ud.set(true, forKey: MalDazeDefaults.sleepScheduleEnabled)
    }

    override func tearDown() {
        let ud = UserDefaults.standard
        if let savedClamshell {
            ud.set(savedClamshell, forKey: MalDazeDefaults.sleepScheduleDismissOnClamshell)
        } else {
            ud.removeObject(forKey: MalDazeDefaults.sleepScheduleDismissOnClamshell)
        }
        if let savedMaster {
            ud.set(savedMaster, forKey: MalDazeDefaults.sleepScheduleEnabled)
        } else {
            ud.removeObject(forKey: MalDazeDefaults.sleepScheduleEnabled)
        }
        super.tearDown()
    }

    func testWillSleepDismissesActiveSleepLock() {
        let mock = MockWindowManager()
        let bell = SevenMinuteReminderController()
        let controller = SleepReminderController(
            contractReader: SleepScheduleContractReader(fileURL: URL(fileURLWithPath: "/dev/null")),
            bellPresenter: bell,
            windowManager: mock
        )
        controller.start()
        controller.testing_setSleepLockActiveForTests(true)

        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
        let drained = expectation(description: "mainActor willSleep handler")
        Task { @MainActor in drained.fulfill() }
        wait(for: [drained], timeout: 2.0)

        XCTAssertEqual(mock.dismissCount, 1)
        XCTAssertFalse(controller.isSleepLockActive)
        controller.cancel()
    }

    func testWillSleepSkipsDismissWhenClamshellSettingOff() {
        UserDefaults.standard.set(false, forKey: MalDazeDefaults.sleepScheduleDismissOnClamshell)
        let mock = MockWindowManager()
        let bell = SevenMinuteReminderController()
        let controller = SleepReminderController(
            contractReader: SleepScheduleContractReader(fileURL: URL(fileURLWithPath: "/dev/null")),
            bellPresenter: bell,
            windowManager: mock
        )
        controller.start()
        controller.testing_setSleepLockActiveForTests(true)

        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)

        XCTAssertEqual(mock.dismissCount, 0)
        XCTAssertTrue(controller.isSleepLockActive)
        controller.cancel()
    }
}
