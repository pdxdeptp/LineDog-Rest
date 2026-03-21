import Foundation

/// 只持久化用户选中的列表 id，不存任何提醒正文（SSOT 在 EventKit）。`class` 便于在协调器内持有 `let` 引用并写入 UserDefaults。
final class RemindersSelectedListPreference {
    private static let key = "LineDog.remindersSelectedCalendarIdentifier"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedCalendarIdentifier: String? {
        get { defaults.string(forKey: Self.key) }
        set {
            if let v = newValue {
                defaults.set(v, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
    }
}

enum RemindersDefaultListResolver {
    /// PRD：默认同名「提醒事项」；英文系统常见为 Reminders。
    static func preferredCalendarId(from lists: [RemindersCalendarDescriptor]) -> String? {
        if let m = lists.first(where: { $0.title == "提醒事项" }) {
            return m.calendarIdentifier
        }
        if let m = lists.first(where: { $0.title == "Reminders" }) {
            return m.calendarIdentifier
        }
        return lists.first?.calendarIdentifier
    }
}
