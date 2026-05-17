import Foundation

/// 模式 B：每逢时钟 `:00` 与 `:30` 触发休息；其余时间处于等待下一锚点状态。
final class AutoTimerEngine: TimerEngine {
    private static let restCountdownSlopTolerance: TimeInterval = 0.15

    var onStateChange: ((TimeState) -> Void)?

    private var restDuration: TimeInterval

    init(restDuration: TimeInterval = 5 * 60) {
        self.restDuration = restDuration
    }

    /// 更新下一次进入休息段时的时长（当前休息窗口仍按既有 `phaseEnd` 结束）。
    func setRestDuration(_ duration: TimeInterval) {
        restDuration = duration
    }
    private var tickTimer: Timer?
    private var phaseEnd: Date?
    private var isResting = false
    /// 仅当剩余整秒变化时派发 `.resting`，避免重复 tick 触发 SwiftUI / WindowServer。
    private var lastRestingEmitWholeSeconds: Int?

    var isTimerRunning: Bool { tickTimer != nil }

    /// 是否处于整点/半点触发的休息窗口内。
    var isInScheduledRest: Bool { isResting }

    /// 若处于整点/半点休息窗口内，返回距该窗口结束剩余时间；否则为 0。
    var scheduledRestRemainingOrZero: TimeInterval {
        guard tickTimer != nil, isResting, let end = phaseEnd else { return 0 }
        return max(0, end.timeIntervalSinceNow)
    }

    func start() {
        stop()
        isResting = false
        scheduleWatching()
    }

    func stop() {
        tickTimer?.invalidate()
        tickTimer = nil
        phaseEnd = nil
        isResting = false
    }

    /// 用户在休息霸屏上双击小狗：结束当前整点/半点休息窗口，回到等待下一锚点。
    func skipScheduledRest() {
        guard tickTimer != nil, isResting else { return }
        isResting = false
        phaseEnd = nil
        lastRestingEmitWholeSeconds = nil
        scheduleWatching()
    }

    private func scheduleWatching() {
        tickTimer?.invalidate()
        let anchor = Self.nextHalfHourAnchor(after: Date())
        phaseEnd = anchor
        onStateChange?(.autoWatching(nextAnchor: anchor))

        let delay = max(0, anchor.timeIntervalSinceNow)
        let t = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.beginRest()
        }
        RunLoop.main.add(t, forMode: .common)
        tickTimer = t
    }

    private func beginRest() {
        isResting = true
        phaseEnd = Date().addingTimeInterval(restDuration)
        lastRestingEmitWholeSeconds = max(0, Int(restDuration.rounded(.down)))
        onStateChange?(.resting(remaining: restDuration))
        scheduleRestTick()
    }

    private func scheduleRestTick() {
        tickTimer?.invalidate()
        guard let end = phaseEnd, isResting else { return }
        let remaining = end.timeIntervalSinceNow
        guard remaining > 0 else {
            tickResting()
            return
        }

        let delay = min(1, remaining)
        let t = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.tickResting()
        }
        RunLoop.main.add(t, forMode: .common)
        tickTimer = t
    }

    private func tickResting() {
        guard let end = phaseEnd, isResting else { return }
        let remaining = end.timeIntervalSinceNow
        if remaining > 0 {
            let whole = displayedRestWholeSeconds(for: remaining)
            if whole != lastRestingEmitWholeSeconds {
                lastRestingEmitWholeSeconds = whole
                onStateChange?(.resting(remaining: TimeInterval(whole)))
            }
            scheduleRestTick()
            return
        }
        lastRestingEmitWholeSeconds = nil
        isResting = false
        scheduleWatching()
    }

    private func displayedRestWholeSeconds(for remaining: TimeInterval) -> Int {
        let whole = max(0, Int(remaining.rounded(.down)))
        guard let last = lastRestingEmitWholeSeconds else { return whole }
        let expectedNext = max(0, last - 1)
        guard whole < expectedNext else { return whole }

        let slopAdjusted = max(0, Int((remaining + Self.restCountdownSlopTolerance).rounded(.down)))
        return slopAdjusted >= expectedNext ? expectedNext : whole
    }

    /// 严格晚于 `date` 的下一个 `:00` 或 `:30`（秒与纳秒为 0）。
    static func nextHalfHourAnchor(after date: Date) -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        var anchors: [Date] = []
        for dayOffset in 0..<2 {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: start) else { continue }
            for hour in 0..<24 {
                guard let hourDate = cal.date(byAdding: .hour, value: hour, to: cal.startOfDay(for: day)) else { continue }
                let y = cal.component(.year, from: hourDate)
                let mo = cal.component(.month, from: hourDate)
                let d = cal.component(.day, from: hourDate)
                let h = cal.component(.hour, from: hourDate)
                for minute in [0, 30] {
                    if let t = cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: minute, second: 0, nanosecond: 0)) {
                        anchors.append(t)
                    }
                }
            }
        }
        return anchors.filter { $0 > date }.min() ?? date.addingTimeInterval(30 * 60)
    }
}
