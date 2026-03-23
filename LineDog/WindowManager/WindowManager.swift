import AppKit
import SwiftUI

/// 桌宠 / 休息霸屏窗：默认 `NSWindow` 在仅菜单栏（accessory）应用里往往 `canBecomeKey == false`，
/// 导致左键 `clickCount` 无法累加，**双击永远到不了 2**。休息结束依赖双击时必须可成为 key。
private final class PetStageWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// 供 `AppViewModel` 与单元测试注入；生产环境由 `WindowManager` 实现。
protocol WindowManaging: AnyObject {
    func dismissRestImmediately()
    func presentRest(duration: TimeInterval, onDismissed: @escaping () -> Void)
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
}

/// 模块 2：常态为**仅桌宠大小**的透明小窗（可拖动，位置持久化）；休息时扩展为菜单栏屏全屏霸屏。同一只 `PetStageView`。
@MainActor
final class WindowManager: WindowManaging {
    private var window: NSWindow?
    private var stageView: PetStageView?
    private weak var deskMenuViewModel: AppViewModel?
    private var deskMenuPopover: NSPopover?
    private var deskMenuHosting: NSHostingController<MenuBarContentView>?
    private var pendingDismiss: (() -> Void)?
    private var screenObserver: NSObjectProtocol?
    private var primaryDisplayObserver: NSObjectProtocol?
    private var launchObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var screenRepositionWorkItem: DispatchWorkItem?

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
        precondition(!screens.isEmpty, "LineDog requires at least one NSScreen")
        if let menuBar = MenuBarNSScreen.screen {
            return (menuBar, menuBar.frame)
        }
        let s = screens[0]
        return (s, s.frame)
    }

    private static let idlePetSize = NSSize(width: 132, height: 132)
    private static let idlePetOriginXKey = "LineDog.idlePetOriginX"
    private static let idlePetOriginYKey = "LineDog.idlePetOriginY"

    /// 首次启动：菜单栏屏可见区右下角默认位。
    private static func defaultIdlePetWindowFrame() -> NSRect {
        let w = idlePetSize.width
        let h = idlePetSize.height
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
        return NSRect(x: x, y: y, width: idlePetSize.width, height: idlePetSize.height)
    }

    private static func isApproximatelyIdleSized(_ rect: NSRect) -> Bool {
        abs(rect.width - idlePetSize.width) < 24 && abs(rect.height - idlePetSize.height) < 24
    }

    /// 至少与某块屏的 `frame` 有足够交集则保留位置（支持副屏）；完全离开所有屏则退回默认角。
    private static func clampIdlePetFrameToScreens(_ rect: NSRect) -> NSRect {
        let r = NSRect(origin: rect.origin, size: idlePetSize)
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
        LineDogPresentationAnchor.updateIdlePetWindowFrame(frame)
        NotificationCenter.default.post(
            name: LineDogBroadcastNotifications.idlePetScreenFrameChanged,
            object: nil,
            userInfo: [LineDogBroadcastNotifications.idlePetScreenFrameUserInfoKey: NSValue(rect: frame)]
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
        applyMousePolicy()
        win.orderFrontRegardless()
        syncContentViewToWindowLayout()
        view.applyNonRestPetDisplayMode(pendingIdlePetMode)
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
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
        deskMenuPopover?.close()
        deskMenuPopover = nil
        deskMenuHosting = nil
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
    }

    func setRestBlocksClicks(_ blocks: Bool) {
        restBlocksClicks = blocks
        applyMousePolicy()
    }

    func presentRest(duration: TimeInterval, onDismissed: @escaping () -> Void) {
        deskMenuPopover?.close()
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

    func dismissRestImmediately() {
        deskMenuPopover?.close()
        let callback = pendingDismiss
        pendingDismiss = nil
        stageView?.cancelToIdle()
        setWindowLevel(resting: false)
        callback?()
        shrinkWindowToIdlePetFrame()
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
            return
        }
        if stageView?.isInRestPhase == true {
            syncPetRestWindowMousePolicy()
            return
        }
        win.ignoresMouseEvents = false
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

    func presentDeskMenu(from stage: PetStageView, anchorRect: NSRect) {
        guard let vm = deskMenuViewModel else { return }
        if deskMenuPopover == nil {
            let pop = NSPopover()
            pop.behavior = .transient
            pop.animates = true
            let host = NSHostingController(rootView: MenuBarContentView(viewModel: vm))
            host.view.translatesAutoresizingMaskIntoConstraints = true
            pop.contentViewController = host
            pop.contentSize = NSSize(width: 668, height: 560)
            deskMenuPopover = pop
            deskMenuHosting = host
        } else if let host = deskMenuHosting {
            host.rootView = MenuBarContentView(viewModel: vm)
        }
        guard let pop = deskMenuPopover else { return }
        if pop.isShown {
            pop.close()
            return
        }
        // 锚在桌宠矩形上侧，菜单向上展开（桌宠常在屏幕底部）。
        pop.show(relativeTo: anchorRect, of: stage, preferredEdge: .minY)
    }
}
