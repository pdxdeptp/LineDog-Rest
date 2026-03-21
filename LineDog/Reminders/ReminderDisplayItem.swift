import Foundation

/// 仅用于内存中渲染；内容来自 EventKit 拉取，不做本地持久化。
struct ReminderDisplayItem: Equatable, Sendable, Identifiable {
    var id: String { calendarItemIdentifier }
    let calendarItemIdentifier: String
    let title: String
}
