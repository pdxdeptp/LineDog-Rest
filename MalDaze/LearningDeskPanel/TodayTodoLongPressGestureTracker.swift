import AppKit
import Foundation

enum TodayTodoLongPressGestureOutcome: Equatable {
    case none
    case quickClickEdit
    case pressingReady
    case reorderActivated
    case reorderEnded
    case longPressReleasedWithoutDrag
}

@MainActor
final class TodayTodoLongPressGestureTracker {
    typealias Clock = () -> TimeInterval
    typealias Schedule = (_ delay: TimeInterval, _ block: @escaping () -> Void) -> Void

    private let longPressDuration: TimeInterval
    private let dragStartThreshold: CGFloat
    private let clock: Clock
    private let schedule: Schedule

    private(set) var reorderEnabledSnapshot = false
    private(set) var longPressReady = false
    private(set) var isReorderDragging = false
    private var mouseDownLocation: NSPoint = .zero
    private var mouseDownEvent: NSEvent?
    private var scheduledFireTime: TimeInterval?
    var onPressingReady: ((NSEvent) -> Void)?

    init(
        longPressDuration: TimeInterval = TodayTodoReorderMetrics.longPressDuration,
        dragStartThreshold: CGFloat = TodayTodoReorderMetrics.dragStartThreshold,
        clock: @escaping Clock = { ProcessInfo.processInfo.systemUptime },
        schedule: @escaping Schedule = { delay, block in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: block)
        }
    ) {
        self.longPressDuration = longPressDuration
        self.dragStartThreshold = dragStartThreshold
        self.clock = clock
        self.schedule = schedule
    }

    func mouseDown(reorderEnabled: Bool, event: NSEvent) -> TodayTodoLongPressGestureOutcome {
        reset()
        guard reorderEnabled else { return .quickClickEdit }

        reorderEnabledSnapshot = true
        mouseDownLocation = event.locationInWindow
        mouseDownEvent = event
        scheduledFireTime = clock() + longPressDuration
        schedule(longPressDuration) { [weak self] in
            guard let self, let event = self.mouseDownEvent else { return }
            self.longPressReady = true
            self.onPressingReady?(event)
        }
        return .none
    }

    func mouseDragged(event: NSEvent) -> TodayTodoLongPressGestureOutcome {
        guard reorderEnabledSnapshot else { return .none }

        if longPressReady || isReorderDragging {
            let dx = event.locationInWindow.x - mouseDownLocation.x
            let dy = event.locationInWindow.y - mouseDownLocation.y
            let distance = hypot(dx, dy)

            if !isReorderDragging, longPressReady, distance >= dragStartThreshold {
                isReorderDragging = true
                return .reorderActivated
            }

            if isReorderDragging {
                return .none
            }
        }
        return .none
    }

    func mouseUp() -> (TodayTodoLongPressGestureOutcome, NSEvent?) {
        defer { resetTrackingState() }

        if isReorderDragging {
            isReorderDragging = false
            return (.reorderEnded, nil)
        }

        if reorderEnabledSnapshot, longPressReady {
            return (.longPressReleasedWithoutDrag, nil)
        }

        if reorderEnabledSnapshot, let mouseDownEvent, !longPressReady {
            return (.quickClickEdit, mouseDownEvent)
        }

        return (.none, nil)
    }

    func pressingReadyIfElapsed() -> Bool {
        guard reorderEnabledSnapshot, !longPressReady, let fire = scheduledFireTime else { return false }
        if clock() >= fire {
            longPressReady = true
            return true
        }
        return false
    }

    func reset() {
        resetTrackingState()
        reorderEnabledSnapshot = false
    }

    private func resetTrackingState() {
        longPressReady = false
        isReorderDragging = false
        mouseDownEvent = nil
        scheduledFireTime = nil
    }
}
