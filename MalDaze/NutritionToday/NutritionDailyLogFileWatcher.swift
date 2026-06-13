import Foundation

/// 监听 Hermes `daily_log.json` 所在目录；文件变更时回调。
final class NutritionDailyLogFileWatcher: @unchecked Sendable {
    private let watcher: FileChangeWatcher

    init(
        fileURL: URL = NutritionDailyLogContractReader.defaultHermesFileURL,
        onFileChanged: @escaping () -> Void
    ) {
        watcher = FileChangeWatcher(fileURL: fileURL, onFileChanged: onFileChanged)
    }

    deinit {
        stop()
    }

    func start() {
        watcher.start()
    }

    func stop() {
        watcher.stop()
    }
}
