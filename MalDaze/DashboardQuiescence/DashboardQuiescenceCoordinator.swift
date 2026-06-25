import Foundation

enum DashboardPresentationPhase: Equatable {
    case absent
    case hidden
    case visible
}

/// AppKit-authoritative pause/resume for Dashboard-scoped periodic work.
@MainActor
final class DashboardQuiescenceCoordinator {
    private(set) var phase: DashboardPresentationPhase = .absent
    private var pauseHandlers: [UUID: () -> Void] = [:]

    @discardableResult
    func registerPauseHandler(_ handler: @escaping () -> Void) -> UUID {
        let id = UUID()
        pauseHandlers[id] = handler
        return id
    }

    func unregisterPauseHandler(_ id: UUID) {
        pauseHandlers.removeValue(forKey: id)
    }

    func transition(to newPhase: DashboardPresentationPhase) {
        let oldPhase = phase
        phase = newPhase
        if oldPhase == .visible, newPhase == .hidden {
            pauseAll()
        }
    }

    func pauseAll() {
        for handler in pauseHandlers.values {
            handler()
        }
    }
}
