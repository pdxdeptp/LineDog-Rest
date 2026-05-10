import Foundation

enum MalDazeDefaults {
    // 学习助手后端 LLM 配置
    static let backendLLMProvider    = "MalDaze.backend.llmProvider"    // "gemini"|"openai"|"deepseek"
    static let backendLLMModel       = "MalDaze.backend.llmModel"
    static let backendGeminiAPIKey   = "MalDaze.backend.geminiAPIKey"
    static let backendOpenAIAPIKey   = "MalDaze.backend.openAIAPIKey"
    static let backendDeepSeekAPIKey = "MalDaze.backend.deepSeekAPIKey"
    static let defaultBackendLLMProvider = "gemini"
    static let defaultBackendLLMModel    = "gemini-2.5-flash"

    // 桌宠智能输入（Smart Reminder）— 勿改
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

    /// 手动番茄：专注段长度（分钟），默认 25，范围 5–120。
    static let pomodoroWorkDurationMinutes = "MalDaze.pomodoro.workDurationMinutes"
    /// 手动 / 整点模式：休息段长度（分钟），默认 5，范围 1–60。
    static let pomodoroRestDurationMinutes = "MalDaze.pomodoro.restDurationMinutes"

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
    /// 安静时段开关：启用后在指定时间段内不弹喝水提醒（默认关）。
    static let hydrationQuietHoursEnabled = "MalDaze.hydrationReminder.quietHoursEnabled"
    /// 安静时段开始时间（距 0:00 的分钟数），默认 1260 = 21:00。
    static let hydrationQuietStartMinutes = "MalDaze.hydrationReminder.quietStartMinutes"
    /// 安静时段结束/恢复时间（距 0:00 的分钟数），默认 480 = 08:00。
    static let hydrationQuietResumeMinutes = "MalDaze.hydrationReminder.quietResumeMinutes"

    /// 休息打断风格："fullscreen"（默认霸屏）或 "breakRun"（跑屏漫游）。
    static let breakInterruptStyle = "MalDaze.breakInterruptStyle"

    /// 常态桌宠 GIF 是否播放帧动画并允许多素材轮换（默认开）；键缺失时视为 `true`。
    static let idlePetIconAnimationEnabled = "MalDaze.idlePetIconAnimationEnabled"

    /// 常态桌宠图标绘制边长（点），与桌宠透明小窗边长联动；未写入时按默认 120。
    static let idlePetIconSidePoints = "MalDaze.idlePetIconSidePoints"
    static let idlePetIconSideMin = 72
    static let idlePetIconSideMax = 180
    static let idlePetIconSideDefault = 120

    static func clampedIdlePetIconSidePoints(stored: Int) -> Int {
        let base = stored == 0 ? idlePetIconSideDefault : stored
        return min(max(base, idlePetIconSideMin), idlePetIconSideMax)
    }

    /// 与 `@AppStorage(..., true)` 对齐：未写入 UserDefaults 时默认允许动画。
    static func resolvedIdlePetIconAnimationEnabled() -> Bool {
        if UserDefaults.standard.object(forKey: idlePetIconAnimationEnabled) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: idlePetIconAnimationEnabled)
    }
}
