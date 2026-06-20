import AppKit

struct TransientOverlayDashboardPolicy {
    var demoteVisibleDashboardIfNeeded: (_ appWasActiveBeforePresent: Bool) -> Void
}

enum TransientOverlayKind: Hashable {
    case centerBell
    case hydration
}

@MainActor
protocol MalDazeTransientOverlayPresenting: AnyObject {
    var isCenterBellVisible: Bool { get }
    var isHydrationReminderVisible: Bool { get }

    func presentCenterBell(message: String, onDismiss: @escaping () -> Void)
    func dismissCenterBell()

    func presentHydrationReminder(
        message: String,
        onDone: @escaping () -> Void,
        onSnooze: @escaping () -> Void
    )
    func dismissHydrationReminder()

    func presentSmartReminderInput(panel: NSPanel, anchor: NSRect, size: NSSize)
    func presentSmartReminderToast(panel: NSPanel, anchor: NSRect, size: NSSize)
}
