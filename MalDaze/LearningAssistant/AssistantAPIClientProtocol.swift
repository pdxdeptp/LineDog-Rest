import Foundation

/// 学习助手 API 客户端协议；生产代码用 AssistantAPIClient.shared，测试可注入 mock。
protocol AssistantAPIClientProtocol {
    func fetchTodayBriefing() async throws -> TodayBriefing
    func completeTask(id: Int, actualMinutes: Int?) async throws
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

extension AssistantAPIClient: AssistantAPIClientProtocol {}
