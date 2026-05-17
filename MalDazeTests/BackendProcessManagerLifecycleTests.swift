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

    func testApplicationDidFinishLaunchingDoesNotStartAssistantBackend() throws {
        let backend = RecordingAppBackendLifecycle()
        let (defaults, suiteName) = try makeIsolatedDefaults()
        let delegate = MalDazeAppDelegate(backendLifecycle: backend, userDefaults: defaults)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        }

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        XCTAssertFalse(backend.didStart)
    }

    func testApplicationDidFinishLaunchingStartsAssistantBackendWhenLazyStartupDisabled() throws {
        let backend = RecordingAppBackendLifecycle()
        let (defaults, suiteName) = try makeIsolatedDefaults()
        let delegate = MalDazeAppDelegate(backendLifecycle: backend, userDefaults: defaults)
        defaults.set(false, forKey: MalDazeDefaults.assistantBackendLazyStartupEnabled)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        }

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        XCTAssertEqual(backend.startIfNeededCallCount, 1)
    }

    func testStartupTimeoutDoesNotMarkBackendReady() async throws {
        let backendDir = try makeBackendDir()
        let process = RecordingBackendProcess()
        let manager = BackendProcessManager(
            backendDirectoryProvider: { backendDir },
            processFactory: { process },
            parentProcessIdentifierProvider: { 42 },
            portBoundProbe: { false },
            readinessTimeout: 0.01,
            readinessPollNanoseconds: 1_000_000
        )

        manager.startIfNeeded()
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(process.didRun)
        XCTAssertFalse(manager.isReady)
        XCTAssertFalse(manager.isStarting)
    }

    func testStartupFailureClearsStartingStateAndAllowsRetry() async throws {
        let backendDir = try makeBackendDir()
        let firstProcess = RecordingBackendProcess(runError: TestBackendRunError())
        let secondProcess = RecordingBackendProcess(runError: TestBackendRunError())
        var processes = [firstProcess, secondProcess]
        let manager = BackendProcessManager(
            backendDirectoryProvider: { backendDir },
            processFactory: { processes.removeFirst() },
            parentProcessIdentifierProvider: { 42 },
            portBoundProbe: { false },
            readinessTimeout: 0.01,
            readinessPollNanoseconds: 1_000_000
        )

        manager.startIfNeeded()
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(firstProcess.didRun)
        XCTAssertFalse(manager.isReady)
        XCTAssertFalse(manager.isStarting)

        manager.startIfNeeded()
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(secondProcess.didRun)
        XCTAssertFalse(manager.isReady)
        XCTAssertFalse(manager.isStarting)
    }

    func testStopInvalidatesPendingStartupProbeBeforeItCanSpawnBackend() async throws {
        let backendDir = try makeBackendDir()
        let process = RecordingBackendProcess()
        let didBecomeReady = expectation(forNotification: .backendDidBecomeReady, object: nil)
        didBecomeReady.isInverted = true
        let manager = BackendProcessManager(
            backendDirectoryProvider: { backendDir },
            processFactory: { process },
            parentProcessIdentifierProvider: { 42 },
            portBoundProbe: {
                try? await Task.sleep(nanoseconds: 25_000_000)
                return false
            },
            readinessTimeout: 0.01,
            readinessPollNanoseconds: 1_000_000
        )

        manager.startIfNeeded()
        manager.stop()
        await fulfillment(of: [didBecomeReady], timeout: 0.1)

        XCTAssertFalse(process.didRun)
        XCTAssertFalse(manager.isReady)
        XCTAssertFalse(manager.isStarting)
    }

    func testOldProcessTerminationCallbackAfterRestartDoesNotClearNewBackendState() async throws {
        let backendDir = try makeBackendDir()
        let oldProcess = RecordingBackendProcess(firesTerminationOnTerminate: false)
        let newProcess = RecordingBackendProcess()
        var processes = [oldProcess, newProcess]
        var probeResults = [false, true]
        let didBecomeUnavailable = expectation(forNotification: .backendDidBecomeUnavailable, object: nil)
        didBecomeUnavailable.isInverted = true
        let manager = BackendProcessManager(
            backendDirectoryProvider: { backendDir },
            processFactory: { processes.removeFirst() },
            parentProcessIdentifierProvider: { 42 },
            portBoundProbe: { probeResults.removeFirst() },
            readinessTimeout: 0.05,
            readinessPollNanoseconds: 1_000_000
        )

        manager.spawnBackendForTesting()
        manager.stop()
        manager.startIfNeeded()
        try await Task.sleep(nanoseconds: 50_000_000)
        oldProcess.fireTerminationHandler()
        await fulfillment(of: [didBecomeUnavailable], timeout: 0.1)

        XCTAssertTrue(oldProcess.didTerminate)
        XCTAssertTrue(newProcess.didRun)
        XCTAssertTrue(manager.isReady)
        XCTAssertFalse(manager.isStarting)

        manager.stop()

        XCTAssertTrue(newProcess.didTerminate)
    }

    func testRestartWhileOwnedProcessStillBoundDoesNotTreatOldPortAsExternalBackend() async throws {
        let backendDir = try makeBackendDir()
        let oldProcess = RecordingBackendProcess(firesTerminationOnTerminate: false)
        let newProcess = RecordingBackendProcess()
        var processes = [oldProcess, newProcess]
        var probeResults = [true, false, true]
        let manager = BackendProcessManager(
            backendDirectoryProvider: { backendDir },
            processFactory: { processes.removeFirst() },
            parentProcessIdentifierProvider: { 42 },
            portBoundProbe: { probeResults.removeFirst() },
            readinessTimeout: 0.05,
            readinessPollNanoseconds: 1_000_000
        )

        manager.spawnBackendForTesting()
        manager.stop()
        manager.startIfNeeded()
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertTrue(oldProcess.didTerminate)
        XCTAssertFalse(newProcess.didRun)
        XCTAssertFalse(manager.isReady)
        XCTAssertTrue(manager.isStarting)

        oldProcess.fireTerminationHandler()
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(newProcess.didRun)
        XCTAssertTrue(manager.isReady)
        XCTAssertFalse(manager.isStarting)

        manager.stop()

        XCTAssertTrue(newProcess.didTerminate)
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

    private func makeIsolatedDefaults() throws -> (UserDefaults, String) {
        let suiteName = "BackendProcessManagerLifecycleTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
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
    private let runError: Error?
    private let firesTerminationOnTerminate: Bool

    init(runError: Error? = nil, firesTerminationOnTerminate: Bool = true) {
        self.runError = runError
        self.firesTerminationOnTerminate = firesTerminationOnTerminate
    }

    func run() throws {
        didRun = true
        if let runError { throw runError }
    }

    func terminate() {
        didTerminate = true
        isRunning = false
        if firesTerminationOnTerminate {
            fireTerminationHandler()
        }
    }

    func fireTerminationHandler() {
        terminationHandler?(self)
    }

    func setTerminationHandler(_ handler: @escaping @MainActor @Sendable (BackendProcessControlling) -> Void) {
        terminationHandler = handler
    }
}

private struct TestBackendRunError: Error {}

private final class RecordingAppBackendLifecycle: AppBackendLifecycleManaging {
    var isReady = false
    var isStarting = false

    var didStart: Bool { startIfNeededCallCount > 0 }
    private(set) var startIfNeededCallCount = 0
    private(set) var didStop = false
    private let onStop: () -> Void

    init(onStop: @escaping () -> Void = {}) {
        self.onStop = onStop
    }

    func startIfNeeded() {
        guard !isReady, !isStarting else { return }
        isStarting = true
        startIfNeededCallCount += 1
    }

    func stop() {
        didStop = true
        onStop()
    }
}
