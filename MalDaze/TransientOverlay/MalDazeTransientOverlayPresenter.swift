import AppKit

/// 临时浮层展示 SSOT：中心铃铛、喝水提醒（被动居中）与智能提醒（交互锚定）。
@MainActor
final class MalDazeTransientOverlayPresenter: MalDazeTransientOverlayPresenting {
    private struct PassiveOverlayState {
        var panel: NSPanel
        var reposition: () -> NSRect
    }

    private let dashboardPolicy: TransientOverlayDashboardPolicy
    private var passiveOverlays: [TransientOverlayKind: PassiveOverlayState] = [:]
    private var screenObserver: NSObjectProtocol?

    init(dashboardPolicy: TransientOverlayDashboardPolicy) {
        self.dashboardPolicy = dashboardPolicy
    }

    var isCenterBellVisible: Bool { passiveOverlays[.centerBell] != nil }
    var isHydrationReminderVisible: Bool { passiveOverlays[.hydration] != nil }

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

    func presentSmartReminderInput(panel: NSPanel, anchor: NSRect, size: NSSize) {
        SmartReminderUIPanels.positionPanelTopCenter(panel, anchor: anchor, size: size)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(panel.contentView)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(panel.contentView)
        }
    }

    func presentSmartReminderToast(panel: NSPanel, anchor: NSRect, size: NSSize) {
        SmartReminderUIPanels.positionPanelTopCenter(panel, anchor: anchor, size: size)
        panel.orderFrontRegardless()
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
        DispatchQueue.main.async { [dashboardPolicy] in
            dashboardPolicy.demoteVisibleDashboardIfNeeded(appWasActiveBeforePresent)
        }
    }

    private func installScreenObserverIfNeeded() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.repositionPassiveOverlays()
            }
        }
    }

    private func removeScreenObserverIfNeeded() {
        guard passiveOverlays.isEmpty else { return }
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
            screenObserver = nil
        }
    }

    private func repositionPassiveOverlays() {
        for (kind, state) in passiveOverlays {
            state.panel.setFrame(state.reposition(), display: true)
            passiveOverlays[kind] = state
        }
    }
}
