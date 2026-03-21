import AppKit

/// 桌宠常态小窗在**屏幕坐标**下的 frame，供设置窗、系统权限 sheet 等与小狗同屏显示。
/// 由 `WindowManager` 在常态小窗位置变化时更新（休息全屏阶段不更新，沿用上次常态位置）。
@MainActor
enum LineDogPresentationAnchor {
    private static var idlePetWindowFrameInScreenCoordinates: CGRect = .zero
    private static var hasKnownPetFrame = false

    static func updateIdlePetWindowFrame(_ frame: NSRect) {
        idlePetWindowFrameInScreenCoordinates = frame
        hasKnownPetFrame = true
    }

    /// 桌宠所在 `NSScreen`；尚无记录时退回菜单栏主屏（与 `MenuBarNSScreen` 一致）。
    static func preferredScreenForLineDogAuxiliaryUI() -> NSScreen? {
        if !hasKnownPetFrame {
            return MenuBarNSScreen.screen ?? NSScreen.main
        }
        let p = NSPoint(x: idlePetWindowFrameInScreenCoordinates.midX, y: idlePetWindowFrameInScreenCoordinates.midY)
        if let s = NSScreen.screens.first(where: { $0.frame.contains(p) }) {
            return s
        }
        var best: NSScreen?
        var bestArea: CGFloat = 0
        for s in NSScreen.screens {
            let inter = s.frame.intersection(idlePetWindowFrameInScreenCoordinates)
            let area = inter.width * inter.height
            if area > bestArea {
                bestArea = area
                best = s
            }
        }
        return best ?? MenuBarNSScreen.screen ?? NSScreen.main
    }

    /// 在首选屏的可见区内居中放置给定内容尺寸的窗口 frame（屏幕坐标）。
    static func centeredFrame(forWindowContent size: NSSize, padding: CGFloat = 16) -> NSRect {
        guard let screen = preferredScreenForLineDogAuxiliaryUI() ?? NSScreen.main else {
            return NSRect(origin: .zero, size: size)
        }
        let vf = screen.visibleFrame
        var x = vf.midX - size.width / 2
        var y = vf.midY - size.height / 2
        x = min(max(x, vf.minX + padding), vf.maxX - size.width - padding)
        y = min(max(y, vf.minY + padding), vf.maxY - size.height - padding)
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}

// MARK: - 系统权限 / TCC sheet 锚定

/// `EKEventStore.requestAccess` 等系统弹窗往往跟随**关键窗口**所在屏；LSUIElement 下用透明临时窗占位。
@MainActor
enum LineDogModalKeyWindowAnchor {
    private static var window: NSWindow?

    static func activateEphemeralKeyWindowForSystemModal() {
        NSApp.activate(ignoringOtherApps: true)
        guard let screen = LineDogPresentationAnchor.preferredScreenForLineDogAuxiliaryUI() ?? NSScreen.main else {
            return
        }
        let vf = screen.visibleFrame
        let side: CGFloat = 64
        let r = NSRect(
            x: vf.midX - side / 2,
            y: vf.midY - side / 2,
            width: side,
            height: side
        )
        if window == nil {
            let w = NSWindow(
                contentRect: r,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            w.isOpaque = false
            w.backgroundColor = .clear
            w.alphaValue = 0.001
            w.level = .normal
            w.collectionBehavior = [.canJoinAllSpaces]
            w.ignoresMouseEvents = true
            w.isReleasedWhenClosed = false
            w.hidesOnDeactivate = false
            window = w
        }
        window?.setFrame(r, display: true)
        window?.makeKeyAndOrderFront(nil)
    }

    static func removeEphemeralKeyWindow() {
        window?.orderOut(nil)
    }
}
