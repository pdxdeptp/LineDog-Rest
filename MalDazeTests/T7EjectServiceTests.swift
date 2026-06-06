import XCTest
@testable import MalDaze

@MainActor
final class T7EjectServiceTests: XCTestCase {
    func testManualRunInvokesResolvedHelperParsesStdoutAndWritesJSONLLog() async throws {
        let (defaults, suiteName) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let logURL = try makeTemporaryLogURL()
        defer { try? FileManager.default.removeItem(at: logURL.deletingLastPathComponent()) }
        let helperURL = URL(fileURLWithPath: "/tmp/TestT7EjectHelper")
        let expected = Self.result(
            status: .success,
            reason: nil,
            wholeDisk: "disk4",
            volumes: ["Storage", "T7 Shield"],
            remainingMountedVolumes: []
        )
        let runner = RecordingT7EjectProcessRunner(outputs: [
            .success(.init(terminationStatus: 0, stdout: try stdoutData(for: expected), stderr: "")),
        ])
        let service = makeService(
            defaults: defaults,
            runner: runner,
            helperURL: helperURL,
            logURL: logURL
        )

        let result = await service.runManualEject()

        XCTAssertEqual(result, expected)
        XCTAssertEqual(service.latestResult, expected)
        XCTAssertFalse(service.isRunning)
        XCTAssertEqual(runner.requestedExecutableURLs, [helperURL])

        let entries = try readLogEntries(at: logURL)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].result, expected)
        XCTAssertEqual(entries[0].terminationStatus, 0)
        XCTAssertEqual(entries[0].helperURL, helperURL.path)
    }

    func testManualRunReturnsUnexpectedErrorAndLogsDiagnosticsForInvalidJSONMissingJSONNonzeroExitAndSpawnFailure() async throws {
        let cases: [(String, Result<T7EjectProcessOutput, Error>, String)] = [
            (
                "invalid json",
                .success(.init(terminationStatus: 0, stdout: Data("not json\n".utf8), stderr: "bad stdout")),
                "bad stdout"
            ),
            (
                "missing json",
                .success(.init(terminationStatus: 0, stdout: Data(), stderr: "empty stdout")),
                "empty stdout"
            ),
            (
                "nonzero exit",
                .success(.init(
                    terminationStatus: 42,
                    stdout: try stdoutData(for: Self.result(status: .success, reason: nil)),
                    stderr: "process failed"
                )),
                "process failed"
            ),
            (
                "spawn failure",
                .failure(SpawnFailure()),
                "SpawnFailure"
            ),
        ]

        for (name, output, expectedDiagnostic) in cases {
            let (defaults, suiteName) = try makeIsolatedDefaults()
            defer { defaults.removePersistentDomain(forName: suiteName) }
            let logURL = try makeTemporaryLogURL()
            defer { try? FileManager.default.removeItem(at: logURL.deletingLastPathComponent()) }
            let runner = RecordingT7EjectProcessRunner(outputs: [output])
            let service = makeService(defaults: defaults, runner: runner, logURL: logURL)

            let result = await service.runManualEject()

            XCTAssertEqual(result.status, .failed, name)
            XCTAssertEqual(result.reason, .unexpectedError, name)
            XCTAssertEqual(result.message, T7EjectResult.message(for: .failed, reason: .unexpectedError), name)
            XCTAssertTrue(result.dissenterMessage?.contains(expectedDiagnostic) == true, name)

            let entries = try readLogEntries(at: logURL)
            XCTAssertEqual(entries.count, 1, name)
            XCTAssertEqual(entries[0].result.status, .failed, name)
            XCTAssertEqual(entries[0].result.reason, .unexpectedError, name)
            XCTAssertTrue(
                [entries[0].stderr, entries[0].error, entries[0].processFailure]
                    .compactMap { $0 }
                    .joined(separator: "\n")
                    .contains(expectedDiagnostic),
                name
            )
        }
    }

    func testProductionProcessRunnerTimesOutAndTerminatesLongRunningHelper() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("T7EjectProcessRunnerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let executableURL = directory.appendingPathComponent("SleepsLongerThanTimeout")
        try """
        #!/bin/sh
        exec /bin/sleep 10
        """.write(to: executableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

        let runner = T7EjectProcessRunner(timeoutNanoseconds: 150_000_000)
        let startedAt = Date()

        do {
            _ = try await runner.run(executableURL: executableURL)
            XCTFail("Expected the long-running helper to time out.")
        } catch {
            let diagnostic = String(describing: error)
            XCTAssertTrue(diagnostic.localizedCaseInsensitiveContains("timeout"), diagnostic)
        }

        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 2)
    }

    func testManualRunTimeoutWaitsForChildTerminationBeforeReportingAndLoggingFailure() async throws {
        let script = try makeSignalAwareTemporaryScript(
            name: "TimeoutWaitsForTermination",
            terminationDelaySeconds: "0.25"
        )
        defer { try? FileManager.default.removeItem(at: script.directory) }
        let (defaults, suiteName) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let logURL = try makeTemporaryLogURL()
        defer { try? FileManager.default.removeItem(at: logURL.deletingLastPathComponent()) }
        let runner = T7EjectProcessRunner(timeoutNanoseconds: 1_000_000_000)
        let service = makeService(
            defaults: defaults,
            runner: runner,
            helperURL: script.executableURL,
            logURL: logURL
        )

        let result = await service.runManualEject()

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.reason, .unexpectedError)
        XCTAssertTrue(FileManager.default.fileExists(atPath: script.terminatedMarkerURL.path))

        let entries = try readLogEntries(at: logURL)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].result.status, .failed)
        XCTAssertEqual(entries[0].result.reason, .unexpectedError)
        XCTAssertTrue(entries[0].processFailure?.localizedCaseInsensitiveContains("timeout") == true)
    }

    func testProductionProcessRunnerTaskCancellationWaitsForChildTerminationBeforeFailing() async throws {
        let script = try makeSignalAwareTemporaryScript(
            name: "CancellationWaitsForTermination",
            terminationDelaySeconds: "0.25"
        )
        defer { try? FileManager.default.removeItem(at: script.directory) }
        let runner = T7EjectProcessRunner(timeoutNanoseconds: 10_000_000_000)
        let runTask = Task { @MainActor in
            try await runner.run(executableURL: script.executableURL)
        }
        try await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            FileManager.default.fileExists(atPath: script.startedMarkerURL.path)
        }

        let cancelledAt = Date()
        runTask.cancel()

        do {
            _ = try await runTask.value
            XCTFail("Expected task cancellation to fail the helper run.")
        } catch {
            XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(cancelledAt), 0.20)
            XCTAssertTrue(FileManager.default.fileExists(atPath: script.terminatedMarkerURL.path))
        }
    }

    func testProductionProcessRunnerPreLaunchCancelDoesNotStartHelper() async throws {
        let script = try makeSignalAwareTemporaryScript(
            name: "PreLaunchCancelDoesNotStartHelper",
            terminationDelaySeconds: "0.01"
        )
        defer { try? FileManager.default.removeItem(at: script.directory) }

        var reachedBeforeLaunch = false
        var allowLaunch = false
        let runner = T7EjectProcessRunner(
            timeoutNanoseconds: 150_000_000,
            beforeLaunchForTesting: {
                reachedBeforeLaunch = true
                while !allowLaunch {
                    try? await Task.sleep(nanoseconds: 1_000_000)
                }
            }
        )
        let runTask = Task { @MainActor in
            try await runner.run(executableURL: script.executableURL)
        }
        try await waitUntil {
            reachedBeforeLaunch
        }

        runner.cancel()
        allowLaunch = true

        do {
            _ = try await runTask.value
            XCTFail("Expected pre-launch cancellation to fail the helper run.")
        } catch {
            XCTAssertTrue(String(describing: error).localizedCaseInsensitiveContains("cancel"), String(describing: error))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: script.startedMarkerURL.path))
    }

    func testProductionProcessRunnerTaskCancellationAfterPreLaunchCheckDoesNotStartHelper() async throws {
        let script = try makeSignalAwareTemporaryScript(
            name: "TaskCancellationAfterPreLaunchCheckDoesNotStartHelper",
            terminationDelaySeconds: "0.01"
        )
        defer { try? FileManager.default.removeItem(at: script.directory) }

        var reachedBeforeProcessRun = false
        var allowProcessRun = false
        var processRunWasAttempted = false
        var runTask: Task<T7EjectProcessOutput, Error>?
        let runner = T7EjectProcessRunner(
            timeoutNanoseconds: 150_000_000,
            beforeProcessRunForTesting: {
                reachedBeforeProcessRun = true
                while !allowProcessRun {
                    try? await Task.sleep(nanoseconds: 1_000_000)
                }
            },
            afterProcessRunForTesting: {
                processRunWasAttempted = true
            }
        )
        runTask = Task { @MainActor in
            try await runner.run(executableURL: script.executableURL)
        }
        try await waitUntil {
            reachedBeforeProcessRun
        }

        runTask?.cancel()
        allowProcessRun = true

        do {
            _ = try await XCTUnwrap(runTask).value
            XCTFail("Expected task cancellation after the pre-launch check to fail the helper run.")
        } catch {
            XCTAssertTrue(String(describing: error).localizedCaseInsensitiveContains("cancel"), String(describing: error))
        }
        XCTAssertTrue(reachedBeforeProcessRun)
        XCTAssertFalse(processRunWasAttempted)
        XCTAssertFalse(FileManager.default.fileExists(atPath: script.startedMarkerURL.path))
    }

    func testManualRunPreventsConcurrentHelperProcessesAndKeepsInFlightStateUntilActiveRunFinishes() async throws {
        let (defaults, suiteName) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let logURL = try makeTemporaryLogURL()
        defer { try? FileManager.default.removeItem(at: logURL.deletingLastPathComponent()) }
        let runner = BlockingT7EjectProcessRunner()
        let service = makeService(defaults: defaults, runner: runner, logURL: logURL)
        let success = Self.result(status: .success, reason: nil)

        let firstRun = Task { @MainActor in
            await service.runManualEject()
        }
        try await waitUntil { runner.requestedExecutableURLs.count == 1 }

        let secondResult = await service.runManualEject()

        XCTAssertEqual(runner.requestedExecutableURLs.count, 1)
        XCTAssertTrue(service.isRunning)
        XCTAssertEqual(secondResult.status, .failed)
        XCTAssertEqual(secondResult.reason, .unexpectedError)
        XCTAssertTrue(secondResult.dissenterMessage?.contains("already running") == true)

        runner.complete(with: .init(terminationStatus: 0, stdout: try stdoutData(for: success), stderr: ""))
        let firstResult = await firstRun.value

        XCTAssertEqual(firstResult, success)
        XCTAssertFalse(service.isRunning)
        XCTAssertEqual(runner.requestedExecutableURLs.count, 1)
        XCTAssertEqual(try readLogEntries(at: logURL).map(\.result.status), [.failed, .success])
    }

    func testStopCancelsSchedulerAndActiveHelperRun() async throws {
        let (defaults, suiteName) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let logURL = try makeTemporaryLogURL()
        defer { try? FileManager.default.removeItem(at: logURL.deletingLastPathComponent()) }
        let runner = BlockingT7EjectProcessRunner()
        let service = makeService(defaults: defaults, runner: runner, logURL: logURL)

        service.startScheduler()
        let inFlightRun = Task { @MainActor in
            await service.runManualEject()
        }
        try await waitUntil { runner.requestedExecutableURLs.count == 1 && service.isRunning }

        service.stop()

        XCTAssertFalse(service.isSchedulerRunningForTesting)
        XCTAssertEqual(runner.cancelCount, 1)
        let result = await inFlightRun.value
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.reason, .unexpectedError)
        XCTAssertFalse(service.isRunning)

        let entries = try readLogEntries(at: logURL)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].result.status, .failed)
        XCTAssertEqual(entries[0].result.reason, .unexpectedError)
        XCTAssertTrue(entries[0].processFailure?.contains("CancellationError") == true)
    }

    func testSchedulerAttemptsImmediatelyWhenStartedInsideWindowAndNoAttemptHasRun() async throws {
        let (defaults, suiteName) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let clock = MutableT7EjectServiceClock(Self.date("2026-06-06 20:00"))
        let runner = RecordingT7EjectProcessRunner(outputs: [
            .success(.init(
                terminationStatus: 0,
                stdout: try stdoutData(for: Self.result(status: .idle, reason: .idleNotConnected)),
                stderr: ""
            )),
        ])
        let service = makeService(defaults: defaults, runner: runner, clock: clock)

        service.startScheduler()
        defer { service.cancelScheduler() }

        try await waitUntil(timeoutNanoseconds: 300_000_000) {
            runner.requestedExecutableURLs.count == 1
        }
        XCTAssertEqual(runner.requestedExecutableURLs.count, 1)
    }

    func testSchedulerDefaultsToEnabledAndRunsOnlyInNightlyWindowAtRetryInterval() async throws {
        let (defaults, suiteName) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let clock = MutableT7EjectServiceClock(Self.date("2026-06-06 19:59"))
        let runner = RecordingT7EjectProcessRunner(outputs: [
            .success(.init(terminationStatus: 0, stdout: try stdoutData(for: Self.result(status: .idle, reason: .idleNotConnected)), stderr: "")),
            .success(.init(terminationStatus: 0, stdout: try stdoutData(for: Self.result(status: .idle, reason: .idleNotConnected)), stderr: "")),
            .success(.init(terminationStatus: 0, stdout: try stdoutData(for: Self.result(status: .idle, reason: .idleNotConnected)), stderr: "")),
        ])
        let service = makeService(defaults: defaults, runner: runner, clock: clock)

        XCTAssertTrue(service.isAutomaticEnabled)
        XCTAssertEqual(service.scheduleConfiguration.startMinuteOfDay, 20 * 60)
        XCTAssertEqual(service.scheduleConfiguration.endMinuteOfDay, 23 * 60 + 45)
        XCTAssertEqual(service.scheduleConfiguration.retryIntervalSeconds, 15 * 60)
        let beforeWindow = await service.runScheduledEjectIfEligibleForTesting()
        XCTAssertNil(beforeWindow)
        XCTAssertEqual(runner.requestedExecutableURLs.count, 0)

        clock.now = Self.date("2026-06-06 20:00")
        let firstWindowRun = await service.runScheduledEjectIfEligibleForTesting()
        XCTAssertNotNil(firstWindowRun)
        XCTAssertEqual(runner.requestedExecutableURLs.count, 1)

        clock.now = Self.date("2026-06-06 20:10")
        let retryTooSoon = await service.runScheduledEjectIfEligibleForTesting()
        XCTAssertNil(retryTooSoon)
        XCTAssertEqual(runner.requestedExecutableURLs.count, 1)

        clock.now = Self.date("2026-06-06 20:15")
        let secondWindowRun = await service.runScheduledEjectIfEligibleForTesting()
        XCTAssertNotNil(secondWindowRun)
        XCTAssertEqual(runner.requestedExecutableURLs.count, 2)

        clock.now = Self.date("2026-06-06 23:45")
        let lastWindowRun = await service.runScheduledEjectIfEligibleForTesting()
        XCTAssertNotNil(lastWindowRun)
        XCTAssertEqual(runner.requestedExecutableURLs.count, 3)

        clock.now = Self.date("2026-06-06 23:46")
        let afterWindow = await service.runScheduledEjectIfEligibleForTesting()
        XCTAssertNil(afterWindow)
        XCTAssertEqual(runner.requestedExecutableURLs.count, 3)
    }

    func testScheduleConfigurationNormalizesCrossMidnightWindowToSameDaySlot() async throws {
        let configuration = T7EjectScheduleConfiguration(
            startMinuteOfDay: 23 * 60,
            endMinuteOfDay: 1 * 60,
            retryIntervalSeconds: 15 * 60
        )
        XCTAssertEqual(configuration.startMinuteOfDay, 23 * 60)
        XCTAssertEqual(configuration.endMinuteOfDay, 23 * 60)

        let (defaults, suiteName) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let clock = MutableT7EjectServiceClock(Self.date("2026-06-07 00:30"))
        let runner = RecordingT7EjectProcessRunner(outputs: [
            .success(.init(
                terminationStatus: 0,
                stdout: try stdoutData(for: Self.result(status: .success, reason: nil)),
                stderr: ""
            )),
        ])
        let service = makeService(defaults: defaults, runner: runner, clock: clock)
        service.updateScheduleConfiguration(configuration)

        let afterMidnight = await service.runScheduledEjectIfEligibleForTesting()
        XCTAssertNil(afterMidnight)
        XCTAssertEqual(runner.requestedExecutableURLs.count, 0)

        clock.now = Self.date("2026-06-07 23:00")
        let sameDaySlot = await service.runScheduledEjectIfEligibleForTesting()
        XCTAssertEqual(sameDaySlot?.status, .success)
        XCTAssertEqual(runner.requestedExecutableURLs.count, 1)
    }

    func testSchedulerSuppressesRestOfLocalDayAfterSuccessOrAlreadyUnmountedButRetriesNextDay() async throws {
        let completionResults: [(String, T7EjectResult)] = [
            ("success", Self.result(status: .success, reason: nil)),
            ("already unmounted", Self.result(status: .idle, reason: .idleAlreadyUnmounted)),
        ]

        for (name, completionResult) in completionResults {
            let (defaults, suiteName) = try makeIsolatedDefaults()
            defer { defaults.removePersistentDomain(forName: suiteName) }
            let clock = MutableT7EjectServiceClock(Self.date("2026-06-06 20:00"))
            let runner = RecordingT7EjectProcessRunner(outputs: [
                .success(.init(terminationStatus: 0, stdout: try stdoutData(for: completionResult), stderr: "")),
                .success(.init(terminationStatus: 0, stdout: try stdoutData(for: Self.result(status: .success, reason: nil)), stderr: "")),
            ])
            let service = makeService(defaults: defaults, runner: runner, clock: clock)

            let completion = await service.runScheduledEjectIfEligibleForTesting()
            XCTAssertNotNil(completion, name)
            XCTAssertEqual(runner.requestedExecutableURLs.count, 1, name)

            clock.now = Self.date("2026-06-06 20:15")
            let suppressed = await service.runScheduledEjectIfEligibleForTesting()
            XCTAssertNil(suppressed, name)
            XCTAssertEqual(runner.requestedExecutableURLs.count, 1, name)

            clock.now = Self.date("2026-06-07 20:00")
            let nextDay = await service.runScheduledEjectIfEligibleForTesting()
            XCTAssertNotNil(nextDay, name)
            XCTAssertEqual(runner.requestedExecutableURLs.count, 2, name)
        }
    }

    func testSchedulerKeepsRetryEligibilityAfterIdleNotConnected() async throws {
        let (defaults, suiteName) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let clock = MutableT7EjectServiceClock(Self.date("2026-06-06 20:00"))
        let runner = RecordingT7EjectProcessRunner(outputs: [
            .success(.init(terminationStatus: 0, stdout: try stdoutData(for: Self.result(status: .idle, reason: .idleNotConnected)), stderr: "")),
            .success(.init(terminationStatus: 0, stdout: try stdoutData(for: Self.result(status: .success, reason: nil)), stderr: "")),
        ])
        let service = makeService(defaults: defaults, runner: runner, clock: clock)

        let first = await service.runScheduledEjectIfEligibleForTesting()
        XCTAssertEqual(first?.reason, .idleNotConnected)

        clock.now = Self.date("2026-06-06 20:15")
        let second = await service.runScheduledEjectIfEligibleForTesting()
        XCTAssertEqual(second?.status, .success)
        XCTAssertEqual(runner.requestedExecutableURLs.count, 2)
    }

    func testManualRunBypassesWindowAndDisablingAutomaticCancelsScheduledAttempts() async throws {
        let (defaults, suiteName) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let clock = MutableT7EjectServiceClock(Self.date("2026-06-06 12:00"))
        let runner = RecordingT7EjectProcessRunner(outputs: [
            .success(.init(terminationStatus: 0, stdout: try stdoutData(for: Self.result(status: .success, reason: nil)), stderr: "")),
        ])
        let service = makeService(defaults: defaults, runner: runner, clock: clock)

        service.startScheduler()
        XCTAssertTrue(service.isSchedulerRunningForTesting)
        service.setAutomaticEnabled(false)

        XCTAssertFalse(service.isAutomaticEnabled)
        XCTAssertFalse(service.isSchedulerRunningForTesting)
        XCTAssertFalse(defaults.bool(forKey: MalDazeDefaults.t7EjectAutomaticEnabled))

        clock.now = Self.date("2026-06-06 20:00")
        let disabledScheduledRun = await service.runScheduledEjectIfEligibleForTesting()
        XCTAssertNil(disabledScheduledRun)
        XCTAssertEqual(runner.requestedExecutableURLs.count, 0)

        clock.now = Self.date("2026-06-06 12:00")
        let manual = await service.runManualEject()
        XCTAssertEqual(manual.status, .success)
        XCTAssertEqual(runner.requestedExecutableURLs.count, 1)
    }

    func testScheduleConfigurationPersistsWindowRetryAndAutomaticDefaults() throws {
        let (defaults, suiteName) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let service = makeService(defaults: defaults, runner: RecordingT7EjectProcessRunner())
        let configuration = T7EjectScheduleConfiguration(
            startMinuteOfDay: 21 * 60 + 5,
            endMinuteOfDay: 23 * 60 + 30,
            retryIntervalSeconds: 30 * 60
        )

        service.updateScheduleConfiguration(configuration)
        service.setAutomaticEnabled(false)

        XCTAssertEqual(service.scheduleConfiguration, configuration)
        XCTAssertEqual(defaults.integer(forKey: MalDazeDefaults.t7EjectScheduleStartMinuteOfDay), 21 * 60 + 5)
        XCTAssertEqual(defaults.integer(forKey: MalDazeDefaults.t7EjectScheduleEndMinuteOfDay), 23 * 60 + 30)
        XCTAssertEqual(defaults.integer(forKey: MalDazeDefaults.t7EjectRetryIntervalSeconds), 30 * 60)
        XCTAssertFalse(defaults.bool(forKey: MalDazeDefaults.t7EjectAutomaticEnabled))
    }

    func testAppViewModelStartsInjectedT7SchedulerOnBootstrapAndStopsItOnDeinit() async throws {
        let lifecycle = RecordingT7EjectServiceLifecycle()
        var viewModel: AppViewModel? = AppViewModel(
            windowManager: MockWindowManager(),
            bootstrapAutoEngine: false,
            t7EjectService: lifecycle,
            bootstrapT7EjectScheduler: true
        )

        XCTAssertNotNil(viewModel)
        XCTAssertEqual(lifecycle.startCount, 1)
        XCTAssertEqual(lifecycle.cancelCount, 0)

        viewModel = nil

        try await waitUntil { lifecycle.stopCount == 1 }
        XCTAssertEqual(lifecycle.stopCount, 1)
        XCTAssertEqual(lifecycle.cancelCount, 0)
    }

    func testAppViewModelCanDisableT7SchedulerBootstrapForTests() async throws {
        let lifecycle = RecordingT7EjectServiceLifecycle()
        var viewModel: AppViewModel? = AppViewModel(
            windowManager: MockWindowManager(),
            bootstrapAutoEngine: false,
            t7EjectService: lifecycle,
            bootstrapT7EjectScheduler: false
        )

        XCTAssertNotNil(viewModel)
        XCTAssertEqual(lifecycle.startCount, 0)

        viewModel = nil

        try await waitUntil { lifecycle.stopCount == 1 }
        XCTAssertEqual(lifecycle.stopCount, 1)
        XCTAssertEqual(lifecycle.cancelCount, 0)
    }

    func testAppViewModelDoesNotImplicitlyStartT7SchedulerUnderXCTestWhenAutoEngineBootstraps() async throws {
        let lifecycle = RecordingT7EjectServiceLifecycle()
        var viewModel: AppViewModel? = AppViewModel(
            windowManager: MockWindowManager(),
            bootstrapAutoEngine: true,
            t7EjectService: lifecycle
        )

        XCTAssertNotNil(viewModel)
        XCTAssertEqual(lifecycle.startCount, 0)

        viewModel = nil

        try await waitUntil { lifecycle.stopCount == 1 }
        XCTAssertEqual(lifecycle.stopCount, 1)
    }

    func testAppViewModelExposesT7UIStateAndRoutesCommandsThroughService() async throws {
        let latest = Self.result(status: .idle, reason: .idleNotConnected)
        let service = RecordingT7EjectUIService(
            latestResultValue: latest,
            isRunningValue: false,
            isAutomaticEnabledValue: true,
            scheduleConfigurationValue: T7EjectScheduleConfiguration(
                startMinuteOfDay: 21 * 60,
                endMinuteOfDay: 23 * 60,
                retryIntervalSeconds: 20 * 60
            ),
            manualResult: Self.result(status: .success, reason: nil)
        )
        let viewModel = AppViewModel(
            windowManager: MockWindowManager(),
            bootstrapAutoEngine: false,
            t7EjectService: service,
            bootstrapT7EjectScheduler: false
        )

        XCTAssertEqual(viewModel.t7LatestResult, latest)
        XCTAssertFalse(viewModel.isT7EjectRunning)
        XCTAssertTrue(viewModel.isT7AutomaticEjectEnabled)
        XCTAssertEqual(viewModel.t7ScheduleConfiguration.startMinuteOfDay, 21 * 60)
        XCTAssertEqual(viewModel.t7ScheduleConfiguration.endMinuteOfDay, 23 * 60)
        XCTAssertEqual(viewModel.t7ScheduleConfiguration.retryIntervalSeconds, 20 * 60)

        viewModel.setT7AutomaticEjectEnabled(false)
        XCTAssertEqual(service.setAutomaticEnabledCalls, [false])
        XCTAssertTrue(viewModel.isT7ManualEjectAvailable)

        let updated = T7EjectScheduleConfiguration(
            startMinuteOfDay: 20 * 60 + 30,
            endMinuteOfDay: 22 * 60 + 45,
            retryIntervalSeconds: 30 * 60
        )
        viewModel.updateT7ScheduleConfiguration(updated)
        XCTAssertEqual(service.updatedScheduleConfigurations, [updated])

        let manual = await viewModel.runT7ManualEject()
        XCTAssertEqual(manual, service.manualResult)
        XCTAssertEqual(service.manualRunCount, 1)
    }

    func testAppViewModelT7ManualActionIsAvailableWhenAutomaticOffAndUnavailableWhileRunning() {
        let idleService = RecordingT7EjectUIService(
            isRunningValue: false,
            isAutomaticEnabledValue: false
        )
        let idleViewModel = AppViewModel(
            windowManager: MockWindowManager(),
            bootstrapAutoEngine: false,
            t7EjectService: idleService,
            bootstrapT7EjectScheduler: false
        )
        XCTAssertFalse(idleViewModel.isT7AutomaticEjectEnabled)
        XCTAssertTrue(idleViewModel.isT7ManualEjectAvailable)

        let runningService = RecordingT7EjectUIService(
            isRunningValue: true,
            isAutomaticEnabledValue: false
        )
        let runningViewModel = AppViewModel(
            windowManager: MockWindowManager(),
            bootstrapAutoEngine: false,
            t7EjectService: runningService,
            bootstrapT7EjectScheduler: false
        )
        XCTAssertFalse(runningViewModel.isT7ManualEjectAvailable)
    }

    func testAppViewModelPublishesWhenLiveT7ServiceRunningStateChanges() async throws {
        let (defaults, suiteName) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let runner = BlockingT7EjectProcessRunner()
        let service = makeService(defaults: defaults, runner: runner)
        let viewModel = AppViewModel(
            windowManager: MockWindowManager(),
            bootstrapAutoEngine: false,
            t7EjectService: service,
            bootstrapT7EjectScheduler: false
        )
        var publishCount = 0
        let cancellable = viewModel.objectWillChange.sink {
            publishCount += 1
        }
        defer { cancellable.cancel() }

        let runTask = Task { @MainActor in
            await service.runManualEject()
        }
        try await waitUntil { service.isRunning }

        XCTAssertGreaterThan(publishCount, 0)

        runner.complete(with: .init(
            terminationStatus: 0,
            stdout: try stdoutData(for: Self.result(status: .success, reason: nil)),
            stderr: ""
        ))
        _ = await runTask.value
    }

    func testAppViewModelFormatsConciseChineseT7LatestResultDisplay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let endedAt = Self.date("2026-06-06 20:15")
        let cases: [(String, T7EjectResult?, String, String?)] = [
            ("idle before first run", nil, "尚未运行", nil),
            ("success", Self.result(status: .success, reason: nil, endedAt: endedAt), "T7 已安全推出。", "上次运行：20:15"),
            ("idle not connected", Self.result(status: .idle, reason: .idleNotConnected, endedAt: endedAt), "未发现已连接的 T7。", "上次运行：20:15"),
            ("busy", Self.result(status: .failed, reason: .diskBusy, endedAt: endedAt), "T7 正在被占用，未强制推出。", "上次运行：20:15"),
            ("dissenter", Self.result(status: .failed, reason: .diskArbitrationDissented, endedAt: endedAt), "macOS 拒绝推出 T7，未强制推出。", "上次运行：20:15"),
            ("time machine", Self.result(status: .failed, reason: .timeMachineStillRunning, endedAt: endedAt), "Time Machine 仍在运行，未强制推出 T7。", "上次运行：20:15"),
            ("unsafe multiple target", Self.result(status: .failed, reason: .unsafeTargetMultipleDisks, endedAt: endedAt), "T7 目标解析到多个磁盘，未强制推出。", "上次运行：20:15"),
            ("unsafe internal target", Self.result(status: .failed, reason: .unsafeTargetInternalDisk, endedAt: endedAt), "目标看起来是内部磁盘，未强制推出。", "上次运行：20:15"),
            ("eject failed after unmount", Self.result(status: .failed, reason: .unmountSucceededEjectFailed, endedAt: endedAt), "T7 已卸载，但未强制推出。", "上次运行：20:15"),
            ("unexpected", Self.result(status: .failed, reason: .unexpectedError, endedAt: endedAt), "T7 推出时遇到未知错误，未强制推出。", "上次运行：20:15"),
            ("generic failed", Self.result(status: .failed, reason: nil, endedAt: endedAt), "T7 未强制推出，请稍后重试。", "上次运行：20:15"),
        ]

        for (name, result, expectedStatus, expectedTime) in cases {
            let display = AppViewModel.t7LatestResultDisplay(for: result, calendar: calendar)
            XCTAssertEqual(display.statusText, expectedStatus, name)
            XCTAssertEqual(display.runTimeText, expectedTime, name)
            if result?.status == .failed {
                XCTAssertTrue(display.statusText.contains("未强制推出"), name)
            }
        }
    }

    func testServiceScheduleUpdateClampsPersistsAndReschedulesActiveScheduler() async throws {
        let (defaults, suiteName) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let clock = MutableT7EjectServiceClock(Self.date("2026-06-06 12:00"))
        let service = makeService(
            defaults: defaults,
            runner: RecordingT7EjectProcessRunner(),
            clock: clock
        )
        service.startScheduler()
        XCTAssertTrue(service.isSchedulerRunningForTesting)

        service.updateScheduleConfiguration(T7EjectScheduleConfiguration(
            startMinuteOfDay: -20,
            endMinuteOfDay: 30 * 60,
            retryIntervalSeconds: 12
        ))

        XCTAssertTrue(service.isSchedulerRunningForTesting)
        XCTAssertEqual(service.scheduleConfiguration.startMinuteOfDay, 0)
        XCTAssertEqual(service.scheduleConfiguration.endMinuteOfDay, 23 * 60 + 59)
        XCTAssertEqual(service.scheduleConfiguration.retryIntervalSeconds, 60)
        XCTAssertEqual(defaults.integer(forKey: MalDazeDefaults.t7EjectScheduleStartMinuteOfDay), 0)
        XCTAssertEqual(defaults.integer(forKey: MalDazeDefaults.t7EjectScheduleEndMinuteOfDay), 23 * 60 + 59)
        XCTAssertEqual(defaults.integer(forKey: MalDazeDefaults.t7EjectRetryIntervalSeconds), 60)
        service.cancelScheduler()
    }

    func testAppViewModelQuitAppStopsT7LifecycleBeforeTerminatingInSource() throws {
        let source = try Self.productionSource(at: "MalDaze/AppViewModel.swift")
        let stopRange = try XCTUnwrap(source.range(of: "T7EjectAppLifecycleRegistry.shared.stopRegisteredService()"))
        let terminateRange = try XCTUnwrap(source.range(of: "NSApp.terminate(nil)"))

        XCTAssertLessThan(stopRange.lowerBound, terminateRange.lowerBound)
    }

    func testProductionSourcesDoNotInstallLaunchAgentCronOrDetachedScheduler() throws {
        for relativePath in [
            "MalDaze/T7Eject/T7EjectService.swift",
            "MalDaze/AppViewModel.swift",
        ] {
            let source = try Self.productionSource(at: relativePath)
            XCTAssertNil(
                source.range(
                    of: #"(?i)LaunchAgents?|cron|crontab|launchctl|Task\.detached"#,
                    options: .regularExpression
                ),
                relativePath
            )
        }
    }

    func testSchedulePolicySeamOwnsScheduleDecisionsAndServiceDelegatesToIt() throws {
        let source = try Self.productionSource(at: "MalDaze/T7Eject/T7EjectService.swift")

        XCTAssertTrue(source.contains("struct T7EjectSchedulePolicy"))
        XCTAssertTrue(source.contains("schedulePolicy"))
        XCTAssertTrue(source.contains("func isEligible("))
        XCTAssertTrue(source.contains("func nextAttemptDelay("))
        XCTAssertTrue(source.contains("func completionDayToken("))

        for oldPrivateServiceDecision in [
            "private func isScheduledRunEligible",
            "private func isWithinScheduleWindow",
            "private func nextSchedulerDelaySeconds",
            "private func countsAsDailyCompletion",
            "private func minuteOfDay",
            "private func dayToken",
        ] {
            XCTAssertFalse(source.contains(oldPrivateServiceDecision), oldPrivateServiceDecision)
        }
    }

    func testProductionHelperResolverPrefersBundledHelperLocationsBeforeDevFallback() throws {
        let source = try Self.productionSource(at: "MalDaze/T7Eject/T7EjectService.swift")

        XCTAssertTrue(source.contains("builtInPlugInsURL"))
        XCTAssertTrue(source.contains("Contents/Helpers"))
        XCTAssertTrue(source.contains("#if DEBUG"))
        XCTAssertTrue(source.contains("bundleURL.deletingLastPathComponent().appendingPathComponent(helperName)"))

        let productionOnlySource = Self.sourceByRemovingDebugBlocks(source)
        XCTAssertFalse(productionOnlySource.contains("bundleURL.deletingLastPathComponent()"))
    }

    func testProcessRunnerLaunchCheckAndProcessRunAreAtomicInRunState() throws {
        let source = try Self.productionSource(at: "MalDaze/T7Eject/T7EjectService.swift")
        let runnerClassStart = try XCTUnwrap(source.range(of: "final class T7EjectProcessRunner"))
        let launchMethodStart = try XCTUnwrap(source.range(of: "func launchProcessIfNoPendingFailure"))
        let runnerRunStart = try XCTUnwrap(
            source[runnerClassStart.lowerBound...]
                .range(of: "func run(executableURL: URL) async throws -> T7EjectProcessOutput")
        )
        let runnerRunEnd = try XCTUnwrap(
            source[runnerRunStart.upperBound...]
                .range(of: "private enum T7EjectRunSource")
        )
        let launchMethodSource = String(source[launchMethodStart.lowerBound..<runnerClassStart.lowerBound])

        let lockRange = try XCTUnwrap(launchMethodSource.range(of: "lock.lock()"))
        let processRunRange = try XCTUnwrap(launchMethodSource.range(of: "try process.run()"))
        let unlockAfterProcessRunRange = try XCTUnwrap(
            launchMethodSource[processRunRange.upperBound...].range(of: "lock.unlock()")
        )

        XCTAssertLessThan(lockRange.lowerBound, processRunRange.lowerBound)
        XCTAssertLessThan(processRunRange.upperBound, unlockAfterProcessRunRange.lowerBound)

        let runnerSource = String(source[runnerRunStart.lowerBound..<runnerRunEnd.lowerBound])
        XCTAssertNil(
            runnerSource.range(of: #"try\s+process\.run\(\)"#, options: .regularExpression),
            "T7EjectProcessRunner.run must launch through T7EjectProcessRunState."
        )
    }

    private static func result(
        status: T7EjectStatus,
        reason: T7EjectReason?,
        wholeDisk: String? = "disk4",
        volumes: [String] = ["Storage"],
        remainingMountedVolumes: [String] = [],
        endedAt: Date = Date(timeIntervalSince1970: 1_780_000_001)
    ) -> T7EjectResult {
        T7EjectResult(
            status: status,
            reason: reason,
            action: .safeEject,
            wholeDisk: wholeDisk,
            apfsContainer: wholeDisk == nil ? nil : "disk5",
            volumes: volumes,
            timeMachineWasRunning: false,
            timeMachineStopped: false,
            remainingMountedVolumes: remainingMountedVolumes,
            dissenterStatus: nil,
            dissenterMessage: nil,
            startedAt: Date(timeIntervalSince1970: 1_780_000_000),
            endedAt: endedAt,
            message: T7EjectResult.message(for: status, reason: reason)
        )
    }

    private static func date(_ text: String) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: Int(text.prefix(4)),
            month: Int(text.dropFirst(5).prefix(2)),
            day: Int(text.dropFirst(8).prefix(2)),
            hour: Int(text.dropFirst(11).prefix(2)),
            minute: Int(text.dropFirst(14).prefix(2))
        )
        return calendar.date(from: components)!
    }

    private static func productionSource(at relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private static func sourceByRemovingDebugBlocks(_ source: String) -> String {
        var output = source
        while let start = output.range(of: "#if DEBUG"),
              let end = output[start.upperBound...].range(of: "#endif") {
            output.removeSubrange(start.lowerBound..<end.upperBound)
        }
        return output
    }
}

@MainActor
private func makeService(
    defaults: UserDefaults,
    runner: any T7EjectProcessRunning,
    clock: MutableT7EjectServiceClock = MutableT7EjectServiceClock(Date(timeIntervalSince1970: 1_780_000_000)),
    helperURL: URL = URL(fileURLWithPath: "/tmp/T7EjectHelper"),
    logURL: URL? = nil
) -> T7EjectService {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    return T7EjectService(
        processRunner: runner,
        helperURLResolver: { helperURL },
        clock: clock,
        calendar: calendar,
        defaults: defaults,
        logURL: logURL
    )
}

private func stdoutData(for result: T7EjectResult) throws -> Data {
    Data((try result.stdoutJSONString() + "\n").utf8)
}

private func makeIsolatedDefaults() throws -> (UserDefaults, String) {
    let suiteName = "T7EjectServiceTests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return (defaults, suiteName)
}

private func makeTemporaryLogURL() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("T7EjectServiceTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent("t7-eject.jsonl")
}

private struct SignalAwareTemporaryScript {
    let directory: URL
    let executableURL: URL
    let startedMarkerURL: URL
    let terminatedMarkerURL: URL
}

private func makeSignalAwareTemporaryScript(
    name: String,
    terminationDelaySeconds: String
) throws -> SignalAwareTemporaryScript {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("T7EjectProcessRunnerTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let executableURL = directory.appendingPathComponent(name)
    let startedMarkerURL = directory.appendingPathComponent("started")
    let terminatedMarkerURL = directory.appendingPathComponent("terminated")
    try """
    #!/usr/bin/perl
    use strict;
    use warnings;
    $SIG{TERM} = sub {
        select(undef, undef, undef, \(terminationDelaySeconds));
        open(my $terminated, ">", \(perlDoubleQuoted(terminatedMarkerURL.path))) or die $!;
        print $terminated "terminated";
        close($terminated);
        exit 77;
    };
    open(my $started, ">", \(perlDoubleQuoted(startedMarkerURL.path))) or die $!;
    print $started "started";
    close($started);
    while (1) {
        select(undef, undef, undef, 0.05);
    }
    """.write(to: executableURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

    return SignalAwareTemporaryScript(
        directory: directory,
        executableURL: executableURL,
        startedMarkerURL: startedMarkerURL,
        terminatedMarkerURL: terminatedMarkerURL
    )
}

private func perlDoubleQuoted(_ value: String) -> String {
    var escaped = value
    escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
    escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
    escaped = escaped.replacingOccurrences(of: "$", with: "\\$")
    escaped = escaped.replacingOccurrences(of: "@", with: "\\@")
    return "\"\(escaped)\""
}

private func readLogEntries(at url: URL) throws -> [LoggedT7EjectEntry] {
    let contents = try String(contentsOf: url, encoding: .utf8)
    let decoder = T7EjectResult.decoder()
    return try contents
        .split(separator: "\n", omittingEmptySubsequences: true)
        .map { try decoder.decode(LoggedT7EjectEntry.self, from: Data($0.utf8)) }
}

@MainActor
private func waitUntil(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    _ condition: @escaping @MainActor () -> Bool
) async throws {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    while !condition() {
        if DispatchTime.now().uptimeNanoseconds > deadline {
            XCTFail("Timed out waiting for condition")
            return
        }
        try await Task.sleep(nanoseconds: 1_000_000)
    }
}

private struct LoggedT7EjectEntry: Decodable {
    let timestamp: Date
    let helperURL: String?
    let terminationStatus: Int32?
    let stderr: String?
    let error: String?
    let processFailure: String?
    let result: T7EjectResult
}

@MainActor
private final class RecordingT7EjectProcessRunner: T7EjectProcessRunning {
    private var outputs: [Result<T7EjectProcessOutput, Error>]
    private(set) var requestedExecutableURLs: [URL] = []

    init(outputs: [Result<T7EjectProcessOutput, Error>] = []) {
        self.outputs = outputs
    }

    func run(executableURL: URL) async throws -> T7EjectProcessOutput {
        requestedExecutableURLs.append(executableURL)
        guard !outputs.isEmpty else {
            return .init(terminationStatus: 0, stdout: Data(), stderr: "")
        }
        return try outputs.removeFirst().get()
    }

    func cancel() {}
}

@MainActor
private final class BlockingT7EjectProcessRunner: T7EjectProcessRunning {
    private var continuation: CheckedContinuation<T7EjectProcessOutput, Error>?
    private(set) var requestedExecutableURLs: [URL] = []
    private(set) var cancelCount = 0

    func run(executableURL: URL) async throws -> T7EjectProcessOutput {
        requestedExecutableURLs.append(executableURL)
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func complete(with output: T7EjectProcessOutput) {
        continuation?.resume(returning: output)
        continuation = nil
    }

    func cancel() {
        cancelCount += 1
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }
}

private final class MutableT7EjectServiceClock: T7EjectServiceClock {
    var now: Date

    init(_ now: Date) {
        self.now = now
    }

    func currentDate() -> Date {
        now
    }
}

@MainActor
private final class RecordingT7EjectServiceLifecycle: T7EjectServiceLifecycle {
    private(set) var startCount = 0
    private(set) var cancelCount = 0
    private(set) var stopCount = 0
    var isRunning: Bool { false }
    var latestResult: T7EjectResult? { nil }
    var isAutomaticEnabled: Bool { true }
    var isSchedulerRunningForTesting: Bool { startCount > cancelCount + stopCount }

    func startScheduler() {
        startCount += 1
    }

    func cancelScheduler() {
        cancelCount += 1
    }

    func stop() {
        stopCount += 1
    }
}

@MainActor
private final class RecordingT7EjectUIService: T7EjectServiceUIControlling {
    private(set) var startCount = 0
    private(set) var cancelCount = 0
    private(set) var stopCount = 0
    private(set) var manualRunCount = 0
    private(set) var setAutomaticEnabledCalls: [Bool] = []
    private(set) var updatedScheduleConfigurations: [T7EjectScheduleConfiguration] = []

    var latestResultValue: T7EjectResult?
    var isRunningValue: Bool
    var isAutomaticEnabledValue: Bool
    var scheduleConfigurationValue: T7EjectScheduleConfiguration
    let manualResult: T7EjectResult

    var isRunning: Bool { isRunningValue }
    var latestResult: T7EjectResult? { latestResultValue }
    var isAutomaticEnabled: Bool { isAutomaticEnabledValue }
    var scheduleConfiguration: T7EjectScheduleConfiguration { scheduleConfigurationValue }
    var isSchedulerRunningForTesting: Bool { startCount > cancelCount + stopCount }

    init(
        latestResultValue: T7EjectResult? = nil,
        isRunningValue: Bool = false,
        isAutomaticEnabledValue: Bool = true,
        scheduleConfigurationValue: T7EjectScheduleConfiguration = .default,
        manualResult: T7EjectResult = T7EjectResult.idleNotConnected()
    ) {
        self.latestResultValue = latestResultValue
        self.isRunningValue = isRunningValue
        self.isAutomaticEnabledValue = isAutomaticEnabledValue
        self.scheduleConfigurationValue = scheduleConfigurationValue
        self.manualResult = manualResult
    }

    func startScheduler() {
        startCount += 1
    }

    func cancelScheduler() {
        cancelCount += 1
    }

    func stop() {
        stopCount += 1
    }

    func setAutomaticEnabled(_ enabled: Bool) {
        setAutomaticEnabledCalls.append(enabled)
        isAutomaticEnabledValue = enabled
    }

    func updateScheduleConfiguration(_ configuration: T7EjectScheduleConfiguration) {
        updatedScheduleConfigurations.append(configuration)
        scheduleConfigurationValue = configuration
    }

    func runManualEject() async -> T7EjectResult {
        manualRunCount += 1
        latestResultValue = manualResult
        return manualResult
    }
}

private struct SpawnFailure: Error {}
