import AppKit

enum PassiveCenteredOverlayGeometry {
    static func centeredFrame(contentSize: NSSize) -> NSRect {
        guard let screen = MenuBarNSScreen.screen ?? NSScreen.screens.first else {
            return NSRect(x: 200, y: 200, width: contentSize.width, height: contentSize.height)
        }
        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.midX - contentSize.width / 2
        let y = visibleFrame.midY - contentSize.height / 2
        return NSRect(x: x, y: y, width: contentSize.width, height: contentSize.height)
    }

    static func makePassivePanel(frame: NSRect) -> NSPanel {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: MenuBarNSScreen.screen ?? NSScreen.screens.first
        )
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        return panel
    }
}
