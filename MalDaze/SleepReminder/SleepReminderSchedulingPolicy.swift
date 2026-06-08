import Foundation

enum SleepReminderSchedulingPolicy {
    /// 刚过点仍允许补发的宽限（秒）。
    static let missedEventGrace: TimeInterval = 90
    /// 唤醒后等待 Hermes cron 写完 JSON 再 reconcile。
    static let wakeDelayedReconcile: TimeInterval = 10 * 60
    /// 睡眠窗内自检间隔（秒）；非业务轮询，仅对账 pending 项。
    static let watchdogInterval: TimeInterval = 180
    /// 睡眠窗 [21:00, 次日 02:00) 本地时间。
    static let watchdogStartHour = 21
    static let watchdogEndHour = 2

    static func isInSleepWatchdogWindow(now: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: now)
        return hour >= watchdogStartHour || hour < watchdogEndHour
    }
}
