import XCTest
@testable import MalDaze

final class HermesRuntimeTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
        try super.tearDownWithError()
    }

    func testPathsPreserveHermesContractLocations() {
        let home = URL(fileURLWithPath: "/tmp/maldaze-hermes-runtime-test/.hermes", isDirectory: true)
        let paths = HermesRuntimePaths(hermesHome: home)

        XCTAssertEqual(paths.hermesHome.path, home.path)
        XCTAssertEqual(paths.scheduleScriptURL.path, home.appendingPathComponent("scripts/schedule.py").path)
        XCTAssertEqual(paths.learningProjectsFileURL.path, home.appendingPathComponent("data/learning-assistant/projects.json").path)
        XCTAssertEqual(paths.nutritionRecommendScriptURL.path, home.appendingPathComponent("data/nutrition/recommend.py").path)
        XCTAssertEqual(paths.nutritionDataDirectoryURL.path, home.appendingPathComponent("data/nutrition", isDirectory: true).path)
    }

    func testRunnerCapturesStdoutStderrAndTerminationStatus() async throws {
        let directory = try makeTemporaryDirectory()
        let script = try writeShellScript(
            in: directory,
            name: "echo-status.sh",
            body: """
            echo "out:$1"
            echo "err:$1" >&2
            exit 7
            """
        )

        let result = try await HermesProcessRunner().run(
            executablePath: "/bin/sh",
            scriptURL: script,
            arguments: ["value"],
            environment: ["HERMES_TEST": "1"],
            timeoutSeconds: 2
        )

        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "out:value")
        XCTAssertEqual(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines), "err:value")
        XCTAssertEqual(result.terminationStatus, 7)
        XCTAssertFalse(result.timedOut)
    }

    func testRunnerTerminatesOnTimeout() async throws {
        let directory = try makeTemporaryDirectory()
        let script = try writeShellScript(
            in: directory,
            name: "sleep.sh",
            body: """
            sleep 2
            echo "late"
            """
        )

        let result = try await HermesProcessRunner().run(
            executablePath: "/bin/sh",
            scriptURL: script,
            arguments: [],
            environment: [:],
            timeoutSeconds: 0.1
        )

        XCTAssertTrue(result.timedOut)
        XCTAssertNotEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "late")
    }

    func testRunnerDrainsLargeStdoutWhileProcessRuns() async throws {
        let directory = try makeTemporaryDirectory()
        let script = try writeShellScript(
            in: directory,
            name: "large-output.sh",
            body: """
            yes x | head -c 1048576
            """
        )

        let result = try await HermesProcessRunner().run(
            executablePath: "/bin/sh",
            scriptURL: script,
            arguments: [],
            environment: [:],
            timeoutSeconds: 1
        )

        XCTAssertFalse(result.timedOut)
        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertEqual(result.stdout.utf8.count, 1_048_576)
        XCTAssertTrue(result.stderr.isEmpty)
    }

    func testRunnerReturnsPromptlyWhenTimedOutProcessIgnoresTerminate() async throws {
        let directory = try makeTemporaryDirectory()
        let script = try writeShellScript(
            in: directory,
            name: "ignore-term.sh",
            body: """
            trap '' TERM
            sleep 2
            echo "late"
            """
        )

        let start = Date()
        let result = try await HermesProcessRunner().run(
            executablePath: "/bin/sh",
            scriptURL: script,
            arguments: [],
            environment: [:],
            timeoutSeconds: 0.1
        )
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertTrue(result.timedOut)
        XCTAssertLessThan(elapsed, 1.0)
        XCTAssertNotEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "late")
    }

    func testRunnerCancellationTerminatesProcessAndPreventsLateOutput() async throws {
        let directory = try makeTemporaryDirectory()
        let marker = directory.appendingPathComponent("cancel-marker.txt")
        let script = try writeShellScript(
            in: directory,
            name: "cancel-cleanup.sh",
            body: """
            sleep 0.4
            echo "late" > "\(marker.path)"
            """
        )

        let task = Task {
            try await HermesProcessRunner().run(
                executablePath: "/bin/sh",
                scriptURL: script,
                arguments: [],
                environment: [:],
                timeoutSeconds: nil
            )
        }
        try await Task.sleep(nanoseconds: 50_000_000)

        let start = Date()
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertLessThan(Date().timeIntervalSince(start), 1.0)
        }

        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testRunnerTimeoutTerminatesDescendantProcesses() async throws {
        let directory = try makeTemporaryDirectory()
        let marker = directory.appendingPathComponent("descendant-marker.txt")
        let script = try writeShellScript(
            in: directory,
            name: "descendant-cleanup.sh",
            body: """
            ( trap '' HUP TERM; sleep 0.4; echo "child" > "\(marker.path)" ) &
            trap '' HUP TERM
            sleep 2
            """
        )

        let result = try await HermesProcessRunner().run(
            executablePath: "/bin/sh",
            scriptURL: script,
            arguments: [],
            environment: [:],
            timeoutSeconds: 0.1
        )

        XCTAssertTrue(result.timedOut)
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testRunnerTimeoutKillsDescendantEvenWhenParentExitsAfterTerminate() async throws {
        let directory = try makeTemporaryDirectory()
        let marker = directory.appendingPathComponent("descendant-after-parent-exit-marker.txt")
        let ready = directory.appendingPathComponent("descendant-after-parent-exit-ready.txt")
        let script = try writeShellScript(
            in: directory,
            name: "descendant-after-parent-exit.py",
            body: """
            import os
            import signal
            import subprocess
            import time

            subprocess.Popen([
                "/usr/bin/python3",
                "-c",
                'import signal, time; signal.signal(signal.SIGHUP, signal.SIG_IGN); signal.signal(signal.SIGTERM, signal.SIG_IGN); open("\(ready.path)", "w").write("ready"); time.sleep(0.4); open("\(marker.path)", "w").write("child")',
            ])
            while not os.path.exists("\(ready.path)"):
                time.sleep(0.01)
            time.sleep(2)
            """
        )

        let result = try await HermesProcessRunner().run(
            executablePath: "/usr/bin/python3",
            scriptURL: script,
            arguments: [],
            environment: [:],
            timeoutSeconds: 0.1
        )

        XCTAssertTrue(result.timedOut)
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testLearningCLIUsesSharedRuntimeAndPreservesHermesPaths() async throws {
        let directory = try makeTemporaryDirectory()
        let hermesHome = directory.appendingPathComponent(".hermes", isDirectory: true)
        let scriptsDirectory = hermesHome.appendingPathComponent("scripts", isDirectory: true)
        try FileManager.default.createDirectory(at: scriptsDirectory, withIntermediateDirectories: true)
        let script = try writeShellScript(
            in: scriptsDirectory,
            name: "schedule.py",
            body: """
            test "$HERMES_HOME" = "\(hermesHome.path)" || exit 23
            echo '{"date":"2026-06-13","is_rest_day":false,"pending_count":0,"pending":[],"study":{"tasks":[],"total_minutes":0,"budget":300},"review":{"tasks":[],"total_minutes":0,"budget":60},"warnings":[]}'
            """
        )
        XCTAssertEqual(script.path, hermesHome.appendingPathComponent("scripts/schedule.py").path)

        let cli = ProcessHermesScheduleCLI(hermesHome: hermesHome, pythonExecutable: "/bin/sh")
        let today = try await cli.fetchToday()

        XCTAssertEqual(today.date, "2026-06-13")
        XCTAssertEqual(cli.projectsFileURL.path, hermesHome.appendingPathComponent("data/learning-assistant/projects.json").path)
    }

    func testNutritionCLIUsesSharedRuntimeAndPreservesTimeoutMessage() async throws {
        let directory = try makeTemporaryDirectory()
        let hermesHome = directory.appendingPathComponent(".hermes", isDirectory: true)
        let nutritionDirectory = hermesHome.appendingPathComponent("data/nutrition", isDirectory: true)
        try FileManager.default.createDirectory(at: nutritionDirectory, withIntermediateDirectories: true)
        let script = try writeShellScript(
            in: nutritionDirectory,
            name: "recommend.py",
            body: """
            test "$NUTRITION_DATA_DIR" = "\(nutritionDirectory.path)" || exit 24
            sleep 2
            echo '{"logged":true}'
            """
        )
        XCTAssertEqual(script.path, hermesHome.appendingPathComponent("data/nutrition/recommend.py").path)

        let cli = ProcessNutritionHermesCLI(
            hermesHome: hermesHome,
            pythonExecutable: "/bin/sh",
            timeoutSeconds: 0.1
        )

        do {
            try await cli.logFood(name: "banana", grams: 120)
            XCTFail("Expected timeout")
        } catch let error as NutritionCLIError {
            XCTAssertEqual(error.message, "记录饮食超时（0s）")
        }
    }

    func testCLIImplementationsDelegateToSharedRunnerSource() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("MalDaze")

        let scheduleCLI = try String(contentsOf: sourceRoot.appendingPathComponent("LearningDeskPanel/HermesScheduleCLI.swift"))
        XCTAssertTrue(scheduleCLI.contains("HermesRuntimePaths"))
        XCTAssertTrue(scheduleCLI.contains("HermesProcessRunner"))
        XCTAssertFalse(scheduleCLI.contains("waitUntilExit()"))

        let nutritionCLI = try String(contentsOf: sourceRoot.appendingPathComponent("NutritionToday/NutritionHermesCLI.swift"))
        XCTAssertTrue(nutritionCLI.contains("HermesRuntimePaths"))
        XCTAssertTrue(nutritionCLI.contains("HermesProcessRunner"))
    }

    func testPipeHandlersDrainThroughSynchronizedCapture() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("MalDaze")
        let runtimeSource = try String(contentsOf: sourceRoot.appendingPathComponent("HermesRuntime.swift"))

        XCTAssertFalse(runtimeSource.contains("append(handle.availableData)"))
        XCTAssertTrue(runtimeSource.contains("readAvailableData(from:"))
    }

    func testTimeoutKillIsNotConditionalOnDirectChildStillRunning() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("MalDaze")
        let runtimeSource = try String(contentsOf: sourceRoot.appendingPathComponent("HermesRuntime.swift"))

        XCTAssertFalse(runtimeSource.contains("""
        if process.isRunning {
                    process.terminateProcessGroup(signal: SIGKILL)
                }
        """))
        XCTAssertTrue(runtimeSource.contains("terminateProcessGroupThenKill"))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("maldaze-hermes-runtime-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        return directory
    }

    @discardableResult
    private func writeShellScript(in directory: URL, name: String, body: String) throws -> URL {
        let script = directory.appendingPathComponent(name)
        try body.write(to: script, atomically: true, encoding: .utf8)
        return script
    }
}
