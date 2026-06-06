import XCTest
@testable import MalDaze

final class T7TimeMachineControllerTests: XCTestCase {
    func testParsesRunningZeroStatus() throws {
        let status = try T7TimeMachineController.parseStatus(from: """
        Backup session status:
        {
            Running = 0;
        }
        """)

        XCTAssertEqual(status, T7TimeMachineStatus(isRunning: false))
    }

    func testParsesRunningOneStatus() throws {
        let status = try T7TimeMachineController.parseStatus(from: """
        Backup session status:
        {
            Running = 1;
        }
        """)

        XCTAssertEqual(status, T7TimeMachineStatus(isRunning: true))
    }

    func testMalformedStatusOutputThrows() {
        XCTAssertThrowsError(try T7TimeMachineController.parseStatus(from: "Backup session status: { Phase = Copying; }")) { error in
            XCTAssertEqual(error as? T7TimeMachineControllerError, .malformedStatusOutput)
        }
    }

    func testStatusCommandFailureThrows() async {
        let runner = RecordingTimeMachineRunner(
            results: [
                .init(stdout: "", stderr: "tmutil failed", terminationStatus: 72),
            ]
        )
        let controller = T7TimeMachineController(commandRunner: runner.run)

        do {
            _ = try await controller.status()
            XCTFail("Expected tmutil status failure to throw.")
        } catch {
            XCTAssertEqual(
                error as? T7TimeMachineControllerError,
                .commandFailed(arguments: ["status"], status: 72, stderr: "tmutil failed")
            )
        }
    }

    func testPrepareForEjectIncludesDiagnosticWhenStatusParsingFails() async {
        let runner = RecordingTimeMachineRunner(
            results: [
                .init(stdout: "Backup session status: { Phase = Copying; }", stderr: "", terminationStatus: 0),
            ]
        )
        let controller = T7TimeMachineController(commandRunner: runner.run)

        let result = await controller.prepareForEject()

        XCTAssertFalse(result.canProceed)
        XCTAssertEqual(result.reason, .unexpectedError)
        XCTAssertEqual(result.timeMachineWasRunning, false)
        XCTAssertEqual(result.timeMachineStopped, false)
        XCTAssertEqual(result.diagnostic, "Malformed Time Machine status output from tmutil status.")
    }

    func testPrepareForEjectClampsNonPositivePollInterval() async {
        let runner = RecordingTimeMachineRunner(
            results: [
                .runningStatus,
                .successfulStopBackup,
                .runningStatus,
                .idleStatus,
            ]
        )
        let sleeper = NonBlockingTimeMachineSleeper()
        let controller = T7TimeMachineController(
            commandRunner: runner.run,
            monotonicNow: sleeper.now,
            sleep: sleeper.sleep,
            timeout: 2,
            pollInterval: 0,
            stabilityInterval: 0.5
        )

        let result = await controller.prepareForEject()

        XCTAssertTrue(result.canProceed)
        XCTAssertEqual(sleeper.intervals, [0.1, 0.5])
    }

    func testRunProcessTimesOutAndTerminatesLongRunningCommand() async {
        let startedAt = Date()

        do {
            _ = try await T7TimeMachineController.runProcess(
                T7TimeMachineCommand(executablePath: "/bin/sleep", arguments: ["2"]),
                timeout: 0.1
            )
            XCTFail("Expected long-running process to time out.")
        } catch {
            XCTAssertEqual(
                error as? T7TimeMachineControllerError,
                .processTimedOut(arguments: ["2"], timeout: 0.1)
            )
            XCTAssertLessThan(Date().timeIntervalSince(startedAt), 1.5)
        }
    }

    func testRunProcessUsesAsyncTerminationHandlerInsteadOfBlockingWait() throws {
        let source = try Self.productionSource(at: "MalDaze/T7Eject/T7TimeMachineController.swift")

        XCTAssertFalse(source.contains("waitUntilExit()"))
        XCTAssertTrue(source.contains("terminationHandler"))
        XCTAssertTrue(source.contains(".terminate()"))
    }

    func testProcessBoxStateDefersCancellationUntilContinuationIsInstalled() throws {
        let state = T7TimeMachineProcessBoxState<String, String>()

        let pendingCancelAction = state.cancel()
        XCTAssertNil(pendingCancelAction.continuation)
        XCTAssertNil(pendingCancelAction.timeoutTask)
        XCTAssertFalse(pendingCancelAction.shouldTerminateProcess)

        var didStartProcess = false
        let startOutcome = state.installAndStart(
            continuation: "continuation",
            timeoutTask: "timeout"
        ) {
            didStartProcess = true
        }

        guard case let .cancelled(action) = startOutcome else {
            return XCTFail("Expected pending cancellation to resume after continuation installation.")
        }
        XCTAssertEqual(action.continuation, "continuation")
        XCTAssertEqual(action.timeoutTask, "timeout")
        XCTAssertFalse(action.shouldTerminateProcess)
        XCTAssertFalse(didStartProcess)
    }

    func testProcessBoxStateFinishesWithInstalledContinuationAndTimeoutAfterFastStart() throws {
        let state = T7TimeMachineProcessBoxState<String, String>()

        let startOutcome = state.installAndStart(
            continuation: "continuation",
            timeoutTask: "timeout"
        ) {}

        guard case .started = startOutcome else {
            return XCTFail("Expected process start to succeed.")
        }

        let finishAction = state.finish()
        XCTAssertEqual(finishAction.continuation, "continuation")
        XCTAssertEqual(finishAction.timeoutTask, "timeout")
        XCTAssertFalse(finishAction.shouldTerminateProcess)

        let duplicateFinishAction = state.finish()
        XCTAssertNil(duplicateFinishAction.continuation)
        XCTAssertNil(duplicateFinishAction.timeoutTask)
        XCTAssertFalse(duplicateFinishAction.shouldTerminateProcess)
    }

    func testPrepareForEjectTimesOutWhenTimeMachineKeepsRunning() async {
        let runner = RecordingTimeMachineRunner(
            results: [
                .runningStatus,
                .successfulStopBackup,
                .runningStatus,
                .runningStatus,
                .runningStatus,
            ]
        )
        let sleeper = RecordingTimeMachineSleeper()
        let controller = T7TimeMachineController(
            commandRunner: runner.run,
            monotonicNow: sleeper.now,
            sleep: sleeper.sleep,
            timeout: 2,
            pollInterval: 1,
            stabilityInterval: 0.5
        )

        let result = await controller.prepareForEject()

        XCTAssertEqual(
            result,
            T7TimeMachinePreparationResult(
                canProceed: false,
                reason: .timeMachineStillRunning,
                timeMachineWasRunning: true,
                timeMachineStopped: false
            )
        )
        XCTAssertEqual(runner.commandArguments, [["status"], ["stopbackup"], ["status"], ["status"], ["status"]])
        XCTAssertEqual(sleeper.intervals, [1, 1])
    }

    func testPrepareForEjectStopsBackupBeforeStabilityWait() async {
        let runner = RecordingTimeMachineRunner(
            results: [
                .runningStatus,
                .successfulStopBackup,
                .runningStatus,
                .idleStatus,
            ]
        )
        let eventLog = RecordingTimeMachineEventLog()
        let sleeper = RecordingTimeMachineSleeper(eventLog: eventLog)
        let controller = T7TimeMachineController(
            commandRunner: { command in
                eventLog.append("command:\(command.arguments.joined(separator: " "))")
                return try await runner.run(command)
            },
            monotonicNow: sleeper.now,
            sleep: sleeper.sleep,
            timeout: 5,
            pollInterval: 1,
            stabilityInterval: 0.5
        )

        let result = await controller.prepareForEject()

        XCTAssertEqual(
            result,
            T7TimeMachinePreparationResult(
                canProceed: true,
                reason: nil,
                timeMachineWasRunning: true,
                timeMachineStopped: true
            )
        )
        XCTAssertEqual(
            eventLog.events,
            [
                "command:status",
                "command:stopbackup",
                "command:status",
                "sleep:1.0",
                "command:status",
                "sleep:0.5",
            ]
        )
    }

    func testPrepareForEjectSkipsStopBackupWhenTimeMachineIsIdle() async {
        let runner = RecordingTimeMachineRunner(results: [.idleStatus])
        let sleeper = RecordingTimeMachineSleeper()
        let controller = T7TimeMachineController(
            commandRunner: runner.run,
            monotonicNow: sleeper.now,
            sleep: sleeper.sleep,
            timeout: 5,
            pollInterval: 1,
            stabilityInterval: 0.5
        )

        let result = await controller.prepareForEject()

        XCTAssertEqual(
            result,
            T7TimeMachinePreparationResult(
                canProceed: true,
                reason: nil,
                timeMachineWasRunning: false,
                timeMachineStopped: false
            )
        )
        XCTAssertEqual(runner.commandArguments, [["status"]])
        XCTAssertEqual(sleeper.intervals, [])
    }

    private static func productionSource(at relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

private final class RecordingTimeMachineRunner {
    private var results: [T7TimeMachineCommandResult]
    private(set) var commandArguments: [[String]] = []

    init(results: [T7TimeMachineCommandResult]) {
        self.results = results
    }

    func run(_ command: T7TimeMachineCommand) async throws -> T7TimeMachineCommandResult {
        commandArguments.append(command.arguments)
        guard !results.isEmpty else {
            XCTFail("Unexpected Time Machine command: \(command)")
            return .init(stdout: "", stderr: "unexpected command", terminationStatus: 99)
        }

        return results.removeFirst()
    }
}

private final class RecordingTimeMachineSleeper {
    private let eventLog: RecordingTimeMachineEventLog?
    private(set) var currentTime: TimeInterval = 0
    private(set) var intervals: [TimeInterval] = []

    init(eventLog: RecordingTimeMachineEventLog? = nil) {
        self.eventLog = eventLog
    }

    func now() -> TimeInterval {
        currentTime
    }

    func sleep(_ interval: TimeInterval) async {
        intervals.append(interval)
        eventLog?.append(String(format: "sleep:%.1f", interval))
        currentTime += interval
    }
}

private final class NonBlockingTimeMachineSleeper {
    private(set) var currentTime: TimeInterval = 0
    private(set) var intervals: [TimeInterval] = []

    func now() -> TimeInterval {
        currentTime
    }

    func sleep(_ interval: TimeInterval) async {
        intervals.append(interval)
        currentTime += max(interval, 0.1)
    }
}

private final class RecordingTimeMachineEventLog {
    private(set) var events: [String] = []

    func append(_ event: String) {
        events.append(event)
    }
}

private extension T7TimeMachineCommandResult {
    static let idleStatus = T7TimeMachineCommandResult(
        stdout: "Backup session status:\n{\n    Running = 0;\n}\n",
        stderr: "",
        terminationStatus: 0
    )

    static let runningStatus = T7TimeMachineCommandResult(
        stdout: "Backup session status:\n{\n    Running = 1;\n}\n",
        stderr: "",
        terminationStatus: 0
    )

    static let successfulStopBackup = T7TimeMachineCommandResult(
        stdout: "",
        stderr: "",
        terminationStatus: 0
    )
}
