import AppKit

/// 在启动完成后再对齐 accessory 策略；避免在 `App.init` 里调 `setActivationPolicy`（会导致 XCTest 宿主早期崩溃），同时减轻「仅 MenuBarExtra」时独立 NSWindow 不出现的问题。
final class LineDogAppDelegate: NSObject, NSApplicationDelegate {
    /// ⌥⌘R：唤起智能提醒输入（全局；需「辅助功能」授权才能捕获其他 App 内按键）。
    private var globalSmartInputKeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSApp.activationPolicy() != .accessory {
            _ = NSApp.setActivationPolicy(.accessory)
        }
        globalSmartInputKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.contains([.command, .option]),
                  event.charactersIgnoringModifiers?.lowercased() == "r"
            else { return }
            NotificationCenter.default.post(
                name: LineDogBroadcastNotifications.openSmartReminderInput,
                object: nil
            )
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let globalSmartInputKeyMonitor {
            NSEvent.removeMonitor(globalSmartInputKeyMonitor)
        }
    }
}
