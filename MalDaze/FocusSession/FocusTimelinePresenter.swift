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
    enum LiveSchedulingPhase: Equatable {
        case hidden
        case idle
        case live
    }

    @Published private(set) var displayModel: FocusDayTimelineCellGridModel
    @Published private(set) var sessionCount: Int = 0
    @Published private(set) var totalMinutes: Int = 0
    @Published private(set) var hasActivity: Bool = false

    private(set) var skeletonGeneration = 0
    private(set) var liveOverlayGeneration = 0
    private(set) var displayModelPublishCount = 0
    private(set) var schedulingPhase: LiveSchedulingPhase = .hidden

    var liveInputProvider: (() -> FocusTimelineLiveInput)?

    private var skeleton: FocusDayTimelineDaySkeleton
    private var timelineDay: Date?
    private var calendar: Calendar = .current
    private var lastFinalizedSessions: [FocusSession] = []
    private var isConsumerVisible = false
    private var hasActiveInProgressOverlay = false
    private var liveTickTimer: Timer?

    var isLiveTickActive: Bool { liveTickTimer != nil }

    /// Unit tests set this to verify timer scheduling without relying on the run loop.
    static var allowsLiveTickSchedulingInTests = false

    private static var isRunningUnderXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

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
        refreshLiveScheduling()
    }

    /// SwiftUI visibility hint; pairs with dashboard quiescence in a later change.
    func setVisible(_ visible: Bool) {
        setConsumerVisible(visible)
    }

    func setConsumerVisible(_ visible: Bool) {
        guard isConsumerVisible != visible else { return }
        isConsumerVisible = visible
        if visible {
            refreshLiveScheduling()
            syncLiveOverlay()
        } else {
            enterHidden()
        }
    }

    /// Dashboard hide / quiescence entry point (Change 2 coordinator).
    func enterHidden() {
        isConsumerVisible = false
        stopLiveTick()
        clearInProgressOverlayIfNeeded()
        schedulingPhase = .hidden
    }

    func refreshLiveScheduling(
        projection: FocusPomodoroInProgress? = nil,
        isManualWorkActive: Bool? = nil
    ) {
        guard isConsumerVisible else {
            stopLiveTick()
            schedulingPhase = .hidden
            return
        }

        let input = resolvedLiveInput(projection: projection, isManualWorkActive: isManualWorkActive)
        if input.isManualWorkActive, input.projection != nil {
            schedulingPhase = .live
            scheduleLiveTickIfNeeded()
        } else {
            schedulingPhase = .idle
            stopLiveTick()
        }
    }

    func syncLiveOverlay(
        projection: FocusPomodoroInProgress? = nil,
        isManualWorkActive: Bool? = nil
    ) {
        guard isConsumerVisible else {
            clearInProgressOverlayIfNeeded()
            return
        }

        let input = resolvedLiveInput(projection: projection, isManualWorkActive: isManualWorkActive)
        let resolvedProjection = projection ?? input.projection
        let resolvedActive = isManualWorkActive ?? input.isManualWorkActive

        refreshLiveScheduling(projection: resolvedProjection, isManualWorkActive: resolvedActive)

        guard resolvedActive, let resolvedProjection else {
            clearInProgressOverlayIfNeeded()
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

    private func resolvedLiveInput(
        projection: FocusPomodoroInProgress?,
        isManualWorkActive: Bool?
    ) -> FocusTimelineLiveInput {
        if projection != nil || isManualWorkActive != nil {
            return FocusTimelineLiveInput(
                projection: projection,
                isManualWorkActive: isManualWorkActive ?? false
            )
        }
        return liveInputProvider?() ?? FocusTimelineLiveInput(projection: nil, isManualWorkActive: false)
    }

    private func updateSummary(from finalizedSessions: [FocusSession]) {
        sessionCount = finalizedSessions.filter { $0.source == .completed }.count
        totalMinutes = finalizedSessions
            .filter { $0.source == .completed }
            .reduce(0) { $0 + $1.durationMinutes }
        hasActivity = !finalizedSessions.isEmpty
    }

    private func publishDisplayModel(overlay: FocusTimelineLiveOverlay?, now: Date = Date()) {
        let nextModel = FocusDayTimelineCellGridModel.applying(
            liveOverlay: overlay,
            to: skeleton,
            now: now,
            calendar: calendar
        )
        guard nextModel != displayModel else { return }
        displayModel = nextModel
        displayModelPublishCount += 1
        hasActiveInProgressOverlay = nextModel.cells.contains {
            $0.fillSegments.contains(where: \.isInProgress)
        }
        if overlay != nil {
            hasActivity = true
        }
    }

    private func clearInProgressOverlayIfNeeded() {
        guard hasActiveInProgressOverlay else { return }
        publishDisplayModel(overlay: nil)
    }

    private func scheduleLiveTickIfNeeded() {
        if Self.isRunningUnderXCTest, !Self.allowsLiveTickSchedulingInTests {
            return
        }
        guard liveTickTimer == nil else { return }
        scheduleNextLiveTick()
    }

    private func scheduleNextLiveTick() {
        if Self.isRunningUnderXCTest, !Self.allowsLiveTickSchedulingInTests {
            return
        }
        liveTickTimer?.invalidate()
        liveTickTimer = nil
        guard isConsumerVisible, schedulingPhase == .live else { return }

        let now = Date()
        let nextWholeSecond = floor(now.timeIntervalSince1970) + 1
        let delay = max(0.01, nextWholeSecond - now.timeIntervalSince1970)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.liveTickFired()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        liveTickTimer = timer
    }

    private func stopLiveTick() {
        liveTickTimer?.invalidate()
        liveTickTimer = nil
    }

    private func liveTickFired() {
        liveTickTimer = nil
        guard isConsumerVisible, schedulingPhase == .live else { return }
        liveOverlayGeneration += 1
        syncLiveOverlay()
        scheduleNextLiveTick()
    }
}
