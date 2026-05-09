import Foundation

// MARK: - Error Types

/// 后端离线或无法连接时抛出此错误。
struct AssistantOfflineError: Error, LocalizedError {
    var errorDescription: String? { "学习助手后端离线或无法连接（localhost:8765）" }
}

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

    var isCompleted: Bool { completedAt != nil }

    enum CodingKeys: String, CodingKey {
        case id, title
        case targetMinutes = "target_minutes"
        case completedAt   = "completed_at"
        case resourceTitle = "resource_title"
        case priority
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
    let response: String
    let proposal: String?

    enum CodingKeys: String, CodingKey {
        case threadId = "thread_id"
        case response, proposal
    }
}

struct IngestionDraft: Codable {
    let threadId: String
    let draft: String

    enum CodingKeys: String, CodingKey {
        case threadId = "thread_id"
        case draft
    }
}

// MARK: - API Client

/// 封装所有对 localhost:8765 的 HTTP 调用；后端离线时抛出 AssistantOfflineError。
final class AssistantAPIClient {
    static let shared = AssistantAPIClient()

    private let baseURL = URL(string: "http://localhost:8765")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 8
        config.timeoutIntervalForResource = 15
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

    private func fetch(url: URL, method: String, body: Data?) async throws -> Data {
        var request        = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw AssistantOfflineError()
            }
            return data
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

    func startIngestion(url: String, deadline: String, speedFactor: Double?) async throws -> IngestionDraft {
        struct Body: Encodable {
            let url: String
            let deadline: String
            let speedFactor: Double?
            enum CodingKeys: String, CodingKey {
                case url, deadline
                case speedFactor = "speed_factor"
            }
        }
        return try await post("/api/ingest", body: Body(url: url, deadline: deadline, speedFactor: speedFactor))
    }

    func confirmIngestion(threadId: String, confirmed: Bool, selectedOption: String?) async throws {
        struct Body: Encodable {
            let threadId: String
            let confirmed: Bool
            let selectedOption: String?
            enum CodingKeys: String, CodingKey {
                case threadId      = "thread_id"
                case confirmed
                case selectedOption = "selected_option"
            }
        }
        try await postVoid("/api/ingest/confirm",
                           body: Body(threadId: threadId, confirmed: confirmed, selectedOption: selectedOption))
    }

    func fetchResources() async throws -> [AssistantResource] {
        try await get("/api/resources")
    }
}
