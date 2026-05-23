import AppKit
import SwiftUI

/// 设置窗口：Gemini API Key、全局快捷键等。
struct MalDazeSettingsView: View {
    // 学习助手后端 LLM
    @AppStorage(MalDazeDefaults.backendLLMProvider)    private var backendProvider    = MalDazeDefaults.defaultBackendLLMProvider
    @AppStorage(MalDazeDefaults.backendLLMModel)       private var backendModel       = MalDazeDefaults.defaultBackendLLMModel
    @AppStorage(MalDazeDefaults.backendGeminiAPIKey)   private var backendGeminiKey   = ""
    @AppStorage(MalDazeDefaults.backendOpenAIAPIKey)   private var backendOpenAIKey   = ""
    @AppStorage(MalDazeDefaults.backendDeepSeekAPIKey) private var backendDeepSeekKey = ""
    @AppStorage(MalDazeDefaults.assistantBackendLazyStartupEnabled) private var assistantBackendLazyStartupEnabled = MalDazeDefaults.defaultAssistantBackendLazyStartupEnabled

    // 桌宠智能输入（勿改）
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

    @State private var isRecordingSmartShortcut = false
    @State private var isRecordingDeskShortcut = false
    @State private var isRecordingSevenMinuteShortcut = false
    @State private var isRecordingResetPetShortcut = false
    @State private var selectedCategory: SettingsCategory = .learningAssistant
    @State private var isBackendAPIKeyVisible = false
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

    private var selectedBackendAPIKey: Binding<String> {
        Binding(
            get: {
                switch backendProvider {
                case "openai": return backendOpenAIKey
                case "deepseek": return backendDeepSeekKey
                default: return backendGeminiKey
                }
            },
            set: { newValue in
                switch backendProvider {
                case "openai": backendOpenAIKey = newValue
                case "deepseek": backendDeepSeekKey = newValue
                default: backendGeminiKey = newValue
                }
            }
        )
    }

    private var backendProviderDisplayName: String {
        switch backendProvider {
        case "openai": return "OpenAI"
        case "deepseek": return "DeepSeek"
        default: return "Google Gemini"
        }
    }

    private var backendProviderSymbol: String {
        switch backendProvider {
        case "openai": return "sparkles"
        case "deepseek": return "brain.head.profile"
        default: return "diamond.fill"
        }
    }

    private var backendAPIKeyVisibleLabel: String {
        "\(backendProviderDisplayName) API Key"
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
            let ids = Set(MalDazeGeminiModelCatalog.pickerOptions.map(\.id))
            if !ids.contains(geminiModelId) {
                geminiModelId = MalDazeDefaults.defaultGeminiModelId
            }
        }
    }

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("MalDaze")
                    .font(.title3.bold())
                Text("桌宠、学习助手与提醒")
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

            Text("API Key 按当前实现即时保存到本机设置；本页只改善入口、说明与可读性。")
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
            case .learningAssistant:
                learningAssistantSettingsPane
            case .smartInput:
                smartInputSettingsPane
            case .shortcuts:
                shortcutsSettingsPane
            }
        }
    }

    private var learningAssistantSettingsPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGroup(
                title: "学习助手 LLM",
                subtitle: "影响中栏学习助手，下次后端启动时生效。",
                systemImage: "server.rack",
                trailing: "本机即时保存"
            ) {
                SettingsLabeledRow(
                    title: "服务商与模型",
                    subtitle: "切换服务商时会回到该服务商默认模型。"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("服务商", selection: $backendProvider) {
                            Text("Google Gemini").tag("gemini")
                            Text("OpenAI").tag("openai")
                            Text("DeepSeek").tag("deepseek")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: backendProvider) { newProvider in
                            backendModel = BackendLLMCatalog.defaultModel(for: newProvider)
                        }

                        Picker("模型", selection: $backendModel) {
                            ForEach(BackendLLMCatalog.models(for: backendProvider), id: \.id) { model in
                                Text(model.label).tag(model.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                SettingsLabeledRow(
                    title: backendAPIKeyVisibleLabel,
                    subtitle: "用于学习助手后端生成计划、复盘与对话。"
                ) {
                    APIKeySettingRow(
                        visibleLabel: backendAPIKeyVisibleLabel,
                        providerName: backendProviderDisplayName,
                        providerContext: "学习助手后端",
                        systemImage: backendProviderSymbol,
                        key: selectedBackendAPIKey,
                        isKeyVisible: $isBackendAPIKeyVisible
                    )
                }

                SettingsLabeledRow(
                    title: "懒启动学习助手后端",
                    subtitle: "更省电，但首次打开学习助手可能需要等待。"
                ) {
                    Toggle(isOn: $assistantBackendLazyStartupEnabled) {
                        Text("开启懒启动")
                    }
                    .toggleStyle(.switch)
                    .help("影响下次 App 启动策略：开启时更省电，启动不会拉起后端，首次打开学习助手可能需要等待；关闭后会在 App 启动完成后预先启动后端。切换此项不会立即启动或停止当前后端。")

                    Text("下次 App 启动时生效，不会立即启动或停止当前后端。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var smartInputSettingsPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGroup(
                title: "智能输入",
                subtitle: "用于自然语言解析提醒事项。",
                systemImage: "text.bubble",
                trailing: "本机即时保存"
            ) {
                SettingsLabeledRow(
                    title: "Google Gemini API Key",
                    subtitle: "用于智能输入自然语言提醒解析，与学习助手后端 Key 分开保存。"
                ) {
                    APIKeySettingRow(
                        visibleLabel: "Google Gemini API Key",
                        providerName: "Google Gemini",
                        providerContext: "智能输入提醒解析",
                        systemImage: "diamond.fill",
                        key: $geminiAPIKey,
                        isKeyVisible: $isSmartInputAPIKeyVisible
                    )
                }

                SettingsLabeledRow(
                    title: "Gemini 模型",
                    subtitle: "若请求失败，可换一款或到 AI Studio 核对模型名。"
                ) {
                    Picker("Gemini 模型", selection: $geminiModelId) {
                        ForEach(MalDazeGeminiModelCatalog.pickerOptions) { option in
                            Text(option.label).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                ShortcutSettingRow(
                    title: "添加提醒",
                    subtitle: "默认 ⌘⇧<（小于号，物理键为逗号 + Shift）。通常无需辅助功能授权。",
                    displayString: smartShortcutModel.displayString,
                    isRecording: isRecordingSmartShortcut,
                    shortcutRecorderBusy: shortcutRecorderBusy,
                    onRecord: { isRecordingSmartShortcut = true },
                    onRestoreDefault: {
                        let d = SmartReminderInputShortcut.default
                        smartKeyCode = Int(d.keyCode)
                        smartModifiersRaw = SmartReminderInputShortcut.defaultModifiersStorageInt
                        smartKeyLabel = d.keyLabel
                    }
                )
            }
        }
    }

    private var shortcutsSettingsPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGroup(
                title: "全局快捷键",
                subtitle: "录制时须带 ⌘ / ⌥ / ⌃ / ⇧ 之一；按 Esc 取消录制。",
                systemImage: "keyboard",
                trailing: "须带修饰键"
            ) {
                ShortcutSettingRow(
                    title: "桌宠菜单",
                    subtitle: "默认 ⌘⇧.（句号），打开桌宠 Dashboard 面板。",
                    displayString: deskShortcutModel.displayString,
                    isRecording: isRecordingDeskShortcut,
                    shortcutRecorderBusy: shortcutRecorderBusy,
                    onRecord: { isRecordingDeskShortcut = true },
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

    private var shortcutRecorders: some View {
        VStack(spacing: 0) {
            GlobalShortcutKeyRecorder(
                isRecording: $isRecordingSmartShortcut,
                onCaptured: { keyCode, modRaw, label in
                    smartKeyCode = Int(keyCode)
                    smartModifiersRaw = Int(modRaw)
                    smartKeyLabel = label
                },
                onCancel: {}
            )

            GlobalShortcutKeyRecorder(
                isRecording: $isRecordingDeskShortcut,
                onCaptured: { keyCode, modRaw, label in
                    deskKeyCode = Int(keyCode)
                    deskModifiersRaw = Int(modRaw)
                    deskKeyLabel = label
                },
                onCancel: {}
            )

            GlobalShortcutKeyRecorder(
                isRecording: $isRecordingResetPetShortcut,
                onCaptured: { keyCode, modRaw, label in
                    resetPetKeyCode = Int(keyCode)
                    resetPetModifiersRaw = Int(modRaw)
                    resetPetKeyLabel = label
                },
                onCancel: {}
            )

            GlobalShortcutKeyRecorder(
                isRecording: $isRecordingSevenMinuteShortcut,
                onCaptured: { keyCode, modRaw, label in
                    sevenKeyCode = Int(keyCode)
                    sevenModifiersRaw = Int(modRaw)
                    sevenKeyLabel = label
                },
                onCancel: {}
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
    case learningAssistant
    case smartInput
    case shortcuts

    var id: Self { self }

    var title: String {
        switch self {
        case .learningAssistant: return "学习助手"
        case .smartInput: return "智能输入"
        case .shortcuts: return "快捷键"
        }
    }

    var subtitle: String {
        switch self {
        case .learningAssistant: return "后端模型与凭据"
        case .smartInput: return "提醒解析"
        case .shortcuts: return "全局操作"
        }
    }

    var systemImage: String {
        switch self {
        case .learningAssistant: return "sparkles"
        case .smartInput: return "text.bubble"
        case .shortcuts: return "keyboard"
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

// MARK: - 后端 LLM 模型目录

enum BackendLLMCatalog {
    struct Model { let id: String; let label: String }

    static func models(for provider: String) -> [Model] {
        switch provider {
        case "openai":
            return [
                Model(id: "gpt-5.5",      label: "GPT-5.5"),
                Model(id: "gpt-5.4",      label: "GPT-5.4"),
                Model(id: "gpt-5.4-mini", label: "GPT-5.4 mini"),
            ]
        case "deepseek":
            return [
                Model(id: "deepseek-v4-pro",   label: "DeepSeek V4 Pro"),
                Model(id: "deepseek-v4-flash", label: "DeepSeek V4 Flash"),
            ]
        default: // gemini
            return [
                Model(id: "gemini-3.1-pro-preview", label: "Gemini 3.1 Pro (Preview)"),
                Model(id: "gemini-3.1-flash-lite",  label: "Gemini 3.1 Flash Lite"),
                Model(id: "gemini-3-flash-preview",  label: "Gemini 3 Flash (Preview)"),
                Model(id: "gemini-2.5-pro",          label: "Gemini 2.5 Pro"),
                Model(id: "gemini-2.5-flash",        label: "Gemini 2.5 Flash"),
                Model(id: "gemini-2.5-flash-lite",   label: "Gemini 2.5 Flash Lite"),
            ]
        }
    }

    static func defaultModel(for provider: String) -> String { models(for: provider)[0].id }
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
