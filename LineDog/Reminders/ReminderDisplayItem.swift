import Foundation

/// 仅用于内存中渲染；内容来自 EventKit 拉取，不做本地持久化。
struct ReminderDisplayItem: Equatable, Sendable, Identifiable {
    var id: String { calendarItemIdentifier }
    let calendarItemIdentifier: String
    let title: String
    /// 用于排序与时间列；无截止日期时可能为 `nil`。
    let dueDate: Date?
    /// `notes` 含 `#日常` 时在 UI 显示微标（不展示原文）。
    let hasRoutineTag: Bool

    init(
        calendarItemIdentifier: String,
        title: String,
        dueDate: Date? = nil,
        hasRoutineTag: Bool = false
    ) {
        self.calendarItemIdentifier = calendarItemIdentifier
        self.title = title
        self.dueDate = dueDate
        self.hasRoutineTag = hasRoutineTag
    }
}
