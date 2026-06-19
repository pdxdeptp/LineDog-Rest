import Foundation

enum TodayTodoLoadState: Equatable {
    case idle
    case ready
    case error(String)
}

@MainActor
final class TodayTodoStore: ObservableObject {
    @Published private(set) var incompleteEntries: [TodayTodoEntry] = []
    @Published private(set) var completedEntries: [TodayTodoEntry] = []
    @Published private(set) var loadState: TodayTodoLoadState = .idle
    @Published private(set) var mutationError: String?

    private var allEntries: [TodayTodoEntry] = []
    private let fileURL: URL
    private let todayISO: () -> String
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    var canMutate: Bool {
        if case .ready = loadState { return true }
        return false
    }

    init(
        fileURL: URL? = nil,
        todayISO: @escaping () -> String = { TodayTodoFormatting.isoDate(Date()) }
    ) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.todayISO = todayISO
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
        return dir.appendingPathComponent("today-todo.json", isDirectory: false)
    }

    func loadAndRollForward() {
        mutationError = nil
        do {
            var file = try readFile()
            let today = todayISO()
            var changed = false
            file.entries = file.entries.map { entry in
                guard !entry.isCompleted, entry.dateISO < today else { return entry }
                var rolled = entry
                rolled.rolledFromDateISO = entry.rolledFromDateISO ?? entry.dateISO
                rolled.dateISO = today
                changed = true
                return rolled
            }
            if changed {
                try writeFile(file)
            }
            allEntries = file.entries
            publishTodaySlices(for: today)
            loadState = .ready
        } catch let error as TodayTodoStoreError {
            loadState = .error(error.localizedDescription)
            incompleteEntries = []
            completedEntries = []
        } catch {
            loadState = .error("无法读取今日 todo。")
            incompleteEntries = []
            completedEntries = []
        }
    }

    @discardableResult
    func add(title rawTitle: String) -> Bool {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        guard canMutate else { return false }

        let today = todayISO()
        let nextIndex = (allEntries.map(\.sortIndex).max() ?? -1) + 1
        let entry = TodayTodoEntry(
            id: UUID(),
            title: title,
            dateISO: today,
            rolledFromDateISO: nil,
            isCompleted: false,
            createdAt: Date(),
            completedAt: nil,
            sortIndex: nextIndex
        )
        allEntries.append(entry)
        return persistTodaySlices() != nil
    }

    func toggleComplete(id: UUID) {
        guard canMutate else { return }
        guard let index = allEntries.firstIndex(where: { $0.id == id }) else { return }
        allEntries[index].isCompleted.toggle()
        if allEntries[index].isCompleted {
            allEntries[index].completedAt = Date()
        } else {
            allEntries[index].completedAt = nil
            allEntries[index].dateISO = todayISO()
        }
        _ = persistTodaySlices()
    }

    func updateTitle(id: UUID, title rawTitle: String) {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canMutate else { return }
        guard let index = allEntries.firstIndex(where: { $0.id == id }) else { return }
        if title.isEmpty {
            allEntries.remove(at: index)
        } else {
            allEntries[index].title = title
        }
        _ = persistTodaySlices()
    }

    func delete(id: UUID) {
        guard canMutate else { return }
        allEntries.removeAll { $0.id == id }
        _ = persistTodaySlices()
    }

    func historyGroupedByDate() -> [TodayTodoHistorySection] {
        let today = todayISO()
        let history = allEntries.filter { $0.isCompleted && $0.dateISO < today }
        let grouped = Dictionary(grouping: history, by: \.dateISO)
        return grouped.keys.sorted(by: >).map { dateISO in
            let entries = grouped[dateISO] ?? []
            let sorted = entries.sorted {
                ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt)
            }
            return TodayTodoHistorySection(dateISO: dateISO, entries: sorted)
        }
    }

    @discardableResult
    private func persistTodaySlices() -> Bool {
        mutationError = nil
        do {
            try writeFile(TodayTodoFile(version: 1, entries: allEntries))
            publishTodaySlices(for: todayISO())
            return true
        } catch {
            mutationError = "保存今日 todo 失败。"
            return false
        }
    }

    private func publishTodaySlices(for today: String) {
        let todayEntries = allEntries.filter { $0.dateISO == today }
        incompleteEntries = todayEntries
            .filter { !$0.isCompleted }
            .sorted { lhs, rhs in
                if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
                return lhs.createdAt < rhs.createdAt
            }
        completedEntries = todayEntries
            .filter(\.isCompleted)
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    private func readFile() throws -> TodayTodoFile {
        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path) {
            return TodayTodoFile(version: 1, entries: [])
        }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw TodayTodoStoreError.decodeFailed
        }
        let file: TodayTodoFile
        do {
            file = try jsonDecoder.decode(TodayTodoFile.self, from: data)
        } catch {
            throw TodayTodoStoreError.decodeFailed
        }
        guard file.version == 1 else {
            throw TodayTodoStoreError.unsupportedVersion(file.version)
        }
        return file
    }

    private func writeFile(_ file: TodayTodoFile) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try jsonEncoder.encode(file)
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw TodayTodoStoreError.writeFailed
        }
    }
}

extension TodayTodoStoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "今日 todo 文件版本不受支持（\(version)）。"
        case .decodeFailed:
            return "今日 todo 文件已损坏。"
        case .writeFailed:
            return "无法写入今日 todo 文件。"
        }
    }
}
