import Foundation

// MARK: - Record

/// Wall-clock SSOT for an actively running chrono session. `phaseEnd` is the absolute end of the current phase.
struct ChronoSessionRecord: Codable, Equatable {
    enum Mode: String, Codable {
        case manual
        case auto
    }

    enum Phase: String, Codable {
        case manualWorking
        case manualResting
        case autoWatching
        case autoResting
    }

    let mode: Mode
    let phase: Phase
    let phaseEnd: Date

    func appMode() -> AppViewModel.Mode {
        switch mode {
        case .manual: return .manual
        case .auto: return .auto
        }
    }
}

enum ChronoSessionStoredState: Equatable {
    case none
    case record(ChronoSessionRecord)
}

// MARK: - Capture

struct ChronoSessionCaptureContext {
    let mode: AppViewModel.Mode
    let manualEngine: ManualTimerEngine
    let autoEngine: AutoTimerEngine
}

// MARK: - Bootstrap

enum ChronoSessionBootstrapPlan: Equatable {
    case usePreferredMode(AppViewModel.Mode)
    case restoreRunning(ChronoSessionRecord)
}

// MARK: - Store

enum ChronoSessionStore {
    private static let schemaVersion = 3

    private struct Envelope: Codable {
        let schemaVersion: Int
        let record: ChronoSessionRecord
    }

    private struct V2Record: Codable {
        let mode: ChronoSessionRecord.Mode
        let phase: ChronoSessionRecord.Phase
        let phaseEnd: Date
        let pauseKind: String
    }

    private struct V2Envelope: Codable {
        let schemaVersion: Int
        let record: V2Record
    }

    static func loadState(defaults: UserDefaults = .standard) -> ChronoSessionStoredState {
        if let data = defaults.data(forKey: MalDazeDefaults.chronoSessionSnapshot) {
            if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
               envelope.schemaVersion == schemaVersion {
                return .record(envelope.record)
            }
            if let v2 = try? JSONDecoder().decode(V2Envelope.self, from: data),
               v2.schemaVersion == 2 {
                if v2.record.pauseKind == "user" {
                    clear(defaults: defaults)
                    return .none
                }
                return .record(
                    ChronoSessionRecord(
                        mode: v2.record.mode,
                        phase: v2.record.phase,
                        phaseEnd: v2.record.phaseEnd
                    )
                )
            }
            if let legacy = try? JSONDecoder().decode(LegacyChronoSessionSnapshot.self, from: data),
               let record = migrateLegacySnapshot(legacy) {
                return .record(record)
            }
        }
        if defaults.object(forKey: MalDazeDefaults.suspendedTimerModeSnapshot) != nil {
            clear(defaults: defaults)
        }
        return .none
    }

    static func save(_ record: ChronoSessionRecord, defaults: UserDefaults = .standard) {
        let envelope = Envelope(schemaVersion: schemaVersion, record: record)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        defaults.set(data, forKey: MalDazeDefaults.chronoSessionSnapshot)
        defaults.removeObject(forKey: MalDazeDefaults.suspendedTimerModeSnapshot)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: MalDazeDefaults.chronoSessionSnapshot)
        defaults.removeObject(forKey: MalDazeDefaults.suspendedTimerModeSnapshot)
    }

    private static func migrateLegacySnapshot(_ legacy: LegacyChronoSessionSnapshot) -> ChronoSessionRecord? {
        guard let mode = ChronoSessionRecord.Mode(rawValue: legacy.modeToken),
              let phase = legacy.phase,
              let phaseEnd = legacy.phaseEnd else {
            return nil
        }
        if legacy.isUserSuspended {
            return nil
        }
        return ChronoSessionRecord(mode: mode, phase: phase, phaseEnd: phaseEnd)
    }
}

// MARK: - Coordinator

struct ChronoSessionCoordinator {
    private(set) var lastPersistedPhaseEnd: Date?

    mutating func persistRunning(from context: ChronoSessionCaptureContext, defaults: UserDefaults = .standard) {
        guard let record = capture(from: context) else { return }
        persistIfChanged(record, defaults: defaults)
    }

    mutating func persistIfChanged(_ record: ChronoSessionRecord, defaults: UserDefaults = .standard) {
        if lastPersistedPhaseEnd == record.phaseEnd,
           defaults.data(forKey: MalDazeDefaults.chronoSessionSnapshot) != nil {
            return
        }
        save(record, defaults: defaults)
        lastPersistedPhaseEnd = record.phaseEnd
    }

    func save(_ record: ChronoSessionRecord, defaults: UserDefaults = .standard) {
        ChronoSessionStore.save(record, defaults: defaults)
    }

    mutating func clear(defaults: UserDefaults = .standard) {
        ChronoSessionStore.clear(defaults: defaults)
        lastPersistedPhaseEnd = nil
    }

    func loadState(defaults: UserDefaults = .standard) -> ChronoSessionStoredState {
        ChronoSessionStore.loadState(defaults: defaults)
    }

    func capture(from context: ChronoSessionCaptureContext) -> ChronoSessionRecord? {
        let mode: ChronoSessionRecord.Mode = context.mode == .manual ? .manual : .auto

        switch context.mode {
        case .manual:
            guard context.manualEngine.isTimerRunning,
                  let phaseEnd = context.manualEngine.currentPhaseEnd else {
                return nil
            }
            let phase: ChronoSessionRecord.Phase = context.manualEngine.isInRestPhase ? .manualResting : .manualWorking
            return ChronoSessionRecord(mode: mode, phase: phase, phaseEnd: phaseEnd)
        case .auto:
            guard context.autoEngine.isTimerRunning else { return nil }
            if context.autoEngine.isInScheduledRest, let phaseEnd = context.autoEngine.currentPhaseEnd {
                return ChronoSessionRecord(mode: mode, phase: .autoResting, phaseEnd: phaseEnd)
            }
            if let anchor = context.autoEngine.currentWaitingAnchor ?? context.autoEngine.currentPhaseEnd {
                return ChronoSessionRecord(mode: mode, phase: .autoWatching, phaseEnd: anchor)
            }
            return nil
        }
    }

    func planBootstrap(
        stored: ChronoSessionStoredState,
        preferredMode: AppViewModel.Mode
    ) -> ChronoSessionBootstrapPlan {
        switch stored {
        case .none:
            return .usePreferredMode(preferredMode)
        case .record(let record):
            return .restoreRunning(record)
        }
    }

    func applyEngines(
        record: ChronoSessionRecord,
        manualEngine: ManualTimerEngine,
        autoEngine: AutoTimerEngine
    ) {
        switch record.phase {
        case .manualWorking:
            manualEngine.restorePersistedPhase(end: record.phaseEnd, isRestPhase: false)
        case .manualResting:
            manualEngine.restorePersistedPhase(end: record.phaseEnd, isRestPhase: true)
        case .autoWatching:
            autoEngine.restorePersistedWatching(nextAnchor: record.phaseEnd)
        case .autoResting:
            autoEngine.restorePersistedRest(end: record.phaseEnd)
        }
    }
}

// MARK: - Legacy decode

private struct LegacyChronoSessionSnapshot: Codable {
    let modeToken: String
    let isUserSuspended: Bool
    let phase: ChronoSessionRecord.Phase?
    let phaseEnd: Date?
    let workSegmentStartedAt: Date?
}

enum ChronoSessionSnapshotStore {
    static func clear(defaults: UserDefaults = .standard) {
        ChronoSessionStore.clear(defaults: defaults)
    }
}
