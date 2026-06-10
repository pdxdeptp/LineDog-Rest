import AppKit
import SwiftUI

/// 设置窗口：Smart Reminder API Key、全局快捷键等。
struct MalDazeSettingsView: View {
    // 桌宠智能输入 LLM
    @AppStorage(MalDazeDefaults.smartInputLLMProvider)    private var smartInputProvider    = MalDazeDefaults.defaultSmartInputLLMProvider
    @AppStorage(MalDazeDefaults.smartInputLLMModel)       private var smartInputModel       = MalDazeDefaults.defaultSmartInputLLMModel
    @AppStorage(MalDazeDefaults.smartInputGeminiAPIKey)   private var smartInputGeminiKey   = ""
    @AppStorage(MalDazeDefaults.smartInputOpenAIAPIKey)   private var smartInputOpenAIKey   = ""
    @AppStorage(MalDazeDefaults.smartInputDeepSeekAPIKey) private var smartInputDeepSeekKey = ""
    @AppStorage(MalDazeDefaults.geminiAPIKey) private var geminiAPIKey = ""
    @AppStorage(MalDazeDefaults.geminiModelId) private var geminiModelId = MalDazeDefaults.defaultGeminiModelId

    @AppStorage(MalDazeDefaults.smartReminderInputShortcutKeyCode) private var smartKeyCode: Int = Int(SmartReminderInputShortcut.defaultKeyCode)
    @AppStorage(MalDazeDefaults.smartReminderInputShortcutModifiers) private var smartModifiersRaw: Int = SmartReminderInputShortcut.defaultModifiersStorageInt
    @AppStorage(MalDazeDefaults.smartReminderInputShortcutKeyLabel) private var smartKeyLabel: String = SmartReminderInputShortcut.default.keyLabel

    @AppStorage(MalDazeDefaults.deskPetMenuShortcutKeyCode) private var deskKeyCode: Int = Int(DeskPetMenuShortcut.defaultKeyCode)
    @AppStorage(MalDazeDefaults.deskPetMenuShortcutModifiers) private var deskModifiersRaw: Int = DeskPetMenuShortcut.defaultModifiersStorageInt
    @AppStorage(MalDazeDefaults.deskPetMenuShortcutKeyLabel) private var deskKeyLabel: String = DeskPetMenuShortcut.default.keyLabel

    @AppStorage(MalDazeDefaults.sevenMinuteReminderShortcutKeyCode) private var sevenKeyCode: Int = Int(SevenMinuteReminderShortcut.defaultKeyCode)
    @AppStorage(MalDazeDefaults.sevenMinuteReminderShortcutModifiers) private var sevenModifiersRaw: Int = SevenMinuteReminderShortcut.defaultModifiersStorageInt
    @AppStorage(MalDazeDefaults.sevenMinuteReminderShortcutKeyLabel) private var sevenKeyLabel: String = SevenMinuteReminderShortcut.default.keyLabel

    @AppStorage(MalDazeDefaults.resetIdlePetShortcutKeyCode) private var resetPetKeyCode: Int = Int(ResetIdlePetPositionShortcut.defaultKeyCode)
    @AppStorage(MalDazeDefaults.resetIdlePetShortcutModifiers) private var resetPetModifiersRaw: Int = ResetIdlePetPositionShortcut.defaultModifiersStorageInt
    @AppStorage(MalDazeDefaults.resetIdlePetShortcutKeyLabel) private var resetPetKeyLabel: String = ResetIdlePetPositionShortcut.default.keyLabel

    @AppStorage(MalDazeDefaults.sleepScheduleEnabled) private var sleepScheduleEnabled = true
    @AppStorage(MalDazeDefaults.sleepScheduleRemindersEnabled) private var sleepRemindersEnabled = true
    @AppStorage(MalDazeDefaults.sleepScheduleLockScreenEnabled) private var sleepLockScreenEnabled = true
    @AppStorage(MalDazeDefaults.sleepScheduleDismissOnClamshell) private var sleepDismissOnClamshell = true
    @AppStorage(MalDazeDefaults.sleepScheduleShowerReminderEnabled) private var sleepShowerReminderEnabled = true
    @AppStorage(MalDazeDefaults.learningDailyCapacityHours) private var learningDailyCapacityHours =
        MalDazeDefaults.defaultLearningDailyCapacityHours
    @AppStorage(MalDazeDefaults.dashboardLeftPlanFraction) private var dashboardLeftPlanFraction =
        MalDazeDefaults.defaultDashboardLeftPlanFraction

    @State private var isRecordingSmartShortcut = false
    @State private var isRecordingDeskShortcut = false
    @State private var isRecordingSevenMinuteShortcut = false
    @State private var isRecordingResetPetShortcut = false
    @State private var selectedCategory: SettingsCategory = .modelCredentials
    @State private var isSmartInputAPIKeyVisible = false

    private var shortcutRecorderBusy: Bool {
        isRecordingSmartShortcut || isRecordingDeskShortcut || isRecordingSevenMinuteShortcut || isRecordingResetPetShortcut
    }

    private var smartShortcutModel: SmartReminderInputShortcut {
        SmartReminderInputShortcut(
            keyCode: UInt16(clamping: smartKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(clamping: max(0, smartModifiersRaw))),
            keyLabel: smartKeyLabel
        )
    }

    private var deskShortcutModel: DeskPetMenuShortcut {
        DeskPetMenuShortcut(
            keyCode: UInt16(clamping: deskKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(clamping: max(0, deskModifiersRaw))),
            keyLabel: deskKeyLabel
        )
    }

    private var sevenShortcutModel: SevenMinuteReminderShortcut {
        SevenMinuteReminderShortcut(
            keyCode: UInt16(clamping: sevenKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(clamping: max(0, sevenModifiersRaw))),
            keyLabel: sevenKeyLabel
        )
    }

    private var resetPetShortcutModel: ResetIdlePetPositionShortcut {
        ResetIdlePetPositionShortcut(
            keyCode: UInt16(clamping: resetPetKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(clamping: max(0, resetPetModifiersRaw))),
            keyLabel: resetPetKeyLabel
        )
    }

    private func disableSmartShortcut() {
        smartKeyCode = 0
        smartModifiersRaw = 0
        smartKeyLabel = ""
    }

    private func disableDeskShortcut() {
        deskKeyCode = 0
        deskModifiersRaw = 0
        deskKeyLabel = ""
    }

    private func disableSevenMinuteShortcut() {
        sevenKeyCode = 0
        sevenModifiersRaw = 0
        sevenKeyLabel = ""
    }

    private func disableResetPetShortcut() {
        resetPetKeyCode = 0
        resetPetModifiersRaw = 0
        resetPetKeyLabel = ""
    }

    private var selectedSmartInputModel: Binding<String> {
        Binding(
            get: {
                let provider = LLMProviderCatalog.provider(for: smartInputProvider)
                if UserDefaults.standard.object(forKey: MalDazeDefaults.smartInputLLMModel) == nil, provider == .gemini {
                    let legacy = geminiModelId.trimmingCharacters(in: .whitespacesAndNewlines)
                    return legacy.isEmpty ? MalDazeDefaults.defaultGeminiModelId : legacy
                }
                if smartInputModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return LLMProviderCatalog.defaultModel(for: provider)
                }
                return smartInputModel
            },
            set: { newValue in
                smartInputModel = newValue
            }
        )
    }

    private var selectedSmartInputAPIKey: Binding<String> {
        Binding(
            get: {
                switch LLMProviderCatalog.provider(for: smartInputProvider) {
                case .openai:
                    return smartInputOpenAIKey
                case .deepseek:
                    return smartInputDeepSeekKey
                case .gemini:
                    if UserDefaults.standard.object(forKey: MalDazeDefaults.smartInputGeminiAPIKey) != nil {
                        return smartInputGeminiKey
                    }
                    return geminiAPIKey
                }
            },
            set: { newValue in
                switch LLMProviderCatalog.provider(for: smartInputProvider) {
                case .openai: smartInputOpenAIKey = newValue
                case .deepseek: smartInputDeepSeekKey = newValue
                case .gemini: smartInputGeminiKey = newValue
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar

            Divider()

            settingsDetailPane
        }
        .background(SettingsDesignPalette.windowBackground)
        .overlay(alignment: .topLeading) {
            // `onExitCommand` 在系统设置窗 / Form 里往往收不到 Esc，会落到系统里变成「咚」一声。
            // 本地监视器在快捷键录制之后注册，`GlobalShortcutKeyRecorder` 会先消费 Esc。
            SettingsEscapeKeyMonitor(shortcutRecorderBusy: shortcutRecorderBusy)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            shortcutRecorders
        }
        .tint(SettingsDesignPalette.paleBlueAccent)
        .frame(minWidth: 720, minHeight: 520)
        .onAppear {
            repairModelSelectionsIfNeeded()
        }
    }

    private func repairModelSelectionsIfNeeded() {
        if !LLMProviderCatalog.models(for: smartInputProvider).contains(where: { $0.id == selectedSmartInputModel.wrappedValue }) {
            smartInputModel = LLMProviderCatalog.defaultModel(for: smartInputProvider)
        }
        let geminiIDs = Set(MalDazeGeminiModelCatalog.pickerOptions.map(\.id))
        if !geminiIDs.contains(geminiModelId) {
            geminiModelId = MalDazeDefaults.defaultGeminiModelId
        }
    }

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("MalDaze")
                    .font(.title3.bold())
                Text("桌宠、智能提醒与快捷键")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            VStack(spacing: 6) {
                ForEach(SettingsCategory.allCases) { category in
                    SettingsSidebarButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }

            Spacer(minLength: 12)

            Text(selectedCategory.helperCopy)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .background(SettingsDesignPalette.paleBlueAccent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(12)
        .frame(width: 206)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(SettingsDesignPalette.sidebarBackground)
    }

    private var settingsDetailPane: some View {
        SettingsPane(category: selectedCategory) {
            switch selectedCategory {
            case .modelCredentials:
                modelCredentialsSettingsPane
            case .shortcuts:
                shortcutsSettingsPane
            case .sleepReminder:
                sleepReminderSettingsPane
            case .learningPanel:
                learningPanelSettingsPane
            }
        }
    }

    private var modelCredentialsSettingsPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            LLMProviderSettingsCard(
                title: "智能输入",
                subtitle: "用于自然语言解析提醒事项。",
                providerContext: "智能输入提醒解析",
                systemImage: "text.bubble",
                provider: $smartInputProvider,
                model: selectedSmartInputModel,
                apiKey: selectedSmartInputAPIKey,
                isKeyVisible: $isSmartInputAPIKeyVisible
            ) {
                EmptyView()
            }
        }
    }

    private var shortcutsSettingsPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGroup(
                title: "全局快捷键",
                subtitle: "录制时须带 ⌘ / ⌥ / ⌃ / ⇧ 之一；按 Esc 不输入并关闭当前快捷键。",
                systemImage: "keyboard",
                trailing: "须带修饰键"
            ) {
                ShortcutSettingRow(
                    title: "添加提醒",
                    subtitle: "默认 ⌘⇧<（小于号，物理键为逗号 + Shift）。通常无需辅助功能授权。",
                    displayString: smartShortcutModel.displayString,
                    isRecording: isRecordingSmartShortcut,
                    shortcutRecorderBusy: shortcutRecorderBusy,
                    onRecord: { isRecordingSmartShortcut = true },
                    onDisable: disableSmartShortcut,
                    onRestoreDefault: {
                        let d = SmartReminderInputShortcut.default
                        smartKeyCode = Int(d.keyCode)
                        smartModifiersRaw = SmartReminderInputShortcut.defaultModifiersStorageInt
                        smartKeyLabel = d.keyLabel
                    }
                )

                ShortcutSettingRow(
                    title: "桌宠菜单",
                    subtitle: "默认 ⌘⇧.（句号），打开桌宠 Dashboard 面板。",
                    displayString: deskShortcutModel.displayString,
                    isRecording: isRecordingDeskShortcut,
                    shortcutRecorderBusy: shortcutRecorderBusy,
                    onRecord: { isRecordingDeskShortcut = true },
                    onDisable: disableDeskShortcut,
                    onRestoreDefault: {
                        let d = DeskPetMenuShortcut.default
                        deskKeyCode = Int(d.keyCode)
                        deskModifiersRaw = DeskPetMenuShortcut.defaultModifiersStorageInt
                        deskKeyLabel = d.keyLabel
                    }
                )

                ShortcutSettingRow(
                    title: "桌宠回到右下角",
                    subtitle: "一键把桌宠移回菜单栏屏可见区右下角。",
                    displayString: resetPetShortcutModel.displayString,
                    isRecording: isRecordingResetPetShortcut,
                    shortcutRecorderBusy: shortcutRecorderBusy,
                    onRecord: { isRecordingResetPetShortcut = true },
                    onDisable: disableResetPetShortcut,
                    onRestoreDefault: {
                        let d = ResetIdlePetPositionShortcut.default
                        resetPetKeyCode = Int(d.keyCode)
                        resetPetModifiersRaw = ResetIdlePetPositionShortcut.defaultModifiersStorageInt
                        resetPetKeyLabel = d.keyLabel
                    }
                )

                ShortcutSettingRow(
                    title: "独立倒计时提醒",
                    subtitle: "默认 ⌘⇧M。再按一次可取消进行中的倒计时。",
                    displayString: sevenShortcutModel.displayString,
                    isRecording: isRecordingSevenMinuteShortcut,
                    shortcutRecorderBusy: shortcutRecorderBusy,
                    onRecord: { isRecordingSevenMinuteShortcut = true },
                    onDisable: disableSevenMinuteShortcut,
                    onRestoreDefault: {
                        let d = SevenMinuteReminderShortcut.default
                        sevenKeyCode = Int(d.keyCode)
                        sevenModifiersRaw = SevenMinuteReminderShortcut.defaultModifiersStorageInt
                        sevenKeyLabel = d.keyLabel
                    }
                )
            }
        }
    }

    private var learningPanelSettingsPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGroup(
                title: "学习面板",
                subtitle: "每日正课上限用于今日预算与周负荷标红；会同步到 Hermes profile。",
                systemImage: "book.closed",
                trailing: "小时"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("每日学习上限")
                        Spacer()
                        Text(LearningCapacityFormatting.formatHours(learningDailyCapacityHours))
                            .font(.body.monospacedDigit().weight(.semibold))
                    }
                    Slider(
                        value: Binding(
                            get: {
                                MalDazeDefaults.clampedLearningDailyCapacityHours(learningDailyCapacityHours)
                            },
                            set: { newValue in
                                let stepped = (newValue * 2).rounded() / 2
                                learningDailyCapacityHours = MalDazeDefaults.clampedLearningDailyCapacityHours(stepped)
                                MalDazeDefaults.syncLearningCapacityToHermesProfile()
                                NotificationCenter.default.post(
                                    name: MalDazeBroadcastNotifications.learningDailyCapacityChanged,
                                    object: nil
                                )
                            }
                        ),
                        in: MalDazeDefaults.learningDailyCapacityHoursMin...MalDazeDefaults.learningDailyCapacityHoursMax,
                        step: 0.5
                    )
                    Text("默认 5 小时。范围 \(Int(MalDazeDefaults.learningDailyCapacityHoursMin))–\(Int(MalDazeDefaults.learningDailyCapacityHoursMax)) 小时，步进 0.5 小时。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SettingsGroup(
                title: "Dashboard 左栏",
                subtitle: "计划区与饮食区的垂直高度比例。",
                systemImage: "rectangle.split.1x2",
                trailing: "计划 %"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("计划区高度")
                        Spacer()
                        Text("\(Int((MalDazeDefaults.clampedDashboardLeftPlanFraction(dashboardLeftPlanFraction) * 100).rounded()))%")
                            .font(.body.monospacedDigit().weight(.semibold))
                    }
                    Slider(
                        value: Binding(
                            get: {
                                MalDazeDefaults.clampedDashboardLeftPlanFraction(dashboardLeftPlanFraction)
                            },
                            set: { newValue in
                                dashboardLeftPlanFraction = MalDazeDefaults.clampedDashboardLeftPlanFraction(newValue)
                            }
                        ),
                        in: MalDazeDefaults.dashboardLeftPlanFractionMin...MalDazeDefaults.dashboardLeftPlanFractionMax,
                        step: 0.05
                    )
                    Text("默认计划 60% / 饮食 40%。范围 40%–75% 计划区。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var sleepReminderSettingsPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGroup(
                title: "睡眠提醒",
                subtitle: "依赖 Hermes 每日晨报更新的 sleep_schedule.json。",
                systemImage: "moon.zzz.fill",
                trailing: "只读契约"
            ) {
                Toggle(isOn: $sleepScheduleEnabled) {
                    Text("开启睡眠提醒")
                }
                .toggleStyle(.switch)
                .onChange(of: sleepScheduleEnabled) { _ in
                    NotificationCenter.default.post(name: MalDazeBroadcastNotifications.sleepScheduleSettingsChanged, object: nil)
                }

                Toggle(isOn: $sleepRemindersEnabled) {
                    Text("睡前铃铛链")
                }
                .toggleStyle(.switch)
                .disabled(!sleepScheduleEnabled)
                .onChange(of: sleepRemindersEnabled) { _ in
                    NotificationCenter.default.post(name: MalDazeBroadcastNotifications.sleepScheduleSettingsChanged, object: nil)
                }

                Toggle(isOn: $sleepLockScreenEnabled) {
                    Text("截止后 5 分钟霸屏")
                }
                .toggleStyle(.switch)
                .disabled(!sleepScheduleEnabled)
                .onChange(of: sleepLockScreenEnabled) { _ in
                    NotificationCenter.default.post(name: MalDazeBroadcastNotifications.sleepScheduleSettingsChanged, object: nil)
                }

                Toggle(isOn: $sleepDismissOnClamshell) {
                    Text("合盖自动取消挡屏")
                }
                .toggleStyle(.switch)
                .disabled(!sleepScheduleEnabled)
                .onChange(of: sleepDismissOnClamshell) { _ in
                    NotificationCenter.default.post(name: MalDazeBroadcastNotifications.sleepScheduleSettingsChanged, object: nil)
                }

                Toggle(isOn: $sleepShowerReminderEnabled) {
                    Text("训练日洗澡提醒（T-90）")
                }
                .toggleStyle(.switch)
                .disabled(!sleepScheduleEnabled)
                .onChange(of: sleepShowerReminderEnabled) { _ in
                    NotificationCenter.default.post(name: MalDazeBroadcastNotifications.sleepScheduleSettingsChanged, object: nil)
                }
            }
        }
    }

    private var shortcutRecorders: some View {
        VStack(spacing: 0) {
            GlobalShortcutKeyRecorder(
                isRecording: $isRecordingSmartShortcut,
                onCaptured: { keyCode, modRaw, label in
                    smartKeyCode = Int(keyCode)
                    smartModifiersRaw = Int(modRaw)
                    smartKeyLabel = label
                },
                onCancel: disableSmartShortcut
            )

            GlobalShortcutKeyRecorder(
                isRecording: $isRecordingDeskShortcut,
                onCaptured: { keyCode, modRaw, label in
                    deskKeyCode = Int(keyCode)
                    deskModifiersRaw = Int(modRaw)
                    deskKeyLabel = label
                },
                onCancel: disableDeskShortcut
            )

            GlobalShortcutKeyRecorder(
                isRecording: $isRecordingResetPetShortcut,
                onCaptured: { keyCode, modRaw, label in
                    resetPetKeyCode = Int(keyCode)
                    resetPetModifiersRaw = Int(modRaw)
                    resetPetKeyLabel = label
                },
                onCancel: disableResetPetShortcut
            )

            GlobalShortcutKeyRecorder(
                isRecording: $isRecordingSevenMinuteShortcut,
                onCaptured: { keyCode, modRaw, label in
                    sevenKeyCode = Int(keyCode)
                    sevenModifiersRaw = Int(modRaw)
                    sevenKeyLabel = label
                },
                onCancel: disableSevenMinuteShortcut
            )
        }
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
    }
}

// MARK: - Settings redesign helpers

private enum SettingsDesignPalette {
    static let paleBlueAccent = Color(red: 0.45, green: 0.72, blue: 0.98)
    static let windowBackground = Color(.windowBackgroundColor)
    static let sidebarBackground = Color(.controlBackgroundColor).opacity(0.72)
    static let groupBackground = Color(.textBackgroundColor).opacity(0.82)
    static let rowBackground = Color(.controlBackgroundColor).opacity(0.46)
    static let border = Color(.separatorColor).opacity(0.42)
}

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case modelCredentials
    case shortcuts
    case sleepReminder
    case learningPanel

    var id: Self { self }

    var title: String {
        switch self {
        case .modelCredentials: return "模型与密钥"
        case .shortcuts: return "快捷键"
        case .sleepReminder: return "睡眠提醒"
        case .learningPanel: return "学习面板"
        }
    }

    var subtitle: String {
        switch self {
        case .modelCredentials: return "LLM 凭据与默认模型"
        case .shortcuts: return "全局操作"
        case .sleepReminder: return "Hermes 契约与睡前链"
        case .learningPanel: return "每日上限与周负荷"
        }
    }

    var systemImage: String {
        switch self {
        case .modelCredentials: return "key.horizontal"
        case .shortcuts: return "keyboard"
        case .sleepReminder: return "moon.zzz.fill"
        case .learningPanel: return "book.closed"
        }
    }

    var helperCopy: String {
        switch self {
        case .modelCredentials:
            return "API Key 按当前实现即时保存到本机设置；本页只改善入口、说明与可读性。"
        case .shortcuts:
            return "快捷键录制仅更新本机设置，恢复默认不会影响其他类别。"
        case .sleepReminder:
            return "目标时间由 Hermes 晨报写入 ~/.hermes/data/sleep/sleep_schedule.json；桌宠只读该文件。"
        case .learningPanel:
            return "每日学习上限写入 ~/.hermes/data/learning-assistant/profile.json，供排程与周负荷共用。"
        }
    }
}

private struct SettingsSidebarButton: View {
    let category: SettingsCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(isSelected ? SettingsDesignPalette.paleBlueAccent : Color.secondary)
                    .background(
                        (isSelected ? SettingsDesignPalette.paleBlueAccent.opacity(0.18) : Color(.separatorColor).opacity(0.10)),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    Text(category.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                isSelected ? Color(.textBackgroundColor).opacity(0.88) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? SettingsDesignPalette.paleBlueAccent.opacity(0.28) : Color.clear, lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(category.title))
        .accessibilityValue(Text(isSelected ? "已选择" : "未选择"))
    }
}

private struct SettingsPane<Content: View>: View {
    let category: SettingsCategory
    let content: Content

    init(category: SettingsCategory, @ViewBuilder content: () -> Content) {
        self.category = category
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: category.systemImage)
                        .font(.title3.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .foregroundStyle(SettingsDesignPalette.paleBlueAccent)
                        .background(SettingsDesignPalette.paleBlueAccent.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(category.title)
                            .font(.title2.bold())
                        Text(category.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                content
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SettingsDesignPalette.windowBackground)
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var trailing: String?
    let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        trailing: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(SettingsDesignPalette.paleBlueAccent)
                    .background(SettingsDesignPalette.paleBlueAccent.opacity(0.15), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if let trailing {
                    Text(trailing)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.controlBackgroundColor), in: Capsule())
                }
            }
            .padding(12)
            .background(SettingsDesignPalette.rowBackground)

            Divider()

            content
        }
        .background(SettingsDesignPalette.groupBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(SettingsDesignPalette.border, lineWidth: 0.75)
        )
    }
}

private struct LLMProviderSettingsCard<ExtraRows: View>: View {
    let title: String
    let subtitle: String
    let providerContext: String
    let systemImage: String
    let provider: Binding<String>
    let model: Binding<String>
    let apiKey: Binding<String>
    let isKeyVisible: Binding<Bool>
    let extraRows: ExtraRows

    init(
        title: String,
        subtitle: String,
        providerContext: String,
        systemImage: String,
        provider: Binding<String>,
        model: Binding<String>,
        apiKey: Binding<String>,
        isKeyVisible: Binding<Bool>,
        @ViewBuilder extraRows: () -> ExtraRows
    ) {
        self.title = title
        self.subtitle = subtitle
        self.providerContext = providerContext
        self.systemImage = systemImage
        self.provider = provider
        self.model = model
        self.apiKey = apiKey
        self.isKeyVisible = isKeyVisible
        self.extraRows = extraRows()
    }

    private var selectedProvider: LLMProviderID {
        LLMProviderCatalog.provider(for: provider.wrappedValue)
    }

    var body: some View {
        SettingsGroup(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            trailing: "本机即时保存"
        ) {
            SettingsLabeledRow(
                title: "服务商与模型",
                subtitle: "切换服务商时会回到该服务商默认模型。"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("服务商", selection: provider) {
                        ForEach(LLMProviderCatalog.providerOptions) { option in
                            Text(option.label).tag(option.id.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 280, alignment: .leading)
                    .onChange(of: provider.wrappedValue) { newProvider in
                        model.wrappedValue = LLMProviderCatalog.defaultModel(for: newProvider)
                    }

                    Picker("模型", selection: model) {
                        ForEach(LLMProviderCatalog.models(for: provider.wrappedValue), id: \.id) { option in
                            Text(option.label).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 280, alignment: .leading)

                    Text("仅保存在本机 UserDefaults；切换此处不会改写另一项功能的服务商、模型或 API Key。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingsLabeledRow(
                title: selectedProvider.apiKeyLabel,
                subtitle: "只读取和写入当前服务商在「\(title)」中的 API Key。"
            ) {
                APIKeySettingRow(
                    visibleLabel: selectedProvider.apiKeyLabel,
                    providerName: selectedProvider.displayName,
                    providerContext: providerContext,
                    systemImage: selectedProvider.systemImage,
                    key: apiKey,
                    isKeyVisible: isKeyVisible
                )
            }

            extraRows
        }
        .tint(SettingsDesignPalette.paleBlueAccent)
    }
}

private struct SettingsLabeledRow<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 168, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(12)

        Divider()
            .padding(.leading, 198)
    }
}

private struct APIKeySettingRow: View {
    let visibleLabel: String
    let providerName: String
    let providerContext: String
    let systemImage: String
    @Binding var key: String
    @Binding var isKeyVisible: Bool

    private var keyStateText: String {
        key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未填写" : "已保存在本机"
    }

    private var keyStateColor: Color {
        key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.orange : SettingsDesignPalette.paleBlueAccent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(SettingsDesignPalette.paleBlueAccent)
                    .background(SettingsDesignPalette.paleBlueAccent.opacity(0.16), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(providerName)
                        .font(.subheadline.weight(.semibold))
                    Text(providerContext)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(keyStateText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(keyStateColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(keyStateColor.opacity(0.14), in: Capsule())
            }

            Text(visibleLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Group {
                    if isKeyVisible {
                        TextField(visibleLabel, text: $key)
                    } else {
                        SecureField(visibleLabel, text: $key)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

                Button {
                    isKeyVisible.toggle()
                } label: {
                    Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(Text(isKeyVisible ? "隐藏 API Key" : "显示 API Key"))
                .help(isKeyVisible ? "隐藏 API Key" : "显示 API Key")
            }

            Text("仅保存在本机 UserDefaults；本页不会上传、测试或转存 API Key。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(SettingsDesignPalette.paleBlueAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(SettingsDesignPalette.paleBlueAccent.opacity(0.22), lineWidth: 0.75)
        )
    }
}

private struct ShortcutSettingRow: View {
    let title: String
    let subtitle: String
    let displayString: String
    let isRecording: Bool
    let shortcutRecorderBusy: Bool
    let onRecord: () -> Void
    let onDisable: () -> Void
    let onRestoreDefault: () -> Void

    private var keycap: some View {
        Text(isRecording ? "等待按键…" : displayString)
            .font(.system(.body, design: .monospaced))
            .fontWeight(.semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 10)
            .frame(minWidth: 94, minHeight: 32)
            .background(
                LinearGradient(
                    colors: [Color(.textBackgroundColor), Color(.controlBackgroundColor)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(SettingsDesignPalette.border, lineWidth: 0.75)
            )
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            keycap

            Button(isRecording ? "等待按键…" : "录制") {
                onRecord()
            }
            .buttonStyle(.borderedProminent)
            .tint(SettingsDesignPalette.paleBlueAccent)
            .disabled(shortcutRecorderBusy && !isRecording)

            Button("关闭") {
                onDisable()
            }
            .buttonStyle(.bordered)
            .disabled(shortcutRecorderBusy)

            Button("恢复默认") {
                onRestoreDefault()
            }
            .buttonStyle(.bordered)
            .disabled(shortcutRecorderBusy)
        }
        .padding(12)
        .background(isRecording ? SettingsDesignPalette.paleBlueAccent.opacity(0.12) : Color.clear)

        Divider()
            .padding(.leading, 12)
    }
}

// MARK: - Esc 关闭设置窗（AppKit 本地监视器）

private struct SettingsEscapeKeyMonitor: NSViewRepresentable {
    var shortcutRecorderBusy: Bool

    func makeNSView(context: Context) -> SettingsEscapeHostView {
        let v = SettingsEscapeHostView()
        v.shortcutRecorderBusy = shortcutRecorderBusy
        return v
    }

    func updateNSView(_ nsView: SettingsEscapeHostView, context: Context) {
        nsView.shortcutRecorderBusy = shortcutRecorderBusy
    }

    static func dismantleNSView(_ nsView: SettingsEscapeHostView, coordinator: ()) {
        nsView.teardown()
    }
}

private final class SettingsEscapeHostView: NSView {
    var shortcutRecorderBusy = false

    private var keyDownMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            installKeyDownMonitorIfNeeded()
        } else {
            removeKeyDownMonitor()
        }
    }

    deinit {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
        }
    }

    func teardown() {
        removeKeyDownMonitor()
    }

    private func installKeyDownMonitorIfNeeded() {
        guard keyDownMonitor == nil, window != nil else { return }
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard let target = self.window, target.isVisible else { return event }
            guard NSApp.keyWindow === target else { return event }
            guard event.keyCode == 53 else { return event }
            if self.shortcutRecorderBusy {
                return event
            }
            DispatchQueue.main.async {
                target.performClose(nil)
            }
            return nil
        }
    }

    private func removeKeyDownMonitor() {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
        }
        keyDownMonitor = nil
    }
}

// MARK: - 快捷键录制（本地事件，仅设置窗在前台时生效）

/// `modRaw` 为 `NSEvent.ModifierFlags` 与 `.deviceIndependentFlagsMask` 相交后的 `rawValue`。
private struct GlobalShortcutKeyRecorder: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onCaptured: (UInt16, UInt, String) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isRecording: $isRecording,
            onCaptured: onCaptured,
            onCancel: onCancel
        )
    }

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        v.isHidden = true
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isRecording = $isRecording
        context.coordinator.onCaptured = onCaptured
        context.coordinator.onCancel = onCancel
        context.coordinator.sync(isRecording: isRecording)
    }

    final class Coordinator: NSObject {
        var isRecording: Binding<Bool>
        var onCaptured: (UInt16, UInt, String) -> Void
        var onCancel: () -> Void
        private var monitor: Any?

        init(
            isRecording: Binding<Bool>,
            onCaptured: @escaping (UInt16, UInt, String) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.isRecording = isRecording
            self.onCaptured = onCaptured
            self.onCancel = onCancel
        }

        func sync(isRecording recording: Bool) {
            if recording {
                startIfNeeded()
            } else {
                stop()
            }
        }

        private func startIfNeeded() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                if event.keyCode == 53 {
                    DispatchQueue.main.async {
                        self.stop()
                        self.isRecording.wrappedValue = false
                        self.onCancel()
                    }
                    return nil
                }
                if Self.modifierOnlyKeyCodes.contains(event.keyCode) {
                    return event
                }
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                guard !flags.intersection([.command, .option, .control, .shift]).isEmpty else {
                    NSSound.beep()
                    return event
                }
                let label = event.charactersIgnoringModifiers?.first.map(String.init) ?? ""
                let modRaw = flags.rawValue
                DispatchQueue.main.async {
                    self.onCaptured(event.keyCode, modRaw, label)
                    self.stop()
                    self.isRecording.wrappedValue = false
                }
                return nil
            }
        }

        private func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        private static let modifierOnlyKeyCodes: Set<UInt16> = [55, 56, 57, 58, 59, 60, 61, 62]
    }
}

// MARK: - 独立设置窗（LSUIElement 下 `showSettingsWindow:` 往往无效）

@MainActor
enum MalDazeSettingsWindowPresenter {
    private static var window: NSWindow?
    private static let windowDelegate = CloseHidesDelegate()

    /// 菜单栏代理应用需显式 `NSWindow`；与 SwiftUI `Settings` 场景并存，共享同一 `MalDazeSettingsView` / `@AppStorage`。
    static func present() {
        NSApp.activate(ignoringOtherApps: true)
        if window == nil {
            let contentSize = NSSize(width: 760, height: 560)
            let w = NSWindow(
                contentRect: NSRect(origin: .zero, size: contentSize),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            w.title = "MalDaze 设置"
            w.isReleasedWhenClosed = false
            w.delegate = windowDelegate
            w.level = .floating
            let host = NSHostingController(rootView: MalDazeSettingsView())
            w.contentViewController = host
            let outerSize = w.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
            w.setFrame(MalDazePresentationAnchor.centeredFrame(forWindowContent: outerSize), display: false)
            window = w
        } else if let w = window {
            w.setFrame(MalDazePresentationAnchor.centeredFrame(forWindowContent: w.frame.size), display: true)
        }
        window?.makeKeyAndOrderFront(nil)
    }
}

/// 红点关闭时只隐藏，便于再次打开同一实例。
private final class CloseHidesDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
