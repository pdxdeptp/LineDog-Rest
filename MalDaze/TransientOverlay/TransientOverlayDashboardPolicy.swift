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
    var isSmartReminderInputVisible: Bool { get }
    var isSmartReminderToastVisible: Bool { get }

    func presentCenterBell(message: String, onDismiss: @escaping () -> Void)
    func dismissCenterBell()

    func presentHydrationReminder(
        message: String,
        onDone: @escaping () -> Void,
        onSnooze: @escaping () -> Void
    )
    func dismissHydrationReminder()

    func presentSmartReminderInput(content: TransientOverlayContent, anchor: NSRect)
    func dismissSmartReminderInput()
    func smartReminderInputContains(screenPoint: NSPoint) -> Bool

    func presentSmartReminderToast(content: TransientOverlayContent, anchor: NSRect)
    func dismissSmartReminderToast()
    func smartReminderToastContains(screenPoint: NSPoint) -> Bool
}
