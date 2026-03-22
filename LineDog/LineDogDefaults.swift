import Foundation

enum LineDogDefaults {
    static let geminiAPIKey = "LineDog.geminiAPIKey"
    /// `generateContent` 路径中的模型 ID，如 `gemini-2.5-flash`。
    static let geminiModelId = "LineDog.geminiModelId"
    static let defaultGeminiModelId = "gemini-2.5-flash"

    static let deskPetMenuShortcutKeyCode = "LineDog.deskPetMenuShortcut.keyCode"
    static let deskPetMenuShortcutModifiers = "LineDog.deskPetMenuShortcut.modifiers"
    static let deskPetMenuShortcutKeyLabel = "LineDog.deskPetMenuShortcut.keyLabel"

    static let smartReminderInputShortcutKeyCode = "LineDog.smartReminderInputShortcut.keyCode"
    static let smartReminderInputShortcutModifiers = "LineDog.smartReminderInputShortcut.modifiers"
    static let smartReminderInputShortcutKeyLabel = "LineDog.smartReminderInputShortcut.keyLabel"

    /// 独立倒计时长度（分钟），默认 7。
    static let sevenMinuteReminderDurationMinutes = "LineDog.sevenMinuteReminder.durationMinutes"

    static let sevenMinuteReminderShortcutKeyCode = "LineDog.sevenMinuteReminderShortcut.keyCode"
    static let sevenMinuteReminderShortcutModifiers = "LineDog.sevenMinuteReminderShortcut.modifiers"
    static let sevenMinuteReminderShortcutKeyLabel = "LineDog.sevenMinuteReminderShortcut.keyLabel"
}
