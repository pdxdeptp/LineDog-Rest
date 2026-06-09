import Foundation

struct NutritionCLIError: Error, LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

protocol NutritionHermesCLI: Sendable {
    func logFood(name: String, grams: Double) async throws
}

struct ProcessNutritionHermesCLI: NutritionHermesCLI {
    var hermesHome: URL
    var pythonExecutable: String
    var timeoutSeconds: TimeInterval

    init(
        hermesHome: URL = ProcessNutritionHermesCLI.defaultHermesHome(),
        pythonExecutable: String = "/usr/bin/python3",
        timeoutSeconds: TimeInterval = 60
    ) {
        self.hermesHome = hermesHome
        self.pythonExecutable = pythonExecutable
        self.timeoutSeconds = timeoutSeconds
    }

    static func defaultHermesHome() -> URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".hermes", isDirectory: true)
    }

    func logFood(name: String, grams: Double) async throws {
        let gramsText = NutritionHermesCLIFormatting.gramsArgument(grams)
        let stdout = try await runRecommend(arguments: ["log", name, gramsText])
        if let message = NutritionHermesCLIFormatting.errorMessage(from: stdout) {
            throw NutritionCLIError(message: message)
        }
        guard NutritionHermesCLIFormatting.logSucceeded(from: stdout) else {
            throw NutritionCLIError(message: "记录响应异常，请确认食物名在 foods.json 中存在。")
        }
    }

    private func runRecommend(arguments: [String]) async throws -> String {
        let script = hermesHome.appendingPathComponent("data/nutrition/recommend.py")
        guard FileManager.default.isExecutableFile(atPath: pythonExecutable),
              FileManager.default.fileExists(atPath: script.path)
        else {
            throw NutritionCLIError(
                message: "未找到 Hermes 营养脚本：\(script.path)"
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonExecutable)
        process.arguments = [script.path] + arguments
        var env = ProcessInfo.processInfo.environment
        env["NUTRITION_DATA_DIR"] = script.deletingLastPathComponent().path
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        if process.isRunning {
            process.terminate()
            throw NutritionCLIError(message: "记录饮食超时（\(Int(timeoutSeconds))s）")
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            if let message = NutritionHermesCLIFormatting.errorMessage(from: stdout) {
                throw NutritionCLIError(message: message)
            }
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !detail.isEmpty {
                throw NutritionCLIError(message: detail)
            }
            throw NutritionCLIError(message: "recommend.py 退出码 \(process.terminationStatus)")
        }

        if let message = NutritionHermesCLIFormatting.errorMessage(from: stdout) {
            throw NutritionCLIError(message: message)
        }

        return stdout
    }
}

enum NutritionHermesCLIFormatting {
    static func gramsArgument(_ grams: Double) -> String {
        if grams.rounded() == grams {
            return String(Int(grams.rounded()))
        }
        return String(format: "%.1f", grams)
    }

    static func errorMessage(from stdout: String) -> String? {
        guard let data = stdout.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if let message = root["message"] as? String, !message.isEmpty {
            return message
        }
        if let error = root["error"] as? String, !error.isEmpty {
            return error
        }
        if root["error"] as? Bool == true, let message = root["message"] as? String {
            return message
        }
        return nil
    }

    static func logSucceeded(from stdout: String) -> Bool {
        guard let data = stdout.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        return root["logged"] != nil
    }
}
