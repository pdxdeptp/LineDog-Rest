import Foundation

enum DashboardPresentationPhase: Equatable {
    case absent
    case hidden
    case visible
}

/// AppKit-authoritative pause/resume for Dashboard-scoped periodic work.
@MainActor
final class DashboardQuiescenceCoordinator {
    private struct Consumer {
        let pause: () -> Void
        let resume: () -> Void
    }

    private(set) var phase: DashboardPresentationPhase = .absent
    private var consumers: [UUID: Consumer] = [:]

    @discardableResult
    func registerConsumer(
        pause: @escaping () -> Void,
        resume: @escaping () -> Void
    ) -> UUID {
        let id = UUID()
        consumers[id] = Consumer(pause: pause, resume: resume)
        return id
    }

    func unregisterConsumer(_ id: UUID) {
        consumers.removeValue(forKey: id)
    }

    func transition(to newPhase: DashboardPresentationPhase) {
        let oldPhase = phase
        guard oldPhase != newPhase else { return }
        phase = newPhase
        switch (oldPhase, newPhase) {
        case (.visible, .hidden):
            pauseAll()
        case (.hidden, .visible), (.absent, .visible):
            resumeAll()
        default:
            break
        }
    }

    private func pauseAll() {
        for consumer in consumers.values {
            consumer.pause()
        }
    }

    private func resumeAll() {
        for consumer in consumers.values {
            consumer.resume()
        }
    }
}
