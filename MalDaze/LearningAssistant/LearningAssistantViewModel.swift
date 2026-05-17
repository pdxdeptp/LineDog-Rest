import Combine
import Foundation

private final class NotificationObserverBag: @unchecked Sendable {
    private let lock = NSLock()
    private var observers: [NSObjectProtocol] = []

    func add(_ observer: NSObjectProtocol) {
        lock.lock()
        observers.append(observer)
        lock.unlock()
    }

    func removeAll() {
        lock.lock()
        let observers = observers
        self.observers.removeAll()
        lock.unlock()

        observers.forEach(NotificationCenter.default.removeObserver)
    }

    deinit {
        removeAll()
    }
}

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

    @Published var ingestionDraft: IngestionDraftDetail? = nil
    @Published var ingestionThreadId: String?            = nil
    @Published var selectedOption: String                = "B"

    @Published var todayTotalMinutes: Int  = 0
    @Published var todayHighlights: String = ""

    @Published var isFetchingBriefing = false
    @Published var isSendingMessage   = false
    @Published var isIngesting        = false
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
    private let shouldRequestBackendStartup: Bool
    private let notificationObservers = NotificationObserverBag()
    private var analysisTask: Task<Void, Never>?
    private var rescheduleDebounceTask: Task<Void, Never>?

    // MARK: - Init

    init(
        api: any AssistantAPIClientProtocol = AssistantAPIClient.shared,
        orderStore: UserDefaults = .standard,
        todayProvider: @escaping () -> Date = Date.init,
        autoLoadWhenReady: Bool = true,
        backendLifecycle: AppBackendLifecycleManaging = BackendProcessManager.shared
    ) {
        self.api = api
        self.orderStore = orderStore
        self.todayProvider = todayProvider
        self.backendLifecycle = backendLifecycle
        self.shouldRequestBackendStartup = autoLoadWhenReady
        let readyObserver = NotificationCenter.default.addObserver(
            forName: .backendDidBecomeReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.shouldRequestBackendStartup else { return }
                self.isConnecting = false
                await self.fetchDashboard()
            }
        }
        notificationObservers.add(readyObserver)

        let unavailableObserver = NotificationCenter.default.addObserver(
            forName: .backendDidBecomeUnavailable,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.shouldRequestBackendStartup else { return }
                self.clearDashboardContent()
                self.isConnecting = false
                self.isOffline = true
            }
        }
        notificationObservers.add(unavailableObserver)

        // 若通知在订阅前已发出（后端早于视图初始化就绪），直接开始 fetch。
        if autoLoadWhenReady {
            requestBackendStartupIfNeeded()
            if backendLifecycle.isReady {
                isConnecting = false
                Task { await fetchDashboard() }
            }
        }
    }

    deinit {
        notificationObservers.removeAll()
    }

    // MARK: - Briefing

    var dashboardState: AssistantDashboardState {
        let kind: AssistantDashboardKind
        let primaryAction: AssistantDashboardPrimaryAction?

        if isConnecting {
            kind = .connecting
            primaryAction = nil
        } else if isOffline {
            kind = .offline
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
        requestBackendStartupIfNeeded()
        if shouldRequestBackendStartup, !backendLifecycle.isReady {
            isConnecting = true
            isOffline = false
            return
        }

        isFetchingBriefing = true
        defer { isFetchingBriefing = false }
        do {
            async let briefingRequest = api.fetchTodayBriefing()
            async let resourcesRequest = api.fetchResources()
            let (briefing, fetchedResources) = try await (briefingRequest, resourcesRequest)
            apply(briefing: briefing, resources: fetchedResources)
            isOffline = false
            isConnecting = false
        } catch {
            clearDashboardContent()
            isOffline = true
            isConnecting = false
        }
    }

    private func requestBackendStartupIfNeeded() {
        guard shouldRequestBackendStartup else { return }
        guard !backendLifecycle.isReady, !backendLifecycle.isStarting else { return }
        backendLifecycle.startIfNeeded()
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
            isOffline = false
        } catch {
            isOffline = true
        }
    }

    // MARK: - Task Completion

    func completeTask(_ task: AssistantTask) async {
        do {
            try await api.completeTask(id: task.id, actualMinutes: nil)
            // Optimistic update: mark locally while re-fetching
            await fetchDashboard()
        } catch {
            isOffline = true
        }
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
    }

    private func clearDashboardContent() {
        tasks = []
        visibleTodayTasks = []
        resources = []
        todayTotalMinutes = 0
        todayHighlights = ""
        expandedTaskIDs = []
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
}
