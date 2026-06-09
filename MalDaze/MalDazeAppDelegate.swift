import AppKit

/// 在启动完成后再设置激活策略；避免在 `App.init` 里调 `setActivationPolicy`（会导致 XCTest 宿主早期崩溃）。
/// `.regular` + 非 `LSUIElement`：Dock 图标、Cmd+Tab、Mission Control 中可见桌宠等 `NSWindow`。
@MainActor
final class MalDazeAppDelegate: NSObject, NSApplicationDelegate {
    /// 全局快捷键监听（需「辅助功能」授权才能在其他 App 前台时生效）。
    private var globalMalDazeKeyMonitor: Any?

    override init() {
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            MalDazeDefaults.geminiModelId: MalDazeDefaults.defaultGeminiModelId,
            MalDazeDefaults.sevenMinuteReminderDurationMinutes: 7,
            MalDazeDefaults.pomodoroWorkDurationMinutes: 25,
            MalDazeDefaults.pomodoroRestDurationMinutes: 5,
            MalDazeDefaults.idlePetIconSidePoints: MalDazeDefaults.idlePetIconSideDefault,
            MalDazeDefaults.learningDailyCapacityHours: MalDazeDefaults.defaultLearningDailyCapacityHours,
        ])
        if NSApp.activationPolicy() != .regular {
            _ = NSApp.setActivationPolicy(.regular)
        }
        // 与右下角桌宠同一套素材逻辑（`MalDazePet` 或 `dog.fill` + 白边），不改动 `PetRenderer`。
        NSApp.applicationIconImage = MalDazeDockIcon.makeImage()
        // 桌宠菜单：Carbon 全局热键（不依赖「辅助功能」）；`NSEvent.addGlobalMonitor` 未授权时返回 nil，按键会落到 Finder 并响系统提示音。
        MalDazeCarbonGlobalHotKeys.start()

        globalMalDazeKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // ⌥⌘R：备用唤起智能输入（仍依赖辅助功能；默认 ⌘⇧< 由 Carbon 注册，无需此项）
            if flags.contains([.command, .option]),
               event.charactersIgnoringModifiers?.lowercased() == "r" {
                NotificationCenter.default.post(
                    name: MalDazeBroadcastNotifications.openSmartReminderInput,
                    object: nil
                )
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        T7EjectAppLifecycleRegistry.shared.stopRegisteredService()
        MalDazeCarbonGlobalHotKeys.stop()
        if let globalMalDazeKeyMonitor {
            NSEvent.removeMonitor(globalMalDazeKeyMonitor)
        }
    }

    /// Dock 图标被再次点按时，激活应用并 show/focus Dashboard（不关已打开的窗口）。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: MalDazeBroadcastNotifications.focusDashboardFromDock, object: nil)
        return true
    }
}
