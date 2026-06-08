import Foundation

// MARK: - Today

struct HermesTodayResponse: Decodable, Equatable {
    let date: String
    let isRestDay: Bool
    let pending: [HermesPendingTask]
    let pendingCount: Int
    let study: HermesStudyBucket
    let review: HermesReviewBucket
    let warnings: [HermesProjectWarning]

    enum CodingKeys: String, CodingKey {
        case date
        case isRestDay = "is_rest_day"
        case pending
        case pendingCount = "pending_count"
        case study, review, warnings
    }
}

struct HermesPendingTask: Decodable, Equatable, Identifiable {
    var id: String { taskId }
    let index: Int
    let taskId: String
    let title: String
    let projectId: String
    let projectName: String
    let durationMinutes: Int
    let taskType: String
    let scheduledDate: String

    enum CodingKeys: String, CodingKey {
        case index
        case taskId = "task_id"
        case title
        case projectId = "project_id"
        case projectName = "project_name"
        case durationMinutes = "duration_minutes"
        case taskType = "task_type"
        case scheduledDate = "scheduled_date"
    }
}

struct HermesStudyBucket: Decodable, Equatable {
    let tasks: [HermesNestedTaskItem]
    let totalMinutes: Int
    let budget: Int

    enum CodingKeys: String, CodingKey {
        case tasks
        case totalMinutes = "total_minutes"
        case budget
    }
}

struct HermesReviewBucket: Decodable, Equatable {
    let tasks: [HermesNestedTaskItem]
    let totalMinutes: Int
    let budget: Int

    enum CodingKeys: String, CodingKey {
        case tasks
        case totalMinutes = "total_minutes"
        case budget
    }
}

struct HermesNestedTaskItem: Decodable, Equatable {
    let projectId: String
    let projectName: String
    let task: HermesTaskDetail

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case projectName = "project_name"
        case task
    }
}

struct HermesTaskDetail: Decodable, Equatable {
    let id: String
    let title: String
    let durationMinutes: Int
    let autoRollDays: Int?

    enum CodingKeys: String, CodingKey {
        case id, title
        case durationMinutes = "duration_minutes"
        case autoRollDays = "auto_roll_days"
    }
}

struct HermesProjectWarning: Decodable, Equatable, Identifiable {
    var id: String { projectId }
    let projectId: String
    let projectName: String
    let daysBehind: Int

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case projectName = "project_name"
        case daysBehind = "days_behind"
    }
}

// MARK: - Display row

struct LearningTaskDisplayRow: Identifiable, Equatable {
    let pending: HermesPendingTask
    let autoRollDays: Int
    var id: String { pending.taskId }
    var isReview: Bool { pending.taskType == "review" }
}

struct LearningTodaySnapshot: Equatable {
    let response: HermesTodayResponse
    let rows: [LearningTaskDisplayRow]

    var studyRows: [LearningTaskDisplayRow] {
        rows.filter { !$0.isReview }
    }

    var reviewRows: [LearningTaskDisplayRow] {
        rows.filter(\.isReview)
    }

    static func make(from response: HermesTodayResponse) -> LearningTodaySnapshot {
        var rollMap: [String: Int] = [:]
        for item in response.study.tasks + response.review.tasks {
            rollMap[item.task.id] = item.task.autoRollDays ?? 0
        }
        let rows = response.pending.map { pending in
            LearningTaskDisplayRow(
                pending: pending,
                autoRollDays: rollMap[pending.taskId] ?? 0
            )
        }
        return LearningTodaySnapshot(response: response, rows: rows)
    }
}

// MARK: - Complete / Move

struct HermesCompleteResponse: Decodable, Equatable {
    let taskId: String?
    let status: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case status, error
    }

    var succeeded: Bool {
        error == nil && status == "completed"
    }
}

struct HermesMoveChange: Decodable, Equatable, Identifiable {
    var id: String { taskId }
    let taskId: String
    let title: String
    let oldDate: String
    let newDate: String

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case title
        case oldDate = "old_date"
        case newDate = "new_date"
    }
}

struct HermesMoveResponse: Decodable, Equatable {
    let action: String?
    let dryRun: Bool?
    let taskId: String?
    let deltaDays: Int?
    let changes: [HermesMoveChange]
    let affectedCount: Int?
    let error: String?
    let calendarErrors: [HermesCalendarError]?

    enum CodingKeys: String, CodingKey {
        case action
        case dryRun = "dry_run"
        case taskId = "task_id"
        case deltaDays = "delta_days"
        case changes
        case affectedCount = "affected_count"
        case error
        case calendarErrors = "calendar_errors"
    }

    var succeeded: Bool { error == nil }
}

struct HermesCalendarError: Decodable, Equatable {
    let taskId: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case error
    }
}

struct HermesCLIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum HermesScheduleJSON {
    static func decode<T: Decodable>(_ type: T.Type, from stdout: String) throws -> T {
        let data = Data(stdout.utf8)
        if let err = try? JSONDecoder().decode(HermesErrorEnvelope.self, from: data), let message = err.error {
            throw HermesCLIError(message: message)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let snippet = stdout.trimmingCharacters(in: .whitespacesAndNewlines).prefix(240)
            throw HermesCLIError(message: "无法解析 Hermes 输出：\(snippet)")
        }
    }
}

private struct HermesErrorEnvelope: Decodable {
    let error: String?
}
