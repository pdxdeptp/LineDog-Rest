import XCTest
@testable import MalDaze

@MainActor
final class DashboardQuiescenceCoordinatorTests: XCTestCase {
    func testTransitionVisibleToHiddenInvokesPauseHandlers() {
        let coordinator = DashboardQuiescenceCoordinator()
        var pauseCount = 0
        _ = coordinator.registerPauseHandler {
            pauseCount += 1
        }

        coordinator.transition(to: .visible)
        XCTAssertEqual(coordinator.phase, .visible)
        XCTAssertEqual(pauseCount, 0)

        coordinator.transition(to: .hidden)
        XCTAssertEqual(coordinator.phase, .hidden)
        XCTAssertEqual(pauseCount, 1)
    }

    func testHiddenToVisibleDoesNotInvokePauseHandlers() {
        let coordinator = DashboardQuiescenceCoordinator()
        var pauseCount = 0
        _ = coordinator.registerPauseHandler {
            pauseCount += 1
        }

        coordinator.transition(to: .hidden)
        coordinator.transition(to: .visible)
        XCTAssertEqual(pauseCount, 0)
    }
}
