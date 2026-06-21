import Foundation

struct FocusDayTimelineFillSegment: Equatable, Identifiable {
    let sessionID: UUID?
    let isInProgress: Bool
    let source: FocusSessionSource?
    let sessionStartedAt: Date
    let sessionEndedAt: Date
    let overlapStart: Date
    let overlapEnd: Date
    let startFraction: Double
    let widthFraction: Double
    let pomodoroPhaseEndsAt: Date?
    let pomodoroRemainingSeconds: Int?

    var id: String {
        let owner = sessionID?.uuidString ?? "in-progress"
        return "\(owner)-\(Int(overlapStart.timeIntervalSince1970))"
    }

    var durationMinutes: Int {
        FocusSessionFormatting.displayMinutes(
            fromSeconds: FocusSessionFormatting.durationSeconds(from: sessionStartedAt, to: sessionEndedAt)
        )
    }

    var isSuccessful: Bool {
        isInProgress || source == .completed
    }
}

struct FocusDayTimelineFailedMarker: Equatable, Identifiable {
    let sessionID: UUID
    let sessionStartedAt: Date
    let sessionEndedAt: Date
    let startFraction: Double

    var id: String { sessionID.uuidString }
}

struct FocusDayTimelineCell: Equatable {
    let index: Int
    let start: Date
    let end: Date
    let fillSegments: [FocusDayTimelineFillSegment]
    let failedMarkers: [FocusDayTimelineFailedMarker]
}

struct FocusDayTimelineCellGridModel: Equatable {
    static let cellDurationSeconds: TimeInterval = 30 * 60
    static let columnCount = 16
    static let baseStartHour = 8
    static let baseEndHour = 24
    static let defaultTickHours = [8, 12, 16, 20, 24]
    static let minFillWidthPoints: CGFloat = 2
    static let failedMarkerWidthPoints: CGFloat = 4
    static let defaultVisibleCellCount = (baseEndHour - baseStartHour) * 2

    let visibleStart: Date
    let visibleEnd: Date
    let cells: [FocusDayTimelineCell]
    let tickHours: [Int]

    var rowCount: Int {
        guard !cells.isEmpty else { return 0 }
        return (cells.count + Self.columnCount - 1) / Self.columnCount
    }

    static func make(
        calendar: Calendar = .current,
        now: Date,
        timelineDay: Date? = nil,
        finalizedSessions: [FocusSession],
        inProgress: FocusSessionInProgress?
    ) -> FocusDayTimelineCellGridModel {
        let day = timelineDay ?? now
        let windowAnchors = inProgress.map { [$0.startedAt] } ?? []
        let skeleton = makeSkeleton(
            calendar: calendar,
            timelineDay: day,
            finalizedSessions: finalizedSessions,
            windowAnchorDates: windowAnchors
        )
        guard let inProgress else { return skeleton }
        let overlay = FocusTimelineLiveOverlay(
            startedAt: inProgress.startedAt,
            endsAt: inProgress.endsAt,
            remainingSeconds: inProgress.remainingSeconds
        )
        return applying(liveOverlay: overlay, to: skeleton, now: now, calendar: calendar)
    }

    static func makeSkeleton(
        calendar: Calendar = .current,
        timelineDay: Date,
        finalizedSessions: [FocusSession],
        windowAnchorDates: [Date] = []
    ) -> FocusDayTimelineDaySkeleton {
        let dayStart = calendar.startOfDay(for: timelineDay)
        let baseStart = calendar.date(byAdding: .hour, value: baseStartHour, to: dayStart)!
        let baseEnd = calendar.date(byAdding: .hour, value: baseEndHour, to: dayStart)!
        let offHours = DateInterval(start: dayStart, end: baseStart)

        let successIntervals = mappedFinalizedSuccessIntervals(
            calendar: calendar,
            dayStart: dayStart,
            baseEnd: baseEnd,
            finalizedSessions: finalizedSessions
        )
        let failedStarts = mappedFailedStarts(
            calendar: calendar,
            dayStart: dayStart,
            baseEnd: baseEnd,
            finalizedSessions: finalizedSessions
        )
        let anchorDisplayStarts = windowAnchorDates.compactMap {
            mapTimestampToDisplayTimeline($0, dayStart: dayStart, baseEnd: baseEnd, calendar: calendar)
        }

        let visibleStart: Date
        let earliestOffHours = earliestTime(
            within: offHours,
            among: successIntervals.map(\.displayStart) + failedStarts.map(\.displayStart) + anchorDisplayStarts
        )
        if let earliestOffHours {
            visibleStart = max(dayStart, floorToCellBoundary(earliestOffHours, calendar: calendar))
        } else {
            visibleStart = baseStart
        }

        return buildGridModel(
            calendar: calendar,
            visibleStart: visibleStart,
            visibleEnd: baseEnd,
            successIntervals: successIntervals,
            failedStarts: failedStarts
        )
    }

    static func applying(
        liveOverlay: FocusTimelineLiveOverlay?,
        to skeleton: FocusDayTimelineDaySkeleton,
        now: Date,
        calendar: Calendar = .current
    ) -> FocusDayTimelineCellGridModel {
        guard let liveOverlay else { return skeleton }

        let dayStart = calendar.startOfDay(for: skeleton.visibleStart)
        let baseEnd = skeleton.visibleEnd
        var overlayIntervals: [MappedSuccessInterval] = []
        appendMappedSuccess(
            sessionID: nil,
            isInProgress: true,
            source: nil,
            sessionStartedAt: liveOverlay.startedAt,
            sessionEndedAt: min(now, liveOverlay.endsAt),
            pomodoroPhaseEndsAt: liveOverlay.endsAt,
            pomodoroRemainingSeconds: liveOverlay.remainingSeconds,
            dayStart: dayStart,
            baseEnd: baseEnd,
            calendar: calendar,
            into: &overlayIntervals
        )
        guard let overlayInterval = overlayIntervals.first else {
            return skeleton
        }

        let cells = skeleton.cells.map { cell in
            let cellInterval = DateInterval(start: cell.start, end: cell.end)
            let overlaySegments = successFillSegments(for: cellInterval, mappedIntervals: [overlayInterval])
            guard !overlaySegments.isEmpty else { return cell }
            return FocusDayTimelineCell(
                index: cell.index,
                start: cell.start,
                end: cell.end,
                fillSegments: cell.fillSegments + overlaySegments,
                failedMarkers: cell.failedMarkers
            )
        }

        return FocusDayTimelineCellGridModel(
            visibleStart: skeleton.visibleStart,
            visibleEnd: skeleton.visibleEnd,
            cells: cells,
            tickHours: skeleton.tickHours
        )
    }

    private static func buildGridModel(
        calendar: Calendar,
        visibleStart: Date,
        visibleEnd: Date,
        successIntervals: [MappedSuccessInterval],
        failedStarts: [MappedFailedStart]
    ) -> FocusDayTimelineCellGridModel {
        let cellCount = max(0, Int(visibleEnd.timeIntervalSince(visibleStart) / cellDurationSeconds))
        var cells: [FocusDayTimelineCell] = []
        cells.reserveCapacity(cellCount)

        for index in 0..<cellCount {
            let cellStart = visibleStart.addingTimeInterval(TimeInterval(index) * cellDurationSeconds)
            let cellEnd = cellStart.addingTimeInterval(cellDurationSeconds)
            let cellInterval = DateInterval(start: cellStart, end: cellEnd)
            cells.append(
                FocusDayTimelineCell(
                    index: index,
                    start: cellStart,
                    end: cellEnd,
                    fillSegments: successFillSegments(for: cellInterval, mappedIntervals: successIntervals),
                    failedMarkers: failedMarkers(for: cellInterval, failedStarts: failedStarts)
                )
            )
        }

        return FocusDayTimelineCellGridModel(
            visibleStart: visibleStart,
            visibleEnd: visibleEnd,
            cells: cells,
            tickHours: tickHours(from: visibleStart, to: visibleEnd, calendar: calendar)
        )
    }

    // MARK: - Interval helpers

    private struct MappedSuccessInterval: Equatable {
        let sessionID: UUID?
        let isInProgress: Bool
        let source: FocusSessionSource?
        let sessionStartedAt: Date
        let sessionEndedAt: Date
        let displayStart: Date
        let displayEnd: Date
        let pomodoroPhaseEndsAt: Date?
        let pomodoroRemainingSeconds: Int?
    }

    private struct MappedFailedStart: Equatable {
        let sessionID: UUID
        let sessionStartedAt: Date
        let sessionEndedAt: Date
        let displayStart: Date
    }

    private static func mappedFinalizedSuccessIntervals(
        calendar: Calendar,
        dayStart: Date,
        baseEnd: Date,
        finalizedSessions: [FocusSession]
    ) -> [MappedSuccessInterval] {
        var mapped: [MappedSuccessInterval] = []
        for session in finalizedSessions where session.source == .completed {
            appendMappedSuccess(
                sessionID: session.id,
                isInProgress: false,
                source: session.source,
                sessionStartedAt: session.startedAt,
                sessionEndedAt: session.endedAt,
                dayStart: dayStart,
                baseEnd: baseEnd,
                calendar: calendar,
                into: &mapped
            )
        }
        return mapped.filter { $0.displayEnd > $0.displayStart }
    }

    private static func mappedFailedStarts(
        calendar: Calendar,
        dayStart: Date,
        baseEnd: Date,
        finalizedSessions: [FocusSession]
    ) -> [MappedFailedStart] {
        finalizedSessions.compactMap { session in
            guard session.source == .stoppedEarly else { return nil }
            guard let displayStart = mapTimestampToDisplayTimeline(
                session.startedAt,
                dayStart: dayStart,
                baseEnd: baseEnd,
                calendar: calendar
            ) else {
                return nil
            }
            return MappedFailedStart(
                sessionID: session.id,
                sessionStartedAt: session.startedAt,
                sessionEndedAt: session.endedAt,
                displayStart: displayStart
            )
        }
    }

    private static func appendMappedSuccess(
        sessionID: UUID?,
        isInProgress: Bool,
        source: FocusSessionSource?,
        sessionStartedAt: Date,
        sessionEndedAt: Date,
        pomodoroPhaseEndsAt: Date? = nil,
        pomodoroRemainingSeconds: Int? = nil,
        dayStart: Date,
        baseEnd: Date,
        calendar: Calendar,
        into mapped: inout [MappedSuccessInterval]
    ) {
        guard sessionStartedAt <= sessionEndedAt else {
            assertionFailure("Focus timeline interval start after end")
            return
        }
        let interval = DateInterval(start: sessionStartedAt, end: sessionEndedAt)
        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let nextDayOffHoursEnd = calendar.date(byAdding: .hour, value: baseStartHour, to: nextDayStart)!

        let sameDayEnd = min(interval.end, baseEnd)
        if sameDayEnd > interval.start {
            mapped.append(
                MappedSuccessInterval(
                    sessionID: sessionID,
                    isInProgress: isInProgress,
                    source: source,
                    sessionStartedAt: sessionStartedAt,
                    sessionEndedAt: sessionEndedAt,
                    displayStart: max(interval.start, dayStart),
                    displayEnd: sameDayEnd,
                    pomodoroPhaseEndsAt: pomodoroPhaseEndsAt,
                    pomodoroRemainingSeconds: pomodoroRemainingSeconds
                )
            )
        }

        if interval.end > nextDayStart {
            let continuationStart = max(interval.start, nextDayStart)
            let continuationEnd = min(interval.end, nextDayOffHoursEnd)
            if continuationEnd > continuationStart {
                let offset = continuationStart.timeIntervalSince(nextDayStart)
                let mappedStart = dayStart.addingTimeInterval(offset)
                let mappedEnd = dayStart.addingTimeInterval(continuationEnd.timeIntervalSince(nextDayStart))
                mapped.append(
                    MappedSuccessInterval(
                        sessionID: sessionID,
                        isInProgress: isInProgress,
                        source: source,
                        sessionStartedAt: sessionStartedAt,
                        sessionEndedAt: sessionEndedAt,
                        displayStart: mappedStart,
                        displayEnd: mappedEnd,
                        pomodoroPhaseEndsAt: pomodoroPhaseEndsAt,
                        pomodoroRemainingSeconds: pomodoroRemainingSeconds
                    )
                )
            }
        }
    }

    private static func mapTimestampToDisplayTimeline(
        _ timestamp: Date,
        dayStart: Date,
        baseEnd: Date,
        calendar: Calendar
    ) -> Date? {
        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let nextDayOffHoursEnd = calendar.date(byAdding: .hour, value: baseStartHour, to: nextDayStart)!

        if timestamp >= dayStart && timestamp < baseEnd {
            return timestamp
        }
        if timestamp >= nextDayStart && timestamp < nextDayOffHoursEnd {
            return dayStart.addingTimeInterval(timestamp.timeIntervalSince(nextDayStart))
        }
        return nil
    }

    private static func earliestTime(within window: DateInterval, among times: [Date]) -> Date? {
        var earliest: Date?
        for time in times where window.contains(time) {
            if earliest == nil || time < earliest! {
                earliest = time
            }
        }
        return earliest
    }

    private static func floorToCellBoundary(_ date: Date, calendar: Calendar) -> Date {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = parts.minute ?? 0
        let flooredMinute = (minute / 30) * 30
        var floored = parts
        floored.minute = flooredMinute
        floored.second = 0
        floored.nanosecond = 0
        return calendar.date(from: floored) ?? date
    }

    private static func successFillSegments(
        for cell: DateInterval,
        mappedIntervals: [MappedSuccessInterval]
    ) -> [FocusDayTimelineFillSegment] {
        let cellDuration = cell.duration
        guard cellDuration > 0 else { return [] }

        var segments: [FocusDayTimelineFillSegment] = []
        for mapped in mappedIntervals {
            let displayInterval = DateInterval(start: mapped.displayStart, end: mapped.displayEnd)
            guard let overlap = displayInterval.intersection(with: cell), overlap.duration > 0 else { continue }
            let startFraction = overlap.start.timeIntervalSince(cell.start) / cellDuration
            let widthFraction = overlap.end.timeIntervalSince(overlap.start) / cellDuration
            segments.append(
                FocusDayTimelineFillSegment(
                    sessionID: mapped.sessionID,
                    isInProgress: mapped.isInProgress,
                    source: mapped.source,
                    sessionStartedAt: mapped.sessionStartedAt,
                    sessionEndedAt: mapped.sessionEndedAt,
                    overlapStart: overlap.start,
                    overlapEnd: overlap.end,
                    startFraction: startFraction,
                    widthFraction: widthFraction,
                    pomodoroPhaseEndsAt: mapped.pomodoroPhaseEndsAt,
                    pomodoroRemainingSeconds: mapped.pomodoroRemainingSeconds
                )
            )
        }
        return segments
    }

    private static func failedMarkers(
        for cell: DateInterval,
        failedStarts: [MappedFailedStart]
    ) -> [FocusDayTimelineFailedMarker] {
        let cellDuration = cell.duration
        guard cellDuration > 0 else { return [] }

        return failedStarts.compactMap { failed in
            guard cell.contains(failed.displayStart) else { return nil }
            let startFraction = failed.displayStart.timeIntervalSince(cell.start) / cellDuration
            return FocusDayTimelineFailedMarker(
                sessionID: failed.sessionID,
                sessionStartedAt: failed.sessionStartedAt,
                sessionEndedAt: failed.sessionEndedAt,
                startFraction: startFraction
            )
        }
    }

    private static func tickHours(from visibleStart: Date, to visibleEnd: Date, calendar: Calendar) -> [Int] {
        let dayStart = calendar.startOfDay(for: visibleStart)
        var hours: [Int] = []
        for hour in stride(from: 0, through: baseEndHour, by: 2) {
            guard let marker = calendar.date(byAdding: .hour, value: hour, to: dayStart) else { continue }
            if marker >= visibleStart && marker <= visibleEnd {
                hours.append(hour)
            }
        }
        if hours.last != baseEndHour, visibleEnd >= calendar.date(byAdding: .hour, value: baseEndHour, to: dayStart)! {
            hours.append(baseEndHour)
        }
        return hours.isEmpty ? defaultTickHours : hours
    }

    static func dayStart(fromISODate iso: String, calendar: Calendar = .current) -> Date? {
        let parts = iso.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}

enum FocusDayTimelineFormatting {
    static func dateLine(_ date: Date, calendar: Calendar = .current) -> String {
        FocusSessionFormatting.isoDate(date, calendar: calendar)
    }

    static func timeRangeLine(start: Date, end: Date, calendar: Calendar = .current) -> String {
        "\(FocusSessionFormatting.clockTime(start, calendar: calendar)) – \(FocusSessionFormatting.clockTime(end, calendar: calendar))"
    }

    static func sourceLabel(for segment: FocusDayTimelineFillSegment) -> String {
        if segment.isInProgress {
            return "进行中"
        }
        switch segment.source {
        case .completed:
            return "完整番茄"
        case .stoppedEarly:
            return "已放弃"
        case .none:
            return "专注"
        }
    }

    static func failedMarkerLabel(for marker: FocusDayTimelineFailedMarker, calendar: Calendar = .current) -> String {
        let date = dateLine(marker.sessionStartedAt, calendar: calendar)
        let start = FocusSessionFormatting.clockTime(marker.sessionStartedAt, calendar: calendar)
        let minutes = FocusSessionFormatting.displayMinutes(
            fromSeconds: FocusSessionFormatting.durationSeconds(
                from: marker.sessionStartedAt,
                to: marker.sessionEndedAt
            )
        )
        return "\(date) · \(start) 起 · 已放弃 · \(minutes) 分钟"
    }

    static func hoverHelp(for segment: FocusDayTimelineFillSegment, calendar: Calendar = .current) -> String {
        let date = dateLine(segment.sessionStartedAt, calendar: calendar)
        let range = timeRangeLine(start: segment.sessionStartedAt, end: segment.sessionEndedAt, calendar: calendar)
        return "\(date) · \(range) · \(FocusDayTimelineFormatting.sourceLabel(for: segment))"
    }
}
