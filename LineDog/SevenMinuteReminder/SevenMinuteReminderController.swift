import AppKit

/// 固定 7 分钟倒计时 + 结束铃铛提醒。与桌宠、`WindowManager`、`PetStageView` 无引用关系，独立窗口层级。
@MainActor
final class SevenMinuteReminderController {
    static let duration: TimeInterval = 7 * 60

    /// 倒计时进行中为 `true`；仅显示铃铛等待点击时为 `false`（可再次开始新的 7 分钟）。
    var onRunningChanged: ((Bool) -> Void)?

    private var countdownWindow: NSWindow?
    private var countdownLabel: NSTextField?
    private var reminderWindow: NSWindow?
    private var reminderCloseTarget: NSObject?
    private var tickTimer: Timer?
    private var remainingSeconds: Int = 0
    private var screenObserver: NSObjectProtocol?

    func start() {
        stopTickTimer()
        tearDownCountdownUI()
        tearDownReminderUI()
        remainingSeconds = Int(Self.duration)
        observeScreensIfNeeded()
        installCountdownWindow()
        refreshCountdownLabel()
        startTickTimer()
        onRunningChanged?(true)
    }

    func cancel() {
        stopTickTimer()
        tearDownCountdownUI()
        tearDownReminderUI()
        removeScreenObserver()
        onRunningChanged?(false)
    }

    private func startTickTimer() {
        stopTickTimer()
        let t = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleTick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        tickTimer = t
    }

    private func stopTickTimer() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func handleTick() {
        remainingSeconds -= 1
        if remainingSeconds <= 0 {
            onCountdownFinished()
            return
        }
        refreshCountdownLabel()
    }

    private func onCountdownFinished() {
        stopTickTimer()
        tearDownCountdownUI()
        onRunningChanged?(false)
        showReminderWindow()
    }

    private func dismissReminder() {
        tearDownReminderUI()
        removeScreenObserver()
    }

    // MARK: - Countdown window（右下角，穿透鼠标）

    private static let countdownSize = NSSize(width: 92, height: 34)

    private static func countdownFrame() -> NSRect {
        let sz = countdownSize
        guard let s = MenuBarNSScreen.screen ?? NSScreen.screens.first else {
            return NSRect(x: 120, y: 120, width: sz.width, height: sz.height)
        }
        let vf = s.visibleFrame
        let m: CGFloat = 10
        let x = vf.maxX - sz.width - m
        let y = vf.minY + m
        return NSRect(x: x, y: y, width: sz.width, height: sz.height)
    }

    private func installCountdownWindow() {
        let frame = Self.countdownFrame()
        let win = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: MenuBarNSScreen.screen ?? NSScreen.screens.first
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 3)
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.isReleasedWhenClosed = false
        win.ignoresMouseEvents = true
        win.hidesOnDeactivate = false

        let label = NSTextField(labelWithString: "7:00")
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        label.textColor = NSColor.labelColor.withAlphaComponent(0.92)
        label.alignment = .center
        label.drawsBackground = true
        label.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.78)
        label.wantsLayer = true
        label.layer?.cornerRadius = 8
        label.layer?.borderWidth = 1
        label.layer?.borderColor = NSColor.separatorColor.cgColor
        label.frame = NSRect(origin: .zero, size: frame.size)
        label.autoresizingMask = [.width, .height]

        win.contentView = label
        countdownWindow = win
        countdownLabel = label
        win.orderFrontRegardless()
    }

    private func repositionCountdownWindow() {
        guard let win = countdownWindow else { return }
        win.setFrame(Self.countdownFrame(), display: true)
    }

    private func refreshCountdownLabel() {
        let s = max(0, remainingSeconds)
        let m = s / 60
        let sec = s % 60
        countdownLabel?.stringValue = String(format: "%d:%02d", m, sec)
    }

    private func tearDownCountdownUI() {
        countdownWindow?.orderOut(nil)
        countdownWindow = nil
        countdownLabel = nil
    }

    // MARK: - Reminder window（屏幕中心，可点关）

    private static let reminderSide: CGFloat = 128

    private static func reminderFrame() -> NSRect {
        let side = reminderSide
        guard let s = MenuBarNSScreen.screen ?? NSScreen.screens.first else {
            return NSRect(x: 200, y: 200, width: side, height: side)
        }
        let vf = s.visibleFrame
        let x = vf.midX - side / 2
        let y = vf.midY - side / 2
        return NSRect(x: x, y: y, width: side, height: side)
    }

    private func showReminderWindow() {
        tearDownReminderUI()
        observeScreensIfNeeded()
        let frame = Self.reminderFrame()
        let win = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: MenuBarNSScreen.screen ?? NSScreen.screens.first
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.isReleasedWhenClosed = false
        win.ignoresMouseEvents = false
        win.hidesOnDeactivate = false

        let container = NSView(frame: NSRect(origin: .zero, size: frame.size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        let symbol =
            NSImage(systemSymbolName: "bell.badge.fill", accessibilityDescription: "提醒")
            ?? NSImage(systemSymbolName: "bell.fill", accessibilityDescription: "提醒")
        let btn = NSButton(image: symbol ?? NSImage(size: NSSize(width: 64, height: 64)), target: nil, action: nil)
        btn.frame = container.bounds.insetBy(dx: 16, dy: 16)
        btn.autoresizingMask = [.width, .height]
        btn.isBordered = false
        btn.imageScaling = .scaleProportionallyUpOrDown
        btn.contentTintColor = .systemOrange

        let target = ReminderBellTarget { [weak self] in
            Task { @MainActor [weak self] in
                self?.dismissReminder()
            }
        }
        reminderCloseTarget = target
        btn.target = target
        btn.action = #selector(ReminderBellTarget.fire)

        container.addSubview(btn)
        win.contentView = container
        reminderWindow = win
        win.orderFrontRegardless()
    }

    private func repositionReminderWindow() {
        guard let win = reminderWindow else { return }
        win.setFrame(Self.reminderFrame(), display: true)
    }

    private func tearDownReminderUI() {
        reminderWindow?.orderOut(nil)
        reminderWindow = nil
        reminderCloseTarget = nil
    }

    // MARK: - Screen changes

    private func observeScreensIfNeeded() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.repositionCountdownWindow()
                self?.repositionReminderWindow()
            }
        }
    }

    private func removeScreenObserver() {
        if let o = screenObserver {
            NotificationCenter.default.removeObserver(o)
            screenObserver = nil
        }
    }
}

// MARK: - NSButton target (no NSObject on controller)

private final class ReminderBellTarget: NSObject {
    private let onFire: () -> Void

    init(onFire: @escaping () -> Void) {
        self.onFire = onFire
        super.init()
    }

    @objc func fire() {
        onFire()
    }
}
