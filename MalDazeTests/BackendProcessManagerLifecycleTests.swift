import AppKit
import XCTest
@testable import MalDaze

@MainActor
final class BackendProcessManagerLifecycleTests: XCTestCase {
    func testSpawnedBackendReceivesParentPIDEnvironment() throws {
        let backendDir = try makeBackendDir()
        let process = RecordingBackendProcess()
        let manager = BackendProcessManager(
            backendDirectoryProvider: { backendDir },
            processFactory: { process },
            parentProcessIdentifierProvider: { 42 }
        )

        manager.spawnBackendForTesting()

        XCTAssertEqual(process.environment?["MALDAZE_PARENT_PID"], "42")
        XCTAssertTrue(process.didRun)
    }

    func testStopTerminatesAppOwnedChildProcess() throws {
        let backendDir = try makeBackendDir()
        let process = RecordingBackendProcess()
        let manager = BackendProcessManager(
            backendDirectoryProvider: { backendDir },
            processFactory: { process },
            parentProcessIdentifierProvider: { 42 }
        )
        manager.spawnBackendForTesting()

        manager.stop()

        XCTAssertTrue(process.didTerminate)
    }

    func testStopDoesNotTerminateExternalBackendWhenNoProcessIsOwned() {
        let process = RecordingBackendProcess()
        let manager = BackendProcessManager(
            backendDirectoryProvider: { nil },
            processFactory: { process },
            parentProcessIdentifierProvider: { 42 }
        )

        manager.stop()

        XCTAssertFalse(process.didTerminate)
    }

    func testAppDelegateTerminationStopsInjectedBackendManager() {
        let backend = RecordingAppBackendLifecycle()
        let delegate = MalDazeAppDelegate(backendLifecycle: backend)

        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))

        XCTAssertTrue(backend.didStop)
    }

    func testApplicationWillTerminateStopsBackendBeforeTerminationCleanup() {
        var events: [String] = []
        let backend = RecordingAppBackendLifecycle {
            events.append("backend")
        }
        let delegate = MalDazeAppDelegate(backendLifecycle: backend) {
            events.append("cleanup")
        }

        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))

        XCTAssertEqual(events, ["backend", "cleanup"])
    }

    private func makeBackendDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackendProcessManagerLifecycleTests-\(UUID().uuidString)")
        let uvicorn = root.appendingPathComponent(".venv/bin/uvicorn")
        try FileManager.default.createDirectory(
            at: uvicorn.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: uvicorn.path, contents: Data())
        return root
    }
}

private final class RecordingBackendProcess: BackendProcessControlling {
    var executableURL: URL?
    var arguments: [String]?
    var currentDirectoryURL: URL?
    var environment: [String: String]?

    var isRunning = true
    private(set) var didRun = false
    private(set) var didTerminate = false
    private var terminationHandler: (@MainActor @Sendable (BackendProcessControlling) -> Void)?

    func run() throws {
        didRun = true
    }

    func terminate() {
        didTerminate = true
        isRunning = false
        terminationHandler?(self)
    }

    func setTerminationHandler(_ handler: @escaping @MainActor @Sendable (BackendProcessControlling) -> Void) {
        terminationHandler = handler
    }
}

private final class RecordingAppBackendLifecycle: AppBackendLifecycleManaging {
    private(set) var didStart = false
    private(set) var didStop = false
    private let onStop: () -> Void

    init(onStop: @escaping () -> Void = {}) {
        self.onStop = onStop
    }

    func start() {
        didStart = true
    }

    func stop() {
        didStop = true
        onStop()
    }
}
