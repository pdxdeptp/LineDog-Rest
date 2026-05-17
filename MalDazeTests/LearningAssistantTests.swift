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

    func testAssistantResourceDecodesURLIntoResourceURL() throws {
        let json = """
        {
            "id": 42,
            "title": "Swift Concurrency Guide",
            "tracking_mode": "article",
            "completed_units": 2,
            "total_units": 8,
            "actual_minutes_total": 75,
            "deadline": "2026-06-01",
            "status": "active",
            "url": "https://example.com/swift-concurrency"
        }
        """
        let resource = try decode(AssistantResource.self, from: json)
        XCTAssertEqual(resource.resourceURL, URL(string: "https://example.com/swift-concurrency"))
    }

    func testAssistantResourceTreatsMissingNullOrInvalidURLAsNil() throws {
        let missingURL = """
        {"id":1,"title":"A","tracking_mode":"article","completed_units":0,"total_units":1,"actual_minutes_total":0,"deadline":null,"status":"active"}
        """
        let nullURL = """
        {"id":2,"title":"B","tracking_mode":"article","completed_units":0,"total_units":1,"actual_minutes_total":0,"deadline":null,"status":"active","url":null}
        """
        let invalidURL = """
        {"id":3,"title":"C","tracking_mode":"article","completed_units":0,"total_units":1,"actual_minutes_total":0,"deadline":null,"status":"active","url":"not a valid url"}
        """

        XCTAssertNil(try decode(AssistantResource.self, from: missingURL).resourceURL)
        XCTAssertNil(try decode(AssistantResource.self, from: nullURL).resourceURL)
        XCTAssertNil(try decode(AssistantResource.self, from: invalidURL).resourceURL)
    }

    func testAssistantResourceRejectsUnsafeResourceURLSchemes() throws {
        let fileURL = """
        {"id":4,"title":"D","tracking_mode":"article","completed_units":0,"total_units":1,"actual_minutes_total":0,"deadline":null,"status":"active","url":"file:///Users/cpt/.ssh/id_rsa"}
        """
        let mailtoURL = """
        {"id":5,"title":"E","tracking_mode":"article","completed_units":0,"total_units":1,"actual_minutes_total":0,"deadline":null,"status":"active","url":"mailto:test@example.com"}
        """
        let customSchemeURL = """
        {"id":6,"title":"F","tracking_mode":"article","completed_units":0,"total_units":1,"actual_minutes_total":0,"deadline":null,"status":"active","url":"maliciousapp://open"}
        """

        XCTAssertNil(try decode(AssistantResource.self, from: fileURL).resourceURL)
        XCTAssertNil(try decode(AssistantResource.self, from: mailtoURL).resourceURL)
        XCTAssertNil(try decode(AssistantResource.self, from: customSchemeURL).resourceURL)
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

    func testResourceProgressCardsExposeManagementActions() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/ResourceProgressView.swift")

        XCTAssertTrue(source.contains("onOpen"))
        XCTAssertTrue(source.contains("onAdjustPlan"))
        XCTAssertTrue(source.contains("onComplete"))
        XCTAssertTrue(source.contains("onArchive"))
        XCTAssertTrue(source.contains("isManagementInFlight"))
        XCTAssertTrue(source.contains("isLocalManagementInFlight"))
        XCTAssertTrue(source.contains(".disabled(isResourceManagementInFlight)"))
        XCTAssertTrue(source.contains("NSWorkspace.shared.open"))
        XCTAssertTrue(source.contains("打开资料"))
        XCTAssertTrue(source.contains("调整计划"))
        XCTAssertTrue(source.contains("标记完成"))
        XCTAssertTrue(source.contains("移出当前计划"))
    }

    func testAssistantPanelWiresResourceProgressManagementActionsAndFeedback() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("resourceManagementError"))
        XCTAssertTrue(source.contains("clearResourceManagementError"))
        XCTAssertTrue(source.contains("seedAdjustPlan(for: resource)"))
        XCTAssertTrue(source.contains("completeResource(resource)"))
        XCTAssertTrue(source.contains("archiveResource(resource)"))
        XCTAssertTrue(source.contains("isManagingResource(resource)"))
    }

    func testChatViewConsumesResourceAdjustPlanDraftText() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/ChatView.swift")

        XCTAssertTrue(source.contains("consumeAdjustPlanDraftText"))
        XCTAssertTrue(source.contains("inputText = draft"))
        XCTAssertTrue(source.contains("inputFocused = true"))
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
        XCTAssertEqual(vm.selectedOption, "B")  // default is now "B"
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

    // MARK: 1-1a/b 资料分析 → 草稿展示（via SSE）

    func testStartIngestionSetsDraftDetailViaSse() async {
        let mock = MockAssistantAPIClient()
        mock.startIngestionThreadId = "c414b9cb"
        mock.progressEvents = [
            IngestionProgressEvent(
                phase: "draft_ready",
                label: "草稿已就绪",
                done: true,
                draft: IngestionDraftDetail(
                    resourceTitle: "基础算法精讲 高频面试题",
                    resourceType: "bilibili_series",
                    totalEstimatedHours: 4.55,
                    unitCount: 27,
                    optionA: [],
                    optionB: []
                ),
                error: nil
            )
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.startIngestion(url: "https://bilibili.com/BV1bP411c7oJ", deadline: Date(), speedFactor: 1.0)
        // Allow SSE task to complete
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(vm.ingestionDraft)
        XCTAssertEqual(vm.ingestionDraft?.resourceTitle, "基础算法精讲 高频面试题")
        XCTAssertEqual(vm.ingestionDraft?.resourceType, "bilibili_series")
        XCTAssertEqual(vm.ingestionDraft?.unitCount, 27)
        XCTAssertEqual(vm.ingestionDraft?.totalEstimatedHours ?? 0, 4.55, accuracy: 0.001)
        XCTAssertEqual(vm.ingestionThreadId, "c414b9cb")
        XCTAssertFalse(vm.isOffline)
    }

    func testStartIngestionOfflineSetsIsOffline() async {
        let mock = MockAssistantAPIClient()
        mock.shouldThrowOffline = true
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.startIngestion(url: "https://bad.example.com", deadline: Date(), speedFactor: 1.0)
        XCTAssertTrue(vm.isOffline)
        XCTAssertNil(vm.ingestionDraft)
    }

    // MARK: 1-2 确认草稿写入 — selectedOption 正确传给后端

    func testConfirmIngestionPassesSelectedOptionToAPI() async {
        let mock = MockAssistantAPIClient()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.ingestionThreadId = "t1"
        vm.selectedOption = "B"
        await vm.confirmIngestion(confirmed: true)

        XCTAssertNil(vm.ingestionDraft)
        XCTAssertNil(vm.ingestionThreadId)
        XCTAssertEqual(mock.lastConfirmIngestionConfirmed, true)
        XCTAssertEqual(mock.lastConfirmIngestionOption, "B")
    }

    // MARK: 1-3 取消草稿 — cancelDraft 清除 draft（纯本地操作）

    func testCancelIngestionClearsDraft() {
        let mock = MockAssistantAPIClient()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.ingestionThreadId = "t1"
        vm.ingestionDraft = sampleDraftDetail()
        vm.confirmIngestion(cancelDraft: true)

        XCTAssertNil(vm.ingestionDraft)
        XCTAssertNil(vm.ingestionThreadId)
        XCTAssertEqual(vm.selectedOption, "B")
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

    func testResourceManagementProtocolCallsCompleteAndArchiveEndpoints() async throws {
        let mock = MockAssistantAPIClient()
        let api: any AssistantAPIClientProtocol = mock

        try await api.completeResource(id: 42)
        try await api.archiveResource(id: 43)

        XCTAssertEqual(mock.lastCompleteResourceId, 42)
        XCTAssertEqual(mock.lastArchiveResourceId, 43)
    }

    func testCompleteResourceCallsAPIAndRefreshesDashboard() async {
        let mock = MockAssistantAPIClient()
        mock.resourcesResult = [sampleResource(id: 99, title: "Remaining Resource")]
        mock.briefingResult = TodayBriefing(
            tasks: [AssistantTask(id: 7, title: "Next", targetMinutes: 20,
                                  completedAt: nil, resourceTitle: "Remaining Resource", priority: 1)],
            totalMinutes: 20,
            highlights: "refreshed"
        )
        let resource = sampleResource(id: 42, title: "Swift Concurrency Guide")
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.resources = [resource]

        await vm.completeResource(resource)

        XCTAssertEqual(mock.lastCompleteResourceId, 42)
        XCTAssertEqual(mock.fetchBriefingCallCount, 1)
        XCTAssertEqual(mock.fetchResourcesCallCount, 1)
        XCTAssertNil(vm.resourceManagementError)
        XCTAssertEqual(vm.resources.map(\.id), [99])
        XCTAssertEqual(vm.tasks.map(\.id), [7])
    }

    func testArchiveResourceCallsAPIAndRefreshesDashboard() async {
        let mock = MockAssistantAPIClient()
        mock.resourcesResult = []
        let resource = sampleResource(id: 43, title: "Old Plan")
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.resources = [resource]

        await vm.archiveResource(resource)

        XCTAssertEqual(mock.lastArchiveResourceId, 43)
        XCTAssertEqual(mock.fetchBriefingCallCount, 1)
        XCTAssertEqual(mock.fetchResourcesCallCount, 1)
        XCTAssertNil(vm.resourceManagementError)
        XCTAssertTrue(vm.resources.isEmpty)
    }

    func testResourceManagementFailurePreservesResourcesAndShowsClearableError() async {
        let mock = MockAssistantAPIClient()
        mock.shouldThrowResourceManagement = true
        let resource = sampleResource(id: 44, title: "Do Not Remove")
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.resources = [resource]

        await vm.archiveResource(resource)

        XCTAssertEqual(mock.lastArchiveResourceId, 44)
        XCTAssertEqual(vm.resources.map(\.id), [44])
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
        XCTAssertEqual(mock.fetchResourcesCallCount, 0)
        XCTAssertNotNil(vm.resourceManagementError)

        vm.clearResourceManagementError()
        XCTAssertNil(vm.resourceManagementError)
    }

    func testResourceManagementRefreshFailurePreservesDashboardAndReportsRefreshError() async {
        let mock = MockAssistantAPIClient()
        mock.shouldThrowResources = true
        mock.briefingResult = TodayBriefing(
            tasks: [AssistantTask(id: 200, title: "Server Update", targetMinutes: 15,
                                  completedAt: nil, resourceTitle: "Server", priority: 1)],
            totalMinutes: 15,
            highlights: "new data that should not partially apply"
        )
        let task = AssistantTask(id: 100, title: "Keep Visible", targetMinutes: 25,
                                 completedAt: nil, resourceTitle: "Local Resource", priority: 2)
        let resource = sampleResource(id: 45, title: "Local Resource")
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.tasks = [task]
        vm.visibleTodayTasks = [task]
        vm.resources = [resource]
        vm.todayTotalMinutes = 25
        vm.todayHighlights = "local state"

        await vm.completeResource(resource)

        XCTAssertEqual(mock.lastCompleteResourceId, 45)
        XCTAssertEqual(mock.fetchBriefingCallCount, 1)
        XCTAssertEqual(mock.fetchResourcesCallCount, 1)
        XCTAssertEqual(vm.tasks.map(\.id), [100])
        XCTAssertEqual(vm.visibleTodayTasks.map(\.id), [100])
        XCTAssertEqual(vm.resources.map(\.id), [45])
        XCTAssertEqual(vm.todayTotalMinutes, 25)
        XCTAssertEqual(vm.todayHighlights, "local state")
        XCTAssertTrue(vm.resourceManagementError?.contains("刷新") ?? false)
    }

    func testSuccessfulFetchResourcesClearsStaleResourceManagementError() async {
        let mock = MockAssistantAPIClient()
        mock.resourcesResult = [sampleResource(id: 46, title: "Fresh")]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.resourceManagementError = "之前的资源操作失败"

        await vm.fetchResources()

        XCTAssertNil(vm.resourceManagementError)
        XCTAssertEqual(vm.resources.map(\.id), [46])
    }

    func testResourceManagementIgnoresDuplicateArchiveWhileResourceIsInFlight() async {
        let mock = MockAssistantAPIClient()
        mock.resourceManagementDelayNanoseconds = 50_000_000
        let resource = sampleResource(id: 47, title: "Only Archive Once")
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.resources = [resource]

        let firstRequest = Task {
            await vm.archiveResource(resource)
        }
        try? await Task.sleep(nanoseconds: 10_000_000)

        await vm.archiveResource(resource)
        await firstRequest.value

        XCTAssertEqual(mock.archiveResourceCallCount, 1)
        XCTAssertEqual(mock.fetchBriefingCallCount, 1)
        XCTAssertEqual(mock.fetchResourcesCallCount, 1)
        XCTAssertNil(vm.resourceManagementError)
    }

    func testResourceManagementIgnoresDifferentResourceWhileAnotherResourceIsInFlight() async {
        let mock = MockAssistantAPIClient()
        mock.resourceManagementDelayNanoseconds = 50_000_000
        let firstResource = sampleResource(id: 48, title: "First Resource")
        let secondResource = sampleResource(id: 49, title: "Second Resource")
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.resources = [firstResource, secondResource]

        let firstRequest = Task {
            await vm.archiveResource(firstResource)
        }
        try? await Task.sleep(nanoseconds: 10_000_000)

        await vm.completeResource(secondResource)
        await firstRequest.value

        XCTAssertEqual(mock.archiveResourceCallCount, 1)
        XCTAssertEqual(mock.completeResourceCallCount, 0)
        XCTAssertEqual(mock.fetchBriefingCallCount, 1)
        XCTAssertEqual(mock.fetchResourcesCallCount, 1)
        XCTAssertNil(vm.resourceManagementError)
    }

    func testSeedAdjustPlanForResourceSelectsAdjustPlanAndIncludesTitleAndIDInDraft() {
        let vm = LearningAssistantViewModel(api: MockAssistantAPIClient(), autoLoadWhenReady: false)
        let resource = sampleResource(id: 45, title: "Distributed Systems Notes")

        vm.seedAdjustPlan(for: resource)

        XCTAssertEqual(vm.selectedPanelTab, .adjustPlan)
        XCTAssertTrue(vm.adjustPlanDraftText?.contains("Distributed Systems Notes") ?? false)
        XCTAssertTrue(vm.adjustPlanDraftText?.contains("ID: 45") ?? false)

        let draft = vm.consumeAdjustPlanDraftText()
        XCTAssertTrue(draft?.contains("Distributed Systems Notes") ?? false)
        XCTAssertTrue(draft?.contains("ID: 45") ?? false)
        XCTAssertNil(vm.adjustPlanDraftText)
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
    var shouldThrowResourceManagement = false
    var resourceManagementDelayNanoseconds: UInt64 = 0
    // New: for updated protocol methods
    var startIngestionThreadId: String = "mock-thread"
    var progressEvents: [IngestionProgressEvent] = []
    var rescheduleResult: IngestionDraftDetail?
    var rescheduleError: Error?
    var learningPreferencesResult = LearningPreferences(dailyCapacityMin: 60)

    // Captured call arguments for assertions
    private(set) var fetchBriefingCallCount = 0
    private(set) var fetchResourcesCallCount = 0
    private(set) var lastCompleteTaskId: Int?
    private(set) var lastCompleteResourceId: Int?
    private(set) var lastArchiveResourceId: Int?
    private(set) var completeResourceCallCount = 0
    private(set) var archiveResourceCallCount = 0
    private(set) var lastConfirmChatConfirmed: Bool?
    private(set) var lastConfirmIngestionConfirmed: Bool?
    private(set) var lastConfirmIngestionOption: String?
    private(set) var lastConfirmIngestionDeadline: String?
    private(set) var lastConfirmIngestionSpeedFactor: Double?
    private(set) var lastRescheduleDeadline: String?
    private(set) var lastRescheduleSpeedFactor: Double?

    func fetchTodayBriefing() async throws -> TodayBriefing {
        fetchBriefingCallCount += 1
        if shouldThrowOffline { throw AssistantOfflineError() }
        return briefingResult
    }

    func completeTask(id: Int, actualMinutes: Int?) async throws {
        if shouldThrowOffline { throw AssistantOfflineError() }
        lastCompleteTaskId = id
    }

    func completeResource(id: Int) async throws {
        completeResourceCallCount += 1
        lastCompleteResourceId = id
        if resourceManagementDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: resourceManagementDelayNanoseconds)
        }
        if shouldThrowOffline || shouldThrowResourceManagement { throw AssistantOfflineError() }
    }

    func archiveResource(id: Int) async throws {
        archiveResourceCallCount += 1
        lastArchiveResourceId = id
        if resourceManagementDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: resourceManagementDelayNanoseconds)
        }
        if shouldThrowOffline || shouldThrowResourceManagement { throw AssistantOfflineError() }
    }

    func sendMessage(message: String, threadId: String?) async throws -> ChatResponse {
        if shouldThrowOffline { throw AssistantOfflineError() }
        return chatResult ?? ChatResponse(threadId: "mock", response: "ok", proposal: nil)
    }

    func confirmChat(threadId: String, confirmed: Bool) async throws {
        if shouldThrowOffline { throw AssistantOfflineError() }
        lastConfirmChatConfirmed = confirmed
    }

    // Updated: now returns String (thread_id)
    func startIngestion(url: String, deadline: String, speedFactor: Double?) async throws -> String {
        if shouldThrowOffline { throw AssistantOfflineError() }
        return startIngestionThreadId
    }

    func subscribeIngestionProgress(threadId: String) -> AsyncThrowingStream<IngestionProgressEvent, Error> {
        let events = progressEvents
        return AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    func rescheduleIngestion(threadId: String, deadline: String, speedFactor: Double) async throws -> IngestionDraftDetail {
        lastRescheduleDeadline = deadline
        lastRescheduleSpeedFactor = speedFactor
        if let err = rescheduleError { throw err }
        if shouldThrowOffline { throw AssistantOfflineError() }
        return rescheduleResult ?? sampleDraftDetail()
    }

    func confirmIngestion(threadId: String, confirmed: Bool, selectedOption: String?, deadline: String?, speedFactor: Double?) async throws {
        if shouldThrowOffline { throw AssistantOfflineError() }
        lastConfirmIngestionConfirmed = confirmed
        lastConfirmIngestionOption = selectedOption
        lastConfirmIngestionDeadline = deadline
        lastConfirmIngestionSpeedFactor = speedFactor
    }

    func fetchResources() async throws -> [AssistantResource] {
        fetchResourcesCallCount += 1
        if shouldThrowOffline || shouldThrowResources { throw AssistantOfflineError() }
        return resourcesResult
    }

    func getLearningPreferences() async throws -> LearningPreferences {
        if shouldThrowOffline { throw AssistantOfflineError() }
        return learningPreferencesResult
    }

    func updateLearningPreferences(_ prefs: LearningPreferences) async throws {
        if shouldThrowOffline { throw AssistantOfflineError() }
    }
}

// MARK: - Shared test fixtures

private func sampleDraftDetail() -> IngestionDraftDetail {
    IngestionDraftDetail(
        resourceTitle: "测试资料",
        resourceType: "bilibili_series",
        totalEstimatedHours: 4.0,
        unitCount: 10,
        optionA: [],
        optionB: []
    )
}

private func sampleResource(id: Int, title: String) -> AssistantResource {
    AssistantResource(
        id: id,
        title: title,
        trackingMode: "article",
        completedUnits: 1,
        totalUnits: 5,
        actualMinutesTotal: 45,
        deadline: nil,
        status: "active",
        resourceURL: URL(string: "https://example.com/resources/\(id)")
    )
}

// MARK: - New ViewModel Ingestion Tests (Tasks 3.1–3.6)

@MainActor
final class IngestionViewModelTests: XCTestCase {

    // MARK: 3.1 selectedOption defaults to "B"

    func testSelectedOptionDefaultsToB() {
        let vm = LearningAssistantViewModel(api: MockAssistantAPIClient(), autoLoadWhenReady: false)
        XCTAssertEqual(vm.selectedOption, "B")
    }

    // MARK: 3.5 cancel preserves VM state

    func testCancelPreservesURL() {
        let vm = LearningAssistantViewModel(api: MockAssistantAPIClient(), autoLoadWhenReady: false)
        vm.ingestionDraft = sampleDraftDetail()
        vm.ingestionThreadId = "test-thread"
        vm.confirmIngestion(cancelDraft: true)
        XCTAssertNil(vm.ingestionDraft)
        XCTAssertNil(vm.ingestionThreadId)
        XCTAssertEqual(vm.selectedOption, "B")
    }

    // MARK: 3.6 canConfirm logic — unsynced params

    func testCanConfirmFalseWhenParamsUnsynced() {
        let vm = LearningAssistantViewModel(api: MockAssistantAPIClient(), autoLoadWhenReady: false)
        vm.ingestionDraft = sampleDraftDetail()
        vm.isRescheduling = false
        // After user changes deadline but hasn't synced yet
        vm.currentDeadline = "2026-07-01"
        vm.lastSyncedDeadline = "2026-06-01"
        vm.lastSyncedSpeedFactor = 1.0
        vm.currentSpeedFactor = 1.0
        XCTAssertFalse(vm.canConfirm)
    }

    // MARK: 3.6 canConfirm logic — synced params

    func testCanConfirmTrueAfterSuccessfulReschedule() {
        let vm = LearningAssistantViewModel(api: MockAssistantAPIClient(), autoLoadWhenReady: false)
        vm.ingestionDraft = sampleDraftDetail()
        vm.currentDeadline = "2026-07-01"
        vm.currentSpeedFactor = 1.0
        vm.lastSyncedDeadline = "2026-07-01"
        vm.lastSyncedSpeedFactor = 1.0
        vm.isRescheduling = false
        XCTAssertTrue(vm.canConfirm)
    }

    // MARK: 3.6 canConfirm — initial state (never rescheduled) allows confirm

    func testCanConfirmTrueInInitialStateNeverRescheduled() {
        let vm = LearningAssistantViewModel(api: MockAssistantAPIClient(), autoLoadWhenReady: false)
        vm.ingestionDraft = sampleDraftDetail()
        vm.isRescheduling = false
        // lastSyncedDeadline is nil → canConfirm should be true
        XCTAssertTrue(vm.canConfirm)
    }

    // MARK: 3.5 session expired clears draft

    func testSessionExpiredClearsDraft() async {
        let mock = MockAssistantAPIClient()
        mock.rescheduleError = ThreadNotFoundError()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.ingestionDraft = sampleDraftDetail()
        vm.ingestionThreadId = "test-thread"
        await vm.reschedule(deadline: "2026-07-01", speedFactor: 1.0)
        XCTAssertNil(vm.ingestionDraft)
        XCTAssertNil(vm.ingestionThreadId)
        XCTAssertEqual(vm.ingestionError, "session_expired")
    }

    // MARK: 3.2 SSE phases update ingestionPhase

    func testSSEPhasesUpdateIngestionPhase() async {
        let mock = MockAssistantAPIClient()
        mock.startIngestionThreadId = "sse-thread"
        mock.progressEvents = [
            IngestionProgressEvent(phase: "fetch_structure", label: "正在读取章节结构…", done: false, draft: nil, error: nil),
            IngestionProgressEvent(phase: "draft_ready", label: "草稿已就绪", done: true, draft: sampleDraftDetail(), error: nil),
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.startIngestion(url: "https://example.com", deadline: Date().addingTimeInterval(86400 * 30), speedFactor: 1.0)
        // Give the async analysisTask time to process
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNotNil(vm.ingestionDraft)
        XCTAssertEqual(vm.ingestionDraft?.resourceTitle, "测试资料")
        XCTAssertFalse(vm.isIngesting)
    }

    // MARK: 3.3 reschedule updates ingestionDraft and syncs params

    func testRescheduleUpdatesIngestionDraft() async {
        let mock = MockAssistantAPIClient()
        mock.rescheduleResult = IngestionDraftDetail(
            resourceTitle: "重排后资料",
            resourceType: "github_repo",
            totalEstimatedHours: 6.0,
            unitCount: 12,
            optionA: [],
            optionB: []
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.ingestionThreadId = "test-thread"

        await vm.reschedule(deadline: "2026-08-01", speedFactor: 1.5)

        XCTAssertEqual(vm.ingestionDraft?.resourceTitle, "重排后资料")
        XCTAssertEqual(vm.lastSyncedDeadline, "2026-08-01")
        XCTAssertEqual(vm.lastSyncedSpeedFactor ?? 0, 1.5, accuracy: 0.001)
        XCTAssertFalse(vm.isRescheduling)
        XCTAssertFalse(vm.rescheduleError)
    }

    // MARK: 3.4 confirmIngestion passes deadline and speedFactor

    func testConfirmIngestionPassesDeadlineAndSpeedFactor() async {
        let mock = MockAssistantAPIClient()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.ingestionThreadId = "t-confirm"
        vm.selectedOption = "A"
        vm.currentDeadline = "2026-09-01"
        vm.currentSpeedFactor = 1.2
        await vm.confirmIngestion(confirmed: true)
        XCTAssertEqual(mock.lastConfirmIngestionDeadline, "2026-09-01")
        XCTAssertEqual(mock.lastConfirmIngestionSpeedFactor ?? 0, 1.2, accuracy: 0.001)
        XCTAssertEqual(mock.lastConfirmIngestionOption, "A")
        XCTAssertNil(vm.ingestionDraft)
        XCTAssertNil(vm.ingestionThreadId)
    }

    // MARK: 3.1 startIngestion offline sets isOffline

    func testStartIngestionOfflineSetsIsOffline() async {
        let mock = MockAssistantAPIClient()
        mock.shouldThrowOffline = true
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.startIngestion(url: "https://bad.example.com", deadline: Date(), speedFactor: 1.0)
        XCTAssertTrue(vm.isOffline)
        XCTAssertEqual(vm.ingestionError, "无法连接学习助手后端，请确认服务已启动（localhost:8765）")
        XCTAssertNil(vm.ingestionDraft)
    }

    // MARK: Capacity refresh + reschedule after preferences change

    func testFetchDailyCapacityUsesAPI() async {
        let mock = MockAssistantAPIClient()
        mock.learningPreferencesResult = LearningPreferences(dailyCapacityMin: 120)
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchDailyCapacity()
        XCTAssertEqual(vm.dailyCapacityMin, 120)
    }

    func testRefreshDailyCapacityAndRescheduleWhenDraftPresent() async {
        let mock = MockAssistantAPIClient()
        mock.learningPreferencesResult = LearningPreferences(dailyCapacityMin: 90)
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.ingestionDraft = sampleDraftDetail()
        vm.ingestionThreadId = "tid"
        vm.currentDeadline = "2026-08-01"
        vm.currentSpeedFactor = 1.2
        await vm.refreshDailyCapacityAndRescheduleIfDraftActive()
        XCTAssertEqual(vm.dailyCapacityMin, 90)
        XCTAssertEqual(mock.lastRescheduleDeadline, "2026-08-01")
        XCTAssertEqual(mock.lastRescheduleSpeedFactor ?? 0, 1.2, accuracy: 0.001)
    }

    func testSSEErrorSetsIngestionError() async {
        let mock = MockAssistantAPIClient()
        mock.startIngestionThreadId = "err-thread"
        mock.progressEvents = [
            IngestionProgressEvent(phase: "error", label: "链接格式无效", done: true, draft: nil, error: "fetch_failed"),
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.startIngestion(url: "http://bad", deadline: Date().addingTimeInterval(86400 * 30), speedFactor: 1.0)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(vm.ingestionError, "链接格式无效")
        XCTAssertFalse(vm.isIngesting)
    }
}

// MARK: - Learning Preferences Tests (Task 4.1 / 4.2)

final class LearningPreferencesDecodingTests: XCTestCase {

    // RED: LearningPreferences model decodes daily_capacity_min from JSON
    func testLearningPreferencesDecodesFromJSON() throws {
        let json = "{\"daily_capacity_min\": 90}"
        let prefs = try JSONDecoder().decode(LearningPreferences.self, from: Data(json.utf8))
        XCTAssertEqual(prefs.dailyCapacityMin, 90)
    }

    // RED: LearningPreferences encodes back to snake_case JSON
    func testLearningPreferencesEncodesToSnakeCaseJSON() throws {
        let prefs = LearningPreferences(dailyCapacityMin: 45)
        let data = try JSONEncoder().encode(prefs)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Int]
        XCTAssertEqual(dict?["daily_capacity_min"], 45)
        XCTAssertNil(dict?["dailyCapacityMin"])
    }
}

@MainActor
final class LearningPreferencesAPITests: XCTestCase {

    // RED: MockAssistantAPIClient.getLearningPreferences returns stub value
    func testMockGetLearningPreferencesReturnsStubbedCapacity() async throws {
        let mock = MockAssistantAPIClient()
        let prefs = try await mock.getLearningPreferences()
        XCTAssertEqual(prefs.dailyCapacityMin, 60)
    }

    // RED: MockAssistantAPIClient.updateLearningPreferences does not throw
    func testMockUpdateLearningPreferencesDoesNotThrow() async {
        let mock = MockAssistantAPIClient()
        let prefs = LearningPreferences(dailyCapacityMin: 30)
        await XCTAssertNoThrowAsync { try await mock.updateLearningPreferences(prefs) }
    }
}

// MARK: - LearningPreferencesView Source Tests (Task 4.2)

final class LearningPreferencesViewSourceTests: XCTestCase {

    // RED: LearningPreferencesView.swift exists and contains expected UI elements
    func testLearningPreferencesViewFileExists() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/LearningPreferencesView.swift")
        XCTAssertTrue(source.contains("LearningPreferencesView"))
        XCTAssertTrue(source.contains("dailyCapacityMin"))
        XCTAssertTrue(source.contains("每日学习容量"))
        XCTAssertTrue(source.contains("Stepper"))
        XCTAssertTrue(source.contains("getLearningPreferences"))
        XCTAssertTrue(source.contains("updateLearningPreferences"))
    }

    // RED: AssistantPanelView wires LearningPreferencesView for .settings tab
    func testAssistantPanelViewWiresLearningPreferencesViewForSettingsTab() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        XCTAssertTrue(source.contains("LearningPreferencesView"))
        XCTAssertFalse(source.contains("Text(\"学习偏好\")"))
    }

    // RED: AssistantPanelView bottom nav includes settings tab
    func testAssistantPanelViewBottomNavIncludesSettingsTab() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        XCTAssertTrue(source.contains("bottomNavigationButton(.settings)"))
    }

    private func sourceFile(_ relativePath: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let url = projectRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}

// MARK: - XCTest async helper

func XCTAssertNoThrowAsync(_ expression: () async throws -> Void, file: StaticString = #file, line: UInt = #line) async {
    do {
        try await expression()
    } catch {
        XCTFail("Unexpected error thrown: \(error)", file: file, line: line)
    }
}
