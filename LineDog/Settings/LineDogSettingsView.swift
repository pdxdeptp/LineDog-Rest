import AppKit
import SwiftUI

/// 设置窗口：Gemini API Key、全局快捷键等。
struct LineDogSettingsView: View {
    @AppStorage(LineDogDefaults.geminiAPIKey) private var geminiAPIKey = ""
    @AppStorage(LineDogDefaults.geminiModelId) private var geminiModelId = LineDogDefaults.defaultGeminiModelId

    @AppStorage(LineDogDefaults.smartReminderInputShortcutKeyCode) private var smartKeyCode: Int = Int(SmartReminderInputShortcut.defaultKeyCode)
    @AppStorage(LineDogDefaults.smartReminderInputShortcutModifiers) private var smartModifiersRaw: Int = SmartReminderInputShortcut.defaultModifiersStorageInt
    @AppStorage(LineDogDefaults.smartReminderInputShortcutKeyLabel) private var smartKeyLabel: String = SmartReminderInputShortcut.default.keyLabel

    @AppStorage(LineDogDefaults.deskPetMenuShortcutKeyCode) private var deskKeyCode: Int = Int(DeskPetMenuShortcut.defaultKeyCode)
    @AppStorage(LineDogDefaults.deskPetMenuShortcutModifiers) private var deskModifiersRaw: Int = DeskPetMenuShortcut.defaultModifiersStorageInt
    @AppStorage(LineDogDefaults.deskPetMenuShortcutKeyLabel) private var deskKeyLabel: String = DeskPetMenuShortcut.default.keyLabel

    @AppStorage(LineDogDefaults.sevenMinuteReminderShortcutKeyCode) private var sevenKeyCode: Int = Int(SevenMinuteReminderShortcut.defaultKeyCode)
    @AppStorage(LineDogDefaults.sevenMinuteReminderShortcutModifiers) private var sevenModifiersRaw: Int = SevenMinuteReminderShortcut.defaultModifiersStorageInt
    @AppStorage(LineDogDefaults.sevenMinuteReminderShortcutKeyLabel) private var sevenKeyLabel: String = SevenMinuteReminderShortcut.default.keyLabel

    @State private var isRecordingSmartShortcut = false
    @State private var isRecordingDeskShortcut = false
    @State private var isRecordingSevenMinuteShortcut = false

    private var shortcutRecorderBusy: Bool {
        isRecordingSmartShortcut || isRecordingDeskShortcut || isRecordingSevenMinuteShortcut
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

    var body: some View {
        Form {
            Section {
                SecureField("Gemini API Key", text: $geminiAPIKey)
                    .textFieldStyle(.roundedBorder)
                LabeledContent("Gemini 模型") {
                    Picker("", selection: $geminiModelId) {
                        ForEach(LineDogGeminiModelCatalog.pickerOptions) { opt in
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
                Text("上述「添加提醒」快捷键由系统全局热键注册，通常无需「辅助功能」。另可选用 ⌥⌘R（需在「隐私与安全性 → 辅助功能」中授权 LineDog）。")
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
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 420)
        .padding()
        .onAppear {
            let ids = Set(LineDogGeminiModelCatalog.pickerOptions.map(\.id))
            if !ids.contains(geminiModelId) {
                geminiModelId = LineDogDefaults.defaultGeminiModelId
            }
        }
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
enum LineDogSettingsWindowPresenter {
    private static var window: NSWindow?
    private static let windowDelegate = CloseHidesDelegate()

    /// 菜单栏代理应用需显式 `NSWindow`；与 SwiftUI `Settings` 场景并存，共享同一 `LineDogSettingsView` / `@AppStorage`。
    static func present() {
        NSApp.activate(ignoringOtherApps: true)
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 440),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            w.title = "LineDog 设置"
            w.isReleasedWhenClosed = false
            w.delegate = windowDelegate
            w.level = .floating
            let host = NSHostingController(rootView: LineDogSettingsView())
            w.contentViewController = host
            let contentSize = NSSize(width: 480, height: 440)
            let outerSize = w.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
            w.setFrame(LineDogPresentationAnchor.centeredFrame(forWindowContent: outerSize), display: false)
            window = w
        } else if let w = window {
            w.setFrame(LineDogPresentationAnchor.centeredFrame(forWindowContent: w.frame.size), display: true)
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
