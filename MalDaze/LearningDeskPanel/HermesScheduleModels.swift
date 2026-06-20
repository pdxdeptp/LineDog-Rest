import Foundation

// MARK: - Today

struct HermesProgressBucket: Decodable, Equatable {
    let done: Int
    let total: Int
}

struct HermesTodayProgress: Decodable, Equatable {
    let study: HermesProgressBucket
    let review: HermesProgressBucket
}

struct HermesTodayResponse: Decodable, Equatable {
    let date: String
    let isRestDay: Bool
    let pending: [HermesPendingTask]
    let pendingCount: Int
    let progress: HermesTodayProgress?
    let tomorrowPreview: HermesTomorrowPreview?
    let study: HermesStudyBucket
    let review: HermesReviewBucket
    let warnings: [HermesProjectWarning]

    enum CodingKeys: String, CodingKey {
        case date
        case isRestDay = "is_rest_day"
        case pending
        case pendingCount = "pending_count"
        case progress
        case tomorrowPreview = "tomorrow_preview"
        case study, review, warnings
    }
}

struct HermesTomorrowPreview: Decodable, Equatable {
    let date: String
    let pendingCount: Int
    let studyMinutes: Int
    let studyBudget: Int
    let isRestDay: Bool?
    let tasks: [HermesTomorrowPreviewTask]

    enum CodingKeys: String, CodingKey {
        case date
        case pendingCount = "pending_count"
        case studyMinutes = "study_minutes"
        case studyBudget = "study_budget"
        case isRestDay = "is_rest_day"
        case tasks
    }
}

struct HermesTomorrowPreviewTask: Decodable, Equatable, Identifiable {
    var id: String { taskId }
    let index: Int
    let taskId: String
    let title: String
    let projectName: String
    let durationMinutes: Int

    enum CodingKeys: String, CodingKey {
        case index
        case taskId = "task_id"
        case title
        case projectName = "project_name"
        case durationMinutes = "duration_minutes"
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
    let autoRollDays: Int?
    let sourceUrl: String?

    enum CodingKeys: String, CodingKey {
        case index
        case taskId = "task_id"
        case title
        case projectId = "project_id"
        case projectName = "project_name"
        case durationMinutes = "duration_minutes"
        case taskType = "task_type"
        case scheduledDate = "scheduled_date"
        case autoRollDays = "auto_roll_days"
        case sourceUrl = "source_url"
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

struct LearningTodayProjectSection: Identifiable, Equatable {
    let projectName: String
    let rows: [LearningTaskDisplayRow]
    var id: String { projectName }
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

    var highRolloverRows: [LearningTaskDisplayRow] {
        rows.filter { $0.autoRollDays >= 3 }
    }

    static func projectSections(from rows: [LearningTaskDisplayRow]) -> [LearningTodayProjectSection] {
        var order: [String] = []
        var grouped: [String: [LearningTaskDisplayRow]] = [:]
        for row in rows {
            let name = row.pending.projectName
            if grouped[name] == nil {
                order.append(name)
            }
            grouped[name, default: []].append(row)
        }
        return order.map { LearningTodayProjectSection(projectName: $0, rows: grouped[$0] ?? []) }
    }

    var projectOptions: [LearningProjectOption] {
        var seen = Set<String>()
        var out: [LearningProjectOption] = []
        for item in response.study.tasks + response.review.tasks {
            if seen.insert(item.projectId).inserted {
                out.append(LearningProjectOption(id: item.projectId, name: item.projectName))
            }
        }
        for warning in response.warnings {
            if seen.insert(warning.projectId).inserted {
                out.append(LearningProjectOption(id: warning.projectId, name: warning.projectName))
            }
        }
        return out.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func make(from response: HermesTodayResponse) -> LearningTodaySnapshot {
        var rollMap: [String: Int] = [:]
        for item in response.study.tasks + response.review.tasks {
            rollMap[item.task.id] = item.task.autoRollDays ?? 0
        }
        let rows = response.pending.map { pending in
            LearningTaskDisplayRow(
                pending: pending,
                autoRollDays: pending.autoRollDays ?? rollMap[pending.taskId] ?? 0
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

    enum CodingKeys: String, CodingKey {
        case action
        case dryRun = "dry_run"
        case taskId = "task_id"
        case deltaDays = "delta_days"
        case changes
        case affectedCount = "affected_count"
        case error
    }

    var succeeded: Bool { error == nil }
}

struct HermesInsertResponse: Decodable, Equatable {
    let action: String?
    let error: String?

    var succeeded: Bool { error == nil && action == "insert" }
}

struct HermesRemoveResponse: Decodable, Equatable {
    let action: String?
    let error: String?

    var succeeded: Bool { error == nil && action == "remove" }
}

struct HermesDeleteProjectResponse: Decodable, Equatable {
    let action: String?
    let projectId: String?
    let name: String?
    let tasksRemoved: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case action
        case projectId = "project_id"
        case name
        case tasksRemoved = "tasks_removed"
        case error
    }

    var succeeded: Bool { error == nil && action == "delete-project" }
}

struct HermesReviewResponse: Decodable, Equatable {
    let taskId: String?
    let result: String?
    let status: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case result, status, error
    }

    var succeeded: Bool { error == nil }
}

struct HermesWeekLoadDay: Decodable, Equatable, Identifiable {
    var id: String { date }
    let date: String
    let totalMinutes: Int
    let budget: Int
    let overCapacity: Bool
    let isRestDay: Bool

    enum CodingKeys: String, CodingKey {
        case date
        case totalMinutes = "total_minutes"
        case budget
        case overCapacity = "over_capacity"
        case isRestDay = "is_rest_day"
    }
}

struct HermesWeekLoadResponse: Decodable, Equatable {
    let fromDate: String
    let days: Int
    let daysData: [HermesWeekLoadDay]

    enum CodingKeys: String, CodingKey {
        case fromDate = "from_date"
        case days
        case daysData = "days_data"
    }
}

// MARK: - Schedule range (agenda)

struct HermesScheduleRangeDeadline: Decodable, Equatable, Identifiable {
    var id: String { projectId }
    let projectId: String
    let name: String
    let deadline: String

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case name, deadline
    }
}

struct HermesScheduleRangeTask: Decodable, Equatable, Identifiable {
    var id: String { taskId }
    let taskId: String
    let projectId: String
    let projectName: String
    let title: String
    let durationMinutes: Int
    let taskType: String?
    let status: String
    let afterProjectDeadline: Bool
    let autoRollDays: Int?

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case projectId = "project_id"
        case projectName = "project_name"
        case title
        case durationMinutes = "duration_minutes"
        case taskType = "task_type"
        case status
        case afterProjectDeadline = "after_project_deadline"
        case autoRollDays = "auto_roll_days"
    }

    var isReview: Bool { taskType == "review" }

    func displayRow(scheduledDate: String, index: Int) -> LearningTaskDisplayRow {
        let pending = HermesPendingTask(
            index: index,
            taskId: taskId,
            title: title,
            projectId: projectId,
            projectName: projectName,
            durationMinutes: durationMinutes,
            taskType: taskType ?? "",
            scheduledDate: scheduledDate,
            autoRollDays: autoRollDays,
            sourceUrl: nil
        )
        return LearningTaskDisplayRow(
            pending: pending,
            autoRollDays: autoRollDays ?? 0
        )
    }
}

struct HermesScheduleRangeDay: Decodable, Equatable, Identifiable {
    var id: String { date }
    let date: String
    let isRestDay: Bool
    let studyMinutes: Int
    let reviewMinutes: Int
    let budgetStudy: Int
    let budgetReview: Int
    let overCapacity: Bool
    let tasks: [HermesScheduleRangeTask]

    enum CodingKeys: String, CodingKey {
        case date
        case isRestDay = "is_rest_day"
        case studyMinutes = "study_minutes"
        case reviewMinutes = "review_minutes"
        case budgetStudy = "budget_study"
        case budgetReview = "budget_review"
        case overCapacity = "over_capacity"
        case tasks
    }
}

struct HermesScheduleRangeResponse: Decodable, Equatable {
    let fromDate: String
    let toDate: String
    let truncated: Bool?
    let deadlines: [HermesScheduleRangeDeadline]
    let days: [HermesScheduleRangeDay]

    enum CodingKeys: String, CodingKey {
        case fromDate = "from_date"
        case toDate = "to_date"
        case truncated, deadlines, days
    }
}

struct LearningProjectOption: Identifiable, Equatable {
    let id: String
    let name: String
}

struct HermesStatusNextTask: Decodable, Equatable {
    let title: String
    let scheduledDate: String?
    let durationMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case title
        case scheduledDate = "scheduled_date"
        case durationMinutes = "duration_minutes"
    }
}

struct HermesStatusProject: Decodable, Equatable {
    let projectId: String
    let name: String
    let status: String
    let deadline: String?
    let progress: String?
    let percent: Int?
    let deadlineExceeded: Bool?
    let nextTask: HermesStatusNextTask?

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case name, status, deadline, progress, percent
        case deadlineExceeded = "deadline_exceeded"
        case nextTask = "next_task"
    }

    var asOption: LearningProjectOption {
        LearningProjectOption(id: projectId, name: name)
    }

    var isActive: Bool { status == "active" }

    var totalTaskCount: Int? {
        guard let progress else { return nil }
        let parts = progress.split(separator: "/")
        guard parts.count == 2, let total = Int(parts[1]) else { return nil }
        return total
    }
}

struct HermesDeadlineChange: Decodable, Equatable {
    let projectId: String?
    let taskId: String
    let title: String?
    let oldDate: String?
    let newDate: String?

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case taskId = "task_id"
        case title
        case oldDate = "old_date"
        case newDate = "new_date"
    }
}

struct HermesDeadlineOverflowTask: Decodable, Equatable {
    let projectId: String?
    let taskId: String
    let title: String?
    let scheduledDate: String?

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case taskId = "task_id"
        case title
        case scheduledDate = "scheduled_date"
    }
}

struct HermesProjectCadence: Decodable, Equatable {
    let projectId: String
    let remainingStudyTasks: Int?
    let eligibleStudyDays: Int?
    let minPreferredDaily: Int?
    let maxPreferredDaily: Int?
    let movedTaskCount: Int?

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case remainingStudyTasks = "remaining_study_tasks"
        case eligibleStudyDays = "eligible_study_days"
        case minPreferredDaily = "min_preferred_daily"
        case maxPreferredDaily = "max_preferred_daily"
        case movedTaskCount = "moved_task_count"
    }
}

struct HermesCapacityConflict: Decodable, Equatable {
    let type: String?
    let date: String?
    let loadMinutes: Int?
    let capacity: Int?
    let overBy: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case date
        case loadMinutes = "load_minutes"
        case capacity
        case overBy = "over_by"
    }
}

struct HermesSetDeadlineResponse: Decodable, Equatable {
    let projectId: String?
    let name: String?
    let oldDeadline: String?
    let newDeadline: String?
    let repacked: Bool?
    let repackMode: String?
    let repackScope: String?
    let feasible: Bool?
    let affectedProjectIds: [String]?
    let projectCadences: [HermesProjectCadence]?
    let capacityConflicts: [HermesCapacityConflict]?
    let changes: [HermesDeadlineChange]?
    let overflowCount: Int?
    let overflowTasks: [HermesDeadlineOverflowTask]?
    let deadlineExceeded: Bool?
    let dryRun: Bool?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case name
        case oldDeadline = "old_deadline"
        case newDeadline = "new_deadline"
        case repacked
        case repackMode = "repack_mode"
        case repackScope = "repack_scope"
        case feasible
        case affectedProjectIds = "affected_project_ids"
        case projectCadences = "project_cadences"
        case capacityConflicts = "capacity_conflicts"
        case changes
        case overflowCount = "overflow_count"
        case overflowTasks = "overflow_tasks"
        case deadlineExceeded = "deadline_exceeded"
        case dryRun = "dry_run"
        case error
    }

    var succeeded: Bool { error == nil && projectId != nil }
    var isFeasiblePreview: Bool { feasible ?? ((overflowCount ?? 0) == 0) }
}

enum LearningProjectStatusOrdering {
    static func sorted(_ projects: [HermesStatusProject]) -> [HermesStatusProject] {
        projects.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive && !rhs.isActive
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

enum HermesActiveProjects {
    static func options(from status: [HermesStatusProject]) -> [LearningProjectOption] {
        status
            .filter { $0.status == "active" }
            .map(\.asOption)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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
