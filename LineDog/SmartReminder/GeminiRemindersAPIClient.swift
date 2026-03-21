import Foundation

enum GeminiRemindersAPIError: Error {
    case invalidURL
    case emptyResponse
    case noCandidates
    case httpStatus(Int)
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

final class GeminiRemindersAPIClient: GeminiRemindersGenerating {
    /// 轻量快速模型（PRD：Gemini 家族快速 API）。
    private let modelName = "gemini-2.0-flash"

    func generateStructuredReminderJSON(
        systemPrompt: String,
        userText: String,
        apiKey: String,
        timeoutSeconds: TimeInterval
    ) async throws -> String {
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

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeoutSeconds
        config.timeoutIntervalForResource = timeoutSeconds + 0.5
        let session = URLSession(configuration: config)

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
}
