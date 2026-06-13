import CoreServices
import XCTest
@testable import MalDaze

final class FileChangeWatcherTests: XCTestCase {
    func testWatchedFileChangeMatchesOnlyTargetFilenameAndChangeFlags() {
        let watchedFileName = "daily_log.json"

        XCTAssertTrue(FileChangeWatcher.matchesWatchedFileEvent(
            watchedFileName: watchedFileName,
            eventPath: "/tmp/hermes/daily_log.json",
            eventFlags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified)
        ))
        XCTAssertTrue(FileChangeWatcher.matchesWatchedFileEvent(
            watchedFileName: watchedFileName,
            eventPath: "/tmp/hermes/daily_log.json",
            eventFlags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated)
        ))
        XCTAssertTrue(FileChangeWatcher.matchesWatchedFileEvent(
            watchedFileName: watchedFileName,
            eventPath: "/tmp/hermes/daily_log.json",
            eventFlags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed)
        ))

        XCTAssertFalse(FileChangeWatcher.matchesWatchedFileEvent(
            watchedFileName: watchedFileName,
            eventPath: "/tmp/hermes/recommendation.json",
            eventFlags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified)
        ))
        XCTAssertFalse(FileChangeWatcher.matchesWatchedFileEvent(
            watchedFileName: watchedFileName,
            eventPath: "/tmp/hermes/daily_log.json",
            eventFlags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved)
        ))
    }

    func testEventBatchInvokesCallbackOnceForFirstMatchingChange() {
        var callbackCount = 0
        let watcher = FileChangeWatcher(
            fileURL: URL(fileURLWithPath: "/tmp/hermes/projects.json"),
            onFileChanged: { callbackCount += 1 }
        )

        watcher.handleEventBatch(
            paths: [
                "/tmp/hermes/other.json",
                "/tmp/hermes/projects.json",
                "/tmp/hermes/projects.json"
            ],
            flags: [
                FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified),
                FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated),
                FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed)
            ]
        )

        XCTAssertEqual(callbackCount, 1)
    }

    func testDomainWatchersDelegateFSEventsLifecycleToSharedWatcher() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("MalDaze")

        let watcherPaths = [
            "LearningDeskPanel/LearningProjectsFileWatcher.swift",
            "SleepReminder/SleepScheduleFileWatcher.swift",
            "NutritionToday/NutritionDailyLogFileWatcher.swift",
            "InterventionRequest/InterventionRequestFileWatcher.swift"
        ]

        for watcherPath in watcherPaths {
            let source = try String(contentsOf: sourceRoot.appendingPathComponent(watcherPath))
            XCTAssertTrue(source.contains("FileChangeWatcher"), watcherPath)
            XCTAssertFalse(source.contains("FSEventStreamCreate"), watcherPath)
            XCTAssertFalse(source.contains("FSEventStreamRef"), watcherPath)
        }
    }
}
