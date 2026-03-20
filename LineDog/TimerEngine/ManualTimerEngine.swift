import Foundation

/// 模式 A：从「开始」起 25 分钟工作 → 5 分钟休息 → 再进入下一轮 25 分钟。
final class ManualTimerEngine: TimerEngine {
    var onStateChange: ((TimeState) -> Void)?

    private let workDuration: TimeInterval
    private let restDuration: TimeInterval

    private var tickTimer: Timer?
    private var phaseEnd: Date?
    private var isRestPhase = false

    /// 生产环境用默认番茄时长；测试可传入秒级时长。
    init(workDuration: TimeInterval = 25 * 60, restDuration: TimeInterval = 5 * 60) {
        self.workDuration = workDuration
        self.restDuration = restDuration
    }

    /// 计时器是否在跑（未点「停止计时」且 `start()` 已调用）。
    var isTimerRunning: Bool { tickTimer != nil }

    /// 当前是否处于休息段（`start()` 之后的 5 分钟休息内）。 
    var isInRestPhase: Bool { isRestPhase }

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

    /// 单测或调试：跳过工作段，直接进入休息段并派发 `.resting`（与真实 `tick` 切换后状态一致）。
    func testing_enterRestPhase(remaining: TimeInterval) {
        tickTimer?.invalidate()
        isRestPhase = true
        phaseEnd = Date().addingTimeInterval(remaining)
        scheduleTick()
        emit()
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
            if isRestPhase {
                onStateChange?(.resting(remaining: remaining))
            } else {
                onStateChange?(.working(remaining: remaining))
            }
            return
        }

        if isRestPhase {
            isRestPhase = false
            phaseEnd = Date().addingTimeInterval(workDuration)
            onStateChange?(.working(remaining: workDuration))
        } else {
            isRestPhase = true
            phaseEnd = Date().addingTimeInterval(restDuration)
            onStateChange?(.resting(remaining: restDuration))
        }
    }

    private func emit() {
        guard let end = phaseEnd else { return }
        let remaining = max(0, end.timeIntervalSinceNow)
        if isRestPhase {
            onStateChange?(.resting(remaining: remaining))
        } else {
            onStateChange?(.working(remaining: remaining))
        }
    }
}
