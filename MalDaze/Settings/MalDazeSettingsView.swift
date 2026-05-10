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

    var body: some View {
        Form {
            Section {
                LabeledContent("服务商") {
                    Picker("", selection: $backendProvider) {
                        Text("Google Gemini").tag("gemini")
                        Text("OpenAI").tag("openai")
                        Text("DeepSeek").tag("deepseek")
                    }
                    .labelsHidden().pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: backendProvider) { newProvider in
                    backendModel = BackendLLMCatalog.defaultModel(for: newProvider)
                }
                LabeledContent("模型") {
                    Picker("", selection: $backendModel) {
                        ForEach(BackendLLMCatalog.models(for: backendProvider), id: \.id) { m in
                            Text(m.label).tag(m.id)
                        }
                    }
                    .labelsHidden().pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                }
                switch backendProvider {
                case "openai":
                    SecureField("OpenAI API Key", text: $backendOpenAIKey)
                        .textFieldStyle(.roundedBorder)
                case "deepseek":
                    SecureField("DeepSeek API Key", text: $backendDeepSeekKey)
                        .textFieldStyle(.roundedBorder)
                default:
                    SecureField("Gemini API Key", text: $backendGeminiKey)
                        .textFieldStyle(.roundedBorder)
                }
                Text("重启桌宠后生效。API Key 仅保存在本机 UserDefaults。")
                    .font(.caption).foregroundStyle(.secondary)
            } header: {
                Text("学习助手 LLM")
            }

            Section {
                SecureField("Gemini API Key", text: $geminiAPIKey)
                    .textFieldStyle(.roundedBorder)
                LabeledContent("Gemini 模型") {
                    Picker("", selection: $geminiModelId) {
                        ForEach(MalDazeGeminiModelCatalog.pickerOptions) { opt in
                            Text(opt.label).tag(opt.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("用于自然语言解析提醒事项；仅保存在本机 UserDefaults。列表以 Google 当前开放为准，若请求失败可换一款或到 AI Studio 核对模型名。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(smartShortcutModel.displayString)
                        .font(.system(.body, design: .monospaced))
                        .frame(minWidth: 120, alignment: .leading)
                    Button(isRecordingSmartShortcut ? "等待按键…" : "修改快捷键…") {
                        isRecordingSmartShortcut = true
                    }
                    .disabled(shortcutRecorderBusy)
                    Button("恢复默认") {
                        let d = SmartReminderInputShortcut.default
                        smartKeyCode = Int(d.keyCode)
                        smartModifiersRaw = SmartReminderInputShortcut.defaultModifiersStorageInt
                        smartKeyLabel = d.keyLabel
                    }
                    .disabled(shortcutRecorderBusy)
                }
                Text("默认 ⌘⇧<（小于号，物理键为逗号 + Shift）。须带 ⌘ / ⌥ / ⌃ / ⇧ 之一；按 Esc 取消录制。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                GlobalShortcutKeyRecorder(
                    isRecording: $isRecordingSmartShortcut,
                    onCaptured: { keyCode, modRaw, label in
                        smartKeyCode = Int(keyCode)
                        smartModifiersRaw = Int(modRaw)
                        smartKeyLabel = label
                    },
                    onCancel: {}
                )
                .frame(width: 0, height: 0)
            } header: {
                Text("智能输入 (Smart Input)")
            } footer: {
                Text("上述「添加提醒」快捷键由系统全局热键注册，通常无需「辅助功能」。另可选用 ⌥⌘R（需在「隐私与安全性 → 辅助功能」中授权 MalDaze）。")
                    .font(.caption)
            }

            Section {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(deskShortcutModel.displayString)
                        .font(.system(.body, design: .monospaced))
                        .frame(minWidth: 120, alignment: .leading)
                    Button(isRecordingDeskShortcut ? "等待按键…" : "修改快捷键…") {
                        isRecordingDeskShortcut = true
                    }
                    .disabled(shortcutRecorderBusy)
                    Button("恢复默认") {
                        let d = DeskPetMenuShortcut.default
                        deskKeyCode = Int(d.keyCode)
                        deskModifiersRaw = DeskPetMenuShortcut.defaultModifiersStorageInt
                        deskKeyLabel = d.keyLabel
                    }
                    .disabled(shortcutRecorderBusy)
                }
                Text("默认 ⌘⇧.（句号）。录制时须带 ⌘ / ⌥ / ⌃ / ⇧ 之一；按 Esc 取消录制。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                GlobalShortcutKeyRecorder(
                    isRecording: $isRecordingDeskShortcut,
                    onCaptured: { keyCode, modRaw, label in
                        deskKeyCode = Int(keyCode)
                        deskModifiersRaw = Int(modRaw)
                        deskKeyLabel = label
                    },
                    onCancel: {}
                )
                .frame(width: 0, height: 0)
            } header: {
                Text("桌宠菜单")
            }

            Section {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(resetPetShortcutModel.displayString)
                        .font(.system(.body, design: .monospaced))
                        .frame(minWidth: 120, alignment: .leading)
                    Button(isRecordingResetPetShortcut ? "等待按键…" : "修改快捷键…") {
                        isRecordingResetPetShortcut = true
                    }
                    .disabled(shortcutRecorderBusy)
                    Button("恢复默认") {
                        let d = ResetIdlePetPositionShortcut.default
                        resetPetKeyCode = Int(d.keyCode)
                        resetPetModifiersRaw = ResetIdlePetPositionShortcut.defaultModifiersStorageInt
                        resetPetKeyLabel = d.keyLabel
                    }
                    .disabled(shortcutRecorderBusy)
                }
                Text("一键把桌宠移回菜单栏屏可见区右下角（与面板里按钮相同）。默认 ⌘⇧R；须带 ⌘ / ⌥ / ⌃ / ⇧ 之一；按 Esc 取消录制。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                GlobalShortcutKeyRecorder(
                    isRecording: $isRecordingResetPetShortcut,
                    onCaptured: { keyCode, modRaw, label in
                        resetPetKeyCode = Int(keyCode)
                        resetPetModifiersRaw = Int(modRaw)
                        resetPetKeyLabel = label
                    },
                    onCancel: {}
                )
                .frame(width: 0, height: 0)
            } header: {
                Text("桌宠回到右下角")
            }

            Section {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(sevenShortcutModel.displayString)
                        .font(.system(.body, design: .monospaced))
                        .frame(minWidth: 120, alignment: .leading)
                    Button(isRecordingSevenMinuteShortcut ? "等待按键…" : "修改快捷键…") {
                        isRecordingSevenMinuteShortcut = true
                    }
                    .disabled(shortcutRecorderBusy)
                    Button("恢复默认") {
                        let d = SevenMinuteReminderShortcut.default
                        sevenKeyCode = Int(d.keyCode)
                        sevenModifiersRaw = SevenMinuteReminderShortcut.defaultModifiersStorageInt
                        sevenKeyLabel = d.keyLabel
                    }
                    .disabled(shortcutRecorderBusy)
                }
                Text("默认 ⌘⇧M。再按一次可取消进行中的倒计时。须带 ⌘ / ⌥ / ⌃ / ⇧ 之一；按 Esc 取消录制。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                GlobalShortcutKeyRecorder(
                    isRecording: $isRecordingSevenMinuteShortcut,
                    onCaptured: { keyCode, modRaw, label in
                        sevenKeyCode = Int(keyCode)
                        sevenModifiersRaw = Int(modRaw)
                        sevenKeyLabel = label
                    },
                    onCancel: {}
                )
                .frame(width: 0, height: 0)
            } header: {
                Text("独立倒计时提醒（快捷键）")
            } footer: {
                Text("倒计时时长在菜单栏本应用面板里调整。此处仅配置全局快捷键（默认 ⌘⇧M，再按取消）。")
                    .font(.caption)
            }
        }
        .overlay(alignment: .topLeading) {
            // `onExitCommand` 在系统设置窗 / Form 里往往收不到 Esc，会落到系统里变成「咚」一声。
            // 本地监视器在快捷键录制之后注册，`GlobalShortcutKeyRecorder` 会先消费 Esc。
            SettingsEscapeKeyMonitor(shortcutRecorderBusy: shortcutRecorderBusy)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 480)
        .padding()
        .onAppear {
            let ids = Set(MalDazeGeminiModelCatalog.pickerOptions.map(\.id))
            if !ids.contains(geminiModelId) {
                geminiModelId = MalDazeDefaults.defaultGeminiModelId
            }
        }
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
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 440),
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
            let contentSize = NSSize(width: 480, height: 440)
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
