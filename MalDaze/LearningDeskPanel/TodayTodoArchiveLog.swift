import Foundation

enum TodayTodoArchiveAction: String, Codable {
    case add
    case updateTitle
    case toggleComplete
    case delete
    case restore
    case permanentDelete
    case reorder
    case rollForward
}

struct TodayTodoArchiveRecord: Codable, Equatable {
    var version: Int
    var recordedAt: Date
    var action: TodayTodoArchiveAction
    var entry: TodayTodoEntry?
    var previousTitle: String?
    var incompleteOrder: [UUID]?

    init(
        recordedAt: Date = Date(),
        action: TodayTodoArchiveAction,
        entry: TodayTodoEntry? = nil,
        previousTitle: String? = nil,
        incompleteOrder: [UUID]? = nil
    ) {
        version = 1
        self.recordedAt = recordedAt
        self.action = action
        self.entry = entry
        self.previousTitle = previousTitle
        self.incompleteOrder = incompleteOrder
    }
}

/// Append-only 本地存档：记录 todo 相关变更，不参与 UI 或 SSOT 读取。
struct TodayTodoArchiveLog {
    let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    static func defaultFileURL(beside stateFileURL: URL) -> URL {
        stateFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("today-todo-archive.jsonl", isDirectory: false)
    }

    mutating func append(_ record: TodayTodoArchiveRecord) {
        do {
            try appendThrowing(record)
        } catch {
            // 存档失败不阻塞主 todo 写入；留待后续排查。
        }
    }

    func appendThrowing(_ record: TodayTodoArchiveRecord) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var data = try encoder.encode(record)
        data.append(0x0A)

        if fileManager.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: fileURL, options: .atomic)
        }
    }
}
