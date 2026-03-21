import Foundation

/// 抽象 EventKit 写入，便于单测 Mock。
protocol ReminderMutationServing: AnyObject {
    /// `(identifier, title, allowsContentModifications)`
    func fetchReminderCalendarsForMutation() async throws -> [(String, String, Bool)]
    func defaultCalendarForNewRemindersIdentifier() async throws -> String?
    /// 返回 `calendarItemIdentifier`
    func createReminder(
        title: String,
        notes: String?,
        calendarIdentifier: String,
        alarmDate: Date?,
        priority: Int
    ) async throws -> String

    func removeReminder(calendarItemIdentifier: String) async throws
}
