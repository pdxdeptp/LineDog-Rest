import Foundation

protocol HermesScheduleCLI: Sendable {
    func runRollover() async throws
    func fetchToday() async throws -> HermesTodayResponse
    func complete(taskId: String) async throws -> HermesCompleteResponse
    func move(taskId: String, newDate: String, dryRun: Bool) async throws -> HermesMoveResponse
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

    func complete(taskId: String) async throws -> HermesCompleteResponse {
        let stdout = try await runSchedule(arguments: ["complete", "--task-id", taskId])
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
