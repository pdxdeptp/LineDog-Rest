import AppKit

/// 在启动完成后再设置激活策略；避免在 `App.init` 里调 `setActivationPolicy`（会导致 XCTest 宿主早期崩溃）。
/// `.regular` + 非 `LSUIElement`：Dock 图标、Cmd+Tab、Mission Control 中可见桌宠等 `NSWindow`。
final class LineDogAppDelegate: NSObject, NSApplicationDelegate {
    /// 全局快捷键监听（需「辅助功能」授权才能在其他 App 前台时生效）。
    private var globalLineDogKeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            LineDogDefaults.geminiModelId: LineDogDefaults.defaultGeminiModelId,
            LineDogDefaults.sevenMinuteReminderDurationMinutes: 7,
        ])
        if NSApp.activationPolicy() != .regular {
            _ = NSApp.setActivationPolicy(.regular)
        }
        // 与右下角桌宠同一套素材逻辑（`LineDogPet` 或 `dog.fill` + 白边），不改动 `PetRenderer`。
        NSApp.applicationIconImage = LineDogDockIcon.makeImage()
        // 桌宠菜单：Carbon 全局热键（不依赖「辅助功能」）；`NSEvent.addGlobalMonitor` 未授权时返回 nil，按键会落到 Finder 并响系统提示音。
        LineDogCarbonGlobalHotKeys.start()

        globalLineDogKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // ⌥⌘R：备用唤起智能输入（仍依赖辅助功能；默认 ⌘⇧< 由 Carbon 注册，无需此项）
            if flags.contains([.command, .option]),
               event.charactersIgnoringModifiers?.lowercased() == "r" {
                NotificationCenter.default.post(
                    name: LineDogBroadcastNotifications.openSmartReminderInput,
                    object: nil
                )
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        LineDogCarbonGlobalHotKeys.stop()
        if let globalLineDogKeyMonitor {
            NSEvent.removeMonitor(globalLineDogKeyMonitor)
        }
    }

    /// Dock 图标被再次点按时，激活应用并把桌宠窗提到前层（休息霸屏时仍为 `screenSaver` 层级，由 `WindowManager` 管理）。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        if let w = sender.windows.first(where: { $0.identifier?.rawValue == WindowManager.deskPetWindowIdentifier }) {
            w.orderFrontRegardless()
        }
        return true
    }
}
