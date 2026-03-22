import AppKit

/// 在启动完成后再对齐 accessory 策略；避免在 `App.init` 里调 `setActivationPolicy`（会导致 XCTest 宿主早期崩溃），同时减轻「仅 MenuBarExtra」时独立 NSWindow 不出现的问题。
final class LineDogAppDelegate: NSObject, NSApplicationDelegate {
    /// 全局快捷键监听（需「辅助功能」授权才能在其他 App 前台时生效）。
    private var globalLineDogKeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            LineDogDefaults.geminiModelId: LineDogDefaults.defaultGeminiModelId,
        ])
        if NSApp.activationPolicy() != .accessory {
            _ = NSApp.setActivationPolicy(.accessory)
        }
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
}
