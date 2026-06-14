import Foundation

enum MalDazeDefaults {
    // 智能输入 LLM 配置（新 provider-aware 设置）
    static let smartInputLLMProvider    = MalDazeDefaultsKeys.SmartInput.llmProvider
    static let smartInputLLMModel       = MalDazeDefaultsKeys.SmartInput.llmModel
    static let smartInputGeminiAPIKey   = MalDazeDefaultsKeys.SmartInput.geminiAPIKey
    static let smartInputOpenAIAPIKey   = MalDazeDefaultsKeys.SmartInput.openAIAPIKey
    static let smartInputDeepSeekAPIKey = MalDazeDefaultsKeys.SmartInput.deepSeekAPIKey
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
    static let geminiAPIKey = MalDazeDefaultsKeys.LegacyGemini.apiKey
    /// `generateContent` 路径中的模型 ID，如 `gemini-2.5-flash`。
    static let geminiModelId = MalDazeDefaultsKeys.LegacyGemini.modelId
    static let defaultGeminiModelId = "gemini-2.5-flash"

    static let deskPetMenuShortcutKeyCode = MalDazeDefaultsKeys.Shortcuts.DeskPetMenu.keyCode
    static let deskPetMenuShortcutModifiers = MalDazeDefaultsKeys.Shortcuts.DeskPetMenu.modifiers
    static let deskPetMenuShortcutKeyLabel = MalDazeDefaultsKeys.Shortcuts.DeskPetMenu.keyLabel

    static let smartReminderInputShortcutKeyCode = MalDazeDefaultsKeys.Shortcuts.SmartReminderInput.keyCode
    static let smartReminderInputShortcutModifiers = MalDazeDefaultsKeys.Shortcuts.SmartReminderInput.modifiers
    static let smartReminderInputShortcutKeyLabel = MalDazeDefaultsKeys.Shortcuts.SmartReminderInput.keyLabel

    /// 手动番茄：专注段长度（分钟），默认 25，范围 5–120。
    static let pomodoroWorkDurationMinutes = MalDazeDefaultsKeys.Timer.workDurationMinutes
    /// 手动 / 整点模式：休息段长度（分钟），默认 5，范围 1–60。
    static let pomodoroRestDurationMinutes = MalDazeDefaultsKeys.Timer.restDurationMinutes
    /// 用户主动停止计时时保存的模式快照；存在即表示启动后保持暂停并显示「恢复计时」。
    static let suspendedTimerModeSnapshot = MalDazeDefaultsKeys.Timer.suspendedModeSnapshot

    /// 独立倒计时长度（分钟），默认 7。
    static let sevenMinuteReminderDurationMinutes = MalDazeDefaultsKeys.SevenMinute.durationMinutes

    static let sevenMinuteReminderShortcutKeyCode = MalDazeDefaultsKeys.Shortcuts.SevenMinuteReminder.keyCode
    static let sevenMinuteReminderShortcutModifiers = MalDazeDefaultsKeys.Shortcuts.SevenMinuteReminder.modifiers
    static let sevenMinuteReminderShortcutKeyLabel = MalDazeDefaultsKeys.Shortcuts.SevenMinuteReminder.keyLabel

    static let resetIdlePetShortcutKeyCode = MalDazeDefaultsKeys.Shortcuts.ResetIdlePet.keyCode
    static let resetIdlePetShortcutModifiers = MalDazeDefaultsKeys.Shortcuts.ResetIdlePet.modifiers
    static let resetIdlePetShortcutKeyLabel = MalDazeDefaultsKeys.Shortcuts.ResetIdlePet.keyLabel

    /// 休息霸屏期间连续单击桌宠 10 下可提前结束休息（默认开）。
    static let restDoubleClickEndsRest = MalDazeDefaultsKeys.Rest.doubleClickEndsRest

    /// 喝水提醒开关（默认关）。
    static let hydrationReminderEnabled = MalDazeDefaultsKeys.Hydration.enabled
    /// 喝水提醒间隔（分钟），默认 90，范围 15–240。
    static let hydrationReminderIntervalMinutes = MalDazeDefaultsKeys.Hydration.intervalMinutes
    /// 安静时段开关：启用后在指定时间段内不弹喝水提醒（默认关）。
    static let hydrationQuietHoursEnabled = MalDazeDefaultsKeys.Hydration.quietHoursEnabled
    /// 安静时段开始时间（距 0:00 的分钟数），默认 1260 = 21:00。
    static let hydrationQuietStartMinutes = MalDazeDefaultsKeys.Hydration.quietStartMinutes
    /// 安静时段结束/恢复时间（距 0:00 的分钟数），默认 480 = 08:00。
    static let hydrationQuietResumeMinutes = MalDazeDefaultsKeys.Hydration.quietResumeMinutes

    /// T7 安全推出自动调度开关（默认开）。
    static let t7EjectAutomaticEnabled = MalDazeDefaultsKeys.T7Eject.automaticEnabled
    /// T7 自动推出窗口开始时间（距 0:00 的分钟数），默认 1200 = 20:00。
    static let t7EjectScheduleStartMinuteOfDay = MalDazeDefaultsKeys.T7Eject.scheduleStartMinuteOfDay
    /// T7 自动推出窗口结束时间（距 0:00 的分钟数），默认 1425 = 23:45。
    static let t7EjectScheduleEndMinuteOfDay = MalDazeDefaultsKeys.T7Eject.scheduleEndMinuteOfDay
    /// T7 自动推出重试间隔（秒），默认 900 = 15 分钟。
    static let t7EjectRetryIntervalSeconds = MalDazeDefaultsKeys.T7Eject.retryIntervalSeconds
    /// 本地日期 token；当天成功或已卸载后，自动调度不再重复。
    static let t7EjectLastCompletedDay = MalDazeDefaultsKeys.T7Eject.lastCompletedDay

    /// 睡眠提醒总开关（默认开）；依赖 Hermes `sleep_schedule.json`。
    static let sleepScheduleEnabled = MalDazeDefaultsKeys.SleepSchedule.enabled

    static func resolvedSleepScheduleEnabled(from defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: sleepScheduleEnabled) == nil
            ? true
            : defaults.bool(forKey: sleepScheduleEnabled)
    }
    static let sleepScheduleRemindersEnabled = MalDazeDefaultsKeys.SleepSchedule.remindersEnabled
    static let sleepScheduleLockScreenEnabled = MalDazeDefaultsKeys.SleepSchedule.lockScreenEnabled
    static let sleepScheduleDismissOnClamshell = MalDazeDefaultsKeys.SleepSchedule.dismissOnClamshell
    static let sleepScheduleShowerReminderEnabled = MalDazeDefaultsKeys.SleepSchedule.showerReminderEnabled
    /// 已触发睡眠事件所属 Hermes `updatedAt`。
    static let sleepScheduleFiredContractUpdatedAt = MalDazeDefaultsKeys.SleepSchedule.firedContractUpdatedAt
    /// 已触发睡眠事件 stable id 列表（同契约内防重响）。
    static let sleepScheduleFiredEventIDs = MalDazeDefaultsKeys.SleepSchedule.firedEventIDs

    /// 休息打断风格："fullscreen"（默认霸屏）或 "breakRun"（跑屏漫游）。
    static let breakInterruptStyle = MalDazeDefaultsKeys.Rest.breakInterruptStyle

    /// **已迁移**：常态桌宠 GIF 是否播放（由 `idlePetAnimationIntensity` 替代）；勿在新代码写入。
    static let idlePetIconAnimationEnabled = MalDazeDefaultsKeys.PetAppearance.idlePetIconAnimationEnabled

    /// 常态桌宠 GIF 动态强度 **0…1**（0 静止，1 满速原生动画与轮换）。首次读取时从旧布尔键迁移。
    static let idlePetAnimationIntensity = MalDazeDefaultsKeys.PetAppearance.idlePetAnimationIntensity

    /// 常态桌宠图标绘制边长（点），与桌宠透明小窗边长联动；未写入时按默认 120。
    static let idlePetIconSidePoints = MalDazeDefaultsKeys.PetAppearance.idlePetIconSidePoints
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

    /// Dashboard 标准窗口 frame（origin + size），Dock / 桌宠入口恢复上次位置。
    static let dashboardWindowOriginX = MalDazeDefaultsKeys.DashboardWindow.originX
    static let dashboardWindowOriginY = MalDazeDefaultsKeys.DashboardWindow.originY
    static let dashboardWindowWidth = MalDazeDefaultsKeys.DashboardWindow.width
    static let dashboardWindowHeight = MalDazeDefaultsKeys.DashboardWindow.height
    /// `true` 表示已按带标题栏窗口的外框尺寸持久化；`false`/缺失时按旧无边框内容区迁移一次。
    static let dashboardWindowFrameUsesTitledOuterSize = MalDazeDefaultsKeys.DashboardWindow.frameUsesTitledOuterSize

    /// Dashboard 左 / 右分栏宽度（pt）；未写入或 ≤0 时使用布局默认值。
    static let dashboardLeftColumnWidth = MalDazeDefaultsKeys.DashboardLayout.leftColumnWidth
    static let dashboardRightColumnWidth = MalDazeDefaultsKeys.DashboardLayout.rightColumnWidth
    static let dashboardColumnWidthMin = DashboardLayout.columnWidthMin
    static let dashboardMiddleColumnWidthMin = DashboardLayout.middleColumnWidthMin

    static func resolvedDashboardLeftColumnWidth(
        stored: Double,
        defaultWidth: CGFloat
    ) -> CGFloat {
        DashboardLayout.resolvedLeftColumnWidth(stored: stored, defaultWidth: defaultWidth)
    }

    static func resolvedDashboardRightColumnWidth(
        stored: Double,
        defaultWidth: CGFloat
    ) -> CGFloat {
        DashboardLayout.resolvedRightColumnWidth(stored: stored, defaultWidth: defaultWidth)
    }

    static func clampedDashboardColumnWidths(
        left: CGFloat,
        right: CGFloat,
        totalInnerWidth: CGFloat,
        middleMin: CGFloat = dashboardMiddleColumnWidthMin,
        columnMin: CGFloat = dashboardColumnWidthMin,
        chromeWidth: CGFloat = 0
    ) -> (left: CGFloat, right: CGFloat) {
        DashboardLayout.clampedColumnWidths(
            left: left,
            right: right,
            totalInnerWidth: totalInnerWidth,
            middleMin: middleMin,
            columnMin: columnMin,
            chromeWidth: chromeWidth
        )
    }

    /// Dashboard 左栏计划区高度占比（0.4–0.75），默认 0.6。
    static let dashboardLeftPlanFraction = MalDazeDefaultsKeys.DashboardLayout.leftPlanFraction
    static let defaultDashboardLeftPlanFraction = DashboardLayout.defaultLeftPlanFraction
    static let dashboardLeftPlanFractionMin = DashboardLayout.leftPlanFractionMin
    static let dashboardLeftPlanFractionMax = DashboardLayout.leftPlanFractionMax

    static func clampedDashboardLeftPlanFraction(_ value: Double) -> Double {
        DashboardLayout.clampedLeftPlanFraction(value)
    }

    static func resolvedDashboardLeftPlanFraction(defaults: UserDefaults = .standard) -> Double {
        DashboardLayout.resolvedLeftPlanFraction(defaults: defaults)
    }

    /// 学习面板每日正课上限（小时），默认 5；同步到 Hermes `daily_capacity_minutes`。
    static let learningTodayGrouping = MalDazeDefaultsKeys.Learning.todayGrouping
    static let learningDailyCapacityHours = MalDazeDefaultsKeys.Learning.dailyCapacityHours
    static let defaultLearningDailyCapacityHours = 5.0
    static let learningDailyCapacityHoursMin = 1.0
    static let learningDailyCapacityHoursMax = 12.0

    static func clampedLearningDailyCapacityHours(_ hours: Double) -> Double {
        let base = hours == 0 ? defaultLearningDailyCapacityHours : hours
        return min(max(base, learningDailyCapacityHoursMin), learningDailyCapacityHoursMax)
    }

    static func resolvedLearningDailyCapacityHours(defaults: UserDefaults = .standard) -> Double {
        migrateLearningDailyCapacityIfNeeded(defaults: defaults)
        return clampedLearningDailyCapacityHours(defaults.double(forKey: learningDailyCapacityHours))
    }

    static func resolvedLearningDailyCapacityMinutes(defaults: UserDefaults = .standard) -> Int {
        LearningCapacityFormatting.minutes(fromHours: resolvedLearningDailyCapacityHours(defaults: defaults))
    }

    /// 首次启动：写入默认 5 小时并同步 Hermes profile。
    static func migrateLearningDailyCapacityIfNeeded(defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: learningDailyCapacityHours) == nil else { return }
        defaults.set(defaultLearningDailyCapacityHours, forKey: learningDailyCapacityHours)
        syncLearningCapacityToHermesProfile(defaults: defaults)
    }

    static func syncLearningCapacityToHermesProfile(defaults: UserDefaults = .standard) {
        let minutes = resolvedLearningDailyCapacityMinutes(defaults: defaults)
        try? HermesLearningProfileStore().writeDailyCapacityMinutes(minutes)
    }

    /// 启动时对齐 Hermes profile（例如从 90 分迁移到设置中的 5 小时）。
    static func ensureLearningCapacitySyncedToHermes(defaults: UserDefaults = .standard) {
        migrateLearningDailyCapacityIfNeeded(defaults: defaults)
        let target = resolvedLearningDailyCapacityMinutes(defaults: defaults)
        if HermesLearningProfileStore().readDailyCapacityMinutes() != target {
            syncLearningCapacityToHermesProfile(defaults: defaults)
        }
    }
}
