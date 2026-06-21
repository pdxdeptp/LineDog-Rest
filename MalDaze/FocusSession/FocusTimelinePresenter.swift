import Combine
import Foundation

struct FocusTimelineLiveOverlay: Equatable {
    let startedAt: Date
    let endsAt: Date
    let remainingSeconds: Int
}

struct FocusTimelineLiveInput: Equatable {
    let projection: FocusPomodoroInProgress?
    let isManualWorkActive: Bool
}

typealias FocusDayTimelineDaySkeleton = FocusDayTimelineCellGridModel

@MainActor
final class FocusTimelinePresenter: ObservableObject {
    @Published private(set) var displayModel: FocusDayTimelineCellGridModel
    @Published private(set) var sessionCount: Int = 0
    @Published private(set) var totalMinutes: Int = 0
    @Published private(set) var hasActivity: Bool = false

    private(set) var skeletonGeneration = 0
    private(set) var liveOverlayGeneration = 0

    var liveInputProvider: (() -> FocusTimelineLiveInput)?

    private var skeleton: FocusDayTimelineDaySkeleton
    private var timelineDay: Date?
    private var calendar: Calendar = .current
    private var lastFinalizedSessions: [FocusSession] = []
    private var isConsumerVisible = false
    private var liveTickTimer: Timer?
    private var lastPublishedWholeSecond = -1

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        let dayStart = calendar.startOfDay(for: Date())
        self.skeleton = FocusDayTimelineCellGridModel.makeSkeleton(
            calendar: calendar,
            timelineDay: dayStart,
            finalizedSessions: []
        )
        self.displayModel = skeleton
    }

    func setTimelineDay(_ day: Date, calendar: Calendar = .current) {
        timelineDay = day
        self.calendar = calendar
    }

    func rebuildSkeleton(
        finalizedSessions: [FocusSession],
        windowAnchorDates: [Date] = [],
        calendar overrideCalendar: Calendar? = nil
    ) {
        if let overrideCalendar {
            calendar = overrideCalendar
        }
        lastFinalizedSessions = finalizedSessions
        let day = timelineDay ?? calendar.startOfDay(for: Date())
        skeleton = FocusDayTimelineCellGridModel.makeSkeleton(
            calendar: self.calendar,
            timelineDay: day,
            finalizedSessions: finalizedSessions,
            windowAnchorDates: windowAnchorDates
        )
        skeletonGeneration += 1
        updateSummary(from: finalizedSessions)
        publishDisplayModel(overlay: nil)
    }

    func setVisible(_ visible: Bool) {
        guard isConsumerVisible != visible else { return }
        isConsumerVisible = visible
        if visible {
            startLiveTickIfNeeded()
            syncLiveOverlay()
        } else {
            stopLiveTick()
            publishDisplayModel(overlay: nil)
        }
    }

    func syncLiveOverlay(
        projection: FocusPomodoroInProgress? = nil,
        isManualWorkActive: Bool? = nil
    ) {
        guard isConsumerVisible else {
            publishDisplayModel(overlay: nil)
            return
        }

        let input = liveInputProvider?() ?? FocusTimelineLiveInput(
            projection: projection,
            isManualWorkActive: isManualWorkActive ?? false
        )
        let resolvedProjection = projection ?? input.projection
        let resolvedActive = isManualWorkActive ?? input.isManualWorkActive

        guard resolvedActive, let resolvedProjection else {
            publishDisplayModel(overlay: nil)
            return
        }

        let now = Date()
        let overlay = FocusTimelineLiveOverlay(
            startedAt: resolvedProjection.startedAt,
            endsAt: resolvedProjection.endsAt,
            remainingSeconds: resolvedProjection.remainingSeconds
        )
        publishDisplayModel(overlay: overlay, now: now)
    }

    private func updateSummary(from finalizedSessions: [FocusSession]) {
        sessionCount = finalizedSessions.filter { $0.source == .completed }.count
        totalMinutes = finalizedSessions
            .filter { $0.source == .completed }
            .reduce(0) { $0 + $1.durationMinutes }
        hasActivity = !finalizedSessions.isEmpty
    }

    private func publishDisplayModel(overlay: FocusTimelineLiveOverlay?, now: Date = Date()) {
        displayModel = FocusDayTimelineCellGridModel.applying(
            liveOverlay: overlay,
            to: skeleton,
            now: now,
            calendar: calendar
        )
        if overlay != nil {
            hasActivity = true
        }
    }

    private func startLiveTickIfNeeded() {
        stopLiveTick()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.liveTick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        liveTickTimer = timer
    }

    private func stopLiveTick() {
        liveTickTimer?.invalidate()
        liveTickTimer = nil
        lastPublishedWholeSecond = -1
    }

    private func liveTick() {
        guard isConsumerVisible else { return }
        let now = Date()
        let wholeSecond = Int(now.timeIntervalSince1970)
        guard wholeSecond != lastPublishedWholeSecond else { return }
        lastPublishedWholeSecond = wholeSecond
        liveOverlayGeneration += 1
        syncLiveOverlay()
    }
}
