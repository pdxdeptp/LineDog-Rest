import AppKit

/// 可配置时长（默认 7 分钟）的倒计时 + 结束铃铛提醒。中心铃铛展示委托 `MalDazeTransientOverlayPresenter`。
@MainActor
final class SevenMinuteReminderController {
    /// 倒计时进行中为 `true`；仅显示铃铛等待点击时为 `false`（可再次开始）。
    var onRunningChanged: ((Bool) -> Void)?

    private let overlayPresenter: MalDazeTransientOverlayPresenting
    private var countdownWindow: NSWindow?
    private var countdownLabel: NSTextField?
    private var tickTimer: Timer?
    private var remainingSeconds: Int = 0
    private var startedDurationMinutes: Int = 7
    private var screenObserver: NSObjectProtocol?
    private var lastReminderMessage: String = ""
    private var completionMessage: String = ""

    init(overlayPresenter: MalDazeTransientOverlayPresenting) {
        self.overlayPresenter = overlayPresenter
    }

    func start() {
        start(minutes: Self.configuredDurationMinutes(), completionMessage: "")
    }

    /// Hermes 强提醒：使用契约分钟数与结束文案（非 UserDefaults 默认时长）。
    func start(minutes: Int, completionMessage: String) {
        stopTickTimer()
        tearDownCountdownUI()
        overlayPresenter.dismissCenterBell()
        let clamped = min(180, max(1, minutes))
        startedDurationMinutes = clamped
        self.completionMessage = completionMessage
        remainingSeconds = clamped * 60
        observeScreensIfNeeded()
        installCountdownWindow()
        refreshCountdownLabel()
        startTickTimer()
        onRunningChanged?(true)
    }

    /// 单测：立即触发倒计时结束铃铛（不等待真实时间）。
    func testing_finishCountdownImmediately() {
        remainingSeconds = 0
        onCountdownFinished()
    }

    var testing_lastReminderMessage: String { lastReminderMessage }

    func cancel() {
        stopTickTimer()
        tearDownCountdownUI()
        overlayPresenter.dismissCenterBell()
        removeScreenObserver()
        completionMessage = ""
        onRunningChanged?(false)
    }

    /// 与倒计时结束相同 UI：中央铃铛 + 文案，点击任意处关闭。
    func presentCenterBellReminder(message: String = "计时结束") {
        lastReminderMessage = message
        overlayPresenter.presentCenterBell(message: message, onDismiss: {})
    }

    /// 仅关闭中央铃铛浮层，不影响独立倒计时条。
    func dismissCenterBellReminderIfShowing() {
        overlayPresenter.dismissCenterBell()
    }

    var isCenterBellReminderVisible: Bool { overlayPresenter.isCenterBellVisible }

    private static func configuredDurationMinutes() -> Int {
        var v = UserDefaults.standard.integer(forKey: MalDazeDefaults.sevenMinuteReminderDurationMinutes)
        if v < 1 { v = 7 }
        return min(180, v)
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
        removeScreenObserver()
        onRunningChanged?(false)
        let message = completionMessage.isEmpty
            ? "\(startedDurationMinutes) 分钟计时结束"
            : completionMessage
        completionMessage = ""
        presentCenterBellReminder(message: message)
    }

    // MARK: - Countdown window（右下角，穿透鼠标）

    private static let countdownSize = NSSize(width: 104, height: 34)

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

        let label = NSTextField(labelWithString: "0:00")
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
