import Foundation

@MainActor
final class ManualFocusCoordinator {
    private let store: FocusSessionStore
    private var activeWorkPhaseStart: Date?

    init(store: FocusSessionStore) {
        self.store = store
    }

    func handle(_ event: ManualPhaseEvent, calendar: Calendar = .current) {
        switch event {
        case .workStarted(let start, _):
            activeWorkPhaseStart = start
        case .workCompleted(let start, let end):
            appendFinalized(startedAt: start, endedAt: end, source: .completed, calendar: calendar)
            activeWorkPhaseStart = nil
        case .restStarted, .restEnded:
            activeWorkPhaseStart = nil
        case .engineStopped:
            break
        }
    }

    func abandonCurrentWorkPhase(
        now: Date = Date(),
        manualEngine: ManualTimerEngine,
        calendar: Calendar = .current
    ) {
        let start = activeWorkPhaseStart ?? manualEngine.currentWorkPhase?.startedAt
        guard let start, start < now else { return }
        appendFinalized(startedAt: start, endedAt: now, source: .stoppedEarly, calendar: calendar)
        activeWorkPhaseStart = nil
    }

    func inProgressProjection(
        now: Date,
        manualEngine: ManualTimerEngine,
        isManualSessionActive: Bool
    ) -> FocusPomodoroInProgress? {
        guard isManualSessionActive,
              manualEngine.isTimerRunning,
              !manualEngine.isInRestPhase,
              let phase = manualEngine.currentWorkPhase else {
            return nil
        }
        let effectiveNow = min(now, phase.endsAt)
        return FocusPomodoroInProgress(
            startedAt: phase.startedAt,
            endsAt: phase.endsAt,
            remainingSeconds: phase.remainingSeconds(at: now),
            elapsedSeconds: FocusSessionFormatting.elapsedWholeSeconds(from: phase.startedAt, to: effectiveNow)
        )
    }

    func refreshTodaySummary(now: Date = Date(), calendar: Calendar = .current) -> (
        sessions: [FocusSession],
        count: Int,
        minutes: Int
    ) {
        let sessions = store.todaySessions(calendar: calendar, now: now)
        let count = store.todayPomodoroCount(calendar: calendar, now: now)
        let minutes = store.todayCompletedMinutes(calendar: calendar, now: now)
        return (sessions, count, minutes)
    }

    func updateSession(id: UUID, startedAt: Date, endedAt: Date, calendar: Calendar = .current) throws -> FocusSession {
        try store.updateSession(id: id, startedAt: startedAt, endedAt: endedAt, calendar: calendar)
    }

    func deleteSession(id: UUID) throws {
        try store.deleteSession(id: id)
    }

    private func appendFinalized(
        startedAt: Date,
        endedAt: Date,
        source: FocusSessionSource,
        calendar: Calendar
    ) {
        do {
            _ = try store.appendFinalized(startedAt: startedAt, endedAt: endedAt, source: source, calendar: calendar)
        } catch {
            // Focus persistence failure must not block timer UX.
        }
    }
}
