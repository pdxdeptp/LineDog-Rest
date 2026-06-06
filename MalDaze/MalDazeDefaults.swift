import Foundation

enum MalDazeDefaults {
    // 智能输入 LLM 配置（新 provider-aware 设置）
    static let smartInputLLMProvider    = "MalDaze.smartInput.llmProvider"
    static let smartInputLLMModel       = "MalDaze.smartInput.llmModel"
    static let smartInputGeminiAPIKey   = "MalDaze.smartInput.geminiAPIKey"
    static let smartInputOpenAIAPIKey   = "MalDaze.smartInput.openAIAPIKey"
    static let smartInputDeepSeekAPIKey = "MalDaze.smartInput.deepSeekAPIKey"
    static let defaultSmartInputLLMProvider = "gemini"
    static let defaultSmartInputLLMModel    = "gemini-2.5-flash"

    static func resolvedSmartInputProvider(defaults: UserDefaults = .standard) -> LLMProviderID {
        let raw = defaults.string(forKey: smartInputLLMProvider) ?? defaultSmartInputLLMProvider
        return LLMProviderCatalog.provider(for: raw)
    }

    static func resolvedSmartInputModel(defaults: UserDefaults = .standard) -> String {
        let provider = resolvedSmartInputProvider(defaults: defaults)
        let newModel = defaults.object(forKey: smartInputLLMModel) as? String
        let legacyGeminiModel = provider == .gemini ? defaults.object(forKey: geminiModelId) as? String : nil
        if provider == .gemini,
           let legacyGeminiModel,
           newModel == nil {
            return resolvedModel(
                rawModel: legacyGeminiModel,
                provider: provider,
                fallbackModel: defaultGeminiModelId
            )
        }
        return resolvedModel(
            rawModel: newModel ?? legacyGeminiModel,
            provider: provider,
            fallbackModel: provider == .gemini ? defaultGeminiModelId : LLMProviderCatalog.defaultModel(for: provider)
        )
    }

    static func resolvedSmartInputAPIKey(for provider: LLMProviderID, defaults: UserDefaults = .standard) -> String {
        switch provider {
        case .gemini:
            return resolvedSmartInputGeminiAPIKey(defaults: defaults)
        case .openai:
            return trimmed(defaults.string(forKey: smartInputOpenAIAPIKey))
        case .deepseek:
            return trimmed(defaults.string(forKey: smartInputDeepSeekAPIKey))
        }
    }

    static func resolvedSmartInputGeminiAPIKey(defaults: UserDefaults = .standard) -> String {
        if let newKey = defaults.object(forKey: smartInputGeminiAPIKey) as? String {
            return trimmed(newKey)
        }
        return trimmed(defaults.string(forKey: geminiAPIKey))
    }

    private static func resolvedModel(rawModel: String?, provider: LLMProviderID, fallbackModel: String) -> String {
        let raw = trimmed(rawModel)
        guard !raw.isEmpty, !raw.contains("/"), !raw.contains(":") else {
            return fallbackModel
        }
        let allowedIDs = Set(LLMProviderCatalog.models(for: provider).map(\.id))
        return allowedIDs.contains(raw) ? raw : fallbackModel
    }

    private static func trimmed(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

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
    /// 用户主动停止计时时保存的模式快照；存在即表示启动后保持暂停并显示「恢复计时」。
    static let suspendedTimerModeSnapshot = "MalDaze.timer.suspendedModeSnapshot"

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

    /// T7 安全推出自动调度开关（默认开）。
    static let t7EjectAutomaticEnabled = "MalDaze.t7Eject.automaticEnabled"
    /// T7 自动推出窗口开始时间（距 0:00 的分钟数），默认 1200 = 20:00。
    static let t7EjectScheduleStartMinuteOfDay = "MalDaze.t7Eject.scheduleStartMinuteOfDay"
    /// T7 自动推出窗口结束时间（距 0:00 的分钟数），默认 1425 = 23:45。
    static let t7EjectScheduleEndMinuteOfDay = "MalDaze.t7Eject.scheduleEndMinuteOfDay"
    /// T7 自动推出重试间隔（秒），默认 900 = 15 分钟。
    static let t7EjectRetryIntervalSeconds = "MalDaze.t7Eject.retryIntervalSeconds"
    /// 本地日期 token；当天成功或已卸载后，自动调度不再重复。
    static let t7EjectLastCompletedDay = "MalDaze.t7Eject.lastCompletedDay"

    /// 休息打断风格："fullscreen"（默认霸屏）或 "breakRun"（跑屏漫游）。
    static let breakInterruptStyle = "MalDaze.breakInterruptStyle"

    /// **已迁移**：常态桌宠 GIF 是否播放（由 `idlePetAnimationIntensity` 替代）；勿在新代码写入。
    static let idlePetIconAnimationEnabled = "MalDaze.idlePetIconAnimationEnabled"

    /// 常态桌宠 GIF 动态强度 **0…1**（0 静止，1 满速原生动画与轮换）。首次读取时从旧布尔键迁移。
    static let idlePetAnimationIntensity = "MalDaze.idlePetAnimationIntensity"

    /// 常态桌宠图标绘制边长（点），与桌宠透明小窗边长联动；未写入时按默认 120。
    static let idlePetIconSidePoints = "MalDaze.idlePetIconSidePoints"
    static let idlePetIconSideMin = 72
    static let idlePetIconSideMax = 180
    static let idlePetIconSideDefault = 120

    static func clampedIdlePetIconSidePoints(stored: Int) -> Int {
        let base = stored == 0 ? idlePetIconSideDefault : stored
        return min(max(base, idlePetIconSideMin), idlePetIconSideMax)
    }

    /// 首次启动或升级后调用：若无强度键则从旧布尔键迁移（关→0、开→1；皆缺失→1）。
    static func migrateIdlePetAnimationIntensityFromLegacyIfNeeded() {
        let ud = UserDefaults.standard
        guard ud.object(forKey: idlePetAnimationIntensity) == nil else { return }
        let value: Double
        if ud.object(forKey: idlePetIconAnimationEnabled) != nil {
            value = ud.bool(forKey: idlePetIconAnimationEnabled) ? 1.0 : 0.0
        } else {
            value = 1.0
        }
        ud.set(value, forKey: idlePetAnimationIntensity)
    }

    /// 返回 **0…1** 常态桌宠动画强度（读取前确保已执行迁移）。
    static func resolvedIdlePetAnimationIntensity() -> Double {
        migrateIdlePetAnimationIntensityFromLegacyIfNeeded()
        let raw = UserDefaults.standard.double(forKey: idlePetAnimationIntensity)
        return min(max(raw, 0), 1)
    }
}
