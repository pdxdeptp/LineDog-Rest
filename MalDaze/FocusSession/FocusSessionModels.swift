import Foundation

enum FocusSessionSource: String, Codable, Equatable {
    case completed
    case stoppedEarly
}

struct FocusSession: Codable, Identifiable, Equatable {
    let id: UUID
    let date: String
    let startedAt: Date
    let endedAt: Date
    /// SSOT for elapsed time; UI minutes are derived via floor division.
    let durationSeconds: Int
    let source: FocusSessionSource
    let labels: [String]

    var durationMinutes: Int {
        durationSeconds / 60
    }

    init(
        id: UUID = UUID(),
        date: String,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        source: FocusSessionSource,
        labels: [String] = []
    ) {
        self.id = id
        self.date = date
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.source = source
        self.labels = labels
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case startedAt
        case endedAt
        case durationSeconds
        case durationMinutes
        case source
        case labels
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(String.self, forKey: .date)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decode(Date.self, forKey: .endedAt)
        source = try container.decode(FocusSessionSource.self, forKey: .source)
        labels = try container.decodeIfPresent([String].self, forKey: .labels) ?? []
        if let seconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds) {
            durationSeconds = seconds
        } else {
            let legacyMinutes = try container.decode(Int.self, forKey: .durationMinutes)
            durationSeconds = legacyMinutes * 60
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(endedAt, forKey: .endedAt)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encode(source, forKey: .source)
        try container.encode(labels, forKey: .labels)
    }
}

struct FocusSessionFile: Codable, Equatable {
    var schemaVersion: Int
    var sessions: [FocusSession]
}

enum FocusSessionStoreError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case decodeFailed
    case writeFailed
    case notFound
}

enum FocusSessionFormatting {
    static func isoDate(_ date: Date, calendar: Calendar = .current) -> String {
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func clockTime(_ date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%02d:%02d", hour, minute)
    }

    static func durationSeconds(from startedAt: Date, to endedAt: Date) -> Int {
        max(0, Int(endedAt.timeIntervalSince(startedAt).rounded(.down)))
    }

    static func displayMinutes(fromSeconds seconds: Int) -> Int {
        seconds / 60
    }

    static func elapsedWholeSeconds(from startedAt: Date, to now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(startedAt).rounded(.down)))
    }

    static func elapsedWholeMinutes(from startedAt: Date, to now: Date) -> Int {
        displayMinutes(fromSeconds: elapsedWholeSeconds(from: startedAt, to: now))
    }
}

struct FocusPomodoroInProgress: Equatable {
    let startedAt: Date
    let endsAt: Date
    let remainingSeconds: Int
    let elapsedSeconds: Int

    var elapsedMinutes: Int {
        FocusSessionFormatting.displayMinutes(fromSeconds: elapsedSeconds)
    }

    var configuredDurationSeconds: Int {
        FocusSessionFormatting.durationSeconds(from: startedAt, to: endsAt)
    }

    var configuredDurationMinutes: Int {
        FocusSessionFormatting.displayMinutes(fromSeconds: configuredDurationSeconds)
    }
}

/// Backward-compatible alias for timeline call sites migrating to pomodoro-scoped projection.
typealias FocusSessionInProgress = FocusPomodoroInProgress
