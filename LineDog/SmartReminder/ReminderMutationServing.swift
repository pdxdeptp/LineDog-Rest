import Foundation

/// 由 LLM `recurrence` 映射而来，供 `EventKitReminderMutationService` 转成 `EKRecurrenceRule`。
struct ReminderRecurrenceSpec: Equatable {
    enum Frequency: String, Equatable {
        case daily
        case weekly
        case monthly
        case yearly
    }

    var frequency: Frequency
    /// 每几天 / 几周 / 几月 / 几年（≥1）
    var interval: Int
    /// `EKWeekday` 原始值：1=周日 … 7=周六；仅 `weekly` 使用
    var daysOfTheWeek: [Int]?
    /// 每月第几天（1…31）；仅 `monthly` 使用
    var dayOfMonth: Int?

    init(
        frequency: Frequency,
        interval: Int = 1,
        daysOfTheWeek: [Int]? = nil,
        dayOfMonth: Int? = nil
    ) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.daysOfTheWeek = daysOfTheWeek
        self.dayOfMonth = dayOfMonth
    }
}

/// 抽象 EventKit 写入，便于单测 Mock。
protocol ReminderMutationServing: AnyObject {
    /// `(identifier, title, allowsContentModifications)`
    func fetchReminderCalendarsForMutation() async throws -> [(String, String, Bool)]
    func defaultCalendarForNewRemindersIdentifier() async throws -> String?
    /// 返回 `calendarItemIdentifier`。`dueDate` 可单独设置截止日期；`alarmAt` 非 nil 时添加系统闹钟并用于本机到点铃铛。
    func createReminder(
        title: String,
        notes: String?,
        calendarIdentifier: String,
        dueDate: Date?,
        alarmAt: Date?,
        priority: Int,
        recurrence: ReminderRecurrenceSpec?
    ) async throws -> String

    func removeReminder(calendarItemIdentifier: String) async throws
}
