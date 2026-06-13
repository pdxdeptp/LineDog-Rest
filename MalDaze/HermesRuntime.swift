import Darwin
import Foundation

struct HermesRuntimePaths: Sendable {
    var hermesHome: URL

    init(hermesHome: URL = Self.defaultHermesHome()) {
        self.hermesHome = hermesHome
    }

    static func defaultHermesHome() -> URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".hermes", isDirectory: true)
    }

    var scheduleScriptURL: URL {
        hermesHome.appendingPathComponent("scripts/schedule.py", isDirectory: false)
    }

    var learningProjectsFileURL: URL {
        hermesHome.appendingPathComponent("data/learning-assistant/projects.json", isDirectory: false)
    }

    var nutritionRecommendScriptURL: URL {
        hermesHome.appendingPathComponent("data/nutrition/recommend.py", isDirectory: false)
    }

    var nutritionDataDirectoryURL: URL {
        hermesHome.appendingPathComponent("data/nutrition", isDirectory: true)
    }
}

struct HermesProcessResult: Equatable, Sendable {
    let stdout: String
    let stderr: String
    let terminationStatus: Int32
    let timedOut: Bool
}

enum HermesProcessRunnerError: Error, Equatable {
    case missingExecutable(String)
    case missingScript(String)
}

struct HermesProcessRunner: Sendable {
    private let postTimeoutTerminationGraceSeconds: TimeInterval = 0.2

    func run(
        executablePath: String,
        scriptURL: URL,
        arguments: [String],
        environment: [String: String],
        timeoutSeconds: TimeInterval?
    ) async throws -> HermesProcessResult {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw HermesProcessRunnerError.missingExecutable(executablePath)
        }
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            throw HermesProcessRunnerError.missingScript(scriptURL.path)
        }

        var processEnvironment = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            processEnvironment[key] = value
        }

        let stdoutCapture = HermesPipeCapture()
        let stderrCapture = HermesPipeCapture()
        let runState = HermesProcessRunState(
            cancellationTerminationGraceSeconds: postTimeoutTerminationGraceSeconds
        )

        return try await withTaskCancellationHandler {
            let process = try spawnProcess(
                executablePath: executablePath,
                arguments: [scriptURL.path] + arguments,
                environment: processEnvironment,
                stdoutCapture: stdoutCapture,
                stderrCapture: stderrCapture
            )
            runState.setProcess(process)

            let timedOut: Bool
            do {
                timedOut = try await waitForExit(process, timeoutSeconds: timeoutSeconds)
                try Task.checkCancellation()
            } catch {
                runState.cancel()
                throw error
            }
            runState.finish(timedOut: timedOut)

            return HermesProcessResult(
                stdout: stdoutCapture.stringValue,
                stderr: stderrCapture.stringValue,
                terminationStatus: process.terminationStatus ?? -1,
                timedOut: timedOut
            )
        } onCancel: {
            runState.cancel()
        }
    }

    private func spawnProcess(
        executablePath: String,
        arguments: [String],
        environment: [String: String],
        stdoutCapture: HermesPipeCapture,
        stderrCapture: HermesPipeCapture
    ) throws -> HermesSpawnedProcess {
        var stdoutFDs = [Int32](repeating: 0, count: 2)
        var stderrFDs = [Int32](repeating: 0, count: 2)
        guard pipe(&stdoutFDs) == 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        guard pipe(&stderrFDs) == 0 else {
            close(stdoutFDs[0])
            close(stdoutFDs[1])
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }

        var fileActions: posix_spawn_file_actions_t? = nil
        var spawnAttributes: posix_spawnattr_t? = nil
        posix_spawn_file_actions_init(&fileActions)
        posix_spawnattr_init(&spawnAttributes)
        defer {
            posix_spawn_file_actions_destroy(&fileActions)
            posix_spawnattr_destroy(&spawnAttributes)
        }

        posix_spawn_file_actions_addclose(&fileActions, stdoutFDs[0])
        posix_spawn_file_actions_addclose(&fileActions, stderrFDs[0])
        posix_spawn_file_actions_adddup2(&fileActions, stdoutFDs[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, stderrFDs[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&fileActions, stdoutFDs[1])
        posix_spawn_file_actions_addclose(&fileActions, stderrFDs[1])
        // Start Hermes in its own process group so timeout/cancel can stop descendants too.
        posix_spawnattr_setflags(&spawnAttributes, Int16(POSIX_SPAWN_SETPGROUP))
        posix_spawnattr_setpgroup(&spawnAttributes, 0)

        var pid = pid_t()
        let spawnResult = executablePath.withCString { executablePathPointer in
            withCStringArray([executablePath] + arguments) { argumentPointers in
                withCStringArray(environment.map { "\($0)=\($1)" }) { environmentPointers in
                    var mutableArguments = argumentPointers
                    var mutableEnvironment = environmentPointers
                    return posix_spawn(
                        &pid,
                        executablePathPointer,
                        &fileActions,
                        &spawnAttributes,
                        &mutableArguments,
                        &mutableEnvironment
                    )
                }
            }
        }

        close(stdoutFDs[1])
        close(stderrFDs[1])
        guard spawnResult == 0 else {
            close(stdoutFDs[0])
            close(stderrFDs[0])
            throw POSIXError(.init(rawValue: spawnResult) ?? .EIO)
        }

        let stdoutHandle = FileHandle(fileDescriptor: stdoutFDs[0], closeOnDealloc: true)
        let stderrHandle = FileHandle(fileDescriptor: stderrFDs[0], closeOnDealloc: true)
        stdoutHandle.readabilityHandler = { handle in
            stdoutCapture.readAvailableData(from: handle)
        }
        stderrHandle.readabilityHandler = { handle in
            stderrCapture.readAvailableData(from: handle)
        }

        return HermesSpawnedProcess(
            pid: pid,
            stdoutHandle: stdoutHandle,
            stderrHandle: stderrHandle,
            stdoutCapture: stdoutCapture,
            stderrCapture: stderrCapture
        )
    }

    private func waitForExit(_ process: HermesSpawnedProcess, timeoutSeconds: TimeInterval?) async throws -> Bool {
        guard let timeoutSeconds else {
            while !process.pollExit() {
                try await Task.sleep(nanoseconds: 50_000_000)
            }
            return false
        }

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while !process.pollExit(), Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        guard process.isRunning else { return false }
        process.terminateProcessGroup(signal: SIGTERM)

        let terminateDeadline = Date().addingTimeInterval(postTimeoutTerminationGraceSeconds)
        while !process.pollExit(), Date() < terminateDeadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        process.terminateProcessGroup(signal: SIGKILL)

        let killDeadline = Date().addingTimeInterval(postTimeoutTerminationGraceSeconds)
        while !process.pollExit(), Date() < killDeadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        return true
    }

    private func withCStringArray<T>(
        _ strings: [String],
        _ body: ([UnsafeMutablePointer<CChar>?]) throws -> T
    ) rethrows -> T {
        var pointers = strings.map { strdup($0) }
        pointers.append(nil)
        defer {
            for pointer in pointers {
                free(pointer)
            }
        }
        return try body(pointers)
    }
}

private final class HermesPipeCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        guard !chunk.isEmpty else { return }
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    func readAvailableData(from handle: FileHandle) {
        lock.lock()
        let chunk = handle.availableData
        if !chunk.isEmpty {
            data.append(chunk)
        }
        lock.unlock()
    }

    func readRemainingData(from handle: FileHandle) {
        lock.lock()
        let chunk = handle.readDataToEndOfFile()
        if !chunk.isEmpty {
            data.append(chunk)
        }
        lock.unlock()
    }

    func close(_ handle: FileHandle) {
        lock.lock()
        try? handle.close()
        lock.unlock()
    }

    var stringValue: String {
        lock.lock()
        let snapshot = data
        lock.unlock()
        return String(data: snapshot, encoding: .utf8) ?? ""
    }
}

private final class HermesSpawnedProcess: @unchecked Sendable {
    let pid: pid_t
    private let stdoutHandle: FileHandle
    private let stderrHandle: FileHandle
    private let stdoutCapture: HermesPipeCapture
    private let stderrCapture: HermesPipeCapture
    private let lock = NSLock()
    private var exitStatus: Int32?
    private var cleanedUp = false

    init(
        pid: pid_t,
        stdoutHandle: FileHandle,
        stderrHandle: FileHandle,
        stdoutCapture: HermesPipeCapture,
        stderrCapture: HermesPipeCapture
    ) {
        self.pid = pid
        self.stdoutHandle = stdoutHandle
        self.stderrHandle = stderrHandle
        self.stdoutCapture = stdoutCapture
        self.stderrCapture = stderrCapture
    }

    var isRunning: Bool {
        lock.lock()
        let running = exitStatus == nil
        lock.unlock()
        return running
    }

    var terminationStatus: Int32? {
        lock.lock()
        let status = exitStatus
        lock.unlock()
        return status
    }

    @discardableResult
    func pollExit() -> Bool {
        lock.lock()
        if exitStatus != nil {
            lock.unlock()
            return true
        }
        lock.unlock()

        var status: Int32 = 0
        let result = waitpid(pid, &status, WNOHANG)
        guard result == pid else { return false }

        lock.lock()
        exitStatus = Self.decodeWaitStatus(status)
        lock.unlock()
        return true
    }

    func terminateProcessGroup(signal: Int32) {
        kill(-pid, signal)
    }

    func terminateProcessGroupThenKill(graceSeconds: TimeInterval) {
        terminateProcessGroup(signal: SIGTERM)
        waitForExitSynchronously(until: Date().addingTimeInterval(graceSeconds))
        terminateProcessGroup(signal: SIGKILL)
        waitForExitSynchronously(until: Date().addingTimeInterval(graceSeconds))
    }

    func cleanup(timedOut: Bool) {
        lock.lock()
        guard !cleanedUp else {
            lock.unlock()
            return
        }
        cleanedUp = true
        lock.unlock()

        stdoutHandle.readabilityHandler = nil
        stderrHandle.readabilityHandler = nil

        if !timedOut, !isRunning {
            stdoutCapture.readRemainingData(from: stdoutHandle)
            stderrCapture.readRemainingData(from: stderrHandle)
        } else {
            stdoutCapture.close(stdoutHandle)
            stderrCapture.close(stderrHandle)
        }
    }

    private static func decodeWaitStatus(_ status: Int32) -> Int32 {
        if status & 0x7f == 0 {
            return (status >> 8) & 0xff
        }
        return status & 0x7f
    }

    private func waitForExitSynchronously(until deadline: Date) {
        while isRunning, Date() < deadline {
            _ = pollExit()
            usleep(10_000)
        }
    }
}

private final class HermesProcessRunState: @unchecked Sendable {
    private let lock = NSLock()
    private var process: HermesSpawnedProcess?
    private var cancelled = false
    private let cancellationTerminationGraceSeconds: TimeInterval

    init(cancellationTerminationGraceSeconds: TimeInterval) {
        self.cancellationTerminationGraceSeconds = cancellationTerminationGraceSeconds
    }

    func setProcess(_ process: HermesSpawnedProcess) {
        lock.lock()
        let shouldCancel = cancelled
        self.process = process
        lock.unlock()

        if shouldCancel {
            cancel()
        }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let process = process
        lock.unlock()

        process?.terminateProcessGroupThenKill(graceSeconds: cancellationTerminationGraceSeconds)
        process?.cleanup(timedOut: true)
    }

    func finish(timedOut: Bool) {
        lock.lock()
        let process = process
        lock.unlock()

        process?.cleanup(timedOut: timedOut)
    }
}
