import AppKit

/// 临时浮层展示 SSOT：中心铃铛、喝水提醒（被动居中）与智能提醒（交互锚定）。
@MainActor
final class MalDazeTransientOverlayPresenter: MalDazeTransientOverlayPresenting {
    private struct PassiveOverlayState {
        var panel: NSPanel
        var reposition: () -> NSRect
    }

    private struct InteractiveOverlayState {
        var panel: NSPanel
        var anchor: NSRect
        var contentSize: NSSize
        var generation: UInt64
        var retainedObject: AnyObject?
    }

    private let dashboardPolicy: TransientOverlayDashboardPolicy
    private let scheduleFocusWork: (@escaping () -> Void) -> Void
    private var passiveOverlays: [TransientOverlayKind: PassiveOverlayState] = [:]
    private var smartInputState: InteractiveOverlayState?
    private var smartToastState: InteractiveOverlayState?
    private var screenObserver: NSObjectProtocol?
    private var nextGeneration: UInt64 = 0

    init(
        dashboardPolicy: TransientOverlayDashboardPolicy,
        scheduleFocusWork: @escaping (@escaping () -> Void) -> Void = { work in
            DispatchQueue.main.async(execute: work)
        }
    ) {
        self.dashboardPolicy = dashboardPolicy
        self.scheduleFocusWork = scheduleFocusWork
    }

    var isCenterBellVisible: Bool { passiveOverlays[.centerBell] != nil }
    var isHydrationReminderVisible: Bool { passiveOverlays[.hydration] != nil }
    var isSmartReminderInputVisible: Bool { smartInputState != nil }
    var isSmartReminderToastVisible: Bool { smartToastState != nil }

    func presentCenterBell(message: String, onDismiss: @escaping () -> Void) {
        dismissCenterBell()
        let wrappedDismiss = { [weak self] in
            self?.dismissCenterBell()
            onDismiss()
        }
        let built = CenterBellOverlayContentBuilder.makeContentView(message: message, onDismiss: wrappedDismiss)
        presentPassiveOverlay(
            kind: .centerBell,
            contentView: built.view,
            contentSize: built.size
        )
    }

    func dismissCenterBell() {
        dismissPassiveOverlay(kind: .centerBell)
    }

    func presentHydrationReminder(
        message: String,
        onDone: @escaping () -> Void,
        onSnooze: @escaping () -> Void
    ) {
        dismissHydrationReminder()
        let wrappedDone = { [weak self] in
            self?.dismissHydrationReminder()
            onDone()
        }
        let wrappedSnooze = { [weak self] in
            self?.dismissHydrationReminder()
            onSnooze()
        }
        let built = HydrationOverlayContentBuilder.makeContentView(
            message: message,
            onDone: wrappedDone,
            onSnooze: wrappedSnooze
        )
        presentPassiveOverlay(
            kind: .hydration,
            contentView: built.view,
            contentSize: built.size
        )
    }

    func dismissHydrationReminder() {
        dismissPassiveOverlay(kind: .hydration)
    }

    func presentSmartReminderInput(content: TransientOverlayContent, anchor: NSRect) {
        dismissSmartReminderInput()
        let generation = bumpGeneration()
        let panel = InteractiveAnchoredOverlayGeometry.makeInputPanelShell(contentSize: content.size)
        panel.contentView = content.view
        content.view.frame = NSRect(origin: .zero, size: content.size)
        content.view.autoresizingMask = [.width, .height]

        smartInputState = InteractiveOverlayState(
            panel: panel,
            anchor: anchor,
            contentSize: content.size,
            generation: generation,
            retainedObject: content.retainedObject
        )
        installScreenObserverIfNeeded()
        InteractiveAnchoredOverlayGeometry.positionPanel(panel, anchor: anchor, size: content.size)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(panel.contentView)
        scheduleInputFocus(for: panel, generation: generation)
    }

    func dismissSmartReminderInput() {
        guard smartInputState != nil else { return }
        bumpGeneration()
        smartInputState?.panel.orderOut(nil)
        smartInputState?.panel.close()
        smartInputState = nil
        removeScreenObserverIfNeeded()
    }

    func smartReminderInputContains(screenPoint: NSPoint) -> Bool {
        guard let panel = smartInputState?.panel, panel.isVisible else { return false }
        return panel.frame.contains(screenPoint)
    }

    func presentSmartReminderToast(content: TransientOverlayContent, anchor: NSRect) {
        dismissSmartReminderToast()
        let generation = bumpGeneration()
        let panel = InteractiveAnchoredOverlayGeometry.makeToastPanelShell(contentSize: content.size)
        panel.contentView = content.view
        content.view.frame = NSRect(origin: .zero, size: content.size)

        smartToastState = InteractiveOverlayState(
            panel: panel,
            anchor: anchor,
            contentSize: content.size,
            generation: generation,
            retainedObject: content.retainedObject
        )
        installScreenObserverIfNeeded()
        InteractiveAnchoredOverlayGeometry.positionPanel(panel, anchor: anchor, size: content.size)
        panel.orderFrontRegardless()
    }

    func dismissSmartReminderToast() {
        guard smartToastState != nil else { return }
        bumpGeneration()
        smartToastState?.panel.orderOut(nil)
        smartToastState?.panel.close()
        smartToastState = nil
        removeScreenObserverIfNeeded()
    }

    func smartReminderToastContains(screenPoint: NSPoint) -> Bool {
        guard let panel = smartToastState?.panel, panel.isVisible else { return false }
        return panel.frame.contains(screenPoint)
    }

    private func presentPassiveOverlay(kind: TransientOverlayKind, contentView: NSView, contentSize: NSSize) {
        let appWasActiveBeforePresent = NSApp.isActive
        let frame = PassiveCenteredOverlayGeometry.centeredFrame(contentSize: contentSize)
        let panel = PassiveCenteredOverlayGeometry.makePassivePanel(frame: frame)
        panel.contentView = contentView

        passiveOverlays[kind] = PassiveOverlayState(
            panel: panel,
            reposition: { PassiveCenteredOverlayGeometry.centeredFrame(contentSize: contentSize) }
        )
        installScreenObserverIfNeeded()

        panel.orderFrontRegardless()
        scheduleDashboardDemotionIfNeeded(appWasActiveBeforePresent: appWasActiveBeforePresent)
    }

    private func dismissPassiveOverlay(kind: TransientOverlayKind) {
        passiveOverlays[kind]?.panel.orderOut(nil)
        passiveOverlays[kind] = nil
        removeScreenObserverIfNeeded()
    }

    private func scheduleDashboardDemotionIfNeeded(appWasActiveBeforePresent: Bool) {
        scheduleFocusWork { [dashboardPolicy] in
            dashboardPolicy.demoteVisibleDashboardIfNeeded(appWasActiveBeforePresent)
        }
    }

    private func scheduleInputFocus(for panel: NSPanel, generation: UInt64) {
        scheduleFocusWork { [weak self, weak panel] in
            guard let self, let panel else { return }
            guard let state = self.smartInputState else { return }
            guard state.generation == generation else { return }
            guard state.panel === panel else { return }
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(panel.contentView)
        }
    }

    @discardableResult
    private func bumpGeneration() -> UInt64 {
        nextGeneration &+= 1
        return nextGeneration
    }

    private func installScreenObserverIfNeeded() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.repositionAllOverlays()
            }
        }
    }

    private func removeScreenObserverIfNeeded() {
        guard passiveOverlays.isEmpty, smartInputState == nil, smartToastState == nil else { return }
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
            screenObserver = nil
        }
    }

    private func repositionAllOverlays() {
        for (kind, state) in passiveOverlays {
            state.panel.setFrame(state.reposition(), display: true)
            passiveOverlays[kind] = state
        }
        if let state = smartInputState {
            InteractiveAnchoredOverlayGeometry.positionPanel(
                state.panel,
                anchor: state.anchor,
                size: state.contentSize
            )
        }
        if let state = smartToastState {
            InteractiveAnchoredOverlayGeometry.positionPanel(
                state.panel,
                anchor: state.anchor,
                size: state.contentSize
            )
        }
    }
}
