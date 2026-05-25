import Foundation

enum GeminiRemindersAPIError: Error, LocalizedError {
    case invalidURL
    case emptyResponse
    case noCandidates
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Gemini request URL."
        case .emptyResponse:
            return "Gemini returned an empty response."
        case .noCandidates:
            return "Gemini response did not include candidate text."
        case .httpStatus(let statusCode):
            return "Gemini request failed with HTTP status \(statusCode)."
        }
    }
}

enum ReminderLLMAPIError: Error, LocalizedError {
    case invalidURL
    case emptyResponse
    case noChoices
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid reminder LLM request URL."
        case .emptyResponse:
            return "The reminder LLM provider returned an empty response."
        case .noChoices:
            return "The reminder LLM provider response did not include message text."
        case .httpStatus(let statusCode):
            return "The reminder LLM provider request failed with HTTP status \(statusCode)."
        }
    }
}

/// Gemini `generateContent`，JSON 输出；带请求超时（PRD 3.5s）。
protocol GeminiRemindersGenerating: AnyObject {
    func generateStructuredReminderJSON(
        systemPrompt: String,
        userText: String,
        apiKey: String,
        timeoutSeconds: TimeInterval
    ) async throws -> String
}

protocol ReminderLLMGenerating: AnyObject, Sendable {
    func generateStructuredReminderJSON(
        provider: LLMProviderID,
        model: String,
        systemPrompt: String,
        userText: String,
        apiKey: String,
        timeoutSeconds: TimeInterval
    ) async throws -> String
}

final class GeminiRemindersAPIClient: GeminiRemindersGenerating {
    private let urlSessionConfiguration: URLSessionConfiguration

    init(urlSessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.ephemeral) {
        self.urlSessionConfiguration = urlSessionConfiguration
    }

    func generateStructuredReminderJSON(
        systemPrompt: String,
        userText: String,
        apiKey: String,
        timeoutSeconds: TimeInterval
    ) async throws -> String {
        let modelName = MalDazeGeminiModelCatalog.modelIdForAPI()
        return try await generateStructuredReminderJSON(
            model: modelName,
            systemPrompt: systemPrompt,
            userText: userText,
            apiKey: apiKey,
            timeoutSeconds: timeoutSeconds
        )
    }

    func generateStructuredReminderJSON(
        model: String,
        systemPrompt: String,
        userText: String,
        apiKey: String,
        timeoutSeconds: TimeInterval
    ) async throws -> String {
        let modelName = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let encKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey
        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(encKey)"
        guard let url = URL(string: urlStr) else { throw GeminiRemindersAPIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": systemPrompt] as [String: String]]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": userText] as [String: String]]
                ] as [String: Any]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.2
            ] as [String: Any]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let session = makeSession(timeoutSeconds: timeoutSeconds)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw GeminiRemindersAPIError.emptyResponse }
        guard (200 ... 299).contains(http.statusCode) else {
            throw GeminiRemindersAPIError.httpStatus(http.statusCode)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String,
            !text.isEmpty
        else {
            throw GeminiRemindersAPIError.noCandidates
        }
        return text
    }

    private func makeSession(timeoutSeconds: TimeInterval) -> URLSession {
        let config = (urlSessionConfiguration.copy() as? URLSessionConfiguration) ?? URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeoutSeconds
        config.timeoutIntervalForResource = timeoutSeconds + 0.5
        return URLSession(configuration: config)
    }
}

final class ReminderLLMAPIClient: ReminderLLMGenerating, @unchecked Sendable {
    private let gemini: GeminiRemindersAPIClient
    private let urlSessionConfiguration: URLSessionConfiguration

    init(urlSessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.ephemeral) {
        self.urlSessionConfiguration = urlSessionConfiguration
        self.gemini = GeminiRemindersAPIClient(urlSessionConfiguration: urlSessionConfiguration)
    }

    func generateStructuredReminderJSON(
        provider: LLMProviderID,
        model: String,
        systemPrompt: String,
        userText: String,
        apiKey: String,
        timeoutSeconds: TimeInterval
    ) async throws -> String {
        switch provider {
        case .gemini:
            return try await gemini.generateStructuredReminderJSON(
                model: model,
                systemPrompt: systemPrompt,
                userText: userText,
                apiKey: apiKey,
                timeoutSeconds: timeoutSeconds
            )
        case .openai:
            return try await generateOpenAICompatibleReminderJSON(
                endpoint: "https://api.openai.com/v1/chat/completions",
                model: model,
                systemPrompt: systemPrompt,
                userText: userText,
                apiKey: apiKey,
                timeoutSeconds: timeoutSeconds
            )
        case .deepseek:
            return try await generateOpenAICompatibleReminderJSON(
                endpoint: "https://api.deepseek.com/chat/completions",
                model: model,
                systemPrompt: systemPrompt,
                userText: userText,
                apiKey: apiKey,
                timeoutSeconds: timeoutSeconds
            )
        }
    }

    private func generateOpenAICompatibleReminderJSON(
        endpoint: String,
        model: String,
        systemPrompt: String,
        userText: String,
        apiKey: String,
        timeoutSeconds: TimeInterval
    ) async throws -> String {
        guard let url = URL(string: endpoint) else { throw ReminderLLMAPIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userText],
            ],
            "temperature": 0.2,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let session = makeSession(timeoutSeconds: timeoutSeconds)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw ReminderLLMAPIError.emptyResponse }
        guard (200 ... 299).contains(http.statusCode) else {
            throw ReminderLLMAPIError.httpStatus(http.statusCode)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let text = message["content"] as? String,
            !text.isEmpty
        else {
            throw ReminderLLMAPIError.noChoices
        }
        return text
    }

    private func makeSession(timeoutSeconds: TimeInterval) -> URLSession {
        let config = (urlSessionConfiguration.copy() as? URLSessionConfiguration) ?? URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeoutSeconds
        config.timeoutIntervalForResource = timeoutSeconds + 0.5
        return URLSession(configuration: config)
    }
}
