import XCTest
@testable import MalDaze

@MainActor
final class DashboardQuiescenceCoordinatorTests: XCTestCase {
    func testTransitionVisibleToHiddenInvokesPauseHandlers() {
        let coordinator = DashboardQuiescenceCoordinator()
        var pauseCount = 0
        _ = coordinator.registerConsumer(pause: { pauseCount += 1 }, resume: {})

        coordinator.transition(to: .visible)
        XCTAssertEqual(coordinator.phase, .visible)
        XCTAssertEqual(pauseCount, 0)

        coordinator.transition(to: .hidden)
        XCTAssertEqual(coordinator.phase, .hidden)
        XCTAssertEqual(pauseCount, 1)
    }

    func testHiddenToVisibleInvokesResumeHandlers() {
        let coordinator = DashboardQuiescenceCoordinator()
        var pauseCount = 0
        var resumeCount = 0
        _ = coordinator.registerConsumer(
            pause: { pauseCount += 1 },
            resume: { resumeCount += 1 }
        )

        coordinator.transition(to: .hidden)
        coordinator.transition(to: .visible)
        XCTAssertEqual(pauseCount, 0)
        XCTAssertEqual(resumeCount, 1)
    }

    func testAbsentToVisibleInvokesResumeHandlers() {
        let coordinator = DashboardQuiescenceCoordinator()
        var resumeCount = 0
        _ = coordinator.registerConsumer(pause: {}, resume: { resumeCount += 1 })

        coordinator.transition(to: .visible)
        XCTAssertEqual(coordinator.phase, .visible)
        XCTAssertEqual(resumeCount, 1)
    }

    func testHiddenToVisibleDoesNotInvokePauseHandlers() {
        let coordinator = DashboardQuiescenceCoordinator()
        var pauseCount = 0
        _ = coordinator.registerConsumer(pause: { pauseCount += 1 }, resume: {})

        coordinator.transition(to: .hidden)
        coordinator.transition(to: .visible)
        XCTAssertEqual(pauseCount, 0)
    }

    func testPairedConsumersReceiveIndependentPauseAndResume() {
        let coordinator = DashboardQuiescenceCoordinator()
        var firstPause = 0
        var firstResume = 0
        var secondPause = 0
        var secondResume = 0
        _ = coordinator.registerConsumer(
            pause: { firstPause += 1 },
            resume: { firstResume += 1 }
        )
        _ = coordinator.registerConsumer(
            pause: { secondPause += 1 },
            resume: { secondResume += 1 }
        )

        coordinator.transition(to: .hidden)
        coordinator.transition(to: .visible)
        coordinator.transition(to: .hidden)
        coordinator.transition(to: .visible)

        XCTAssertEqual(firstPause, 1)
        XCTAssertEqual(secondPause, 1)
        XCTAssertEqual(firstResume, 2)
        XCTAssertEqual(secondResume, 2)
    }
}
