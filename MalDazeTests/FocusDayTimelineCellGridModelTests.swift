import XCTest
@testable import MalDaze

@MainActor
final class FocusDayTimelineCellGridModelTests: XCTestCase {
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

    private func session(
        startedAt: Date,
        endedAt: Date,
        source: FocusSessionSource = .completed
    ) -> FocusSession {
        FocusSession(
            date: FocusSessionFormatting.isoDate(startedAt, calendar: calendar),
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: FocusSessionFormatting.durationSeconds(from: startedAt, to: endedAt),
            source: source
        )
    }

    private func cell(
        in model: FocusDayTimelineCellGridModel,
        hour: Int,
        minute: Int = 0,
        day: Int = 20
    ) -> FocusDayTimelineCell? {
        let target = date(year: 2026, month: 6, day: day, hour: hour, minute: minute)
        return model.cells.first { $0.start == target }
    }

    func testDefaultWindowWhenNoOffHoursActivity() {
        let now = date(year: 2026, month: 6, day: 20, hour: 15, minute: 0)
        let started = date(year: 2026, month: 6, day: 20, hour: 14, minute: 10)
        let ended = date(year: 2026, month: 6, day: 20, hour: 14, minute: 25)
        let model = FocusDayTimelineCellGridModel.make(
            calendar: calendar,
            now: now,
            finalizedSessions: [session(startedAt: started, endedAt: ended)],
            inProgress: nil
        )

        XCTAssertEqual(model.visibleStart, date(year: 2026, month: 6, day: 20, hour: 8, minute: 0))
        XCTAssertEqual(model.visibleEnd, date(year: 2026, month: 6, day: 20, hour: 24, minute: 0))
        XCTAssertEqual(model.cells.count, 32)
    }

    func testPartialCellFill1410To1425() throws {
        let now = date(year: 2026, month: 6, day: 20, hour: 15, minute: 0)
        let started = date(year: 2026, month: 6, day: 20, hour: 14, minute: 10)
        let ended = date(year: 2026, month: 6, day: 20, hour: 14, minute: 25)
        let model = FocusDayTimelineCellGridModel.make(
            calendar: calendar,
            now: now,
            finalizedSessions: [session(startedAt: started, endedAt: ended)],
            inProgress: nil
        )

        let targetCell = try XCTUnwrap(cell(in: model, hour: 14, minute: 0))
        XCTAssertEqual(targetCell.fillSegments.count, 1)
        XCTAssertEqual(targetCell.fillSegments[0].startFraction, 10.0 / 30.0, accuracy: 0.0001)
        XCTAssertEqual(targetCell.fillSegments[0].widthFraction, 15.0 / 30.0, accuracy: 0.0001)
    }

    func testThreeMinutesInCellIsTenPercentWidth() throws {
        let now = date(year: 2026, month: 6, day: 20, hour: 15, minute: 0)
        let started = date(year: 2026, month: 6, day: 20, hour: 14, minute: 0)
        let ended = date(year: 2026, month: 6, day: 20, hour: 14, minute: 3)
        let model = FocusDayTimelineCellGridModel.make(
            calendar: calendar,
            now: now,
            finalizedSessions: [session(startedAt: started, endedAt: ended)],
            inProgress: nil
        )

        let targetCell = try XCTUnwrap(cell(in: model, hour: 14, minute: 0))
        XCTAssertEqual(targetCell.fillSegments[0].startFraction, 0, accuracy: 0.0001)
        XCTAssertEqual(targetCell.fillSegments[0].widthFraction, 3.0 / 30.0, accuracy: 0.0001)
    }

    func testCrossCellSession() throws {
        let now = date(year: 2026, month: 6, day: 20, hour: 15, minute: 0)
        let started = date(year: 2026, month: 6, day: 20, hour: 14, minute: 20)
        let ended = date(year: 2026, month: 6, day: 20, hour: 14, minute: 50)
        let model = FocusDayTimelineCellGridModel.make(
            calendar: calendar,
            now: now,
            finalizedSessions: [session(startedAt: started, endedAt: ended)],
            inProgress: nil
        )

        let firstCell = try XCTUnwrap(cell(in: model, hour: 14, minute: 0))
        let secondCell = try XCTUnwrap(cell(in: model, hour: 14, minute: 30))

        XCTAssertEqual(firstCell.fillSegments[0].startFraction, 20.0 / 30.0, accuracy: 0.0001)
        XCTAssertEqual(firstCell.fillSegments[0].widthFraction, 10.0 / 30.0, accuracy: 0.0001)
        XCTAssertEqual(secondCell.fillSegments[0].startFraction, 0, accuracy: 0.0001)
        XCTAssertEqual(secondCell.fillSegments[0].widthFraction, 20.0 / 30.0, accuracy: 0.0001)
    }

    func testStoppedEarlyRendersFailedMarkerNotSuccessFill() throws {
        let now = date(year: 2026, month: 6, day: 20, hour: 15, minute: 0)
        let started = date(year: 2026, month: 6, day: 20, hour: 14, minute: 0)
        let ended = date(year: 2026, month: 6, day: 20, hour: 14, minute: 12)
        let abandoned = session(startedAt: started, endedAt: ended, source: .stoppedEarly)
        let model = FocusDayTimelineCellGridModel.make(
            calendar: calendar,
            now: now,
            finalizedSessions: [abandoned],
            inProgress: nil
        )

        let targetCell = try XCTUnwrap(cell(in: model, hour: 14, minute: 0))
        XCTAssertTrue(targetCell.fillSegments.isEmpty)
        XCTAssertEqual(targetCell.failedMarkers.count, 1)
        XCTAssertEqual(targetCell.failedMarkers[0].startFraction, 0, accuracy: 0.0001)
        XCTAssertEqual(targetCell.failedMarkers[0].sessionID, abandoned.id)
    }

    func testOffHoursAbandonedSessionExpandsVisibleStartWithFailedMarker() throws {
        let now = date(year: 2026, month: 6, day: 20, hour: 8, minute: 0)
        let started = date(year: 2026, month: 6, day: 20, hour: 6, minute: 10)
        let ended = date(year: 2026, month: 6, day: 20, hour: 6, minute: 30)
        let model = FocusDayTimelineCellGridModel.make(
            calendar: calendar,
            now: now,
            finalizedSessions: [session(startedAt: started, endedAt: ended, source: .stoppedEarly)],
            inProgress: nil
        )

        XCTAssertEqual(model.visibleStart, date(year: 2026, month: 6, day: 20, hour: 6, minute: 0))
        let targetCell = try XCTUnwrap(cell(in: model, hour: 6, minute: 0))
        XCTAssertTrue(targetCell.fillSegments.isEmpty)
        XCTAssertEqual(targetCell.failedMarkers.count, 1)
        XCTAssertEqual(targetCell.failedMarkers[0].startFraction, 10.0 / 30.0, accuracy: 0.0001)
    }

    func testInProgressPaintsToNow() throws {
        let started = date(year: 2026, month: 6, day: 20, hour: 14, minute: 0)
        let now = date(year: 2026, month: 6, day: 20, hour: 14, minute: 10)
        let model = FocusDayTimelineCellGridModel.make(
            calendar: calendar,
            now: now,
            finalizedSessions: [],
            inProgress: FocusSessionInProgress(
                startedAt: started,
                endsAt: started.addingTimeInterval(25 * 60),
                remainingSeconds: 15 * 60,
                elapsedSeconds: 10 * 60
            )
        )

        let targetCell = try XCTUnwrap(cell(in: model, hour: 14, minute: 0))
        XCTAssertEqual(targetCell.fillSegments[0].startFraction, 0, accuracy: 0.0001)
        XCTAssertEqual(targetCell.fillSegments[0].widthFraction, 10.0 / 30.0, accuracy: 0.0001)
    }

    func testOffHoursSessionExpandsVisibleStart() {
        let now = date(year: 2026, month: 6, day: 20, hour: 8, minute: 0)
        let started = date(year: 2026, month: 6, day: 20, hour: 6, minute: 10)
        let ended = date(year: 2026, month: 6, day: 20, hour: 6, minute: 30)
        let model = FocusDayTimelineCellGridModel.make(
            calendar: calendar,
            now: now,
            finalizedSessions: [session(startedAt: started, endedAt: ended)],
            inProgress: nil
        )

        XCTAssertEqual(model.visibleStart, date(year: 2026, month: 6, day: 20, hour: 6, minute: 0))
        XCTAssertEqual(model.cells.count, 36)
    }

    func testMidnightSpanningSessionSplitsAcrossCells() throws {
        let now = date(year: 2026, month: 6, day: 21, hour: 1, minute: 0)
        let started = date(year: 2026, month: 6, day: 20, hour: 23, minute: 40)
        let ended = date(year: 2026, month: 6, day: 21, hour: 0, minute: 20)
        let timelineDay = date(year: 2026, month: 6, day: 20, hour: 12, minute: 0)
        let model = FocusDayTimelineCellGridModel.make(
            calendar: calendar,
            now: now,
            timelineDay: timelineDay,
            finalizedSessions: [session(startedAt: started, endedAt: ended)],
            inProgress: nil
        )

        XCTAssertEqual(model.visibleStart, date(year: 2026, month: 6, day: 20, hour: 0, minute: 0))

        let lateCell = try XCTUnwrap(cell(in: model, hour: 23, minute: 30))
        XCTAssertEqual(lateCell.fillSegments[0].startFraction, 10.0 / 30.0, accuracy: 0.0001)
        XCTAssertEqual(lateCell.fillSegments[0].widthFraction, 20.0 / 30.0, accuracy: 0.0001)

        let earlyCell = try XCTUnwrap(cell(in: model, hour: 0, minute: 0))
        XCTAssertEqual(earlyCell.fillSegments[0].startFraction, 0, accuracy: 0.0001)
        XCTAssertEqual(earlyCell.fillSegments[0].widthFraction, 20.0 / 30.0, accuracy: 0.0001)
    }

    func testMakeSkeletonExcludesInProgressFill() throws {
        let day = date(year: 2026, month: 6, day: 20, hour: 12, minute: 0)
        let started = date(year: 2026, month: 6, day: 20, hour: 14, minute: 0)
        let skeleton = FocusDayTimelineCellGridModel.makeSkeleton(
            calendar: calendar,
            timelineDay: day,
            finalizedSessions: []
        )

        let targetCell = try XCTUnwrap(cell(in: skeleton, hour: 14, minute: 0))
        XCTAssertTrue(targetCell.fillSegments.isEmpty)
    }

    func testApplyingLiveOverlayMergesOntoSkeleton() throws {
        let day = date(year: 2026, month: 6, day: 20, hour: 12, minute: 0)
        let started = date(year: 2026, month: 6, day: 20, hour: 14, minute: 0)
        let ended = date(year: 2026, month: 6, day: 20, hour: 14, minute: 10)
        let skeleton = FocusDayTimelineCellGridModel.makeSkeleton(
            calendar: calendar,
            timelineDay: day,
            finalizedSessions: [session(startedAt: started, endedAt: ended)]
        )

        let now = date(year: 2026, month: 6, day: 20, hour: 14, minute: 25)
        let overlayStart = date(year: 2026, month: 6, day: 20, hour: 14, minute: 15)
        let overlay = FocusTimelineLiveOverlay(
            startedAt: overlayStart,
            endsAt: overlayStart.addingTimeInterval(25 * 60),
            remainingSeconds: 20 * 60
        )
        let merged = FocusDayTimelineCellGridModel.applying(
            liveOverlay: overlay,
            to: skeleton,
            now: now,
            calendar: calendar
        )

        let targetCell = try XCTUnwrap(cell(in: merged, hour: 14, minute: 0))
        XCTAssertEqual(targetCell.fillSegments.count, 2)
        XCTAssertTrue(targetCell.fillSegments.contains { !$0.isInProgress })
        XCTAssertTrue(targetCell.fillSegments.contains(where: \.isInProgress))
    }
}
