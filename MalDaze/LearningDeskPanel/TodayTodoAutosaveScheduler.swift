import Foundation

@MainActor
final class TodayTodoAutosaveScheduler {
    typealias Sleep = (_ seconds: TimeInterval) async throws -> Void

    private let delay: TimeInterval
    private let sleep: Sleep
    private var pendingTask: Task<Void, Never>?

    init(
        delay: TimeInterval = 0.3,
        sleep: @escaping Sleep = { interval in
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    ) {
        self.delay = delay
        self.sleep = sleep
    }

    func schedule(_ action: @escaping @MainActor () -> Void) {
        pendingTask?.cancel()
        pendingTask = Task {
            do {
                try await sleep(delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            action()
        }
    }

    func flush(_ action: @escaping @MainActor () -> Void) {
        pendingTask?.cancel()
        pendingTask = nil
        action()
    }

    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
    }
}
