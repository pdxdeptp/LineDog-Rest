import Foundation

/// 模式 B：每逢时钟 `:00` 与 `:30` 触发 5 分钟休息；其余时间处于等待下一锚点状态。
final class AutoTimerEngine: TimerEngine {
    var onStateChange: ((TimeState) -> Void)?

    private let restDuration: TimeInterval = 5 * 60
    private var tickTimer: Timer?
    private var phaseEnd: Date?
    private var isResting = false

    var isTimerRunning: Bool { tickTimer != nil }

    /// 是否处于整点/半点触发的休息窗口内。
    var isInScheduledRest: Bool { isResting }

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

    private func scheduleWatching() {
        tickTimer?.invalidate()
        let anchor = Self.nextHalfHourAnchor(after: Date())
        phaseEnd = anchor
        onStateChange?(.autoWatching(nextAnchor: anchor))

        let t = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tickWatching()
        }
        RunLoop.main.add(t, forMode: .common)
        tickTimer = t
    }

    private func tickWatching() {
        if isResting {
            tickResting()
            return
        }
        guard let anchor = phaseEnd else { return }
        if Date() >= anchor {
            beginRest()
            return
        }
        onStateChange?(.autoWatching(nextAnchor: anchor))
    }

    private func beginRest() {
        isResting = true
        phaseEnd = Date().addingTimeInterval(restDuration)
        onStateChange?(.resting(remaining: restDuration))

        tickTimer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tickResting()
        }
        RunLoop.main.add(t, forMode: .common)
        tickTimer = t
    }

    private func tickResting() {
        guard let end = phaseEnd, isResting else { return }
        let remaining = end.timeIntervalSinceNow
        if remaining > 0 {
            onStateChange?(.resting(remaining: remaining))
            return
        }
        isResting = false
        scheduleWatching()
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
