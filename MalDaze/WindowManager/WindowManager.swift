import AppKit
import SwiftUI

/// 桌宠 / 休息霸屏窗：默认 `NSWindow` 在仅菜单栏（accessory）应用里往往 `canBecomeKey == false`，
/// 导致左键 `clickCount` 无法累加，**双击永远到不了 2**。休息结束依赖双击时必须可成为 key。
private final class PetStageWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// 跑屏模式固定在屏幕左下角的倒计时视图；点击 20 次可提前结束休息。
private final class BreakRunCountdownView: NSView {
    let label = NSTextField(labelWithString: "5:00")
    var onTwentyClicks: (() -> Void)?
    private var clickCount = 0
    private var lastClickAt: TimeInterval = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.52).cgColor
        layer?.cornerRadius = 15
        layer?.masksToBounds = true

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 72, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        label.isBordered = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.timestamp - lastClickAt > 3.0 { clickCount = 0 }
        lastClickAt = event.timestamp
        clickCount += 1
        if clickCount >= 20 {
            clickCount = 0
            onTwentyClicks?()
        }
    }
}

/// 供 `AppViewModel` 与单元测试注入；生产环境由 `WindowManager` 实现。
protocol WindowManaging: AnyObject {
    /// - Parameter bringIdlePetWindowToFront: 为 `false` 时，在桌宠已为小窗且无需缩回霸屏的路径下**不**调用 `orderFrontRegardless`，
    ///   避免从菜单栏 `MenuBarExtra` 操作时桌宠抢焦点导致菜单窗被系统收起。
    func dismissRestImmediately(bringIdlePetWindowToFront: Bool)
    func presentRest(duration: TimeInterval, onDismissed: @escaping () -> Void)
    /// 跑屏休息模式（PawPal 风格）：桌宠小窗在屏幕工作区内弹跳漫游，不霸屏。
    func presentBreakRun(duration: TimeInterval, onDismissed: @escaping () -> Void)
    func applyIdlePetDisplayMode(_ mode: PetDisplayMode)
    /// 绑定后右下角桌宠可点击弹出与菜单栏相同的 `MenuBarContentView`；单测用 `MockWindowManager` 空实现即可。
    func bindDeskPetMenu(viewModel: AppViewModel?)
    /// `true`（默认）：休息全屏时窗口接收鼠标，挡桌面；`false`：休息时鼠标穿透，不挡操作。
    func setRestBlocksClicks(_ blocks: Bool)

    /// 智能输入单行面板；`anchorRectInScreen` 为桌宠区域（屏幕坐标），用于定位在头顶上方。
    func presentSmartReminderInput(anchorRectInScreen: NSRect, onSubmit: @escaping (String) -> Void, onCancel: @escaping () -> Void)
    /// 无桌宠框时（或未安装窗）：用菜单栏屏可见区底部中点上方。
    func presentSmartReminderInputFromGlobalShortcut(onSubmit: @escaping (String) -> Void, onCancel: @escaping () -> Void)
    /// 全局快捷键：锚在桌宠上与左键相同，弹出 `MenuBarContentView`。
    func presentDeskMenuFromGlobalShortcut()
    func dismissSmartReminderInput()
    func showSmartReminderToast(
        message: String,
        showUndo: Bool,
        onUndo: @escaping () -> Void,
        onAutoDismiss: @escaping () -> Void
    )
    func dismissSmartReminderToast()
    /// 提醒已成功写入后调用：仅当草稿仍与本次提交原文一致时清空（避免异步返回时覆盖用户新开面板后的输入）。
    func clearSmartReminderInputDraftIfStillMatchesSubmittedText(_ submitted: String)
    /// 常态桌宠窗回到菜单栏屏可见区右下角并写入 UserDefaults；休息霸屏中不执行。
    func resetIdlePetPositionToDefaultCorner()
    /// `MalDazeDefaults.idlePetIconSidePoints` 变更后：按新边长调整桌宠小窗与命中区。
    func applyIdlePetIconSideFromUserDefaults()
}

extension WindowManaging {
    /// 默认仍会把小窗桌宠 `orderFront`，以保持与其它入口一致；从菜单栏改模式等路径请传 `false`。
    func dismissRestImmediately() {
        dismissRestImmediately(bringIdlePetWindowToFront: true)
    }
}

/// 模块 2：常态为**仅桌宠大小**的透明小窗（可拖动，位置持久化）；休息时扩展为菜单栏屏全屏霸屏。同一只 `PetStageView`。
@MainActor
final class WindowManager: WindowManaging {
    /// 桌宠 `NSWindow.identifier`，供 `NSApplicationDelegate.applicationShouldHandleReopen` 等前置窗口。
    static let deskPetWindowIdentifier = "com.maldaze.deskPetStage"

    private var window: NSWindow?
    private var stageView: PetStageView?
    private weak var deskMenuViewModel: AppViewModel?
    /// 桌宠旁浮动控制面板（非 `NSPopover`：可右对齐锚点并在 SwiftUI 内自绘底部小三角）。
    private var deskMenuPanel: NSPanel?
    private var deskMenuHosting: NSHostingController<AnyView>?
    /// Custom transient-dismiss monitor（原 `.transient` Popover 行为）。
    private var transientMonitor: Any?
    /// 桌宠浮动菜单：Esc 关闭（与 `SmartReminder` 输入框的 Esc 监听同理，用本地监视器吃掉按键避免系统咚声）。
    private var deskMenuEscMonitor: Any?
    private var dismissObservers: [NSObjectProtocol] = []
    /// 启动后对 `deskMenuPanel` 做一次静默预热（alpha=0），提前触发 SwiftUI 首次 layout。
    private var isPrewarming = false
    private var prewarmCloseWorkItem: DispatchWorkItem?
    private var pendingDismiss: (() -> Void)?
    private var screenObserver: NSObjectProtocol?
    private var primaryDisplayObserver: NSObjectProtocol?
    private var launchObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var screenRepositionWorkItem: DispatchWorkItem?
    /// 常态下以 10 Hz 轮询光标位置，动态切换 `ignoresMouseEvents`，确保透明区域不吞焦点。
    private var idleCursorTrackTimer: Timer?
    /// 跑屏模式驱动器（PawPal breakRun 算法移植）。
    private let breakRunController = BreakRunController()
    /// 跑屏倒计时更新定时器（1 Hz，更新 PetStageView 的小标签）。
    private var breakRunCountdownTimer: Timer?
    /// 跑屏1分钟后展示遮罩的延迟任务。
    private var breakRunShieldWorkItem: DispatchWorkItem?
    /// 跑屏1分钟后展示的全屏半透明遮罩窗口（阻止用户点击桌面）。
    private var breakRunShieldWindow: NSPanel?
    /// 跑屏模式全程显示在屏幕左下角的独立倒计时面板（与遮罩无关）。
    private var breakRunCountdownPanel: NSPanel?
    private var breakRunCountdownView: BreakRunCountdownView?

    /// 进入休息全屏前一刻的常态小窗框，用于结束后回到原位置（与 `UserDefaults` 一致）。
    private var idleFrameBeforeRest: NSRect?

    /// `AppViewModel` 可能在宠物窗创建之前就 `syncPetDisplayMode`，需记住并在首屏安装时应用。
    private var pendingIdlePetMode: PetDisplayMode = .runningBlack
    /// 与 `AppViewModel.restBlocksClicksDuringRest` 同步；仅影响**休息全屏**阶段的鼠标是否穿透。
    private var restBlocksClicks: Bool = true

    private var smartInputPanel: NSPanel?
    /// 用户取消智能输入时回调（Esc / 点外部 /「取消」）；提交成功前清除且不调用。
    private var smartInputUserOnCancel: (() -> Void)?
    private var smartInputEscapeMonitor: Any?
    /// 本应用内点击面板外关闭（不依赖辅助功能）。
    private var smartInputLocalMouseMonitor: Any?
    /// 系统全局点击面板外关闭（需辅助功能授权）。
    private var smartInputClickAwayMonitor: Any?
    private var smartToastPanel: NSPanel?
    private var smartToastDismiss: Timer?
    /// 智能输入框草稿：点外部 / Esc /「取消」关闭后面板不丢字；回车提交成功后清空。
    private var smartReminderInputDraft: String = ""

    init() {
        // SwiftUI + 仅 MenuBarExtra 时，`AppViewModel` 初始化可能早于应用完成启动；窗口层级未就绪会导致「有进程但桌宠窗从未真正出现」。
        // 用「启动完成通知 + 下一拍 main」双通道，先到的负责安装，另一路被 `window == nil` 守卫挡掉。
        launchObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.installPetWindowIfNeeded()
            }
        }
        DispatchQueue.main.async { [weak self] in
            Task { @MainActor [weak self] in
                self?.installPetWindowIfNeeded()
            }
        }
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.persistIdlePetFrameIfIdleSized()
            }
        }
    }

    deinit {
        idleCursorTrackTimer?.invalidate()
        breakRunCountdownTimer?.invalidate()
        breakRunShieldWorkItem?.cancel()
        prewarmCloseWorkItem?.cancel()
        breakRunShieldWindow?.orderOut(nil)
        breakRunCountdownPanel?.orderOut(nil)
        if let launchObserver {
            NotificationCenter.default.removeObserver(launchObserver)
        }
        if let terminateObserver {
            NotificationCenter.default.removeObserver(terminateObserver)
        }
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        if let primaryDisplayObserver {
            NotificationCenter.default.removeObserver(primaryDisplayObserver)
        }
    }

    /// 菜单栏所在物理显示器（`CGMainDisplayID`），不随当前焦点 App 在哪块屏上而变。
    private static func primaryDisplay() -> (screen: NSScreen, frame: NSRect) {
        let screens = NSScreen.screens
        precondition(!screens.isEmpty, "MalDaze requires at least one NSScreen")
        if let menuBar = MenuBarNSScreen.screen {
            return (menuBar, menuBar.frame)
        }
        let s = screens[0]
        return (s, s.frame)
    }

    private static let idlePetOriginXKey = "MalDaze.idlePetOriginX"
    private static let idlePetOriginYKey = "MalDaze.idlePetOriginY"
    /// 图标与透明窗边界的留白（单侧）；原 150×150 窗内约 120pt 图标 → 每侧 15。
    private static let idlePetWindowMarginEachSide: CGFloat = 15

    private static func resolvedIdlePetIconSidePoints() -> CGFloat {
        let raw = UserDefaults.standard.integer(forKey: MalDazeDefaults.idlePetIconSidePoints)
        return CGFloat(MalDazeDefaults.clampedIdlePetIconSidePoints(stored: raw))
    }

    private static func idlePetWindowSideLength() -> CGFloat {
        resolvedIdlePetIconSidePoints() + 2 * idlePetWindowMarginEachSide
    }

    private static func idlePetWindowSize() -> NSSize {
        let s = idlePetWindowSideLength()
        return NSSize(width: s, height: s)
    }

    /// 首次启动：菜单栏屏可见区右下角默认位。
    private static func defaultIdlePetWindowFrame() -> NSRect {
        let w = idlePetWindowSize().width
        let h = idlePetWindowSize().height
        guard let s = MenuBarNSScreen.screen ?? NSScreen.screens.first else {
            return NSRect(x: 100, y: 100, width: w, height: h)
        }
        let vf = s.visibleFrame
        let m: CGFloat = 10
        let x = vf.maxX - w - m
        let y = vf.minY + m
        return NSRect(x: x, y: y, width: w, height: h)
    }

    private static func loadPersistedIdlePetFrame() -> NSRect? {
        let d = UserDefaults.standard
        guard d.object(forKey: idlePetOriginXKey) != nil,
              d.object(forKey: idlePetOriginYKey) != nil
        else { return nil }
        let x = d.double(forKey: idlePetOriginXKey)
        let y = d.double(forKey: idlePetOriginYKey)
        let sz = idlePetWindowSize()
        return NSRect(x: x, y: y, width: sz.width, height: sz.height)
    }

    private static func isApproximatelyIdleSized(_ rect: NSRect) -> Bool {
        let target = idlePetWindowSideLength()
        return abs(rect.width - target) < 24 && abs(rect.height - target) < 24
    }

    /// 至少与某块屏的 `frame` 有足够交集则保留位置（支持副屏）；完全离开所有屏则退回默认角。
    private static func clampIdlePetFrameToScreens(_ rect: NSRect) -> NSRect {
        let sz = idlePetWindowSize()
        let r = NSRect(origin: rect.origin, size: sz)
        let union = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        let inter = union.intersection(r)
        if inter.width >= 32, inter.height >= 32 {
            return r
        }
        return defaultIdlePetWindowFrame()
    }

    /// 启动或需要默认位时：读盘 → 默认角 → 夹紧。
    private static func resolvedIdlePetFrameForInstall() -> NSRect {
        if let saved = loadPersistedIdlePetFrame() {
            return clampIdlePetFrameToScreens(saved)
        }
        return defaultIdlePetWindowFrame()
    }

    private func persistIdlePetFrame(_ frame: NSRect) {
        guard Self.isApproximatelyIdleSized(frame) else { return }
        let d = UserDefaults.standard
        d.set(frame.origin.x, forKey: Self.idlePetOriginXKey)
        d.set(frame.origin.y, forKey: Self.idlePetOriginYKey)
        postIdlePetScreenFrameChanged(frame)
    }

    private func postIdlePetScreenFrameChanged(_ frame: NSRect) {
        guard Self.isApproximatelyIdleSized(frame), stageView?.isInRestPhase != true else { return }
        MalDazePresentationAnchor.updateIdlePetWindowFrame(frame)
        NotificationCenter.default.post(
            name: MalDazeBroadcastNotifications.idlePetScreenFrameChanged,
            object: nil,
            userInfo: [MalDazeBroadcastNotifications.idlePetScreenFrameUserInfoKey: NSValue(rect: frame)]
        )
    }

    private func persistIdlePetFrameIfIdleSized() {
        guard let f = window?.frame, stageView?.isInRestPhase != true else { return }
        guard Self.isApproximatelyIdleSized(f) else { return }
        persistIdlePetFrame(f)
    }

    private func installPetWindowIfNeeded() {
        guard window == nil else { return }
        if let obs = launchObserver {
            NotificationCenter.default.removeObserver(obs)
            launchObserver = nil
        }

        let primary = Self.primaryDisplay()
        let frame = Self.resolvedIdlePetFrameForInstall()

        let win = PetStageWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: primary.screen
        )
        win.identifier = NSUserInterfaceItemIdentifier(Self.deskPetWindowIdentifier)
        win.alphaValue = 1
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .floating
        // `.fullScreenAuxiliary` 在多显示器 + 透明无边框窗上常被合成到桌面之下，表现为「双屏时桌宠整块没了」。
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.isReleasedWhenClosed = false
        win.hidesOnDeactivate = false

        let view = PetStageView(frame: NSRect(origin: .zero, size: frame.size))
        wireDeskPetCallbacks(into: view)
        win.contentView = view
        window = win
        stageView = view
        win.orderFrontRegardless()
        syncContentViewToWindowLayout()
        view.applyNonRestPetDisplayMode(pendingIdlePetMode)
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        // applyMousePolicy 必须在 layoutSubtreeIfNeeded 之后：layout() → layoutIdlePet() 会
        // 计算 petHitRect；若提前调用，petHitRect == .zero，syncIdleWindowMousePolicy 会把
        // ignoresMouseEvents 设为 true，导致启动后首次点击穿透到桌面无响应。
        applyMousePolicy()
        postIdlePetScreenFrameChanged(win.frame)

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRepositionToPrimaryDisplay()
        }
        // Swift 未暴露该常量时用手写名称；用户在「显示器」设置里调换主屏时会发此通知。
        primaryDisplayObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("NSWorkspaceActiveDisplayDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRepositionToPrimaryDisplay()
        }

        // 多屏插拔后 `NSScreen` / window 布局常晚一拍才稳定，再对齐一次。
        scheduleRepositionToPrimaryDisplay()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            Task { @MainActor [weak self] in
                self?.repositionToPrimaryDisplay()
            }
        }
    }

    func bindDeskPetMenu(viewModel: AppViewModel?) {
        deskMenuViewModel = viewModel
        tearDownPopoverDismissMonitor()
        deskMenuPanel?.orderOut(nil)
        deskMenuPanel = nil
        deskMenuHosting = nil
        if let v = stageView {
            wireDeskPetCallbacks(into: v)
        }
        if viewModel != nil {
            _ = makeDeskMenuPanelIfNeeded()
        }
        applyMousePolicy()
        if deskMenuPanel != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.prewarmDeskMenuIfNeeded()
            }
        }
    }

    private func wireDeskPetCallbacks(into v: PetStageView) {
        v.deskMenuPresenter = deskMenuViewModel != nil ? self : nil
        v.onIdlePetFramePersist = { [weak self] r in
            self?.persistIdlePetFrame(r)
        }
        v.onRestPhaseGeometryChanged = { [weak self] in
            self?.syncPetRestWindowMousePolicy()
        }
        if deskMenuViewModel != nil {
            v.onRestPetDoubleClickEndRest = { [weak self] in
                self?.deskMenuViewModel?.endRestEarlyFromDeskPet()
            }
        } else {
            v.onRestPetDoubleClickEndRest = nil
        }
        v.idlePetIconSidePoints = Self.resolvedIdlePetIconSidePoints()
    }

    func setRestBlocksClicks(_ blocks: Bool) {
        restBlocksClicks = blocks
        applyMousePolicy()
    }

    func presentRest(duration: TimeInterval, onDismissed: @escaping () -> Void) {
        closeDeskMenuImmediate()
        installPetWindowIfNeeded()
        dismissRestImmediately()
        idleFrameBeforeRest = window?.frame
        pendingDismiss = onDismissed
        stageView?.snapshotRestPetStartStateBeforeExpandingToRest()
        expandWindowToMenuBarScreenFullFrame()
        setWindowLevel(resting: true)
        stageView?.beginRestCycle(total: duration) { [weak self] in
            self?.finishRestCycle()
        }
        applyMousePolicy()
    }

    /// 右下角桌宠在非休息时的配色（计时中黑 / 停止白边）。
    func applyIdlePetDisplayMode(_ mode: PetDisplayMode) {
        pendingIdlePetMode = mode
        stageView?.applyNonRestPetDisplayMode(mode)
    }

    func resetIdlePetPositionToDefaultCorner() {
        installPetWindowIfNeeded()
        guard let win = window, let stage = stageView else { return }
        guard !stage.isInRestPhase else { return }
        stage.idlePetIconSidePoints = Self.resolvedIdlePetIconSidePoints()
        let target = Self.clampIdlePetFrameToScreens(Self.defaultIdlePetWindowFrame())
        win.setFrame(target, display: true)
        syncContentViewToWindowLayout()
        stage.needsLayout = true
        stage.layoutSubtreeIfNeeded()
        persistIdlePetFrame(target)
        applyMousePolicy()
        win.orderFrontRegardless()
    }

    func applyIdlePetIconSideFromUserDefaults() {
        installPetWindowIfNeeded()
        guard let win = window, let stage = stageView else { return }
        guard !stage.isInRestPhase, !stage.isInBreakRunPhase else { return }
        let iconSide = Self.resolvedIdlePetIconSidePoints()
        stage.idlePetIconSidePoints = iconSide
        let sideLen = Self.idlePetWindowSideLength()
        var f = win.frame
        let anchor = CGPoint(x: f.midX, y: f.midY)
        f.size = NSSize(width: sideLen, height: sideLen)
        f.origin.x = anchor.x - f.width / 2
        f.origin.y = anchor.y - f.height / 2
        let clamped = Self.clampIdlePetFrameToScreens(f)
        win.setFrame(clamped, display: true)
        syncContentViewToWindowLayout()
        stage.needsLayout = true
        stage.layoutSubtreeIfNeeded()
        persistIdlePetFrameIfIdleSized()
        applyMousePolicy()
    }

    func dismissRestImmediately(bringIdlePetWindowToFront: Bool) {
        closeDeskMenuImmediate()
        let callback = pendingDismiss
        pendingDismiss = nil

        // 同时停止跑屏（若正在跑屏模式）
        hideBreakRunShield()
        hideBreakRunCountdownPanel()
        stopBreakRunCountdownTimer()
        // 记录是否正在跑屏，以及出发前帧（stop() 之前检查）
        let wasBreakRun = breakRunController.isRunning
        let savedIdleFrame = idleFrameBeforeRest
        if wasBreakRun { idleFrameBeforeRest = nil }
        breakRunController.stop()
        stageView?.cancelToIdle()
        setWindowLevel(resting: false)

        // #region agent log
        MalDazeAgentDebugNDJSON.log(hypothesisId: "H-dismiss", location: "WindowManager.dismissRestImmediately", message: "dismiss_branch", data: ["wasBreakRun": "\(wasBreakRun)", "savedIdleFrame": "\(savedIdleFrame as Any)", "window_frame": "\(window?.frame ?? .zero)"])
        // #endregion

        if let wf = window?.frame, !Self.isApproximatelyIdleSized(wf) {
            // 霸屏模式：先通知 AppViewModel，再缩回小窗
            callback?()
            shrinkWindowToIdlePetFrame()
        } else if wasBreakRun, let r = savedIdleFrame, Self.isApproximatelyIdleSized(r) {
            // 跑屏模式：动画飞回出发前位置，动画结束后再通知 AppViewModel
            let target = Self.clampIdlePetFrameToScreens(r)
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 1.0
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.window?.animator().setFrame(target, display: true)
            }, completionHandler: { [weak self] in
                guard let self else { return }
                // #region agent log
                MalDazeAgentDebugNDJSON.log(hypothesisId: "H-dismiss", location: "WindowManager.dismissRestImmediately.completion", message: "breakrun_animation_done", data: ["final_frame": "\(self.window?.frame ?? .zero)"])
                // #endregion
                syncContentViewToWindowLayout()
                stageView?.needsLayout = true
                stageView?.layoutSubtreeIfNeeded()
                applyMousePolicy()
                window?.orderFrontRegardless()
                persistIdlePetFrame(target)
                callback?()
            })
        } else {
            // 跑屏但无出发前帧记录，或其他情况
            callback?()
            applyMousePolicy()
            if bringIdlePetWindowToFront {
                window?.orderFrontRegardless()
            }
        }
    }

    func presentBreakRun(duration: TimeInterval, onDismissed: @escaping () -> Void) {
        closeDeskMenuImmediate()
        installPetWindowIfNeeded()
        // 清理任何可能残留的霸屏/跑屏状态（不触发 onDismissed 回调）
        hideBreakRunShield()
        hideBreakRunCountdownPanel()
        stopBreakRunCountdownTimer()
        breakRunController.stop()
        stageView?.cancelToIdle()
        setWindowLevel(resting: false)

        guard let win = window, let stage = stageView else { return }
        idleFrameBeforeRest = win.frame          // 记住出发前位置，结束后动画返回
        pendingDismiss = onDismissed
        stage.beginBreakRunDisplay(total: duration)

        // 启动跑屏弹跳
        breakRunController.start(window: win, duration: duration) { [weak self] in
            self?.finishBreakRun()
        }

        // 1 Hz 倒计时更新
        startBreakRunCountdownTimer(duration: duration)
        // 屏幕左下角固定倒计时面板（全跑屏期间显示）
        showBreakRunCountdownPanel(duration: duration)
        applyMousePolicy()
        win.orderFrontRegardless()
    }

    private func finishBreakRun() {
        hideBreakRunShield()
        hideBreakRunCountdownPanel()
        stopBreakRunCountdownTimer()
        breakRunController.stop()
        // 立即重置 view 状态（不再响应跑屏点击），动画期间 pet 已是常态小图标
        stageView?.cancelBreakRunToIdle()
        window?.level = .floating

        let cb = pendingDismiss
        pendingDismiss = nil

        // 慢慢飞回休息开始前的位置（1秒缓动动画）；cb?() 必须在动画结束后调用，
        // 否则 resumeEngineRestOverlayIfNeeded 会立即再启动一轮跑屏并取消当前动画。
        let target: NSRect
        if let r = idleFrameBeforeRest, Self.isApproximatelyIdleSized(r) {
            target = Self.clampIdlePetFrameToScreens(r)
        } else {
            target = Self.resolvedIdlePetFrameForInstall()
        }
        idleFrameBeforeRest = nil
        // #region agent log
        MalDazeAgentDebugNDJSON.log(hypothesisId: "H-animate", location: "WindowManager.finishBreakRun", message: "animation_start", data: ["target": "\(target)", "window_frame": "\(window?.frame ?? .zero)"])
        // #endregion
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 1.0
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window?.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            guard let self else { return }
            // #region agent log
            MalDazeAgentDebugNDJSON.log(hypothesisId: "H-animate", location: "WindowManager.finishBreakRun.completion", message: "animation_done", data: ["final_frame": "\(self.window?.frame ?? .zero)"])
            // #endregion
            syncContentViewToWindowLayout()
            stageView?.needsLayout = true
            stageView?.layoutSubtreeIfNeeded()
            applyMousePolicy()
            window?.orderFrontRegardless()
            persistIdlePetFrame(target)
            cb?()
        })
    }

    private func startBreakRunCountdownTimer(duration: TimeInterval) {
        stopBreakRunCountdownTimer()

        // 60秒后展示半透明遮罩，阻止用户点击桌面
        if duration > 60 {
            let item = DispatchWorkItem { [weak self] in
                Task { @MainActor [weak self] in self?.showBreakRunShield() }
            }
            breakRunShieldWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: item)
        }

        let startDate = Date()
        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(startDate)
                let remaining = max(0, duration - elapsed)
                stageView?.updateBreakRunCountdown(remaining: remaining)
                updateBreakRunCountdownPanel(remaining: remaining)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        breakRunCountdownTimer = t
    }

    private func stopBreakRunCountdownTimer() {
        breakRunCountdownTimer?.invalidate()
        breakRunCountdownTimer = nil
        breakRunShieldWorkItem?.cancel()
        breakRunShieldWorkItem = nil
    }

    // MARK: - 跑屏遮罩（1分钟后阻止点击桌面）

    private func showBreakRunShield() {
        guard breakRunShieldWindow == nil else { return }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        // 遮罩层级比 .screenSaver(1000) 低2级；倒计时面板在 screenSaver-1 确保在遮罩之上
        let shieldLevel = NSWindow.Level(rawValue: Int(NSWindow.Level.screenSaver.rawValue) - 2)
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.20)
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = shieldLevel
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.orderFrontRegardless()
        breakRunShieldWindow = panel
        // 桌宠窗升到 .screenSaver，保证在遮罩之上仍可点击
        window?.level = .screenSaver
        window?.orderFrontRegardless()
        // 遮罩出现后停止光标追踪定时器：定时器每100ms会把窗口设为 ignoresMouseEvents=true
        // 导致点击穿透到遮罩被吸收，宠物再也无法被点击。改为永久可点击，hitTest 负责过滤非宠物区域。
        stopIdleCursorTracking()
        window?.ignoresMouseEvents = false
        // 确保倒计时面板在遮罩之上（level 已是 screenSaver-1 > 遮罩 screenSaver-2）
        breakRunCountdownPanel?.orderFrontRegardless()
    }

    private func hideBreakRunShield() {
        breakRunShieldWindow?.orderOut(nil)
        breakRunShieldWindow = nil
    }

    // MARK: - 跑屏固定倒计时面板（屏幕左下角）

    private func showBreakRunCountdownPanel(duration: TimeInterval) {
        hideBreakRunCountdownPanel()
        guard let screen = MenuBarNSScreen.screen ?? NSScreen.screens.first else { return }
        let vf = screen.visibleFrame
        let panelSize = NSSize(width: 300, height: 108)
        let origin = NSPoint(x: vf.minX + 48, y: vf.minY + 48)
        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        // level = screenSaver-1（999）；遮罩在 screenSaver-2（998），pet 在 screenSaver（1000）
        panel.level = NSWindow.Level(rawValue: Int(NSWindow.Level.screenSaver.rawValue) - 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false

        let cv = BreakRunCountdownView(frame: NSRect(origin: .zero, size: panelSize))
        cv.onTwentyClicks = { [weak self] in
            Task { @MainActor [weak self] in
                self?.deskMenuViewModel?.endRestEarlyFromDeskPet()
            }
        }
        panel.contentView = cv
        panel.orderFrontRegardless()
        breakRunCountdownPanel = panel
        breakRunCountdownView = cv

        let total = max(0, Int(floor(duration)))
        cv.label.stringValue = String(format: "%d:%02d", total / 60, total % 60)
    }

    private func hideBreakRunCountdownPanel() {
        breakRunCountdownPanel?.orderOut(nil)
        breakRunCountdownPanel = nil
        breakRunCountdownView = nil
    }

    private func updateBreakRunCountdownPanel(remaining: TimeInterval) {
        let total = max(0, Int(floor(remaining)))
        breakRunCountdownView?.label.stringValue = String(format: "%d:%02d", total / 60, total % 60)
    }

    private func finishRestCycle() {
        setWindowLevel(resting: false)
        shrinkWindowToIdlePetFrame()
        let callback = pendingDismiss
        pendingDismiss = nil
        callback?()
    }

    private func setWindowLevel(resting: Bool) {
        window?.level = resting ? .screenSaver : .floating
        window?.orderFrontRegardless()
    }

    /// 插拔显示器时连续发通知，防抖后只做一次完整对齐，避免读到陈旧的 `NSScreen` 几何。
    private func scheduleRepositionToPrimaryDisplay() {
        screenRepositionWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.repositionToPrimaryDisplay()
            }
        }
        screenRepositionWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: item)
    }

    /// 把 `contentView` 贴满父视图（主题框内的 clip 区）。仅用 `contentLayoutRect` 时，在新系统上可能与 `frame` 有环带差，点击会落在 `PetStageView` 外仍被本窗吞掉，表现为「穿透失效」。
    private func syncContentViewToWindowLayout() {
        guard let win = window, let cv = win.contentView else { return }
        cv.autoresizingMask = [.width, .height]
        if let parent = cv.superview {
            cv.frame = parent.bounds
        } else {
            cv.frame = win.contentLayoutRect
        }
    }

    private func repositionToPrimaryDisplay() {
        let frame: NSRect
        if stageView?.isInRestPhase == true {
            frame = Self.primaryDisplay().frame
        } else if let wf = window?.frame, Self.isApproximatelyIdleSized(wf) {
            frame = Self.clampIdlePetFrameToScreens(wf)
        } else {
            frame = Self.resolvedIdlePetFrameForInstall()
        }
        window?.setFrame(frame, display: true)
        syncContentViewToWindowLayout()
        stageView?.needsLayout = true
        stageView?.layoutSubtreeIfNeeded()
        applyMousePolicy()
        window?.orderFrontRegardless()
        if stageView?.isInRestPhase != true {
            persistIdlePetFrameIfIdleSized()
        }
    }

    private func expandWindowToMenuBarScreenFullFrame() {
        let frame = Self.primaryDisplay().frame
        window?.setFrame(frame, display: true)
        syncContentViewToWindowLayout()
        stageView?.needsLayout = true
        stageView?.layoutSubtreeIfNeeded()
        window?.orderFrontRegardless()
    }

    private func shrinkWindowToIdlePetFrame() {
        let target: NSRect
        if let r = idleFrameBeforeRest, Self.isApproximatelyIdleSized(r) {
            target = Self.clampIdlePetFrameToScreens(r)
            idleFrameBeforeRest = nil
        } else if let wf = window?.frame, Self.isApproximatelyIdleSized(wf) {
            target = Self.clampIdlePetFrameToScreens(wf)
        } else {
            target = Self.resolvedIdlePetFrameForInstall()
            idleFrameBeforeRest = nil
        }
        window?.setFrame(target, display: true)
        syncContentViewToWindowLayout()
        stageView?.needsLayout = true
        stageView?.layoutSubtreeIfNeeded()
        applyMousePolicy()
        window?.orderFrontRegardless()
        persistIdlePetFrame(target)
    }

    private func applyMousePolicy() {
        guard let win = window else { return }
        stageView?.restUserBlocksClicksOutsidePet = restBlocksClicks
        guard deskMenuViewModel != nil else {
            win.ignoresMouseEvents = true
            stopIdleCursorTracking()
            return
        }
        if stageView?.isInRestPhase == true {
            stopIdleCursorTracking()
            syncPetRestWindowMousePolicy()
            return
        }
        // 跑屏模式：窗口是小窗，复用常态的光标轨迹逻辑（50×50 区域内不穿透）。
        // 常态：根据光标实时位置决定是否透传，防止透明区域抢焦点。
        startIdleCursorTracking()
        syncIdleWindowMousePolicy()
    }

    private func startIdleCursorTracking() {
        guard idleCursorTrackTimer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.syncIdleWindowMousePolicy() }
        }
        RunLoop.main.add(t, forMode: .common)
        idleCursorTrackTimer = t
    }

    private func stopIdleCursorTracking() {
        idleCursorTrackTimer?.invalidate()
        idleCursorTrackTimer = nil
    }

    /// 光标在宠物屏幕命中区内 → 窗口接收鼠标；光标在外 → 完全透传（不抢焦点）。
    private func syncIdleWindowMousePolicy() {
        guard let win = window, let stage = stageView else { return }
        guard !stage.isInRestPhase, deskMenuViewModel != nil else { return }
        let petScreen = win.convertToScreen(stage.petHitRectInWindowBaseCoordinates)
        win.ignoresMouseEvents = !petScreen.contains(NSEvent.mouseLocation)
    }

    /// 休息且允许「狗外穿透」时：光标不在狗的屏幕命中区内则整窗 `ignoresMouseEvents = true`（系统级穿透）；在狗上则关闭，以便单击菜单 / 双击结束。
    private func syncPetRestWindowMousePolicy() {
        guard let win = window, let stage = stageView else { return }
        guard deskMenuViewModel != nil else {
            win.ignoresMouseEvents = true
            return
        }
        guard stage.isInRestPhase else {
            win.ignoresMouseEvents = false
            return
        }
        let liberalPassThrough = !restBlocksClicks || !stage.restApproachAnimationComplete
        if !liberalPassThrough {
            win.ignoresMouseEvents = false
            return
        }
        let petInWindow = stage.petHitRectInWindowBaseCoordinates
        let petScreen = win.convertToScreen(petInWindow)
        win.ignoresMouseEvents = !petScreen.contains(NSEvent.mouseLocation)
    }

    // MARK: - 智能提醒输入 / 气泡（PRD Smart Input）

    private func teardownSmartInputPanel(invokeUserCancel: Bool) {
        if let m = smartInputEscapeMonitor {
            NSEvent.removeMonitor(m)
            smartInputEscapeMonitor = nil
        }
        if let m = smartInputLocalMouseMonitor {
            NSEvent.removeMonitor(m)
            smartInputLocalMouseMonitor = nil
        }
        if let m = smartInputClickAwayMonitor {
            NSEvent.removeMonitor(m)
            smartInputClickAwayMonitor = nil
        }
        smartInputPanel?.close()
        smartInputPanel = nil
        let cb = smartInputUserOnCancel
        smartInputUserOnCancel = nil
        if invokeUserCancel {
            cb?()
        }
    }

    private func installSmartInputDismissMonitors() {
        smartInputEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.smartInputPanel != nil else { return event }
            guard event.keyCode == 53 else { return event }
            self.teardownSmartInputPanel(invokeUserCancel: true)
            return nil
        }
        smartInputLocalMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, let panel = self.smartInputPanel else { return event }
            if !panel.frame.contains(NSEvent.mouseLocation) {
                self.teardownSmartInputPanel(invokeUserCancel: true)
            }
            return event
        }
        // 点其它 App / 桌面时关闭（需辅助功能）；否则依赖本地监听 + Esc +「取消」。
        smartInputClickAwayMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let panel = self.smartInputPanel else { return }
                if !panel.frame.contains(NSEvent.mouseLocation) {
                    self.teardownSmartInputPanel(invokeUserCancel: true)
                }
            }
        }
    }

    func presentSmartReminderInput(
        anchorRectInScreen: NSRect,
        onSubmit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        teardownSmartInputPanel(invokeUserCancel: false)
        smartInputUserOnCancel = onCancel
        let anchor = anchorRectInScreen.width > 1 && anchorRectInScreen.height > 1
            ? anchorRectInScreen
            : Self.defaultSmartInputAnchorInScreen()
        let draftBinding = Binding<String>(
            get: { [weak self] in self?.smartReminderInputDraft ?? "" },
            set: { [weak self] newValue in self?.smartReminderInputDraft = newValue }
        )
        let (panel, _) = SmartReminderUIPanels.makeInputPanel(
            draft: draftBinding,
            onSubmit: { [weak self] text in
                guard let self else { return }
                self.teardownSmartInputPanel(invokeUserCancel: false)
                onSubmit(text)
            },
            onCancel: { [weak self] in
                self?.teardownSmartInputPanel(invokeUserCancel: true)
            }
        )
        smartInputPanel = panel
        SmartReminderUIPanels.positionPanelTopCenter(panel, anchor: anchor, size: panel.frame.size)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(panel.contentView)
        installSmartInputDismissMonitors()
        DispatchQueue.main.async { [weak panel] in
            guard let panel else { return }
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(panel.contentView)
        }
    }

    func presentSmartReminderInputFromGlobalShortcut(
        onSubmit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        // 与桌宠菜单快捷键一致：已打开时再按同一全局快捷键则关闭（等同 Esc / 取消）。
        if smartInputPanel != nil {
            teardownSmartInputPanel(invokeUserCancel: true)
            return
        }
        installPetWindowIfNeeded()
        let anchor = window.map { $0.frame } ?? Self.defaultSmartInputAnchorInScreen()
        presentSmartReminderInput(anchorRectInScreen: anchor, onSubmit: onSubmit, onCancel: onCancel)
    }

    func presentDeskMenuFromGlobalShortcut() {
        installPetWindowIfNeeded()
        guard let stage = stageView, deskMenuViewModel != nil else { return }
        presentDeskMenu(from: stage, anchorRect: stage.deskMenuShortcutAnchorRect)
    }

    func dismissSmartReminderInput() {
        teardownSmartInputPanel(invokeUserCancel: false)
    }

    func showSmartReminderToast(
        message: String,
        showUndo: Bool,
        onUndo: @escaping () -> Void,
        onAutoDismiss: @escaping () -> Void
    ) {
        dismissSmartReminderToast()
        let (panel, _, size) = SmartReminderUIPanels.makeToastPanel(
            message: message,
            showUndo: showUndo,
            onUndo: { [weak self] in
                self?.dismissSmartReminderToast()
                onUndo()
            }
        )
        smartToastPanel = panel
        let anchor = window.map { $0.frame } ?? Self.defaultSmartInputAnchorInScreen()
        SmartReminderUIPanels.positionPanelTopCenter(panel, anchor: anchor, size: size)
        panel.orderFrontRegardless()
        smartToastDismiss = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismissSmartReminderToast()
                onAutoDismiss()
            }
        }
        if let t = smartToastDismiss {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    func dismissSmartReminderToast() {
        smartToastDismiss?.invalidate()
        smartToastDismiss = nil
        smartToastPanel?.close()
        smartToastPanel = nil
    }

    func clearSmartReminderInputDraftIfStillMatchesSubmittedText(_ submitted: String) {
        if smartReminderInputDraft == submitted {
            smartReminderInputDraft = ""
        }
    }

    private static func defaultSmartInputAnchorInScreen() -> NSRect {
        guard let vf = NSScreen.main?.visibleFrame else { return .zero }
        return NSRect(x: vf.midX - 1, y: vf.minY + 120, width: 2, height: 2)
    }
}

// MARK: - 右下角桌宠弹出菜单（复用 `MenuBarContentView`）

extension WindowManager: PetStageDeskMenuPresenter {
    func presentSmartReminderInput(from stage: PetStageView, anchorRect: NSRect) {
        guard let vm = deskMenuViewModel, let win = stage.window else { return }
        let screenAnchor = win.convertToScreen(anchorRect)
        vm.userRequestedSmartReminderInput(screenAnchor: screenAnchor)
    }

    /// 创建或复用桌宠旁浮动面板（`NSPanel` + `MenuBarContentView`）。
    private func makeDeskMenuPanelIfNeeded() -> NSPanel? {
        guard let vm = deskMenuViewModel else { return nil }
        if let existing = deskMenuPanel { return existing }

        let size = MenuBarContentView.deskPetPanelContentSize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false

        // 与 MenuBarExtra 同款：NSVisualEffectView(.popover) 提供系统级毛玻璃背景与圆角，
        // 取代原先在 SwiftUI 层手绘的 RoundedRectangle + .regularMaterial。
        let effectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 12
        effectView.layer?.masksToBounds = true
        panel.contentView = effectView

        let host = NSHostingController(
            rootView: AnyView(
                MenuBarContentView(viewModel: vm)
                    .environment(\.maldazeDeskMenuPresentation, .deskPetFloatingPanel)
            )
        )
        host.view.translatesAutoresizingMaskIntoConstraints = true
        host.view.frame = effectView.bounds
        host.view.autoresizingMask = [.width, .height]
        effectView.addSubview(host.view)
        panel.setContentSize(size)

        deskMenuPanel = panel
        deskMenuHosting = host
        return panel
    }

    /// 右对齐桌宠锚点：面板右缘贴近锚区右缘，避免系统 Popover 箭头落在第 2、3 栏之间。
    private func deskMenuPanelFrame(anchorScreen: NSRect) -> NSRect {
        let size = MenuBarContentView.deskPetPanelContentSize
        let screen = NSScreen.screens.first(where: { NSIntersectsRect($0.frame, anchorScreen) }) ?? NSScreen.main!
        let vf = screen.visibleFrame
        let gap: CGFloat = 6
        var originX = anchorScreen.maxX - size.width
        originX = min(originX, vf.maxX - size.width - 4)
        originX = max(originX, vf.minX + 4)
        let originY = anchorScreen.maxY + gap
        return NSRect(x: originX, y: originY, width: size.width, height: size.height)
    }

    /// 立即收起桌宠菜单（无动画）；保留 `deskMenuPanel` 实例供复用。
    private func closeDeskMenuImmediate() {
        tearDownPopoverDismissMonitor()
        deskMenuPanel?.orderOut(nil)
        deskMenuPanel?.alphaValue = 1
        deskMenuPanel?.ignoresMouseEvents = false
    }

    /// 启动后悄悄 `orderFront` 一次浮动面板（alpha=0，ignoresMouseEvents=true），
    /// 触发 SwiftUI 首次 layout，使用户第一次点击桌宠时面板能瞬间出现。
    ///
    /// - 预热窗口完全透明且不拦截鼠标，用户不会察觉。
    /// - 0.4s 后自动关闭；用户若在预热期间点击，由 `presentDeskMenu` 中止预热并立即展示面板。
    private func prewarmDeskMenuIfNeeded() {
        guard !isPrewarming,
              let panel = makeDeskMenuPanelIfNeeded(),
              let stage = stageView,
              !panel.isVisible else { return }

        isPrewarming = true
        guard let petWin = stage.window else {
            isPrewarming = false
            return
        }
        let anchor = petWin.convertToScreen(stage.deskMenuShortcutAnchorRect)
        let frame = deskMenuPanelFrame(anchorScreen: anchor)
        panel.alphaValue = 0
        panel.ignoresMouseEvents = true
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()

        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isPrewarming else { return }
            self.isPrewarming = false
            self.prewarmCloseWorkItem = nil
            if let panel = self.deskMenuPanel {
                panel.ignoresMouseEvents = false
                panel.orderOut(nil)
                panel.alphaValue = 1
            }
        }
        prewarmCloseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    func presentDeskMenu(from stage: PetStageView, anchorRect: NSRect) {
        guard let vm = deskMenuViewModel else { return }
        guard let panel = makeDeskMenuPanelIfNeeded() else { return }

        if let host = deskMenuHosting {
            host.rootView = AnyView(
                MenuBarContentView(viewModel: vm)
                    .environment(\.maldazeDeskMenuPresentation, .deskPetFloatingPanel)
            )
        }

        if panel.isVisible {
            if isPrewarming {
                prewarmCloseWorkItem?.cancel()
                prewarmCloseWorkItem = nil
                isPrewarming = false
                panel.ignoresMouseEvents = false
                panel.orderOut(nil)
                panel.alphaValue = 1
            } else {
                closeDeskMenuPanelWithFade()
                return
            }
        }

        let capturedAnchor = anchorRect
        DispatchQueue.main.async { [weak self, weak panel, weak stage] in
            guard let self, let panel, !panel.isVisible, let stage, let petWin = stage.window else { return }
            NSApp.activate(ignoringOtherApps: true)
            let screenAnchor = petWin.convertToScreen(capturedAnchor)
            let frame = self.deskMenuPanelFrame(anchorScreen: screenAnchor)
            panel.setFrame(frame, display: true)
            panel.ignoresMouseEvents = false
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.14
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
            if let host = self.deskMenuHosting, let vm = self.deskMenuViewModel {
                host.rootView = AnyView(
                    MenuBarContentView(viewModel: vm)
                        .environment(\.maldazeDeskMenuPresentation, .deskPetFloatingPanel)
                )
            }
            self.installPopoverDismissMonitor()
        }
    }

    // MARK: - 桌宠菜单 Dismiss 监视器

    /// 安装全局鼠标点击监视器 + App 失活监视器（原 `NSPopover.transient` 语义）。
    ///
    /// 使用自定义监视器的原因：
    /// 1. acceptsFirstMouse + App 非 frontmost 时的首次点击会产生系统级 App Activation Event，
    ///    内置 transient 监视器会把该事件误判为「外部点击」而立即关闭面板。
    /// 2. petHitRect 在几何上位于面板窗口之外，会把每次点击宠物都判定为「外部点击」，
    ///    导致 toggle 逻辑失效。
    private func installPopoverDismissMonitor() {
        tearDownPopoverDismissMonitor()

        transientMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            guard let self, let panel = self.deskMenuPanel, panel.isVisible else {
                self?.tearDownPopoverDismissMonitor()
                return
            }
            if panel.frame.contains(NSEvent.mouseLocation) {
                return
            }
            self.closeDeskMenuPanelWithFade()
        }

        deskMenuEscMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard event.keyCode == 53 else { return event }
            guard let panel = self.deskMenuPanel, panel.isVisible else { return event }
            // 智能输入面板自己处理 Esc；避免抢它的取消语义。
            guard self.smartInputPanel == nil else { return event }
            self.closeDeskMenuPanelWithFade()
            return nil
        }

        let nc = NotificationCenter.default
        dismissObservers.append(nc.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.closeDeskMenuPanelWithFade()
        })
    }

    private func tearDownPopoverDismissMonitor() {
        if let m = transientMonitor {
            NSEvent.removeMonitor(m)
            transientMonitor = nil
        }
        if let m = deskMenuEscMonitor {
            NSEvent.removeMonitor(m)
            deskMenuEscMonitor = nil
        }
        dismissObservers.forEach { NotificationCenter.default.removeObserver($0) }
        dismissObservers = []
    }

    /// 淡出后收起面板。
    private func closeDeskMenuPanelWithFade() {
        tearDownPopoverDismissMonitor()
        guard let panel = deskMenuPanel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.10
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
        })
    }
}
