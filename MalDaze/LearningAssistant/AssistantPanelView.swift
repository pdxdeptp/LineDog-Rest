import SwiftUI

/// 学习助手中间栏：后端就绪后默认显示首页 dashboard，底部固定导航进入工具页。
struct AssistantPanelView: View {
    @StateObject private var vm: LearningAssistantViewModel

    @MainActor
    init(viewModel: LearningAssistantViewModel = LearningAssistantViewModel()) {
        _vm = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader

            Divider()

            switch vm.dashboardState.kind {
            case .connecting:
                connectingPlaceholder
            case .offline:
                offlinePlaceholder
            default:
                readyPanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("学习助手")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            if vm.isFetchingBriefing {
                ProgressView()
                    .controlSize(.small)
            }
            Button {
                Task { await vm.fetchDashboard() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("刷新首页")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Connecting

    private var connectingPlaceholder: some View {
        VStack(spacing: 10) {
            Spacer()
            ProgressView()
                .controlSize(.small)
            Text("后端启动中…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Offline

    private var offlinePlaceholder: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("助手离线")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("后端（localhost:8765）无法连接。\n请确认助手服务已启动。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button("重试") {
                Task { await vm.fetchDashboard() }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Ready Panel

    private var readyPanel: some View {
        VStack(spacing: 0) {
            activePanelContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            bottomNavigationBar
        }
    }

    @ViewBuilder
    private var activePanelContent: some View {
        switch vm.selectedPanelTab {
        case .home:
            homeDashboard
        case .addResource:
            IngestionView(vm: vm)
        case .resourceProgress:
            resourcesPanel
        case .adjustPlan:
            ChatView(vm: vm)
        case .settings:
            LearningPreferencesView(api: vm.api)
        }
    }

    // MARK: - Dashboard

    private var homeDashboard: some View {
        List {
            dashboardSummarySection

            switch vm.dashboardState.kind {
            case .emptyDatabase:
                emptyDatabaseSection
            case .noTasksWithResources:
                noTasksWithResourcesSection
            case .allTasksCompleted:
                allTasksCompletedSection
            case .tasksToday:
                todayTasksSection
            default:
                EmptyView()
            }
        }
        .listStyle(.plain)
        .refreshable { await vm.fetchDashboard() }
    }

    private var dashboardSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日摘要")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                summaryMetric(value: "\(vm.dashboardState.taskCount)", label: "任务")
                summaryMetric(value: "\(vm.dashboardState.totalMinutes)", label: "分钟")
                summaryMetric(value: "\(vm.dashboardState.resourceCount)", label: "资料")
            }

            if !vm.dashboardState.highlights.isEmpty {
                Text(vm.dashboardState.highlights)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if vm.dashboardState.hasDeadlineRisk {
                HStack(spacing: 8) {
                    Label("资料存在截止风险", systemImage: "exclamationmark.triangle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Spacer(minLength: 8)
                    Button("查看详情") {
                        vm.selectedPanelTab = .resourceProgress
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func summaryMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyDatabaseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("尚未添加学习资料")
                .font(.headline)
            Text("添加第一份资料后，助手会生成可执行的学习安排。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                vm.selectedPanelTab = .addResource
            } label: {
                Label("添加第一份资料", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 12)
    }

    private var noTasksWithResourcesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今天没有安排学习任务")
                .font(.headline)
            Text("资料已经在库中，可以查看资料进度或进入调整计划。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
    }

    private var allTasksCompletedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日已完成")
                .font(.headline)
            Text("今天的任务都完成了，底部导航仍可进入资料进度、添加资料或调整计划。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
    }

    private var todayTasksSection: some View {
        Section {
            ForEach(vm.visibleTodayTasks) { task in
                TaskRowView(
                    task: task,
                    isExpanded: vm.isTaskExpanded(task),
                    learningLink: vm.learningLink(for: task),
                    onToggleExpansion: {
                        vm.toggleTaskExpansion(task)
                    },
                    onComplete: {
                        await vm.completeTask(task)
                    }
                )
            }
            .onMove { source, destination in
                vm.moveVisibleTasks(fromOffsets: source, toOffset: destination)
            }
        } header: {
            Text("今日任务")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Resources

    private var resourcesPanel: some View {
        List {
            if vm.resources.isEmpty {
                Text("暂无资料记录")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(vm.resources) { resource in
                    ResourceProgressView(resource: resource)
                }
            }
        }
        .listStyle(.plain)
        .task { await vm.fetchResources() }
    }

    // MARK: - Bottom Navigation

    private var bottomNavigationBar: some View {
        HStack(spacing: 0) {
            bottomNavigationButton(.home)
            bottomNavigationButton(.addResource)
            bottomNavigationButton(.resourceProgress)
            bottomNavigationButton(.adjustPlan)
            bottomNavigationButton(.settings)
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func bottomNavigationButton(_ tab: AssistantPanelTab) -> some View {
        Button {
            vm.selectedPanelTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 15, weight: .semibold))
                Text(tab.shortLabel)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(vm.selectedPanelTab == tab ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .help(tab.shortLabel)
    }
}

#if DEBUG
private enum AssistantPanelPreviewFixtures {
    @MainActor
    static func emptyDatabaseViewModel() -> LearningAssistantViewModel {
        fixtureViewModel(tasks: [], resources: [], totalMinutes: 0, highlights: "")
    }

    @MainActor
    static func backendStartingViewModel() -> LearningAssistantViewModel {
        let vm = fixtureViewModel(tasks: [], resources: [], totalMinutes: 0, highlights: "")
        vm.isConnecting = true
        return vm
    }

    @MainActor
    static func wholeColumnOfflineViewModel() -> LearningAssistantViewModel {
        let vm = fixtureViewModel(tasks: [linkedTask], resources: [activeResource], totalMinutes: 25, highlights: "今日负荷正常")
        vm.isOffline = true
        return vm
    }

    @MainActor
    static func tasksTodayViewModel() -> LearningAssistantViewModel {
        fixtureViewModel(tasks: [linkedTask, plainTask], resources: [activeResource], totalMinutes: 45, highlights: "今天适合先完成高优先级任务。")
    }

    @MainActor
    static func taskExpandedWithLinkViewModel() -> LearningAssistantViewModel {
        let vm = fixtureViewModel(tasks: [linkedTask], resources: [activeResource], totalMinutes: 25, highlights: "展开后可打开学习链接。")
        vm.toggleTaskExpansion(linkedTask)
        return vm
    }

    @MainActor
    static func taskExpandedWithoutLinkViewModel() -> LearningAssistantViewModel {
        let vm = fixtureViewModel(tasks: [plainTask], resources: [activeResource], totalMinutes: 20, highlights: "展开后显示链接不可用。")
        vm.toggleTaskExpansion(plainTask)
        return vm
    }

    @MainActor
    static func resourcesWithoutTodayTasksViewModel() -> LearningAssistantViewModel {
        fixtureViewModel(tasks: [], resources: [activeResource], totalMinutes: 0, highlights: "")
    }

    @MainActor
    static func deadlineRiskViewModel() -> LearningAssistantViewModel {
        fixtureViewModel(tasks: [linkedTask], resources: [deadlineRiskResource], totalMinutes: 25, highlights: "截止日期临近，请查看资料进度。")
    }

    @MainActor
    private static func fixtureViewModel(
        tasks: [AssistantTask],
        resources: [AssistantResource],
        totalMinutes: Int,
        highlights: String
    ) -> LearningAssistantViewModel {
        let vm = LearningAssistantViewModel(
            api: AssistantPanelFixtureAPIClient(briefing: TodayBriefing(tasks: tasks, totalMinutes: totalMinutes, highlights: highlights),
                                                resources: resources),
            orderStore: UserDefaults(suiteName: "AssistantPanelPreviewFixtures.\(UUID().uuidString)") ?? .standard,
            autoLoadWhenReady: false
        )
        vm.isConnecting = false
        vm.isOffline = false
        vm.tasks = tasks
        vm.visibleTodayTasks = tasks
        vm.resources = resources
        vm.todayTotalMinutes = totalMinutes
        vm.todayHighlights = highlights
        return vm
    }

    private static let linkedTask = AssistantTask(
        id: 1,
        title: "01 相向双指针",
        targetMinutes: 25,
        completedAt: nil,
        resourceTitle: "基础算法精讲",
        priority: 1,
        resourceURL: URL(string: "https://example.com/course"),
        unitURL: URL(string: "https://example.com/unit")
    )

    private static let plainTask = AssistantTask(
        id: 2,
        title: "整理今日学习笔记",
        targetMinutes: 20,
        completedAt: nil,
        resourceTitle: "复盘资料",
        priority: 2
    )

    private static let activeResource = AssistantResource(
        id: 10,
        title: "基础算法精讲",
        trackingMode: "video",
        completedUnits: 3,
        totalUnits: 12,
        actualMinutesTotal: 90,
        deadline: nil,
        status: "active"
    )

    private static let deadlineRiskResource = AssistantResource(
        id: 11,
        title: "系统设计冲刺",
        trackingMode: "article",
        completedUnits: 2,
        totalUnits: 10,
        actualMinutesTotal: 60,
        deadline: "2026-05-11",
        status: "deadline_risk"
    )
}

private struct AssistantPanelFixtureAPIClient: AssistantAPIClientProtocol {
    let briefing: TodayBriefing
    let resources: [AssistantResource]

    func fetchTodayBriefing() async throws -> TodayBriefing { briefing }
    func completeTask(id: Int, actualMinutes: Int?) async throws {}
    func sendMessage(message: String, threadId: String?) async throws -> ChatResponse {
        ChatResponse(threadId: threadId ?? "preview-thread", response: "预览回复", proposal: nil)
    }
    func confirmChat(threadId: String, confirmed: Bool) async throws {}

    func startIngestion(url: String, deadline: String, speedFactor: Double?) async throws -> String {
        "preview-ingestion"
    }
    func subscribeIngestionProgress(threadId: String) -> AsyncThrowingStream<IngestionProgressEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(IngestionProgressEvent(
                phase: "draft_ready",
                label: "草稿已就绪",
                done: true,
                draft: IngestionDraftDetail(
                    resourceTitle: "预览资料",
                    resourceType: "web_article",
                    totalEstimatedHours: 1,
                    unitCount: 1,
                    optionA: [],
                    optionB: []
                ),
                error: nil
            ))
            continuation.finish()
        }
    }
    func rescheduleIngestion(threadId: String, deadline: String, speedFactor: Double) async throws -> IngestionDraftDetail {
        IngestionDraftDetail(resourceTitle: "预览资料", resourceType: "web_article",
                             totalEstimatedHours: 1, unitCount: 1, optionA: [], optionB: [])
    }
    func confirmIngestion(threadId: String, confirmed: Bool, selectedOption: String?, deadline: String?, speedFactor: Double?) async throws {}
    func fetchResources() async throws -> [AssistantResource] { resources }
    func getLearningPreferences() async throws -> LearningPreferences {
        LearningPreferences(dailyCapacityMin: 60)
    }
    func updateLearningPreferences(_ prefs: LearningPreferences) async throws {}
}

private struct AssistantPanelView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        Group {
            AssistantPanelView(viewModel: AssistantPanelPreviewFixtures.emptyDatabaseViewModel())
                .previewDisplayName("Empty database")
            AssistantPanelView(viewModel: AssistantPanelPreviewFixtures.backendStartingViewModel())
                .previewDisplayName("Backend starting")
            AssistantPanelView(viewModel: AssistantPanelPreviewFixtures.wholeColumnOfflineViewModel())
                .previewDisplayName("Whole-column offline")
            AssistantPanelView(viewModel: AssistantPanelPreviewFixtures.tasksTodayViewModel())
                .previewDisplayName("Tasks today")
            AssistantPanelView(viewModel: AssistantPanelPreviewFixtures.taskExpandedWithLinkViewModel())
                .previewDisplayName("Task expanded with link")
            AssistantPanelView(viewModel: AssistantPanelPreviewFixtures.taskExpandedWithoutLinkViewModel())
                .previewDisplayName("Task without link")
            AssistantPanelView(viewModel: AssistantPanelPreviewFixtures.resourcesWithoutTodayTasksViewModel())
                .previewDisplayName("Resources without today tasks")
            AssistantPanelView(viewModel: AssistantPanelPreviewFixtures.deadlineRiskViewModel())
                .previewDisplayName("Deadline risk")
        }
        .frame(width: 520, height: 640)
    }
}
#endif

private extension AssistantPanelTab {
    var shortLabel: String {
        switch self {
        case .home: return "首页"
        case .addResource: return "添加资料"
        case .resourceProgress: return "资料进度"
        case .adjustPlan: return "调整计划"
        case .settings: return "设置"
        }
    }

    var iconName: String {
        switch self {
        case .home: return "house"
        case .addResource: return "plus.circle"
        case .resourceProgress: return "chart.bar"
        case .adjustPlan: return "slider.horizontal.3"
        case .settings: return "gearshape"
        }
    }
}
