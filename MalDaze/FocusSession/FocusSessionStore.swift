import Foundation

@MainActor
final class FocusSessionStore: ObservableObject {
    @Published private(set) var allSessions: [FocusSession] = []

    private let fileURL: URL
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    private var didLoad = false

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        jsonEncoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        jsonDecoder = decoder
    }

    static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = base.appendingPathComponent("MalDaze", isDirectory: true)
        return dir.appendingPathComponent("focus-sessions.json", isDirectory: false)
    }

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        do {
            allSessions = try readFile().sessions
        } catch FocusSessionStoreError.decodeFailed {
            allSessions = []
        } catch {
            allSessions = []
        }
    }

    @discardableResult
    func appendFinalized(
        startedAt: Date,
        endedAt: Date,
        source: FocusSessionSource,
        calendar: Calendar = .current
    ) throws -> FocusSession {
        loadIfNeeded()
        let durationSeconds = FocusSessionFormatting.durationSeconds(from: startedAt, to: endedAt)
        guard durationSeconds > 0 else {
            throw FocusSessionStoreError.writeFailed
        }
        let session = FocusSession(
            date: FocusSessionFormatting.isoDate(endedAt, calendar: calendar),
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: durationSeconds,
            source: source
        )
        allSessions.append(session)
        try writeFile(FocusSessionFile(schemaVersion: 1, sessions: allSessions))
        return session
    }

    @discardableResult
    func updateSession(
        id: UUID,
        startedAt: Date,
        endedAt: Date,
        calendar: Calendar = .current
    ) throws -> FocusSession {
        loadIfNeeded()
        guard let index = allSessions.firstIndex(where: { $0.id == id }) else {
            throw FocusSessionStoreError.notFound
        }
        let durationSeconds = FocusSessionFormatting.durationSeconds(from: startedAt, to: endedAt)
        guard durationSeconds > 0 else {
            throw FocusSessionStoreError.writeFailed
        }
        let existing = allSessions[index]
        let updated = FocusSession(
            id: existing.id,
            date: FocusSessionFormatting.isoDate(endedAt, calendar: calendar),
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: durationSeconds,
            source: existing.source,
            labels: existing.labels
        )
        allSessions[index] = updated
        try writeFile(FocusSessionFile(schemaVersion: 1, sessions: allSessions))
        return updated
    }

    func deleteSession(id: UUID) throws {
        loadIfNeeded()
        guard let index = allSessions.firstIndex(where: { $0.id == id }) else {
            throw FocusSessionStoreError.notFound
        }
        allSessions.remove(at: index)
        try writeFile(FocusSessionFile(schemaVersion: 1, sessions: allSessions))
    }

    func todaySessions(calendar: Calendar = .current, now: Date = Date()) -> [FocusSession] {
        loadIfNeeded()
        let today = FocusSessionFormatting.isoDate(now, calendar: calendar)
        return allSessions
            .filter { $0.date == today }
            .sorted { $0.endedAt > $1.endedAt }
    }

    func todayFinalizedSeconds(calendar: Calendar = .current, now: Date = Date()) -> Int {
        todaySessions(calendar: calendar, now: now).reduce(0) { $0 + $1.durationSeconds }
    }

    func todayCompletedSeconds(calendar: Calendar = .current, now: Date = Date()) -> Int {
        todaySessions(calendar: calendar, now: now)
            .filter { $0.source == .completed }
            .reduce(0) { $0 + $1.durationSeconds }
    }

    func todayCompletedMinutes(calendar: Calendar = .current, now: Date = Date()) -> Int {
        FocusSessionFormatting.displayMinutes(fromSeconds: todayCompletedSeconds(calendar: calendar, now: now))
    }

    func todayFinalizedMinutes(calendar: Calendar = .current, now: Date = Date()) -> Int {
        FocusSessionFormatting.displayMinutes(fromSeconds: todayFinalizedSeconds(calendar: calendar, now: now))
    }

    func todaySessionCount(calendar: Calendar = .current, now: Date = Date()) -> Int {
        todaySessions(calendar: calendar, now: now).count
    }

    /// Full manual work segments that naturally entered rest (`source == .completed`).
    func todayPomodoroCount(calendar: Calendar = .current, now: Date = Date()) -> Int {
        todaySessions(calendar: calendar, now: now).filter { $0.source == .completed }.count
    }

    private func readFile() throws -> FocusSessionFile {
        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path) {
            return FocusSessionFile(schemaVersion: 1, sessions: [])
        }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw FocusSessionStoreError.decodeFailed
        }
        do {
            let file = try jsonDecoder.decode(FocusSessionFile.self, from: data)
            guard file.schemaVersion == 1 else {
                throw FocusSessionStoreError.unsupportedSchemaVersion(file.schemaVersion)
            }
            return file
        } catch let error as FocusSessionStoreError {
            throw error
        } catch {
            throw FocusSessionStoreError.decodeFailed
        }
    }

    private func writeFile(_ file: FocusSessionFile) throws {
        let dir = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try jsonEncoder.encode(file)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            throw FocusSessionStoreError.writeFailed
        }
    }
}
