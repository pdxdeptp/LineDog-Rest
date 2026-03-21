import AppKit

/// 固定 7 分钟倒计时 + 结束铃铛提醒。与桌宠、`WindowManager`、`PetStageView` 无引用关系，独立窗口层级。
@MainActor
final class SevenMinuteReminderController {
    static let duration: TimeInterval = 7 * 60

    /// 7 分钟倒计时正常结束时的中央面板默认说明。
    static let defaultSevenMinuteEndMessage = "7 分钟计时结束"

    /// 倒计时进行中为 `true`；仅显示铃铛等待点击时为 `false`（可再次开始新的 7 分钟）。
    var onRunningChanged: ((Bool) -> Void)?

    private var countdownWindow: NSWindow?
    private var countdownLabel: NSTextField?
    private var reminderWindow: NSWindow?
    private var tickTimer: Timer?
    private var remainingSeconds: Int = 0
    private var screenObserver: NSObjectProtocol?
    private var lastReminderMessage: String = ""

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

    /// 与倒计时结束相同 UI：中央铃铛 + 文案，点击任意处关闭。
    func presentCenterBellReminder(message: String = SevenMinuteReminderController.defaultSevenMinuteEndMessage) {
        observeScreensIfNeeded()
        showReminderWindow(message: message)
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
        showReminderWindow(message: Self.defaultSevenMinuteEndMessage)
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

    // MARK: - Reminder window（屏幕中心，铃铛 + 文案，点按关闭）

    private static let reminderMaxTextWidth: CGFloat = 280
    private static let reminderPadding: CGFloat = 20
    private static let reminderIconGap: CGFloat = 12
    private static let reminderIconSide: CGFloat = 52

    private static func contentSizeForReminder(message: String) -> NSSize {
        let pad = reminderPadding
        let maxInnerW = reminderMaxTextWidth - 2 * pad
        let font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let rect = (message as NSString).boundingRect(
            with: NSSize(width: max(80, maxInnerW), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        let textH = ceil(max(24, rect.height))
        let w = max(200, min(reminderMaxTextWidth, ceil(rect.width) + 2 * pad))
        let h = pad + reminderIconSide + reminderIconGap + textH + pad
        return NSSize(width: w, height: h)
    }

    private static func reminderFrame(contentSize: NSSize) -> NSRect {
        guard let s = MenuBarNSScreen.screen ?? NSScreen.screens.first else {
            return NSRect(x: 200, y: 200, width: contentSize.width, height: contentSize.height)
        }
        let vf = s.visibleFrame
        let x = vf.midX - contentSize.width / 2
        let y = vf.midY - contentSize.height / 2
        return NSRect(x: x, y: y, width: contentSize.width, height: contentSize.height)
    }

    private func showReminderWindow(message: String) {
        lastReminderMessage = message
        tearDownReminderUI()
        observeScreensIfNeeded()
        let size = Self.contentSizeForReminder(message: message)
        let frame = Self.reminderFrame(contentSize: size)
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

        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.94).cgColor
        container.layer?.cornerRadius = 16
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor
        container.layer?.shadowColor = NSColor.black.cgColor
        container.layer?.shadowOpacity = 0.22
        container.layer?.shadowOffset = NSSize(width: 0, height: -3)
        container.layer?.shadowRadius = 12

        let baseSymbol =
            NSImage(systemSymbolName: "bell.badge.fill", accessibilityDescription: "提醒")
            ?? NSImage(systemSymbolName: "bell.fill", accessibilityDescription: "提醒")
            ?? NSImage(size: NSSize(width: 48, height: 48))
        let cfg = NSImage.SymbolConfiguration(pointSize: 36, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.systemOrange]))
        let iconImg = baseSymbol.withSymbolConfiguration(cfg) ?? baseSymbol
        let imgView = NSImageView(image: iconImg)
        imgView.imageScaling = NSImageScaling.scaleProportionallyUpOrDown
        imgView.imageAlignment = .alignCenter
        imgView.isEditable = false

        let textField = NSTextField(wrappingLabelWithString: message)
        textField.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        textField.textColor = .labelColor
        textField.alignment = .center
        textField.maximumNumberOfLines = 0
        textField.isEditable = false
        textField.isSelectable = false
        textField.isBordered = false
        textField.drawsBackground = false

        let pad = Self.reminderPadding
        let iconY = size.height - pad - Self.reminderIconSide
        imgView.frame = NSRect(
            x: (size.width - Self.reminderIconSide) / 2,
            y: iconY,
            width: Self.reminderIconSide,
            height: Self.reminderIconSide
        )
        let textY = pad
        let textH = iconY - Self.reminderIconGap - textY
        textField.frame = NSRect(x: pad, y: textY, width: size.width - 2 * pad, height: max(24, textH))

        let overlay = ReminderDismissPanelView(frame: container.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor.clear.cgColor
        overlay.onDismiss = { [weak self] in
            Task { @MainActor [weak self] in
                self?.dismissReminder()
            }
        }

        container.addSubview(imgView)
        container.addSubview(textField)
        container.addSubview(overlay)

        win.contentView = container
        reminderWindow = win
        win.orderFrontRegardless()
    }

    private func repositionReminderWindow() {
        guard let win = reminderWindow else { return }
        let sz = Self.contentSizeForReminder(message: lastReminderMessage)
        win.setFrame(Self.reminderFrame(contentSize: sz), display: true)
    }

    private func tearDownReminderUI() {
        reminderWindow?.orderOut(nil)
        reminderWindow = nil
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

// MARK: - 点击面板任意处关闭

private final class ReminderDismissPanelView: NSView {
    var onDismiss: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onDismiss?()
    }
}
