import AppKit
import QuartzCore

/// 周期性喝水提醒：按用户设定间隔（默认 90 分钟）弹出中央浮层，提供「已喝水 💧」/「稍后提醒」操作。
/// 结构仿照 SevenMinuteReminderController：独立浮窗，不经 WindowManager，通过回调汇报调度状态。
/// start()/cancel() 的调用权完全归 AppViewModel，控制器本身不读取 enabled 状态。
/// 弹窗外壳：顶部淡蓝渐变 + 圆角描边阴影（方案 A）。
private final class HydrationReminderCardView: NSView {
    private let gradientLayer = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        guard let layer else { return }
        layer.cornerRadius = 18
        if #available(macOS 11.0, *) {
            layer.cornerCurve = .continuous
        }
        layer.borderWidth = 1
        layer.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowOffset = NSSize(width: 0, height: -4)
        layer.shadowRadius = 14

        gradientLayer.colors = [
            NSColor.systemBlue.withAlphaComponent(0.14).cgColor,
            NSColor.controlBackgroundColor.withAlphaComponent(0.97).cgColor,
        ]
        gradientLayer.locations = [0, 1] as [NSNumber]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.28)
        gradientLayer.cornerRadius = 18
        gradientLayer.masksToBounds = true
        layer.insertSublayer(gradientLayer, at: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
    }
}

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

    /// 测试用：立即弹出喝水浮层（**绕过安静时段**，否则当前在安静窗口内会静默无 UI，像「点了没反应」）。
    func testing_fireNow() {
        fireReminder(bypassQuietHours: true)
    }

    // MARK: - Timer

    static func configuredIntervalMinutes() -> Int {
        let v = UserDefaults.standard.integer(forKey: MalDazeDefaults.hydrationReminderIntervalMinutes)
        if v < 15 { return 90 }
        return min(240, v)
    }

    // MARK: - Quiet hours

    /// 返回当前是否处于用户配置的安静时段（如 21:00–08:00）。
    static func isInQuietHours() -> Bool {
        guard UserDefaults.standard.bool(forKey: MalDazeDefaults.hydrationQuietHoursEnabled) else { return false }
        let startMins = quietStartMinutes()
        let resumeMins = quietResumeMinutes()
        let cal = Calendar.current
        let now = Date()
        let nowMins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        // 跨日时段（如 21:00–08:00）：nowMins >= start 或 nowMins < resume
        // 同日时段（如 08:00–21:00，不常见）：nowMins >= start 且 nowMins < resume
        if startMins > resumeMins {
            return nowMins >= startMins || nowMins < resumeMins
        } else {
            return nowMins >= startMins && nowMins < resumeMins
        }
    }

    /// 距离安静时段结束（恢复时间）还有多少秒。
    static func secondsUntilResume() -> TimeInterval {
        let resumeMins = quietResumeMinutes()
        let cal = Calendar.current
        let now = Date()
        let nowSecs = cal.component(.hour, from: now) * 3600
            + cal.component(.minute, from: now) * 60
            + cal.component(.second, from: now)
        let resumeSecs = resumeMins * 60
        if resumeSecs > nowSecs {
            return TimeInterval(resumeSecs - nowSecs)
        } else {
            return TimeInterval(86400 - nowSecs + resumeSecs)
        }
    }

    static func quietStartMinutes() -> Int {
        let v = UserDefaults.standard.integer(forKey: MalDazeDefaults.hydrationQuietStartMinutes)
        return v > 0 ? v : 1260   // 默认 21:00
    }

    static func quietResumeMinutes() -> Int {
        let v = UserDefaults.standard.integer(forKey: MalDazeDefaults.hydrationQuietResumeMinutes)
        return v > 0 ? v : 480    // 默认 08:00
    }

    private func schedulePendingTimer(after seconds: TimeInterval) {
        pendingTimer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fireReminder(bypassQuietHours: false)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        pendingTimer = t
    }

    private func fireReminder(bypassQuietHours: Bool = false) {
        pendingTimer = nil
        // 若处于安静时段，静默等待至恢复时间，不弹出浮层（测试入口可绕过）。
        if !bypassQuietHours, Self.isInQuietHours() {
            let delay = Self.secondsUntilResume()
            schedulePendingTimer(after: delay)
            return
        }
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

    /// 方案 A：更宽卡片、大按钮与大图标区（与 `docs/hydration-reminder-popup-mockups.html` 一致）。
    private static let reminderMaxTextWidth: CGFloat = 360
    private static let reminderPadding: CGFloat = 22
    private static let reminderIconGap: CGFloat = 14
    private static let reminderIconSide: CGFloat = 64
    private static let buttonH: CGFloat = 48
    private static let buttonGap: CGFloat = 12
    private static let reminderMessageFontSize: CGFloat = 17
    private static let reminderButtonFontSize: CGFloat = 15
    private static let reminderIconSymbolPointSize: CGFloat = 40

    /// `quaternarySystemFill` / `tertiarySystemFill` 等为 macOS 14+；部署目标 13.0 时需回退。
    private static func snoozeButtonBackgroundColor() -> NSColor {
        if #available(macOS 14.0, *) {
            return .quaternarySystemFill
        }
        return NSColor(name: nil) { appearance in
            let dark =
                appearance.name == .darkAqua
                || appearance.name == .vibrantDark
                || appearance.name == .accessibilityHighContrastDarkAqua
            if dark {
                return NSColor.white.withAlphaComponent(0.14)
            }
            return NSColor.black.withAlphaComponent(0.07)
        }
    }

    private static func contentSizeForReminder(message: String) -> NSSize {
        let pad = reminderPadding
        let maxInnerW = reminderMaxTextWidth - 2 * pad
        let font = NSFont.systemFont(ofSize: reminderMessageFontSize, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let rect = (message as NSString).boundingRect(
            with: NSSize(width: max(80, maxInnerW), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        let textH = ceil(max(24, rect.height))
        let w = max(300, min(reminderMaxTextWidth, ceil(rect.width) + 2 * pad))
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

        let win = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: MenuBarNSScreen.screen ?? NSScreen.screens.first
        )
        win.isFloatingPanel = true
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.isReleasedWhenClosed = false
        win.ignoresMouseEvents = false
        win.hidesOnDeactivate = false

        let container = HydrationReminderCardView(frame: NSRect(origin: .zero, size: size))

        let baseSymbol =
            NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "喝水")
            ?? NSImage(size: NSSize(width: 48, height: 48))
        let cfg = NSImage.SymbolConfiguration(pointSize: Self.reminderIconSymbolPointSize, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.systemBlue]))
        let iconImg = baseSymbol.withSymbolConfiguration(cfg) ?? baseSymbol
        let imgView = NSImageView(image: iconImg)
        imgView.imageScaling = .scaleProportionallyUpOrDown
        imgView.imageAlignment = .alignCenter
        imgView.isEditable = false

        let textField = NSTextField(wrappingLabelWithString: message)
        textField.font = NSFont.systemFont(ofSize: Self.reminderMessageFontSize, weight: .semibold)
        textField.textColor = .labelColor
        textField.alignment = .center
        textField.maximumNumberOfLines = 0
        textField.isEditable = false
        textField.isSelectable = false
        textField.isBordered = false
        textField.drawsBackground = false

        let buttonFont = NSFont.systemFont(ofSize: Self.reminderButtonFontSize, weight: .semibold)
        let buttonFontSecondary = NSFont.systemFont(ofSize: Self.reminderButtonFontSize, weight: .medium)

        let doneButton = NSButton(title: "", target: self, action: #selector(doneButtonTapped))
        doneButton.bezelStyle = .rounded
        doneButton.isBordered = false
        doneButton.wantsLayer = true
        doneButton.layer?.cornerRadius = 12
        if #available(macOS 11.0, *) {
            doneButton.layer?.cornerCurve = .continuous
        }
        doneButton.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        doneButton.attributedTitle = NSAttributedString(
            string: "已喝水 💧",
            attributes: [
                .foregroundColor: NSColor.white,
                .font: buttonFont,
            ]
        )
        doneButton.keyEquivalent = "\r"

        let snoozeButton = NSButton(title: "", target: self, action: #selector(snoozeButtonTapped))
        snoozeButton.bezelStyle = .rounded
        snoozeButton.isBordered = false
        snoozeButton.wantsLayer = true
        snoozeButton.layer?.cornerRadius = 12
        if #available(macOS 11.0, *) {
            snoozeButton.layer?.cornerCurve = .continuous
        }
        snoozeButton.layer?.backgroundColor = Self.snoozeButtonBackgroundColor().cgColor
        snoozeButton.layer?.borderWidth = 1
        snoozeButton.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.65).cgColor
        snoozeButton.attributedTitle = NSAttributedString(
            string: "稍后提醒",
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: buttonFontSecondary,
            ]
        )

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
