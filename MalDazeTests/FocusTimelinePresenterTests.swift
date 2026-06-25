import XCTest
@testable import MalDaze

@MainActor
final class FocusTimelinePresenterTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() async throws {
        FocusTimelinePresenter.allowsLiveTickSchedulingInTests = false
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        ))!
    }

    private func session(startedAt: Date, endedAt: Date) -> FocusSession {
        FocusSession(
            date: FocusSessionFormatting.isoDate(startedAt, calendar: calendar),
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: FocusSessionFormatting.durationSeconds(from: startedAt, to: endedAt),
            source: .completed
        )
    }

    private func inProgress(at now: Date, elapsedMinutes: Int, totalMinutes: Int = 25) -> FocusPomodoroInProgress {
        let startedAt = now.addingTimeInterval(-TimeInterval(elapsedMinutes * 60))
        let endsAt = startedAt.addingTimeInterval(TimeInterval(totalMinutes * 60))
        let remaining = max(0, totalMinutes * 60 - elapsedMinutes * 60)
        return FocusPomodoroInProgress(
            startedAt: startedAt,
            endsAt: endsAt,
            remainingSeconds: remaining,
            elapsedSeconds: elapsedMinutes * 60
        )
    }

    override func tearDown() async throws {
        FocusTimelinePresenter.allowsLiveTickSchedulingInTests = false
    }

    private func timelinePresenter(
        day: Date? = nil
    ) -> FocusTimelinePresenter {
        let presenter = FocusTimelinePresenter(calendar: calendar)
        let timelineDay = day ?? date(year: 2026, month: 6, day: 20, hour: 12, minute: 0)
        presenter.setTimelineDay(timelineDay, calendar: calendar)
        presenter.rebuildSkeleton(finalizedSessions: [])
        return presenter
    }

    func testLiveOverlayRefreshDoesNotRebuildSkeleton() {
        let presenter = timelinePresenter()
        let started = date(year: 2026, month: 6, day: 20, hour: 14, minute: 0)
        let ended = date(year: 2026, month: 6, day: 20, hour: 14, minute: 25)
        presenter.rebuildSkeleton(finalizedSessions: [session(startedAt: started, endedAt: ended)])

        let skeletonGeneration = presenter.skeletonGeneration
        presenter.setVisible(true)

        let now = date(year: 2026, month: 6, day: 20, hour: 15, minute: 5)
        presenter.syncLiveOverlay(
            projection: inProgress(at: now, elapsedMinutes: 5),
            isManualWorkActive: true
        )
        XCTAssertTrue(presenter.displayModel.cells.contains {
            $0.fillSegments.contains(where: \.isInProgress)
        })

        presenter.syncLiveOverlay(
            projection: inProgress(at: now.addingTimeInterval(1), elapsedMinutes: 5),
            isManualWorkActive: true
        )

        XCTAssertEqual(presenter.skeletonGeneration, skeletonGeneration)
        XCTAssertEqual(presenter.schedulingPhase, .live)
    }

    func testVisibleAutoWatchingDoesNotStartLiveTick() {
        let presenter = timelinePresenter()
        presenter.liveInputProvider = {
            FocusTimelineLiveInput(projection: nil, isManualWorkActive: false)
        }
        presenter.setVisible(true)

        XCTAssertEqual(presenter.schedulingPhase, .idle)
        XCTAssertFalse(presenter.isLiveTickActive)
    }

    func testVisibleAutoWatchingLiveTickDoesNotPublishDisplayModel() {
        let presenter = timelinePresenter()
        presenter.liveInputProvider = {
            FocusTimelineLiveInput(projection: nil, isManualWorkActive: false)
        }
        presenter.setVisible(true)
        let publishCountAfterVisible = presenter.displayModelPublishCount

        presenter.refreshLiveScheduling()
        presenter.syncLiveOverlay()

        XCTAssertEqual(presenter.displayModelPublishCount, publishCountAfterVisible)
        XCTAssertFalse(presenter.isLiveTickActive)
    }

    func testManualWorkVisibleStartsLiveTickAndUpdatesOverlay() {
        FocusTimelinePresenter.allowsLiveTickSchedulingInTests = true
        defer { FocusTimelinePresenter.allowsLiveTickSchedulingInTests = false }
        let presenter = timelinePresenter()
        let now = date(year: 2026, month: 6, day: 20, hour: 15, minute: 5)
        presenter.setVisible(true)
        presenter.syncLiveOverlay(
            projection: inProgress(at: now, elapsedMinutes: 5),
            isManualWorkActive: true
        )

        XCTAssertEqual(presenter.schedulingPhase, .live)
        XCTAssertTrue(presenter.isLiveTickActive)
        XCTAssertTrue(presenter.displayModel.cells.contains {
            $0.fillSegments.contains(where: \.isInProgress)
        })
        presenter.enterHidden()
    }

    func testManualWorkEndsStopsTickAndClearsOverlayOnce() {
        let presenter = timelinePresenter()
        let now = date(year: 2026, month: 6, day: 20, hour: 15, minute: 5)
        presenter.setVisible(true)
        presenter.syncLiveOverlay(
            projection: inProgress(at: now, elapsedMinutes: 5),
            isManualWorkActive: true
        )
        let publishCountAfterLive = presenter.displayModelPublishCount

        presenter.syncLiveOverlay(projection: nil, isManualWorkActive: false)

        XCTAssertEqual(presenter.schedulingPhase, .idle)
        XCTAssertFalse(presenter.isLiveTickActive)
        XCTAssertFalse(presenter.displayModel.cells.contains {
            $0.fillSegments.contains(where: \.isInProgress)
        })
        XCTAssertEqual(presenter.displayModelPublishCount, publishCountAfterLive + 1)
    }

    func testHiddenStopsTickAndClearsOverlay() {
        let presenter = timelinePresenter()
        let now = date(year: 2026, month: 6, day: 20, hour: 15, minute: 5)
        presenter.setVisible(true)
        presenter.syncLiveOverlay(
            projection: inProgress(at: now, elapsedMinutes: 5),
            isManualWorkActive: true
        )

        presenter.enterHidden()

        XCTAssertEqual(presenter.schedulingPhase, .hidden)
        XCTAssertFalse(presenter.isLiveTickActive)
        XCTAssertFalse(presenter.displayModel.cells.contains {
            $0.fillSegments.contains(where: \.isInProgress)
        })
    }

    func testLiveOverlayOmittedWhenConsumerHidden() throws {
        let presenter = timelinePresenter()
        presenter.setVisible(false)

        let now = date(year: 2026, month: 6, day: 20, hour: 14, minute: 10)
        presenter.syncLiveOverlay(
            projection: inProgress(at: now, elapsedMinutes: 10),
            isManualWorkActive: true
        )

        let targetCell = try XCTUnwrap(
            presenter.displayModel.cells.first {
                $0.start == date(year: 2026, month: 6, day: 20, hour: 14, minute: 0)
            }
        )
        XCTAssertTrue(targetCell.fillSegments.allSatisfy { !$0.isInProgress })
    }

    func testSkipRestProjectionStartsAtOrBeforeNow() throws {
        let presenter = timelinePresenter()
        presenter.setVisible(true)

        let now = date(year: 2026, month: 6, day: 20, hour: 14, minute: 0)
        let endsAt = now.addingTimeInterval(25 * 60)
        let projection = FocusPomodoroInProgress(
            startedAt: now,
            endsAt: endsAt,
            remainingSeconds: 25 * 60,
            elapsedSeconds: 0
        )

        presenter.syncLiveOverlay(projection: projection, isManualWorkActive: true)

        let inProgressSegments = presenter.displayModel.cells.flatMap(\.fillSegments).filter(\.isInProgress)
        let segment = try XCTUnwrap(inProgressSegments.first)
        XCTAssertLessThanOrEqual(segment.sessionStartedAt, now)
        XCTAssertGreaterThanOrEqual(segment.overlapEnd, now)
    }

    func testSetVisibleFalseStopsPublishingInProgressFill() {
        let presenter = timelinePresenter()
        presenter.setVisible(true)

        let now = date(year: 2026, month: 6, day: 20, hour: 14, minute: 5)
        presenter.syncLiveOverlay(
            projection: inProgress(at: now, elapsedMinutes: 5),
            isManualWorkActive: true
        )
        XCTAssertTrue(presenter.displayModel.cells.contains {
            $0.fillSegments.contains(where: \.isInProgress)
        })

        presenter.setVisible(false)
        XCTAssertFalse(presenter.displayModel.cells.contains {
            $0.fillSegments.contains(where: \.isInProgress)
        })
    }
}
