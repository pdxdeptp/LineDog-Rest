import AppKit

/// 在启动完成后再对齐 accessory 策略；避免在 `App.init` 里调 `setActivationPolicy`（会导致 XCTest 宿主早期崩溃），同时减轻「仅 MenuBarExtra」时独立 NSWindow 不出现的问题。
final class LineDogAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSApp.activationPolicy() != .accessory {
            _ = NSApp.setActivationPolicy(.accessory)
        }
    }
}
