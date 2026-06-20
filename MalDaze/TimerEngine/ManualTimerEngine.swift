import Foundation

/// 模式 A：从「开始」起 25 分钟工作 → 5 分钟休息 → 再进入下一轮 25 分钟。
final class ManualTimerEngine: TimerEngine {
    var onStateChange: ((TimeState) -> Void)?

    private var workDuration: TimeInterval
    private var restDuration: TimeInterval

    private var tickTimer: Timer?
    private var phaseEnd: Date?
    private var isRestPhase = false
    /// 与 `AppViewModel.formatClock` 一致：仅整秒变化时上报，减少 0.25s 定时器带来的无效 UI 刷新。
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

    /// 计时器是否在跑（未点「停止计时」且 `start()` 已调用）。
    var isTimerRunning: Bool { tickTimer != nil }

    /// 当前是否处于休息段（`start()` 之后的 5 分钟休息内）。 
    var isInRestPhase: Bool { isRestPhase }

    /// 若计时器在跑且处于休息段，返回距该段结束剩余时间；否则为 0（用于测试休息结束后恢复霸屏时长）。
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

    func start() {
        stop()
        isRestPhase = false
        phaseEnd = Date().addingTimeInterval(workDuration)
        emit()
        scheduleTick()
    }

    func stop() {
        tickTimer?.invalidate()
        tickTimer = nil
        phaseEnd = nil
        isRestPhase = false
    }

    /// 用户在休息霸屏上双击小狗：跳过当前休息段，进入下一轮工作段。
    func skipRestPhaseToWork() {
        guard tickTimer != nil, isRestPhase else { return }
        isRestPhase = false
        phaseEnd = Date().addingTimeInterval(workDuration)
        lastEmittedRemainingWholeSeconds = -1
        scheduleTick()
        emit()
    }

    /// 单测或调试：跳过工作段，直接进入休息段并派发 `.resting`（与真实 `tick` 切换后状态一致）。
    func testing_enterRestPhase(remaining: TimeInterval) {
        tickTimer?.invalidate()
        isRestPhase = true
        phaseEnd = Date().addingTimeInterval(remaining)
        scheduleTick()
        emit()
    }

    /// 从持久化快照恢复当前相位，并按 wall clock 追赶到 now。
    func restorePersistedPhase(end: Date, isRestPhase: Bool, now: Date = Date()) {
        tickTimer?.invalidate()
        tickTimer = nil
        self.isRestPhase = isRestPhase
        phaseEnd = end
        lastEmittedRemainingWholeSeconds = -1
        reconcileWallClockFromPersisted(now: now)
        scheduleTick()
        emit()
    }

    private func reconcileWallClockFromPersisted(now: Date) {
        guard var end = phaseEnd else { return }
        while end.timeIntervalSince(now) <= 0 {
            if isRestPhase {
                isRestPhase = false
                end = end.addingTimeInterval(workDuration)
            } else {
                isRestPhase = true
                end = end.addingTimeInterval(restDuration)
            }
        }
        phaseEnd = end
    }

    private func scheduleTick() {
        tickTimer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        tickTimer = t
    }

    private func tick() {
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
            return
        }

        lastEmittedRemainingWholeSeconds = -1
        if isRestPhase {
            isRestPhase = false
            phaseEnd = Date().addingTimeInterval(workDuration)
            onStateChange?(.working(remaining: workDuration))
        } else {
            isRestPhase = true
            phaseEnd = Date().addingTimeInterval(restDuration)
            onStateChange?(.resting(remaining: restDuration))
        }
        lastEmittedRemainingWholeSeconds = max(0, Int((phaseEnd?.timeIntervalSinceNow ?? 0).rounded(.down)))
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
}
