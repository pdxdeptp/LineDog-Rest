import Foundation

protocol HermesScheduleCLI: Sendable {
    func runRollover() async throws
    func fetchToday() async throws -> HermesTodayResponse
    func complete(taskId: String, actualMinutes: Int?) async throws -> HermesCompleteResponse
    func move(taskId: String, newDate: String, dryRun: Bool) async throws -> HermesMoveResponse
    func insert(projectId: String, title: String, duration: Int, date: String) async throws -> HermesInsertResponse
    func remove(taskId: String) async throws -> HermesRemoveResponse
    func review(taskId: String, result: String) async throws -> HermesReviewResponse
    func weekLoad(fromDate: String?, days: Int) async throws -> HermesWeekLoadResponse
    func scheduleRange(month: String?, fromDate: String?, toDate: String?) async throws -> HermesScheduleRangeResponse
    func fetchStatus() async throws -> [HermesStatusProject]
    func setDeadline(projectId: String, deadline: String, dryRun: Bool) async throws -> HermesSetDeadlineResponse
    func deleteProject(projectId: String) async throws -> HermesDeleteProjectResponse
    var projectsFileURL: URL { get }
}

struct ProcessHermesScheduleCLI: HermesScheduleCLI {
    var hermesHome: URL
    var pythonExecutable: String

    init(
        hermesHome: URL = ProcessHermesScheduleCLI.defaultHermesHome(),
        pythonExecutable: String = "/usr/bin/python3"
    ) {
        self.hermesHome = hermesHome
        self.pythonExecutable = pythonExecutable
    }

    static func defaultHermesHome() -> URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".hermes", isDirectory: true)
    }

    func runRollover() async throws {
        _ = try await runSchedule(arguments: ["rollover"])
    }

    func fetchToday() async throws -> HermesTodayResponse {
        let stdout = try await runSchedule(arguments: ["today"])
        return try HermesScheduleJSON.decode(HermesTodayResponse.self, from: stdout)
    }

    func complete(taskId: String, actualMinutes: Int? = nil) async throws -> HermesCompleteResponse {
        var args = ["complete", "--task-id", taskId]
        if let actualMinutes {
            args += ["--actual-minutes", String(actualMinutes)]
        }
        let stdout = try await runSchedule(arguments: args)
        return try HermesScheduleJSON.decode(HermesCompleteResponse.self, from: stdout)
    }

    func move(taskId: String, newDate: String, dryRun: Bool) async throws -> HermesMoveResponse {
        var args = ["move", "--task-id", taskId, "--new-date", newDate]
        if dryRun {
            args.append("--dry-run")
        }
        let stdout = try await runSchedule(arguments: args)
        return try HermesScheduleJSON.decode(HermesMoveResponse.self, from: stdout)
    }

    func insert(projectId: String, title: String, duration: Int, date: String) async throws -> HermesInsertResponse {
        let stdout = try await runSchedule(arguments: [
            "insert",
            "--project-id", projectId,
            "--title", title,
            "--duration", String(duration),
            "--date", date,
        ])
        return try HermesScheduleJSON.decode(HermesInsertResponse.self, from: stdout)
    }

    func remove(taskId: String) async throws -> HermesRemoveResponse {
        let stdout = try await runSchedule(arguments: ["remove", "--task-id", taskId])
        return try HermesScheduleJSON.decode(HermesRemoveResponse.self, from: stdout)
    }

    func review(taskId: String, result: String) async throws -> HermesReviewResponse {
        let stdout = try await runSchedule(arguments: [
            "review", "--task-id", taskId, "--result", result,
        ])
        return try HermesScheduleJSON.decode(HermesReviewResponse.self, from: stdout)
    }

    func weekLoad(fromDate: String?, days: Int) async throws -> HermesWeekLoadResponse {
        var args = ["week-load", "--days", String(days)]
        if let fromDate {
            args += ["--from", fromDate]
        }
        let stdout = try await runSchedule(arguments: args)
        return try HermesScheduleJSON.decode(HermesWeekLoadResponse.self, from: stdout)
    }

    func scheduleRange(
        month: String?,
        fromDate: String?,
        toDate: String?
    ) async throws -> HermesScheduleRangeResponse {
        var args = ["schedule-range"]
        if let month {
            args += ["--month", month]
        } else {
            if let fromDate { args += ["--from", fromDate] }
            if let toDate { args += ["--to", toDate] }
        }
        let stdout = try await runSchedule(arguments: args)
        return try HermesScheduleJSON.decode(HermesScheduleRangeResponse.self, from: stdout)
    }

    func fetchStatus() async throws -> [HermesStatusProject] {
        let stdout = try await runSchedule(arguments: ["status"])
        return try HermesScheduleJSON.decode([HermesStatusProject].self, from: stdout)
    }

    func setDeadline(projectId: String, deadline: String, dryRun: Bool = false) async throws -> HermesSetDeadlineResponse {
        var arguments = [
            "set-deadline",
            "--project-id", projectId,
            "--deadline", deadline,
        ]
        if dryRun {
            arguments.append("--dry-run")
        }
        let stdout = try await runSchedule(arguments: arguments)
        return try HermesScheduleJSON.decode(HermesSetDeadlineResponse.self, from: stdout)
    }

    func deleteProject(projectId: String) async throws -> HermesDeleteProjectResponse {
        let stdout = try await runSchedule(arguments: [
            "delete-project",
            "--project-id", projectId,
        ])
        return try HermesScheduleJSON.decode(HermesDeleteProjectResponse.self, from: stdout)
    }

    var projectsFileURL: URL {
        hermesHome
            .appendingPathComponent("data/learning-assistant/projects.json", isDirectory: false)
    }

    private func runSchedule(arguments: [String]) async throws -> String {
        let script = hermesHome.appendingPathComponent("scripts/schedule.py")
        guard FileManager.default.isExecutableFile(atPath: pythonExecutable),
              FileManager.default.fileExists(atPath: script.path)
        else {
            throw HermesCLIError(
                message: "未找到 Hermes：请确认 \(script.path) 存在且 python3 可执行。"
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonExecutable)
        process.arguments = [script.path] + arguments
        var env = ProcessInfo.processInfo.environment
        env["HERMES_HOME"] = hermesHome.path
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            if let err = try? HermesScheduleJSON.decode(HermesErrorOnly.self, from: stdout), let message = err.error {
                throw HermesCLIError(message: message)
            }
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !detail.isEmpty {
                throw HermesCLIError(message: detail)
            }
            throw HermesCLIError(message: "schedule.py 退出码 \(process.terminationStatus)")
        }

        return stdout
    }
}

private struct HermesErrorOnly: Decodable {
    let error: String?
}
