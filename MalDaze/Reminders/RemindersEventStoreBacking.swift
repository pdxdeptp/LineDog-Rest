import Foundation

/// 可替换的数据源，供单测 Mock；生产为 `EventKitRemindersBacking`。
protocol RemindersEventStoreBacking: AnyObject {
    func requestAccess() async throws -> Bool
    func fetchReminderCalendars() async throws -> [RemindersCalendarDescriptor]
    /// 桌宠侧：先用 `predicateForIncompleteReminders` 按 due 窗口缩小，再按 `notes` 是否含 `#日常` 分为两路后合并排序。
    func fetchDeskSidebarReminders(calendarId: String) async throws -> [ReminderDisplayItem]
    func completeReminder(calendarItemIdentifier: String) async throws
    func loadReminderDetail(calendarItemIdentifier: String) async throws -> ReminderEditDetail
    func saveReminderDetail(_ detail: ReminderEditDetail) async throws
    func deleteReminder(calendarItemIdentifier: String) async throws
}
