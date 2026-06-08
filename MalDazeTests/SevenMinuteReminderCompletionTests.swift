import XCTest
@testable import MalDaze

/// tasks-maldaze 5.1b：Hermes countdown 结束铃铛文案为 title，非「X 分钟计时结束」。
@MainActor
final class SevenMinuteReminderCompletionTests: XCTestCase {
    func testCountdownFinishUsesCompletionMessageNotDefaultMinutes() {
        let controller = SevenMinuteReminderController()
        controller.start(minutes: 30, completionMessage: "红薯煮好了")
        controller.testing_finishCountdownImmediately()
        XCTAssertEqual(controller.testing_lastReminderMessage, "红薯煮好了")
    }

    func testCountdownFinishUsesDefaultMinutesWhenMessageEmpty() {
        let controller = SevenMinuteReminderController()
        controller.start(minutes: 7, completionMessage: "")
        controller.testing_finishCountdownImmediately()
        XCTAssertEqual(controller.testing_lastReminderMessage, "7 分钟计时结束")
    }
}
