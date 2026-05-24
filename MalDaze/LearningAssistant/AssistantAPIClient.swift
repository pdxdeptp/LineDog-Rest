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
    let resourceURL: URL?

    init(
        id: Int,
        title: String,
        trackingMode: String,
        completedUnits: Int,
        totalUnits: Int,
        actualMinutesTotal: Int,
        deadline: String?,
        status: String,
        resourceURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.trackingMode = trackingMode
        self.completedUnits = completedUnits
        self.totalUnits = totalUnits
        self.actualMinutesTotal = actualMinutesTotal
        self.deadline = deadline
        self.status = status
        self.resourceURL = resourceURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        trackingMode = try container.decode(String.self, forKey: .trackingMode)
        completedUnits = try container.decode(Int.self, forKey: .completedUnits)
        totalUnits = try container.decode(Int.self, forKey: .totalUnits)
        actualMinutesTotal = try container.decode(Int.self, forKey: .actualMinutesTotal)
        deadline = try container.decodeIfPresent(String.self, forKey: .deadline)
        status = try container.decode(String.self, forKey: .status)

        let rawURL = try container.decodeIfPresent(String.self, forKey: .url)
        resourceURL = validWebURL(from: rawURL)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(trackingMode, forKey: .trackingMode)
        try container.encode(completedUnits, forKey: .completedUnits)
        try container.encode(totalUnits, forKey: .totalUnits)
        try container.encode(actualMinutesTotal, forKey: .actualMinutesTotal)
        try container.encodeIfPresent(deadline, forKey: .deadline)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(resourceURL?.absoluteString, forKey: .url)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, deadline, status
        case url
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

// MARK: - Study Views Models

struct StudyTodayView: Codable {
    let date: String
    let tasks: [StudyViewTask]
}

struct StudyViewTask: Codable, Identifiable {
    let id: Int
    let title: String
    let targetMinutes: Int
    let completedAt: String?
    let projectId: Int?
    let projectTitle: String?
    let resourceId: Int?
    let resourceTitle: String?
    let resourceURL: URL?
    let unitId: Int?
    let unitTitle: String?
    let unitURL: URL?

    var isCompleted: Bool { completedAt != nil }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        targetMinutes = try container.decode(Int.self, forKey: .targetMinutes)
        completedAt = try container.decodeIfPresent(String.self, forKey: .completedAt)
        projectId = try container.decodeIfPresent(Int.self, forKey: .projectId)
        projectTitle = try container.decodeIfPresent(String.self, forKey: .projectTitle)
        resourceId = try container.decodeIfPresent(Int.self, forKey: .resourceId)
        resourceTitle = try container.decodeIfPresent(String.self, forKey: .resourceTitle)
        resourceURL = validWebURL(from: try container.decodeIfPresent(String.self, forKey: .resourceURL))
        unitId = try container.decodeIfPresent(Int.self, forKey: .unitId)
        unitTitle = try container.decodeIfPresent(String.self, forKey: .unitTitle)
        unitURL = validWebURL(from: try container.decodeIfPresent(String.self, forKey: .unitURL))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(targetMinutes, forKey: .targetMinutes)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(projectId, forKey: .projectId)
        try container.encodeIfPresent(projectTitle, forKey: .projectTitle)
        try container.encodeIfPresent(resourceId, forKey: .resourceId)
        try container.encodeIfPresent(resourceTitle, forKey: .resourceTitle)
        try container.encodeIfPresent(resourceURL?.absoluteString, forKey: .resourceURL)
        try container.encodeIfPresent(unitId, forKey: .unitId)
        try container.encodeIfPresent(unitTitle, forKey: .unitTitle)
        try container.encodeIfPresent(unitURL?.absoluteString, forKey: .unitURL)
    }

    enum CodingKeys: String, CodingKey {
        case id, title
        case targetMinutes = "target_minutes"
        case completedAt = "completed_at"
        case projectId = "project_id"
        case projectTitle = "project_title"
        case resourceId = "resource_id"
        case resourceTitle = "resource_title"
        case resourceURL = "resource_url"
        case unitId = "unit_id"
        case unitTitle = "unit_title"
        case unitURL = "unit_url"
    }

}

struct StudyProjectOverview: Codable {
    let activeProjects: [StudyProjectSummary]
    let completedProjects: [StudyProjectSummary]

    enum CodingKeys: String, CodingKey {
        case activeProjects = "active_projects"
        case completedProjects = "completed_projects"
    }
}

struct StudyProjectSummary: Codable, Identifiable {
    let id: Int
    let title: String
    let completedUnits: Int
    let totalUnits: Int
    let progressRatio: Double
    let targetMinutes: Int
    let actualMinutes: Int
    let deadline: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, title, deadline, status
        case completedUnits = "completed_units"
        case totalUnits = "total_units"
        case progressRatio = "progress_ratio"
        case targetMinutes = "target_minutes"
        case actualMinutes = "actual_minutes"
    }
}

struct StudyCalendarLoad: Codable {
    let startDate: String
    let endDate: String
    let dailyCapacityMinutes: Int
    let days: [StudyCalendarDay]

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case dailyCapacityMinutes = "daily_capacity_minutes"
        case days
    }
}

struct StudyCalendarDay: Codable {
    let date: String
    let scheduledTaskCount: Int
    let totalTargetMinutes: Int
    let completedTaskCount: Int
    let overCapacity: Bool

    enum CodingKeys: String, CodingKey {
        case date
        case scheduledTaskCount = "scheduled_task_count"
        case totalTargetMinutes = "total_target_minutes"
        case completedTaskCount = "completed_task_count"
        case overCapacity = "over_capacity"
    }
}

struct TaskCompletionResult: Codable {
    let taskId: Int
    let completedAt: String

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case completedAt = "completed_at"
    }
}

// MARK: - Study Plan v2 Models

struct StudyPlanClarification: Codable {
    let version: String
    let materialType: String
    let questions: [StudyPlanClarificationQuestion]
    let defaults: [String: String]
    let skipAction: StudyPlanSkipAction

    enum CodingKeys: String, CodingKey {
        case version
        case materialType = "material_type"
        case questions
        case defaults
        case skipAction = "skip_action"
    }
}

struct StudyPlanStartResponse: Codable {
    let draftId: Int
    let clarification: StudyPlanClarification

    init(draftId: Int, clarification: StudyPlanClarification) {
        self.draftId = draftId
        self.clarification = clarification
    }

    enum CodingKeys: String, CodingKey {
        case draftId = "draft_id"
        case clarification
    }
}

struct StudyPlanClarificationQuestion: Codable {
    let id: String
    let prompt: String
    let options: [StudyPlanClarificationOption]
    let allowsCustomText: Bool

    init(
        id: String,
        prompt: String,
        options: [StudyPlanClarificationOption],
        allowsCustomText: Bool = false
    ) {
        self.id = id
        self.prompt = prompt
        self.options = options
        self.allowsCustomText = allowsCustomText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        prompt = try container.decode(String.self, forKey: .prompt)
        options = try container.decode([StudyPlanClarificationOption].self, forKey: .options)
        allowsCustomText = try container.decodeIfPresent(Bool.self, forKey: .allowsCustomText) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case id, prompt, options
        case allowsCustomText = "allows_custom_text"
    }
}

struct StudyPlanClarificationOption: Codable {
    let id: String
    let label: String
    let value: String
    let recommended: Bool
    let isDefault: Bool
    let usesDefault: Bool

    init(
        id: String,
        label: String,
        value: String,
        recommended: Bool = false,
        isDefault: Bool = false,
        usesDefault: Bool = false
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.recommended = recommended
        self.isDefault = isDefault
        self.usesDefault = usesDefault
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        value = try container.decode(String.self, forKey: .value)
        recommended = try container.decodeIfPresent(Bool.self, forKey: .recommended) ?? false
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        usesDefault = try container.decodeIfPresent(Bool.self, forKey: .usesDefault) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case id, label, value, recommended
        case isDefault = "default"
        case usesDefault = "uses_default"
    }
}

struct StudyPlanSkipAction: Codable {
    let id: String
    let label: String
    let usesDefaults: Bool

    init(id: String, label: String, usesDefaults: Bool = false) {
        self.id = id
        self.label = label
        self.usesDefaults = usesDefaults
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        usesDefaults = try container.decodeIfPresent(Bool.self, forKey: .usesDefaults) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case id, label
        case usesDefaults = "uses_defaults"
    }
}

struct StudyPlanSkipClarificationResponse: Codable {
    let answers: [String: String]
    let defaults: [String: String]
    let clarificationSkipped: Bool
    let lowCalibration: Bool

    enum CodingKeys: String, CodingKey {
        case answers, defaults
        case clarificationSkipped = "clarification_skipped"
        case lowCalibration = "low_calibration"
    }
}

struct StudyPlanDraftTask: Codable {
    let title: String
    let orderIndex: Int
    let estimatedMinutes: Int
    let scheduledDate: String
    let targetMinutes: Int

    init(
        title: String,
        orderIndex: Int,
        estimatedMinutes: Int,
        scheduledDate: String,
        targetMinutes: Int
    ) {
        self.title = title
        self.orderIndex = orderIndex
        self.estimatedMinutes = estimatedMinutes
        self.scheduledDate = scheduledDate
        self.targetMinutes = targetMinutes
    }

    enum CodingKeys: String, CodingKey {
        case title
        case orderIndex = "order_index"
        case estimatedMinutes = "estimated_minutes"
        case scheduledDate = "scheduled_date"
        case targetMinutes = "target_minutes"
    }
}

struct StudyPlanDraft: Codable {
    let id: Int
    let title: String
    let sourceURL: URL
    let deadline: String
    let status: String
    let capacityMinutes: Int
    let clarificationSkipped: Bool
    let lowCalibration: Bool
    let tasks: [StudyPlanDraftTask]
    let expectedLate: Bool
    let overCapacityDays: [StudyPlanOverCapacityDay]

    init(
        id: Int,
        title: String,
        sourceURL: URL,
        deadline: String,
        status: String,
        capacityMinutes: Int,
        clarificationSkipped: Bool,
        lowCalibration: Bool = false,
        tasks: [StudyPlanDraftTask],
        expectedLate: Bool = false,
        overCapacityDays: [StudyPlanOverCapacityDay] = []
    ) {
        self.id = id
        self.title = title
        self.sourceURL = sourceURL
        self.deadline = deadline
        self.status = status
        self.capacityMinutes = capacityMinutes
        self.clarificationSkipped = clarificationSkipped
        self.lowCalibration = lowCalibration
        self.tasks = tasks
        self.expectedLate = expectedLate
        self.overCapacityDays = overCapacityDays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        sourceURL = try container.decode(URL.self, forKey: .sourceURL)
        deadline = try container.decode(String.self, forKey: .deadline)
        status = try container.decode(String.self, forKey: .status)
        capacityMinutes = try container.decode(Int.self, forKey: .capacityMinutes)
        clarificationSkipped = try container.decodeIfPresent(Bool.self, forKey: .clarificationSkipped) ?? false
        lowCalibration = try container.decodeIfPresent(Bool.self, forKey: .lowCalibration) ?? false
        tasks = try container.decode([StudyPlanDraftTask].self, forKey: .tasks)
        expectedLate = try container.decodeIfPresent(Bool.self, forKey: .expectedLate) ?? false
        overCapacityDays = try container.decodeIfPresent([StudyPlanOverCapacityDay].self, forKey: .overCapacityDays) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case id, title, deadline, status, tasks
        case sourceURL = "source_url"
        case capacityMinutes = "capacity_minutes"
        case clarificationSkipped = "clarification_skipped"
        case lowCalibration = "low_calibration"
        case expectedLate = "expected_late"
        case overCapacityDays = "over_capacity_days"
    }
}

struct StudyPlanOverCapacityDay: Codable {
    let date: String
    let scheduledMinutes: Int
    let existingMinutes: Int
    let capacityMinutes: Int
    let overByMinutes: Int

    init(
        date: String,
        scheduledMinutes: Int,
        existingMinutes: Int,
        capacityMinutes: Int,
        overByMinutes: Int
    ) {
        self.date = date
        self.scheduledMinutes = scheduledMinutes
        self.existingMinutes = existingMinutes
        self.capacityMinutes = capacityMinutes
        self.overByMinutes = overByMinutes
    }

    enum CodingKeys: String, CodingKey {
        case date
        case scheduledMinutes = "scheduled_minutes"
        case existingMinutes = "existing_minutes"
        case capacityMinutes = "capacity_minutes"
        case overByMinutes = "over_by_minutes"
    }
}

struct StudyPlanStartRequest: Codable {
    let url: String
    let deadline: String
    let capacityMinutes: Int

    enum CodingKeys: String, CodingKey {
        case url, deadline
        case capacityMinutes = "capacity_minutes"
    }
}

struct StudyPlanClarificationSubmission: Codable {
    let answers: [String: String]
    let clarificationSkipped: Bool

    enum CodingKeys: String, CodingKey {
        case answers
        case clarificationSkipped = "clarification_skipped"
    }
}

struct StudyPlanDraftTaskDurationUpdateRequest: Codable {
    let estimatedMinutes: Int

    enum CodingKeys: String, CodingKey {
        case estimatedMinutes = "estimated_minutes"
    }
}

struct StudyPlanActivationResult: Codable {
    let id: Int
    let resourceId: Int
    let status: String
    let sourceURL: URL
    let deadline: String
    let capacityMinutes: Int
    let clarificationSkipped: Bool

    init(
        id: Int,
        resourceId: Int,
        status: String,
        sourceURL: URL,
        deadline: String,
        capacityMinutes: Int,
        clarificationSkipped: Bool
    ) {
        self.id = id
        self.resourceId = resourceId
        self.status = status
        self.sourceURL = sourceURL
        self.deadline = deadline
        self.capacityMinutes = capacityMinutes
        self.clarificationSkipped = clarificationSkipped
    }

    enum CodingKeys: String, CodingKey {
        case id, status, deadline
        case resourceId = "resource_id"
        case sourceURL = "source_url"
        case capacityMinutes = "capacity_minutes"
        case clarificationSkipped = "clarification_skipped"
    }
}

private struct EmptyRequestBody: Encodable {}

private func validWebURL(from rawValue: String?) -> URL? {
    guard let rawValue else { return nil }
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
          let url = URL(string: trimmed),
          let scheme = url.scheme?.lowercased(),
          ["http", "https"].contains(scheme),
          let host = url.host,
          !host.isEmpty else {
        return nil
    }
    return url
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

    private let baseURL: URL
    let session: URLSession

    private init() {
        baseURL = URL(string: "http://localhost:8765")!
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 120
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
    }

    init(baseURL: URL, session: URLSession) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Private helpers

    private func requestURL(path: String, queryItems: [URLQueryItem] = []) -> URL {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url!
    }

    private func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        let url = requestURL(path: path, queryItems: queryItems)
        let data = try await fetch(url: url, method: "GET", body: nil)
        return try decode(data)
    }

    private func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        let url  = requestURL(path: path)
        let bodyData = try JSONEncoder().encode(body)
        let data = try await fetch(url: url, method: "POST", body: bodyData)
        return try decode(data)
    }

    private func postVoid<B: Encodable>(_ path: String, body: B) async throws {
        let url  = requestURL(path: path)
        let bodyData = try JSONEncoder().encode(body)
        _ = try await fetch(url: url, method: "POST", body: bodyData)
    }

    private func put<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        let url = requestURL(path: path)
        let bodyData = try JSONEncoder().encode(body)
        let data = try await fetch(url: url, method: "PUT", body: bodyData)
        return try decode(data)
    }

    private func putVoid<B: Encodable>(_ path: String, body: B) async throws {
        let url  = requestURL(path: path)
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

    func fetchStudyTodayView() async throws -> StudyTodayView {
        try await get("/api/study-views/today")
    }

    func fetchStudyProjectOverview() async throws -> StudyProjectOverview {
        try await get("/api/study-views/projects")
    }

    func fetchStudyCalendarLoad(start: String, end: String) async throws -> StudyCalendarLoad {
        try await get(
            "/api/study-views/calendar",
            queryItems: [
                URLQueryItem(name: "start", value: start),
                URLQueryItem(name: "end", value: end)
            ]
        )
    }

    func completeTask(id: Int, actualMinutes: Int? = nil) async throws -> TaskCompletionResult {
        struct Body: Encodable {
            let actualMinutes: Int?
            enum CodingKeys: String, CodingKey { case actualMinutes = "actual_minutes" }
        }
        return try await post("/api/tasks/\(id)/complete", body: Body(actualMinutes: actualMinutes))
    }

    func completeResource(id: Int) async throws {
        struct Body: Encodable {
            let source: String
        }
        try await postVoid("/api/resources/\(id)/complete", body: Body(source: "resource_progress"))
    }

    func archiveResource(id: Int) async throws {
        struct Body: Encodable {}
        try await postVoid("/api/resources/\(id)/archive", body: Body())
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

    // MARK: - Study Plan v2

    func startStudyPlan(url: String, deadline: String, capacityMinutes: Int) async throws -> StudyPlanStartResponse {
        try await post(
            "/api/study-plan/start",
            body: StudyPlanStartRequest(
                url: url,
                deadline: deadline,
                capacityMinutes: capacityMinutes
            )
        )
    }

    func submitStudyPlanClarification(
        draftId: Int,
        answers: [String: String],
        skip: Bool
    ) async throws -> StudyPlanDraft {
        try await post(
            "/api/study-plan/drafts/\(draftId)/clarification",
            body: StudyPlanClarificationSubmission(
                answers: answers,
                clarificationSkipped: skip
            )
        )
    }

    func updateStudyPlanDraftTaskDuration(
        draftId: Int,
        taskOrderIndex: Int,
        estimatedMinutes: Int
    ) async throws -> StudyPlanDraft {
        try await put(
            "/api/study-plan/drafts/\(draftId)/tasks/\(taskOrderIndex)/duration",
            body: StudyPlanDraftTaskDurationUpdateRequest(estimatedMinutes: estimatedMinutes)
        )
    }

    func cancelStudyPlanDraft(draftId: Int) async throws {
        try await postVoid(
            "/api/study-plan/drafts/\(draftId)/cancel",
            body: EmptyRequestBody()
        )
    }

    func confirmStudyPlanDraft(draftId: Int) async throws -> StudyPlanActivationResult {
        try await post(
            "/api/study-plan/drafts/\(draftId)/confirm",
            body: EmptyRequestBody()
        )
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
