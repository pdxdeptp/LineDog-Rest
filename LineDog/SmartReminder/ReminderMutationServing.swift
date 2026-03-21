import Foundation

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
        priority: Int
    ) async throws -> String

    func removeReminder(calendarItemIdentifier: String) async throws
}
