import XCTest
@testable import MalDaze

// MARK: - Model Decoding Tests
// 直接验证后端 JSON → Swift 模型的解码正确性，覆盖 Bug A（IngestionDraft）和 Bug C（ChatResponse nullable）

final class AssistantModelDecodingTests: XCTestCase {

    // MARK: Bug A — IngestionDraft.draft 从 String 改为 IngestionDraftDetail

    func testIngestionDraftDecodesNestedDraftObject() throws {
        let json = """
        {
            "thread_id": "c414b9cb",
            "draft": {
                "resource_title": "基础算法精讲 高频面试题",
                "resource_type": "bilibili_series",
                "total_estimated_hours": 4.55,
                "unit_count": 27,
                "option_a": [{"date": "2026-05-09", "task_title": "集1", "target_minutes": 10}],
                "option_b": [{"date": "2026-05-10", "task_title": "集1", "target_minutes": 10}]
            }
        }
        """
        let draft = try decode(IngestionDraft.self, from: json)
        XCTAssertEqual(draft.threadId, "c414b9cb")
        XCTAssertEqual(draft.draft.resourceTitle, "基础算法精讲 高频面试题")
        XCTAssertEqual(draft.draft.resourceType, "bilibili_series")
        XCTAssertEqual(draft.draft.totalEstimatedHours, 4.55, accuracy: 0.001)
        XCTAssertEqual(draft.draft.unitCount, 27)
        XCTAssertEqual(draft.draft.optionA.count, 1)
        XCTAssertEqual(draft.draft.optionB.count, 1)
    }

    func testIngestionDraftDecodesGitHubRepo() throws {
        let json = """
        {
            "thread_id": "11354c8f",
            "draft": {
                "resource_title": "shareAI-lab/learn-claude-code",
                "resource_type": "github_repo",
                "total_estimated_hours": 13.75,
                "unit_count": 12,
                "option_a": [],
                "option_b": []
            }
        }
        """
        let draft = try decode(IngestionDraft.self, from: json)
        XCTAssertEqual(draft.draft.resourceTitle, "shareAI-lab/learn-claude-code")
        XCTAssertEqual(draft.draft.resourceType, "github_repo")
        XCTAssertEqual(draft.draft.totalEstimatedHours, 13.75, accuracy: 0.001)
        XCTAssertEqual(draft.draft.unitCount, 12)
    }

    // Bug A 反向验证：修复前旧的 String 解码会 throw；用嵌套 JSON 验证现在能成功
    func testIngestionDraftDoesNotThrowOnNestedJSON() {
        let json = """
        {"thread_id":"x","draft":{"resource_title":"R","resource_type":"web_article","total_estimated_hours":0.02,"unit_count":1,"option_a":[],"option_b":[]}}
        """
        XCTAssertNoThrow(try decode(IngestionDraft.self, from: json))
    }

    // MARK: Bug C — ChatResponse.response 从非 Optional String 改为 String?

    func testChatResponseResponseIsNullableWhenProposalPresent() throws {
        let json = """
        {
            "thread_id": "35ffe2c3",
            "response": null,
            "proposal": {
                "description": "今日任务已完成",
                "changes": [],
                "affects_deadline": false,
                "summary_for_user": "今天所有任务已完成。"
            }
        }
        """
        let resp = try decode(ChatResponse.self, from: json)
        XCTAssertNil(resp.response)
        XCTAssertNotNil(resp.proposal)
        XCTAssertEqual(resp.proposal?.summaryForUser, "今天所有任务已完成。")
        XCTAssertFalse(resp.proposal?.affectsDeadline ?? true)
        XCTAssertEqual(resp.proposal?.changes.count, 0)
    }

    func testChatResponseWithTextAndNoProposal() throws {
        let json = "{\"thread_id\":\"abc\",\"response\":\"今天有3个任务\",\"proposal\":null}"
        let resp = try decode(ChatResponse.self, from: json)
        XCTAssertEqual(resp.response, "今天有3个任务")
        XCTAssertNil(resp.proposal)
    }

    func testChatResponseWithRescheduleChanges() throws {
        let json = """
        {
            "thread_id": "xyz",
            "response": null,
            "proposal": {
                "description": "推迟任务",
                "changes": [{"action":"reschedule","task_id":2,"scheduled_date":"2026-05-11"}],
                "affects_deadline": false,
                "summary_for_user": "已将任务推迟到 2026-05-11"
            }
        }
        """
        let resp = try decode(ChatResponse.self, from: json)
        XCTAssertNil(resp.response)
        XCTAssertEqual(resp.proposal?.changes.count, 1)
        XCTAssertEqual(resp.proposal?.summaryForUser, "已将任务推迟到 2026-05-11")
    }

    // MARK: TodayBriefing

    func testTodayBriefingDecoding() throws {
        let json = """
        {
            "tasks": [
                {
                    "id": 1,
                    "title": "01 相向双指针",
                    "target_minutes": 13,
                    "completed_at": null,
                    "resource_title": "基础算法精讲",
                    "priority": 1
                }
            ],
            "total_minutes": 13,
            "highlights": "今日负荷正常"
        }
        """
        let briefing = try decode(TodayBriefing.self, from: json)
        XCTAssertEqual(briefing.tasks.count, 1)
        XCTAssertEqual(briefing.tasks[0].id, 1)
        XCTAssertEqual(briefing.tasks[0].title, "01 相向双指针")
        XCTAssertEqual(briefing.tasks[0].targetMinutes, 13)
        XCTAssertFalse(briefing.tasks[0].isCompleted)
        XCTAssertEqual(briefing.tasks[0].resourceTitle, "基础算法精讲")
        XCTAssertEqual(briefing.totalMinutes, 13)
    }

    func testBriefingTaskIsCompletedWhenCompletedAtPresent() throws {
        let json = """
        {"tasks":[{"id":1,"title":"T","target_minutes":10,"completed_at":"2026-05-09T17:46:14","resource_title":null,"priority":0}],"total_minutes":10,"highlights":""}
        """
        let briefing = try decode(TodayBriefing.self, from: json)
        XCTAssertTrue(briefing.tasks[0].isCompleted)
    }

    func testEmptyBriefingDecoding() throws {
        let json = "{\"tasks\":[],\"total_minutes\":0,\"highlights\":\"今日共 0 项任务\"}"
        let briefing = try decode(TodayBriefing.self, from: json)
        XCTAssertTrue(briefing.tasks.isEmpty)
        XCTAssertEqual(briefing.totalMinutes, 0)
    }

    // MARK: - Helper

    private func decode<T: Decodable>(_ type: T.Type, from jsonString: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(jsonString.utf8))
    }
}

// MARK: - ViewModel Tests
// 验证验收场景中涉及前端的各流程；使用 MockAssistantAPIClient 隔离网络

@MainActor
final class LearningAssistantViewModelTests: XCTestCase {

    // MARK: 0-3 空状态初始值

    func testInitialStateIsEmpty() {
        let vm = LearningAssistantViewModel(api: MockAssistantAPIClient())
        XCTAssertTrue(vm.tasks.isEmpty)
        XCTAssertTrue(vm.chatMessages.isEmpty)
        XCTAssertNil(vm.ingestionDraft)
        XCTAssertNil(vm.ingestionThreadId)
        XCTAssertFalse(vm.isOffline)
        XCTAssertEqual(vm.selectedOption, "A")
    }

    // MARK: 2-3 面板任务列表 — fetchTodayBriefing

    func testFetchBriefingPopulatesTasks() async {
        let mock = MockAssistantAPIClient()
        mock.briefingResult = TodayBriefing(
            tasks: [
                AssistantTask(id: 1, title: "01 相向双指针", targetMinutes: 13,
                              completedAt: nil, resourceTitle: "基础算法精讲", priority: 1)
            ],
            totalMinutes: 13,
            highlights: "今日负荷正常"
        )
        let vm = LearningAssistantViewModel(api: mock)
        await vm.fetchTodayBriefing()

        XCTAssertEqual(vm.tasks.count, 1)
        XCTAssertEqual(vm.tasks[0].title, "01 相向双指针")
        XCTAssertEqual(vm.todayTotalMinutes, 13)
        XCTAssertEqual(vm.todayHighlights, "今日负荷正常")
        XCTAssertFalse(vm.isOffline)
    }

    // MARK: 5-1 离线降级 — fetchBriefing

    func testFetchBriefingOfflineSetsIsOffline() async {
        let mock = MockAssistantAPIClient()
        mock.shouldThrowOffline = true
        let vm = LearningAssistantViewModel(api: mock)
        await vm.fetchTodayBriefing()
        XCTAssertTrue(vm.isOffline)
        XCTAssertTrue(vm.tasks.isEmpty)
    }

    // MARK: 1-1a/b 资料分析 → 草稿展示（Bug A 覆盖）

    func testStartIngestionSetsDraftDetail() async {
        let mock = MockAssistantAPIClient()
        mock.ingestionResult = IngestionDraft(
            threadId: "c414b9cb",
            draft: IngestionDraftDetail(
                resourceTitle: "基础算法精讲 高频面试题",
                resourceType: "bilibili_series",
                totalEstimatedHours: 4.55,
                unitCount: 27,
                optionA: [],
                optionB: []
            )
        )
        let vm = LearningAssistantViewModel(api: mock)
        await vm.startIngestion(url: "https://bilibili.com/BV1bP411c7oJ", deadline: Date(), speedFactor: 1.0)

        // Bug A: ingestionDraft 现在是 IngestionDraftDetail?，不再是 String?
        XCTAssertNotNil(vm.ingestionDraft)
        XCTAssertEqual(vm.ingestionDraft?.resourceTitle, "基础算法精讲 高频面试题")
        XCTAssertEqual(vm.ingestionDraft?.resourceType, "bilibili_series")
        XCTAssertEqual(vm.ingestionDraft?.unitCount, 27)
        XCTAssertEqual(vm.ingestionDraft?.totalEstimatedHours ?? 0, 4.55, accuracy: 0.001)
        XCTAssertEqual(vm.ingestionThreadId, "c414b9cb")
        XCTAssertEqual(vm.selectedOption, "A")   // 每次新 ingestion 重置为 A
        XCTAssertFalse(vm.isOffline)
    }

    func testStartIngestionOfflineSetsIsOffline() async {
        let mock = MockAssistantAPIClient()
        mock.shouldThrowOffline = true
        let vm = LearningAssistantViewModel(api: mock)
        await vm.startIngestion(url: "https://bad.example.com", deadline: Date(), speedFactor: 1.0)
        XCTAssertTrue(vm.isOffline)
        XCTAssertNil(vm.ingestionDraft)
    }

    // MARK: 1-2 确认草稿写入 — selectedOption 正确传给后端

    func testConfirmIngestionPassesSelectedOptionToAPI() async {
        let mock = MockAssistantAPIClient()
        let vm = LearningAssistantViewModel(api: mock)
        vm.ingestionThreadId = "t1"
        vm.selectedOption = "B"
        await vm.confirmIngestion(confirmed: true)

        XCTAssertNil(vm.ingestionDraft)
        XCTAssertNil(vm.ingestionThreadId)
        XCTAssertEqual(mock.lastConfirmIngestionConfirmed, true)
        XCTAssertEqual(mock.lastConfirmIngestionOption, "B")
    }

    // MARK: 1-3 取消草稿 — draft 被清除，API 收到 confirmed:false 且 option 为 nil

    func testCancelIngestionClearsDraft() async {
        let mock = MockAssistantAPIClient()
        let vm = LearningAssistantViewModel(api: mock)
        vm.ingestionThreadId = "t1"
        await vm.confirmIngestion(confirmed: false)

        XCTAssertNil(vm.ingestionDraft)
        XCTAssertNil(vm.ingestionThreadId)
        XCTAssertEqual(mock.lastConfirmIngestionConfirmed, false)
        XCTAssertNil(mock.lastConfirmIngestionOption)   // 取消时不传 selectedOption
    }

    // MARK: 4-1 对话查询 — 有文字回复

    func testSendMessageWithTextResponseAppendsAssistantMessage() async {
        let mock = MockAssistantAPIClient()
        mock.chatResult = ChatResponse(threadId: "t1", response: "今天有3个任务", proposal: nil)
        let vm = LearningAssistantViewModel(api: mock)
        await vm.sendMessage("今天有什么任务")

        XCTAssertEqual(vm.chatMessages.count, 2)
        XCTAssertEqual(vm.chatMessages[0].role, .user)
        XCTAssertEqual(vm.chatMessages[0].text, "今天有什么任务")
        XCTAssertEqual(vm.chatMessages[1].role, .assistant)
        XCTAssertEqual(vm.chatMessages[1].text, "今天有3个任务")
        XCTAssertNil(vm.currentProposal)
        XCTAssertEqual(vm.threadId, "t1")
    }

    // MARK: 4-2 减载请求 — response:null 时显示 summaryForUser（Bug C 覆盖）

    func testSendMessageWithNullResponseDisplaysProposalSummary() async {
        let mock = MockAssistantAPIClient()
        let proposal = ChatProposal(
            description: "今日任务已完成",
            changes: [],
            affectsDeadline: false,
            summaryForUser: "今天所有任务已完成。"
        )
        mock.chatResult = ChatResponse(threadId: "t2", response: nil, proposal: proposal)
        let vm = LearningAssistantViewModel(api: mock)
        await vm.sendMessage("今天不想学了")

        // Bug C: response:null + proposal → 显示 summaryForUser，不崩溃
        XCTAssertEqual(vm.chatMessages.count, 2)
        XCTAssertEqual(vm.chatMessages[1].text, "今天所有任务已完成。")
        XCTAssertEqual(vm.currentProposal, "今天所有任务已完成。")
    }

    func testSendMessageWithRescheduleProposalDisplaysSummary() async {
        let mock = MockAssistantAPIClient()
        let proposal = ChatProposal(
            description: "推迟任务",
            changes: [AnyCodable(["action": "reschedule"])],
            affectsDeadline: false,
            summaryForUser: "已将 2 个任务推迟到明天"
        )
        mock.chatResult = ChatResponse(threadId: "t3", response: nil, proposal: proposal)
        let vm = LearningAssistantViewModel(api: mock)
        await vm.sendMessage("把明天的任务推迟到后天")

        XCTAssertEqual(vm.chatMessages[1].text, "已将 2 个任务推迟到明天")
        XCTAssertEqual(vm.currentProposal, "已将 2 个任务推迟到明天")
    }

    // MARK: 4-3 确认变更

    func testConfirmProposalClearsCurrentProposalAndRefetches() async {
        let mock = MockAssistantAPIClient()
        let vm = LearningAssistantViewModel(api: mock)
        vm.threadId = "t1"
        vm.currentProposal = "等待确认"
        await vm.confirmProposal(confirmed: true)

        XCTAssertNil(vm.currentProposal)
        XCTAssertEqual(mock.lastConfirmChatConfirmed, true)
        XCTAssertGreaterThanOrEqual(mock.fetchBriefingCallCount, 1)  // 确认后 refetch
    }

    // MARK: 4-4 取消变更 — proposal 被清除，API 收到 confirmed:false

    func testCancelProposalClearsProposal() async {
        let mock = MockAssistantAPIClient()
        let vm = LearningAssistantViewModel(api: mock)
        vm.threadId = "t1"
        vm.currentProposal = "等待确认"
        await vm.confirmProposal(confirmed: false)

        XCTAssertNil(vm.currentProposal)
        XCTAssertEqual(mock.lastConfirmChatConfirmed, false)
        // 确认 confirm/cancel 后都追加了 assistant 消息
        XCTAssertTrue(vm.chatMessages.last?.text.contains("取消") ?? false)
    }

    // MARK: 5-1 离线降级 — 对话

    func testSendMessageOfflineSetsIsOfflineAndAppendsErrorMessage() async {
        let mock = MockAssistantAPIClient()
        mock.shouldThrowOffline = true
        let vm = LearningAssistantViewModel(api: mock)
        await vm.sendMessage("今天有什么任务")

        XCTAssertTrue(vm.isOffline)
        XCTAssertEqual(vm.chatMessages.count, 2)
        XCTAssertTrue(vm.chatMessages[1].text.contains("离线"))
    }

    // MARK: 3-1 任务完成标记

    func testCompleteTaskCallsAPIWithCorrectIDAndRefetches() async {
        let mock = MockAssistantAPIClient()
        let task = AssistantTask(id: 5, title: "T", targetMinutes: 10,
                                 completedAt: nil, resourceTitle: nil, priority: 0)
        let vm = LearningAssistantViewModel(api: mock)
        await vm.completeTask(task)

        XCTAssertEqual(mock.lastCompleteTaskId, 5)
        XCTAssertGreaterThanOrEqual(mock.fetchBriefingCallCount, 1)
    }
}

// MARK: - Mock API Client

private final class MockAssistantAPIClient: AssistantAPIClientProtocol, @unchecked Sendable {

    // Configurable results
    var briefingResult = TodayBriefing(tasks: [], totalMinutes: 0, highlights: "")
    var ingestionResult: IngestionDraft?
    var chatResult: ChatResponse?
    var shouldThrowOffline = false

    // Captured call arguments for assertions
    private(set) var fetchBriefingCallCount = 0
    private(set) var lastCompleteTaskId: Int?
    private(set) var lastConfirmChatConfirmed: Bool?
    private(set) var lastConfirmIngestionConfirmed: Bool?
    private(set) var lastConfirmIngestionOption: String?

    func fetchTodayBriefing() async throws -> TodayBriefing {
        fetchBriefingCallCount += 1
        if shouldThrowOffline { throw AssistantOfflineError() }
        return briefingResult
    }

    func completeTask(id: Int, actualMinutes: Int?) async throws {
        if shouldThrowOffline { throw AssistantOfflineError() }
        lastCompleteTaskId = id
    }

    func sendMessage(message: String, threadId: String?) async throws -> ChatResponse {
        if shouldThrowOffline { throw AssistantOfflineError() }
        return chatResult ?? ChatResponse(threadId: "mock", response: "ok", proposal: nil)
    }

    func confirmChat(threadId: String, confirmed: Bool) async throws {
        if shouldThrowOffline { throw AssistantOfflineError() }
        lastConfirmChatConfirmed = confirmed
    }

    func startIngestion(url: String, deadline: String, speedFactor: Double?) async throws -> IngestionDraft {
        if shouldThrowOffline { throw AssistantOfflineError() }
        return ingestionResult ?? IngestionDraft(
            threadId: "mock-thread",
            draft: IngestionDraftDetail(
                resourceTitle: "mock", resourceType: "web_article",
                totalEstimatedHours: 0.1, unitCount: 1, optionA: [], optionB: []
            )
        )
    }

    func confirmIngestion(threadId: String, confirmed: Bool, selectedOption: String?) async throws {
        if shouldThrowOffline { throw AssistantOfflineError() }
        lastConfirmIngestionConfirmed = confirmed
        lastConfirmIngestionOption = selectedOption
    }

    func fetchResources() async throws -> [AssistantResource] {
        if shouldThrowOffline { throw AssistantOfflineError() }
        return []
    }
}
