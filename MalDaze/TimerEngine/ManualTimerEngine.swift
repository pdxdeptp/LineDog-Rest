import Foundation

/// 模式 A：从「开始」起 25 分钟工作 → 5 分钟休息 → 再进入下一轮 25 分钟。
final class ManualTimerEngine: TimerEngine {
    var onStateChange: ((TimeState) -> Void)?
    var onPhaseEvent: ((ManualPhaseEvent) -> Void)?

    private var workDuration: TimeInterval
    private var restDuration: TimeInterval

    private var tickTimer: Timer?
    private var phaseEnd: Date?
    private var workPhaseStart: Date?
    private var isRestPhase = false
    /// 与 `AppViewModel.formatClock` 一致：仅整秒变化时上报；one-shot chain 保证 MainActor 唤醒 ≤1 Hz。
    private var lastEmittedRemainingWholeSeconds: Int = -1

    /// 生产环境用默认番茄时长；测试可传入秒级时长。
    init(workDuration: TimeInterval = 25 * 60, restDuration: TimeInterval = 5 * 60) {
        self.workDuration = workDuration
        self.restDuration = restDuration
    }

    var configuredWorkDuration: TimeInterval { workDuration }
    var configuredRestDuration: TimeInterval { restDuration }

    /// 更新下一段工作 / 休息所用时长（当前正在进行的相位仍按进入该相位时的 `phaseEnd` 计时）。
    func setPhaseDurations(work: TimeInterval, rest: TimeInterval) {
        workDuration = work
        restDuration = rest
    }

    /// 计时器是否在跑（`start()` 已调用且未 `stop()`）。
    var isTimerRunning: Bool { tickTimer != nil }

    /// 当前是否处于休息段（`start()` 之后的休息内）。
    var isInRestPhase: Bool { isRestPhase }

    /// 若计时器在跑且处于休息段，返回距该段结束剩余时间；否则为 0。
    var restPhaseRemainingOrZero: TimeInterval {
        guard tickTimer != nil, isRestPhase, let end = phaseEnd else { return 0 }
        return max(0, end.timeIntervalSinceNow)
    }

    /// 若计时器在跑且处于工作段，返回距该段结束剩余时间；否则为 0。
    var workPhaseRemainingOrZero: TimeInterval {
        guard tickTimer != nil, !isRestPhase, let end = phaseEnd else { return 0 }
        return max(0, end.timeIntervalSinceNow)
    }

    var currentPhaseEnd: Date? { phaseEnd }

    var currentWorkPhase: ManualWorkPhase? {
        guard tickTimer != nil, !isRestPhase, let end = phaseEnd, let start = workPhaseStart else { return nil }
        return ManualWorkPhase(startedAt: start, endsAt: end)
    }

    func start() {
        stop(emitStopped: false)
        isRestPhase = false
        let start = Date()
        workPhaseStart = start
        phaseEnd = start.addingTimeInterval(workDuration)
        emitPhaseEvent(.workStarted(start: start, end: phaseEnd!))
        emit()
        scheduleTick()
    }

    func stop() {
        stop(emitStopped: true)
    }

    private func stop(emitStopped: Bool) {
        tickTimer?.invalidate()
        tickTimer = nil
        phaseEnd = nil
        workPhaseStart = nil
        isRestPhase = false
        if emitStopped {
            onPhaseEvent?(.engineStopped)
        }
    }

    /// 用户在休息霸屏上双击小狗：跳过当前休息段，进入下一轮工作段。
    func skipRestPhaseToWork() {
        guard tickTimer != nil, isRestPhase, phaseEnd != nil else { return }
        isRestPhase = false
        let nextStart = Date()
        let nextEnd = nextStart.addingTimeInterval(workDuration)
        workPhaseStart = nextStart
        phaseEnd = nextEnd
        lastEmittedRemainingWholeSeconds = -1
        emitPhaseEvent(.restEnded(nextWorkStart: nextStart, nextWorkEnd: nextEnd))
        emitPhaseEvent(.workStarted(start: nextStart, end: nextEnd))
        scheduleTick()
        emit()
    }

    /// 单测或调试：跳过工作段，直接进入休息段并派发 `.resting`。
    func testing_enterRestPhase(remaining: TimeInterval) {
        tickTimer?.invalidate()
        if let start = workPhaseStart, let end = phaseEnd, !isRestPhase {
            emitPhaseEvent(.workCompleted(start: start, end: end))
        }
        isRestPhase = true
        workPhaseStart = nil
        phaseEnd = Date().addingTimeInterval(remaining)
        emitPhaseEvent(.restStarted(end: phaseEnd!))
        scheduleTick()
        emit()
    }

    /// 从持久化快照恢复当前相位，并按 wall clock 追赶到 now。
    func restorePersistedPhase(end: Date, isRestPhase: Bool, now: Date = Date()) {
        tickTimer?.invalidate()
        tickTimer = nil
        self.isRestPhase = isRestPhase
        phaseEnd = end
        workPhaseStart = isRestPhase ? nil : end.addingTimeInterval(-workDuration)
        lastEmittedRemainingWholeSeconds = -1
        reconcileWallClockFromPersisted(now: now, emitEvents: true)
        scheduleTick()
        emit()
    }

    private func reconcileWallClockFromPersisted(now: Date, emitEvents: Bool) {
        guard var end = phaseEnd else { return }
        while end.timeIntervalSince(now) <= 0 {
            if isRestPhase {
                let nextStart = end
                let nextEnd = nextStart.addingTimeInterval(workDuration)
                isRestPhase = false
                end = nextEnd
                workPhaseStart = nextStart
                if emitEvents {
                    emitPhaseEvent(.restEnded(nextWorkStart: nextStart, nextWorkEnd: nextEnd))
                    emitPhaseEvent(.workStarted(start: nextStart, end: nextEnd))
                }
            } else {
                let workEnd = end
                let workStart = workPhaseStart ?? workEnd.addingTimeInterval(-workDuration)
                isRestPhase = true
                end = workEnd.addingTimeInterval(restDuration)
                workPhaseStart = nil
                if emitEvents {
                    emitPhaseEvent(.workCompleted(start: workStart, end: workEnd))
                    emitPhaseEvent(.restStarted(end: end))
                }
            }
        }
        phaseEnd = end
        if !isRestPhase, workPhaseStart == nil {
            workPhaseStart = end.addingTimeInterval(-workDuration)
            if emitEvents, let start = workPhaseStart {
                emitPhaseEvent(.workStarted(start: start, end: end))
            }
        }
    }

    private func scheduleTick() {
        tickTimer?.invalidate()
        tickTimer = nil
        guard let end = phaseEnd else { return }
        let remaining = end.timeIntervalSinceNow
        guard remaining > 0 else {
            tick()
            return
        }

        let delay = min(1, remaining)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func tick() {
        tickTimer = nil
        guard let end = phaseEnd else { return }
        let remaining = end.timeIntervalSinceNow
        if remaining > 0 {
            let whole = max(0, Int(remaining.rounded(.down)))
            if whole != lastEmittedRemainingWholeSeconds {
                lastEmittedRemainingWholeSeconds = whole
                if isRestPhase {
                    onStateChange?(.resting(remaining: remaining))
                } else {
                    onStateChange?(.working(remaining: remaining))
                }
            }
            scheduleTick()
            return
        }

        lastEmittedRemainingWholeSeconds = -1
        if isRestPhase {
            let nextStart = Date()
            let nextEnd = nextStart.addingTimeInterval(workDuration)
            isRestPhase = false
            phaseEnd = nextEnd
            workPhaseStart = nextStart
            emitPhaseEvent(.restEnded(nextWorkStart: nextStart, nextWorkEnd: nextEnd))
            emitPhaseEvent(.workStarted(start: nextStart, end: nextEnd))
            onStateChange?(.working(remaining: workDuration))
        } else {
            let workEnd = end
            let workStart = workPhaseStart ?? workEnd.addingTimeInterval(-workDuration)
            isRestPhase = true
            phaseEnd = Date().addingTimeInterval(restDuration)
            workPhaseStart = nil
            emitPhaseEvent(.workCompleted(start: workStart, end: workEnd))
            emitPhaseEvent(.restStarted(end: phaseEnd!))
            onStateChange?(.resting(remaining: restDuration))
        }
        lastEmittedRemainingWholeSeconds = max(0, Int((phaseEnd?.timeIntervalSinceNow ?? 0).rounded(.down)))
        scheduleTick()
    }

    private func emit() {
        guard let end = phaseEnd else { return }
        let remaining = max(0, end.timeIntervalSinceNow)
        lastEmittedRemainingWholeSeconds = max(0, Int(remaining.rounded(.down)))
        if isRestPhase {
            onStateChange?(.resting(remaining: remaining))
        } else {
            onStateChange?(.working(remaining: remaining))
        }
    }

    private func emitPhaseEvent(_ event: ManualPhaseEvent) {
        onPhaseEvent?(event)
    }
}
