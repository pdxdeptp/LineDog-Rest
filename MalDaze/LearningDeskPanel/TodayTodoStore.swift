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
    @Published private(set) var deletedEntries: [TodayTodoEntry] = []
    @Published private(set) var loadState: TodayTodoLoadState = .idle
    @Published private(set) var mutationError: String?

    private var allEntries: [TodayTodoEntry] = []
    private let fileURL: URL
    private var archiveLog: TodayTodoArchiveLog
    private let todayISO: () -> String
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    private let titleAutosave: TodayTodoAutosaveScheduler

    private var pendingLiveEditId: UUID?
    private var lastPersistedTitles: [UUID: String] = [:]

    var canMutate: Bool {
        if case .ready = loadState { return true }
        return false
    }

    init(
        fileURL: URL? = nil,
        archiveFileURL: URL? = nil,
        todayISO: @escaping () -> String = { TodayTodoFormatting.isoDate(Date()) },
        titleAutosave: TodayTodoAutosaveScheduler = TodayTodoAutosaveScheduler()
    ) {
        let resolvedFileURL = fileURL ?? Self.defaultFileURL()
        self.fileURL = resolvedFileURL
        self.archiveLog = TodayTodoArchiveLog(
            fileURL: archiveFileURL ?? TodayTodoArchiveLog.defaultFileURL(beside: resolvedFileURL)
        )
        self.todayISO = todayISO
        self.titleAutosave = titleAutosave
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

    func loadIfNeeded() {
        if case .ready = loadState {
            flushPendingTitleEdits()
            return
        }
        loadAndRollForward()
    }

    func loadAndRollForward() {
        if case .ready = loadState {
            flushPendingTitleEdits()
        }
        mutationError = nil
        do {
            var file = try readFile()
            let today = todayISO()
            var changed = false
            var rolledEntries: [TodayTodoEntry] = []
            file.entries = file.entries.map { entry in
                guard entry.deletedAt == nil else { return entry }
                guard !entry.isCompleted, entry.dateISO < today else { return entry }
                var rolled = entry
                rolled.rolledFromDateISO = entry.rolledFromDateISO ?? entry.dateISO
                rolled.dateISO = today
                changed = true
                rolledEntries.append(rolled)
                return rolled
            }
            if changed {
                try writeFile(file)
                for entry in rolledEntries {
                    recordArchive(.rollForward, entry: entry)
                }
            }
            allEntries = file.entries
            seedLastPersistedTitles()
            publishTodaySlices(for: today)
            loadState = .ready
        } catch let error as TodayTodoStoreError {
            loadState = .error(error.localizedDescription)
            incompleteEntries = []
            completedEntries = []
            deletedEntries = []
        } catch {
            loadState = .error("无法读取今日 todo。")
            incompleteEntries = []
            completedEntries = []
            deletedEntries = []
        }
    }

    func beginTitleEditing(id: UUID) {
        guard let index = allEntries.firstIndex(where: { $0.id == id }) else { return }
        lastPersistedTitles[id] = allEntries[index].title
        pendingLiveEditId = id
    }

    func updateTitleLive(id: UUID, title: String) {
        guard canMutate else { return }
        guard let index = allEntries.firstIndex(where: { $0.id == id }) else { return }

        pendingLiveEditId = id
        if allEntries[index].title != title {
            allEntries[index].title = title
        }

        titleAutosave.schedule { [weak self] in
            self?.persistLiveTitleIfNeeded(for: id)
        }
    }

    func flushPendingTitleEdits() {
        titleAutosave.flush { [weak self] in
            self?.persistPendingLiveTitleIfNeeded()
        }
    }

    func finalizeTitle(id: UUID, title rawTitle: String) {
        flushPendingTitleEdits()
        guard canMutate else { return }
        guard let index = allEntries.firstIndex(where: { $0.id == id }) else { return }

        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousTitle = lastPersistedTitles[id] ?? allEntries[index].title

        if trimmed.isEmpty {
            softDelete(at: index)
            guard persistTodaySlices() else { return }
            lastPersistedTitles[id] = nil
            pendingLiveEditId = nil
            recordArchive(.delete, entry: allEntries[index], previousTitle: previousTitle)
            return
        }

        if allEntries[index].title != trimmed {
            allEntries[index].title = trimmed
        }
        guard persistTodaySlices() else { return }

        if previousTitle != trimmed {
            recordArchive(.updateTitle, entry: allEntries[index], previousTitle: previousTitle)
        }
        lastPersistedTitles[id] = trimmed
        pendingLiveEditId = nil
    }

    func updateTitle(id: UUID, title rawTitle: String) {
        finalizeTitle(id: id, title: rawTitle)
    }

    @discardableResult
    func add(title rawTitle: String) -> Bool {
        flushPendingTitleEdits()
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
        guard persistTodaySlices() else { return false }
        lastPersistedTitles[entry.id] = title
        recordArchive(.add, entry: entry)
        return true
    }

    func toggleComplete(id: UUID) {
        flushPendingTitleEdits()
        guard canMutate else { return }
        guard let index = allEntries.firstIndex(where: { $0.id == id }) else { return }
        allEntries[index].isCompleted.toggle()
        if allEntries[index].isCompleted {
            allEntries[index].completedAt = Date()
        } else {
            allEntries[index].completedAt = nil
            allEntries[index].dateISO = todayISO()
        }
        guard persistTodaySlices() else { return }
        recordArchive(.toggleComplete, entry: allEntries[index])
    }

    func delete(id: UUID) {
        flushPendingTitleEdits()
        guard canMutate else { return }
        guard let index = allEntries.firstIndex(where: { $0.id == id }) else { return }
        let previousTitle = allEntries[index].title
        softDelete(at: index)
        guard persistTodaySlices() else { return }
        lastPersistedTitles[id] = nil
        if pendingLiveEditId == id { pendingLiveEditId = nil }
        recordArchive(.delete, entry: allEntries[index], previousTitle: previousTitle)
    }

    func moveIncomplete(from source: IndexSet, to destination: Int) {
        flushPendingTitleEdits()
        guard canMutate else { return }
        guard !source.isEmpty else { return }

        var ordered = incompleteEntries
        ordered.move(fromOffsets: source, toOffset: destination)
        applyIncompleteSortIndices(ordered)
        guard persistTodaySlices() else { return }
        recordArchive(.reorder, incompleteOrder: incompleteEntries.map(\.id))
    }

    func reorderIncomplete(draggedId: UUID, toFinalIndex finalIndex: Int) {
        flushPendingTitleEdits()
        guard canMutate else { return }

        var ordered = incompleteEntries
        guard let fromIndex = ordered.firstIndex(where: { $0.id == draggedId }) else { return }
        guard fromIndex != finalIndex else { return }

        let item = ordered.remove(at: fromIndex)
        let insertAt = min(max(finalIndex, 0), ordered.count)
        ordered.insert(item, at: insertAt)
        applyIncompleteSortIndices(ordered)
        guard persistTodaySlices() else { return }
        recordArchive(.reorder, entry: item, incompleteOrder: incompleteEntries.map(\.id))
    }

    func reorderIncomplete(fromSource sourceIndex: Int, toInsertionIndex insertionIndex: Int) {
        flushPendingTitleEdits()
        guard canMutate else { return }
        guard insertionIndex != sourceIndex, insertionIndex != sourceIndex + 1 else { return }

        var ordered = incompleteEntries
        guard ordered.indices.contains(sourceIndex) else { return }
        let item = ordered.remove(at: sourceIndex)
        let insertAt = insertionIndex > sourceIndex ? insertionIndex - 1 : insertionIndex
        ordered.insert(item, at: insertAt)
        applyIncompleteSortIndices(ordered)
        guard persistTodaySlices() else { return }
        recordArchive(.reorder, entry: item, incompleteOrder: incompleteEntries.map(\.id))
    }

    func moveIncomplete(draggedId: UUID, before targetId: UUID) {
        flushPendingTitleEdits()
        guard canMutate, draggedId != targetId else { return }

        var ordered = incompleteEntries
        guard let fromIndex = ordered.firstIndex(where: { $0.id == draggedId }),
              let targetIndex = ordered.firstIndex(where: { $0.id == targetId })
        else { return }

        let entry = ordered.remove(at: fromIndex)
        let insertIndex = fromIndex < targetIndex ? targetIndex - 1 : targetIndex
        ordered.insert(entry, at: insertIndex)
        applyIncompleteSortIndices(ordered)
        guard persistTodaySlices() else { return }
        recordArchive(.reorder, entry: entry, incompleteOrder: incompleteEntries.map(\.id))
    }

    func restore(id: UUID) {
        flushPendingTitleEdits()
        guard canMutate else { return }
        guard let index = allEntries.firstIndex(where: { $0.id == id }) else { return }
        guard allEntries[index].deletedAt != nil else { return }
        allEntries[index].deletedAt = nil
        guard persistTodaySlices() else { return }
        lastPersistedTitles[id] = allEntries[index].title
        recordArchive(.restore, entry: allEntries[index])
    }

    func permanentlyDelete(id: UUID) {
        flushPendingTitleEdits()
        guard canMutate else { return }
        guard let index = allEntries.firstIndex(where: { $0.id == id }) else { return }
        guard allEntries[index].deletedAt != nil else { return }
        let entry = allEntries[index]
        allEntries.remove(at: index)
        guard persistTodaySlices() else { return }
        lastPersistedTitles[id] = nil
        if pendingLiveEditId == id { pendingLiveEditId = nil }
        recordArchive(.permanentDelete, entry: entry)
    }

    func historyGroupedByDate() -> [TodayTodoHistorySection] {
        let today = todayISO()
        let history = allEntries.filter {
            $0.deletedAt == nil && $0.isCompleted && $0.dateISO < today
        }
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

    private func persistPendingLiveTitleIfNeeded() {
        guard let id = pendingLiveEditId else { return }
        persistLiveTitleIfNeeded(for: id)
    }

    private func persistLiveTitleIfNeeded(for id: UUID) {
        guard canMutate else { return }
        guard let index = allEntries.firstIndex(where: { $0.id == id }) else { return }

        let title = allEntries[index].title
        let previousTitle = lastPersistedTitles[id] ?? title
        guard previousTitle != title else { return }

        guard persistTodaySlices() else { return }
        lastPersistedTitles[id] = title
        recordArchive(.updateTitle, entry: allEntries[index], previousTitle: previousTitle)
    }

    private func seedLastPersistedTitles() {
        lastPersistedTitles = Dictionary(uniqueKeysWithValues: allEntries.map { ($0.id, $0.title) })
    }

    private func recordArchive(
        _ action: TodayTodoArchiveAction,
        entry: TodayTodoEntry? = nil,
        previousTitle: String? = nil,
        incompleteOrder: [UUID]? = nil
    ) {
        archiveLog.append(
            TodayTodoArchiveRecord(
                action: action,
                entry: entry,
                previousTitle: previousTitle,
                incompleteOrder: incompleteOrder
            )
        )
    }

    private func publishTodaySlices(for today: String) {
        let activeEntries = allEntries.filter { $0.deletedAt == nil }
        deletedEntries = allEntries
            .filter { $0.deletedAt != nil }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }

        let todayEntries = activeEntries.filter { $0.dateISO == today }
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

    private func softDelete(at index: Int) {
        allEntries[index].deletedAt = Date()
    }

    private func applyIncompleteSortIndices(_ ordered: [TodayTodoEntry]) {
        for (index, entry) in ordered.enumerated() {
            guard let allIndex = allEntries.firstIndex(where: { $0.id == entry.id }) else { continue }
            allEntries[allIndex].sortIndex = index
        }
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
