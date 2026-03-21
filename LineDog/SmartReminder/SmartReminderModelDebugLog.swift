import Foundation

/// 将智能提醒每次请求的 system / user 与模型原始返回追加到日志文件，便于对照 EventKit 行为。
enum SmartReminderModelDebugLog {
    private static let fileName = "smart_reminder_model_debug.log"
    private static let lock = NSLock()
    private static let tsFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// 单测跑在同一进程时不写盘，避免污染本地调试日志。
    private static var shouldWrite: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    }

    /// 可通过环境变量覆盖路径（绝对路径或 `~/...`）。
    private static func logFileURL() -> URL? {
        guard shouldWrite else { return nil }
        if let env = ProcessInfo.processInfo.environment["LINEDOG_SMART_REMINDER_LOG_PATH"],
           !env.isEmpty {
            let expanded = (env as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded, isDirectory: false)
        }
        if let repoRoot = findDirectoryContainingXcodeProj(from: URL(fileURLWithPath: #filePath)) {
            return repoRoot.appendingPathComponent(fileName, isDirectory: false)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let base else { return nil }
        let dir = base.appendingPathComponent("LineDog", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName, isDirectory: false)
    }

    private static func findDirectoryContainingXcodeProj(from fileURL: URL) -> URL? {
        var dir = fileURL.deletingLastPathComponent()
        for _ in 0 ..< 20 {
            let proj = dir.appendingPathComponent("LineDog.xcodeproj", isDirectory: true)
            if FileManager.default.fileExists(atPath: proj.path) {
                return dir
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        return nil
    }

    static func appendExchange(systemPrompt: String, userText: String, modelRaw: String) {
        guard let url = logFileURL() else { return }
        let ts = tsFormatter.string(from: Date())
        let block = """
        ========== \(ts) ==========
        --- system ---
        \(systemPrompt)
        --- user ---
        \(userText)
        --- model raw ---
        \(modelRaw)


        """
        appendUTF8(block, to: url)
    }

    private static func appendUTF8(_ string: String, to url: URL) {
        guard let data = string.data(using: .utf8) else { return }
        lock.lock()
        defer { lock.unlock() }
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                let h = try FileHandle(forWritingTo: url)
                try h.seekToEnd()
                try h.write(contentsOf: data)
                try h.close()
            } else {
                try data.write(to: url, options: .atomic)
            }
        } catch {
            // 日志失败不影响主流程
        }
    }
}
