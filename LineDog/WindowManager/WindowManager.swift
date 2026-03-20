import AppKit

/// 供 `AppViewModel` 与单元测试注入；生产环境由 `WindowManager` 实现。
protocol WindowManaging: AnyObject {
    func dismissRestImmediately()
    func presentRest(duration: TimeInterval, onDismissed: @escaping () -> Void)
    func applyIdlePetDisplayMode(_ mode: PetDisplayMode)
}

/// 模块 2：唯一全屏透明窗口 + `PetStageView`。霸屏与右下角常态是同一只小狗的状态变化，不创建第二套窗口。
final class WindowManager: WindowManaging {
    private var window: NSWindow?
    private var stageView: PetStageView?
    private var pendingDismiss: (() -> Void)?
    private var screenObserver: NSObjectProtocol?
    private var primaryDisplayObserver: NSObjectProtocol?
    private var launchObserver: NSObjectProtocol?
    private var screenRepositionWorkItem: DispatchWorkItem?

    /// `AppViewModel` 可能在宠物窗创建之前就 `syncPetDisplayMode`，需记住并在首屏安装时应用。
    private var pendingIdlePetMode: PetDisplayMode = .runningBlack

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
    }

    deinit {
        if let launchObserver {
            NotificationCenter.default.removeObserver(launchObserver)
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

    private func installPetWindowIfNeeded() {
        guard window == nil else { return }
        if let obs = launchObserver {
            NotificationCenter.default.removeObserver(obs)
            launchObserver = nil
        }

        let primary = Self.primaryDisplay()
        let frame = primary.frame

        let win = NSWindow(
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
        win.ignoresMouseEvents = true
        win.hidesOnDeactivate = false

        let view = PetStageView(frame: NSRect(origin: .zero, size: frame.size))
        win.contentView = view
        window = win
        stageView = view
        win.orderFrontRegardless()
        syncContentViewToWindowLayout()
        view.applyNonRestPetDisplayMode(pendingIdlePetMode)
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()

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

    func presentRest(duration: TimeInterval, onDismissed: @escaping () -> Void) {
        installPetWindowIfNeeded()
        dismissRestImmediately()
        pendingDismiss = onDismissed
        setWindowLevel(resting: true)
        stageView?.beginRestCycle(total: duration) { [weak self] in
            self?.finishRestCycle()
        }
    }

    /// 右下角桌宠在非休息时的配色（计时中黑 / 停止白边）。
    func applyIdlePetDisplayMode(_ mode: PetDisplayMode) {
        pendingIdlePetMode = mode
        stageView?.applyNonRestPetDisplayMode(mode)
    }

    func dismissRestImmediately() {
        let callback = pendingDismiss
        pendingDismiss = nil
        stageView?.cancelToIdle()
        setWindowLevel(resting: false)
        callback?()
    }

    private func finishRestCycle() {
        setWindowLevel(resting: false)
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

    /// 把 `contentView` 贴齐 `contentLayoutRect`，避免多屏下窗框变了但 `bounds` 仍为零或错位。
    private func syncContentViewToWindowLayout() {
        guard let win = window, let cv = win.contentView else { return }
        cv.autoresizingMask = [.width, .height]
        cv.frame = win.contentLayoutRect
    }

    private func repositionToPrimaryDisplay() {
        let primary = Self.primaryDisplay()
        let frame = primary.frame
        window?.setFrame(frame, display: true)
        syncContentViewToWindowLayout()
        stageView?.needsLayout = true
        stageView?.layoutSubtreeIfNeeded()
        window?.orderFrontRegardless()
    }
}
