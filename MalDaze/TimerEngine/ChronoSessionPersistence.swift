import Foundation

// MARK: - Record

/// Wall-clock SSOT for an in-flight chrono session. `phaseEnd` is the absolute end of the current phase.
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

    /// `.none` — app exited while counting; relaunch restores engines immediately.
    /// `.user` — user tapped「停止计时」; relaunch shows「恢复计时」until resumed.
    enum PauseKind: String, Codable {
        case none
        case user
    }

    let mode: Mode
    let phase: Phase
    let phaseEnd: Date
    let pauseKind: PauseKind
    /// Manual work segment only; used for Dashboard in-progress focus row.
    let workSegmentStartedAt: Date?

    var isUserPaused: Bool { pauseKind == .user }

    func appMode() -> AppViewModel.Mode {
        switch mode {
        case .manual: return .manual
        case .auto: return .auto
        }
    }
}

/// Legacy pause token without a phase anchor. Resume realigns / restarts instead of continuing remaining time.
struct ChronoSessionModeOnlyPause: Equatable {
    let mode: ChronoSessionRecord.Mode

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
    case modeOnlyPause(ChronoSessionModeOnlyPause)
}

// MARK: - Capture

struct ChronoSessionCaptureContext {
    let mode: AppViewModel.Mode
    let manualEngine: ManualTimerEngine
    let autoEngine: AutoTimerEngine
    let workSegmentStartedAt: Date?
    let wasInManualWorkPhase: Bool
}

// MARK: - Bootstrap

enum ChronoSessionBootstrapPlan: Equatable {
    case usePreferredMode(AppViewModel.Mode)
    case restoreRunning(ChronoSessionRecord)
    case restoreUserPaused(ChronoSessionRecord)
    case restoreUserPausedModeOnly(ChronoSessionModeOnlyPause)
}

struct ChronoSessionEngineRestoreHints: Equatable {
    let workSegmentStartedAt: Date?
    let wasInManualWorkPhase: Bool
}

// MARK: - Store

enum ChronoSessionStore {
    private static let schemaVersion = 2

    private struct Envelope: Codable {
        let schemaVersion: Int
        let record: ChronoSessionRecord
    }

    static func loadState(defaults: UserDefaults = .standard) -> ChronoSessionStoredState {
        if let data = defaults.data(forKey: MalDazeDefaults.chronoSessionSnapshot) {
            if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
               envelope.schemaVersion == schemaVersion {
                return .record(envelope.record)
            }
            if let legacy = try? JSONDecoder().decode(LegacyChronoSessionSnapshot.self, from: data),
               let record = migrateLegacySnapshot(legacy) {
                return .record(record)
            }
            if let legacy = try? JSONDecoder().decode(LegacyChronoSessionSnapshot.self, from: data),
               legacy.isUserSuspended,
               let mode = ChronoSessionRecord.Mode(rawValue: legacy.modeToken) {
                return .modeOnlyPause(ChronoSessionModeOnlyPause(mode: mode))
            }
        }
        if let modeOnly = migrateLegacySuspendedModeToken(defaults: defaults) {
            return .modeOnlyPause(modeOnly)
        }
        return .none
    }

    static func save(_ record: ChronoSessionRecord, defaults: UserDefaults = .standard) {
        let envelope = Envelope(schemaVersion: schemaVersion, record: record)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        defaults.set(data, forKey: MalDazeDefaults.chronoSessionSnapshot)
        if record.isUserPaused {
            defaults.set(record.mode.rawValue, forKey: MalDazeDefaults.suspendedTimerModeSnapshot)
        }
    }

    static func saveModeOnlyPause(_ pause: ChronoSessionModeOnlyPause, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: MalDazeDefaults.chronoSessionSnapshot)
        defaults.set(pause.mode.rawValue, forKey: MalDazeDefaults.suspendedTimerModeSnapshot)
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
        return ChronoSessionRecord(
            mode: mode,
            phase: phase,
            phaseEnd: phaseEnd,
            pauseKind: legacy.isUserSuspended ? .user : .none,
            workSegmentStartedAt: legacy.workSegmentStartedAt
        )
    }

    private static func migrateLegacySuspendedModeToken(defaults: UserDefaults) -> ChronoSessionModeOnlyPause? {
        guard defaults.object(forKey: MalDazeDefaults.suspendedTimerModeSnapshot) != nil else {
            return nil
        }
        guard let rawMode = defaults.string(forKey: MalDazeDefaults.suspendedTimerModeSnapshot),
              let mode = ChronoSessionRecord.Mode(rawValue: rawMode) else {
            defaults.removeObject(forKey: MalDazeDefaults.suspendedTimerModeSnapshot)
            return nil
        }
        return ChronoSessionModeOnlyPause(mode: mode)
    }
}

// MARK: - Coordinator

struct ChronoSessionCoordinator {
    private(set) var lastPersistedPhaseEnd: Date?

    mutating func persistRunning(from context: ChronoSessionCaptureContext, defaults: UserDefaults = .standard) {
        guard let record = capture(from: context, pauseKind: .none) else { return }
        persistIfChanged(record, defaults: defaults)
    }

    mutating func persistUserPaused(from context: ChronoSessionCaptureContext, defaults: UserDefaults = .standard) {
        if let record = capture(from: context, pauseKind: .user) {
            save(record, defaults: defaults)
            lastPersistedPhaseEnd = record.phaseEnd
            return
        }
        let mode: ChronoSessionRecord.Mode = context.mode == .manual ? .manual : .auto
        ChronoSessionStore.saveModeOnlyPause(ChronoSessionModeOnlyPause(mode: mode), defaults: defaults)
        lastPersistedPhaseEnd = nil
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

    func capture(
        from context: ChronoSessionCaptureContext,
        pauseKind: ChronoSessionRecord.PauseKind
    ) -> ChronoSessionRecord? {
        let mode: ChronoSessionRecord.Mode = context.mode == .manual ? .manual : .auto

        switch context.mode {
        case .manual:
            guard context.manualEngine.isTimerRunning,
                  let phaseEnd = context.manualEngine.currentPhaseEnd else {
                return nil
            }
            let phase: ChronoSessionRecord.Phase = context.manualEngine.isInRestPhase ? .manualResting : .manualWorking
            let startedAt = (!context.manualEngine.isInRestPhase && context.wasInManualWorkPhase)
                ? context.workSegmentStartedAt
                : nil
            return ChronoSessionRecord(
                mode: mode,
                phase: phase,
                phaseEnd: phaseEnd,
                pauseKind: pauseKind,
                workSegmentStartedAt: startedAt
            )
        case .auto:
            guard context.autoEngine.isTimerRunning else { return nil }
            if context.autoEngine.isInScheduledRest, let phaseEnd = context.autoEngine.currentPhaseEnd {
                return ChronoSessionRecord(
                    mode: mode,
                    phase: .autoResting,
                    phaseEnd: phaseEnd,
                    pauseKind: pauseKind,
                    workSegmentStartedAt: nil
                )
            }
            if let anchor = context.autoEngine.currentWaitingAnchor ?? context.autoEngine.currentPhaseEnd {
                return ChronoSessionRecord(
                    mode: mode,
                    phase: .autoWatching,
                    phaseEnd: anchor,
                    pauseKind: pauseKind,
                    workSegmentStartedAt: nil
                )
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
            switch record.pauseKind {
            case .none:
                return .restoreRunning(record)
            case .user:
                return .restoreUserPaused(record)
            }
        case .modeOnlyPause(let pause):
            return .restoreUserPausedModeOnly(pause)
        }
    }

    func applyEngines(
        record: ChronoSessionRecord,
        manualEngine: ManualTimerEngine,
        autoEngine: AutoTimerEngine
    ) -> ChronoSessionEngineRestoreHints {
        switch record.phase {
        case .manualWorking:
            manualEngine.restorePersistedPhase(end: record.phaseEnd, isRestPhase: false)
            if let startedAt = record.workSegmentStartedAt {
                return ChronoSessionEngineRestoreHints(
                    workSegmentStartedAt: startedAt,
                    wasInManualWorkPhase: true
                )
            }
            return ChronoSessionEngineRestoreHints(
                workSegmentStartedAt: record.phaseEnd.addingTimeInterval(-manualEngine.configuredWorkDuration),
                wasInManualWorkPhase: true
            )
        case .manualResting:
            manualEngine.restorePersistedPhase(end: record.phaseEnd, isRestPhase: true)
            return ChronoSessionEngineRestoreHints(workSegmentStartedAt: nil, wasInManualWorkPhase: false)
        case .autoWatching:
            autoEngine.restorePersistedWatching(nextAnchor: record.phaseEnd)
            return ChronoSessionEngineRestoreHints(workSegmentStartedAt: nil, wasInManualWorkPhase: false)
        case .autoResting:
            autoEngine.restorePersistedRest(end: record.phaseEnd)
            return ChronoSessionEngineRestoreHints(workSegmentStartedAt: nil, wasInManualWorkPhase: false)
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

// Backward-compatible test helpers.
enum ChronoSessionSnapshotStore {
    static func clear(defaults: UserDefaults = .standard) {
        ChronoSessionStore.clear(defaults: defaults)
    }
}
