import AppKit
import SwiftUI

struct LearningDeskPanelView: View {
    @StateObject private var viewModel = LearningDeskPanelViewModel()
    @AppStorage(MalDazeDefaults.learningDailyCapacityHours) private var dailyCapacityHours =
        MalDazeDefaults.defaultLearningDailyCapacityHours
    @AppStorage(MalDazeDefaults.learningTodayGrouping) private var todayGroupingRaw =
        LearningDeskPanelViewModel.TodayGroupingMode.flat.rawValue

    private var todayGrouping: LearningDeskPanelViewModel.TodayGroupingMode {
        LearningDeskPanelViewModel.TodayGroupingMode(rawValue: todayGroupingRaw) ?? .flat
    }

    private var dailyCapacityMinutes: Int {
        LearningCapacityFormatting.minutes(
            fromHours: MalDazeDefaults.clampedLearningDailyCapacityHours(dailyCapacityHours)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            tabPicker
            tabContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .background(Color(.controlBackgroundColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .task {
            await viewModel.loadToday()
        }
        .onAppear { viewModel.startWatching() }
        .onDisappear { viewModel.stopWatching() }
        .onChange(of: viewModel.selectedTab) { _ in
            Task { await viewModel.onTabChanged() }
        }
        .onChange(of: dailyCapacityHours) { _ in
            Task {
                LearningSettingsSyncService().syncDailyCapacityToHermesProfile()
                if viewModel.selectedTab == .schedule {
                    await viewModel.loadSchedule(force: true)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: MalDazeBroadcastNotifications.learningDailyCapacityChanged)) { _ in
            Task {
                if viewModel.selectedTab == .schedule {
                    await viewModel.loadSchedule(force: true)
                } else {
                    await viewModel.loadToday()
                }
            }
        }
        .sheet(item: $viewModel.movePreview) { preview in
            LearningMovePreviewSheet(
                preview: preview,
                onConfirm: { Task { await viewModel.confirmMove() } },
                onCancel: { viewModel.cancelMovePreview() }
            )
        }
        .deskPetDashboardEscapeOverlay(
            id: "learning.movePreview",
            isPresented: viewModel.movePreview != nil,
            onDismiss: { viewModel.cancelMovePreview() }
        )
        .sheet(isPresented: $viewModel.showInsertSheet) {
            LearningInsertTaskSheet(
                projects: viewModel.insertProjectOptions,
                defaultDate: viewModel.todayDateISO,
                onSubmit: { projectId, title, duration, date in
                    Task {
                        await viewModel.insertTask(
                            projectId: projectId,
                            title: title,
                            duration: duration,
                            date: date
                        )
                    }
                },
                onCancel: { viewModel.showInsertSheet = false }
            )
        }
        .deskPetDashboardEscapeOverlay(
            id: "learning.insertTask",
            isPresented: viewModel.showInsertSheet,
            onDismiss: { viewModel.showInsertSheet = false }
        )
        .confirmationDialog(
            "删除任务？",
            isPresented: Binding(
                get: { viewModel.deleteCandidate != nil },
                set: { if !$0 { viewModel.deleteCandidate = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                Task { await viewModel.confirmDelete() }
            }
            Button("取消", role: .cancel) {
                viewModel.deleteCandidate = nil
            }
        } message: {
            if let candidate = viewModel.deleteCandidate {
                Text("将删除「\(candidate.title)」，此操作不可撤销。")
            }
        }
        .deskPetDashboardEscapeOverlay(
            id: "learning.deleteTask",
            isPresented: viewModel.deleteCandidate != nil,
            onDismiss: { viewModel.deleteCandidate = nil }
        )
        .sheet(item: $viewModel.completeDurationCandidate) { candidate in
            LearningCompleteDurationSheet(
                title: candidate.title,
                plannedMinutes: candidate.plannedMinutes,
                onConfirm: { minutes in
                    Task { await viewModel.confirmCompleteWithDuration(minutes: minutes) }
                },
                onCancel: { viewModel.cancelCompleteWithDuration() }
            )
        }
        .deskPetDashboardEscapeOverlay(
            id: "learning.completeDuration",
            isPresented: viewModel.completeDurationCandidate != nil,
            onDismiss: { viewModel.cancelCompleteWithDuration() }
        )
        .sheet(item: $viewModel.deadlineEditSession) { session in
            LearningDeadlineEditSheet(
                session: session,
                preview: viewModel.deadlineRepackPreview,
                onDateChange: { newDeadline in
                    Task {
                        await viewModel.previewDeadlineRepack(
                            projectId: session.projectId,
                            deadline: newDeadline
                        )
                    }
                },
                onConfirm: { newDeadline in
                    Task { await viewModel.confirmDeadlineEdit(newDeadline: newDeadline) }
                },
                onCancel: { viewModel.cancelDeadlineEdit() }
            )
        }
        .deskPetDashboardEscapeOverlay(
            id: "learning.deadlineEdit",
            isPresented: viewModel.deadlineEditSession != nil,
            onDismiss: { viewModel.cancelDeadlineEdit() }
        )
        .deskPetDashboardEscapeOverlay(
            id: "learning.deleteProject",
            isPresented: viewModel.deleteProjectCandidate != nil,
            onDismiss: { viewModel.deleteProjectCandidate = nil }
        )
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .center) {
            Label("学习", systemImage: "book.closed")
                .font(.headline)
            Spacer()
            if viewModel.selectedTab == .today {
                Button {
                    Task { await viewModel.prepareInsertSheet() }
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("添加任务")
                .disabled(insertDisabled)
            }
            Button {
                Task { await viewModel.refreshCurrentTab(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("刷新")
        }

        if let notice = viewModel.actionNotice {
            Text(notice)
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private var insertDisabled: Bool {
        if case .loaded = viewModel.loadState {
            return false
        }
        return true
    }

    private var tabPicker: some View {
        Picker("视图", selection: $viewModel.selectedTab) {
            ForEach(LearningDeskPanelViewModel.PanelTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .labelsHidden()
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .today:
            todayContent
        case .schedule:
            scheduleContent
        case .projects:
            projectsContent
        }
    }

    @ViewBuilder
    private var todayContent: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            ProgressView("加载今日学习任务…")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text("无法加载学习面板")
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("确认 ~/.hermes/scripts/schedule.py 存在。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(8)
        case .loaded(let snapshot):
            loadedBody(snapshot: snapshot)
        }
    }

    @ViewBuilder
    private var projectsContent: some View {
        switch viewModel.statusLoadState {
        case .idle, .loading:
            ProgressView("加载项目状态…")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text("无法加载项目总览")
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        case .loaded(let projects):
            LearningProjectStatusView(
                projects: projects,
                busyProjectIds: viewModel.busyProjectIds,
                scrollToProjectId: viewModel.scrollToProjectId,
                onJumpToToday: { projectId in
                    viewModel.jumpToToday(projectId: projectId)
                },
                onBeginDeadlineEdit: { project in
                    viewModel.beginDeadlineEdit(project: project)
                },
                onBeginDeleteProject: { project in
                    viewModel.beginDeleteProject(project)
                }
            )
            .alert(item: $viewModel.deleteProjectCandidate) { candidate in
                Alert(
                    title: Text("删除项目？"),
                    message: Text(deleteProjectAlertMessage(candidate)),
                    primaryButton: .destructive(Text("删除项目")) {
                        Task { await viewModel.confirmDeleteProject(candidate) }
                    },
                    secondaryButton: .cancel(Text("取消")) {
                        viewModel.deleteProjectCandidate = nil
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var scheduleContent: some View {
        switch viewModel.scheduleLoadState {
        case .idle, .loading:
            LearningScheduleView(
                monthTitle: viewModel.scheduleMonthTitle,
                days: [],
                deadlines: [],
                budgetStudyMinutes: dailyCapacityMinutes,
                isLoading: true,
                errorMessage: nil,
                truncated: false,
                selectedDate: $viewModel.selectedScheduleDate,
                onPrevMonth: { Task { await viewModel.shiftScheduleMonth(by: -1) } },
                onNextMonth: { Task { await viewModel.shiftScheduleMonth(by: 1) } },
                onJumpToday: { Task { await viewModel.jumpToTodayInSchedule() } },
                taskRow: { row, isReview in taskRow(row, isReview: isReview) }
            )
        case .failed(let message):
            LearningScheduleView(
                monthTitle: viewModel.scheduleMonthTitle,
                days: [],
                deadlines: [],
                budgetStudyMinutes: dailyCapacityMinutes,
                isLoading: false,
                errorMessage: message,
                truncated: false,
                selectedDate: $viewModel.selectedScheduleDate,
                onPrevMonth: { Task { await viewModel.shiftScheduleMonth(by: -1) } },
                onNextMonth: { Task { await viewModel.shiftScheduleMonth(by: 1) } },
                onJumpToday: { Task { await viewModel.jumpToTodayInSchedule() } },
                taskRow: { row, isReview in taskRow(row, isReview: isReview) }
            )
        case .loaded(let response):
            LearningScheduleView(
                monthTitle: viewModel.scheduleMonthTitle,
                days: response.days,
                deadlines: response.deadlines,
                budgetStudyMinutes: dailyCapacityMinutes,
                isLoading: false,
                errorMessage: nil,
                truncated: response.truncated == true,
                selectedDate: $viewModel.selectedScheduleDate,
                onPrevMonth: { Task { await viewModel.shiftScheduleMonth(by: -1) } },
                onNextMonth: { Task { await viewModel.shiftScheduleMonth(by: 1) } },
                onJumpToday: { Task { await viewModel.jumpToTodayInSchedule() } },
                taskRow: { row, isReview in taskRow(row, isReview: isReview) }
            )
        }
    }

    @ViewBuilder
    private func loadedBody(snapshot: LearningTodaySnapshot) -> some View {
        let response = snapshot.response
        let displayRows = filteredRows(snapshot.rows)
        let displaySnapshot = LearningTodaySnapshot(response: response, rows: displayRows)
        let studyOver = response.study.totalMinutes > dailyCapacityMinutes
        let reviewOver = response.review.totalMinutes > response.review.budget

        todayHeader(response: response)

        if studyOver || reviewOver || !response.warnings.isEmpty {
            LearningTodayActionCard(
                studyOverCapacity: studyOver,
                reviewOverCapacity: reviewOver,
                warnings: response.warnings,
                focusProjectId: viewModel.todayProjectFilter,
                onFilterProject: { viewModel.filterTodayToProject($0) },
                onOpenScheduleTomorrow: {
                    Task { await viewModel.openScheduleTomorrow() }
                },
                onOpenProjectsTab: { projectId in
                    Task { await viewModel.jumpToProjectTab(projectId: projectId) }
                },
                onRepackProject: { projectId in
                    Task { await viewModel.beginRepackForProject(projectId: projectId) }
                }
            )
        }

        if let filterId = viewModel.todayProjectFilter,
           let name = response.warnings.first(where: { $0.projectId == filterId })?.projectName
               ?? displayRows.first?.pending.projectName {
            HStack {
                Text("筛选：\(name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("清除") { viewModel.clearTodayProjectFilter() }
                    .controlSize(.small)
            }
        }

        if !displaySnapshot.highRolloverRows.isEmpty {
            LearningTodayRolloverStrip(rows: displaySnapshot.highRolloverRows) { taskId in
                viewModel.focusRolloverTask(taskId)
            }
        }

        if !response.warnings.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(response.warnings) { warning in
                    Button {
                        viewModel.handleWarningTap(warning)
                    } label: {
                        Label(
                            "\(warning.projectName) 落后 \(warning.daysBehind) 天",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        if response.isRestDay {
            Text("今日休息")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        if displayRows.isEmpty {
            Text(response.isRestDay ? "休息日无学习任务。" : "今日无学习任务。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        } else {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        todayTaskList(snapshot: displaySnapshot)
                        if let preview = response.tomorrowPreview {
                            sectionTitle("明天预告")
                            LearningTomorrowPreviewBlock(preview: preview)
                        }
                    }
                }
                .onChange(of: viewModel.highlightTaskId) { taskId in
                    guard let taskId else { return }
                    withAnimation {
                        proxy.scrollTo(taskId, anchor: .center)
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        viewModel.clearHighlight()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func todayTaskList(snapshot: LearningTodaySnapshot) -> some View {
        if todayGrouping == .byProject {
            ForEach(LearningTodaySnapshot.projectSections(from: snapshot.rows)) { section in
                sectionTitle(section.projectName)
                ForEach(section.rows) { row in
                    taskRow(row, isReview: row.isReview)
                        .id(row.pending.taskId)
                }
            }
        } else {
            if !snapshot.studyRows.isEmpty {
                sectionTitle("正课")
                ForEach(snapshot.studyRows) { row in
                    taskRow(row, isReview: false)
                        .id(row.pending.taskId)
                }
            }
            if !snapshot.reviewRows.isEmpty {
                sectionTitle("复习")
                ForEach(snapshot.reviewRows) { row in
                    taskRow(row, isReview: true)
                        .id(row.pending.taskId)
                }
            }
        }
    }

    private func todayHeader(response: HermesTodayResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(response.date)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("分组", selection: $todayGroupingRaw) {
                    ForEach(LearningDeskPanelViewModel.TodayGroupingMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 140)
            }

            budgetLine(
                label: "正课",
                totalMinutes: response.study.totalMinutes,
                budgetMinutes: dailyCapacityMinutes
            )
            budgetLine(
                label: "复习",
                totalMinutes: response.review.totalMinutes,
                budgetMinutes: response.review.budget
            )

            if let progress = response.progress {
                progressLine(
                    label: "正课完成",
                    done: progress.study.done,
                    total: progress.study.total
                )
                progressLine(
                    label: "复习完成",
                    done: progress.review.done,
                    total: progress.review.total
                )
            }

        }
    }

    private func filteredRows(_ rows: [LearningTaskDisplayRow]) -> [LearningTaskDisplayRow] {
        guard let filter = viewModel.todayProjectFilter else { return rows }
        return rows.filter { $0.pending.projectId == filter }
    }

    private func budgetLine(label: String, totalMinutes: Int, budgetMinutes: Int) -> some View {
        let over = totalMinutes > budgetMinutes
        let loadText = label == "复习"
            ? LearningCapacityFormatting.formatMinutesLoad(totalMinutes: totalMinutes, budgetMinutes: budgetMinutes)
            : LearningCapacityFormatting.formatLoad(totalMinutes: totalMinutes, budgetMinutes: budgetMinutes)
        return HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
            Text(loadText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(over ? .red : .primary)
            if over {
                Text("超额")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.red)
            }
            Spacer(minLength: 0)
        }
    }

    private func progressLine(label: String, done: Int, total: Int) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            Text("\(done)/\(total)")
                .font(.caption.monospacedDigit())
                .frame(width: 36, alignment: .leading)
            ProgressView(
                value: LearningCapacityFormatting.progressFraction(done: done, total: total)
            )
            .progressViewStyle(.linear)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func taskRow(_ row: LearningTaskDisplayRow, isReview: Bool) -> some View {
        let busy = viewModel.busyTaskIds.contains(row.pending.taskId)
        return LearningTaskRow(
            row: row,
            isBusy: busy,
            isHighlighted: viewModel.highlightTaskId == row.pending.taskId,
            showReviewActions: isReview,
            onComplete: {
                Task { await viewModel.complete(taskId: row.pending.taskId) }
            },
            onCompleteWithDuration: {
                viewModel.beginCompleteWithDuration(for: row)
            },
            onPostponeTomorrow: {
                Task {
                    await viewModel.requestMove(
                        taskId: row.pending.taskId,
                        taskTitle: row.pending.title,
                        newDate: LearningDeskPanelViewModel.tomorrowISO()
                    )
                }
            },
            onPickDate: { date in
                Task {
                    await viewModel.requestMove(
                        taskId: row.pending.taskId,
                        taskTitle: row.pending.title,
                        newDate: LearningDeskPanelViewModel.isoDate(date)
                    )
                }
            },
            onDelete: {
                viewModel.deleteCandidate = LearningDeskPanelViewModel.DeleteCandidate(
                    id: row.pending.taskId,
                    taskId: row.pending.taskId,
                    title: row.pending.title
                )
            },
            onReviewPassed: {
                Task { await viewModel.review(taskId: row.pending.taskId, passed: true) }
            },
            onReviewFailed: {
                Task { await viewModel.review(taskId: row.pending.taskId, passed: false) }
            },
            onOpenSourceURL: {
                openSourceURL(row.pending.sourceUrl)
            }
        )
    }

    private func openSourceURL(_ raw: String?) {
        guard let raw, let url = URL(string: raw) else { return }
        NSWorkspace.shared.open(url)
    }

    private func deleteProjectAlertMessage(
        _ candidate: LearningDeskPanelViewModel.DeleteProjectCandidate
    ) -> String {
        if let count = candidate.taskCount, count > 0 {
            return "将删除「\(candidate.name)」及其 \(count) 个任务，此操作不可撤销。"
        }
        return "将删除「\(candidate.name)」，此操作不可撤销。"
    }
}
