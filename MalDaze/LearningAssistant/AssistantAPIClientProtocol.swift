import Foundation

/// 学习助手 API 客户端协议；生产代码用 AssistantAPIClient.shared，测试可注入 mock。
protocol AssistantAPIClientProtocol {
    func fetchTodayBriefing() async throws -> TodayBriefing
    func completeTask(id: Int, actualMinutes: Int?) async throws
    func sendMessage(message: String, threadId: String?) async throws -> ChatResponse
    func confirmChat(threadId: String, confirmed: Bool) async throws
    func startIngestion(url: String, deadline: String, speedFactor: Double?) async throws -> IngestionDraft
    func confirmIngestion(threadId: String, confirmed: Bool, selectedOption: String?) async throws
    func fetchResources() async throws -> [AssistantResource]
}

extension AssistantAPIClient: AssistantAPIClientProtocol {}
