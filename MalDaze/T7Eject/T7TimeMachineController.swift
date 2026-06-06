import Foundation

struct T7TimeMachineStatus: Equatable {
    let isRunning: Bool
}

struct T7TimeMachineCommand: Equatable {
    let executablePath: String
    let arguments: [String]

    static func tmutil(_ arguments: [String]) -> T7TimeMachineCommand {
        T7TimeMachineCommand(executablePath: "/usr/bin/tmutil", arguments: arguments)
    }
}

struct T7TimeMachineCommandResult: Equatable {
    let stdout: String
    let stderr: String
    let terminationStatus: Int32
}

enum T7TimeMachineControllerError: Error, Equatable {
    case malformedStatusOutput
    case commandFailed(arguments: [String], status: Int32, stderr: String)
    case commandRunnerFailed(arguments: [String], description: String)
    case processTimedOut(arguments: [String], timeout: TimeInterval)
}

struct T7TimeMachinePreparationResult: Equatable {
    let canProceed: Bool
    let reason: T7EjectReason?
    let timeMachineWasRunning: Bool
    let timeMachineStopped: Bool
    let diagnostic: String?

    init(
        canProceed: Bool,
        reason: T7EjectReason?,
        timeMachineWasRunning: Bool,
        timeMachineStopped: Bool,
        diagnostic: String? = nil
    ) {
        self.canProceed = canProceed
        self.reason = reason
        self.timeMachineWasRunning = timeMachineWasRunning
        self.timeMachineStopped = timeMachineStopped
        self.diagnostic = diagnostic
    }
}

struct T7TimeMachineController {
    typealias CommandRunner = (T7TimeMachineCommand) async throws -> T7TimeMachineCommandResult
    typealias MonotonicClock = () -> TimeInterval
    typealias Sleeper = (TimeInterval) async -> Void

    private let commandRunner: CommandRunner
    private let monotonicNow: MonotonicClock
    private let sleep: Sleeper
    private let timeout: TimeInterval
    private let pollInterval: TimeInterval
    private let stabilityInterval: TimeInterval

    init(
        commandRunner: CommandRunner? = nil,
        monotonicNow: @escaping MonotonicClock = T7TimeMachineController.defaultMonotonicNow,
        sleep: @escaping Sleeper = T7TimeMachineController.defaultSleep,
        timeout: TimeInterval = 5 * 60,
        pollInterval: TimeInterval = 5,
        stabilityInterval: TimeInterval = 10,
        processTimeout: TimeInterval = 60
    ) {
        let resolvedProcessTimeout = Self.clampedProcessTimeout(processTimeout)
        self.commandRunner = commandRunner ?? { command in
            try await T7TimeMachineController.runProcess(command, timeout: resolvedProcessTimeout)
        }
        self.monotonicNow = monotonicNow
        self.sleep = sleep
        self.timeout = timeout
        self.pollInterval = Self.clampedPollInterval(pollInterval)
        self.stabilityInterval = stabilityInterval
    }

    static func parseStatus(from stdout: String) throws -> T7TimeMachineStatus {
        let pattern = #"\bRunning\s*=\s*([01])\s*;"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(stdout.startIndex..<stdout.endIndex, in: stdout)

        guard
            let match = regex.firstMatch(in: stdout, range: range),
            match.numberOfRanges == 2,
            let valueRange = Range(match.range(at: 1), in: stdout)
        else {
            throw T7TimeMachineControllerError.malformedStatusOutput
        }

        return T7TimeMachineStatus(isRunning: stdout[valueRange] == "1")
    }

    func status() async throws -> T7TimeMachineStatus {
        let result = try await runTMUtil(arguments: ["status"])
        return try Self.parseStatus(from: result.stdout)
    }

    func prepareForEject() async -> T7TimeMachinePreparationResult {
        var timeMachineWasRunning = false
        var timeMachineStopped = false

        do {
            let initialStatus = try await status()
            guard initialStatus.isRunning else {
                return T7TimeMachinePreparationResult(
                    canProceed: true,
                    reason: nil,
                    timeMachineWasRunning: false,
                    timeMachineStopped: false
                )
            }

            timeMachineWasRunning = true
            _ = try await runTMUtil(arguments: ["stopbackup"])

            let deadline = monotonicNow() + timeout
            while true {
                let polledStatus = try await status()
                if !polledStatus.isRunning {
                    timeMachineStopped = true
                    await sleep(stabilityInterval)
                    return T7TimeMachinePreparationResult(
                        canProceed: true,
                        reason: nil,
                        timeMachineWasRunning: true,
                        timeMachineStopped: true
                    )
                }

                let remaining = deadline - monotonicNow()
                guard remaining > 0 else {
                    return T7TimeMachinePreparationResult(
                        canProceed: false,
                        reason: .timeMachineStillRunning,
                        timeMachineWasRunning: true,
                        timeMachineStopped: false
                    )
                }

                await sleep(min(pollInterval, remaining))
            }
        } catch {
            return T7TimeMachinePreparationResult(
                canProceed: false,
                reason: .unexpectedError,
                timeMachineWasRunning: timeMachineWasRunning,
                timeMachineStopped: timeMachineStopped,
                diagnostic: Self.diagnosticDescription(for: error)
            )
        }
    }

    private func runTMUtil(arguments: [String]) async throws -> T7TimeMachineCommandResult {
        let command = T7TimeMachineCommand.tmutil(arguments)
        let result: T7TimeMachineCommandResult

        do {
            result = try await commandRunner(command)
        } catch let error as T7TimeMachineControllerError {
            throw error
        } catch {
            throw T7TimeMachineControllerError.commandRunnerFailed(
                arguments: arguments,
                description: String(describing: error)
            )
        }

        guard result.terminationStatus == 0 else {
            throw T7TimeMachineControllerError.commandFailed(
                arguments: arguments,
                status: result.terminationStatus,
                stderr: result.stderr
            )
        }

        return result
    }

    static func runProcess(
        _ command: T7TimeMachineCommand,
        timeout: TimeInterval = 60
    ) async throws -> T7TimeMachineCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executablePath)
        process.arguments = command.arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let box = T7TimeMachineProcessBox(
            command: command,
            process: process,
            stdoutPipe: stdoutPipe,
            stderrPipe: stderrPipe,
            timeout: clampedProcessTimeout(timeout)
        )
        return try await withTaskCancellationHandler {
            try await box.run()
        } onCancel: {
            box.cancel()
        }
    }

    private static func clampedPollInterval(_ interval: TimeInterval) -> TimeInterval {
        max(interval, 0.1)
    }

    private static func clampedProcessTimeout(_ timeout: TimeInterval) -> TimeInterval {
        max(timeout, 0.1)
    }

    private static func diagnosticDescription(for error: Error) -> String {
        switch error {
        case T7TimeMachineControllerError.malformedStatusOutput:
            return "Malformed Time Machine status output from tmutil status."
        case let T7TimeMachineControllerError.commandFailed(arguments, status, stderr):
            let command = (["tmutil"] + arguments).joined(separator: " ")
            let suffix = stderr.isEmpty ? "" : ": \(stderr)"
            return "\(command) failed with exit status \(status)\(suffix)"
        case let T7TimeMachineControllerError.commandRunnerFailed(arguments, description):
            let command = (["tmutil"] + arguments).joined(separator: " ")
            return "\(command) runner failed: \(description)"
        case let T7TimeMachineControllerError.processTimedOut(arguments, timeout):
            let command = (["tmutil"] + arguments).joined(separator: " ")
            return "\(command) timed out after \(timeout) seconds."
        default:
            return String(describing: error)
        }
    }

    private static func defaultMonotonicNow() -> TimeInterval {
        TimeInterval(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
    }

    private static func defaultSleep(_ interval: TimeInterval) async {
        guard interval > 0 else { return }
        let nanoseconds = UInt64((interval * 1_000_000_000).rounded())
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

private final class T7TimeMachineProcessBox: @unchecked Sendable {
    private typealias State = T7TimeMachineProcessBoxState<CheckedContinuation<T7TimeMachineCommandResult, Error>, Task<Void, Never>>

    private let command: T7TimeMachineCommand
    private let process: Process
    private let stdoutPipe: Pipe
    private let stderrPipe: Pipe
    private let timeout: TimeInterval
    private let state = State()

    init(
        command: T7TimeMachineCommand,
        process: Process,
        stdoutPipe: Pipe,
        stderrPipe: Pipe,
        timeout: TimeInterval
    ) {
        self.command = command
        self.process = process
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        self.timeout = timeout
    }

    func run() async throws -> T7TimeMachineCommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let timeoutTask = Task { [weak self] in
                guard let self else { return }
                let nanoseconds = UInt64((timeout * 1_000_000_000).rounded())
                try? await Task.sleep(nanoseconds: nanoseconds)
                finishWithTimeout()
            }

            let startOutcome = state.installAndStart(
                continuation: continuation,
                timeoutTask: timeoutTask
            ) {
                process.terminationHandler = { [weak self] _ in
                    self?.finishWithProcessResult()
                }
                try process.run()
            }

            switch startOutcome {
            case .started:
                break
            case let .cancelled(action):
                complete(action, with: .failure(CancellationError()))
            case let .failed(action, error):
                complete(action, with: .failure(error))
            }
        }
    }

    func cancel() {
        let action = state.cancel()
        if action.shouldTerminateProcess {
            process.terminate()
        }
        complete(action, with: .failure(CancellationError()))
    }

    private func finishWithTimeout() {
        let action = state.finish(shouldTerminateProcess: true)
        if action.shouldTerminateProcess {
            process.terminate()
        }
        complete(action, with: .failure(T7TimeMachineControllerError.processTimedOut(
            arguments: command.arguments,
            timeout: timeout
        )))
    }

    private func finishWithProcessResult() {
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        finish(.success(T7TimeMachineCommandResult(
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            terminationStatus: process.terminationStatus
        )), shouldTerminateProcess: false)
    }

    private func finish(
        _ result: Result<T7TimeMachineCommandResult, Error>,
        shouldTerminateProcess: Bool
    ) {
        let action = state.finish(shouldTerminateProcess: shouldTerminateProcess)
        if action.shouldTerminateProcess {
            process.terminate()
        }
        complete(action, with: result)
    }

    private func complete(
        _ action: State.FinishAction,
        with result: Result<T7TimeMachineCommandResult, Error>
    ) {
        action.timeoutTask?.cancel()
        action.continuation?.resume(with: result)
    }
}

final class T7TimeMachineProcessBoxState<Continuation, TimeoutTask>: @unchecked Sendable {
    struct FinishAction {
        let continuation: Continuation?
        let timeoutTask: TimeoutTask?
        let shouldTerminateProcess: Bool
    }

    enum StartOutcome {
        case started
        case cancelled(FinishAction)
        case failed(FinishAction, Error)
    }

    private let lock = NSLock()
    private var continuation: Continuation?
    private var timeoutTask: TimeoutTask?
    private var hasFinished = false
    private var hasPendingCancellation = false
    private var hasStartedProcess = false

    init() {}

    func installAndStart(
        continuation: Continuation,
        timeoutTask: TimeoutTask?,
        start: () throws -> Void
    ) -> StartOutcome {
        lock.lock()
        guard !hasFinished else {
            let action = FinishAction(
                continuation: continuation,
                timeoutTask: timeoutTask,
                shouldTerminateProcess: false
            )
            lock.unlock()
            return .cancelled(action)
        }

        guard !hasPendingCancellation else {
            hasFinished = true
            let action = FinishAction(
                continuation: continuation,
                timeoutTask: timeoutTask,
                shouldTerminateProcess: false
            )
            lock.unlock()
            return .cancelled(action)
        }

        self.continuation = continuation
        self.timeoutTask = timeoutTask
        do {
            try start()
            hasStartedProcess = true
            lock.unlock()
            return .started
        } catch {
            hasFinished = true
            let action = consumeLocked(shouldTerminateProcess: false)
            lock.unlock()
            return .failed(action, error)
        }
    }

    func cancel() -> FinishAction {
        lock.lock()
        guard !hasFinished else {
            lock.unlock()
            return .empty
        }

        guard continuation != nil else {
            hasPendingCancellation = true
            lock.unlock()
            return .empty
        }

        hasFinished = true
        let action = consumeLocked(shouldTerminateProcess: hasStartedProcess)
        lock.unlock()
        return action
    }

    func finish(shouldTerminateProcess: Bool = false) -> FinishAction {
        lock.lock()
        guard !hasFinished else {
            lock.unlock()
            return .empty
        }

        hasFinished = true
        let action = consumeLocked(shouldTerminateProcess: shouldTerminateProcess && hasStartedProcess)
        lock.unlock()
        return action
    }

    private func consumeLocked(shouldTerminateProcess: Bool) -> FinishAction {
        let action = FinishAction(
            continuation: continuation,
            timeoutTask: timeoutTask,
            shouldTerminateProcess: shouldTerminateProcess
        )
        continuation = nil
        timeoutTask = nil
        return action
    }
}

private extension T7TimeMachineProcessBoxState.FinishAction {
    static var empty: Self {
        Self(continuation: nil, timeoutTask: nil, shouldTerminateProcess: false)
    }
}
