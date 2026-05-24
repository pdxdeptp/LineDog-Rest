import Foundation

/// 学习助手 API 客户端协议；生产代码用 AssistantAPIClient.shared，测试可注入 mock。
protocol AssistantAPIClientProtocol: Sendable {
    func fetchTodayBriefing() async throws -> TodayBriefing
    func fetchStudyTodayView() async throws -> StudyTodayView
    func fetchStudyProjectOverview() async throws -> StudyProjectOverview
    func fetchStudyCalendarLoad(start: String, end: String) async throws -> StudyCalendarLoad
    func completeTask(id: Int, actualMinutes: Int?) async throws -> TaskCompletionResult
    func rolloverStudyTasks() async throws -> StudyRolloverResult
    func moveStudyTask(id: Int, scheduledDate: String) async throws -> StudyTaskMoveResult
    func updateStudyProjectDeadline(
        projectId: Int,
        deadline: String
    ) async throws -> StudyProjectDeadlineUpdateResult
    func insertStudyProjectTask(
        projectId: Int,
        title: String,
        targetMinutes: Int,
        scheduledDate: String
    ) async throws -> StudyTaskInsertResult
    func deleteStudyTask(id: Int) async throws -> StudyTaskDeleteResult
    func fetchStudyRestDaySettings() async throws -> StudyRestDaySettings
    func updateStudyRestDaySettings(_ settings: StudyRestDaySettings) async throws -> StudyRestDaySettingsUpdateResult
    func fetchStudySmartModeSettings() async throws -> StudySmartModeSettings
    func updateStudySmartModeSettings(_ settings: StudySmartModeSettings) async throws -> StudySmartModeSettings
    func fetchStudySmartMorningBriefing() async throws -> StudySmartMorningBriefing
    func generateStudySmartProposals(_ request: StudySmartProposalGenerationRequest) async throws -> StudySmartProposalGenerationResponse
    func applyStudySmartProposal(_ request: StudySmartProposalApplyRequest) async throws -> StudySmartProposalApplyResult
    func previewStudyDialogueAdjustment(
        instruction: String,
        projectId: Int?
    ) async throws -> StudyDialogueAdjustmentPreview
    func applyStudyDialogueAdjustment(
        instruction: String,
        projectId: Int?,
        preview: StudyDialogueAdjustmentPreview
    ) async throws -> StudyDialogueAdjustmentApplyResult
    func completeResource(id: Int) async throws
    func archiveResource(id: Int) async throws
    func sendMessage(message: String, threadId: String?) async throws -> ChatResponse
    func confirmChat(threadId: String, confirmed: Bool) async throws
    func startIngestion(url: String, deadline: String, speedFactor: Double?) async throws -> String
    func subscribeIngestionProgress(threadId: String) -> AsyncThrowingStream<IngestionProgressEvent, Error>
    func rescheduleIngestion(threadId: String, deadline: String, speedFactor: Double) async throws -> IngestionDraftDetail
    func confirmIngestion(threadId: String, confirmed: Bool, selectedOption: String?, deadline: String?, speedFactor: Double?) async throws
    func startStudyPlan(url: String, deadline: String, capacityMinutes: Int) async throws -> StudyPlanStartResponse
    func submitStudyPlanClarification(draftId: Int, answers: [String: String], skip: Bool) async throws -> StudyPlanDraft
    func updateStudyPlanDraftTaskDuration(draftId: Int, taskOrderIndex: Int, estimatedMinutes: Int) async throws -> StudyPlanDraft
    func cancelStudyPlanDraft(draftId: Int) async throws
    func confirmStudyPlanDraft(draftId: Int) async throws -> StudyPlanActivationResult
    func fetchResources() async throws -> [AssistantResource]
    func getLearningPreferences() async throws -> LearningPreferences
    func updateLearningPreferences(_ prefs: LearningPreferences) async throws
}

extension AssistantAPIClientProtocol {
    func fetchStudyTodayView() async throws -> StudyTodayView {
        throw AssistantOfflineError()
    }

    func fetchStudyProjectOverview() async throws -> StudyProjectOverview {
        throw AssistantOfflineError()
    }

    func fetchStudyCalendarLoad(start: String, end: String) async throws -> StudyCalendarLoad {
        throw AssistantOfflineError()
    }

    func completeTask(id: Int, actualMinutes: Int?) async throws -> TaskCompletionResult {
        throw AssistantOfflineError()
    }

    func rolloverStudyTasks() async throws -> StudyRolloverResult {
        throw AssistantOfflineError()
    }

    func moveStudyTask(id: Int, scheduledDate: String) async throws -> StudyTaskMoveResult {
        throw AssistantOfflineError()
    }

    func updateStudyProjectDeadline(projectId: Int, deadline: String) async throws -> StudyProjectDeadlineUpdateResult {
        throw AssistantOfflineError()
    }

    func insertStudyProjectTask(
        projectId: Int,
        title: String,
        targetMinutes: Int,
        scheduledDate: String
    ) async throws -> StudyTaskInsertResult {
        throw AssistantOfflineError()
    }

    func deleteStudyTask(id: Int) async throws -> StudyTaskDeleteResult {
        throw AssistantOfflineError()
    }

    func fetchStudyRestDaySettings() async throws -> StudyRestDaySettings {
        throw AssistantOfflineError()
    }

    func updateStudyRestDaySettings(_ settings: StudyRestDaySettings) async throws -> StudyRestDaySettingsUpdateResult {
        throw AssistantOfflineError()
    }

    func fetchStudySmartModeSettings() async throws -> StudySmartModeSettings {
        throw AssistantOfflineError()
    }

    func updateStudySmartModeSettings(_ settings: StudySmartModeSettings) async throws -> StudySmartModeSettings {
        throw AssistantOfflineError()
    }

    func fetchStudySmartMorningBriefing() async throws -> StudySmartMorningBriefing {
        throw AssistantOfflineError()
    }

    func generateStudySmartProposals(_ request: StudySmartProposalGenerationRequest) async throws -> StudySmartProposalGenerationResponse {
        throw AssistantOfflineError()
    }

    func applyStudySmartProposal(_ request: StudySmartProposalApplyRequest) async throws -> StudySmartProposalApplyResult {
        throw AssistantOfflineError()
    }

    func previewStudyDialogueAdjustment(
        instruction: String,
        projectId: Int?
    ) async throws -> StudyDialogueAdjustmentPreview {
        throw AssistantOfflineError()
    }

    func applyStudyDialogueAdjustment(
        instruction: String,
        projectId: Int?,
        preview: StudyDialogueAdjustmentPreview
    ) async throws -> StudyDialogueAdjustmentApplyResult {
        throw AssistantOfflineError()
    }
}

extension AssistantAPIClient: AssistantAPIClientProtocol {}
