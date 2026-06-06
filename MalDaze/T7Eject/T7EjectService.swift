import Combine
import Foundation

struct T7EjectProcessOutput: Equatable {
    let terminationStatus: Int32
    let stdout: Data
    let stderr: String
}

@MainActor
protocol T7EjectProcessRunning: AnyObject {
    func run(executableURL: URL) async throws -> T7EjectProcessOutput
    func cancel()
}

protocol T7EjectServiceClock {
    func currentDate() -> Date
}

struct T7EjectSystemServiceClock: T7EjectServiceClock {
    func currentDate() -> Date {
        Date()
    }
}

struct T7EjectScheduleConfiguration: Equatable {
    static let `default` = T7EjectScheduleConfiguration(
        startMinuteOfDay: 20 * 60,
        endMinuteOfDay: 23 * 60 + 45,
        retryIntervalSeconds: 15 * 60
    )

    let startMinuteOfDay: Int
    let endMinuteOfDay: Int
    let retryIntervalSeconds: Int

    init(startMinuteOfDay: Int, endMinuteOfDay: Int, retryIntervalSeconds: Int) {
        let clampedStart = min(max(startMinuteOfDay, 0), 23 * 60 + 59)
        let clampedEnd = min(max(endMinuteOfDay, 0), 23 * 60 + 59)
        self.startMinuteOfDay = clampedStart
        self.endMinuteOfDay = max(clampedEnd, clampedStart)
        self.retryIntervalSeconds = max(retryIntervalSeconds, 60)
    }

    static func resolved(defaults: UserDefaults) -> T7EjectScheduleConfiguration {
        let fallback = Self.default
        return T7EjectScheduleConfiguration(
            startMinuteOfDay: defaults.object(forKey: MalDazeDefaults.t7EjectScheduleStartMinuteOfDay) as? Int
                ?? fallback.startMinuteOfDay,
            endMinuteOfDay: defaults.object(forKey: MalDazeDefaults.t7EjectScheduleEndMinuteOfDay) as? Int
                ?? fallback.endMinuteOfDay,
            retryIntervalSeconds: defaults.object(forKey: MalDazeDefaults.t7EjectRetryIntervalSeconds) as? Int
                ?? fallback.retryIntervalSeconds
        )
    }

    func persist(to defaults: UserDefaults) {
        defaults.set(startMinuteOfDay, forKey: MalDazeDefaults.t7EjectScheduleStartMinuteOfDay)
        defaults.set(endMinuteOfDay, forKey: MalDazeDefaults.t7EjectScheduleEndMinuteOfDay)
        defaults.set(retryIntervalSeconds, forKey: MalDazeDefaults.t7EjectRetryIntervalSeconds)
    }
}

struct T7EjectSchedulePolicy {
    let configuration: T7EjectScheduleConfiguration
    let calendar: Calendar

    init(configuration: T7EjectScheduleConfiguration, calendar: Calendar = .current) {
        self.configuration = configuration
        self.calendar = calendar
    }

    func isEligible(
        now: Date,
        isAutomaticEnabled: Bool,
        completedDayToken: String?,
        lastAttemptDate: Date?
    ) -> Bool {
        guard isAutomaticEnabled else {
            return false
        }
        guard isInsideWindow(now) else {
            return false
        }
        guard completedDayToken != dayToken(for: now) else {
            return false
        }
        guard retryDelayRemaining(now: now, lastAttemptDate: lastAttemptDate) == nil else {
            return false
        }
        return true
    }

    func nextAttemptDelay(
        from date: Date,
        completedDayToken: String?,
        lastAttemptDate: Date?
    ) -> TimeInterval {
        if completedDayToken == dayToken(for: date) {
            return delayUntilWindowStart(after: date, forceTomorrow: true)
        }
        guard isInsideWindow(date) else {
            return delayUntilWindowStart(after: date)
        }
        guard let retryDelay = retryDelayRemaining(now: date, lastAttemptDate: lastAttemptDate) else {
            return 0
        }
        let retryDate = date.addingTimeInterval(retryDelay)
        guard dayToken(for: retryDate) == dayToken(for: date), isInsideWindow(retryDate) else {
            return delayUntilWindowStart(after: date, forceTomorrow: true)
        }
        return retryDelay
    }

    func completionDayToken(for result: T7EjectResult, now: Date) -> String? {
        guard result.status == .success || result.reason == .idleAlreadyUnmounted else {
            return nil
        }
        return dayToken(for: now)
    }

    func dayToken(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func isInsideWindow(_ date: Date) -> Bool {
        let minute = localMinuteOfDay(for: date)
        return minute >= configuration.startMinuteOfDay && minute <= configuration.endMinuteOfDay
    }

    private func retryDelayRemaining(now: Date, lastAttemptDate: Date?) -> TimeInterval? {
        guard let lastAttemptDate else {
            return nil
        }
        let elapsed = now.timeIntervalSince(lastAttemptDate)
        guard elapsed >= 0 else {
            return nil
        }
        let retryInterval = TimeInterval(configuration.retryIntervalSeconds)
        guard elapsed < retryInterval else {
            return nil
        }
        return retryInterval - elapsed
    }

    private func delayUntilWindowStart(after date: Date, forceTomorrow: Bool = false) -> TimeInterval {
        let todayStart = windowStart(onSameLocalDayAs: date)
        if !forceTomorrow, date < todayStart {
            return max(0, todayStart.timeIntervalSince(date))
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date)
            ?? date.addingTimeInterval(24 * 60 * 60)
        return max(0, windowStart(onSameLocalDayAs: tomorrow).timeIntervalSince(date))
    }

    private func windowStart(onSameLocalDayAs date: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = configuration.startMinuteOfDay / 60
        components.minute = configuration.startMinuteOfDay % 60
        components.second = 0
        components.nanosecond = 0
        return calendar.date(from: components) ?? date
    }

    private func localMinuteOfDay(for date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

@MainActor
protocol T7EjectServiceLifecycle: AnyObject {
    var isRunning: Bool { get }
    var latestResult: T7EjectResult? { get }
    var isAutomaticEnabled: Bool { get }
    var isSchedulerRunningForTesting: Bool { get }

    func startScheduler()
    func cancelScheduler()
    func stop()
}

@MainActor
final class T7EjectAppLifecycleRegistry {
    static let shared = T7EjectAppLifecycleRegistry()

    private weak var service: (any T7EjectServiceLifecycle)?

    private init() {}

    func register(_ service: any T7EjectServiceLifecycle) {
        self.service = service
    }

    func unregister(_ service: any T7EjectServiceLifecycle) {
        guard let registeredService = self.service,
              registeredService === service else {
            return
        }
        self.service = nil
    }

    func stopRegisteredService() {
        service?.stop()
    }
}

@MainActor
final class T7EjectService: ObservableObject, T7EjectServiceLifecycle {
    typealias HelperURLResolver = () throws -> URL

    @Published private(set) var isRunning = false
    @Published private(set) var latestResult: T7EjectResult?
    @Published private(set) var isAutomaticEnabled: Bool
    @Published private(set) var scheduleConfiguration: T7EjectScheduleConfiguration

    private let processRunner: any T7EjectProcessRunning
    private let helperURLResolver: HelperURLResolver
    private let clock: any T7EjectServiceClock
    private let calendar: Calendar
    private let defaults: UserDefaults
    private let logWriter: T7EjectJSONLLogWriter
    private var schedulePolicy: T7EjectSchedulePolicy

    private var schedulerTask: Task<Void, Never>?
    private var lastScheduledAttemptDate: Date?
    private var completedDayToken: String?

    var isSchedulerRunningForTesting: Bool {
        schedulerTask != nil
    }

    init(
        processRunner: any T7EjectProcessRunning,
        helperURLResolver: @escaping HelperURLResolver,
        clock: any T7EjectServiceClock = T7EjectSystemServiceClock(),
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard,
        logURL: URL? = nil
    ) {
        self.processRunner = processRunner
        self.helperURLResolver = helperURLResolver
        self.clock = clock
        self.calendar = calendar
        self.defaults = defaults
        let resolvedConfiguration = T7EjectScheduleConfiguration.resolved(defaults: defaults)
        self.scheduleConfiguration = resolvedConfiguration
        self.schedulePolicy = T7EjectSchedulePolicy(configuration: resolvedConfiguration, calendar: calendar)
        self.completedDayToken = defaults.string(forKey: MalDazeDefaults.t7EjectLastCompletedDay)
        self.logWriter = T7EjectJSONLLogWriter(logURL: logURL ?? Self.defaultLogURL())

        if defaults.object(forKey: MalDazeDefaults.t7EjectAutomaticEnabled) == nil {
            self.isAutomaticEnabled = true
            defaults.set(true, forKey: MalDazeDefaults.t7EjectAutomaticEnabled)
        } else {
            self.isAutomaticEnabled = defaults.bool(forKey: MalDazeDefaults.t7EjectAutomaticEnabled)
        }
        self.scheduleConfiguration.persist(to: defaults)
    }

    static func live() -> T7EjectService {
        T7EjectService(
            processRunner: T7EjectProcessRunner(),
            helperURLResolver: {
                try T7BundledEjectHelperURLResolver.resolve()
            }
        )
    }

    func runManualEject() async -> T7EjectResult {
        await runHelper(source: .manual)
    }

    func runScheduledEjectIfEligibleForTesting() async -> T7EjectResult? {
        let now = clock.currentDate()
        guard schedulePolicy.isEligible(
            now: now,
            isAutomaticEnabled: isAutomaticEnabled,
            completedDayToken: completedDayToken,
            lastAttemptDate: lastScheduledAttemptDate
        ) else {
            return nil
        }

        lastScheduledAttemptDate = now
        let result = await runHelper(source: .scheduled)
        if let token = schedulePolicy.completionDayToken(for: result, now: now) {
            completedDayToken = token
            defaults.set(token, forKey: MalDazeDefaults.t7EjectLastCompletedDay)
        }
        return result
    }

    func setAutomaticEnabled(_ enabled: Bool) {
        isAutomaticEnabled = enabled
        defaults.set(enabled, forKey: MalDazeDefaults.t7EjectAutomaticEnabled)
        if enabled {
            startScheduler()
        } else {
            cancelScheduler()
        }
    }

    func updateScheduleConfiguration(_ configuration: T7EjectScheduleConfiguration) {
        scheduleConfiguration = configuration
        schedulePolicy = T7EjectSchedulePolicy(configuration: configuration, calendar: calendar)
        configuration.persist(to: defaults)
        guard isSchedulerRunningForTesting else {
            return
        }
        cancelScheduler()
        startScheduler()
    }

    func startScheduler() {
        guard isAutomaticEnabled, schedulerTask == nil else {
            return
        }
        schedulerTask = Task { [weak self] in
            await self?.schedulerLoop()
        }
    }

    func cancelScheduler() {
        schedulerTask?.cancel()
        schedulerTask = nil
    }

    func stop() {
        cancelScheduler()
        processRunner.cancel()
    }

    private func schedulerLoop() async {
        while !Task.isCancelled {
            let delay = schedulePolicy.nextAttemptDelay(
                from: clock.currentDate(),
                completedDayToken: completedDayToken,
                lastAttemptDate: lastScheduledAttemptDate
            )
            if delay > 0 {
                do {
                    try await Task.sleep(nanoseconds: UInt64((delay * 1_000_000_000).rounded(.up)))
                } catch {
                    return
                }
            }
            _ = await runScheduledEjectIfEligibleForTesting()
        }
    }

    private func runHelper(source: T7EjectRunSource) async -> T7EjectResult {
        let startedAt = clock.currentDate()
        guard !isRunning else {
            let result = unexpectedErrorResult(
                startedAt: startedAt,
                diagnostic: "T7 eject helper is already running."
            )
            latestResult = result
            writeLog(
                result: result,
                source: source,
                helperURL: nil,
                terminationStatus: nil,
                stderr: nil,
                error: nil,
                processFailure: "already running"
            )
            return result
        }

        isRunning = true
        defer { isRunning = false }

        let helperURL: URL
        do {
            helperURL = try helperURLResolver()
        } catch {
            let result = unexpectedErrorResult(
                startedAt: startedAt,
                diagnostic: "Could not resolve T7EjectHelper: \(error)"
            )
            latestResult = result
            writeLog(
                result: result,
                source: source,
                helperURL: nil,
                terminationStatus: nil,
                stderr: nil,
                error: String(describing: error),
                processFailure: nil
            )
            return result
        }

        do {
            let output = try await processRunner.run(executableURL: helperURL)
            let result = parseProcessOutput(output, startedAt: startedAt)
            latestResult = result
            writeLog(
                result: result,
                source: source,
                helperURL: helperURL,
                terminationStatus: output.terminationStatus,
                stderr: output.stderr,
                error: nil,
                processFailure: output.terminationStatus == 0 ? nil : "process exited with \(output.terminationStatus)"
            )
            return result
        } catch {
            let result = unexpectedErrorResult(
                startedAt: startedAt,
                diagnostic: String(describing: error)
            )
            latestResult = result
            writeLog(
                result: result,
                source: source,
                helperURL: helperURL,
                terminationStatus: nil,
                stderr: nil,
                error: String(describing: error),
                processFailure: String(describing: error)
            )
            return result
        }
    }

    private func parseProcessOutput(_ output: T7EjectProcessOutput, startedAt: Date) -> T7EjectResult {
        guard output.terminationStatus == 0 else {
            return unexpectedErrorResult(
                startedAt: startedAt,
                diagnostic: diagnosticMessage(
                    prefix: "T7EjectHelper exited with status \(output.terminationStatus).",
                    stderr: output.stderr
                )
            )
        }

        guard let stdout = String(data: output.stdout, encoding: .utf8),
              let jsonLine = stdout
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map(String.init)
                .first else {
            return unexpectedErrorResult(
                startedAt: startedAt,
                diagnostic: diagnosticMessage(prefix: "T7EjectHelper emitted no JSON.", stderr: output.stderr)
            )
        }

        do {
            return try T7EjectResult.decoder().decode(T7EjectResult.self, from: Data(jsonLine.utf8))
        } catch {
            return unexpectedErrorResult(
                startedAt: startedAt,
                diagnostic: diagnosticMessage(
                    prefix: "T7EjectHelper emitted invalid JSON: \(error)",
                    stderr: output.stderr
                )
            )
        }
    }

    private func unexpectedErrorResult(startedAt: Date, diagnostic: String) -> T7EjectResult {
        T7EjectResult(
            status: .failed,
            reason: .unexpectedError,
            action: .safeEject,
            wholeDisk: nil,
            apfsContainer: nil,
            volumes: [],
            timeMachineWasRunning: false,
            timeMachineStopped: false,
            remainingMountedVolumes: [],
            dissenterStatus: nil,
            dissenterMessage: diagnostic,
            startedAt: startedAt,
            endedAt: clock.currentDate(),
            message: T7EjectResult.message(for: .failed, reason: .unexpectedError)
        )
    }

    private func diagnosticMessage(prefix: String, stderr: String) -> String {
        let trimmedStderr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedStderr.isEmpty else {
            return prefix
        }
        return "\(prefix) stderr: \(trimmedStderr)"
    }

    private func writeLog(
        result: T7EjectResult,
        source: T7EjectRunSource,
        helperURL: URL?,
        terminationStatus: Int32?,
        stderr: String?,
        error: String?,
        processFailure: String?
    ) {
        let entry = T7EjectDiagnosticLogEntry(
            timestamp: clock.currentDate(),
            source: source,
            helperURL: helperURL?.path,
            terminationStatus: terminationStatus,
            stderr: stderr,
            error: error,
            processFailure: processFailure,
            result: result
        )
        try? logWriter.append(entry)
    }

    private static func defaultLogURL() -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return directory
            .appendingPathComponent("MalDaze", isDirectory: true)
            .appendingPathComponent("T7Eject", isDirectory: true)
            .appendingPathComponent("t7-eject.jsonl")
    }
}

struct T7BundledEjectHelperURLResolver {
    static func resolve(bundle: Bundle = .main, fileManager: FileManager = .default) throws -> URL {
        let helperName = "T7EjectHelper"
        var candidates: [URL] = []
        if let builtInPlugInsURL = bundle.builtInPlugInsURL {
            candidates.append(builtInPlugInsURL.appendingPathComponent(helperName))
        }
        candidates.append(
            bundle.bundleURL
                .appendingPathComponent("Contents/Helpers", isDirectory: true)
                .appendingPathComponent(helperName)
        )
        candidates.append(
            bundle.bundleURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("MacOS", isDirectory: true)
                .appendingPathComponent(helperName)
        )
        if let resourceURL = bundle.resourceURL {
            candidates.append(resourceURL.appendingPathComponent(helperName))
        }
        #if DEBUG
        candidates.append(bundle.bundleURL.deletingLastPathComponent().appendingPathComponent(helperName))
        #endif

        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate.path) {
            return candidate
        }
        throw T7EjectHelperResolutionError.notFound(candidates.map(\.path))
    }
}

enum T7EjectHelperResolutionError: Error, CustomStringConvertible {
    case notFound([String])

    var description: String {
        switch self {
        case .notFound(let candidates):
            return "T7EjectHelper was not found in bundled locations: \(candidates.joined(separator: ", "))"
        }
    }
}

enum T7EjectProcessRunnerError: Error, CustomStringConvertible {
    case timedOut(timeoutNanoseconds: UInt64, terminationStatus: Int32?, stderr: String)
    case cancelled(terminationStatus: Int32?, stderr: String)

    var description: String {
        switch self {
        case .timedOut(let timeoutNanoseconds, let terminationStatus, let stderr):
            let seconds = Double(timeoutNanoseconds) / 1_000_000_000
            return "T7EjectHelper timeout after \(String(format: "%.3f", seconds)) seconds\(diagnosticSuffix(terminationStatus: terminationStatus, stderr: stderr))."
        case .cancelled(let terminationStatus, let stderr):
            return "T7EjectHelper cancelled\(diagnosticSuffix(terminationStatus: terminationStatus, stderr: stderr))."
        }
    }

    private func diagnosticSuffix(terminationStatus: Int32?, stderr: String) -> String {
        var parts: [String] = []
        if let terminationStatus {
            parts.append("child exited with status \(terminationStatus)")
        }
        let trimmedStderr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedStderr.isEmpty {
            parts.append("stderr: \(trimmedStderr)")
        }
        guard !parts.isEmpty else {
            return ""
        }
        return " after \(parts.joined(separator: "; "))"
    }
}

private enum T7EjectProcessPendingFailure {
    case timedOut(UInt64)
    case cancelled
}

private final class T7EjectProcessRunState: @unchecked Sendable {
    private typealias ResumeState = (
        continuation: CheckedContinuation<T7EjectProcessOutput, Error>?,
        timeoutTask: Task<Void, Never>?
    )

    private let lock = NSLock()
    private var continuation: CheckedContinuation<T7EjectProcessOutput, Error>?
    private var timeoutTask: Task<Void, Never>?
    private var pendingFailure: T7EjectProcessPendingFailure?
    private var didResume = false

    let process: Process

    init(process: Process) {
        self.process = process
    }

    func install(_ continuation: CheckedContinuation<T7EjectProcessOutput, Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func setTimeoutTask(_ task: Task<Void, Never>) {
        lock.lock()
        if didResume {
            lock.unlock()
            task.cancel()
            return
        }
        timeoutTask = task
        lock.unlock()
    }

    func cancelTimeout() {
        lock.lock()
        let task = timeoutTask
        timeoutTask = nil
        lock.unlock()
        task?.cancel()
    }

    func requestTermination(for failure: T7EjectProcessPendingFailure) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }
        if pendingFailure == nil {
            pendingFailure = failure
        }
        let shouldTerminate = process.isRunning
        lock.unlock()

        if shouldTerminate {
            process.terminate()
        }
    }

    func resumeAfterTermination(_ output: T7EjectProcessOutput) {
        lock.lock()
        let pendingFailure = pendingFailure
        lock.unlock()

        switch pendingFailure {
        case .timedOut(let timeoutNanoseconds):
            resume(.failure(pendingFailureError(
                .timedOut(timeoutNanoseconds),
                terminationStatus: output.terminationStatus,
                stderr: output.stderr
            )))
        case .cancelled:
            resume(.failure(pendingFailureError(
                .cancelled,
                terminationStatus: output.terminationStatus,
                stderr: output.stderr
            )))
        case nil:
            resume(.success(output))
        }
    }

    func launchProcessIfNoPendingFailure() -> Bool {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return false
        }
        if let pendingFailure {
            let error = pendingFailureError(
                pendingFailure,
                terminationStatus: nil,
                stderr: ""
            )
            let resumeState = takeResumeStateLocked()
            lock.unlock()
            finishResume(.failure(error), with: resumeState)
            return false
        }

        do {
            try process.run()
            lock.unlock()
            return true
        } catch {
            let resumeState = takeResumeStateLocked()
            lock.unlock()
            finishResume(.failure(error), with: resumeState)
            return false
        }
    }

    func terminateIfPendingFailureAfterLaunch() {
        lock.lock()
        let shouldTerminate = pendingFailure != nil && !didResume && process.isRunning
        lock.unlock()

        if shouldTerminate {
            process.terminate()
        }
    }

    private func pendingFailureError(
        _ failure: T7EjectProcessPendingFailure,
        terminationStatus: Int32?,
        stderr: String
    ) -> T7EjectProcessRunnerError {
        switch failure {
        case .timedOut(let timeoutNanoseconds):
            return T7EjectProcessRunnerError.timedOut(
                timeoutNanoseconds: timeoutNanoseconds,
                terminationStatus: terminationStatus,
                stderr: stderr
            )
        case .cancelled:
            return T7EjectProcessRunnerError.cancelled(
                terminationStatus: terminationStatus,
                stderr: stderr
            )
        }
    }

    private func takeResumeStateLocked() -> ResumeState {
        didResume = true
        let continuation = continuation
        self.continuation = nil
        let task = timeoutTask
        timeoutTask = nil
        return (continuation, task)
    }

    private func finishResume(_ result: Result<T7EjectProcessOutput, Error>, with resumeState: ResumeState) {
        resumeState.timeoutTask?.cancel()
        switch result {
        case .success(let output):
            resumeState.continuation?.resume(returning: output)
        case .failure(let error):
            resumeState.continuation?.resume(throwing: error)
        }
    }

    func resume(_ result: Result<T7EjectProcessOutput, Error>) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }
        let resumeState = takeResumeStateLocked()
        lock.unlock()

        finishResume(result, with: resumeState)
    }
}

@MainActor
final class T7EjectProcessRunner: T7EjectProcessRunning {
    typealias BeforeLaunchHook = @MainActor () async -> Void
    typealias BeforeProcessRunHook = @MainActor () async -> Void
    typealias AfterProcessRunHook = @MainActor () -> Void

    private static let defaultTimeoutNanoseconds: UInt64 = 12 * 60 * 1_000_000_000

    private let timeoutNanoseconds: UInt64
    private let beforeLaunchForTesting: BeforeLaunchHook?
    private let beforeProcessRunForTesting: BeforeProcessRunHook?
    private let afterProcessRunForTesting: AfterProcessRunHook?
    private var activeRunState: T7EjectProcessRunState?

    init(
        timeoutNanoseconds: UInt64 = T7EjectProcessRunner.defaultTimeoutNanoseconds,
        beforeLaunchForTesting: BeforeLaunchHook? = nil,
        beforeProcessRunForTesting: BeforeProcessRunHook? = nil,
        afterProcessRunForTesting: AfterProcessRunHook? = nil
    ) {
        self.timeoutNanoseconds = timeoutNanoseconds
        self.beforeLaunchForTesting = beforeLaunchForTesting
        self.beforeProcessRunForTesting = beforeProcessRunForTesting
        self.afterProcessRunForTesting = afterProcessRunForTesting
    }

    func cancel() {
        activeRunState?.requestTermination(for: .cancelled)
    }

    func run(executableURL: URL) async throws -> T7EjectProcessOutput {
        let process = Process()
        process.executableURL = executableURL

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        let runState = T7EjectProcessRunState(process: process)
        activeRunState = runState
        defer {
            runState.cancelTimeout()
            if let activeRunState, activeRunState === runState {
                self.activeRunState = nil
            }
        }

        return try await withTaskCancellationHandler {
            if let beforeLaunchForTesting {
                await beforeLaunchForTesting()
            }
            if let beforeProcessRunForTesting {
                await beforeProcessRunForTesting()
            }
            return try await withCheckedThrowingContinuation { continuation in
                runState.install(continuation)
                process.terminationHandler = { terminatedProcess in
                    let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                    runState.resumeAfterTermination(.init(
                        terminationStatus: terminatedProcess.terminationStatus,
                        stdout: stdout,
                        stderr: stderr
                    ))
                }
                guard runState.launchProcessIfNoPendingFailure() else {
                    return
                }
                afterProcessRunForTesting?()
                runState.terminateIfPendingFailureAfterLaunch()

                let timeoutTask = Task { @MainActor [runState, timeoutNanoseconds] in
                    do {
                        try await Task.sleep(nanoseconds: timeoutNanoseconds)
                    } catch {
                        return
                    }
                    runState.requestTermination(for: .timedOut(timeoutNanoseconds))
                }
                runState.setTimeoutTask(timeoutTask)
            }
        } onCancel: {
            runState.requestTermination(for: .cancelled)
        }
    }
}

private enum T7EjectRunSource: String, Encodable {
    case manual
    case scheduled
}

private struct T7EjectDiagnosticLogEntry: Encodable {
    let timestamp: Date
    let source: T7EjectRunSource
    let helperURL: String?
    let terminationStatus: Int32?
    let stderr: String?
    let error: String?
    let processFailure: String?
    let result: T7EjectResult
}

private struct T7EjectJSONLLogWriter {
    let logURL: URL
    let fileManager: FileManager

    init(logURL: URL, fileManager: FileManager = .default) {
        self.logURL = logURL
        self.fileManager = fileManager
    }

    func append(_ entry: T7EjectDiagnosticLogEntry) throws {
        try fileManager.createDirectory(
            at: logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try encodedLine(for: entry)
        if fileManager.fileExists(atPath: logURL.path) {
            let handle = try FileHandle(forWritingTo: logURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: logURL, options: .atomic)
        }
    }

    private func encodedLine(for entry: T7EjectDiagnosticLogEntry) throws -> Data {
        let encoder = T7EjectResult.encoder()
        var data = try encoder.encode(entry)
        data.append(0x0A)
        return data
    }
}
