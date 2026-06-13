import CoreServices
import Foundation

final class FileChangeWatcher: @unchecked Sendable {
    private let directoryPath: String
    private let watchedFileName: String
    private let onFileChanged: () -> Void
    private var stream: FSEventStreamRef?

    init(fileURL: URL, onFileChanged: @escaping () -> Void) {
        directoryPath = fileURL.deletingLastPathComponent().path
        watchedFileName = fileURL.lastPathComponent
        self.onFileChanged = onFileChanged
    }

    deinit {
        stop()
    }

    func start() {
        guard stream == nil else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes
        )

        guard let created = FSEventStreamCreate(
            nil,
            FileChangeWatcher.eventCallback,
            &context,
            [directoryPath] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        ) else { return }

        stream = created
        FSEventStreamSetDispatchQueue(created, DispatchQueue.main)
        FSEventStreamStart(created)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    static func matchesWatchedFileEvent(
        watchedFileName: String,
        eventPath: String,
        eventFlags: FSEventStreamEventFlags
    ) -> Bool {
        guard URL(fileURLWithPath: eventPath).lastPathComponent == watchedFileName else {
            return false
        }

        let changed = eventFlags & UInt32(
            kFSEventStreamEventFlagItemModified
                | kFSEventStreamEventFlagItemCreated
                | kFSEventStreamEventFlagItemRenamed
        ) != 0
        return changed
    }

    func handleEventBatch(paths: [String], flags: [FSEventStreamEventFlags]) {
        for (path, eventFlags) in zip(paths, flags) {
            guard Self.matchesWatchedFileEvent(
                watchedFileName: watchedFileName,
                eventPath: path,
                eventFlags: eventFlags
            ) else { continue }

            onFileChanged()
            return
        }
    }

    private static let eventCallback: FSEventStreamCallback = { _, clientInfo, numEvents, eventPaths, eventFlags, _ in
        guard let clientInfo else { return }
        let watcher = Unmanaged<FileChangeWatcher>.fromOpaque(clientInfo).takeUnretainedValue()
        watcher.handleEvents(
            numEvents: numEvents,
            eventPaths: eventPaths,
            eventFlags: eventFlags
        )
    }

    private func handleEvents(
        numEvents: Int,
        eventPaths: UnsafeMutableRawPointer?,
        eventFlags: UnsafePointer<FSEventStreamEventFlags>?
    ) {
        guard let eventPaths, let eventFlags else { return }
        let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
        let flags = (0..<numEvents).map { eventFlags[$0] }
        handleEventBatch(paths: paths, flags: flags)
    }
}
