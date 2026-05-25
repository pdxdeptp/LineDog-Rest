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

enum AddInitiateSourceType: String, CaseIterable, Identifiable {
    case textGoal = "text_goal"
    case url
    case githubRepo = "github_repo"
    case existingProjectSnippet = "existing_project_snippet"
    case interviewPrepItem = "interview_prep_item"
    case resumeProjectNote = "resume_project_note"
    case noteSnippet = "note_snippet"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .textGoal: return "目标文本"
        case .url: return "URL"
        case .githubRepo: return "GitHub repo"
        case .existingProjectSnippet: return "已有项目片段"
        case .interviewPrepItem: return "面试准备"
        case .resumeProjectNote: return "简历/项目笔记"
        case .noteSnippet: return "笔记片段"
        }
    }

    var placeholder: String {
        switch self {
        case .textGoal: return "例如：两周内做出 agent-browser demo"
        case .url: return "https://example.com/course-or-article"
        case .githubRepo: return "https://github.com/org/repo 或 org/repo"
        case .existingProjectSnippet: return "粘贴已有项目上下文或下一步目标"
        case .interviewPrepItem: return "例如：准备 backend/agent 系统设计面试"
        case .resumeProjectNote: return "粘贴简历 bullet、项目说明或改写目标"
        case .noteSnippet: return "粘贴一段想归档或立项的笔记"
        }
    }
}

enum AddInitiateRoleChoice: String, CaseIterable, Identifiable {
    case newPlan = "new_plan"
    case attachToExistingPlan = "attach_to_existing_plan"
    case supportingMaterial = "supporting_material"
    case referenceMaterial = "reference_material"
    case laterResource = "later_resource"
    case oneOffAction = "one_off_action"

    var id: String { rawValue }

    var requestRole: String {
        switch self {
        case .supportingMaterial:
            return AddInitiateRoleChoice.attachToExistingPlan.rawValue
        case .oneOffAction:
            return "immediate_one_off"
        default:
            return rawValue
        }
    }

    var label: String {
        switch self {
        case .newPlan: return "新计划"
        case .attachToExistingPlan: return "加入已有计划"
        case .supportingMaterial: return "辅助材料"
        case .referenceMaterial: return "参考资料"
        case .laterResource: return "稍后处理"
        case .oneOffAction: return "一次性行动"
        }
    }
}

enum AddInitiateAttachmentMode: String, CaseIterable, Identifiable {
    case materialOnly = "material_only"
    case draftPhase = "draft_phase"
    case scheduledWork = "scheduled_work"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .materialOnly: return "辅助材料"
        case .draftPhase: return "草案阶段"
        case .scheduledWork: return "排入工作"
        }
    }
}

enum AddInitiateFlowState: String, Equatable {
    case idleInput = "idle_input"
    case routingProgress = "routing_progress"
    case roleReview = "role_review"
    case nonPlanTerminal = "non_plan_terminal"
    case anchorReview = "anchor_review"
    case planningProgress = "planning_progress"
    case needsInput = "needs_input"
    case compileFailed = "compile_failed"
    case infeasibleReview = "infeasible_review"
    case draftReview = "draft_review"
    case optionEffectProgress = "option_effect_progress"
    case activationProgress = "activation_progress"
    case activationFailed = "activation_failed"
    case activated
    case cancelled
}

struct AddInitiateExistingPlanCandidate: Identifiable, Equatable {
    let id: Int
    let title: String
}

struct AddInitiateDraftReviewDaySummary: Equatable {
    let date: String
    let plannedMinutes: Int
    let loadStateLabel: String
    let fallbackCue: String?
}

struct AddInitiateDraftScheduleItem: Identifiable, Equatable {
    let id: String
    let title: String
    let minutes: Int
    let fallbackCue: String?
}

struct AddInitiateDraftScheduleDay: Identifiable, Equatable {
    let date: String
    let plannedMinutes: Int
    let loadStateLabel: String
    let items: [AddInitiateDraftScheduleItem]

    var id: String { date }
}

struct AddInitiateTaskEditDraft: Equatable {
    let itemId: String
    var title: String
    var minutes: Int
}

struct AddInitiateDraftReviewSummary: Equatable {
    let roleLabel: String
    let targetOutput: String
    let targetDepth: String
    let deadlineFit: String
    let assumptions: [String]
    let firstWeekDays: [AddInitiateDraftReviewDaySummary]
    let bufferSummary: String?
    let fallbackSummary: String?
    let capacityRiskFacts: [String]
    let deadlineRisk: String?
    let sourceDetailLines: [String]
    let fullScheduleDays: [AddInitiateDraftScheduleDay]
    let fullScheduleDayCount: Int
    let editableTaskCount: Int
    let rendersEveryScheduledItemByDefault: Bool
}

struct AddInitiateInfeasibleOptionChoice: Identifiable, Equatable {
    let optionId: String
    let localizedLabel: String
    let effectDescription: String

    var id: String { optionId }
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
    @Published var addInitiateRawInput: String = ""
    @Published var addInitiateSourceType: AddInitiateSourceType = .textGoal
    @Published private(set) var addInitiateClientRequestId: String? = nil
    @Published private(set) var addInitiateSession: AddInitiateSessionResponse? = nil
    @Published var addInitiateError: String? = nil
    @Published var addInitiateDeadline: String = ""
    @Published var addInitiateDeadlineType: String = "soft"
    @Published var addInitiateCapacityMinutes: Int = 60
    @Published var addInitiateTargetOutput: String = ""
    @Published var addInitiateTargetDepth: String = "apply"
    @Published var addInitiateAcceptedAssumptions: [String] = []
    @Published var addInitiateAssumptionsText: String = "" {
        didSet {
            addInitiateAcceptedAssumptions = Self.parseAddInitiateAssumptions(addInitiateAssumptionsText)
        }
    }
    @Published var addInitiateNeedsInputAnswer: String = ""
    @Published private(set) var addInitiateTaskEditDrafts: [String: AddInitiateTaskEditDraft] = [:]
    @Published private var addInitiateLocalFlowState: AddInitiateFlowState? = nil

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
    @Published var studySmartProposalMessageTrigger: StudySmartProposalTrigger? = nil
    @Published var studySmartSettingsMessage: String? = nil
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
    @Published var isStartingAddInitiateSession = false
    @Published var isConfirmingAddInitiateRole = false
    @Published var isConfirmingAddInitiateAnchors = false
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

    var addInitiateStage: AddInitiateStage? {
        addInitiateSession?.stage
    }

    var addInitiateRecommendedRole: String? {
        addInitiateSession?.recommendedRole
    }

    var addInitiateExistingPlanCandidates: [AddInitiateExistingPlanCandidate] {
        addInitiateSession?.existingPlanCandidates?.compactMap { candidate in
            guard let id = candidate["id"]?.value as? Int else { return nil }
            let title = candidate["title"]?.value as? String ?? "计划 \(id)"
            return AddInitiateExistingPlanCandidate(id: id, title: title)
        } ?? []
    }

    var addInitiateFlowState: AddInitiateFlowState {
        if let addInitiateLocalFlowState { return addInitiateLocalFlowState }
        if isStartingAddInitiateSession { return .routingProgress }
        guard let session = addInitiateSession else { return .idleInput }
        switch session.reviewState {
        case .roleReview:
            return .roleReview
        case .anchorReview:
            return .anchorReview
        case .storedNonPlan, .materialAttached:
            return .nonPlanTerminal
        case .needsInput:
            return .needsInput
        case .compileFailed:
            return .compileFailed
        case .infeasibleReview:
            return .infeasibleReview
        case .draftReview:
            return .draftReview
        case .activationFailed:
            return .activationFailed
        case .activated:
            return .activated
        case .cancelled:
            return .cancelled
        case .error:
            return .compileFailed
        }
    }

    var addInitiatePrimaryActionCount: Int {
        switch addInitiateFlowState {
        case .routingProgress, .planningProgress, .optionEffectProgress, .activationProgress:
            return 0
        default:
            return 1
        }
    }

    var addInitiateDraftReviewSummary: AddInitiateDraftReviewSummary? {
        guard let session = addInitiateSession,
              session.reviewState == .draftReview || session.reviewState == .activationFailed,
              let package = session.reviewPackage else {
            return nil
        }
        return Self.buildAddInitiateDraftReviewSummary(
            package: package,
            session: session,
            fallbackTargetOutput: addInitiateTargetOutput,
            fallbackTargetDepth: addInitiateTargetDepth
        )
    }

    var addInitiateInfeasibleOptionChoices: [AddInitiateInfeasibleOptionChoice] {
        guard let package = addInitiateSession?.reviewPackage else { return [] }
        let packageDeadlineType = Self.stringValue(Self.pairedValue(in: package, snake: "deadline_type", camel: "deadlineType"))
            ?? addInitiateDeadlineType
        let hardDeadline = packageDeadlineType.lowercased() == "hard"
        let optionDictionaries = Self.arrayValue(Self.pairedValue(in: package, snake: "infeasibility_options", camel: "infeasibilityOptions"))
            .compactMap(Self.dictionaryValue)
        let idsFromOptions = optionDictionaries.compactMap { Self.stringValue($0["id"]) }
        let riskReport = Self.dictionaryValue(Self.pairedValue(in: package, snake: "risk_report", camel: "riskReport")) ?? [:]
        let idsFromRisk = Self.stringArrayValue(Self.pairedValue(in: riskReport, snake: "canonical_infeasibility_option_ids", camel: "canonicalInfeasibilityOptionIds")) ?? []
        let ids = idsFromOptions.isEmpty ? idsFromRisk : idsFromOptions
        var seen: Set<String> = []
        return ids.compactMap { optionId in
            guard !optionId.isEmpty else { return nil }
            guard !(hardDeadline && optionId == "accept_late_finish") else { return nil }
            guard seen.insert(optionId).inserted else { return nil }
            let effect = optionDictionaries
                .first { Self.stringValue($0["id"]) == optionId }
                .flatMap { Self.stringValue(Self.pairedValue(in: $0, snake: "effect_type", camel: "effectType")) }
            return AddInitiateInfeasibleOptionChoice(
                optionId: optionId,
                localizedLabel: Self.localizedAddInitiateOptionLabel(optionId),
                effectDescription: Self.localizedAddInitiateOptionEffect(effect)
            )
        }
    }

    var addInitiateInfeasibleRiskFacts: [String] {
        guard let package = addInitiateSession?.reviewPackage,
              let riskReport = Self.dictionaryValue(Self.pairedValue(in: package, snake: "risk_report", camel: "riskReport")) else {
            return []
        }
        var facts = Self.addInitiateCapacityRiskFacts(from: riskReport).filter { fact in
            !fact.hasPrefix("必要工作") && !fact.hasPrefix("可用容量") && !fact.hasPrefix("已有负荷")
        }
        if Self.boolValue(Self.pairedValue(in: riskReport, snake: "buffer_erosion", camel: "bufferErosion")) == true {
            facts.append("缓冲被侵蚀")
        }
        if Self.hasLowCalibrationFact(in: riskReport) {
            facts.append("低校准")
        }
        return facts
    }

    var canActivateAddInitiateDraft: Bool {
        guard addInitiateFlowState == .draftReview || addInitiateFlowState == .activationFailed,
              let session = addInitiateSession,
              let draftVersion = session.draftVersion,
              session.draftId != nil else {
            return false
        }
        guard let package = session.reviewPackage else { return true }
        if let isLatest = Self.boolValue(Self.pairedValue(in: package, snake: "is_latest_version", camel: "isLatestVersion")), !isLatest {
            return false
        }
        if let packageDraftVersion = Self.intValue(Self.pairedValue(in: package, snake: "draft_version", camel: "draftVersion")),
           packageDraftVersion != draftVersion {
            return false
        }
        if let latestDraftVersion = Self.intValue(Self.pairedValue(in: package, snake: "latest_draft_version", camel: "latestDraftVersion")),
           latestDraftVersion > draftVersion {
            return false
        }
        return true
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
    private var addInitiateFlowGeneration = 0
    private var addInitiateAnchorRequestSequence = 0
    private var addInitiateOptionRequestSequence = 0
    private var addInitiateActivationRequestSequence = 0
    private var studyCalendarLoadRequestSequence = 0
    private var studySmartProposalContexts: [String: StudySmartRedState] = [:]
    private var studySmartModeSettingRequestID = 0

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
        isConnecting = autoLoadWhenReady
        readyObserver = NotificationCenter.default.addObserver(
            forName: .backendDidBecomeReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, autoLoadWhenReady, self.isConnecting else { return }
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
            setStudySmartProposalMessage(nil)
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

    func updateStudySmartModeSetting(_ enabled: Bool) async {
        studySmartModeSettingRequestID += 1
        let requestID = studySmartModeSettingRequestID
        do {
            let settings = try await api.updateStudySmartModeSettings(StudySmartModeSettings(enabled: enabled))
            guard requestID == studySmartModeSettingRequestID else { return }
            isStudySmartModeEnabled = settings.enabled
            studySmartSettingsMessage = nil
            setStudySmartProposalMessage(nil)
            if settings.enabled {
                do {
                    let briefing = try await api.fetchStudySmartMorningBriefing()
                    guard requestID == studySmartModeSettingRequestID else { return }
                    isStudySmartModeEnabled = briefing.enabled
                    if briefing.enabled {
                        studySmartMorningBriefing = briefing
                        studySmartProposalOptions = briefing.options
                        studySmartProposalContexts = [:]
                        setStudySmartProposalMessage(nil)
                    } else {
                        clearStudySmartModeState()
                    }
                    isOffline = false
                } catch {
                    guard requestID == studySmartModeSettingRequestID else { return }
                    isStudySmartModeEnabled = settings.enabled
                    clearStudySmartModeState()
                    setStudySmartProposalMessage(
                        "智能模式已开启，但晨间简报暂时无法加载。请稍后刷新。",
                        trigger: .morning
                    )
                    isOffline = true
                }
            } else {
                clearStudySmartModeState()
                isOffline = false
            }
        } catch {
            guard requestID == studySmartModeSettingRequestID else { return }
            setStudySmartProposalMessage(nil)
            studySmartSettingsMessage = "智能模式设置更新失败，请稍后重试。"
            isOffline = true
        }
    }

    func ignoreStudySmartProposals() {
        studySmartProposalOptions = []
        studySmartProposalContexts = [:]
        setStudySmartProposalMessage(nil)
    }

    func applyStudySmartProposal(_ option: StudySmartProposalOption) async {
        guard !isApplyingStudySmartProposal else { return }
        guard isStudySmartModeEnabled else {
            clearStudySmartModeState()
            return
        }
        guard let currentOption = studySmartProposalOptions.first(where: { $0.id == option.id }) else {
            setStudySmartProposalMessage("智能建议已过期，请刷新后重试。", trigger: option.trigger)
            return
        }
        guard currentOption.trigger == option.trigger,
              currentOption.signature == option.signature else {
            setStudySmartProposalMessage("智能建议已过期，请刷新后重试。", trigger: currentOption.trigger)
            return
        }
        isApplyingStudySmartProposal = true
        setStudySmartProposalMessage(nil)
        defer { isApplyingStudySmartProposal = false }

        do {
            let context = studySmartProposalContexts[currentOption.id]
            let result = try await api.applyStudySmartProposal(
                StudySmartProposalApplyRequest(
                    proposal: currentOption,
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
                setStudySmartProposalMessage(
                    result.message ?? studySmartProposalStatusMessage(for: result.status),
                    trigger: result.status == "disabled" ? nil : (result.trigger ?? currentOption.trigger)
                )
                return
            }

            studySmartProposalOptions = []
            studySmartProposalContexts = [:]
            studySmartMorningBriefing = nil
            setStudySmartProposalMessage(
                result.message ?? "智能建议已应用。",
                trigger: result.trigger ?? currentOption.trigger
            )
            if result.refresh?.today == true || result.refresh?.projectOverview == true {
                guard await refreshDashboardFactsOnly() else { return }
            }
            if result.refresh?.calendar == true {
                await refreshCalendarLoadIfNeeded()
            }
            studySmartProposalOptions = []
            studySmartProposalContexts = [:]
        } catch {
            setStudySmartProposalMessage("智能建议应用失败，请稍后重试。", trigger: currentOption.trigger)
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

    // MARK: - Add / Initiate

    func startAddInitiateSession(rawInput: String, sourceType: AddInitiateSourceType) async {
        let trimmedInput = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }

        let clientRequestId = UUID().uuidString
        addInitiateFlowGeneration += 1
        let operationGeneration = addInitiateFlowGeneration
        addInitiateRawInput = trimmedInput
        addInitiateSourceType = sourceType
        addInitiateClientRequestId = clientRequestId
        addInitiateSession = nil
        addInitiateError = nil
        addInitiateLocalFlowState = nil
        resetAddInitiateAnchors()
        isStartingAddInitiateSession = true
        defer { isStartingAddInitiateSession = false }

        do {
            let response = try await api.startAddInitiateSession(
                AddInitiateStartSessionRequest(
                    clientRequestId: clientRequestId,
                    rawInput: trimmedInput,
                    sourceType: sourceType.rawValue
                )
            )
            guard addInitiateFlowGeneration == operationGeneration,
                  addInitiateClientRequestId == clientRequestId else { return }
            reconcileAddInitiateTaskEditDrafts(previous: addInitiateSession, next: response)
            addInitiateSession = response
            addInitiateError = response.error
            isOffline = false
        } catch {
            guard addInitiateFlowGeneration == operationGeneration,
                  addInitiateClientRequestId == clientRequestId else { return }
            addInitiateError = "无法启动 Add / Initiate，请重试。"
            isOffline = true
        }
    }

    func confirmAddInitiateRole(
        title: String,
        confirmedRole: AddInitiateRoleChoice,
        existingPlanId: Int? = nil,
        attachmentMode: AddInitiateAttachmentMode? = nil
    ) async {
        guard !isConfirmingAddInitiateRole else { return }
        guard let session = addInitiateSession,
              let intakeItemId = session.intakeItemId else {
            addInitiateError = "缺少 Add / Initiate 会话，请重新提交。"
            return
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            addInitiateError = "请填写标题后再确认。"
            return
        }

        let requestExistingPlanId: Int?
        let resolvedAttachmentMode: AddInitiateAttachmentMode?
        switch confirmedRole {
        case .supportingMaterial:
            guard let existingPlanId else {
                addInitiateError = "请选择要附加的已有计划。"
                return
            }
            requestExistingPlanId = existingPlanId
            resolvedAttachmentMode = .materialOnly
        case .attachToExistingPlan:
            guard let existingPlanId else {
                addInitiateError = "请选择要附加的已有计划。"
                return
            }
            guard let attachmentMode else {
                addInitiateError = "请选择附件方式。"
                return
            }
            requestExistingPlanId = existingPlanId
            resolvedAttachmentMode = attachmentMode
        default:
            requestExistingPlanId = nil
            resolvedAttachmentMode = nil
        }

        let operationGeneration = addInitiateFlowGeneration
        isConfirmingAddInitiateRole = true
        addInitiateError = nil
        defer { isConfirmingAddInitiateRole = false }

        do {
            let response = try await api.confirmAddInitiateRole(
                AddInitiateRoleConfirmationRequest(
                    sessionId: session.sessionId,
                    intakeItemId: intakeItemId,
                    confirmedRole: confirmedRole.requestRole,
                    title: trimmedTitle,
                    url: addInitiateSourceType == .url ? addInitiateRawInput : nil,
                    existingPlanId: requestExistingPlanId,
                    attachmentMode: resolvedAttachmentMode?.rawValue,
                    canonicalRepoRole: session.canonicalRepoRole
                )
            )
            guard addInitiateFlowGeneration == operationGeneration,
                  addInitiateSession?.sessionId == session.sessionId else { return }
            addInitiateSession = response
            addInitiateError = response.error
            addInitiateLocalFlowState = nil
            seedAddInitiateAnchorsIfNeeded(from: response)
            isOffline = false
        } catch {
            guard addInitiateFlowGeneration == operationGeneration,
                  addInitiateSession?.sessionId == session.sessionId else { return }
            addInitiateError = "角色确认失败，请重试。"
            if error is AssistantOfflineError {
                isOffline = true
            }
        }
    }

    func confirmAddInitiateAnchors() async {
        guard let session = addInitiateSession,
              let draftId = session.draftId else {
            addInitiateError = "缺少 Add / Initiate 草案，请重新确认角色。"
            return
        }
        let trimmedDeadline = addInitiateDeadline.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOutput = addInitiateTargetOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDepth = addInitiateTargetDepth.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDeadline.isEmpty else {
            addInitiateError = "请填写截止日期。"
            return
        }
        guard addInitiateCapacityMinutes > 0 else {
            addInitiateError = "可用时间必须大于 0 分钟。"
            return
        }
        guard !trimmedOutput.isEmpty, !trimmedDepth.isEmpty else {
            addInitiateError = "请填写目标产出和目标深度。"
            return
        }

        let operationGeneration = addInitiateFlowGeneration
        addInitiateAnchorRequestSequence += 1
        let requestSequence = addInitiateAnchorRequestSequence
        isConfirmingAddInitiateAnchors = true
        addInitiateError = nil
        addInitiateLocalFlowState = .planningProgress
        defer { isConfirmingAddInitiateAnchors = false }

        do {
            let response = try await api.confirmAddInitiateAnchors(
                AddInitiateAnchorConfirmationRequest(
                    sessionId: session.sessionId,
                    draftId: draftId,
                    intakeItemId: session.intakeItemId,
                    deadline: trimmedDeadline,
                    deadlineType: addInitiateDeadlineType,
                    capacityMinutes: addInitiateCapacityMinutes,
                    targetOutput: trimmedOutput,
                    targetDepth: trimmedDepth,
                    assumptions: addInitiateAssumptionsPayload(),
                    restWeekdays: nil,
                    unavailableDates: nil,
                    bufferPolicy: nil,
                    loadShape: nil
                )
            )
            guard isCurrentAddInitiateAnchorResponse(
                response,
                requestSessionId: session.sessionId,
                requestDraftId: draftId,
                requestDraftVersion: session.draftVersion,
                operationGeneration: operationGeneration,
                requestSequence: requestSequence
            ) else {
                if addInitiateFlowGeneration == operationGeneration,
                   addInitiateSession?.sessionId == session.sessionId {
                    addInitiateLocalFlowState = nil
                }
                return
            }
            reconcileAddInitiateTaskEditDrafts(previous: addInitiateSession, next: response)
            addInitiateSession = response
            addInitiateError = response.error
            addInitiateLocalFlowState = nil
            isOffline = false
        } catch {
            guard addInitiateFlowGeneration == operationGeneration,
                  addInitiateSession?.sessionId == session.sessionId,
                  addInitiateSession?.draftId == draftId else { return }
            addInitiateLocalFlowState = nil
            addInitiateError = "锚点确认失败，请重试。"
            if error is AssistantOfflineError {
                isOffline = true
            }
        }
    }

    func retryAddInitiatePlanning() async {
        await confirmAddInitiateAnchors()
    }

    func applyAddInitiateOptionEffect(optionId: String) async {
        guard let session = addInitiateSession,
              let draftId = session.draftId,
              let draftVersion = session.draftVersion else {
            addInitiateError = "缺少可调整的 Add / Initiate 草案。"
            return
        }

        let operationGeneration = addInitiateFlowGeneration
        addInitiateOptionRequestSequence += 1
        let requestSequence = addInitiateOptionRequestSequence
        addInitiateError = nil
        addInitiateLocalFlowState = .optionEffectProgress

        do {
            let response = try await api.applyAddInitiateOptionEffect(
                AddInitiateOptionEffectRequest(
                    sessionId: session.sessionId,
                    draftId: draftId,
                    draftVersion: draftVersion,
                    optionId: optionId,
                    parameters: buildAddInitiateOptionParameters(optionId: optionId)
                )
            )
            guard isCurrentAddInitiateOptionResponse(
                response,
                requestSessionId: session.sessionId,
                requestDraftId: draftId,
                requestDraftVersion: draftVersion,
                operationGeneration: operationGeneration,
                requestSequence: requestSequence
            ) else {
                if addInitiateFlowGeneration == operationGeneration,
                   addInitiateSession?.sessionId == session.sessionId {
                    addInitiateLocalFlowState = nil
                }
                return
            }
            reconcileAddInitiateTaskEditDrafts(previous: addInitiateSession, next: response)
            addInitiateSession = response
            addInitiateError = response.error
            addInitiateLocalFlowState = nil
            isOffline = false
        } catch {
            guard addInitiateFlowGeneration == operationGeneration,
                  addInitiateSession?.sessionId == session.sessionId,
                  addInitiateSession?.draftId == draftId,
                  addInitiateSession?.draftVersion == draftVersion else { return }
            addInitiateLocalFlowState = nil
            addInitiateError = "选项调整失败，请重试。"
            if error is AssistantOfflineError {
                isOffline = true
            }
        }
    }

    func activateAddInitiateDraft() async {
        guard let session = addInitiateSession,
              let draftId = session.draftId,
              let draftVersion = session.draftVersion else {
            addInitiateError = "缺少可激活的 Add / Initiate 草案。"
            return
        }
        guard canActivateAddInitiateDraft else {
            addInitiateError = "草案已变更，请先重新载入最新版本。"
            return
        }

        let operationGeneration = addInitiateFlowGeneration
        addInitiateActivationRequestSequence += 1
        let requestSequence = addInitiateActivationRequestSequence
        addInitiateError = nil
        addInitiateLocalFlowState = .activationProgress

        do {
            let response = try await api.activateAddInitiateDraft(
                AddInitiateActivationRequest(
                    sessionId: session.sessionId,
                    draftId: draftId,
                    draftVersion: draftVersion
                )
            )
            guard isCurrentAddInitiateDraftResponse(
                response,
                requestSessionId: session.sessionId,
                requestDraftId: draftId,
                requestDraftVersion: draftVersion,
                operationGeneration: operationGeneration,
                requestSequence: requestSequence
            ) else {
                if addInitiateFlowGeneration == operationGeneration,
                   addInitiateSession?.sessionId == session.sessionId {
                    addInitiateLocalFlowState = nil
                }
                return
            }
            let preservedResponse = Self.preserveAddInitiateReviewPackageIfNeeded(response, current: addInitiateSession)
            reconcileAddInitiateTaskEditDrafts(previous: addInitiateSession, next: preservedResponse)
            addInitiateSession = preservedResponse
            addInitiateError = preservedResponse.error
            addInitiateLocalFlowState = nil
            isOffline = false
        } catch {
            guard addInitiateFlowGeneration == operationGeneration,
                  addInitiateSession?.sessionId == session.sessionId,
                  addInitiateSession?.draftId == draftId,
                  addInitiateSession?.draftVersion == draftVersion else { return }
            addInitiateLocalFlowState = nil
            addInitiateError = "激活失败，请重试。"
            if error is AssistantOfflineError {
                isOffline = true
            }
        }
    }

    func editAddInitiateDraft() {
        guard addInitiateSession?.draftId != nil else {
            addInitiateError = "缺少可编辑的 Add / Initiate 草案。"
            return
        }
        addInitiateError = nil
        addInitiateLocalFlowState = .anchorReview
    }

    func beginAddInitiateTaskEdit(_ item: AddInitiateDraftScheduleItem) {
        if addInitiateTaskEditDrafts[item.id] == nil {
            addInitiateTaskEditDrafts[item.id] = AddInitiateTaskEditDraft(
                itemId: item.id,
                title: item.title,
                minutes: item.minutes
            )
        }
    }

    func addInitiateTaskEditTitle(for item: AddInitiateDraftScheduleItem) -> String {
        addInitiateTaskEditDrafts[item.id]?.title ?? item.title
    }

    func addInitiateTaskEditMinutes(for item: AddInitiateDraftScheduleItem) -> Int {
        addInitiateTaskEditDrafts[item.id]?.minutes ?? item.minutes
    }

    func updateAddInitiateTaskEditTitle(itemId: String, title: String) {
        guard var draft = addInitiateTaskEditDrafts[itemId] else {
            addInitiateTaskEditDrafts[itemId] = AddInitiateTaskEditDraft(
                itemId: itemId,
                title: title,
                minutes: 0
            )
            return
        }
        draft.title = title
        addInitiateTaskEditDrafts[itemId] = draft
    }

    func updateAddInitiateTaskEditMinutes(itemId: String, minutes: Int) {
        let clampedMinutes = max(5, minutes)
        guard var draft = addInitiateTaskEditDrafts[itemId] else {
            addInitiateTaskEditDrafts[itemId] = AddInitiateTaskEditDraft(
                itemId: itemId,
                title: "",
                minutes: clampedMinutes
            )
            return
        }
        draft.minutes = clampedMinutes
        addInitiateTaskEditDrafts[itemId] = draft
    }

    private func buildAddInitiateOptionParameters(optionId: String) -> [String: AnyCodable]? {
        var parameters: [String: AnyCodable] = [:]

        switch optionId {
        case "lower_depth":
            let depth = addInitiateTargetDepth.trimmingCharacters(in: .whitespacesAndNewlines)
            if !depth.isEmpty {
                parameters["requested_depth"] = AnyCodable(depth)
            }
        case "increase_capacity":
            if addInitiateCapacityMinutes > 0 {
                parameters["new_daily_capacity_min"] = AnyCodable(addInitiateCapacityMinutes)
            }
        case "extend_deadline":
            let deadline = addInitiateDeadline.trimmingCharacters(in: .whitespacesAndNewlines)
            if !deadline.isEmpty {
                parameters["new_deadline"] = AnyCodable(deadline)
            }
        case "answer_one_question":
            if let questionId = addInitiateFocusedQuestionId() {
                parameters["question_id"] = AnyCodable(questionId)
            }
        case "edit_estimates":
            addLocalTaskEditParameters(to: &parameters)
        case "rebalance":
            parameters["load_shape"] = AnyCodable("steady")
        default:
            if !addInitiateTaskEditDrafts.isEmpty {
                addLocalTaskEditParameters(to: &parameters)
            }
        }

        return parameters.isEmpty ? nil : parameters
    }

    private func addLocalTaskEditParameters(to parameters: inout [String: AnyCodable]) {
        guard !addInitiateTaskEditDrafts.isEmpty else { return }
        let edits = Dictionary(uniqueKeysWithValues: addInitiateTaskEditDrafts.values
            .sorted { $0.itemId < $1.itemId }
            .map { draft in
                (draft.itemId, draft.minutes)
            })
        parameters["estimate_edits"] = AnyCodable(edits)
    }

    private func addInitiateFocusedQuestionId() -> String? {
        guard let question = addInitiateSession?.clarificationQuestion else { return nil }
        return Self.stringValue(Self.pairedValue(in: question, snake: "question_id", camel: "questionId"))
            ?? Self.stringValue(question["id"]?.value)
    }

    func answerAddInitiateNeedsInput() async {
        let answer = addInitiateNeedsInputAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !answer.isEmpty {
            let existing = Self.parseAddInitiateAssumptions(addInitiateAssumptionsText)
            addInitiateAssumptionsText = (existing + [answer]).joined(separator: "\n")
            addInitiateNeedsInputAnswer = ""
        }
        await confirmAddInitiateAnchors()
    }

    func cancelAddInitiateFlow() {
        addInitiateFlowGeneration += 1
        addInitiateLocalFlowState = .cancelled
        addInitiateSession = nil
        addInitiateError = nil
        addInitiateTaskEditDrafts = [:]
    }

    func prepareForNewAddInitiateInput() {
        addInitiateFlowGeneration += 1
        addInitiateRawInput = ""
        addInitiateClientRequestId = nil
        addInitiateSession = nil
        addInitiateError = nil
        addInitiateLocalFlowState = nil
        resetAddInitiateAnchors()
    }

    private func resetAddInitiateAnchors() {
        addInitiateDeadline = ""
        addInitiateDeadlineType = "soft"
        addInitiateCapacityMinutes = 60
        addInitiateTargetOutput = ""
        addInitiateTargetDepth = "apply"
        addInitiateAcceptedAssumptions = []
        addInitiateAssumptionsText = ""
        addInitiateNeedsInputAnswer = ""
        addInitiateTaskEditDrafts = [:]
    }

    private func seedAddInitiateAnchorsIfNeeded(from session: AddInitiateSessionResponse) {
        guard session.reviewState == .anchorReview else { return }
        if addInitiateTargetOutput.isEmpty {
            addInitiateTargetOutput = addInitiateRawInput
        }
        if addInitiateTargetDepth.isEmpty {
            addInitiateTargetDepth = "apply"
        }
    }

    private func addInitiateAssumptionsPayload() -> [String: AnyCodable]? {
        let textAssumptions = Self.parseAddInitiateAssumptions(addInitiateAssumptionsText)
        let assumptions = textAssumptions.isEmpty ? addInitiateAcceptedAssumptions : textAssumptions
        guard !assumptions.isEmpty else { return nil }
        return ["accepted": AnyCodable(assumptions)]
    }

    private static func parseAddInitiateAssumptions(_ text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func buildAddInitiateDraftReviewSummary(
        package: [String: AnyCodable],
        session: AddInitiateSessionResponse,
        fallbackTargetOutput: String,
        fallbackTargetDepth: String
    ) -> AddInitiateDraftReviewSummary {
        let scheduledDays = arrayValue(pairedValue(in: package, snake: "scheduled_days", camel: "scheduledDays"))
            .compactMap(dictionaryValue)
        let riskReport = dictionaryValue(pairedValue(in: package, snake: "risk_report", camel: "riskReport")) ?? [:]
        let firstWeekDays = scheduledDays.prefix(7).map(addInitiateDaySummary)
        let fallbackSummary = firstFallbackMetadata(in: scheduledDays).map { fallback in
            let output = stringValue(pairedValue(in: fallback, snake: "fallback_output", camel: "fallbackOutput"))
                ?? stringValue(fallback["output"])
                ?? "可降级产出"
            if let riskEffect = stringValue(pairedValue(in: fallback, snake: "risk_effect", camel: "riskEffect")) {
                return "替代执行：\(output)；风险影响：\(localizedAddInitiateToken(riskEffect))"
            }
            return "替代执行：\(output)"
        }
        let sourceDetailLines = dictionaryValue(pairedValue(in: package, snake: "source_details", camel: "sourceDetails"))?
            .compactMap { key, value -> String? in
                guard let text = stringValue(value) else { return nil }
                return "\(localizedAddInitiateSourceDetailKey(key)): \(localizedAddInitiateSourceDetailValue(text))"
            }
            .sorted() ?? []
        let fullScheduleDays = scheduledDays.map(addInitiateScheduleDay)
        let editableTaskCount = fullScheduleDays.reduce(0) { $0 + $1.items.count }

        return AddInitiateDraftReviewSummary(
            roleLabel: localizedAddInitiateRoleLabel(
                stringValue(package["role"]?.value)
                    ?? session.confirmedRole
                    ?? session.recommendedRole
                    ?? ""
            ),
            targetOutput: stringValue(pairedValue(in: package, snake: "target_output", camel: "targetOutput"))
                ?? fallbackTargetOutput,
            targetDepth: stringValue(pairedValue(in: package, snake: "target_depth", camel: "targetDepth"))
                ?? fallbackTargetDepth,
            deadlineFit: localizedAddInitiateToken(
                stringValue(pairedValue(in: package, snake: "deadline_fit", camel: "deadlineFit"))
                    ?? stringValue(package["status"]?.value)
                    ?? "review"
            ),
            assumptions: addInitiateAssumptions(from: package["assumptions"]?.value),
            firstWeekDays: firstWeekDays,
            bufferSummary: addInitiateBufferSummary(from: riskReport),
            fallbackSummary: fallbackSummary,
            capacityRiskFacts: addInitiateCapacityRiskFacts(from: riskReport),
            deadlineRisk: (stringValue(pairedValue(in: riskReport, snake: "date_window_risk", camel: "dateWindowRisk"))
                ?? stringValue(pairedValue(in: package, snake: "deadline_risk", camel: "deadlineRisk")))
                .map(localizedAddInitiateToken),
            sourceDetailLines: sourceDetailLines,
            fullScheduleDays: fullScheduleDays,
            fullScheduleDayCount: fullScheduleDays.count,
            editableTaskCount: editableTaskCount,
            rendersEveryScheduledItemByDefault: false
        )
    }

    private static func addInitiateDaySummary(_ day: [String: Any]) -> AddInitiateDraftReviewDaySummary {
        let loadState = stringValue(pairedValue(in: day, snake: "load_state", camel: "loadState")) ?? "within_budget"
        return AddInitiateDraftReviewDaySummary(
            date: stringValue(day["date"]) ?? "未定日期",
            plannedMinutes: intValue(pairedValue(in: day, snake: "planned_minutes", camel: "plannedMinutes")) ?? 0,
            loadStateLabel: localizedAddInitiateLoadState(loadState),
            fallbackCue: addInitiateFallbackCue(in: day) ?? addInitiateRiskCue(loadState)
        )
    }

    private static func addInitiateScheduleDay(_ day: [String: Any]) -> AddInitiateDraftScheduleDay {
        let loadState = stringValue(pairedValue(in: day, snake: "load_state", camel: "loadState")) ?? "within_budget"
        let items = arrayValue(day["items"])
            .compactMap(dictionaryValue)
            .map(addInitiateScheduleItem)
        return AddInitiateDraftScheduleDay(
            date: stringValue(day["date"]) ?? "未定日期",
            plannedMinutes: intValue(pairedValue(in: day, snake: "planned_minutes", camel: "plannedMinutes")) ?? 0,
            loadStateLabel: localizedAddInitiateLoadState(loadState),
            items: items
        )
    }

    private static func addInitiateScheduleItem(_ item: [String: Any]) -> AddInitiateDraftScheduleItem {
        let normalMode = dictionaryValue(pairedValue(in: item, snake: "normal_mode", camel: "normalMode")) ?? [:]
        let fallbackMode = dictionaryValue(pairedValue(in: item, snake: "fallback_mode", camel: "fallbackMode"))
        let id = stringValue(pairedValue(in: item, snake: "task_id", camel: "taskId"))
            ?? stringValue(normalMode["title"])
            ?? UUID().uuidString
        let title = stringValue(normalMode["title"])
            ?? stringValue(item["title"])
            ?? id
        let fallbackCue = fallbackMode.flatMap { fallback in
            let output = stringValue(pairedValue(in: fallback, snake: "fallback_output", camel: "fallbackOutput"))
                ?? stringValue(fallback["output"])
                ?? "可降级产出"
            if let riskEffect = stringValue(pairedValue(in: fallback, snake: "risk_effect", camel: "riskEffect")) {
                return "低能量：\(output)，风险：\(localizedAddInitiateToken(riskEffect))"
            }
            return "低能量：\(output)"
        }
        return AddInitiateDraftScheduleItem(
            id: id,
            title: title,
            minutes: intValue(pairedValue(in: item, snake: "scheduled_minutes", camel: "scheduledMinutes"))
                ?? intValue(normalMode["minutes"])
                ?? 0,
            fallbackCue: fallbackCue
        )
    }

    private static func addInitiateFallbackCue(in day: [String: Any]) -> String? {
        let items = arrayValue(day["items"]).compactMap(dictionaryValue)
        guard let fallback = items.lazy.compactMap({
            dictionaryValue(pairedValue(in: $0, snake: "fallback_mode", camel: "fallbackMode"))
        }).first else {
            return nil
        }
        let output = stringValue(pairedValue(in: fallback, snake: "fallback_output", camel: "fallbackOutput"))
            ?? stringValue(fallback["output"])
            ?? "可降级产出"
        if let riskEffect = stringValue(pairedValue(in: fallback, snake: "risk_effect", camel: "riskEffect")) {
            return "低能量：\(output)，风险：\(localizedAddInitiateToken(riskEffect))"
        }
        return "低能量：\(output)"
    }

    private static func addInitiateRiskCue(_ loadState: String) -> String? {
        switch loadState {
        case "over_capacity":
            return "风险：超出容量"
        case "over_budget":
            return "风险：接近上限"
        case "uses_buffer":
            return "使用缓冲"
        default:
            return nil
        }
    }

    private static func firstFallbackMetadata(in scheduledDays: [[String: Any]]) -> [String: Any]? {
        for day in scheduledDays {
            let items = arrayValue(day["items"]).compactMap(dictionaryValue)
            if let fallback = items.lazy.compactMap({
                dictionaryValue(pairedValue(in: $0, snake: "fallback_mode", camel: "fallbackMode"))
            }).first {
                return fallback
            }
        }
        return nil
    }

    private static func addInitiateAssumptions(from rawValue: Any?) -> [String] {
        if let strings = stringArrayValue(rawValue) {
            return strings
        }
        return arrayValue(rawValue).compactMap { item in
            if let text = stringValue(item) { return text }
            guard let dict = dictionaryValue(item) else { return nil }
            return stringValue(dict["assumption"])
                ?? stringValue(dict["value"])
                ?? stringValue(dict["field"])
        }
    }

    private static func addInitiateBufferSummary(from riskReport: [String: Any]) -> String? {
        let reserved = stringArrayValue(pairedValue(in: riskReport, snake: "buffer_days_reserved", camel: "bufferDaysReserved")) ?? []
        let eroded = boolValue(pairedValue(in: riskReport, snake: "buffer_erosion", camel: "bufferErosion")) ?? false
        switch (reserved.isEmpty, eroded) {
        case (false, true):
            return "预留缓冲：\(reserved.joined(separator: "、"))；缓冲被侵蚀"
        case (false, false):
            return "预留缓冲：\(reserved.joined(separator: "、"))"
        case (true, true):
            return "缓冲被侵蚀"
        case (true, false):
            return nil
        }
    }

    private static func addInitiateCapacityRiskFacts(from riskReport: [String: Any]) -> [String] {
        var facts: [String] = []
        if let minutes = intValue(pairedValue(in: riskReport, snake: "essential_work_minutes", camel: "essentialWorkMinutes")), minutes > 0 {
            facts.append("必要工作 \(minutes) 分钟")
        }
        if let minutes = intValue(pairedValue(in: riskReport, snake: "available_execution_capacity_minutes", camel: "availableExecutionCapacityMinutes")), minutes > 0 {
            facts.append("可用容量 \(minutes) 分钟")
        }
        if let minutes = intValue(pairedValue(in: riskReport, snake: "capacity_gap_minutes", camel: "capacityGapMinutes")), minutes > 0 {
            facts.append("容量缺口 \(minutes) 分钟")
        }
        if let dates = stringArrayValue(pairedValue(in: riskReport, snake: "overloaded_dates", camel: "overloadedDates")), !dates.isEmpty {
            facts.append("超载日期 \(dates.joined(separator: "、"))")
        }
        if let tasks = stringArrayValue(pairedValue(in: riskReport, snake: "expected_late_tasks", camel: "expectedLateTasks")), !tasks.isEmpty {
            facts.append("预计延期 \(tasks.joined(separator: "、"))")
        }
        if let conflicts = stringArrayValue(pairedValue(in: riskReport, snake: "existing_load_conflicts", camel: "existingLoadConflicts")), !conflicts.isEmpty {
            facts.append("已有负荷 \(conflicts.joined(separator: "、"))")
        }
        return facts
    }

    private static func hasLowCalibrationFact(in riskReport: [String: Any]) -> Bool {
        if boolValue(pairedValue(in: riskReport, snake: "low_calibration", camel: "lowCalibration")) == true {
            return true
        }
        let confidence = dictionaryValue(pairedValue(in: riskReport, snake: "estimate_confidence_summary", camel: "estimateConfidenceSummary")) ?? [:]
        return (intValue(confidence["low"]) ?? 0) > 0 ||
            (intValue(confidence["rough"]) ?? 0) > 0
    }

    private static func localizedAddInitiateRoleLabel(_ rawRole: String) -> String {
        switch rawRole {
        case "new_plan": return "新计划"
        case "attach_to_existing_plan": return "加入已有计划"
        case "reference_material": return "参考资料"
        case "later_resource": return "稍后处理"
        case "immediate_one_off", "one_off_action": return "一次性行动"
        default: return rawRole.isEmpty ? "未定" : rawRole
        }
    }

    private static func localizedAddInitiateLoadState(_ rawState: String) -> String {
        switch rawState {
        case "within_budget": return "预算内"
        case "over_budget": return "接近上限"
        case "over_capacity": return "超出容量"
        case "uses_buffer": return "使用缓冲"
        default: return localizedAddInitiateToken(rawState)
        }
    }

    private static func localizedAddInitiateOptionLabel(_ optionId: String) -> String {
        switch optionId {
        case "reduce_scope": return "缩小范围"
        case "lower_depth": return "降低深度"
        case "extend_deadline": return "调整截止日期"
        case "increase_capacity": return "增加可用时间"
        case "accept_crunch": return "接受紧凑安排"
        case "accept_buffer_risk": return "接受缓冲风险"
        case "accept_overload": return "接受超载日期"
        case "answer_one_question": return "回答一个问题"
        case "edit_estimates": return "调整估算"
        case "accept_rough_draft": return "接受粗略草案"
        case "accept_late_finish": return "接受延期完成"
        case "store_for_later": return "存为稍后处理"
        case "rebalance": return "重新平衡"
        default: return localizedAddInitiateToken(optionId)
        }
    }

    private static func localizedAddInitiateOptionEffect(_ effectType: String?) -> String {
        switch effectType {
        case "compiler_recompute_required":
            return "需要重新生成"
        case "storage":
            return "安静存储"
        case "needs_input":
            return "补一个信息"
        default:
            return "重新排期后再审阅"
        }
    }

    private static func localizedAddInitiateSourceDetailKey(_ key: String) -> String {
        switch key {
        case "kind", "type": return "类型"
        case "source_kind", "sourceKind": return "来源类型"
        case "title": return "标题"
        case "url": return "链接"
        default: return localizedAddInitiateToken(key)
        }
    }

    private static func localizedAddInitiateSourceDetailValue(_ value: String) -> String {
        switch value {
        case "github_repo": return "GitHub 仓库"
        case "text_goal": return "文本目标"
        case "note_snippet": return "笔记片段"
        case "url": return "链接"
        default: return localizedAddInitiateToken(value)
        }
    }

    private static func localizedAddInitiateToken(_ rawValue: String) -> String {
        switch rawValue {
        case "hard_deadline_pressure": return "硬截止日期压力"
        case "fits_with_risk": return "可行但有风险"
        case "preserves_scope": return "保留范围"
        case "scope_visible": return "范围可见"
        default:
            let words = rawValue
                .replacingOccurrences(of: "-", with: "_")
                .split(separator: "_")
                .map(String.init)
            guard !words.isEmpty else { return rawValue }
            let joined = words.joined(separator: " ")
            return joined.prefix(1).uppercased() + String(joined.dropFirst())
        }
    }

    private static func pairedValue(
        in dictionary: [String: AnyCodable],
        snake: String,
        camel: String
    ) -> Any? {
        dictionary[snake]?.value ?? dictionary[camel]?.value
    }

    private static func pairedValue(
        in dictionary: [String: Any],
        snake: String,
        camel: String
    ) -> Any? {
        dictionary[snake] ?? dictionary[camel]
    }

    private static func dictionaryValue(_ value: Any?) -> [String: Any]? {
        if let dict = value as? [String: Any] {
            return dict
        }
        if let dict = value as? [String: AnyCodable] {
            return dict.mapValues(\.value)
        }
        if value is NSNull {
            return nil
        }
        return nil
    }

    private static func arrayValue(_ value: Any?) -> [Any] {
        if let array = value as? [Any] {
            return array
        }
        if let array = value as? [AnyCodable] {
            return array.map(\.value)
        }
        return []
    }

    private static func stringArrayValue(_ value: Any?) -> [String]? {
        if let strings = value as? [String] {
            return strings
        }
        let strings = arrayValue(value).compactMap(stringValue)
        return strings.isEmpty ? nil : strings
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let value = value as? AnyCodable {
            return stringValue(value.value)
        }
        if let value = value as? String {
            return value
        }
        if let value = value as? Int {
            return String(value)
        }
        if let value = value as? Double {
            return String(value)
        }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? AnyCodable {
            return intValue(value.value)
        }
        if let value = value as? Int {
            return value
        }
        if let value = value as? Double {
            return Int(value)
        }
        if let value = value as? String {
            return Int(value)
        }
        return nil
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let value = value as? AnyCodable {
            return boolValue(value.value)
        }
        if let value = value as? Bool {
            return value
        }
        if let value = value as? String {
            return ["true", "yes", "1"].contains(value.lowercased())
        }
        return nil
    }

    private static func preserveAddInitiateReviewPackageIfNeeded(
        _ response: AddInitiateSessionResponse,
        current: AddInitiateSessionResponse?
    ) -> AddInitiateSessionResponse {
        guard response.reviewPackage == nil,
              let current,
              current.sessionId == response.sessionId,
              current.draftId == response.draftId,
              current.draftVersion == response.draftVersion,
              let reviewPackage = current.reviewPackage else {
            return response
        }

        return AddInitiateSessionResponse(
            sessionId: response.sessionId,
            clientRequestId: response.clientRequestId,
            intakeItemId: response.intakeItemId,
            draftId: response.draftId,
            draftVersion: response.draftVersion,
            stage: response.stage,
            reviewState: response.reviewState,
            recommendedRole: response.recommendedRole,
            confirmedRole: response.confirmedRole,
            confidence: response.confidence,
            reasonCodes: response.reasonCodes,
            nextAction: response.nextAction,
            createsActiveTasks: response.createsActiveTasks,
            resourceId: response.resourceId,
            error: response.error,
            clarificationQuestion: response.clarificationQuestion,
            existingPlanCandidates: response.existingPlanCandidates,
            attachmentModeSuggestion: response.attachmentModeSuggestion,
            canonicalRepoRole: response.canonicalRepoRole,
            reviewPackage: reviewPackage,
            activationResult: response.activationResult
        )
    }

    private func reconcileAddInitiateTaskEditDrafts(
        previous: AddInitiateSessionResponse?,
        next: AddInitiateSessionResponse
    ) {
        guard !addInitiateTaskEditDrafts.isEmpty else { return }
        guard previous?.sessionId == next.sessionId,
              previous?.draftId == next.draftId,
              previous?.draftVersion == next.draftVersion else {
            addInitiateTaskEditDrafts = [:]
            return
        }
    }

    private func isCurrentAddInitiateAnchorResponse(
        _ response: AddInitiateSessionResponse,
        requestSessionId: String,
        requestDraftId: Int,
        requestDraftVersion: Int?,
        operationGeneration: Int,
        requestSequence: Int
    ) -> Bool {
        guard addInitiateFlowGeneration == operationGeneration,
              addInitiateLocalFlowState != .cancelled,
              addInitiateAnchorRequestSequence == requestSequence,
              response.sessionId == requestSessionId,
              let current = addInitiateSession,
              current.sessionId == requestSessionId else {
            return false
        }
        if let currentDraftId = current.draftId, currentDraftId != requestDraftId {
            return false
        }
        if let responseDraftId = response.draftId, responseDraftId != requestDraftId {
            return false
        }
        if let requestDraftVersion,
           let currentDraftVersion = current.draftVersion,
           currentDraftVersion != requestDraftVersion {
            return false
        }
        if let currentDraftVersion = current.draftVersion,
           let responseDraftVersion = response.draftVersion,
           responseDraftVersion < currentDraftVersion {
            return false
        }
        if current.draftVersion != nil, response.draftVersion == nil {
            return false
        }
        return true
    }

    private func isCurrentAddInitiateOptionResponse(
        _ response: AddInitiateSessionResponse,
        requestSessionId: String,
        requestDraftId: Int,
        requestDraftVersion: Int,
        operationGeneration: Int,
        requestSequence: Int
    ) -> Bool {
        guard addInitiateFlowGeneration == operationGeneration,
              addInitiateLocalFlowState != .cancelled,
              addInitiateOptionRequestSequence == requestSequence,
              response.sessionId == requestSessionId,
              let current = addInitiateSession,
              current.sessionId == requestSessionId,
              current.draftId == requestDraftId,
              current.draftVersion == requestDraftVersion else {
            return false
        }

        switch response.reviewState {
        case .storedNonPlan, .materialAttached, .cancelled:
            return response.createsActiveTasks == false
        case .anchorReview, .needsInput, .compileFailed, .infeasibleReview, .draftReview, .activationFailed:
            guard response.draftId == requestDraftId,
                  let responseDraftVersion = response.draftVersion else {
                return false
            }
            return responseDraftVersion >= requestDraftVersion
        case .roleReview, .activated, .error:
            return false
        }
    }

    private func isCurrentAddInitiateDraftResponse(
        _ response: AddInitiateSessionResponse,
        requestSessionId: String,
        requestDraftId: Int,
        requestDraftVersion: Int,
        operationGeneration: Int,
        requestSequence: Int
    ) -> Bool {
        let sequenceMatches: Bool
        switch addInitiateLocalFlowState {
        case .optionEffectProgress:
            sequenceMatches = addInitiateOptionRequestSequence == requestSequence
        case .activationProgress:
            sequenceMatches = addInitiateActivationRequestSequence == requestSequence
        default:
            sequenceMatches = true
        }
        guard addInitiateFlowGeneration == operationGeneration,
              addInitiateLocalFlowState != .cancelled,
              sequenceMatches,
              response.sessionId == requestSessionId,
              response.draftId == requestDraftId,
              let current = addInitiateSession,
              current.sessionId == requestSessionId,
              current.draftId == requestDraftId,
              current.draftVersion == requestDraftVersion else {
            return false
        }
        if let responseDraftVersion = response.draftVersion,
           responseDraftVersion < requestDraftVersion {
            return false
        }
        if response.draftVersion == nil {
            return false
        }
        return true
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
        studySmartProposalMessageTrigger = nil
    }

    private func setStudySmartProposalMessage(
        _ message: String?,
        trigger: StudySmartProposalTrigger? = nil
    ) {
        studySmartProposalMessage = message
        studySmartProposalMessageTrigger = message == nil ? nil : trigger
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
            setStudySmartProposalMessage(response.message, trigger: response.trigger)
            isOffline = false
        } catch {
            setStudySmartProposalMessage("智能建议生成失败，请稍后重试。", trigger: .afterAdjustment)
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
        setStudySmartProposalMessage(nil)
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
