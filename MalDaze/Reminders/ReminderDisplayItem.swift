import Foundation

/// 仅用于内存中渲染；内容来自 EventKit 拉取，不做本地持久化。
struct ReminderDisplayItem: Equatable, Hashable, Sendable, Identifiable {
    var id: String { calendarItemIdentifier }
    let calendarItemIdentifier: String
    let title: String
    /// 用于排序与时间列；无截止日期时可能为 `nil`。
    let dueDate: Date?
    /// `false` 表示仅有日期（hour/minute 均为 nil）；时间列显示「全天」而非"00:00"。
    let hasExplicitTime: Bool
    /// `notes` 含 `#日常` 时在 UI 显示微标（不展示原文）。
    let hasRoutineTag: Bool
    /// 侧边栏可展示的用户备注；已移除独立成行的 `#日常` 标记。
    let notesPlain: String

    init(
        calendarItemIdentifier: String,
        title: String,
        dueDate: Date? = nil,
        hasExplicitTime: Bool = true,
        hasRoutineTag: Bool = false,
        notesPlain: String = ""
    ) {
        self.calendarItemIdentifier = calendarItemIdentifier
        self.title = title
        self.dueDate = dueDate
        self.hasExplicitTime = hasExplicitTime
        self.hasRoutineTag = hasRoutineTag
        self.notesPlain = notesPlain
    }
}
