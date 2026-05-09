import Combine
import Foundation

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
}

// MARK: - ViewModel

/// 学习助手中栏数据层；ObservableObject 供 SwiftUI 视图订阅，兼容 macOS 13+。
@MainActor
final class LearningAssistantViewModel: ObservableObject {
    // MARK: State

    @Published var tasks: [AssistantTask]         = []
    @Published var resources: [AssistantResource] = []
    @Published var chatMessages: [ChatMessage]    = []
    @Published var currentProposal: String?       = nil
    @Published var isOffline: Bool                = false
    @Published var threadId: String?              = nil

    /// Ingestion 草稿（rawString from API）
    @Published var ingestionDraft: String?    = nil
    @Published var ingestionThreadId: String? = nil

    @Published var todayTotalMinutes: Int  = 0
    @Published var todayHighlights: String = ""

    @Published var isFetchingBriefing = false
    @Published var isSendingMessage   = false
    @Published var isIngesting        = false
    /// 后端进程启动中（还未收到就绪通知）；区别于运行期离线。
    @Published var isConnecting: Bool = true

    private let api = AssistantAPIClient.shared
    private var readyObserver: Any?

    // MARK: - Init

    init() {
        readyObserver = NotificationCenter.default.addObserver(
            forName: .backendDidBecomeReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isConnecting else { return }
                self.isConnecting = false
                await self.fetchTodayBriefing()
            }
        }

        // 若通知在订阅前已发出（后端早于视图初始化就绪），直接开始 fetch。
        if BackendProcessManager.shared.isReady {
            isConnecting = false
            Task { await fetchTodayBriefing() }
        }
    }

    deinit {
        if let readyObserver { NotificationCenter.default.removeObserver(readyObserver) }
    }

    // MARK: - Briefing

    func fetchTodayBriefing() async {
        isFetchingBriefing = true
        defer { isFetchingBriefing = false }
        do {
            let briefing      = try await api.fetchTodayBriefing()
            tasks             = briefing.tasks
            todayTotalMinutes = briefing.totalMinutes
            todayHighlights   = briefing.highlights
            isOffline         = false
            isConnecting      = false
        } catch {
            isOffline = true
        }
    }

    func fetchResources() async {
        do {
            resources = try await api.fetchResources()
            isOffline = false
        } catch {
            isOffline = true
        }
    }

    // MARK: - Task Completion

    func completeTask(_ task: AssistantTask) async {
        do {
            try await api.completeTask(id: task.id)
            // Optimistic update: mark locally while re-fetching
            await fetchTodayBriefing()
        } catch {
            isOffline = true
        }
    }

    // MARK: - Chat

    func sendMessage(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        chatMessages.append(ChatMessage(role: .user, text: text))
        isSendingMessage = true
        defer { isSendingMessage = false }
        do {
            let resp     = try await api.sendMessage(message: text, threadId: threadId)
            threadId     = resp.threadId
            chatMessages.append(ChatMessage(role: .assistant, text: resp.response))
            currentProposal = resp.proposal
            isOffline = false
        } catch {
            isOffline = true
            chatMessages.append(ChatMessage(role: .assistant, text: "⚠️ 助手离线，无法获取回复。"))
        }
    }

    func confirmProposal(confirmed: Bool) async {
        guard let tid = threadId else { return }
        do {
            try await api.confirmChat(threadId: tid, confirmed: confirmed)
            currentProposal = nil
            let msg = confirmed ? "✅ 变更已确认。" : "❌ 已取消变更。"
            chatMessages.append(ChatMessage(role: .assistant, text: msg))
            if confirmed { await fetchTodayBriefing() }
        } catch {
            isOffline = true
        }
    }

    // MARK: - Ingestion

    func startIngestion(url: String, deadline: Date, speedFactor: Double) async {
        isIngesting = true
        defer { isIngesting = false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let deadlineStr = formatter.string(from: deadline)
        do {
            let draft           = try await api.startIngestion(url: url, deadline: deadlineStr,
                                                               speedFactor: speedFactor)
            ingestionDraft    = draft.draft
            ingestionThreadId = draft.threadId
            isOffline         = false
        } catch {
            isOffline = true
        }
    }

    func confirmIngestion(confirmed: Bool) async {
        guard let tid = ingestionThreadId else { return }
        do {
            try await api.confirmIngestion(threadId: tid, confirmed: confirmed, selectedOption: nil)
            ingestionDraft    = nil
            ingestionThreadId = nil
            if confirmed { await fetchTodayBriefing() }
        } catch {
            isOffline = true
        }
    }
}
