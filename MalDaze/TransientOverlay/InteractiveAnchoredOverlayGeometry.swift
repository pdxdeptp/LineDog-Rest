import AppKit

/// 默认 `NSPanel` 常为 `canBecomeKey == false`，无边框浮动窗无法成为第一响应者。
final class SmartReminderKeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

enum InteractiveAnchoredOverlayGeometry {
    private static let positioningGap: CGFloat = 10
    private static let positioningMargin: CGFloat = 10

    static func makeInputPanelShell(contentSize: NSSize) -> SmartReminderKeyablePanel {
        let panel = SmartReminderKeyablePanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        return panel
    }

    static func makeToastPanelShell(contentSize: NSSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        return panel
    }

    static func positionPanel(_ panel: NSWindow, anchor: NSRect, size: NSSize) {
        let frame = frameTopCenter(anchor: anchor, size: size, visibleFrame: visibleFrame(for: anchor))
        panel.setFrame(frame, display: true)
    }

    static func frameTopCenter(anchor: NSRect, size: NSSize, visibleFrame: NSRect) -> NSRect {
        let maxWidth = max(visibleFrame.width - 2 * positioningMargin, 1)
        let maxHeight = max(visibleFrame.height - 2 * positioningMargin, 1)
        let width = min(size.width, maxWidth)
        let height = min(size.height, maxHeight)

        let minX = visibleFrame.minX + positioningMargin
        let maxX = visibleFrame.maxX - positioningMargin - width
        let unclampedX = anchor.midX - width / 2
        let x = clamp(unclampedX, lower: minX, upper: maxX)

        let aboveY = anchor.maxY + positioningGap
        let belowY = anchor.minY - positioningGap - height
        let preferredY = aboveY + height <= visibleFrame.maxY - positioningMargin ? aboveY : belowY
        let minY = visibleFrame.minY + positioningMargin
        let maxY = visibleFrame.maxY - positioningMargin - height
        let y = clamp(preferredY, lower: minY, upper: maxY)

        return NSRect(x: x, y: y, width: width, height: height)
    }

    private static func visibleFrame(for anchor: NSRect) -> NSRect {
        let screen = NSScreen.screens.first { $0.visibleFrame.intersects(anchor) }
            ?? NSScreen.screens.first { $0.frame.intersects(anchor) }
            ?? NSScreen.main
        return screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
