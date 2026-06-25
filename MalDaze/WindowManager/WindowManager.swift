import AppKit
import SwiftUI

/// 桌宠 / 休息霸屏窗：默认 `NSWindow` 在仅菜单栏（accessory）应用里往往 `canBecomeKey == false`，
/// 导致左键 `clickCount` 无法累加，**双击永远到不了 2**。休息结束依赖双击时必须可成为 key。
private final class PetStageWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class DeskPetDashboardWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

enum DeskPetDashboardWindowLayout {
    static let margin: CGFloat = 12

    static let windowStyleMask: NSWindow.StyleMask = [
        .titled, .closable, .miniaturizable, .resizable, .fullSizeContentView,
    ]

    static func centeredFrame(visibleFrame: NSRect) -> NSRect {
        let preferredSize = DeskPetDashboardView.preferredContentSize(screenVisibleFrame: visibleFrame)
        let width = min(preferredSize.width, max(visibleFrame.width - 2 * margin, 1))
        let height = min(preferredSize.height, max(visibleFrame.height - 2 * margin, 1))
        let x = visibleFrame.midX - width / 2
        let y = visibleFrame.midY - height / 2
        return clampedFrame(
            NSRect(x: x, y: y, width: width, height: height),
            visibleFrame: visibleFrame
        )
    }

    static func clampedFrame(_ frame: NSRect, visibleFrame: NSRect) -> NSRect {
        let inset = visibleFrame.insetBy(dx: margin, dy: margin)
        var f = frame
        f.size.width = min(max(f.width, 1), inset.width)
        f.size.height = min(max(f.height, 1), inset.height)
        if f.minX < inset.minX { f.origin.x = inset.minX }
        if f.minY < inset.minY { f.origin.y = inset.minY }
        if f.maxX > inset.maxX { f.origin.x = inset.maxX - f.width }
        if f.maxY > inset.maxY { f.origin.y = inset.maxY - f.height }
        return f
    }

}

private final class DeskPetDashboardWindowDelegate: NSObject, NSWindowDelegate {
    var onWindowMoved: (() -> Void)?
    var onWindowLiveResized: (() -> Void)?
    var onCloseRequest: (() -> Void)?

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onCloseRequest?()
        return false
    }

    func windowDidMove(_ notification: Notification) {
        onWindowMoved?()
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window.inLiveResize else { return }
        onWindowLiveResized?()
    }
}

struct BreakRunShieldScreenResolver {
    static func screenFrame(
        forWindowFrame windowFrame: CGRect?,
        screenFrames: [CGRect],
        fallbackFrame: CGRect?
    ) -> CGRect? {
        guard let windowFrame else {
            return fallbackFrame ?? screenFrames.first
        }

        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        return screenFrames.first { $0.contains(center) } ?? fallbackFrame ?? screenFrames.first
    }
}

/// 跑屏模式固定在屏幕左下角的倒计时视图；点击 10 次可提前结束休息。
private final class BreakRunCountdownView: NSView {
    let label = NSTextField(labelWithString: "5:00")
    var onTenClicks: (() -> Void)?
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
        if clickCount >= 10 {
            clickCount = 0
            onTenClicks?()
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
    /// 绑定后右下角桌宠可点击 toggle Dashboard 标准窗口；单测用 `MockWindowManager` 空实现即可。
    func bindDeskPetMenu(viewModel: AppViewModel?)
    /// `true`（默认）：休息全屏时窗口接收鼠标，挡桌面；`false`：休息时鼠标穿透，不挡操作。
    func setRestBlocksClicks(_ blocks: Bool)

    /// 智能输入单行面板；`anchorRectInScreen` 为桌宠区域（屏幕坐标），用于定位在头顶上方。
    func presentSmartReminderInput(anchorRectInScreen: NSRect, onSubmit: @escaping (String) -> Void, onCancel: @escaping () -> Void)
    /// 无桌宠框时（或未安装窗）：用菜单栏屏可见区底部中点上方。
    func presentSmartReminderInputFromGlobalShortcut(onSubmit: @escaping (String) -> Void, onCancel: @escaping () -> Void)
    /// 全局快捷键：与左键点桌宠相同，toggle Dashboard 标准窗口。
    func presentDeskMenuFromGlobalShortcut()
    /// 桌宠左键 / 快捷键：显示、聚焦或隐藏 Dashboard（策略 A：恢复 persisted frame）。
    func toggleDashboardWindow()
    /// Dock 再点：显示或前置 Dashboard，不因已 visible 而关闭。
    func showOrFocusDashboardFromDock()
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
    /// `MalDazeDefaults.idlePetAnimationIntensity` 变更后：刷新桌宠 GIF 动画强度。
    func applyIdlePetAnimationFromUserDefaults()
    /// 临时浮层（中心铃铛、喝水、智能提醒）展示 SSOT。
    var transientOverlayPresenter: MalDazeTransientOverlayPresenting { get }
}

extension WindowManaging {
    /// 默认仍会把小窗桌宠 `orderFront`，以保持与其它入口一致；从菜单栏改模式等路径请传 `false`。
    func dismissRestImmediately() {
        dismissRestImmediately(bringIdlePetWindowToFront: true)
    }
}

struct IdleCursorTrackingPolicy {
    static let nearPollingInterval: TimeInterval = 0.08
    /// 指针远离宠物时低频探测，避免常态 baseline 4 Hz 轮询。
    static let farPollingInterval: TimeInterval = 0.5
    static let nearDistance: CGFloat = 180

    static func ignoresMouseEvents(pointer: CGPoint, petScreenRect: CGRect) -> Bool {
        !petScreenRect.contains(pointer)
    }

    static func proximityRect(around petScreenRect: CGRect) -> CGRect {
        petScreenRect.insetBy(dx: -nearDistance, dy: -nearDistance)
    }

    static func pointerIsNearPet(pointer: CGPoint, petScreenRect: CGRect) -> Bool {
        proximityRect(around: petScreenRect).contains(pointer)
    }

    static func pollingInterval(pointer: CGPoint, petScreenRect: CGRect) -> TimeInterval {
        pointerIsNearPet(pointer: pointer, petScreenRect: petScreenRect)
            ? nearPollingInterval
            : farPollingInterval
    }
}

/// 模块 2：常态为**仅桌宠大小**的透明小窗（可拖动，位置持久化）；休息时扩展为菜单栏屏全屏霸屏。同一只 `PetStageView`。
@MainActor
final class WindowManager: WindowManaging {
    /// 桌宠 `NSWindow.identifier`。
    static let deskPetWindowIdentifier = "com.maldaze.deskPetStage"
    /// Dashboard 标准窗口 identifier（Mission Control / 窗口列表）。
    static let deskPetDashboardWindowIdentifier = "com.maldaze.deskPetDashboard"

    private var window: NSWindow?
    private var stageView: PetStageView?
    private weak var deskMenuViewModel: AppViewModel?
    /// Dashboard 标准窗口；隐藏后保留 window / host / SwiftUI 状态以便复用。
    private var deskMenuWindow: DeskPetDashboardWindow?
    private var deskMenuHostingController: NSHostingController<AnyView>?
    private let deskMenuWindowDelegate = DeskPetDashboardWindowDelegate()
    /// 桌宠 Dashboard：Esc / Cmd+W 关闭（本地监视器吃掉 Esc 避免系统咚声）。
    private var deskMenuEscMonitor: Any?
    private var pendingDismiss: (() -> Void)?
    private var screenObserver: NSObjectProtocol?
    private var primaryDisplayObserver: NSObjectProtocol?
    private var launchObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var screenRepositionWorkItem: DispatchWorkItem?
    /// 常态下自适应轮询光标位置：远离静态桌宠时低频，靠近命中区时短暂高频，确保透明区域不吞焦点。
    private var idleCursorTrackTimer: Timer?
    /// 窗口可接收事件时，用本地 mouseMoved 监视离开，减少 near 轮询。
    private var idleLocalMouseMonitor: Any?
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

    /// 用户取消智能输入时回调（Esc / 点外部 /「取消」）；提交成功前清除且不调用。
    private var smartInputUserOnCancel: (() -> Void)?
    private var smartInputEscapeMonitor: Any?
    /// 本应用内点击面板外关闭（不依赖辅助功能）。
    private var smartInputLocalMouseMonitor: Any?
    /// 系统全局点击面板外关闭（需辅助功能授权）。
    private var smartInputClickAwayMonitor: Any?
    private var smartToastDismiss: Timer?
    /// 智能输入框草稿：点外部 / Esc /「取消」关闭后面板不丢字；回车提交成功后清空。
    private var smartReminderInputDraft: String = ""
    private lazy var transientOverlayPresenterStorage = MalDazeTransientOverlayPresenter(
        dashboardPolicy: .init { [weak self] appWasActiveBeforePresent in
            self?.demoteVisibleDashboardBelowOtherApplicationsIfNeeded(
                onlyIfAppWasInactive: true,
                appWasActiveBeforeOverlay: appWasActiveBeforePresent
            )
        }
    )

    var transientOverlayPresenter: MalDazeTransientOverlayPresenting {
        transientOverlayPresenterStorage
    }

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
        if let idleLocalMouseMonitor {
            NSEvent.removeMonitor(idleLocalMouseMonitor)
        }
        breakRunCountdownTimer?.invalidate()
        breakRunShieldWorkItem?.cancel()
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
        // App 级 hide（Cmd+H、部分切换器/启动器藏 App）时仍保留桌宠；Dashboard 保持默认 canHide。
        win.canHide = false

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
        tearDownDashboardEscMonitor()
        deskMenuWindow?.orderOut(nil)
        if viewModel == nil {
            deskMenuWindow = nil
            deskMenuHostingController = nil
        }
        if let v = stageView {
            wireDeskPetCallbacks(into: v)
        }
        applyMousePolicy()
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
        v.applyIdlePetGIFAnimationFromDefaults()
    }

    func setRestBlocksClicks(_ blocks: Bool) {
        restBlocksClicks = blocks
        applyMousePolicy()
    }

    func presentRest(duration: TimeInterval, onDismissed: @escaping () -> Void) {
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
        scheduleDemoteVisibleDashboardBelowOtherApplicationsIfNeeded()
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

    func applyIdlePetAnimationFromUserDefaults() {
        installPetWindowIfNeeded()
        stageView?.applyIdlePetGIFAnimationFromDefaults()
    }

    func dismissRestImmediately(bringIdlePetWindowToFront: Bool) {
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
        if wasBreakRun {
            stageView?.cancelBreakRunToIdle()
        } else {
            stageView?.cancelToIdle()
        }
        setWindowLevel(resting: false)

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
        scheduleDemoteVisibleDashboardBelowOtherApplicationsIfNeeded()
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
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 1.0
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window?.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            guard let self else { return }
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
                self?.showBreakRunShield()
            }
            breakRunShieldWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: item)
        }

        let startDate = Date()
        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let elapsed = Date().timeIntervalSince(startDate)
            let remaining = max(0, duration - elapsed)
            stageView?.updateBreakRunCountdown(remaining: remaining)
            updateBreakRunCountdownPanel(remaining: remaining)
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
        let fallbackScreen = MenuBarNSScreen.screen ?? NSScreen.screens.first
        guard let screenFrame = BreakRunShieldScreenResolver.screenFrame(
            forWindowFrame: window?.frame,
            screenFrames: NSScreen.screens.map(\.frame),
            fallbackFrame: fallbackScreen?.frame
        ) else { return }
        // 遮罩层级比 .screenSaver(1000) 低2级；倒计时面板在 screenSaver-1 确保在遮罩之上
        let shieldLevel = NSWindow.Level(rawValue: Int(NSWindow.Level.screenSaver.rawValue) - 2)
        let panel = NSPanel(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.20)
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.canHide = false
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
        scheduleDemoteVisibleDashboardBelowOtherApplicationsIfNeeded()
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
        panel.hidesOnDeactivate = false
        panel.canHide = false
        // level = screenSaver-1（999）；遮罩在 screenSaver-2（998），pet 在 screenSaver（1000）
        panel.level = NSWindow.Level(rawValue: Int(NSWindow.Level.screenSaver.rawValue) - 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false

        let cv = BreakRunCountdownView(frame: NSRect(origin: .zero, size: panelSize))
        cv.onTenClicks = { [weak self] in
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
        startIdleCursorTracking()
        syncIdleWindowMousePolicy(rescheduleIfNeeded: true)
    }

    private func startIdleCursorTracking() {
        guard idleCursorTrackTimer == nil else { return }
        guard idleLocalMouseMonitor == nil else { return }
        scheduleIdleCursorTracking(after: IdleCursorTrackingPolicy.farPollingInterval)
    }

    private func scheduleIdleCursorTracking(after interval: TimeInterval) {
        idleCursorTrackTimer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.idleCursorTrackTimer = nil
            self?.syncIdleWindowMousePolicy(rescheduleIfNeeded: true)
        }
        RunLoop.main.add(t, forMode: .common)
        idleCursorTrackTimer = t
    }

    private func stopIdleCursorTracking() {
        idleCursorTrackTimer?.invalidate()
        idleCursorTrackTimer = nil
        removeIdleLocalMouseMonitor()
    }

    private func installIdleLocalMouseMonitorIfNeeded() {
        guard idleLocalMouseMonitor == nil else { return }
        idleLocalMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            self?.handleIdleLocalMouseMoved()
            return event
        }
    }

    private func removeIdleLocalMouseMonitor() {
        if let idleLocalMouseMonitor {
            NSEvent.removeMonitor(idleLocalMouseMonitor)
            self.idleLocalMouseMonitor = nil
        }
    }

    private func handleIdleLocalMouseMoved() {
        guard let win = window, let stage = stageView else { return }
        guard !stage.isInRestPhase, deskMenuViewModel != nil else { return }
        let petScreen = win.convertToScreen(stage.petHitRectInWindowBaseCoordinates)
        let mouse = NSEvent.mouseLocation
        if IdleCursorTrackingPolicy.pointerIsNearPet(pointer: mouse, petScreenRect: petScreen) {
            return
        }
        win.ignoresMouseEvents = true
        removeIdleLocalMouseMonitor()
        scheduleIdleCursorTracking(after: IdleCursorTrackingPolicy.farPollingInterval)
    }

    /// 光标在宠物屏幕命中区内 → 窗口接收鼠标；光标在外 → 完全透传（不抢焦点）。
    private func syncIdleWindowMousePolicy(rescheduleIfNeeded: Bool = false) {
        guard let win = window, let stage = stageView else { return }
        guard !stage.isInRestPhase, deskMenuViewModel != nil else { return }
        let petScreen = win.convertToScreen(stage.petHitRectInWindowBaseCoordinates)
        let mouse = NSEvent.mouseLocation
        let shouldIgnore = IdleCursorTrackingPolicy.ignoresMouseEvents(pointer: mouse, petScreenRect: petScreen)
        win.ignoresMouseEvents = shouldIgnore
        if shouldIgnore {
            removeIdleLocalMouseMonitor()
        } else {
            installIdleLocalMouseMonitorIfNeeded()
            idleCursorTrackTimer?.invalidate()
            idleCursorTrackTimer = nil
        }
        if rescheduleIfNeeded, shouldIgnore {
            scheduleIdleCursorTracking(after: IdleCursorTrackingPolicy.pollingInterval(pointer: mouse, petScreenRect: petScreen))
        }
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
        transientOverlayPresenter.dismissSmartReminderInput()
        let cb = smartInputUserOnCancel
        smartInputUserOnCancel = nil
        if invokeUserCancel {
            cb?()
        }
    }

    private func installSmartInputDismissMonitors() {
        smartInputEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.transientOverlayPresenter.isSmartReminderInputVisible else { return event }
            guard event.keyCode == 53 else { return event }
            self.teardownSmartInputPanel(invokeUserCancel: true)
            return nil
        }
        smartInputLocalMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, self.transientOverlayPresenter.isSmartReminderInputVisible else { return event }
            if !self.transientOverlayPresenter.smartReminderInputContains(screenPoint: NSEvent.mouseLocation) {
                self.teardownSmartInputPanel(invokeUserCancel: true)
            }
            return event
        }
        smartInputClickAwayMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.transientOverlayPresenter.isSmartReminderInputVisible else { return }
                if !self.transientOverlayPresenter.smartReminderInputContains(screenPoint: NSEvent.mouseLocation) {
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
        let content = SmartReminderUIPanels.makeInputContent(
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
        transientOverlayPresenter.presentSmartReminderInput(content: content, anchor: anchor)
        installSmartInputDismissMonitors()
    }

    func presentSmartReminderInputFromGlobalShortcut(
        onSubmit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        // 与桌宠菜单快捷键一致：已打开时再按同一全局快捷键则关闭（等同 Esc / 取消）。
        if transientOverlayPresenter.isSmartReminderInputVisible {
            teardownSmartInputPanel(invokeUserCancel: true)
            return
        }
        installPetWindowIfNeeded()
        let anchor = window.map { $0.frame } ?? Self.defaultSmartInputAnchorInScreen()
        presentSmartReminderInput(anchorRectInScreen: anchor, onSubmit: onSubmit, onCancel: onCancel)
    }

    func presentDeskMenuFromGlobalShortcut() {
        toggleDashboardWindow()
    }

    func toggleDashboardWindow() {
        installPetWindowIfNeeded()
        guard deskMenuViewModel != nil else { return }
        if let dashboard = deskMenuWindow, dashboard.isVisible {
            hideDashboardWindow()
            return
        }
        showDashboardWindow()
    }

    func showOrFocusDashboardFromDock() {
        installPetWindowIfNeeded()
        guard deskMenuViewModel != nil else { return }
        if let dashboard = deskMenuWindow, dashboard.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            dashboard.makeKeyAndOrderFront(nil)
            installDashboardEscMonitor()
            return
        }
        showDashboardWindow()
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
        let content = SmartReminderUIPanels.makeToastContent(
            message: message,
            showUndo: showUndo,
            onUndo: { [weak self] in
                self?.dismissSmartReminderToast()
                onUndo()
            }
        )
        let anchor = window.map { $0.frame } ?? Self.defaultSmartInputAnchorInScreen()
        transientOverlayPresenter.presentSmartReminderToast(content: content, anchor: anchor)
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
        transientOverlayPresenter.dismissSmartReminderToast()
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

// MARK: - Dashboard 标准窗口

extension WindowManager: PetStageDeskMenuPresenter {
    func presentSmartReminderInput(from stage: PetStageView, anchorRect: NSRect) {
        guard let vm = deskMenuViewModel, let win = stage.window else { return }
        let screenAnchor = win.convertToScreen(anchorRect)
        vm.userRequestedSmartReminderInput(screenAnchor: screenAnchor)
    }

    private func makeDeskPetDashboardRootView(viewModel vm: AppViewModel) -> AnyView {
        AnyView(DeskPetDashboardView(viewModel: vm))
    }

    private static func dashboardDefaultVisibleFrame() -> NSRect {
        MalDazePresentationAnchor.preferredVisibleFrameForAuxiliaryUI()
    }

    private static func configureDashboardWindowChrome(_ window: NSWindow) {
        window.title = "MalDaze"
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .normal
        window.collectionBehavior = [.managed, .fullScreenNone]
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        // 仅标题栏区可拖窗；面板内由分栏 NSView 接管鼠标，避免与列宽拖拽抢手势。
        window.isMovableByWindowBackground = false
        window.toolbar = nil
        window.contentMinSize = NSSize(width: 480, height: 360)
    }

    private static func resolvedDashboardWindowFrame() -> NSRect {
        let visibleFrame = dashboardDefaultVisibleFrame()
        let defaultFrame = DeskPetDashboardWindowLayout.centeredFrame(visibleFrame: visibleFrame)
        let d = UserDefaults.standard
        guard d.object(forKey: MalDazeDefaults.dashboardWindowOriginX) != nil,
              d.object(forKey: MalDazeDefaults.dashboardWindowOriginY) != nil,
              d.object(forKey: MalDazeDefaults.dashboardWindowWidth) != nil,
              d.object(forKey: MalDazeDefaults.dashboardWindowHeight) != nil
        else {
            return defaultFrame
        }
        let storedFrame = NSRect(
            x: d.double(forKey: MalDazeDefaults.dashboardWindowOriginX),
            y: d.double(forKey: MalDazeDefaults.dashboardWindowOriginY),
            width: d.double(forKey: MalDazeDefaults.dashboardWindowWidth),
            height: d.double(forKey: MalDazeDefaults.dashboardWindowHeight)
        )
        if storedFrame.width < defaultFrame.width * 0.75
            || storedFrame.height < defaultFrame.height * 0.75 {
            return defaultFrame
        }
        let clampVisibleFrame = MalDazePresentationAnchor.visibleFrameContainingScreenRect(storedFrame)
        return DeskPetDashboardWindowLayout.clampedFrame(storedFrame, visibleFrame: clampVisibleFrame)
    }

    private func persistDashboardWindowFrame(_ frame: NSRect) {
        let d = UserDefaults.standard
        d.set(frame.origin.x, forKey: MalDazeDefaults.dashboardWindowOriginX)
        d.set(frame.origin.y, forKey: MalDazeDefaults.dashboardWindowOriginY)
        d.set(frame.size.width, forKey: MalDazeDefaults.dashboardWindowWidth)
        d.set(frame.size.height, forKey: MalDazeDefaults.dashboardWindowHeight)
        d.set(true, forKey: MalDazeDefaults.dashboardWindowFrameUsesTitledOuterSize)
    }

    /// 创建或复用 Dashboard 标准窗口。
    private func makeDeskMenuWindowIfNeeded() -> DeskPetDashboardWindow? {
        guard let vm = deskMenuViewModel else { return nil }
        if let existing = deskMenuWindow {
            return existing
        }

        let panelFrame = Self.resolvedDashboardWindowFrame()
        let dashboardWindow = DeskPetDashboardWindow(
            contentRect: NSRect(origin: .zero, size: panelFrame.size),
            styleMask: DeskPetDashboardWindowLayout.windowStyleMask,
            backing: .buffered,
            defer: true
        )
        Self.configureDashboardWindowChrome(dashboardWindow)
        dashboardWindow.identifier = NSUserInterfaceItemIdentifier(Self.deskPetDashboardWindowIdentifier)
        dashboardWindow.delegate = deskMenuWindowDelegate
        deskMenuWindowDelegate.onWindowMoved = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, let win = self.deskMenuWindow, win.isVisible else { return }
                self.persistDashboardWindowFrame(win.frame)
            }
        }
        deskMenuWindowDelegate.onWindowLiveResized = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, let win = self.deskMenuWindow, win.isVisible else { return }
                self.persistDashboardWindowFrame(win.frame)
            }
        }
        deskMenuWindowDelegate.onCloseRequest = { [weak self] in
            Task { @MainActor [weak self] in
                self?.hideDashboardWindow()
            }
        }

        let host = NSHostingController(rootView: makeDeskPetDashboardRootView(viewModel: vm))
        if #available(macOS 13.3, *) {
            host.safeAreaRegions = []
        }
        dashboardWindow.contentViewController = host
        dashboardWindow.setFrame(panelFrame, display: false)
        dashboardWindow.contentMinSize = NSSize(width: 480, height: 360)
        deskMenuHostingController = host
        deskMenuWindow = dashboardWindow
        return dashboardWindow
    }

    func presentDeskMenu(from stage: PetStageView, anchorRect: NSRect) {
        _ = stage
        _ = anchorRect
        toggleDashboardWindow()
    }

    /// 桌宠休息/跑屏 `orderFrontRegardless` 会把整个 App 激活，连带抬高已打开的 Dashboard；压回全局栈底且保持可见。
    private func demoteVisibleDashboardBelowOtherApplicationsIfNeeded(
        onlyIfAppWasInactive: Bool = false,
        appWasActiveBeforeOverlay: Bool = false
    ) {
        guard let dashboard = deskMenuWindow, dashboard.isVisible else { return }
        if onlyIfAppWasInactive, appWasActiveBeforeOverlay { return }
        dashboard.order(.below, relativeTo: 0)
    }

    private func scheduleDemoteVisibleDashboardBelowOtherApplicationsIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            self?.demoteVisibleDashboardBelowOtherApplicationsIfNeeded()
        }
    }

    private func showDashboardWindow() {
        guard let dashboardWindow = makeDeskMenuWindowIfNeeded() else { return }
        let targetFrame = Self.resolvedDashboardWindowFrame()
        if !dashboardWindow.isVisible {
            dashboardWindow.setFrame(targetFrame, display: false)
        }
        NSApp.activate(ignoringOtherApps: true)
        dashboardWindow.makeKeyAndOrderFront(nil)
        installDashboardEscMonitor()
        deskMenuViewModel?.dashboardPresentationDidShow()
        DispatchQueue.main.async { [weak self] in
            guard let self, let dashboardWindow = self.deskMenuWindow else { return }
            self.restoreDashboardWindowFrameIfShrunk(dashboardWindow, expected: targetFrame)
            NotificationCenter.default.post(name: MalDazeBroadcastNotifications.deskPetDashboardDidOpen, object: nil)
        }
    }

    private func restoreDashboardWindowFrameIfShrunk(_ window: NSWindow, expected: NSRect) {
        guard window.isVisible else { return }
        let current = window.frame
        if current.width < expected.width - 2 || current.height < expected.height - 2 {
            window.setFrame(expected, display: true)
        }
    }

    private func hideDashboardWindow() {
        tearDownDashboardEscMonitor()
        deskMenuViewModel?.dashboardEscapeRouter.reset()
        guard let dashboardWindow = deskMenuWindow, dashboardWindow.isVisible else {
            deskMenuWindow?.orderOut(nil)
            deskMenuViewModel?.dashboardPresentationDidHide()
            NotificationCenter.default.post(name: MalDazeBroadcastNotifications.deskPetDashboardDidClose, object: nil)
            return
        }
        persistDashboardWindowFrame(dashboardWindow.frame)
        dashboardWindow.orderOut(nil)
        deskMenuViewModel?.dashboardPresentationDidHide()
        NotificationCenter.default.post(name: MalDazeBroadcastNotifications.deskPetDashboardDidClose, object: nil)
    }

    private func installDashboardEscMonitor() {
        tearDownDashboardEscMonitor()
        deskMenuEscMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "w",
               self.deskMenuWindow?.isVisible == true {
                self.hideDashboardWindow()
                return nil
            }
            guard event.keyCode == 53 else { return event }
            guard let dashboardWindow = self.deskMenuWindow, dashboardWindow.isVisible else { return event }
            guard !self.transientOverlayPresenter.isSmartReminderInputVisible else { return event }
            if self.deskMenuViewModel?.dashboardEscapeRouter.consumeEscape() == true {
                return nil
            }
            self.hideDashboardWindow()
            return nil
        }
    }

    private func tearDownDashboardEscMonitor() {
        if let m = deskMenuEscMonitor {
            NSEvent.removeMonitor(m)
            deskMenuEscMonitor = nil
        }
    }
}
