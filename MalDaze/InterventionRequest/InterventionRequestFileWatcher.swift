import CoreServices
import Foundation

/// 监听 `intervention_request.json` 所在目录。
final class InterventionRequestFileWatcher: @unchecked Sendable {
    private let directoryPath: String
    private let watchedFileName: String
    private let onFileChanged: () -> Void
    private var stream: FSEventStreamRef?

    init(
        fileURL: URL = InterventionRequestContractReader.defaultHermesPendingFileURL,
        onFileChanged: @escaping () -> Void
    ) {
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
            InterventionRequestFileWatcher.eventCallback,
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

    private static let eventCallback: FSEventStreamCallback = { _, clientInfo, numEvents, eventPaths, eventFlags, _ in
        guard let clientInfo else { return }
        let watcher = Unmanaged<InterventionRequestFileWatcher>.fromOpaque(clientInfo).takeUnretainedValue()
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

        for index in 0..<numEvents {
            let path = paths[index]
            guard URL(fileURLWithPath: path).lastPathComponent == watchedFileName else { continue }

            let flags = eventFlags[index]
            let changed = flags & UInt32(
                kFSEventStreamEventFlagItemModified
                    | kFSEventStreamEventFlagItemCreated
                    | kFSEventStreamEventFlagItemRenamed
            ) != 0
            guard changed else { continue }

            onFileChanged()
            return
        }
    }
}
