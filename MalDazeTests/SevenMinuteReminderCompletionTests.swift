import XCTest
@testable import MalDaze

/// tasks-maldaze 5.1b：Hermes countdown 结束铃铛文案为 title，非「X 分钟计时结束」。
@MainActor
final class SevenMinuteReminderCompletionTests: XCTestCase {
    private func makeController() -> SevenMinuteReminderController {
        let presenter = MalDazeTransientOverlayPresenter(
            dashboardPolicy: .init(demoteVisibleDashboardIfNeeded: { _ in })
        )
        return SevenMinuteReminderController(overlayPresenter: presenter)
    }

    func testCountdownFinishUsesCompletionMessageNotDefaultMinutes() {
        let controller = makeController()
        controller.start(minutes: 30, completionMessage: "红薯煮好了")
        controller.testing_finishCountdownImmediately()
        XCTAssertEqual(controller.testing_lastReminderMessage, "红薯煮好了")
    }

    func testCountdownFinishUsesDefaultMinutesWhenMessageEmpty() {
        let controller = makeController()
        controller.start(minutes: 7, completionMessage: "")
        controller.testing_finishCountdownImmediately()
        XCTAssertEqual(controller.testing_lastReminderMessage, "7 分钟计时结束")
    }

    func testCountdownFinishRemovesScreenObserverBeforeCenterBell() throws {
        let source = try readProjectSource("MalDaze/SevenMinuteReminder/SevenMinuteReminderController.swift")
        let finishSource = try functionSource(named: "onCountdownFinished", in: source)
        guard let removeRange = finishSource.range(of: "removeScreenObserver()"),
              let presentRange = finishSource.range(of: "presentCenterBellReminder")
        else {
            return XCTFail("Countdown finish should remove the screen observer before presenting center bell.")
        }
        XCTAssertLessThan(removeRange.lowerBound, presentRange.lowerBound)
    }

    private func readProjectSource(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func functionSource(named functionName: String, in source: String) throws -> String {
        guard let signatureRange = source.range(of: "func \(functionName)") else {
            throw NSError(domain: "SevenMinuteReminderCompletionTests", code: 1)
        }
        guard let openingBrace = source[signatureRange.lowerBound...].firstIndex(of: "{") else {
            throw NSError(domain: "SevenMinuteReminderCompletionTests", code: 2)
        }

        var depth = 0
        var cursor = openingBrace
        while cursor < source.endIndex {
            switch source[cursor] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(source[signatureRange.lowerBound..<source.index(after: cursor)])
                }
            default:
                break
            }
            cursor = source.index(after: cursor)
        }
        throw NSError(domain: "SevenMinuteReminderCompletionTests", code: 3)
    }
}
