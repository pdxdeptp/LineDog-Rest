import Foundation

/// 监听 `intervention_request.json` 所在目录。
final class InterventionRequestFileWatcher: @unchecked Sendable {
    private let watcher: FileChangeWatcher

    init(
        fileURL: URL = InterventionRequestContractReader.defaultHermesPendingFileURL,
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
