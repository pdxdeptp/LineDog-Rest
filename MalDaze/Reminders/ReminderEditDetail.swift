import Foundation

/// 侧栏「编辑提醒」表单与 EventKit 写入共用；`notesPlain` 不含单独一行的 `#日常`（由 `isRoutine` 控制写入）。
struct ReminderEditDetail: Equatable, Sendable {
    var calendarItemIdentifier: String
    var title: String
    var notesPlain: String
    var isRoutine: Bool
    var dueDate: Date?
    /// `true` 表示截止日期含具体时分；`false` 为仅日期（全天）。
    var includesTimeInDueDate: Bool
}
