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
    var processRunner: HermesProcessRunner

    init(
        hermesHome: URL = ProcessNutritionHermesCLI.defaultHermesHome(),
        pythonExecutable: String = "/usr/bin/python3",
        timeoutSeconds: TimeInterval = 60,
        processRunner: HermesProcessRunner = HermesProcessRunner()
    ) {
        self.hermesHome = hermesHome
        self.pythonExecutable = pythonExecutable
        self.timeoutSeconds = timeoutSeconds
        self.processRunner = processRunner
    }

    static func defaultHermesHome() -> URL {
        HermesRuntimePaths.defaultHermesHome()
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
        let paths = HermesRuntimePaths(hermesHome: hermesHome)
        let script = paths.nutritionRecommendScriptURL
        let result: HermesProcessResult
        do {
            result = try await processRunner.run(
                executablePath: pythonExecutable,
                scriptURL: script,
                arguments: arguments,
                environment: ["NUTRITION_DATA_DIR": paths.nutritionDataDirectoryURL.path],
                timeoutSeconds: timeoutSeconds
            )
        } catch HermesProcessRunnerError.missingExecutable,
                HermesProcessRunnerError.missingScript {
            throw NutritionCLIError(
                message: "未找到 Hermes 营养脚本：\(script.path)"
            )
        } catch {
            throw error
        }

        if result.timedOut {
            throw NutritionCLIError(message: "记录饮食超时（\(Int(timeoutSeconds))s）")
        }

        if result.terminationStatus != 0 {
            if let message = NutritionHermesCLIFormatting.errorMessage(from: result.stdout) {
                throw NutritionCLIError(message: message)
            }
            let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !detail.isEmpty {
                throw NutritionCLIError(message: detail)
            }
            throw NutritionCLIError(message: "recommend.py 退出码 \(result.terminationStatus)")
        }

        if let message = NutritionHermesCLIFormatting.errorMessage(from: result.stdout) {
            throw NutritionCLIError(message: message)
        }

        return result.stdout
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
