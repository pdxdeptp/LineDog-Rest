import XCTest
@testable import MalDaze

@MainActor
final class TodayTodoStoreTests: XCTestCase {
    private var fileURL: URL!
    private var archiveURL: URL!
    private var todayISO: String!

    override func setUp() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TodayTodoStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("today-todo.json")
        archiveURL = dir.appendingPathComponent("today-todo-archive.jsonl")
        todayISO = "2026-06-18"
    }

    override func tearDown() async throws {
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }
    }

    private func makeStore() -> TodayTodoStore {
        TodayTodoStore(fileURL: fileURL, archiveFileURL: archiveURL, todayISO: { [unowned self] in self.todayISO })
    }

    private func readArchiveRecords() throws -> [TodayTodoArchiveRecord] {
        let data = try Data(contentsOf: archiveURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try data
            .split(separator: 0x0A, omittingEmptySubsequences: true)
            .map { try decoder.decode(TodayTodoArchiveRecord.self, from: Data($0)) }
    }

    func testMutationsAppendArchiveRecords() throws {
        let store = makeStore()
        store.loadAndRollForward()

        XCTAssertTrue(store.add(title: "买打印纸"))
        XCTAssertTrue(store.add(title: "第二项"))
        let id = try XCTUnwrap(store.incompleteEntries.first?.id)

        store.updateTitle(id: id, title: "买 A4 纸")
        store.toggleComplete(id: id)
        store.toggleComplete(id: id)
        store.delete(id: id)
        store.restore(id: id)
        store.reorderIncomplete(draggedId: id, toFinalIndex: 1)
        store.delete(id: id)
        store.permanentlyDelete(id: id)

        let records = try readArchiveRecords()
        XCTAssertEqual(records.map(\.action), [
            .add,
            .add,
            .updateTitle,
            .toggleComplete,
            .toggleComplete,
            .delete,
            .restore,
            .reorder,
            .delete,
            .permanentDelete,
        ])
        XCTAssertEqual(records[2].previousTitle, "买打印纸")
        XCTAssertEqual(records[2].entry?.title, "买 A4 纸")
        XCTAssertEqual(records.last?.entry?.id, id)
    }

    func testLiveTitlePersistsBeforeEndEditing() throws {
        let store = makeStore()
        store.loadAndRollForward()
        XCTAssertTrue(store.add(title: "原始标题"))
        let id = try XCTUnwrap(store.incompleteEntries.first?.id)

        store.beginTitleEditing(id: id)
        store.updateTitleLive(id: id, title: "实时修改")
        store.flushPendingTitleEdits()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(TodayTodoFile.self, from: Data(contentsOf: fileURL))
        let saved = try XCTUnwrap(file.entries.first(where: { $0.id == id }))
        XCTAssertEqual(saved.title, "实时修改")

        let records = try readArchiveRecords()
        XCTAssertTrue(records.contains(where: { $0.action == .updateTitle && $0.entry?.title == "实时修改" }))
    }

    func testFinalizeTitleTrimsWhitespace() throws {
        let store = makeStore()
        store.loadAndRollForward()
        XCTAssertTrue(store.add(title: "原始"))
        let id = try XCTUnwrap(store.incompleteEntries.first?.id)

        store.beginTitleEditing(id: id)
        store.finalizeTitle(id: id, title: "  定稿标题  \n")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(TodayTodoFile.self, from: Data(contentsOf: fileURL))
        let saved = try XCTUnwrap(file.entries.first(where: { $0.id == id }))
        XCTAssertEqual(saved.title, "定稿标题")
    }

    func testLoadIfNeededDoesNotReloadAfterReady() throws {
        let store = makeStore()
        store.loadAndRollForward()
        XCTAssertTrue(store.add(title: "第一条"))

        store.beginTitleEditing(id: store.incompleteEntries[0].id)
        store.updateTitleLive(id: store.incompleteEntries[0].id, title: "未 flush")
        store.loadIfNeeded()
        store.flushPendingTitleEdits()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(TodayTodoFile.self, from: Data(contentsOf: fileURL))
        XCTAssertEqual(file.entries.first?.title, "未 flush")
    }

    func testRollForwardWritesArchiveRecord() throws {
        let yesterday = "2026-06-17"
        let entryId = UUID()
        let seed = TodayTodoFile(
            version: 1,
            entries: [
                TodayTodoEntry(
                    id: entryId,
                    title: "未完成",
                    dateISO: yesterday,
                    rolledFromDateISO: nil,
                    isCompleted: false,
                    createdAt: Date(),
                    completedAt: nil,
                    sortIndex: 0
                )
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(seed).write(to: fileURL, options: .atomic)

        let store = makeStore()
        store.loadAndRollForward()

        let records = try readArchiveRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].action, .rollForward)
        XCTAssertEqual(records[0].entry?.id, entryId)
        XCTAssertEqual(records[0].entry?.dateISO, todayISO)
        XCTAssertEqual(records[0].entry?.rolledFromDateISO, yesterday)
    }

    func testAddMultilineTitlePreservesNewlines() {
        let store = makeStore()
        store.loadAndRollForward()

        XCTAssertTrue(store.add(title: "第一行\n第二行"))
        XCTAssertEqual(store.incompleteEntries.first?.title, "第一行\n第二行")
    }

    func testAddCompleteDeleteAndRejectEmptyTitle() throws {
        let store = makeStore()
        store.loadAndRollForward()

        XCTAssertFalse(store.add(title: "   "))
        XCTAssertTrue(store.add(title: "买打印纸"))
        XCTAssertEqual(store.incompleteEntries.count, 1)
        XCTAssertEqual(store.incompleteEntries[0].title, "买打印纸")

        let id = store.incompleteEntries[0].id
        store.toggleComplete(id: id)
        XCTAssertEqual(store.incompleteEntries.count, 0)
        XCTAssertEqual(store.completedEntries.count, 1)

        store.delete(id: id)
        XCTAssertEqual(store.completedEntries.count, 0)
        XCTAssertEqual(store.deletedEntries.count, 1)
        XCTAssertEqual(store.deletedEntries[0].title, "买打印纸")

        store.restore(id: id)
        XCTAssertEqual(store.completedEntries.count, 1)
        XCTAssertEqual(store.deletedEntries.count, 0)

        store.delete(id: id)
        store.permanentlyDelete(id: id)
        XCTAssertEqual(store.deletedEntries.count, 0)

        let data = try Data(contentsOf: fileURL)
        let file = try JSONDecoder().decode(TodayTodoFile.self, from: data)
        XCTAssertTrue(file.entries.isEmpty)
    }

    func testDeleteMovesIncompleteEntryToTrash() {
        let store = makeStore()
        store.loadAndRollForward()
        XCTAssertTrue(store.add(title: "误删项"))
        let id = store.incompleteEntries[0].id

        store.delete(id: id)
        XCTAssertEqual(store.incompleteEntries.count, 0)
        XCTAssertEqual(store.deletedEntries.count, 1)

        store.restore(id: id)
        XCTAssertEqual(store.incompleteEntries.count, 1)
        XCTAssertEqual(store.incompleteEntries[0].title, "误删项")
    }

    func testRollForwardIncompleteEntry() throws {
        let yesterday = "2026-06-17"
        let seed = TodayTodoFile(
            version: 1,
            entries: [
                TodayTodoEntry(
                    id: UUID(),
                    title: "未完成",
                    dateISO: yesterday,
                    rolledFromDateISO: nil,
                    isCompleted: false,
                    createdAt: Date(),
                    completedAt: nil,
                    sortIndex: 0
                )
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(seed).write(to: fileURL, options: .atomic)

        let store = makeStore()
        store.loadAndRollForward()

        XCTAssertEqual(store.incompleteEntries.count, 1)
        XCTAssertEqual(store.incompleteEntries[0].dateISO, todayISO)
        XCTAssertEqual(store.incompleteEntries[0].rolledFromDateISO, yesterday)
    }

    func testHistoryIncludesCompletedPastOnly() throws {
        let yesterday = "2026-06-17"
        let seed = TodayTodoFile(
            version: 1,
            entries: [
                TodayTodoEntry(
                    id: UUID(),
                    title: "已完成昨天",
                    dateISO: yesterday,
                    rolledFromDateISO: nil,
                    isCompleted: true,
                    createdAt: Date(),
                    completedAt: Date(),
                    sortIndex: 0
                ),
                TodayTodoEntry(
                    id: UUID(),
                    title: "未完成昨天",
                    dateISO: yesterday,
                    rolledFromDateISO: nil,
                    isCompleted: false,
                    createdAt: Date(),
                    completedAt: nil,
                    sortIndex: 1
                )
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(seed).write(to: fileURL, options: .atomic)

        let store = makeStore()
        store.loadAndRollForward()

        let history = store.historyGroupedByDate()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].dateISO, yesterday)
        XCTAssertEqual(history[0].entries.map(\.title), ["已完成昨天"])
        XCTAssertEqual(store.incompleteEntries.map(\.title), ["未完成昨天"])
    }

    func testMoveIncompleteReordersAndPersistsSortIndex() throws {
        let store = makeStore()
        store.loadAndRollForward()

        XCTAssertTrue(store.add(title: "第一项"))
        XCTAssertTrue(store.add(title: "第二项"))
        XCTAssertTrue(store.add(title: "第三项"))

        store.moveIncomplete(from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(store.incompleteEntries.map(\.title), ["第三项", "第一项", "第二项"])

        store.moveIncomplete(from: IndexSet(integer: 2), to: 1)
        XCTAssertEqual(store.incompleteEntries.map(\.title), ["第三项", "第二项", "第一项"])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try Data(contentsOf: fileURL)
        let file = try decoder.decode(TodayTodoFile.self, from: data)
        let todayEntries = file.entries.filter { $0.dateISO == todayISO && !$0.isCompleted && $0.deletedAt == nil }
        let sorted = todayEntries.sorted { $0.sortIndex < $1.sortIndex }
        XCTAssertEqual(sorted.map(\.title), ["第三项", "第二项", "第一项"])
        XCTAssertEqual(sorted.map(\.sortIndex), [0, 1, 2])
    }

    func testCorruptFileEntersErrorState() {
        try? Data("{ not-json".utf8).write(to: fileURL, options: .atomic)

        let store = makeStore()
        store.loadAndRollForward()

        if case .error = store.loadState {
            XCTAssertTrue(true)
        } else {
            XCTFail("expected error state")
        }
        XCTAssertFalse(store.canMutate)
    }
}
