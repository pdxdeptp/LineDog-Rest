import Foundation

/// 监听 Hermes `sleep_schedule.json` 所在目录；文件变更时回调（非轮询）。
final class SleepScheduleFileWatcher: @unchecked Sendable {
    private let watcher: FileChangeWatcher

    init(
        fileURL: URL = SleepScheduleContractReader.defaultHermesFileURL,
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
