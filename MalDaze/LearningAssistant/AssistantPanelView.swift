import SwiftUI

/// 学习助手中间栏：后端就绪后默认显示首页 dashboard，底部固定导航进入工具页。
struct AssistantPanelView: View {
    @StateObject private var vm: LearningAssistantViewModel
    @State private var todayMoveDateDrafts: [Int: String] = [:]

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
            if vm.isFetchingBriefing || (vm.isConnecting && vm.hasLoadedDashboardContent) {
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
            todayView
        case .projectOverview:
            ProjectOverviewView(vm: vm)
        case .calendar:
            StudyCalendarLoadView(vm: vm)
        case .addResource:
            StudyPlanIntakeView(vm: vm)
        case .resourceProgress:
            resourcesPanel
        case .adjustPlan:
            StudyPlanAdjustmentView(vm: vm)
        case .settings:
            StudySettingsView(vm: vm)
        }
    }

    // MARK: - Dashboard

    private var todayView: some View {
        homeDashboard
    }

    private var homeDashboard: some View {
        List {
            dashboardSummarySection
            todayV2Facts
            studySmartDashboardSection

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

    @ViewBuilder
    private var todayV2Facts: some View {
        if let todayView = vm.studyTodayView {
            VStack(alignment: .leading, spacing: 10) {
                Text("今日学习")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    summaryMetric(value: todayView.date, label: "v2 日期")
                    summaryMetric(value: "\(studyProjectCount(in: todayView))", label: "项目")
                    summaryMetric(value: "\(studyUnitCount(in: todayView))", label: "单元")
                }
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var studySmartDashboardSection: some View {
        if vm.isStudySmartModeEnabled,
           vm.studySmartMorningBriefing != nil ||
            !dashboardVisibleStudySmartOptions.isEmpty ||
            dashboardVisibleStudySmartMessage != nil {
            VStack(alignment: .leading, spacing: 10) {
                if let briefing = vm.studySmartMorningBriefing {
                    Label("智能晨间简报", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(briefing.summary)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)

                    if !briefing.issues.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(briefing.issues.enumerated()), id: \.offset) { _, issue in
                                Text(studySmartIssueText(issue))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                StudySmartOptionsStrip(vm: vm, placement: .dashboard)
            }
            .padding(.vertical, 8)
        }
    }

    private var dashboardVisibleStudySmartOptions: [StudySmartProposalOption] {
        StudySmartOptionsFilter.visibleOptions(vm.studySmartProposalOptions, placement: .dashboard)
    }

    private var dashboardVisibleStudySmartMessage: String? {
        StudySmartOptionsFilter.visibleMessage(
            vm.studySmartProposalMessage,
            messageTrigger: vm.studySmartProposalMessageTrigger,
            options: vm.studySmartProposalOptions,
            placement: .dashboard
        )
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

    private func studyProjectCount(in todayView: StudyTodayView) -> Int {
        Set(todayView.tasks.compactMap(\.projectId)).count
    }

    private func studyUnitCount(in todayView: StudyTodayView) -> Int {
        Set(todayView.tasks.compactMap(\.unitId)).count
    }

    private func studySmartIssueText(_ issue: StudySmartBriefingIssue) -> String {
        var parts = [issue.type]
        if let projectId = issue.projectId {
            parts.append("项目 \(projectId)")
        }
        if let taskId = issue.taskId {
            parts.append("任务 \(taskId)")
        }
        if let rolledDayCount = issue.rolledDayCount {
            parts.append("已滚动 \(rolledDayCount) 天")
        }
        if let date = issue.date {
            parts.append(date)
        }
        return parts.joined(separator: " · ")
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
                VStack(alignment: .leading, spacing: 6) {
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

                    if let studyTask = todayStudyTask(for: task.id) {
                        todayAdjustmentControls(for: studyTask)
                    }
                }
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

    private func todayStudyTask(for id: Int) -> StudyViewTask? {
        vm.studyTodayView?.tasks.first { $0.id == id }
    }

    private func todayAdjustmentControls(for task: StudyViewTask) -> some View {
        HStack(spacing: 8) {
            if task.showRolledBadge {
                Label("已滚动 \(task.rolledDayCount) 天", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .help("该任务由之前日期滚动而来")
            } else if task.rolledDayCount > 0 {
                Text("滚动 \(task.rolledDayCount) 天")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            TextField("yyyy-MM-dd", text: todayMoveDateBinding(for: task))
                .textFieldStyle(.roundedBorder)
                .frame(width: 104)

            Button {
                Task { await vm.moveStudyTask(id: task.id, scheduledDate: todayMoveDate(for: task)) }
            } label: {
                Label("移动", systemImage: "calendar.badge.clock")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .disabled(!todayMoveDateChanged(for: task) || todayMoveDate(for: task).isEmpty || vm.isAdjustingStudyPlan)
            .help("移动任务日期")
        }
        .padding(.leading, 28)
    }

    private func todayMoveDateBinding(for task: StudyViewTask) -> Binding<String> {
        Binding(
            get: { todayMoveDateDrafts[task.id] ?? vm.studyTodayView?.date ?? "" },
            set: { todayMoveDateDrafts[task.id] = $0 }
        )
    }

    private func todayMoveDate(for task: StudyViewTask) -> String {
        (todayMoveDateDrafts[task.id] ?? vm.studyTodayView?.date ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func todayMoveDateChanged(for task: StudyViewTask) -> Bool {
        guard let draft = todayMoveDateDrafts[task.id] else { return false }
        return draft.trimmingCharacters(in: .whitespacesAndNewlines) != (vm.studyTodayView?.date ?? "")
    }

    // MARK: - Resources

    private var resourcesPanel: some View {
        List {
            if let error = vm.resourceManagementError {
                resourceManagementErrorBanner(error)
            }

            if vm.resources.isEmpty {
                Text("暂无资料记录")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(vm.resources) { resource in
                    ResourceProgressView(
                        resource: resource,
                        isManagementInFlight: vm.isManagingResource(resource),
                        onAdjustPlan: {
                            vm.seedAdjustPlan(for: resource)
                        },
                        onComplete: {
                            await vm.completeResource(resource)
                        },
                        onArchive: {
                            await vm.archiveResource(resource)
                        }
                    )
                }
            }
        }
        .listStyle(.plain)
        .task { await vm.fetchResources() }
    }

    private func resourceManagementErrorBanner(_ error: String) -> some View {
        HStack(spacing: 8) {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button {
                vm.clearResourceManagementError()
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .help("清除错误")
        }
        .padding(.vertical, 6)
    }

    // MARK: - Bottom Navigation

    private var bottomNavigationBar: some View {
        HStack(spacing: 0) {
            bottomNavigationButton(.home)
            bottomNavigationButton(.projectOverview)
            bottomNavigationButton(.calendar)
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

@ViewBuilder
private func defaultModeSilentRedStateFact<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
}

private struct StudyCalendarLoadView: View {
    @ObservedObject var vm: LearningAssistantViewModel
    @State private var addProjectIdText = ""
    @State private var addTaskTitle = ""
    @State private var addTargetMinutes = 30
    @State private var addScheduledDate = ""
    @State private var deleteTaskIdText = ""
    @State private var moveTaskIdText = ""
    @State private var moveScheduledDate = ""

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 8) {
                Text("日历负荷")
                    .font(.headline)
                Text("显示休息日、可用容量和超载事实；下方提供紧凑的任务增删移动控件。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)

            calendarAdjustmentControls

            if vm.isFetchingStudyCalendarLoad {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在加载日历负荷")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = vm.studyCalendarLoadError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let load = vm.studyCalendarLoad {
                Section {
                    Text("\(load.startDate) 到 \(load.endDate) · 每日容量 \(load.dailyCapacityMinutes) 分钟")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(load.days, id: \.date) { day in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(day.date)
                                    .font(.callout.weight(.semibold))
                                Spacer()
                                if day.overCapacity {
                                    defaultModeSilentRedStateFact {
                                        Text("超出容量")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.red)
                                    }
                                }
                                if day.restDay {
                                    defaultModeSilentRedStateFact {
                                        Label("休息日", systemImage: "moon.zzz")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            HStack(spacing: 12) {
                                calendarLoadFact(value: "\(day.scheduledTaskCount)", label: "任务")
                                calendarLoadFact(value: "\(day.totalTargetMinutes)", label: "分钟")
                                calendarLoadFact(value: "\(day.completedTaskCount)", label: "已完成")
                                calendarLoadFact(value: "\(day.availableCapacityMinutes)", label: "可用容量")
                            }
                        }
                        .padding(.vertical, 6)
                    }
                } header: {
                    Text("日负荷")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            } else if !vm.isFetchingStudyCalendarLoad {
                Text("暂无日历负荷")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .listStyle(.plain)
        .task { await fetchDefaultWindowIfNeeded() }
    }

    private var calendarAdjustmentControls: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                calendarAddTaskControls
                calendarDeleteTaskControls
                calendarMoveTaskControls
            }
            .padding(.vertical, 6)
        }
    }

    private var calendarAddTaskControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("添加任务")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("项目 ID", text: $addProjectIdText)
                .textFieldStyle(.roundedBorder)

            TextField("任务标题", text: $addTaskTitle)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Stepper(value: $addTargetMinutes, in: 5...600, step: 5) {
                    Text("\(addTargetMinutes) 分钟")
                        .font(.caption.monospacedDigit())
                }

                TextField("yyyy-MM-dd", text: $addScheduledDate)
                    .textFieldStyle(.roundedBorder)

                Button {
                    addTask()
                } label: {
                    Label("添加任务", systemImage: "plus.circle")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(!canAddTask || vm.isAdjustingStudyPlan)
                .help("添加任务")
            }
        }
    }

    private var calendarDeleteTaskControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("删除任务")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("任务 ID", text: $deleteTaskIdText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    deleteTask()
                } label: {
                    Label("删除任务", systemImage: "trash")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(deleteTaskId == nil || vm.isAdjustingStudyPlan)
                .help("删除任务")
            }
        }
    }

    private var calendarMoveTaskControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("移动任务")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("任务 ID", text: $moveTaskIdText)
                    .textFieldStyle(.roundedBorder)

                TextField("yyyy-MM-dd", text: $moveScheduledDate)
                    .textFieldStyle(.roundedBorder)

                Button {
                    moveTask()
                } label: {
                    Label("移动任务", systemImage: "calendar.badge.clock")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(moveTaskId == nil || trimmedMoveScheduledDate.isEmpty || vm.isAdjustingStudyPlan)
                .help("移动任务")
            }
        }
    }

    private func fetchDefaultWindowIfNeeded() async {
        guard vm.studyCalendarLoad == nil, !vm.isFetchingStudyCalendarLoad else { return }
        let calendar = Calendar.current
        let startDate = Date()
        let endDate = calendar.date(byAdding: .day, value: Self.defaultCalendarWindowDayOffset, to: startDate) ?? startDate
        let start = Self.dateFormatter.string(from: startDate)
        let end = Self.dateFormatter.string(from: endDate)
        await vm.fetchStudyCalendarLoad(start: start, end: end)
    }

    private func calendarLoadFact(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.callout.monospacedDigit().weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let defaultCalendarWindowDayOffset = 27

    private var canAddTask: Bool {
        addProjectId != nil &&
            !addTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !addScheduledDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var addProjectId: Int? {
        Int(addProjectIdText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var deleteTaskId: Int? {
        Int(deleteTaskIdText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var moveTaskId: Int? {
        Int(moveTaskIdText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var trimmedMoveScheduledDate: String {
        moveScheduledDate.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addTask() {
        guard let projectId = addProjectId else { return }
        let title = addTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let scheduledDate = addScheduledDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !scheduledDate.isEmpty else { return }
        Task {
            await vm.insertStudyProjectTask(
                projectId: projectId,
                title: title,
                targetMinutes: addTargetMinutes,
                scheduledDate: scheduledDate
            )
        }
    }

    private func deleteTask() {
        guard let taskId = deleteTaskId else { return }
        Task { await vm.deleteStudyTask(id: taskId) }
    }

    private func moveTask() {
        guard let taskId = moveTaskId, !trimmedMoveScheduledDate.isEmpty else { return }
        Task { await vm.moveStudyTask(id: taskId, scheduledDate: trimmedMoveScheduledDate) }
    }
}

private struct ProjectOverviewView: View {
    @ObservedObject var vm: LearningAssistantViewModel
    @State private var deadlineDrafts: [Int: String] = [:]

    var body: some View {
        List {
            if let overview = vm.studyProjectOverview {
                projectSection(title: "进行中项目", projects: overview.activeProjects, isCompletedHistory: false)
                projectSection(title: "完成历史", projects: overview.completedProjects, isCompletedHistory: true)
            } else {
                Text("暂无项目总览")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .listStyle(.plain)
        .refreshable { await vm.fetchDashboard() }
    }

    private func projectSection(title: String, projects: [StudyProjectSummary], isCompletedHistory: Bool) -> some View {
        Section {
            if projects.isEmpty {
                Text("暂无记录")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(projects) { project in
                    projectRow(project, isCompletedHistory: isCompletedHistory)
                }
            }
        } header: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func projectRow(_ project: StudyProjectSummary, isCompletedHistory: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(project.title)
                    .font(.callout.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(projectStatusLabel(for: project.status))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: clampedProgressRatio(for: project))

            Text("\(project.completedUnits)/\(project.totalUnits) 单元 · \(Int(clampedProgressRatio(for: project) * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                projectFact(value: "\(project.targetMinutes)", label: "目标分钟")
                projectFact(value: "\(project.actualMinutes)", label: "实际分钟")
                projectFact(value: projectDeadlineLabel(for: project.deadline), label: "截止")
            }

            if project.expectedLate {
                defaultModeSilentRedStateFact {
                    Label("预计晚于截止日期", systemImage: "exclamationmark.triangle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .help("事实状态：当前计划预计晚于项目截止日期")
                }
            }

            if !isCompletedHistory {
                HStack(spacing: 8) {
                    TextField("yyyy-MM-dd", text: deadlineBinding(for: project))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 116)
                    Button {
                        Task { await vm.updateStudyProjectDeadline(projectId: project.id, deadline: deadlineDraft(for: project)) }
                    } label: {
                        Label("更新截止日期", systemImage: "calendar")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .disabled(deadlineDraft(for: project).isEmpty || vm.isAdjustingStudyPlan)
                    .help("更新截止日期")
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func clampedProgressRatio(for project: StudyProjectSummary) -> Double {
        let ratio = project.progressRatio
        guard ratio.isFinite else { return 0 }
        return min(max(ratio, 0), 1)
    }

    private func projectStatusLabel(for status: String) -> String {
        switch status.lowercased() {
        case "active": return "进行中"
        case "completed": return "已完成"
        default: return status.isEmpty ? "未知状态" : status
        }
    }

    private func projectDeadlineLabel(for deadline: String?) -> String {
        return deadline ?? "无截止日期"
    }

    private func projectFact(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deadlineBinding(for project: StudyProjectSummary) -> Binding<String> {
        Binding(
            get: { deadlineDrafts[project.id] ?? project.deadline ?? "" },
            set: { deadlineDrafts[project.id] = $0 }
        )
    }

    private func deadlineDraft(for project: StudyProjectSummary) -> String {
        (deadlineDrafts[project.id] ?? project.deadline ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct StudyPlanIntakeView: View {
    @ObservedObject var vm: LearningAssistantViewModel

    @State private var urlText = ""
    @State private var deadline = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var capacityMinutes = 60
    @State private var clarificationAnswers: [String: String] = [:]
    @State private var clarificationOptionSelections: [String: String] = [:]
    @State private var durationDrafts: [Int: Int] = [:]
    @State private var lastClarificationDraftId: Int?
    @State private var lastDurationDraftId: Int?
    @State private var lastDurationDraftIdentity: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                intakeControls

                if let error = vm.studyPlanError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if vm.isStartingStudyPlan {
                    progressRow("正在预览链接内容")
                }

                studyPlanClarificationCard
                studyPlanDraftReview

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await vm.fetchDailyCapacity()
            capacityMinutes = max(vm.dailyCapacityMin, 15)
        }
    }

    private var intakeControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("学习资料 URL", systemImage: "link")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("https://example.com/course", text: $urlText)
                .textFieldStyle(.roundedBorder)

            DatePicker("截止日期（必填）", selection: $deadline, in: Date()..., displayedComponents: .date)
                .datePickerStyle(.compact)

            Stepper(value: $capacityMinutes, in: 15...480, step: 15) {
                Text("每日容量：\(capacityMinutes) 分钟")
                    .font(.callout)
            }

            Button {
                startStudyPlan()
            } label: {
                Label("生成学习计划", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isStartingStudyPlan)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var studyPlanClarificationCard: some View {
        if let clarification = vm.studyPlanClarification, vm.studyPlanDraft == nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("生成前确认")
                    .font(.headline)

                ForEach(Array(clarification.questions.prefix(3)), id: \.id) { question in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(question.prompt)
                            .font(.callout.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)

                        if question.options.isEmpty || question.allowsCustomText {
                            TextField("使用推荐默认，或输入你的补充", text: answerBinding(for: question, defaults: clarification.defaults))
                                .textFieldStyle(.roundedBorder)
                        }

                        if !question.options.isEmpty {
                            Picker("", selection: clarificationOptionSelectionBinding(for: question, defaults: clarification.defaults)) {
                                ForEach(question.options, id: \.id) { option in
                                    Text(optionLabel(option))
                                        .tag(option.id)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.radioGroup)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Button("生成学习计划") {
                        clarificationAnswers = mergedClarificationAnswers(for: clarification)
                        Task { await vm.submitStudyPlanClarification(answers: clarificationAnswers, skip: false) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.isSubmittingStudyPlanClarification)

                    Button("生成粗略计划") {
                        Task { await vm.skipStudyPlanClarification() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isSubmittingStudyPlanClarification)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .onAppear {
                seedClarificationDefaults(from: clarification)
            }
            .onChange(of: clarificationDraftId(for: clarification)) { _ in
                seedClarificationDefaults(from: clarification)
            }
        }
    }

    @ViewBuilder
    private var studyPlanDraftReview: some View {
        if let draft = vm.studyPlanDraft {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.title)
                        .font(.headline)
                    Text("Review 状态：\(draft.status)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("截止日期：\(draft.deadline) · 每日容量：\(draft.capacityMinutes) 分钟")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(draft.sourceURL.absoluteString)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                draftStatusFacts(draft)

                VStack(alignment: .leading, spacing: 8) {
                    Text("任务列表")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(draft.tasks, id: \.orderIndex) { task in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(task.orderIndex + 1). \(task.title)")
                                .font(.callout.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text("安排：\(task.scheduledDate) · 目标 \(task.targetMinutes) 分钟")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                Stepper(value: durationBinding(for: task), in: 5...600, step: 5) {
                                    Text("预计 \(durationDrafts[task.orderIndex] ?? task.estimatedMinutes) 分钟")
                                        .font(.caption)
                                }

                                Button("更新时长") {
                                    let minutes = durationDrafts[task.orderIndex] ?? task.estimatedMinutes
                                    Task { await vm.updateStudyPlanDraftTaskDuration(orderIndex: task.orderIndex, estimatedMinutes: minutes) }
                                }
                                .buttonStyle(.bordered)
                                .disabled(vm.isUpdatingStudyPlanDraft)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                HStack(spacing: 8) {
                    Button("取消") {
                        Task { await vm.cancelStudyPlanDraft() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isConfirmingStudyPlanDraft)

                    Button("确认创建计划") {
                        Task { await vm.confirmStudyPlanDraft() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.isConfirmingStudyPlanDraft)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .onAppear {
                seedDraftDurations(from: draft)
            }
            .onChange(of: durationDraftIdentity(for: draft)) { _ in
                seedDraftDurations(from: draft)
            }
        }
    }

    private func draftStatusFacts(_ draft: StudyPlanDraft) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if draft.clarificationSkipped || draft.lowCalibration {
                Label("低校准：已使用推荐默认生成，确认前建议检查任务时长。", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            if draft.expectedLate {
                Label("预计晚于截止日期", systemImage: "calendar")
                    .foregroundStyle(.red)
            }

            ForEach(draft.overCapacityDays, id: \.date) { day in
                Label("超出每日容量：\(day.date) 超出 \(day.overByMinutes) 分钟", systemImage: "gauge")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption)
    }

    private func startStudyPlan() {
        Task { await vm.startStudyPlan(url: urlText, deadline: deadline, capacityMinutes: capacityMinutes) }
    }

    private func progressRow(_ label: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func seedClarificationDefaults(from clarification: StudyPlanClarification) {
        let draftId = clarificationDraftId(for: clarification)
        if lastClarificationDraftId != draftId {
            clarificationAnswers = [:]
            clarificationOptionSelections = [:]
            lastClarificationDraftId = draftId
        }

        for question in clarification.questions.prefix(3) where clarificationAnswers[question.id] == nil {
            if let defaultValue = clarification.defaults[question.id] {
                clarificationAnswers[question.id] = defaultValue
            } else if let defaultOption = question.options.first(where: { $0.isDefault || $0.usesDefault || $0.recommended }) {
                clarificationAnswers[question.id] = defaultOption.value
            } else if let firstOption = question.options.first {
                clarificationAnswers[question.id] = firstOption.value
            } else {
                clarificationAnswers[question.id] = ""
            }
        }

        for question in clarification.questions.prefix(3) where !question.options.isEmpty && clarificationOptionSelections[question.id] == nil {
            clarificationOptionSelections[question.id] = defaultClarificationOption(for: question, defaults: clarification.defaults)?.id
        }
    }

    private func mergedClarificationAnswers(for clarification: StudyPlanClarification) -> [String: String] {
        var answers = clarification.defaults
        for question in clarification.questions.prefix(3) {
            answers[question.id] = answerValue(for: question, defaults: clarification.defaults)
        }
        return answers
    }

    private func answerValue(
        for question: StudyPlanClarificationQuestion,
        defaults: [String: String]
    ) -> String {
        if let selectedOptionId = clarificationOptionSelections[question.id],
           let selectedOption = question.options.first(where: { $0.id == selectedOptionId }) {
            let typedAnswer = clarificationAnswers[question.id] ?? selectedOption.value
            if question.allowsCustomText && typedAnswer != selectedOption.value {
                return typedAnswer
            }
            return selectedOption.value
        }

        return clarificationAnswers[question.id]
            ?? defaults[question.id]
            ?? defaultClarificationOption(for: question, defaults: defaults)?.value
            ?? ""
    }

    private func answerBinding(
        for question: StudyPlanClarificationQuestion,
        defaults: [String: String]
    ) -> Binding<String> {
        Binding(
            get: {
                clarificationAnswers[question.id]
                    ?? defaults[question.id]
                    ?? question.options.first(where: { $0.isDefault || $0.usesDefault || $0.recommended })?.value
                    ?? question.options.first?.value
                    ?? ""
            },
            set: { newValue in
                clarificationAnswers[question.id] = newValue
                if question.allowsCustomText,
                   let selectedOptionId = clarificationOptionSelections[question.id],
                   question.options.first(where: { $0.id == selectedOptionId })?.value != newValue {
                    clarificationOptionSelections[question.id] = nil
                }
            }
        )
    }

    private func clarificationOptionSelectionBinding(
        for question: StudyPlanClarificationQuestion,
        defaults: [String: String]
    ) -> Binding<String> {
        Binding(
            get: {
                clarificationOptionSelections[question.id]
                    ?? defaultClarificationOption(for: question, defaults: defaults)?.id
                    ?? ""
            },
            set: { optionId in
                clarificationOptionSelections[question.id] = optionId
                if let option = question.options.first(where: { $0.id == optionId }) {
                    clarificationAnswers[question.id] = option.value
                }
            }
        )
    }

    private func defaultClarificationOption(
        for question: StudyPlanClarificationQuestion,
        defaults: [String: String]
    ) -> StudyPlanClarificationOption? {
        if let defaultValue = defaults[question.id] {
            return question.options.first { option in
                option.value == defaultValue && (option.isDefault || option.usesDefault || option.recommended)
            } ?? question.options.first { $0.value == defaultValue }
        }

        return question.options.first { $0.isDefault || $0.usesDefault || $0.recommended }
            ?? question.options.first
    }

    private func clarificationDraftId(for clarification: StudyPlanClarification) -> Int? {
        vm.studyPlanDraftId
    }

    private func optionLabel(_ option: StudyPlanClarificationOption) -> String {
        var badges: [String] = []
        if option.recommended { badges.append("推荐") }
        if option.isDefault || option.usesDefault { badges.append("默认") }
        return badges.isEmpty ? option.label : "\(option.label)（\(badges.joined(separator: " / "))）"
    }

    private func seedDraftDurations(from draft: StudyPlanDraft) {
        let draftIdentity = durationDraftIdentity(for: draft)
        if lastDurationDraftId != draft.id || lastDurationDraftIdentity != draftIdentity {
            durationDrafts = Dictionary(uniqueKeysWithValues: draft.tasks.map { ($0.orderIndex, $0.estimatedMinutes) })
            lastDurationDraftId = draft.id
            lastDurationDraftIdentity = draftIdentity
        }
    }

    private func durationDraftIdentity(for draft: StudyPlanDraft) -> String {
        ([String(draft.id)] + draft.tasks.map { "\($0.orderIndex):\($0.estimatedMinutes)" }).joined(separator: "|")
    }

    private func durationBinding(for task: StudyPlanDraftTask) -> Binding<Int> {
        Binding(
            get: { durationDrafts[task.orderIndex] ?? task.estimatedMinutes },
            set: { durationDrafts[task.orderIndex] = $0 }
        )
    }
}

enum StudySmartOptionsPlacement {
    case dashboard
    case adjustment
}

enum StudySmartOptionsFilter {
    static func visibleOptions(
        _ options: [StudySmartProposalOption],
        placement: StudySmartOptionsPlacement
    ) -> [StudySmartProposalOption] {
        options.filter { shouldShow($0, placement: placement) }
    }

    static func visibleMessage(
        _ message: String?,
        options: [StudySmartProposalOption],
        placement: StudySmartOptionsPlacement
    ) -> String? {
        visibleMessage(message, messageTrigger: nil, options: options, placement: placement)
    }

    static func visibleMessage(
        _ message: String?,
        messageTrigger: StudySmartProposalTrigger?,
        options: [StudySmartProposalOption],
        placement: StudySmartOptionsPlacement
    ) -> String? {
        guard let message else { return nil }
        if let messageTrigger {
            return shouldShow(messageTrigger, placement: placement) ? message : nil
        }
        return visibleOptions(options, placement: placement).isEmpty ? nil : message
    }

    private static func shouldShow(
        _ option: StudySmartProposalOption,
        placement: StudySmartOptionsPlacement
    ) -> Bool {
        shouldShow(option.trigger, placement: placement)
    }

    private static func shouldShow(
        _ trigger: StudySmartProposalTrigger,
        placement: StudySmartOptionsPlacement
    ) -> Bool {
        switch placement {
        case .dashboard:
            return trigger == .morning
        case .adjustment:
            return trigger == .afterAdjustment
        }
    }
}

private struct StudySmartOptionsStrip: View {
    @ObservedObject var vm: LearningAssistantViewModel
    let placement: StudySmartOptionsPlacement

    var body: some View {
        if shouldRender {
            VStack(alignment: .leading, spacing: 10) {
                if !visibleOptions.isEmpty {
                    HStack(spacing: 8) {
                        Label(title, systemImage: "wand.and.stars")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Button("忽略") {
                            vm.ignoreStudySmartProposals()
                        }
                        .buttonStyle(.borderless)
                        .disabled(vm.isApplyingStudySmartProposal)
                        .help("忽略本次智能建议")
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 10) {
                            ForEach(visibleOptions, id: \.id) { option in
                                StudySmartProposalOptionCard(
                                    option: option,
                                    isApplying: vm.isApplyingStudySmartProposal,
                                    onApply: {
                                        Task { await vm.applyStudySmartProposal(option) }
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                if let message = visibleProposalMessage {
                    Label(message, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var title: String {
        switch placement {
        case .dashboard:
            return "智能建议"
        case .adjustment:
            return "调整后的智能建议"
        }
    }

    private var shouldRender: Bool {
        vm.isStudySmartModeEnabled &&
            (!visibleOptions.isEmpty || visibleProposalMessage != nil)
    }

    private var visibleOptions: [StudySmartProposalOption] {
        StudySmartOptionsFilter.visibleOptions(vm.studySmartProposalOptions, placement: placement)
    }

    private var visibleProposalMessage: String? {
        StudySmartOptionsFilter.visibleMessage(
            vm.studySmartProposalMessage,
            messageTrigger: vm.studySmartProposalMessageTrigger,
            options: vm.studySmartProposalOptions,
            placement: placement
        )
    }
}

private struct StudySmartProposalOptionCard: View {
    let option: StudySmartProposalOption
    let isApplying: Bool
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(option.summary ?? "可预览的学习计划调整")
                .font(.callout.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let reasonText {
                Label(reasonText, systemImage: "lightbulb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !option.affectedProjectIds.isEmpty {
                Label("影响项目：\(option.affectedProjectIds.map(String.init).joined(separator: ", "))", systemImage: "folder")
            }

            if !option.affectedTaskIds.isEmpty {
                Label("影响任务：\(option.affectedTaskIds.map(String.init).joined(separator: ", "))", systemImage: "checklist")
            }

            if !option.previewedChanges.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("预览变更")
                        .font(.caption.weight(.semibold))
                    ForEach(Array(option.previewedChanges.enumerated()), id: \.offset) { _, change in
                        Text(previewedChangeText(change))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let redStateImpact = option.redStateImpact {
                redStateImpactView(redStateImpact)
            }

            if let tradeoff = option.tradeoff {
                Text(tradeoff)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("仅预览；点击应用后才会更改计划。")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Button {
                onApply()
            } label: {
                Label("应用", systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isApplying)
            .help("应用这个智能建议")
        }
        .font(.caption)
        .padding(10)
        .frame(width: 260, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.16))
        )
    }

    private var reasonText: String? {
        if let reason = option.reason["reason"]?.value as? String {
            return reason
        }
        if let message = option.reason["message"]?.value as? String {
            return message
        }
        if let type = option.reason["type"]?.value as? String {
            return type
        }
        return nil
    }

    private func previewedChangeText(_ change: StudySmartPreviewedChange) -> String {
        var parts: [String] = []
        if let projectId = change.projectId {
            parts.append("项目 \(projectId)")
        }
        if let taskId = change.taskId {
            parts.append("任务 \(taskId)")
        }
        if let field = change.field {
            parts.append(field)
        }
        if let oldDate = change.oldDate, let newDate = change.newDate {
            parts.append("\(oldDate) -> \(newDate)")
        }
        if let oldDeadline = change.oldDeadline, let newDeadline = change.newDeadline {
            parts.append("\(oldDeadline) -> \(newDeadline)")
        }
        return parts.isEmpty ? "计划预览项" : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func redStateImpactView(_ redStateImpact: StudyRedStateImpact) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let expectedLate = redStateImpact.expectedLate {
                Label(
                    "预计晚于截止日期：\(expectedLate.before ? "是" : "否") -> \(expectedLate.after ? "是" : "否")",
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(expectedLate.after ? .red : .secondary)
            }

            if let overCapacity = redStateImpact.overCapacity {
                if !overCapacity.newOverCapacityDates.isEmpty {
                    Label("新增超载：\(overCapacity.newOverCapacityDates.joined(separator: ", "))", systemImage: "gauge")
                        .foregroundStyle(.red)
                } else if !overCapacity.afterDates.isEmpty {
                    Label("超载日期：\(overCapacity.afterDates.joined(separator: ", "))", systemImage: "gauge")
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

private struct StudySettingsView: View {
    @ObservedObject var vm: LearningAssistantViewModel

    @State private var weeklyWeekdays: Set<Int> = []
    @State private var oneOffDatesText = ""
    @State private var hasTouchedRestDaySettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LearningPreferencesView(api: vm.api)

                Divider()

                smartModeSettings

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Label("休息日设置", systemImage: "moon.zzz")
                        .font(.headline)

                    if let settings = vm.studyRestDaySettings {
                        Text("每周：\(weekdaySummary(settings.weeklyWeekdays)) · 单次：\(settings.oneOffDates.isEmpty ? "无" : settings.oneOffDates.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("尚未加载休息日设置")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(Self.weekdays, id: \.self) { weekday in
                            Toggle(weekdayLabel(weekday), isOn: weekdayBinding(weekday))
                                .toggleStyle(.checkbox)
                                .font(.caption)
                        }
                    }

                    TextField("单次休息日，逗号分隔 yyyy-MM-dd", text: $oneOffDatesText)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 8) {
                        Button {
                            Task {
                                hasTouchedRestDaySettings = false
                                await vm.fetchStudyRestDaySettings()
                                hasTouchedRestDaySettings = true
                                seedDrafts(from: vm.studyRestDaySettings)
                            }
                        } label: {
                            Label("重新加载", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(vm.isAdjustingStudyPlan)
                        .help("加载休息日设置")

                        Button {
                            Task {
                                hasTouchedRestDaySettings = false
                                await vm.updateStudyRestDaySettings(
                                    StudyRestDaySettings(
                                        weeklyWeekdays: weeklyWeekdays.sorted(),
                                        oneOffDates: parsedOneOffDates
                                    )
                                )
                                hasTouchedRestDaySettings = true
                                seedDrafts(from: vm.studyRestDaySettings)
                            }
                        } label: {
                            Label("保存休息日", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(vm.isAdjustingStudyPlan)
                        .help("更新休息日设置")
                    }

                    if let message = restDayErrorMessage {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            hasTouchedRestDaySettings = false
            await vm.fetchStudyRestDaySettings()
            hasTouchedRestDaySettings = true
            seedDrafts(from: vm.studyRestDaySettings)
        }
    }

    private var smartModeSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("智能模式", systemImage: "sparkles")
                .font(.headline)

            Toggle("智能学习模式", isOn: Binding(
                get: { vm.isStudySmartModeEnabled },
                set: { isOn in
                    Task { await vm.updateStudySmartModeSetting(isOn) }
                }
            ))
            .toggleStyle(.switch)

            Text("默认关闭。开启后，首页会显示基于 v2 学习事实的晨间简报和可预览建议；只有点击应用才会更改计划。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let message = vm.studySmartSettingsMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var restDayErrorMessage: String? {
        guard hasTouchedRestDaySettings,
              let error = vm.studyPlanAdjustmentError else { return nil }
        return "休息日设置失败：\(error)"
    }

    private var parsedOneOffDates: [String] {
        oneOffDatesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func seedDrafts(from settings: StudyRestDaySettings?) {
        guard let settings else { return }
        weeklyWeekdays = Set(settings.weeklyWeekdays)
        oneOffDatesText = settings.oneOffDates.joined(separator: ", ")
    }

    private func weekdayBinding(_ weekday: Int) -> Binding<Bool> {
        Binding(
            get: { weeklyWeekdays.contains(weekday) },
            set: { isOn in
                if isOn {
                    weeklyWeekdays.insert(weekday)
                } else {
                    weeklyWeekdays.remove(weekday)
                }
            }
        )
    }

    private func weekdaySummary(_ weekdays: [Int]) -> String {
        weekdays.isEmpty ? "无" : weekdays.sorted().map(weekdayLabel).joined(separator: "、")
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "周一"
        case 2: return "周二"
        case 3: return "周三"
        case 4: return "周四"
        case 5: return "周五"
        case 6: return "周六"
        case 7: return "周日"
        default: return "周\(weekday)"
        }
    }

    private static let weekdays = Array(1...7)
}

private struct StudyPlanAdjustmentView: View {
    @ObservedObject var vm: LearningAssistantViewModel

    @State private var instruction = ""
    @State private var projectIdText = ""
    @State private var previewedInstruction: String?
    @State private var previewedProjectId: Int?
    @State private var hasTouchedDialogueAdjustment = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("调整计划", systemImage: "slider.horizontal.3")
                        .font(.headline)

                    TextEditor(text: $instruction)
                        .font(.body)
                        .frame(minHeight: 90)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.25))
                        )

                    HStack(spacing: 8) {
                        TextField("项目 ID（可选）", text: $projectIdText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 116)

                        Button {
                            Task {
                                hasTouchedDialogueAdjustment = false
                                previewedInstruction = nil
                                previewedProjectId = nil
                                let requestedInstruction = trimmedInstruction
                                let requestedProjectId = projectId
                                await vm.previewStudyDialogueAdjustment(instruction: trimmedInstruction, projectId: projectId)
                                hasTouchedDialogueAdjustment = true
                                if vm.studyPlanAdjustmentError == nil,
                                   vm.studyDialogueAdjustmentPreview != nil,
                                   requestedInstruction == trimmedInstruction,
                                   requestedProjectId == projectId {
                                    previewedInstruction = trimmedInstruction
                                    previewedProjectId = projectId
                                }
                            }
                        } label: {
                            Label("预览", systemImage: "eye")
                        }
                        .buttonStyle(.bordered)
                        .disabled(trimmedInstruction.isEmpty || vm.isAdjustingStudyPlan)
                        .help("预览计划调整")

                        Button {
                            Task {
                                hasTouchedDialogueAdjustment = false
                                await vm.applyStudyDialogueAdjustment(instruction: trimmedInstruction, projectId: projectId)
                                hasTouchedDialogueAdjustment = true
                            }
                        } label: {
                            Label("应用", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!hasCurrentPreview || vm.isAdjustingStudyPlan)
                        .help("应用已预览的计划调整")
                    }
                }

                if vm.isAdjustingStudyPlan {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在处理调整")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let message = dialogueAdjustmentErrorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                previewSection
                resultSection
                StudySmartOptionsStrip(vm: vm, placement: .adjustment)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            if instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let draft = vm.consumeAdjustPlanDraftText() {
                instruction = draft
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        if let preview = vm.studyDialogueAdjustmentPreview {
            VStack(alignment: .leading, spacing: 8) {
                Text("预览")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(preview.message ?? preview.status)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                adjustmentFacts(
                    command: preview.command,
                    projectId: preview.projectId,
                    deltaDays: preview.deltaDays,
                    affectedTaskIds: preview.affectedTaskIds,
                    changes: preview.changes,
                    redStateImpact: preview.redStateImpact
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if let result = vm.studyDialogueAdjustmentResult {
            VStack(alignment: .leading, spacing: 8) {
                Text("结果")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(result.message ?? result.status)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                adjustmentFacts(
                    command: result.command,
                    projectId: result.projectId,
                    deltaDays: result.deltaDays,
                    affectedTaskIds: result.affectedTaskIds,
                    changes: result.changes,
                    redStateImpact: nil
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func adjustmentFacts(
        command: String?,
        projectId: Int?,
        deltaDays: Int?,
        affectedTaskIds: [Int]?,
        changes: [StudyAdjustmentChange]?,
        redStateImpact: StudyRedStateImpact?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let command {
                Label(command, systemImage: "terminal")
            }
            if let projectId {
                Label("项目 ID \(projectId)", systemImage: "folder")
            }
            if let deltaDays {
                Label("移动 \(deltaDays) 天", systemImage: "arrow.left.arrow.right")
            }
            if let affectedTaskIds, !affectedTaskIds.isEmpty {
                Label("影响任务：\(affectedTaskIds.map(String.init).joined(separator: ", "))", systemImage: "checklist")
            }
            if let changes, !changes.isEmpty {
                ForEach(Array(changes.enumerated()), id: \.offset) { _, change in
                    Text("任务 \(change.taskId)：\(change.oldDate) -> \(change.newDate)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            redStateImpactView(redStateImpact)
        }
        .font(.caption)
    }

    @ViewBuilder
    private func redStateImpactView(_ redStateImpact: StudyRedStateImpact?) -> some View {
        if let expectedLate = redStateImpact?.expectedLate {
            defaultModeSilentRedStateFact {
                Label(
                    "预计晚于截止日期：\(expectedLate.before ? "是" : "否") -> \(expectedLate.after ? "是" : "否")",
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(expectedLate.after ? .red : .secondary)
            }
        }

        if let overCapacity = redStateImpact?.overCapacity {
            if !overCapacity.newOverCapacityDates.isEmpty {
                defaultModeSilentRedStateFact {
                    Label("新增超载：\(overCapacity.newOverCapacityDates.joined(separator: ", "))", systemImage: "gauge")
                        .foregroundStyle(.red)
                }
            } else if !overCapacity.afterDates.isEmpty {
                defaultModeSilentRedStateFact {
                    Label("超载日期：\(overCapacity.afterDates.joined(separator: ", "))", systemImage: "gauge")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var trimmedInstruction: String {
        instruction.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var projectId: Int? {
        Int(projectIdText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var hasCurrentPreview: Bool {
        vm.studyDialogueAdjustmentPreview != nil &&
            previewedInstruction == trimmedInstruction &&
            previewedProjectId == projectId
    }

    private var dialogueAdjustmentErrorMessage: String? {
        guard hasTouchedDialogueAdjustment,
              let error = vm.studyPlanAdjustmentError else { return nil }
        return "计划调整失败：\(error)"
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
    func completeTask(id: Int, actualMinutes: Int?) async throws -> TaskCompletionResult {
        TaskCompletionResult(taskId: id, completedAt: "2026-06-01T12:30:00")
    }
    func completeResource(id: Int) async throws {}
    func archiveResource(id: Int) async throws {}
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
    func startStudyPlan(url: String, deadline: String, capacityMinutes: Int) async throws -> StudyPlanStartResponse {
        StudyPlanStartResponse(
            draftId: 1,
            clarification: StudyPlanClarification(
                version: "d30-guided-clarification-v1",
                materialType: "web_article",
                questions: [
                    StudyPlanClarificationQuestion(
                        id: "goal_depth",
                        prompt: "预览学习目标？",
                        options: [
                            StudyPlanClarificationOption(
                                id: "recommended",
                                label: "使用推荐目标",
                                value: "understand_and_apply",
                                recommended: true,
                                isDefault: true
                            )
                        ]
                    )
                ],
                defaults: ["goal_depth": "understand_and_apply"],
                skipAction: StudyPlanSkipAction(id: "generate_rough_draft", label: "生成粗略计划", usesDefaults: true)
            )
        )
    }
    func submitStudyPlanClarification(draftId: Int, answers: [String: String], skip: Bool) async throws -> StudyPlanDraft {
        previewStudyPlanDraft(id: draftId)
    }
    func updateStudyPlanDraftTaskDuration(draftId: Int, taskOrderIndex: Int, estimatedMinutes: Int) async throws -> StudyPlanDraft {
        previewStudyPlanDraft(id: draftId, estimatedMinutes: estimatedMinutes)
    }
    func cancelStudyPlanDraft(draftId: Int) async throws {}
    func confirmStudyPlanDraft(draftId: Int) async throws -> StudyPlanActivationResult {
        StudyPlanActivationResult(
            id: draftId,
            resourceId: 1,
            status: "active",
            sourceURL: URL(string: "https://example.com/preview")!,
            deadline: "2026-07-01",
            capacityMinutes: 60,
            clarificationSkipped: false
        )
    }
    func fetchResources() async throws -> [AssistantResource] { resources }
    func getLearningPreferences() async throws -> LearningPreferences {
        LearningPreferences(dailyCapacityMin: 60)
    }
    func updateLearningPreferences(_ prefs: LearningPreferences) async throws {}

    private func previewStudyPlanDraft(id: Int, estimatedMinutes: Int = 30) -> StudyPlanDraft {
        StudyPlanDraft(
            id: id,
            title: "预览学习计划",
            sourceURL: URL(string: "https://example.com/preview")!,
            deadline: "2026-07-01",
            status: "review",
            capacityMinutes: 60,
            clarificationSkipped: false,
            tasks: [
                StudyPlanDraftTask(
                    title: "预览任务",
                    orderIndex: 0,
                    estimatedMinutes: estimatedMinutes,
                    scheduledDate: "2026-06-20",
                    targetMinutes: estimatedMinutes
                )
            ]
        )
    }
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
        case .home: return "今日"
        case .projectOverview: return "项目总览"
        case .calendar: return "日历"
        case .addResource: return "添加资料"
        case .resourceProgress: return "资料进度"
        case .adjustPlan: return "调整计划"
        case .settings: return "设置"
        }
    }

    var iconName: String {
        switch self {
        case .home: return "house"
        case .projectOverview: return "folder"
        case .calendar: return "calendar"
        case .addResource: return "plus.circle"
        case .resourceProgress: return "chart.bar"
        case .adjustPlan: return "slider.horizontal.3"
        case .settings: return "gearshape"
        }
    }
}
