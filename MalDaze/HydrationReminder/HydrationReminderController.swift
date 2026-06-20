import AppKit

/// 周期性喝水提醒：按用户设定间隔（默认 90 分钟）弹出中央浮层，提供「已喝水 💧」/「稍后提醒」操作。
/// 浮层展示委托 `MalDazeTransientOverlayPresenter`；start()/cancel() 的调用权完全归 AppViewModel。
@MainActor
final class HydrationReminderController: NSObject {

    /// 已调度（计时中或浮层待操作）为 `true`；调用 `cancel()` 后变 `false`。
    var onStateChanged: ((Bool) -> Void)?

    private let overlayPresenter: MalDazeTransientOverlayPresenting
    private var pendingTimer: Timer?

    init(overlayPresenter: MalDazeTransientOverlayPresenting) {
        self.overlayPresenter = overlayPresenter
        super.init()
    }

    // MARK: - Public API

    func start() {
        cancel()
        schedulePendingTimer(after: TimeInterval(Self.configuredIntervalMinutes() * 60))
        onStateChanged?(true)
    }

    func cancel() {
        pendingTimer?.invalidate()
        pendingTimer = nil
        overlayPresenter.dismissHydrationReminder()
        onStateChanged?(false)
    }

    /// 测试用：立即弹出喝水浮层（**绕过安静时段**，否则当前在安静窗口内会静默无 UI，像「点了没反应」）。
    func testing_fireNow() {
        fireReminder(bypassQuietHours: true)
    }

    // MARK: - Timer

    static func configuredIntervalMinutes() -> Int {
        let v = UserDefaults.standard.integer(forKey: MalDazeDefaults.hydrationReminderIntervalMinutes)
        if v < 15 { return 90 }
        return min(240, v)
    }

    // MARK: - Quiet hours

    /// 返回当前是否处于用户配置的安静时段（如 21:00–08:00）。
    static func isInQuietHours() -> Bool {
        guard UserDefaults.standard.bool(forKey: MalDazeDefaults.hydrationQuietHoursEnabled) else { return false }
        let startMins = quietStartMinutes()
        let resumeMins = quietResumeMinutes()
        let cal = Calendar.current
        let now = Date()
        let nowMins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        if startMins > resumeMins {
            return nowMins >= startMins || nowMins < resumeMins
        } else {
            return nowMins >= startMins && nowMins < resumeMins
        }
    }

    /// 距离安静时段结束（恢复时间）还有多少秒。
    static func secondsUntilResume() -> TimeInterval {
        let resumeMins = quietResumeMinutes()
        let cal = Calendar.current
        let now = Date()
        let nowSecs = cal.component(.hour, from: now) * 3600
            + cal.component(.minute, from: now) * 60
            + cal.component(.second, from: now)
        let resumeSecs = resumeMins * 60
        if resumeSecs > nowSecs {
            return TimeInterval(resumeSecs - nowSecs)
        } else {
            return TimeInterval(86400 - nowSecs + resumeSecs)
        }
    }

    static func quietStartMinutes() -> Int {
        let v = UserDefaults.standard.integer(forKey: MalDazeDefaults.hydrationQuietStartMinutes)
        return v > 0 ? v : 1260
    }

    static func quietResumeMinutes() -> Int {
        let v = UserDefaults.standard.integer(forKey: MalDazeDefaults.hydrationQuietResumeMinutes)
        return v > 0 ? v : 480
    }

    private func schedulePendingTimer(after seconds: TimeInterval) {
        pendingTimer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fireReminder(bypassQuietHours: false)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        pendingTimer = t
    }

    private func fireReminder(bypassQuietHours: Bool = false) {
        pendingTimer = nil
        if !bypassQuietHours, Self.isInQuietHours() {
            let delay = Self.secondsUntilResume()
            schedulePendingTimer(after: delay)
            return
        }
        overlayPresenter.dismissHydrationReminder()
        let messages = [
            "我是一个小渴鬼🤔，你也应该喝点水？",
            "*舔舔嘴唇* 🤍 时间喝水～",
            "喝水喝水喝水！💧",
            "主人，喝水啦～",
        ]
        let message = messages.randomElement() ?? messages[0]
        overlayPresenter.presentHydrationReminder(
            message: message,
            onDone: { [weak self] in
                self?.schedulePendingTimer(after: TimeInterval(Self.configuredIntervalMinutes() * 60))
            },
            onSnooze: { [weak self] in
                self?.schedulePendingTimer(after: 15 * 60)
            }
        )
    }
}
