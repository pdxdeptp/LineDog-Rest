import AppKit

/// 周期性喝水提醒：按用户设定间隔（默认 90 分钟）弹出中央浮层，提供「已喝水 💧」/「稍后提醒」操作。
/// 结构仿照 SevenMinuteReminderController：独立 NSWindow，不经 WindowManager，通过回调汇报调度状态。
/// start()/cancel() 的调用权完全归 AppViewModel，控制器本身不读取 enabled 状态。
@MainActor
final class HydrationReminderController: NSObject {

    /// 已调度（计时中或浮层待操作）为 `true`；调用 `cancel()` 后变 `false`。
    var onStateChanged: ((Bool) -> Void)?

    private var reminderWindow: NSWindow?
    private var pendingTimer: Timer?
    private var screenObserver: NSObjectProtocol?
    private var lastMessage: String = ""

    // MARK: - Public API

    func start() {
        cancel()
        schedulePendingTimer(after: TimeInterval(Self.configuredIntervalMinutes() * 60))
        onStateChanged?(true)
    }

    func cancel() {
        pendingTimer?.invalidate()
        pendingTimer = nil
        tearDownReminderWindow()
        removeScreenObserver()
        onStateChanged?(false)
    }

    /// 测试用：立即弹出喝水浮层，不影响正在运行的 pendingTimer。
    func testing_fireNow() {
        fireReminder()
    }

    // MARK: - Timer

    static func configuredIntervalMinutes() -> Int {
        let v = UserDefaults.standard.integer(forKey: MalDazeDefaults.hydrationReminderIntervalMinutes)
        if v < 15 { return 90 }
        return min(240, v)
    }

    private func schedulePendingTimer(after seconds: TimeInterval) {
        pendingTimer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fireReminder()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        pendingTimer = t
    }

    private func fireReminder() {
        pendingTimer = nil
        tearDownReminderWindow()
        observeScreensIfNeeded()
        let messages = [
            "我是一个小渴鬼🤔，你也应该喝点水？",
            "*舔舔嘴唇* 🤍 时间喝水～",
            "喝水喝水喝水！💧",
            "主人，喝水啦～",
        ]
        showReminderWindow(message: messages.randomElement() ?? messages[0])
    }

    // MARK: - Button actions

    @objc private func doneButtonTapped() {
        tearDownReminderWindow()
        removeScreenObserver()
        schedulePendingTimer(after: TimeInterval(Self.configuredIntervalMinutes() * 60))
    }

    @objc private func snoozeButtonTapped() {
        tearDownReminderWindow()
        removeScreenObserver()
        schedulePendingTimer(after: 15 * 60)
    }

    // MARK: - Reminder window

    private static let reminderMaxTextWidth: CGFloat = 280
    private static let reminderPadding: CGFloat = 20
    private static let reminderIconGap: CGFloat = 12
    private static let reminderIconSide: CGFloat = 52
    private static let buttonH: CGFloat = 32
    private static let buttonGap: CGFloat = 10

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
        let w = max(220, min(reminderMaxTextWidth, ceil(rect.width) + 2 * pad))
        let buttonsH = buttonH * 2 + buttonGap
        let h = pad + reminderIconSide + reminderIconGap + textH + reminderIconGap + buttonsH + pad
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
        lastMessage = message
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
            NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "喝水")
            ?? NSImage(size: NSSize(width: 48, height: 48))
        let cfg = NSImage.SymbolConfiguration(pointSize: 36, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.systemBlue]))
        let iconImg = baseSymbol.withSymbolConfiguration(cfg) ?? baseSymbol
        let imgView = NSImageView(image: iconImg)
        imgView.imageScaling = .scaleProportionallyUpOrDown
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

        let doneButton = NSButton(title: "已喝水 💧", target: self, action: #selector(doneButtonTapped))
        doneButton.bezelStyle = .rounded
        doneButton.keyEquivalent = "\r"

        let snoozeButton = NSButton(title: "稍后提醒", target: self, action: #selector(snoozeButtonTapped))
        snoozeButton.bezelStyle = .rounded

        let pad = Self.reminderPadding
        let iconY = size.height - pad - Self.reminderIconSide
        imgView.frame = NSRect(
            x: (size.width - Self.reminderIconSide) / 2,
            y: iconY,
            width: Self.reminderIconSide,
            height: Self.reminderIconSide
        )

        // layout bottom-up: pad | snooze | gap | done | gap | text | gap | icon | pad
        let snoozeY = pad
        let doneY = snoozeY + Self.buttonH + Self.buttonGap
        let textY = doneY + Self.buttonH + Self.reminderIconGap
        let textH = max(24, iconY - Self.reminderIconGap - textY)

        let btnW = size.width - 2 * pad
        snoozeButton.frame = NSRect(x: pad, y: snoozeY, width: btnW, height: Self.buttonH)
        doneButton.frame = NSRect(x: pad, y: doneY, width: btnW, height: Self.buttonH)
        textField.frame = NSRect(x: pad, y: textY, width: btnW, height: textH)

        container.addSubview(imgView)
        container.addSubview(textField)
        container.addSubview(doneButton)
        container.addSubview(snoozeButton)

        win.contentView = container
        reminderWindow = win
        win.orderFrontRegardless()
    }

    private func tearDownReminderWindow() {
        reminderWindow?.orderOut(nil)
        reminderWindow = nil
    }

    private func repositionReminderWindow() {
        guard let win = reminderWindow else { return }
        let sz = Self.contentSizeForReminder(message: lastMessage)
        win.setFrame(Self.reminderFrame(contentSize: sz), display: true)
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
