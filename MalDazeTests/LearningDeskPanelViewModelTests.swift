import XCTest
@testable import MalDaze

@MainActor
final class LearningDeskPanelViewModelTests: XCTestCase {
    func testRefreshTodayOnlySkipsRollover() async throws {
        let cli = MockHermesScheduleCLI()
        let vm = LearningDeskPanelViewModel(cli: cli)

        await vm.refreshTodayOnly()

        XCTAssertEqual(cli.rolloverCount, 0)
        XCTAssertEqual(cli.fetchTodayCount, 1)
        if case .loaded(let snapshot) = vm.loadState {
            XCTAssertEqual(snapshot.response.date, "2026-06-08")
        } else {
            XCTFail("expected loaded state")
        }
    }

    func testDebouncedRefreshCancelsPriorTask() async {
        let cli = MockHermesScheduleCLI()
        let vm = LearningDeskPanelViewModel(cli: cli)

        vm.scheduleDebouncedRefresh()
        vm.scheduleDebouncedRefresh()
        try? await Task.sleep(nanoseconds: 1_600_000_000)

        XCTAssertEqual(cli.fetchTodayCount, 1)
        XCTAssertEqual(cli.rolloverCount, 0)
    }

    func testScheduleTabDebouncedRefreshUsesScheduleRangeOnly() async {
        let cli = MockHermesScheduleCLI()
        let vm = LearningDeskPanelViewModel(cli: cli)
        vm.selectedTab = .schedule

        vm.scheduleDebouncedRefresh()
        try? await Task.sleep(nanoseconds: 1_600_000_000)

        XCTAssertEqual(cli.scheduleRangeCount, 1)
        XCTAssertEqual(cli.fetchTodayCount, 0)
        XCTAssertEqual(cli.rolloverCount, 0)
    }

    func testProjectsTabDebouncedRefreshUsesStatusOnly() async {
        let cli = MockHermesScheduleCLI()
        let vm = LearningDeskPanelViewModel(cli: cli)
        vm.selectedTab = .projects

        vm.scheduleDebouncedRefresh()
        try? await Task.sleep(nanoseconds: 1_600_000_000)

        XCTAssertEqual(cli.fetchStatusCount, 1)
        XCTAssertEqual(cli.fetchTodayCount, 0)
        XCTAssertEqual(cli.rolloverCount, 0)
    }

    func testCompleteWithActualMinutesForwardsToCLI() async {
        let cli = MockHermesScheduleCLI()
        let vm = LearningDeskPanelViewModel(cli: cli)

        await vm.complete(taskId: "task-1", actualMinutes: 42)

        XCTAssertEqual(cli.lastCompleteActualMinutes, 42)
    }

    func testCompleteInvalidatesStatusCache() async throws {
        let cli = MockHermesScheduleCLI()
        let vm = LearningDeskPanelViewModel(cli: cli)

        await vm.loadToday()
        await vm.loadStatus(force: false)
        let beforeComplete = cli.fetchStatusCount

        await vm.complete(taskId: "t1")
        XCTAssertGreaterThan(cli.fetchStatusCount, beforeComplete)
    }

    func testDeadlineEditFromProjectsTabRefreshesScheduleOnReturn() async throws {
        let cli = MockHermesScheduleCLI()
        let vm = LearningDeskPanelViewModel(cli: cli)
        vm.selectedTab = .schedule
        await vm.loadSchedule(force: true)
        let loadsAfterScheduleVisit = cli.scheduleRangeCount

        vm.selectedTab = .projects
        await vm.loadStatus(force: true)
        guard case .loaded(let projects) = vm.statusLoadState,
              let project = projects.first else {
            XCTFail("expected loaded projects")
            return
        }

        vm.beginDeadlineEdit(project: project)
        await vm.previewDeadlineRepack(projectId: project.projectId, deadline: "2026-09-01")
        await vm.confirmDeadlineEdit(newDeadline: "2026-09-01")

        XCTAssertEqual(cli.scheduleRangeCount, loadsAfterScheduleVisit)

        vm.selectedTab = .schedule
        await vm.onTabChanged()
        XCTAssertGreaterThan(cli.scheduleRangeCount, loadsAfterScheduleVisit)
    }

    func testFocusScheduleOnTodayUsesStartingAtWindow() async {
        let cli = MockHermesScheduleCLI()
        let vm = LearningDeskPanelViewModel(cli: cli)
        await vm.focusScheduleOnToday(reload: true)
        if case .startingAt(let iso) = vm.scheduleDayWindow {
            XCTAssertEqual(iso, LearningDeskPanelViewModel.isoDate(Date()))
        } else {
            XCTFail("expected startingAt day window")
        }
    }

    func testShiftScheduleMonthUsesEntireRangeWindow() async {
        let cli = MockHermesScheduleCLI()
        let vm = LearningDeskPanelViewModel(cli: cli)
        await vm.shiftScheduleMonth(by: -1)
        XCTAssertEqual(vm.scheduleDayWindow, .entireRange)
    }

    func testDeadlinePreviewDisclosesCrossProjectImpact() async {
        let cli = MockHermesScheduleCLI()
        let vm = LearningDeskPanelViewModel(cli: cli)
        await vm.loadStatus(force: true)
        guard case .loaded(let projects) = vm.statusLoadState,
              let project = projects.first else {
            XCTFail("expected loaded projects")
            return
        }

        vm.beginDeadlineEdit(project: project)
        await vm.previewDeadlineRepack(projectId: project.projectId, deadline: "2026-09-01")

        XCTAssertEqual(vm.deadlineRepackPreview?.affectedProjectCount, 2)
        XCTAssertEqual(vm.deadlineRepackPreview?.feasible, true)
    }

    func testInfeasibleDeadlinePreviewBlocksConfirm() async {
        let cli = MockHermesScheduleCLI()
        cli.infeasibleDryRun = true
        let vm = LearningDeskPanelViewModel(cli: cli)
        await vm.loadStatus(force: true)
        guard case .loaded(let projects) = vm.statusLoadState,
              let project = projects.first else {
            XCTFail("expected loaded projects")
            return
        }

        vm.beginDeadlineEdit(project: project)
        await vm.previewDeadlineRepack(projectId: project.projectId, deadline: "2026-06-01")
        XCTAssertEqual(vm.deadlineRepackPreview?.feasible, false)

        await vm.confirmDeadlineEdit(newDeadline: "2026-06-01")
        XCTAssertEqual(cli.applyDeadlineCount, 0)
    }

    func testStatusCacheReusedWithoutSecondFetch() async {
        let cli = MockHermesScheduleCLI()
        let vm = LearningDeskPanelViewModel(cli: cli)

        await vm.loadStatus(force: false)
        XCTAssertEqual(cli.fetchStatusCount, 1)
        await vm.loadStatus(force: false)
        XCTAssertEqual(cli.fetchStatusCount, 1)
        if case .loaded(let projects) = vm.statusLoadState {
            XCTAssertEqual(projects.count, 2)
        } else {
            XCTFail("expected loaded status")
        }
    }

    func testConfirmDeleteProjectUsesCapturedCandidate() async {
        let cli = MockHermesScheduleCLI()
        let vm = LearningDeskPanelViewModel(cli: cli)
        let candidate = LearningDeskPanelViewModel.DeleteProjectCandidate(
            id: "agents",
            projectId: "agents",
            name: "Agent Course",
            taskCount: 19
        )

        await vm.confirmDeleteProject(candidate)

        XCTAssertNil(vm.deleteProjectCandidate)
        XCTAssertEqual(cli.deleteProjectCount, 1)
    }

    func testFileChangeOnTodayTabRefreshesStatusWhenOpeningProjects() async {
        let cli = MockHermesScheduleCLI()
        let vm = LearningDeskPanelViewModel(cli: cli)

        await vm.loadToday()
        await vm.loadStatus(force: false)
        let statusFetchesBeforeChange = cli.fetchStatusCount
        XCTAssertGreaterThanOrEqual(statusFetchesBeforeChange, 1)

        vm.scheduleDebouncedRefresh()
        try? await Task.sleep(nanoseconds: 1_600_000_000)

        vm.selectedTab = .projects
        await vm.onTabChanged()
        XCTAssertGreaterThan(cli.fetchStatusCount, statusFetchesBeforeChange)
    }
}

private final class MockHermesScheduleCLI: HermesScheduleCLI, @unchecked Sendable {
    var rolloverCount = 0
    var fetchTodayCount = 0
    var fetchStatusCount = 0
    var scheduleRangeCount = 0
    var deleteProjectCount = 0
    var applyDeadlineCount = 0
    var infeasibleDryRun = false

    var projectsFileURL: URL {
        URL(fileURLWithPath: "/tmp/projects.json")
    }

    func runRollover() async throws {
        rolloverCount += 1
    }

    func fetchToday() async throws -> HermesTodayResponse {
        fetchTodayCount += 1
        let json = """
        {
          "date": "2026-06-08",
          "is_rest_day": false,
          "pending_count": 0,
          "pending": [],
          "study": { "tasks": [], "total_minutes": 0, "budget": 90 },
          "review": { "tasks": [], "total_minutes": 0, "budget": 60 },
          "progress": { "study": { "done": 0, "total": 0 }, "review": { "done": 0, "total": 0 } },
          "warnings": []
        }
        """
        return try HermesScheduleJSON.decode(HermesTodayResponse.self, from: json)
    }

    var lastCompleteActualMinutes: Int?

    func complete(taskId: String, actualMinutes: Int?) async throws -> HermesCompleteResponse {
        lastCompleteActualMinutes = actualMinutes
        return HermesCompleteResponse(taskId: taskId, status: "completed", error: nil)
    }

    func move(taskId: String, newDate: String, dryRun: Bool) async throws -> HermesMoveResponse {
        HermesMoveResponse(
            action: "move",
            dryRun: dryRun,
            taskId: taskId,
            deltaDays: 1,
            changes: [],
            affectedCount: 0,
            error: nil,
        )
    }

    func insert(projectId: String, title: String, duration: Int, date: String) async throws -> HermesInsertResponse {
        HermesInsertResponse(action: "insert", error: nil)
    }

    func remove(taskId: String) async throws -> HermesRemoveResponse {
        HermesRemoveResponse(action: "remove", error: nil)
    }

    func review(taskId: String, result: String) async throws -> HermesReviewResponse {
        HermesReviewResponse(taskId: taskId, result: result, status: "reviewed", error: nil)
    }

    func weekLoad(fromDate: String?, days: Int) async throws -> HermesWeekLoadResponse {
        HermesWeekLoadResponse(fromDate: fromDate ?? "2026-06-08", days: days, daysData: [])
    }

    func scheduleRange(
        month: String?,
        fromDate: String?,
        toDate: String?
    ) async throws -> HermesScheduleRangeResponse {
        scheduleRangeCount += 1
        return HermesScheduleRangeResponse(
            fromDate: "2026-06-01",
            toDate: "2026-06-30",
            truncated: false,
            deadlines: [],
            days: []
        )
    }

    func fetchStatus() async throws -> [HermesStatusProject] {
        fetchStatusCount += 1
        return [
            HermesStatusProject(
                projectId: "p1", name: "Project A", status: "active",
                deadline: "2026-08-01", progress: "1/3", percent: 33, deadlineExceeded: false,
                nextTask: HermesStatusNextTask(title: "Next", scheduledDate: "2026-06-10", durationMinutes: 45)
            ),
            HermesStatusProject(
                projectId: "p2", name: "Project B", status: "paused",
                deadline: nil, progress: "0/1", percent: 0, deadlineExceeded: nil, nextTask: nil
            ),
        ]
    }

    func setDeadline(projectId: String, deadline: String, dryRun: Bool) async throws -> HermesSetDeadlineResponse {
        if !dryRun { applyDeadlineCount += 1 }
        if dryRun && infeasibleDryRun {
            return HermesSetDeadlineResponse(
                projectId: projectId,
                name: "Project A",
                oldDeadline: "2026-08-01",
                newDeadline: deadline,
                repacked: true,
                repackMode: nil,
                repackScope: "all_active",
                feasible: false,
                affectedProjectIds: [projectId],
                projectCadences: [],
                capacityConflicts: [
                    HermesCapacityConflict(type: "study_capacity_exceeded", date: "2026-06-10", loadMinutes: 521, capacity: 300, overBy: 221)
                ],
                changes: [],
                overflowCount: 2,
                overflowTasks: [],
                deadlineExceeded: true,
                dryRun: true,
                error: nil
            )
        }
        return HermesSetDeadlineResponse(
            projectId: projectId,
            name: "Project A",
            oldDeadline: "2026-08-01",
            newDeadline: deadline,
            repacked: true,
            repackMode: nil,
            repackScope: "all_active",
            feasible: true,
            affectedProjectIds: [projectId, "p2"],
            projectCadences: [
                HermesProjectCadence(
                    projectId: projectId,
                    remainingStudyTasks: 2,
                    eligibleStudyDays: 20,
                    minPreferredDaily: 1,
                    maxPreferredDaily: 1,
                    movedTaskCount: dryRun ? 1 : 0
                )
            ],
            capacityConflicts: [],
            changes: dryRun ? [HermesDeadlineChange(projectId: projectId, taskId: "t1", title: "Next", oldDate: "2026-06-10", newDate: "2026-06-11")] : [],
            overflowCount: 0,
            overflowTasks: [],
            deadlineExceeded: false,
            dryRun: dryRun,
            error: nil
        )
    }

    func deleteProject(projectId: String) async throws -> HermesDeleteProjectResponse {
        deleteProjectCount += 1
        return HermesDeleteProjectResponse(
            action: "delete-project",
            projectId: projectId,
            name: "Deleted",
            tasksRemoved: 1,
            error: nil
        )
    }
}
