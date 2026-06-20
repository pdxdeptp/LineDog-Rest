import XCTest
@testable import MalDaze

@MainActor
final class TodayTodoStoreTests: XCTestCase {
    private var fileURL: URL!
    private var todayISO: String!

    override func setUp() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TodayTodoStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("today-todo.json")
        todayISO = "2026-06-18"
    }

    override func tearDown() async throws {
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }
    }

    private func makeStore() -> TodayTodoStore {
        TodayTodoStore(fileURL: fileURL, todayISO: { [unowned self] in self.todayISO })
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
