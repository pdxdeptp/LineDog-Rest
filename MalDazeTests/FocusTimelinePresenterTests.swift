import XCTest
@testable import MalDaze

@MainActor
final class FocusTimelinePresenterTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() async throws {
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

    func testLiveOverlayRefreshDoesNotRebuildSkeleton() {
        let presenter = FocusTimelinePresenter(calendar: calendar)
        let day = date(year: 2026, month: 6, day: 20, hour: 12, minute: 0)
        presenter.setTimelineDay(day, calendar: calendar)
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
    }

    func testLiveOverlayOmittedWhenConsumerHidden() throws {
        let presenter = FocusTimelinePresenter(calendar: calendar)
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
        let presenter = FocusTimelinePresenter(calendar: calendar)
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
        let presenter = FocusTimelinePresenter(calendar: calendar)
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
