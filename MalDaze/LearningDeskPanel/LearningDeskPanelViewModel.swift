import Foundation

@MainActor
final class LearningDeskPanelViewModel: ObservableObject {
    enum PanelTab: String, CaseIterable, Identifiable {
        case today = "今日"
        case schedule = "日程"
        case projects = "项目"

        var id: String { rawValue }
    }

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded(LearningTodaySnapshot)
        case failed(String)
    }

    enum ScheduleLoadState: Equatable {
        case idle
        case loading
        case loaded(HermesScheduleRangeResponse)
        case failed(String)
    }

    enum StatusLoadState: Equatable {
        case idle
        case loading
        case loaded([HermesStatusProject])
        case failed(String)
    }

    struct MovePreview: Identifiable, Equatable {
        let id: String
        let taskId: String
        let taskTitle: String
        let newDate: String
        let changes: [HermesMoveChange]
    }

    struct DeleteCandidate: Identifiable, Equatable {
        let id: String
        let taskId: String
        let title: String
    }

    struct DeleteProjectCandidate: Identifiable, Equatable {
        let id: String
        let projectId: String
        let name: String
        let taskCount: Int?
    }

    struct DeadlineEditSession: Identifiable, Equatable {
        let id: UUID
        let projectId: String
        let projectName: String
        let currentDeadline: String
    }

    struct DeadlineRepackPreview: Equatable {
        let changeCount: Int
        let overflowCount: Int
    }

    struct CompleteDurationCandidate: Identifiable, Equatable {
        let id: String
        let taskId: String
        let title: String
        let plannedMinutes: Int
    }

    enum TodayGroupingMode: String, CaseIterable, Identifiable {
        case flat = "flat"
        case byProject = "byProject"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .flat: return "扁平"
            case .byProject: return "按项目"
            }
        }
    }

    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var scheduleLoadState: ScheduleLoadState = .idle
    @Published var scheduleMonth: String = LearningDeskPanelViewModel.currentMonthKey()
    @Published var selectedScheduleDate: String?
    @Published private(set) var statusLoadState: StatusLoadState = .idle
    @Published var selectedTab: PanelTab = .today
    @Published private(set) var busyTaskIds: Set<String> = []
    @Published private(set) var busyProjectIds: Set<String> = []
    @Published var movePreview: MovePreview?
    @Published var actionNotice: String?
    @Published var showInsertSheet = false
    @Published var deleteCandidate: DeleteCandidate?
    @Published var deleteProjectCandidate: DeleteProjectCandidate?
    @Published var deadlineEditSession: DeadlineEditSession?
    @Published private(set) var deadlineRepackPreview: DeadlineRepackPreview?
    @Published private(set) var insertProjectOptions: [LearningProjectOption] = []
    @Published var highlightTaskId: String?
    @Published var completeDurationCandidate: CompleteDurationCandidate?
    @Published var todayProjectFilter: String?
    @Published var scrollToProjectId: String?
    private let cli: any HermesScheduleCLI
    private var fileWatcher: LearningProjectsFileWatcher?
    private var fsDebounceTask: Task<Void, Never>?
    private var cachedStatus: [HermesStatusProject]?
    private var statusCacheValid = false
    private var scheduleCacheValid = false

    init(cli: any HermesScheduleCLI = ProcessHermesScheduleCLI()) {
        self.cli = cli
    }

    var todayDateISO: String {
        if case .loaded(let snapshot) = loadState {
            return snapshot.response.date
        }
        return Self.isoDate(Date())
    }

    func loadToday() async {
        loadState = .loading
        actionNotice = nil
        do {
            try await cli.runRollover()
            let today = try await cli.fetchToday()
            loadState = .loaded(LearningTodaySnapshot.make(from: today))
            await refreshInsertProjectOptions()
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func prepareInsertSheet() async {
        await refreshInsertProjectOptions()
        showInsertSheet = true
    }

    private func refreshInsertProjectOptions() async {
        do {
            let status = try await cli.fetchStatus()
            insertProjectOptions = HermesActiveProjects.options(from: status)
        } catch {
            if case .loaded(let snapshot) = loadState {
                insertProjectOptions = snapshot.projectOptions
            }
        }
    }

    func refreshTodayOnly() async {
        do {
            let today = try await cli.fetchToday()
            loadState = .loaded(LearningTodaySnapshot.make(from: today))
        } catch {
            actionNotice = error.localizedDescription
        }
    }

    func loadScheduleIfNeeded() async {
        switch scheduleLoadState {
        case .idle:
            await loadSchedule(force: false)
        case .failed:
            await loadSchedule(force: true)
        default:
            break
        }
    }

    func loadSchedule(force: Bool) async {
        if case .loading = scheduleLoadState, !force { return }
        if !force, scheduleCacheValid, case .loaded = scheduleLoadState { return }
        scheduleLoadState = .loading
        do {
            let response = try await cli.scheduleRange(month: scheduleMonth, fromDate: nil, toDate: nil)
            scheduleLoadState = .loaded(response)
            scheduleCacheValid = true
        } catch {
            scheduleLoadState = .failed(error.localizedDescription)
            scheduleCacheValid = false
        }
    }

    func shiftScheduleMonth(by offset: Int) async {
        guard let shifted = Self.shiftMonthKey(scheduleMonth, by: offset) else { return }
        scheduleMonth = shifted
        selectedScheduleDate = nil
        await loadSchedule(force: true)
    }

    func jumpToTodayInSchedule() async {
        let today = Self.isoDate(Date())
        let month = Self.currentMonthKey()
        if scheduleMonth != month {
            scheduleMonth = month
            await loadSchedule(force: true)
        }
        selectedScheduleDate = today
    }

    var scheduleMonthTitle: String {
        Self.formatMonthTitle(scheduleMonth)
    }

    private func invalidateScheduleCache() {
        scheduleCacheValid = false
    }

    private func refreshScheduleAfterMutation() async {
        invalidateScheduleCache()
        if selectedTab == .schedule {
            await loadSchedule(force: true)
        }
    }

    func loadStatusIfNeeded() async {
        switch statusLoadState {
        case .idle, .failed:
            await loadStatus(force: false)
        case .loaded:
            if !statusCacheValid {
                await loadStatus(force: true)
            }
        default:
            break
        }
    }

    func loadStatus(force: Bool) async {
        if case .loading = statusLoadState, !force { return }
        if !force, statusCacheValid, let cachedStatus {
            statusLoadState = .loaded(cachedStatus)
            return
        }
        statusLoadState = .loading
        do {
            let status = try await cli.fetchStatus()
            storeStatusCache(status)
            statusLoadState = .loaded(cachedStatus ?? [])
        } catch {
            statusLoadState = .failed(error.localizedDescription)
        }
    }

    func onTabChanged() async {
        switch selectedTab {
        case .schedule:
            switch scheduleLoadState {
            case .idle:
                await loadSchedule(force: false)
            case .failed:
                await loadSchedule(force: true)
            default:
                if !scheduleCacheValid {
                    await loadSchedule(force: true)
                }
            }
        case .projects:
            await loadStatusIfNeeded()
        case .today:
            break
        }
    }

    func refreshCurrentTab(force: Bool = true) async {
        switch selectedTab {
        case .today:
            await loadToday()
        case .schedule:
            await loadSchedule(force: force)
        case .projects:
            await loadStatus(force: force)
        }
    }

    func complete(taskId: String, actualMinutes: Int? = nil) async {
        busyTaskIds.insert(taskId)
        defer { busyTaskIds.remove(taskId) }
        do {
            let result = try await cli.complete(taskId: taskId, actualMinutes: actualMinutes)
            guard result.succeeded else {
                actionNotice = result.error ?? "完成失败"
                return
            }
            completeDurationCandidate = nil
            await loadToday()
            await refreshStatusAfterMutation()
            await refreshScheduleAfterMutation()
        } catch {
            actionNotice = error.localizedDescription
        }
    }

    func beginCompleteWithDuration(for row: LearningTaskDisplayRow) {
        completeDurationCandidate = CompleteDurationCandidate(
            id: row.pending.taskId,
            taskId: row.pending.taskId,
            title: row.pending.title,
            plannedMinutes: row.pending.durationMinutes
        )
    }

    func cancelCompleteWithDuration() {
        completeDurationCandidate = nil
    }

    func confirmCompleteWithDuration(minutes: Int) async {
        guard let candidate = completeDurationCandidate else { return }
        await complete(taskId: candidate.taskId, actualMinutes: minutes)
    }

    func focusRolloverTask(_ taskId: String) {
        highlightTaskId = taskId
    }

    func requestMove(taskId: String, taskTitle: String, newDate: String) async {
        busyTaskIds.insert(taskId)
        defer { busyTaskIds.remove(taskId) }
        do {
            let preview = try await cli.move(taskId: taskId, newDate: newDate, dryRun: true)
            if let error = preview.error {
                actionNotice = error
                return
            }
            movePreview = MovePreview(
                id: taskId,
                taskId: taskId,
                taskTitle: taskTitle,
                newDate: newDate,
                changes: preview.changes
            )
        } catch {
            actionNotice = error.localizedDescription
        }
    }

    func confirmMove() async {
        guard let preview = movePreview else { return }
        let taskId = preview.taskId
        busyTaskIds.insert(taskId)
        defer { busyTaskIds.remove(taskId) }
        do {
            let result = try await cli.move(taskId: taskId, newDate: preview.newDate, dryRun: false)
            movePreview = nil
            if let error = result.error {
                actionNotice = error
                return
            }
            await loadToday()
            await refreshStatusAfterMutation()
            await refreshScheduleAfterMutation()
        } catch {
            actionNotice = error.localizedDescription
        }
    }

    func cancelMovePreview() {
        movePreview = nil
    }

    func insertTask(projectId: String, title: String, duration: Int, date: String) async {
        actionNotice = nil
        do {
            let result = try await cli.insert(
                projectId: projectId,
                title: title,
                duration: duration,
                date: date
            )
            showInsertSheet = false
            guard result.succeeded else {
                actionNotice = result.error ?? "添加失败"
                return
            }
            await loadToday()
            await refreshStatusAfterMutation()
            await refreshScheduleAfterMutation()
        } catch {
            actionNotice = error.localizedDescription
        }
    }

    func confirmDelete() async {
        guard let candidate = deleteCandidate else { return }
        let taskId = candidate.taskId
        deleteCandidate = nil
        busyTaskIds.insert(taskId)
        defer { busyTaskIds.remove(taskId) }
        do {
            let result = try await cli.remove(taskId: taskId)
            guard result.succeeded else {
                actionNotice = result.error ?? "删除失败"
                return
            }
            await loadToday()
            await refreshStatusAfterMutation()
            await refreshScheduleAfterMutation()
        } catch {
            actionNotice = error.localizedDescription
        }
    }

    func beginDeleteProject(_ project: HermesStatusProject) {
        deleteProjectCandidate = DeleteProjectCandidate(
            id: project.projectId,
            projectId: project.projectId,
            name: project.name,
            taskCount: project.totalTaskCount
        )
    }

    func confirmDeleteProject(_ candidate: DeleteProjectCandidate) async {
        deleteProjectCandidate = nil
        let projectId = candidate.projectId
        busyProjectIds.insert(projectId)
        defer { busyProjectIds.remove(projectId) }
        do {
            let result = try await cli.deleteProject(projectId: projectId)
            guard result.succeeded else {
                actionNotice = result.error ?? "删除项目失败"
                return
            }
            await loadToday()
            await refreshStatusAfterMutation()
            await refreshScheduleAfterMutation()
            actionNotice = "已删除项目「\(candidate.name)」"
        } catch {
            actionNotice = error.localizedDescription
        }
    }

    func review(taskId: String, passed: Bool) async {
        busyTaskIds.insert(taskId)
        defer { busyTaskIds.remove(taskId) }
        do {
            let result = try await cli.review(
                taskId: taskId,
                result: passed ? "passed" : "failed"
            )
            guard result.succeeded else {
                actionNotice = result.error ?? "复习结果提交失败"
                return
            }
            await loadToday()
            await refreshStatusAfterMutation()
            await refreshScheduleAfterMutation()
        } catch {
            actionNotice = error.localizedDescription
        }
    }

    func beginDeadlineEdit(project: HermesStatusProject) {
        deadlineRepackPreview = nil
        deadlineEditSession = DeadlineEditSession(
            id: UUID(),
            projectId: project.projectId,
            projectName: project.name,
            currentDeadline: project.deadline ?? ""
        )
        let initialDeadline = project.deadline ?? ""
        if !initialDeadline.isEmpty {
            Task { await previewDeadlineRepack(projectId: project.projectId, deadline: initialDeadline) }
        }
    }

    func previewDeadlineRepack(projectId: String, deadline: String) async {
        guard deadlineEditSession?.projectId == projectId else { return }
        do {
            let result = try await cli.setDeadline(projectId: projectId, deadline: deadline, dryRun: true)
            guard result.succeeded else { return }
            deadlineRepackPreview = DeadlineRepackPreview(
                changeCount: result.changes?.count ?? 0,
                overflowCount: result.overflowCount ?? 0
            )
        } catch {
            deadlineRepackPreview = nil
        }
    }

    func confirmDeadlineEdit(newDeadline: String) async {
        guard let session = deadlineEditSession else { return }
        let projectId = session.projectId
        let preview = deadlineRepackPreview
        let hasRepackWork = (preview?.changeCount ?? 0) > 0 || (preview?.overflowCount ?? 0) > 0
        guard newDeadline != session.currentDeadline || hasRepackWork else {
            deadlineEditSession = nil
            deadlineRepackPreview = nil
            return
        }
        deadlineEditSession = nil
        deadlineRepackPreview = nil
        busyProjectIds.insert(projectId)
        defer { busyProjectIds.remove(projectId) }
        do {
            let result = try await cli.setDeadline(projectId: projectId, deadline: newDeadline, dryRun: false)
            guard result.succeeded else {
                actionNotice = result.error ?? "修改截止日失败"
                return
            }
            actionNotice = deadlineEditNotice(from: result)
            await refreshStatusAfterMutation()
            await refreshTodayOnly()
            await refreshScheduleAfterMutation()
        } catch {
            actionNotice = error.localizedDescription
        }
    }

    func cancelDeadlineEdit() {
        deadlineEditSession = nil
        deadlineRepackPreview = nil
    }

    private func deadlineEditNotice(from result: HermesSetDeadlineResponse) -> String {
        var parts: [String] = []
        let moved = result.changes?.count ?? 0
        if result.repacked == true, moved > 0 {
            if result.repackMode == "spread" {
                parts.append("已摊开重排 \(moved) 节课")
            } else {
                parts.append("已重排 \(moved) 节课")
            }
        } else if result.repacked == true {
            parts.append("截止日已更新")
        } else {
            parts.append("截止日已更新")
        }
        if let overflow = result.overflowCount, overflow > 0 {
            parts.append("\(overflow) 节课未能排进新截止日（仍保留在原日期）")
        }
        return parts.joined(separator: "；")
    }

    func jumpToToday(projectId: String) {
        selectedTab = .today
        if case .loaded(let snapshot) = loadState {
            if let row = snapshot.rows.first(where: { $0.pending.projectId == projectId }) {
                highlightTaskId = row.pending.taskId
            }
        }
    }

    func filterTodayToProject(_ projectId: String) {
        todayProjectFilter = projectId
        actionNotice = nil
    }

    func clearTodayProjectFilter() {
        todayProjectFilter = nil
    }

    func handleWarningTap(_ warning: HermesProjectWarning) {
        guard case .loaded(let snapshot) = loadState else { return }
        if let row = snapshot.rows.first(where: { $0.pending.projectId == warning.projectId }) {
            highlightTaskId = row.pending.taskId
            actionNotice = nil
        } else {
            actionNotice = "今日无该项目任务"
        }
    }

    func openScheduleTomorrow() async {
        let tomorrow = Self.tomorrowISO()
        if let month = Self.monthKey(fromISO: tomorrow) {
            scheduleMonth = month
        }
        selectedScheduleDate = tomorrow
        selectedTab = .schedule
        await loadSchedule(force: true)
    }

    func jumpToProjectTab(projectId: String) async {
        scrollToProjectId = projectId
        selectedTab = .projects
        await loadStatusIfNeeded()
    }

    func beginRepackForProject(projectId: String) async {
        await loadStatusIfNeeded()
        guard let project = cachedStatus?.first(where: { $0.projectId == projectId }) else {
            actionNotice = "找不到项目"
            return
        }
        beginDeadlineEdit(project: project)
    }

    func clearHighlight() {
        highlightTaskId = nil
    }

    static func monthKey(fromISO iso: String) -> String? {
        let parts = iso.split(separator: "-")
        guard parts.count >= 2 else { return nil }
        return "\(parts[0])-\(parts[1])"
    }

    func startWatching() {
        guard fileWatcher == nil else { return }
        let watcher = LearningProjectsFileWatcher(fileURL: cli.projectsFileURL) { [weak self] in
            Task { @MainActor in
                self?.scheduleDebouncedRefresh()
            }
        }
        fileWatcher = watcher
        watcher.start()
    }

    func stopWatching() {
        fsDebounceTask?.cancel()
        fsDebounceTask = nil
        fileWatcher?.stop()
        fileWatcher = nil
    }

    func scheduleDebouncedRefresh() {
        fsDebounceTask?.cancel()
        fsDebounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            invalidateStatusCache()
            invalidateScheduleCache()
            switch selectedTab {
            case .today:
                await refreshTodayOnly()
            case .schedule:
                await loadSchedule(force: true)
            case .projects:
                await loadStatus(force: true)
            }
        }
    }

    private func storeStatusCache(_ status: [HermesStatusProject]) {
        cachedStatus = LearningProjectStatusOrdering.sorted(status)
        statusCacheValid = true
    }

    private func invalidateStatusCache() {
        statusCacheValid = false
    }

    private func refreshStatusAfterMutation() async {
        invalidateStatusCache()
        await loadStatus(force: true)
    }

    static func tomorrowISO() -> String {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()
        return Self.isoDate(tomorrow)
    }

    static func isoDate(_ date: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func currentMonthKey(from date: Date = Date()) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        return String(format: "%04d-%02d", y, m)
    }

    static func formatMonthTitle(_ monthKey: String) -> String {
        let parts = monthKey.split(separator: "-")
        guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]) else {
            return monthKey
        }
        return "\(y)年\(m)月"
    }

    static func shiftMonthKey(_ monthKey: String, by offset: Int) -> String? {
        let parts = monthKey.split(separator: "-")
        guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        var comp = DateComponents(year: y, month: m, day: 1)
        comp.month = m + offset
        guard let date = Calendar.current.date(from: comp) else { return nil }
        return currentMonthKey(from: date)
    }
}
