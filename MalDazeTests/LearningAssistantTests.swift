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

    func testAssistantTaskDecodesOptionalLearningLinks() throws {
        let json = """
        {
            "tasks": [
                {
                    "id": 1,
                    "title": "01 相向双指针",
                    "target_minutes": 13,
                    "completed_at": null,
                    "resource_title": "基础算法精讲",
                    "priority": 1,
                    "resource_url": "https://example.com/resource",
                    "unit_url": "https://example.com/unit"
                }
            ],
            "total_minutes": 13,
            "highlights": "今日负荷正常"
        }
        """
        let briefing = try decode(TodayBriefing.self, from: json)
        XCTAssertEqual(briefing.tasks[0].resourceURL, URL(string: "https://example.com/resource"))
        XCTAssertEqual(briefing.tasks[0].unitURL, URL(string: "https://example.com/unit"))
    }

    func testAssistantTaskDecodesMissingLearningLinksAsNil() throws {
        let json = """
        {
            "tasks": [
                {
                    "id": 1,
                    "title": "T",
                    "target_minutes": 10,
                    "completed_at": null,
                    "resource_title": null,
                    "priority": 0
                }
            ],
            "total_minutes": 10,
            "highlights": ""
        }
        """
        let briefing = try decode(TodayBriefing.self, from: json)
        XCTAssertNil(briefing.tasks[0].resourceURL)
        XCTAssertNil(briefing.tasks[0].unitURL)
    }

    func testAssistantTaskDecodesNullLearningLinksAsNil() throws {
        let json = """
        {
            "tasks": [
                {
                    "id": 1,
                    "title": "T",
                    "target_minutes": 10,
                    "completed_at": null,
                    "resource_title": null,
                    "priority": 0,
                    "resource_url": null,
                    "unit_url": null
                }
            ],
            "total_minutes": 10,
            "highlights": ""
        }
        """
        let briefing = try decode(TodayBriefing.self, from: json)
        XCTAssertNil(briefing.tasks[0].resourceURL)
        XCTAssertNil(briefing.tasks[0].unitURL)
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

// MARK: - UI Source Tests
// UI 层目前没有稳定的 SwiftUI inspection 依赖；这些测试锁定 OpenSpec 要求的结构和关键文案。

final class LearningAssistantUISourceTests: XCTestCase {

    func testAssistantPanelUsesDashboardHomeAndBottomNavigationInsteadOfSegmentedTabs() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("selectedPanelTab"))
        XCTAssertTrue(source.contains("bottomNavigationBar"))
        XCTAssertTrue(source.contains("首页"))
        XCTAssertTrue(source.contains("添加资料"))
        XCTAssertTrue(source.contains("资料进度"))
        XCTAssertTrue(source.contains("调整计划"))
        XCTAssertTrue(source.contains("fetchDashboard()"))
        XCTAssertFalse(source.contains(".pickerStyle(.segmented)"))
    }

    func testAssistantPanelCoversDashboardStatesAndReorderableTodayTasks() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("emptyDatabase"))
        XCTAssertTrue(source.contains("尚未添加学习资料"))
        XCTAssertTrue(source.contains("添加第一份资料"))
        XCTAssertTrue(source.contains("noTasksWithResources"))
        XCTAssertTrue(source.contains("今天没有安排学习任务"))
        XCTAssertTrue(source.contains("allTasksCompleted"))
        XCTAssertTrue(source.contains("今日已完成"))
        XCTAssertTrue(source.contains("hasDeadlineRisk"))
        XCTAssertTrue(source.contains("moveVisibleTasks"))
    }

    func testAssistantPanelProvidesFixtureInjectionAndPreviewStateMatrix() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("init(viewModel: LearningAssistantViewModel = LearningAssistantViewModel())"))
        XCTAssertTrue(source.contains("_vm = StateObject(wrappedValue: viewModel)"))
        XCTAssertTrue(source.contains("AssistantPanelPreviewFixtures"))
        XCTAssertTrue(source.contains("emptyDatabaseViewModel"))
        XCTAssertTrue(source.contains("backendStartingViewModel"))
        XCTAssertTrue(source.contains("wholeColumnOfflineViewModel"))
        XCTAssertTrue(source.contains("tasksTodayViewModel"))
        XCTAssertTrue(source.contains("taskExpandedWithLinkViewModel"))
        XCTAssertTrue(source.contains("taskExpandedWithoutLinkViewModel"))
        XCTAssertTrue(source.contains("resourcesWithoutTodayTasksViewModel"))
        XCTAssertTrue(source.contains("deadlineRiskViewModel"))
    }

    func testTaskRowProvidesIndependentHandleExpansionCompletionAndLearningLinkAction() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/TaskRowView.swift")

        XCTAssertTrue(source.contains("dragHandle"))
        XCTAssertTrue(source.contains("line.3.horizontal"))
        XCTAssertTrue(source.contains("onToggleExpansion"))
        XCTAssertTrue(source.contains("onComplete"))
        XCTAssertTrue(source.contains("打开链接"))
        XCTAssertTrue(source.contains("链接不可用"))
        XCTAssertTrue(source.contains("NSWorkspace.shared.open"))
    }

    private func sourceFile(_ relativePath: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let url = projectRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}

// MARK: - ViewModel Tests
// 验证验收场景中涉及前端的各流程；使用 MockAssistantAPIClient 隔离网络

@MainActor
final class LearningAssistantViewModelTests: XCTestCase {

    // MARK: 0-3 空状态初始值

    func testInitialStateIsEmpty() {
        let vm = LearningAssistantViewModel(api: MockAssistantAPIClient(), autoLoadWhenReady: false)
        XCTAssertTrue(vm.tasks.isEmpty)
        XCTAssertTrue(vm.chatMessages.isEmpty)
        XCTAssertNil(vm.ingestionDraft)
        XCTAssertNil(vm.ingestionThreadId)
        XCTAssertFalse(vm.isOffline)
        XCTAssertEqual(vm.selectedOption, "A")
    }

    // MARK: 1.4 / 3.2-3.6 首页 dashboard 状态层

    func testFetchDashboardAggregatesBriefingAndResourcesIntoSummaryState() async {
        let mock = MockAssistantAPIClient()
        mock.briefingResult = TodayBriefing(
            tasks: [
                AssistantTask(id: 1, title: "A", targetMinutes: 15,
                              completedAt: nil, resourceTitle: "R", priority: 1),
                AssistantTask(id: 2, title: "B", targetMinutes: 20,
                              completedAt: nil, resourceTitle: "R", priority: 2)
            ],
            totalMinutes: 35,
            highlights: "今日负荷正常"
        )
        mock.resourcesResult = [
            AssistantResource(id: 10, title: "R", trackingMode: "video",
                              completedUnits: 1, totalUnits: 5, actualMinutesTotal: 20,
                              deadline: nil, status: "active")
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.fetchDashboard()

        XCTAssertEqual(mock.fetchBriefingCallCount, 1)
        XCTAssertEqual(mock.fetchResourcesCallCount, 1)
        XCTAssertFalse(vm.isOffline)
        XCTAssertEqual(vm.dashboardState.kind, .tasksToday)
        XCTAssertEqual(vm.dashboardState.taskCount, 2)
        XCTAssertEqual(vm.dashboardState.totalMinutes, 35)
        XCTAssertEqual(vm.dashboardState.highlights, "今日负荷正常")
        XCTAssertEqual(vm.visibleTodayTasks.map(\.id), [1, 2])
    }

    func testDashboardEmptyDatabaseMarksAddResourceAsPrimaryAction() async {
        let mock = MockAssistantAPIClient()
        mock.briefingResult = TodayBriefing(tasks: [], totalMinutes: 0, highlights: "")
        mock.resourcesResult = []
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.fetchDashboard()

        XCTAssertEqual(vm.dashboardState.kind, .emptyDatabase)
        XCTAssertEqual(vm.dashboardState.primaryAction, .addResource)
        XCTAssertTrue(vm.visibleTodayTasks.isEmpty)
    }

    func testDashboardNoTasksWithResourcesDoesNotSelectNextTask() async {
        let mock = MockAssistantAPIClient()
        mock.briefingResult = TodayBriefing(tasks: [], totalMinutes: 0, highlights: "")
        mock.resourcesResult = [
            AssistantResource(id: 10, title: "R", trackingMode: "video",
                              completedUnits: 1, totalUnits: 5, actualMinutesTotal: 20,
                              deadline: nil, status: "active")
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.fetchDashboard()

        XCTAssertEqual(vm.dashboardState.kind, .noTasksWithResources)
        XCTAssertNil(vm.dashboardState.primaryTaskID)
        XCTAssertEqual(vm.selectedPanelTab, .home)
    }

    func testFetchDashboardFailureDoesNotKeepPartialSuccessState() async {
        let mock = MockAssistantAPIClient()
        mock.briefingResult = TodayBriefing(
            tasks: [AssistantTask(id: 1, title: "A", targetMinutes: 15,
                                  completedAt: nil, resourceTitle: "R", priority: 1)],
            totalMinutes: 15,
            highlights: "ok"
        )
        mock.resourcesResult = [
            AssistantResource(id: 10, title: "R", trackingMode: "video",
                              completedUnits: 1, totalUnits: 5, actualMinutesTotal: 20,
                              deadline: nil, status: "active")
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchDashboard()

        mock.shouldThrowResources = true
        mock.briefingResult = TodayBriefing(
            tasks: [AssistantTask(id: 2, title: "B", targetMinutes: 20,
                                  completedAt: nil, resourceTitle: "R2", priority: 1)],
            totalMinutes: 20,
            highlights: "new"
        )
        await vm.fetchDashboard()

        XCTAssertTrue(vm.isOffline)
        XCTAssertEqual(vm.dashboardState.kind, .offline)
        XCTAssertTrue(vm.tasks.isEmpty)
        XCTAssertTrue(vm.resources.isEmpty)
        XCTAssertTrue(vm.visibleTodayTasks.isEmpty)
    }

    func testLocalTaskDisplayOrderPersistsAndMergesChangedTaskSet() async {
        let mock = MockAssistantAPIClient()
        let defaults = UserDefaults(suiteName: "LearningAssistantTests.order.\(UUID().uuidString)")!
        mock.briefingResult = TodayBriefing(
            tasks: [
                AssistantTask(id: 1, title: "A", targetMinutes: 10,
                              completedAt: nil, resourceTitle: nil, priority: 1),
                AssistantTask(id: 2, title: "B", targetMinutes: 10,
                              completedAt: nil, resourceTitle: nil, priority: 2),
                AssistantTask(id: 3, title: "C", targetMinutes: 10,
                              completedAt: nil, resourceTitle: nil, priority: 3)
            ],
            totalMinutes: 30,
            highlights: ""
        )
        let vm = LearningAssistantViewModel(
            api: mock,
            orderStore: defaults,
            todayProvider: { Date(timeIntervalSince1970: 1_778_630_400) },
            autoLoadWhenReady: false
        )
        await vm.fetchDashboard()

        vm.moveVisibleTasks(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(vm.visibleTodayTasks.map(\.id), [3, 1, 2])

        mock.briefingResult = TodayBriefing(
            tasks: [
                AssistantTask(id: 2, title: "B", targetMinutes: 10,
                              completedAt: nil, resourceTitle: nil, priority: 2),
                AssistantTask(id: 3, title: "C", targetMinutes: 10,
                              completedAt: nil, resourceTitle: nil, priority: 3),
                AssistantTask(id: 4, title: "D", targetMinutes: 10,
                              completedAt: nil, resourceTitle: nil, priority: 4)
            ],
            totalMinutes: 30,
            highlights: ""
        )
        await vm.fetchDashboard()

        XCTAssertEqual(vm.visibleTodayTasks.map(\.id), [3, 2, 4])
        XCTAssertNil(mock.lastCompleteTaskId)
    }

    func testLocalTaskDisplayOrderUsesUserLocalTodayKey() async throws {
        let previousTimeZone = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: "America/New_York")!
        defer { NSTimeZone.default = previousTimeZone }

        let mock = MockAssistantAPIClient()
        let defaults = UserDefaults(suiteName: "LearningAssistantTests.order.\(UUID().uuidString)")!
        defaults.set([2, 1], forKey: "LearningAssistant.todayTaskOrder.2026-01-31")
        mock.briefingResult = TodayBriefing(
            tasks: [
                AssistantTask(id: 1, title: "A", targetMinutes: 10,
                              completedAt: nil, resourceTitle: nil, priority: 1),
                AssistantTask(id: 2, title: "B", targetMinutes: 10,
                              completedAt: nil, resourceTitle: nil, priority: 2)
            ],
            totalMinutes: 20,
            highlights: ""
        )
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-02-01T02:00:00Z"))
        let vm = LearningAssistantViewModel(
            api: mock,
            orderStore: defaults,
            todayProvider: { date },
            autoLoadWhenReady: false
        )

        await vm.fetchDashboard()

        XCTAssertEqual(vm.visibleTodayTasks.map(\.id), [2, 1])
    }

    func testTaskExpansionTogglesAndLearningLinkPrefersUnitURL() {
        let vm = LearningAssistantViewModel(api: MockAssistantAPIClient(), autoLoadWhenReady: false)
        let task = AssistantTask(
            id: 1,
            title: "T",
            targetMinutes: 10,
            completedAt: nil,
            resourceTitle: "R",
            priority: 0,
            resourceURL: URL(string: "https://example.com/resource"),
            unitURL: URL(string: "https://example.com/unit")
        )

        XCTAssertFalse(vm.isTaskExpanded(task))
        vm.toggleTaskExpansion(task)
        XCTAssertTrue(vm.isTaskExpanded(task))
        XCTAssertEqual(vm.learningLink(for: task), .available(URL(string: "https://example.com/unit")!))
        vm.toggleTaskExpansion(task)
        XCTAssertFalse(vm.isTaskExpanded(task))
    }

    func testLearningLinkFallsBackToResourceURLAndCanBeUnavailable() {
        let vm = LearningAssistantViewModel(api: MockAssistantAPIClient(), autoLoadWhenReady: false)
        let resourceOnly = AssistantTask(
            id: 1,
            title: "T",
            targetMinutes: 10,
            completedAt: nil,
            resourceTitle: "R",
            priority: 0,
            resourceURL: URL(string: "https://example.com/resource")
        )
        let noLink = AssistantTask(id: 2, title: "N", targetMinutes: 10,
                                   completedAt: nil, resourceTitle: nil, priority: 0)

        XCTAssertEqual(vm.learningLink(for: resourceOnly), .available(URL(string: "https://example.com/resource")!))
        XCTAssertEqual(vm.learningLink(for: noLink), .unavailable)
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
    var resourcesResult: [AssistantResource] = []
    var ingestionResult: IngestionDraft?
    var chatResult: ChatResponse?
    var shouldThrowOffline = false
    var shouldThrowResources = false

    // Captured call arguments for assertions
    private(set) var fetchBriefingCallCount = 0
    private(set) var fetchResourcesCallCount = 0
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
        fetchResourcesCallCount += 1
        if shouldThrowOffline || shouldThrowResources { throw AssistantOfflineError() }
        return resourcesResult
    }
}
