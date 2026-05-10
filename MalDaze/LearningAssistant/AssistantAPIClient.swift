import Foundation

// MARK: - Error Types

/// 后端离线或无法连接时抛出此错误。
struct AssistantOfflineError: Error, LocalizedError {
    var errorDescription: String? { "学习助手后端离线或无法连接（localhost:8765）" }
}

/// 404 + {"error":"thread_not_found"} 时抛出此错误。
struct ThreadNotFoundError: Error {}

// MARK: - Response Models

struct TodayBriefing: Codable {
    let tasks: [AssistantTask]
    let totalMinutes: Int
    let highlights: String

    enum CodingKeys: String, CodingKey {
        case tasks
        case totalMinutes = "total_minutes"
        case highlights
    }
}

struct AssistantTask: Codable, Identifiable {
    let id: Int
    let title: String
    let targetMinutes: Int
    let completedAt: String?
    let resourceTitle: String?
    let priority: Int
    let resourceURL: URL?
    let unitURL: URL?

    init(
        id: Int,
        title: String,
        targetMinutes: Int,
        completedAt: String?,
        resourceTitle: String?,
        priority: Int,
        resourceURL: URL? = nil,
        unitURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.targetMinutes = targetMinutes
        self.completedAt = completedAt
        self.resourceTitle = resourceTitle
        self.priority = priority
        self.resourceURL = resourceURL
        self.unitURL = unitURL
    }

    var isCompleted: Bool { completedAt != nil }

    enum CodingKeys: String, CodingKey {
        case id, title
        case targetMinutes = "target_minutes"
        case completedAt   = "completed_at"
        case resourceTitle = "resource_title"
        case priority
        case resourceURL   = "resource_url"
        case unitURL       = "unit_url"
    }
}

struct AssistantResource: Codable, Identifiable {
    let id: Int
    let title: String
    let trackingMode: String
    let completedUnits: Int
    let totalUnits: Int
    let actualMinutesTotal: Int
    let deadline: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, title, deadline, status
        case trackingMode       = "tracking_mode"
        case completedUnits     = "completed_units"
        case totalUnits         = "total_units"
        case actualMinutesTotal = "actual_minutes_total"
    }
}

struct ChatResponse: Codable {
    let threadId: String
    let response: String?   // null when backend returns a proposal instead of text
    let proposal: ChatProposal?

    enum CodingKeys: String, CodingKey {
        case threadId = "thread_id"
        case response, proposal
    }
}

struct ChatProposal: Codable {
    let description: String
    let changes: [AnyCodable]
    let affectsDeadline: Bool
    let summaryForUser: String

    enum CodingKeys: String, CodingKey {
        case description, changes
        case affectsDeadline  = "affects_deadline"
        case summaryForUser   = "summary_for_user"
    }
}

// MARK: - Ingestion Models (new flow)

struct StartIngestionResponse: Codable {
    let threadId: String
    enum CodingKeys: String, CodingKey { case threadId = "thread_id" }
}

struct IngestionProgressEvent: Decodable {
    let phase: String
    let label: String
    let done: Bool
    let draft: IngestionDraftDetail?
    let error: String?
}

struct IngestionDraftDetail: Codable {
    let resourceTitle: String
    let resourceType: String
    let totalEstimatedHours: Double
    let unitCount: Int
    let optionA: [[String: AnyCodable]]
    let optionB: [[String: AnyCodable]]

    enum CodingKeys: String, CodingKey {
        case resourceTitle       = "resource_title"
        case resourceType        = "resource_type"
        case totalEstimatedHours = "total_estimated_hours"
        case unitCount           = "unit_count"
        case optionA             = "option_a"
        case optionB             = "option_b"
    }
}

// MARK: - Learning Preferences Model

struct LearningPreferences: Codable {
    let dailyCapacityMin: Int
    enum CodingKeys: String, CodingKey { case dailyCapacityMin = "daily_capacity_min" }
}

// Keep IngestionDraft for backward-compatible test decoding tests only
struct IngestionDraft: Codable {
    let threadId: String
    let draft: IngestionDraftDetail

    enum CodingKeys: String, CodingKey {
        case threadId = "thread_id"
        case draft
    }
}

// Wrapper to handle mixed-type JSON values in schedule arrays
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self)   { value = v }
        else if let v = try? container.decode(Int.self)    { value = v }
        else if let v = try? container.decode(Double.self) { value = v }
        else if let v = try? container.decode(String.self) { value = v }
        else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool:   try container.encode(v)
        case let v as Int:    try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        default:              try container.encodeNil()
        }
    }
}

// MARK: - API Client

/// 封装所有对 localhost:8765 的 HTTP 调用；后端离线时抛出 AssistantOfflineError。
final class AssistantAPIClient {
    static let shared = AssistantAPIClient()

    private let baseURL = URL(string: "http://localhost:8765")!
    let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 120
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
    }

    // MARK: - Private helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        let data = try await fetch(url: url, method: "GET", body: nil)
        return try decode(data)
    }

    private func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        let url  = baseURL.appendingPathComponent(path)
        let bodyData = try JSONEncoder().encode(body)
        let data = try await fetch(url: url, method: "POST", body: bodyData)
        return try decode(data)
    }

    private func postVoid<B: Encodable>(_ path: String, body: B) async throws {
        let url  = baseURL.appendingPathComponent(path)
        let bodyData = try JSONEncoder().encode(body)
        _ = try await fetch(url: url, method: "POST", body: bodyData)
    }

    private func putVoid<B: Encodable>(_ path: String, body: B) async throws {
        let url  = baseURL.appendingPathComponent(path)
        let bodyData = try JSONEncoder().encode(body)
        _ = try await fetch(url: url, method: "PUT", body: bodyData)
    }

    private func fetch(url: URL, method: String, body: Data?) async throws -> Data {
        var request        = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AssistantOfflineError() }
            // Detect thread_not_found 404
            if http.statusCode == 404,
               let json = try? JSONDecoder().decode([String: String].self, from: data),
               json["error"] == "thread_not_found" {
                throw ThreadNotFoundError()
            }
            guard (200..<300).contains(http.statusCode) else { throw AssistantOfflineError() }
            return data
        } catch is ThreadNotFoundError {
            throw ThreadNotFoundError()
        } catch is AssistantOfflineError {
            throw AssistantOfflineError()
        } catch {
            // URLSession 连接失败（ECONNREFUSED 等）都视为离线
            throw AssistantOfflineError()
        }
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AssistantOfflineError()
        }
    }

    // MARK: - Public API

    func fetchTodayBriefing() async throws -> TodayBriefing {
        try await get("/api/today-briefing")
    }

    func completeTask(id: Int, actualMinutes: Int? = nil) async throws {
        struct Body: Encodable {
            let actualMinutes: Int?
            enum CodingKeys: String, CodingKey { case actualMinutes = "actual_minutes" }
        }
        try await postVoid("/api/tasks/\(id)/complete", body: Body(actualMinutes: actualMinutes))
    }

    func sendMessage(message: String, threadId: String?) async throws -> ChatResponse {
        struct Body: Encodable {
            let message: String
            let threadId: String?
            enum CodingKeys: String, CodingKey {
                case message
                case threadId = "thread_id"
            }
        }
        return try await post("/api/chat", body: Body(message: message, threadId: threadId))
    }

    func confirmChat(threadId: String, confirmed: Bool) async throws {
        struct Body: Encodable {
            let threadId: String
            let confirmed: Bool
            enum CodingKeys: String, CodingKey {
                case threadId = "thread_id"
                case confirmed
            }
        }
        try await postVoid("/api/chat/confirm", body: Body(threadId: threadId, confirmed: confirmed))
    }

    // MARK: - Ingestion (new flow)

    func startIngestion(url: String, deadline: String, speedFactor: Double?) async throws -> String {
        struct Body: Encodable {
            let url: String
            let deadline: String
            let speedFactor: Double?
            enum CodingKeys: String, CodingKey {
                case url, deadline
                case speedFactor = "speed_factor"
            }
        }
        let resp: StartIngestionResponse = try await post("/api/ingest/start",
                                                          body: Body(url: url, deadline: deadline, speedFactor: speedFactor))
        return resp.threadId
    }

    func subscribeIngestionProgress(threadId: String) -> AsyncThrowingStream<IngestionProgressEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let url = self.baseURL.appendingPathComponent("/api/ingest/progress/\(threadId)")
                var request = URLRequest(url: url)
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                do {
                    let (bytes, response) = try await self.session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        continuation.finish(throwing: AssistantOfflineError())
                        return
                    }
                    for try await line in bytes.lines {
                        if line.hasPrefix("data:") {
                            let jsonStr = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            if let data = jsonStr.data(using: .utf8),
                               let event = try? JSONDecoder().decode(IngestionProgressEvent.self, from: data) {
                                continuation.yield(event)
                                if event.done {
                                    continuation.finish()
                                    return
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func rescheduleIngestion(threadId: String, deadline: String, speedFactor: Double) async throws -> IngestionDraftDetail {
        struct Body: Encodable {
            let threadId: String
            let deadline: String
            let speedFactor: Double
            enum CodingKeys: String, CodingKey {
                case threadId = "thread_id"
                case deadline
                case speedFactor = "speed_factor"
            }
        }
        return try await post("/api/ingest/reschedule",
                              body: Body(threadId: threadId, deadline: deadline, speedFactor: speedFactor))
    }

    func confirmIngestion(threadId: String, confirmed: Bool, selectedOption: String?, deadline: String? = nil, speedFactor: Double? = nil) async throws {
        struct Body: Encodable {
            let threadId: String
            let confirmed: Bool
            let selectedOption: String?
            let deadline: String?
            let speedFactor: Double?
            enum CodingKeys: String, CodingKey {
                case threadId = "thread_id"
                case confirmed
                case selectedOption = "selected_option"
                case deadline
                case speedFactor = "speed_factor"
            }
        }
        try await postVoid("/api/ingest/confirm",
                           body: Body(threadId: threadId, confirmed: confirmed, selectedOption: selectedOption,
                                     deadline: deadline, speedFactor: speedFactor))
    }

    func fetchResources() async throws -> [AssistantResource] {
        try await get("/api/resources")
    }

    func getLearningPreferences() async throws -> LearningPreferences {
        try await get("/api/settings/learning-preferences")
    }

    func updateLearningPreferences(_ prefs: LearningPreferences) async throws {
        struct Body: Encodable {
            let dailyCapacityMin: Int
            enum CodingKeys: String, CodingKey { case dailyCapacityMin = "daily_capacity_min" }
        }
        try await putVoid("/api/settings/learning-preferences", body: Body(dailyCapacityMin: prefs.dailyCapacityMin))
    }
}
