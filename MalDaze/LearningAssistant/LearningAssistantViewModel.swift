import Combine
import Foundation

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
}

// MARK: - Dashboard State

enum AssistantPanelTab: Equatable {
    case home
    case projectOverview
    case calendar
    case addResource
    case resourceProgress
    case adjustPlan
    case settings
}

enum AssistantDashboardKind: Equatable {
    case connecting
    case offline
    case emptyDatabase
    case noTasksWithResources
    case tasksToday
    case allTasksCompleted
}

enum AssistantDashboardPrimaryAction: Equatable {
    case addResource
}

struct AssistantDashboardState: Equatable {
    let kind: AssistantDashboardKind
    let totalMinutes: Int
    let taskCount: Int
    let completedTaskCount: Int
    let highlights: String
    let resourceCount: Int
    let hasDeadlineRisk: Bool
    let primaryAction: AssistantDashboardPrimaryAction?
    let primaryTaskID: Int?
}

enum TaskLearningLink: Equatable {
    case available(URL)
    case unavailable
}

// MARK: - ViewModel

/// 学习助手中栏数据层；ObservableObject 供 SwiftUI 视图订阅，兼容 macOS 13+。
@MainActor
final class LearningAssistantViewModel: ObservableObject {
    // MARK: State

    @Published var tasks: [AssistantTask]         = []
    @Published var visibleTodayTasks: [AssistantTask] = []
    @Published var resources: [AssistantResource] = []
    @Published var chatMessages: [ChatMessage]    = []
    @Published var currentProposal: String?       = nil
    @Published var isOffline: Bool                = false
    @Published var threadId: String?              = nil
    @Published var selectedPanelTab: AssistantPanelTab = .home
    @Published private var expandedTaskIDs: Set<Int> = []
    @Published var resourceManagementError: String? = nil
    @Published private(set) var managingResourceIDs: Set<Int> = []
    @Published var adjustPlanDraftText: String? = nil

    @Published var ingestionDraft: IngestionDraftDetail? = nil
    @Published var ingestionThreadId: String?            = nil
    @Published var selectedOption: String                = "B"

    @Published var studyPlanDraftId: Int? = nil
    @Published var studyPlanClarification: StudyPlanClarification? = nil
    @Published var studyPlanDraft: StudyPlanDraft? = nil
    @Published var studyPlanError: String? = nil

    @Published var todayTotalMinutes: Int  = 0
    @Published var todayHighlights: String = ""
    @Published private(set) var hasLoadedDashboardContent = false
    @Published var studyTodayView: StudyTodayView? = nil
    @Published var studyProjectOverview: StudyProjectOverview? = nil
    @Published var studyCalendarLoad: StudyCalendarLoad? = nil
    @Published var studyViewError: String? = nil
    @Published var studyCalendarLoadError: String? = nil
    @Published var studyRestDaySettings: StudyRestDaySettings? = nil
    @Published var isStudySmartModeEnabled: Bool = false
    @Published var studySmartMorningBriefing: StudySmartMorningBriefing? = nil
    @Published var studySmartProposalOptions: [StudySmartProposalOption] = []
    @Published var studySmartProposalMessage: String? = nil
    @Published var studyDialogueAdjustmentPreview: StudyDialogueAdjustmentPreview? = nil
    @Published var studyDialogueAdjustmentResult: StudyDialogueAdjustmentApplyResult? = nil
    @Published var studyPlanAdjustmentError: String? = nil

    @Published var isFetchingBriefing = false
    @Published var isFetchingStudyCalendarLoad = false
    @Published var isAdjustingStudyPlan = false
    @Published var isApplyingStudySmartProposal = false
    @Published var isSendingMessage   = false
    @Published var isIngesting        = false
    @Published var isStartingStudyPlan = false
    @Published var isSubmittingStudyPlanClarification = false
    @Published var isUpdatingStudyPlanDraft = false
    @Published var isConfirmingStudyPlanDraft = false
    private var isCancellingStudyPlanDraft = false
    private var isStudyPlanDraftFlowBusy: Bool {
        isStartingStudyPlan ||
        isSubmittingStudyPlanClarification ||
        isUpdatingStudyPlanDraft ||
        isCancellingStudyPlanDraft ||
        isConfirmingStudyPlanDraft
    }
    /// 后端进程启动中（还未收到就绪通知）；区别于运行期离线。
    @Published var isConnecting: Bool = true

    // Ingestion phase tracking (SSE)
    @Published var ingestionPhase: String? = nil
    @Published var ingestionError: String? = nil

    // Reschedule tracking
    @Published var currentDeadline: String? = nil
    @Published var currentSpeedFactor: Double = 1.0
    @Published var isRescheduling: Bool = false
    @Published var rescheduleError: Bool = false
    @Published var dailyCapacityMin: Int = 60

    // Internal sync state (not private so tests can verify/set)
    var lastSyncedDeadline: String? = nil
    var lastSyncedSpeedFactor: Double? = nil

    // MARK: - Computed

    var canConfirm: Bool {
        guard let last = lastSyncedDeadline, let lastSpeed = lastSyncedSpeedFactor else {
            // Never rescheduled — use initial draft, always allow confirm
            return ingestionDraft != nil && !isRescheduling
        }
        return last == currentDeadline && lastSpeed == currentSpeedFactor && !isRescheduling
    }

    // MARK: - Private

    let api: any AssistantAPIClientProtocol
    private let orderStore: UserDefaults
    private let todayProvider: () -> Date
    private let backendLifecycle: AppBackendLifecycleManaging
    private var readyObserver: Any?
    private var analysisTask: Task<Void, Never>?
    private var rescheduleDebounceTask: Task<Void, Never>?
    private var dashboardRefreshTail: Task<Void, Never>?
    private var dashboardRefreshSequence = 0
    private var studyCalendarLoadRequestSequence = 0
    private var studySmartProposalContexts: [String: StudySmartRedState] = [:]

    // MARK: - Init

    init(
        api: any AssistantAPIClientProtocol = AssistantAPIClient.shared,
        orderStore: UserDefaults = .standard,
        todayProvider: @escaping () -> Date = Date.init,
        backendLifecycle: AppBackendLifecycleManaging = BackendProcessManager.shared,
        autoLoadWhenReady: Bool = true
    ) {
        self.api = api
        self.orderStore = orderStore
        self.todayProvider = todayProvider
        self.backendLifecycle = backendLifecycle
        readyObserver = NotificationCenter.default.addObserver(
            forName: .backendDidBecomeReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isConnecting else { return }
                self.isConnecting = false
                await self.fetchDashboard()
            }
        }

        // 若通知在订阅前已发出（后端早于视图初始化就绪），直接开始 fetch。
        if autoLoadWhenReady, backendLifecycle.isReady {
            isConnecting = false
            Task { await fetchDashboard() }
        }
    }

    deinit {
        if let readyObserver { NotificationCenter.default.removeObserver(readyObserver) }
    }

    // MARK: - Briefing

    var dashboardState: AssistantDashboardState {
        let kind: AssistantDashboardKind
        let primaryAction: AssistantDashboardPrimaryAction?

        if isOffline {
            kind = .offline
            primaryAction = nil
        } else if isConnecting, !hasLoadedDashboardContent {
            kind = .connecting
            primaryAction = nil
        } else if tasks.isEmpty, resources.isEmpty {
            kind = .emptyDatabase
            primaryAction = .addResource
        } else if tasks.isEmpty {
            kind = .noTasksWithResources
            primaryAction = nil
        } else if tasks.allSatisfy(\.isCompleted) {
            kind = .allTasksCompleted
            primaryAction = nil
        } else {
            kind = .tasksToday
            primaryAction = nil
        }

        return AssistantDashboardState(
            kind: kind,
            totalMinutes: todayTotalMinutes,
            taskCount: tasks.count,
            completedTaskCount: tasks.filter(\.isCompleted).count,
            highlights: todayHighlights,
            resourceCount: resources.count,
            hasDeadlineRisk: hasDeadlineRisk,
            primaryAction: primaryAction,
            primaryTaskID: nil
        )
    }

    func fetchDashboard() async {
        await enqueueDashboardRefresh()
    }

    private func enqueueDashboardRefresh(resourceRefreshFailureMessage: String? = nil) async {
        dashboardRefreshSequence += 1
        let sequence = dashboardRefreshSequence
        let predecessor = dashboardRefreshTail
        let task = Task { @MainActor [weak self] in
            await predecessor?.value
            guard let self else { return }
            await self.performDashboardRefresh(resourceRefreshFailureMessage: resourceRefreshFailureMessage)
            if self.dashboardRefreshSequence == sequence {
                self.dashboardRefreshTail = nil
            }
        }
        dashboardRefreshTail = task
        await task.value
    }

    private func performDashboardRefresh(resourceRefreshFailureMessage: String? = nil) async {
        isFetchingBriefing = true
        defer { isFetchingBriefing = false }
        do {
            try await refreshDashboardFacts(resourceRefreshFailureMessage: resourceRefreshFailureMessage)
            await refreshStudySmartModeForDashboard()
        } catch {
            if let resourceRefreshFailureMessage {
                resourceManagementError = resourceRefreshFailureMessage
            }
            studyViewError = "学习视图刷新失败，请稍后重试。"
            isOffline = true
            isConnecting = false
        }
    }

    private func refreshDashboardFacts(resourceRefreshFailureMessage: String? = nil) async throws {
        async let todayViewRequest = api.fetchStudyTodayView()
        async let projectOverviewRequest = api.fetchStudyProjectOverview()
        async let resourcesRequest = api.fetchResources()
        let (todayView, projectOverview, fetchedResources) = try await (
            todayViewRequest,
            projectOverviewRequest,
            resourcesRequest
        )
        apply(
            studyTodayView: todayView,
            projectOverview: projectOverview,
            resources: fetchedResources
        )
        if resourceRefreshFailureMessage != nil {
            resourceManagementError = nil
        }
        studyViewError = nil
        isOffline = false
        isConnecting = false
    }

    private func refreshDashboardFactsOnly() async -> Bool {
        do {
            try await refreshDashboardFacts()
            return true
        } catch {
            studyViewError = "学习视图刷新失败，请稍后重试。"
            isOffline = true
            isConnecting = false
            return false
        }
    }

    func refreshForDashboardOpen() async {
        guard backendLifecycle.isReady else {
            isConnecting = true
            if !backendLifecycle.isStarting {
                backendLifecycle.startIfNeeded()
            }
            return
        }
        await fetchDashboard()
    }

    private func refreshStudySmartModeForDashboard() async {
        do {
            let settings = try await api.fetchStudySmartModeSettings()
            isStudySmartModeEnabled = settings.enabled
            guard settings.enabled else {
                clearStudySmartModeState()
                return
            }
            let briefing = try await api.fetchStudySmartMorningBriefing()
            isStudySmartModeEnabled = briefing.enabled
            guard briefing.enabled else {
                clearStudySmartModeState()
                return
            }
            studySmartMorningBriefing = briefing
            studySmartProposalOptions = briefing.options
            studySmartProposalContexts = [:]
            studySmartProposalMessage = nil
        } catch {
            clearStudySmartModeState()
        }
    }

    private func refreshStudySmartModeSetting() async -> Bool {
        do {
            let settings = try await api.fetchStudySmartModeSettings()
            isStudySmartModeEnabled = settings.enabled
            if !settings.enabled {
                clearStudySmartModeState()
            }
            return settings.enabled
        } catch {
            clearStudySmartModeState()
            return isStudySmartModeEnabled
        }
    }

    func ignoreStudySmartProposals() {
        studySmartProposalOptions = []
        studySmartProposalContexts = [:]
        studySmartProposalMessage = nil
    }

    func applyStudySmartProposal(_ option: StudySmartProposalOption) async {
        guard !isApplyingStudySmartProposal else { return }
        guard studySmartProposalOptions.contains(where: { $0.id == option.id }) else {
            studySmartProposalMessage = "智能建议已过期，请刷新后重试。"
            return
        }
        isApplyingStudySmartProposal = true
        studySmartProposalMessage = nil
        defer { isApplyingStudySmartProposal = false }

        do {
            let context = studySmartProposalContexts[option.id]
            let result = try await api.applyStudySmartProposal(
                StudySmartProposalApplyRequest(
                    proposal: option,
                    previousExpectedLateProjectIds: context?.expectedLateProjectIds,
                    previousOverCapacityDates: context?.overCapacityDates
                )
            )
            isOffline = false
            guard result.status == "applied", result.mutates else {
                studySmartProposalOptions = []
                studySmartProposalContexts = [:]
                if result.status == "disabled" {
                    isStudySmartModeEnabled = false
                }
                studySmartProposalMessage = result.message ?? studySmartProposalStatusMessage(for: result.status)
                return
            }

            studySmartProposalOptions = []
            studySmartProposalContexts = [:]
            studySmartMorningBriefing = nil
            studySmartProposalMessage = result.message ?? "智能建议已应用。"
            if result.refresh?.today == true || result.refresh?.projectOverview == true {
                guard await refreshDashboardFactsOnly() else { return }
            }
            if result.refresh?.calendar == true {
                await refreshCalendarLoadIfNeeded()
            }
            studySmartProposalOptions = []
            studySmartProposalContexts = [:]
        } catch {
            studySmartProposalMessage = "智能建议应用失败，请稍后重试。"
            isOffline = true
        }
    }

    func fetchTodayBriefing() async {
        isFetchingBriefing = true
        defer { isFetchingBriefing = false }
        do {
            let briefing      = try await api.fetchTodayBriefing()
            let orderedTasks   = applyLocalDisplayOrder(to: briefing.tasks)
            tasks             = orderedTasks
            visibleTodayTasks = orderedTasks
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
            resourceManagementError = nil
            isOffline = false
        } catch {
            isOffline = true
        }
    }

    // MARK: - Task Completion

    func completeTask(_ task: AssistantTask) async {
        do {
            _ = try await api.completeTask(id: task.id, actualMinutes: nil)
            await fetchDashboard()
            await refreshCalendarLoadIfNeeded()
        } catch {
            isOffline = true
        }
    }

    // MARK: - Study Plan Adjustment

    func rolloverStudyTasks() async {
        await performStudyPlanAdjustment {
            _ = try await api.rolloverStudyTasks()
        }
    }

    func moveStudyTask(id: Int, scheduledDate: String) async {
        await performStudyPlanAdjustment {
            _ = try await api.moveStudyTask(id: id, scheduledDate: scheduledDate)
        }
    }

    func updateStudyProjectDeadline(projectId: Int, deadline: String) async {
        await performStudyPlanAdjustment {
            _ = try await api.updateStudyProjectDeadline(projectId: projectId, deadline: deadline)
        }
    }

    func insertStudyProjectTask(
        projectId: Int,
        title: String,
        targetMinutes: Int,
        scheduledDate: String
    ) async {
        await performStudyPlanAdjustment {
            _ = try await api.insertStudyProjectTask(
                projectId: projectId,
                title: title,
                targetMinutes: targetMinutes,
                scheduledDate: scheduledDate
            )
        }
    }

    func deleteStudyTask(id: Int) async {
        await performStudyPlanAdjustment {
            _ = try await api.deleteStudyTask(id: id)
        }
    }

    func fetchStudyRestDaySettings() async {
        guard !isAdjustingStudyPlan else { return }
        isAdjustingStudyPlan = true
        studyPlanAdjustmentError = nil
        defer { isAdjustingStudyPlan = false }

        do {
            studyRestDaySettings = try await api.fetchStudyRestDaySettings()
            isOffline = false
        } catch {
            studyPlanAdjustmentError = "休息日设置加载失败，请稍后重试。"
            isOffline = true
        }
    }

    func updateStudyRestDaySettings(_ settings: StudyRestDaySettings) async {
        await performStudyPlanAdjustment {
            let result = try await api.updateStudyRestDaySettings(settings)
            studyRestDaySettings = StudyRestDaySettings(
                weeklyWeekdays: result.weeklyWeekdays,
                oneOffDates: result.oneOffDates
            )
        }
    }

    func previewStudyDialogueAdjustment(instruction: String, projectId: Int?) async {
        guard !isAdjustingStudyPlan else { return }
        isAdjustingStudyPlan = true
        studyPlanAdjustmentError = nil
        defer { isAdjustingStudyPlan = false }

        do {
            let preview = try await api.previewStudyDialogueAdjustment(
                instruction: instruction,
                projectId: projectId
            )
            studyDialogueAdjustmentPreview = preview
            studyDialogueAdjustmentResult = nil
            isOffline = false
        } catch {
            studyPlanAdjustmentError = "调整预览生成失败，请稍后重试。"
            isOffline = true
        }
    }

    func applyStudyDialogueAdjustment(instruction: String, projectId: Int?) async {
        guard let preview = studyDialogueAdjustmentPreview else {
            studyPlanAdjustmentError = "请先生成调整预览。"
            return
        }
        guard !isAdjustingStudyPlan else { return }
        isAdjustingStudyPlan = true
        studyPlanAdjustmentError = nil
        defer { isAdjustingStudyPlan = false }
        let previousRedState = currentStudySmartRedState()
        let smartModeEnabled = await refreshStudySmartModeSetting()

        do {
            let result = try await api.applyStudyDialogueAdjustment(
                instruction: instruction,
                projectId: projectId,
                preview: preview
            )
            studyDialogueAdjustmentResult = result
            studyDialogueAdjustmentPreview = nil
            isOffline = false
            await refreshAfterStudyPlanAdjustment(
                previousRedState: previousRedState,
                smartModeEnabled: smartModeEnabled
            )
        } catch {
            studyPlanAdjustmentError = "调整应用失败，请稍后重试。"
            isOffline = true
        }
    }

    func fetchStudyCalendarLoad(start: String, end: String) async {
        studyCalendarLoadRequestSequence += 1
        let requestSequence = studyCalendarLoadRequestSequence
        isFetchingStudyCalendarLoad = true
        defer {
            if studyCalendarLoadRequestSequence == requestSequence {
                isFetchingStudyCalendarLoad = false
            }
        }
        do {
            let fetchedLoad = try await api.fetchStudyCalendarLoad(start: start, end: end)
            guard studyCalendarLoadRequestSequence == requestSequence else { return }
            studyCalendarLoad = fetchedLoad
            studyCalendarLoadError = nil
            isOffline = false
        } catch {
            guard studyCalendarLoadRequestSequence == requestSequence else { return }
            studyCalendarLoadError = "日历负荷加载失败，请稍后重试。"
            isOffline = true
        }
    }

    // MARK: - Resource Management

    func completeResource(_ resource: AssistantResource) async {
        await manageResource(
            resource,
            failureMessage: "标记「\(resource.title)」完成失败，请重试。"
        ) {
            try await api.completeResource(id: resource.id)
        }
    }

    func archiveResource(_ resource: AssistantResource) async {
        await manageResource(
            resource,
            failureMessage: "移出「\(resource.title)」失败，请重试。"
        ) {
            try await api.archiveResource(id: resource.id)
        }
    }

    func isManagingResource(_ resource: AssistantResource) -> Bool {
        !managingResourceIDs.isEmpty
    }

    func clearResourceManagementError() {
        resourceManagementError = nil
    }

    func seedAdjustPlan(for resource: AssistantResource) {
        adjustPlanDraftText = "请帮我调整「\(resource.title)」（ID: \(resource.id)）的学习计划："
        selectedPanelTab = .adjustPlan
    }

    func consumeAdjustPlanDraftText() -> String? {
        guard let draft = adjustPlanDraftText else { return nil }
        adjustPlanDraftText = nil
        return draft
    }

    // MARK: - Dashboard interactions

    func moveVisibleTasks(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard !source.isEmpty else { return }
        var reordered = visibleTodayTasks
        let moving = source.sorted().compactMap { index in
            reordered.indices.contains(index) ? reordered[index] : nil
        }
        for index in source.sorted(by: >) where reordered.indices.contains(index) {
            reordered.remove(at: index)
        }
        let removedBeforeDestination = source.filter { $0 < destination }.count
        let insertionIndex = min(max(destination - removedBeforeDestination, 0), reordered.count)
        reordered.insert(contentsOf: moving, at: insertionIndex)
        tasks = reordered
        visibleTodayTasks = reordered
        saveDisplayOrder(reordered.map(\.id))
    }

    func toggleTaskExpansion(_ task: AssistantTask) {
        if expandedTaskIDs.contains(task.id) {
            expandedTaskIDs.remove(task.id)
        } else {
            expandedTaskIDs.insert(task.id)
        }
    }

    func isTaskExpanded(_ task: AssistantTask) -> Bool {
        expandedTaskIDs.contains(task.id)
    }

    func learningLink(for task: AssistantTask) -> TaskLearningLink {
        if let unitURL = task.unitURL { return .available(unitURL) }
        if let resourceURL = task.resourceURL { return .available(resourceURL) }
        return .unavailable
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
            let displayText = resp.response ?? resp.proposal?.summaryForUser ?? "收到，正在处理…"
            chatMessages.append(ChatMessage(role: .assistant, text: displayText))
            currentProposal = resp.proposal?.summaryForUser
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
        ingestionPhase = nil
        ingestionError = nil
        ingestionDraft = nil
        ingestionThreadId = nil
        rescheduleError = false

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let deadlineStr = formatter.string(from: deadline)
        currentDeadline = deadlineStr
        currentSpeedFactor = speedFactor
        lastSyncedDeadline = nil
        lastSyncedSpeedFactor = nil

        do {
            let threadId = try await api.startIngestion(url: url, deadline: deadlineStr, speedFactor: speedFactor)
            ingestionThreadId = threadId
            isOffline = false

            analysisTask = Task {
                do {
                    for try await event in api.subscribeIngestionProgress(threadId: threadId) {
                        await MainActor.run {
                            self.ingestionPhase = event.label
                        }
                        if event.done {
                            await MainActor.run {
                                if event.phase == "draft_ready", let draft = event.draft {
                                    self.ingestionDraft = draft
                                    self.isIngesting = false
                                    Task { await self.fetchDailyCapacity() }
                                } else if event.phase == "error" {
                                    self.ingestionError = event.label
                                    self.isIngesting = false
                                    self.ingestionPhase = nil
                                }
                            }
                            return
                        }
                    }
                    // Stream ended without done event
                    await MainActor.run {
                        self.ingestionError = "连接中断，请重新提交链接分析"
                        self.isIngesting = false
                        self.ingestionPhase = nil
                    }
                } catch {
                    await MainActor.run {
                        self.ingestionError = "连接中断，请重新提交链接分析"
                        self.isIngesting = false
                        self.ingestionPhase = nil
                    }
                }
            }
        } catch {
            isIngesting = false
            isOffline = true
            ingestionError = "无法连接学习助手后端，请确认服务已启动（localhost:8765）"
        }
    }

    func reschedule(deadline: String, speedFactor: Double) async {
        guard let threadId = ingestionThreadId else { return }
        isRescheduling = true
        rescheduleError = false
        defer { isRescheduling = false }
        do {
            let newDraft = try await api.rescheduleIngestion(threadId: threadId, deadline: deadline, speedFactor: speedFactor)
            ingestionDraft = newDraft
            lastSyncedDeadline = deadline
            lastSyncedSpeedFactor = speedFactor
            rescheduleError = false
            isOffline = false
        } catch is ThreadNotFoundError {
            ingestionDraft = nil
            ingestionThreadId = nil
            ingestionError = "session_expired"
        } catch {
            rescheduleError = true
        }
    }

    func debounceReschedule(deadline: String, speedFactor: Double) {
        rescheduleDebounceTask?.cancel()
        rescheduleDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await reschedule(deadline: deadline, speedFactor: speedFactor)
        }
    }

    /// HTTP confirm path (confirmed = true)
    func confirmIngestion(confirmed: Bool, option: String? = nil) async {
        guard let tid = ingestionThreadId else { return }
        do {
            if confirmed {
                try await api.confirmIngestion(
                    threadId: tid,
                    confirmed: true,
                    selectedOption: option ?? selectedOption,
                    deadline: currentDeadline,
                    speedFactor: currentSpeedFactor
                )
                ingestionDraft = nil
                ingestionThreadId = nil
                selectedOption = "B"
                await fetchDashboard()
            } else {
                // Cancel: pass to server for cleanliness (not currently needed but keep contract)
                try await api.confirmIngestion(
                    threadId: tid,
                    confirmed: false,
                    selectedOption: nil,
                    deadline: nil,
                    speedFactor: nil
                )
                ingestionDraft = nil
                ingestionThreadId = nil
                selectedOption = "B"
            }
        } catch {
            ingestionError = "写入失败，请重试"
        }
    }

    /// Pure local cancel — no HTTP call
    func confirmIngestion(cancelDraft: Bool) {
        guard cancelDraft else { return }
        analysisTask?.cancel()
        analysisTask = nil
        ingestionDraft = nil
        ingestionThreadId = nil
        ingestionPhase = nil
        ingestionError = nil
        rescheduleError = false
        selectedOption = "B"
    }

    // MARK: - Study Plan Draft Flow

    func startStudyPlan(url: String, deadline: Date, capacityMinutes: Int) async {
        guard !isStudyPlanDraftFlowBusy else { return }
        isStartingStudyPlan = true
        studyPlanError = nil
        defer { isStartingStudyPlan = false }

        do {
            let response = try await api.startStudyPlan(
                url: url,
                deadline: formatStudyPlanDeadline(deadline),
                capacityMinutes: capacityMinutes
            )
            studyPlanDraftId = response.draftId
            studyPlanClarification = response.clarification
            studyPlanDraft = nil
            isOffline = false
        } catch {
            studyPlanError = "无法启动学习计划，请重试。"
            isOffline = true
        }
    }

    func submitStudyPlanClarification(answers: [String: String], skip: Bool) async {
        guard !isStudyPlanDraftFlowBusy else { return }
        guard let draftId = studyPlanDraftId else {
            studyPlanError = "缺少学习计划草稿，请重新提交链接。"
            return
        }

        isSubmittingStudyPlanClarification = true
        studyPlanError = nil
        defer { isSubmittingStudyPlanClarification = false }

        do {
            let draft = try await api.submitStudyPlanClarification(
                draftId: draftId,
                answers: answers,
                skip: skip
            )
            guard studyPlanDraftId == draftId else { return }
            studyPlanDraft = draft
            isOffline = false
        } catch {
            studyPlanError = "生成学习计划草稿失败，请重试。"
            isOffline = true
        }
    }

    func skipStudyPlanClarification() async {
        await submitStudyPlanClarification(
            answers: studyPlanClarification?.defaults ?? [:],
            skip: true
        )
    }

    func updateStudyPlanDraftTaskDuration(orderIndex: Int, estimatedMinutes: Int) async {
        guard !isStudyPlanDraftFlowBusy else { return }
        guard let draftId = reviewReadyStudyPlanDraftId() else { return }

        isUpdatingStudyPlanDraft = true
        studyPlanError = nil
        defer { isUpdatingStudyPlanDraft = false }

        do {
            let draft = try await api.updateStudyPlanDraftTaskDuration(
                draftId: draftId,
                taskOrderIndex: orderIndex,
                estimatedMinutes: estimatedMinutes
            )
            guard studyPlanDraftId == draftId else { return }
            studyPlanDraft = draft
            isOffline = false
        } catch {
            studyPlanError = "更新任务时长失败，请重试。"
            isOffline = true
        }
    }

    func cancelStudyPlanDraft() async {
        guard !isStudyPlanDraftFlowBusy else { return }
        guard let draftId = studyPlanDraftId else {
            clearStudyPlanDraftFlow()
            return
        }

        isCancellingStudyPlanDraft = true
        studyPlanError = nil
        defer { isCancellingStudyPlanDraft = false }

        do {
            try await api.cancelStudyPlanDraft(draftId: draftId)
            guard studyPlanDraftId == draftId else { return }
            clearStudyPlanDraftFlow()
            isOffline = false
        } catch {
            studyPlanError = "取消学习计划草稿失败，请重试。"
            isOffline = true
        }
    }

    func confirmStudyPlanDraft() async {
        guard !isStudyPlanDraftFlowBusy else { return }
        guard let draftId = reviewReadyStudyPlanDraftId() else { return }

        isConfirmingStudyPlanDraft = true
        studyPlanError = nil
        defer { isConfirmingStudyPlanDraft = false }

        do {
            _ = try await api.confirmStudyPlanDraft(draftId: draftId)
            guard studyPlanDraftId == draftId else { return }
            clearStudyPlanDraftFlow()
            isOffline = false
            await fetchDashboard()
        } catch {
            studyPlanError = "确认学习计划失败，请重试。"
            isOffline = true
        }
    }

    func cancelAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
    }

    func fetchDailyCapacity() async {
        do {
            let prefs = try await api.getLearningPreferences()
            dailyCapacityMin = prefs.dailyCapacityMin
        } catch {
            // Keep previous dailyCapacityMin on failure
        }
    }

    /// 从设置返回采集页或偏好变更后：刷新每日容量并按当前草稿参数重新拉取排期。
    func refreshDailyCapacityAndRescheduleIfDraftActive() async {
        await fetchDailyCapacity()
        guard ingestionDraft != nil,
              let deadline = currentDeadline else { return }
        await reschedule(deadline: deadline, speedFactor: currentSpeedFactor)
    }

    // MARK: - Private dashboard helpers

    private var hasDeadlineRisk: Bool {
        resources.contains { resourceHasDeadlineRisk($0) }
    }

    private func apply(briefing: TodayBriefing, resources fetchedResources: [AssistantResource]) {
        let orderedTasks = applyLocalDisplayOrder(to: briefing.tasks)
        tasks = orderedTasks
        visibleTodayTasks = orderedTasks
        todayTotalMinutes = briefing.totalMinutes
        todayHighlights = briefing.highlights
        resources = fetchedResources
        hasLoadedDashboardContent = true
    }

    private func apply(
        studyTodayView todayView: StudyTodayView,
        projectOverview: StudyProjectOverview,
        resources fetchedResources: [AssistantResource]
    ) {
        let mappedTasks = todayView.tasks.enumerated().map { index, task in
            AssistantTask(
                id: task.id,
                title: task.title,
                targetMinutes: task.targetMinutes,
                completedAt: task.completedAt,
                resourceTitle: task.projectTitle ?? task.resourceTitle,
                priority: index + 1,
                resourceURL: task.resourceURL,
                unitURL: task.unitURL
            )
        }
        let orderedTasks = applyLocalDisplayOrder(to: mappedTasks)
        studyTodayView = todayView
        studyProjectOverview = projectOverview
        tasks = orderedTasks
        visibleTodayTasks = orderedTasks
        todayTotalMinutes = todayView.tasks.reduce(0) { $0 + $1.targetMinutes }
        todayHighlights = factualTodayHighlights(taskCount: todayView.tasks.count, totalMinutes: todayTotalMinutes)
        resources = fetchedResources
        hasLoadedDashboardContent = true
    }

    private func clearDashboardContent() {
        tasks = []
        visibleTodayTasks = []
        resources = []
        todayTotalMinutes = 0
        todayHighlights = ""
        expandedTaskIDs = []
    }

    private func clearStudySmartModeState() {
        studySmartMorningBriefing = nil
        studySmartProposalOptions = []
        studySmartProposalContexts = [:]
        studySmartProposalMessage = nil
    }

    private func studySmartProposalStatusMessage(for status: String) -> String {
        switch status {
        case "stale", "stale_proposal":
            return "智能建议已过期，请刷新后重试。"
        case "disabled":
            return "智能模式已关闭，未应用建议。"
        case "unsupported":
            return "该智能建议暂不支持应用。"
        case "noop", "no_op":
            return "没有需要应用的变更。"
        default:
            return "智能建议未应用。"
        }
    }

    private struct StudySmartRedState {
        let expectedLateProjectIds: [Int]
        let overCapacityDates: [String]
    }

    private func currentStudySmartRedState() -> StudySmartRedState {
        StudySmartRedState(
            expectedLateProjectIds: studyProjectOverview?.activeProjects
                .filter(\.expectedLate)
                .map(\.id)
                .sorted() ?? [],
            overCapacityDates: studyCalendarLoad?.days
                .filter(\.overCapacity)
                .map(\.date)
                .sorted() ?? []
        )
    }

    private func generateAfterAdjustmentProposalsIfNeeded(previousRedState: StudySmartRedState) async {
        let refreshedRedState = currentStudySmartRedState()
        let previousExpectedLateProjectIds = Set(previousRedState.expectedLateProjectIds)
        let previousOverCapacityDates = Set(previousRedState.overCapacityDates)
        let newExpectedLateProjectIds = refreshedRedState.expectedLateProjectIds.filter {
            !previousExpectedLateProjectIds.contains($0)
        }
        let newOverCapacityDates = refreshedRedState.overCapacityDates.filter {
            !previousOverCapacityDates.contains($0)
        }
        guard !newExpectedLateProjectIds.isEmpty || !newOverCapacityDates.isEmpty else { return }

        do {
            let response = try await api.generateStudySmartProposals(
                StudySmartProposalGenerationRequest(
                    trigger: .afterAdjustment,
                    previousExpectedLateProjectIds: previousRedState.expectedLateProjectIds,
                    previousOverCapacityDates: previousRedState.overCapacityDates
                )
            )
            isStudySmartModeEnabled = response.enabled
            guard response.enabled else {
                clearStudySmartModeState()
                return
            }
            studySmartProposalOptions = response.options
            studySmartProposalContexts = Dictionary(
                uniqueKeysWithValues: response.options.map { ($0.id, previousRedState) }
            )
            studySmartProposalMessage = response.message
            isOffline = false
        } catch {
            studySmartProposalMessage = "智能建议生成失败，请稍后重试。"
            isOffline = true
        }
    }

    @discardableResult
    private func refreshCalendarLoadIfNeeded() async -> Bool {
        guard let currentLoad = studyCalendarLoad else { return true }
        await fetchStudyCalendarLoad(start: currentLoad.startDate, end: currentLoad.endDate)
        return studyCalendarLoadError == nil
    }

    private func performStudyPlanAdjustment(_ action: () async throws -> Void) async {
        guard !isAdjustingStudyPlan else { return }
        isAdjustingStudyPlan = true
        studyPlanAdjustmentError = nil
        defer { isAdjustingStudyPlan = false }
        let previousRedState = currentStudySmartRedState()
        let smartModeEnabled = await refreshStudySmartModeSetting()

        do {
            try await action()
            isOffline = false
            await refreshAfterStudyPlanAdjustment(
                previousRedState: previousRedState,
                smartModeEnabled: smartModeEnabled
            )
        } catch {
            studyPlanAdjustmentError = "学习计划调整失败，请稍后重试。"
            isOffline = true
        }
    }

    private func refreshAfterStudyPlanAdjustment(
        previousRedState: StudySmartRedState,
        smartModeEnabled: Bool
    ) async {
        studySmartProposalOptions = []
        studySmartProposalMessage = nil
        studySmartMorningBriefing = nil
        studySmartProposalContexts = [:]
        guard await refreshDashboardFactsOnly() else { return }
        guard await refreshCalendarLoadIfNeeded() else { return }
        guard smartModeEnabled else { return }
        await generateAfterAdjustmentProposalsIfNeeded(previousRedState: previousRedState)
    }

    private func factualTodayHighlights(taskCount: Int, totalMinutes: Int) -> String {
        guard taskCount > 0 else { return "今天没有安排学习任务" }
        return "今日共 \(taskCount) 项学习任务，总计 \(totalMinutes) 分钟"
    }

    private func manageResource(
        _ resource: AssistantResource,
        failureMessage: String,
        action: () async throws -> Void
    ) async {
        guard managingResourceIDs.isEmpty else { return }
        managingResourceIDs.insert(resource.id)
        resourceManagementError = nil
        defer { managingResourceIDs.remove(resource.id) }
        do {
            try await action()
            await refreshDashboardAfterResourceMutation(
                failureMessage: "已更新「\(resource.title)」，但刷新资料进度失败，请稍后重试。"
            )
        } catch {
            resourceManagementError = failureMessage
        }
    }

    private func refreshDashboardAfterResourceMutation(failureMessage: String) async {
        await enqueueDashboardRefresh(resourceRefreshFailureMessage: failureMessage)
    }

    private func applyLocalDisplayOrder(to incomingTasks: [AssistantTask]) -> [AssistantTask] {
        let storedIDs = savedDisplayOrder()
        guard !storedIDs.isEmpty else {
            saveDisplayOrder(incomingTasks.map(\.id))
            return incomingTasks
        }

        let tasksByID = Dictionary(uniqueKeysWithValues: incomingTasks.map { ($0.id, $0) })
        var seen = Set<Int>()
        var ordered = storedIDs.compactMap { id -> AssistantTask? in
            guard let task = tasksByID[id] else { return nil }
            seen.insert(id)
            return task
        }
        ordered.append(contentsOf: incomingTasks.filter { !seen.contains($0.id) })
        saveDisplayOrder(ordered.map(\.id))
        return ordered
    }

    private func savedDisplayOrder() -> [Int] {
        orderStore.array(forKey: displayOrderKey) as? [Int] ?? []
    }

    private func saveDisplayOrder(_ ids: [Int]) {
        orderStore.set(ids, forKey: displayOrderKey)
    }

    private var displayOrderKey: String {
        "LearningAssistant.todayTaskOrder.\(todayKey)"
    }

    private var todayKey: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: todayProvider())
    }

    private func resourceHasDeadlineRisk(_ resource: AssistantResource) -> Bool {
        let status = resource.status.lowercased()
        if status.contains("overdue") || status.contains("risk") || status.contains("due") {
            return true
        }
        guard let deadline = parseDeadline(resource.deadline) else { return false }
        let today = Calendar.current.startOfDay(for: todayProvider())
        let warningWindow = Calendar.current.date(byAdding: .day, value: 3, to: today) ?? today
        return deadline <= warningWindow
    }

    private func parseDeadline(_ rawValue: String?) -> Date? {
        guard let rawValue, !rawValue.isEmpty else { return nil }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: rawValue) { return Calendar.current.startOfDay(for: date) }

        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.calendar = Calendar(identifier: .gregorian)
        dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateOnlyFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
        return dateOnlyFormatter.date(from: rawValue)
    }

    private func formatStudyPlanDeadline(_ deadline: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: deadline)
    }

    private func reviewReadyStudyPlanDraftId() -> Int? {
        guard let draftId = studyPlanDraftId else {
            studyPlanError = "缺少学习计划草稿，请重新提交链接。"
            return nil
        }
        guard let draft = studyPlanDraft, draft.id == draftId, draft.status == "review" else {
            studyPlanError = "学习计划草稿尚未准备好，请先完成草稿生成。"
            return nil
        }
        return draftId
    }

    private func clearStudyPlanDraftFlow() {
        studyPlanDraftId = nil
        studyPlanClarification = nil
        studyPlanDraft = nil
        studyPlanError = nil
    }
}
