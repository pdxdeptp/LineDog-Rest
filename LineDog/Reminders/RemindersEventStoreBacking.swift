import Foundation

/// 可替换的数据源，供单测 Mock；生产为 `EventKitRemindersBacking`。
protocol RemindersEventStoreBacking: AnyObject {
    func requestAccess() async throws -> Bool
    func fetchReminderCalendars() async throws -> [RemindersCalendarDescriptor]
    /// 使用 EventKit 谓词在系统侧过滤后的「今日未完成」；实现侧**禁止**全量拉取再在 Swift 里 filter。
    func fetchIncompleteRemindersForToday(calendarId: String) async throws -> [ReminderDisplayItem]
    func completeReminder(calendarItemIdentifier: String) async throws
}
