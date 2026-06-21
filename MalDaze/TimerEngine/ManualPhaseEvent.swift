import Foundation

struct ManualWorkPhase: Equatable {
    let startedAt: Date
    let endsAt: Date

    func remainingSeconds(at now: Date = Date()) -> Int {
        max(0, Int(endsAt.timeIntervalSince(now).rounded(.down)))
    }
}

enum ManualPhaseEvent: Equatable {
    case workStarted(start: Date, end: Date)
    case workCompleted(start: Date, end: Date)
    case restStarted(end: Date)
    case restEnded(nextWorkStart: Date, nextWorkEnd: Date)
    case engineStopped
}
