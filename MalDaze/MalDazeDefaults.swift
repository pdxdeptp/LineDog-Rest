import Foundation

enum MalDazeDefaults {
    static let geminiAPIKey = "MalDaze.geminiAPIKey"
    /// `generateContent` 路径中的模型 ID，如 `gemini-2.5-flash`。
    static let geminiModelId = "MalDaze.geminiModelId"
    static let defaultGeminiModelId = "gemini-2.5-flash"

    static let deskPetMenuShortcutKeyCode = "MalDaze.deskPetMenuShortcut.keyCode"
    static let deskPetMenuShortcutModifiers = "MalDaze.deskPetMenuShortcut.modifiers"
    static let deskPetMenuShortcutKeyLabel = "MalDaze.deskPetMenuShortcut.keyLabel"

    static let smartReminderInputShortcutKeyCode = "MalDaze.smartReminderInputShortcut.keyCode"
    static let smartReminderInputShortcutModifiers = "MalDaze.smartReminderInputShortcut.modifiers"
    static let smartReminderInputShortcutKeyLabel = "MalDaze.smartReminderInputShortcut.keyLabel"

    /// 独立倒计时长度（分钟），默认 7。
    static let sevenMinuteReminderDurationMinutes = "MalDaze.sevenMinuteReminder.durationMinutes"

    static let sevenMinuteReminderShortcutKeyCode = "MalDaze.sevenMinuteReminderShortcut.keyCode"
    static let sevenMinuteReminderShortcutModifiers = "MalDaze.sevenMinuteReminderShortcut.modifiers"
    static let sevenMinuteReminderShortcutKeyLabel = "MalDaze.sevenMinuteReminderShortcut.keyLabel"

    static let resetIdlePetShortcutKeyCode = "MalDaze.resetIdlePetShortcut.keyCode"
    static let resetIdlePetShortcutModifiers = "MalDaze.resetIdlePetShortcut.modifiers"
    static let resetIdlePetShortcutKeyLabel = "MalDaze.resetIdlePetShortcut.keyLabel"

    /// 休息霸屏期间连续单击桌宠 20 下可提前结束休息（默认开）。
    static let restDoubleClickEndsRest = "MalDaze.restDoubleClickEndsRest"

    /// 喝水提醒开关（默认关）。
    static let hydrationReminderEnabled = "MalDaze.hydrationReminder.enabled"
    /// 喝水提醒间隔（分钟），默认 90，范围 15–240。
    static let hydrationReminderIntervalMinutes = "MalDaze.hydrationReminder.intervalMinutes"
}
