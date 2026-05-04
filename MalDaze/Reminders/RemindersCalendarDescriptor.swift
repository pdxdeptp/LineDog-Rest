import Foundation

/// 提醒事项「列表」元信息；仅 id + 标题供选择器使用。
struct RemindersCalendarDescriptor: Equatable, Sendable, Identifiable {
    var id: String { calendarIdentifier }
    let calendarIdentifier: String
    let title: String
}
