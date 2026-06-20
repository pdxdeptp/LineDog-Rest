import XCTest
@testable import MalDaze

final class HermesScheduleModelsTests: XCTestCase {
    func testDecodeTodayResponse() throws {
        let json = """
        {
          "date": "2026-06-08",
          "is_rest_day": false,
          "pending_count": 1,
          "pending": [
            {
              "index": 1,
              "task_id": "lc_review_task_1",
              "title": "Sample",
              "project_id": "lc_review",
              "project_name": "LC",
              "duration_minutes": 45,
              "task_type": "study",
              "scheduled_date": "2026-06-08"
            }
          ],
          "study": {
            "tasks": [
              {
                "project_id": "lc_review",
                "project_name": "LC",
                "task": {
                  "id": "lc_review_task_1",
                  "title": "Sample",
                  "duration_minutes": 45,
                  "auto_roll_days": 2
                }
              }
            ],
            "total_minutes": 45,
            "budget": 90
          },
          "review": { "tasks": [], "total_minutes": 0, "budget": 60 },
          "progress": { "study": { "done": 1, "total": 2 }, "review": { "done": 0, "total": 1 } },
          "warnings": []
        }
        """

        let response = try HermesScheduleJSON.decode(HermesTodayResponse.self, from: json)
        let snapshot = LearningTodaySnapshot.make(from: response)

        XCTAssertEqual(response.pendingCount, 1)
        XCTAssertEqual(snapshot.rows.first?.autoRollDays, 2)
        XCTAssertEqual(response.progress?.study.done, 1)
        XCTAssertEqual(response.progress?.study.total, 2)
    }

    func testDecodeTomorrowPreviewAndSourceUrl() throws {
        let json = """
        {
          "date": "2026-06-08",
          "is_rest_day": false,
          "pending_count": 1,
          "pending": [
            {
              "index": 1,
              "task_id": "t1",
              "title": "Lesson",
              "project_id": "p1",
              "project_name": "LC",
              "duration_minutes": 45,
              "task_type": "study",
              "scheduled_date": "2026-06-08",
              "source_url": "https://example.com"
            }
          ],
          "study": { "tasks": [], "total_minutes": 45, "budget": 300 },
          "review": { "tasks": [], "total_minutes": 0, "budget": 60 },
          "progress": { "study": { "done": 0, "total": 1 }, "review": { "done": 0, "total": 0 } },
          "tomorrow_preview": {
            "date": "2026-06-09",
            "pending_count": 2,
            "study_minutes": 90,
            "study_budget": 300,
            "is_rest_day": false,
            "tasks": [
              { "index": 1, "task_id": "t2", "title": "Next", "project_name": "LC", "duration_minutes": 45 }
            ]
          },
          "warnings": []
        }
        """
        let response = try HermesScheduleJSON.decode(HermesTodayResponse.self, from: json)
        XCTAssertEqual(response.pending.first?.sourceUrl, "https://example.com")
        XCTAssertEqual(response.tomorrowPreview?.pendingCount, 2)
        XCTAssertEqual(response.tomorrowPreview?.tasks.first?.title, "Next")
    }

    func testProjectSectionsPreservePendingOrder() throws {
        let json = """
        {
          "date": "2026-06-08",
          "is_rest_day": false,
          "pending_count": 3,
          "pending": [
            { "index": 1, "task_id": "a", "title": "A", "project_id": "p1", "project_name": "LC", "duration_minutes": 30, "task_type": "study", "scheduled_date": "2026-06-08" },
            { "index": 2, "task_id": "b", "title": "B", "project_id": "p2", "project_name": "Agent", "duration_minutes": 20, "task_type": "study", "scheduled_date": "2026-06-08" },
            { "index": 3, "task_id": "c", "title": "C", "project_id": "p1", "project_name": "LC", "duration_minutes": 15, "task_type": "study", "scheduled_date": "2026-06-08" }
          ],
          "study": { "tasks": [], "total_minutes": 65, "budget": 300 },
          "review": { "tasks": [], "total_minutes": 0, "budget": 60 },
          "progress": { "study": { "done": 0, "total": 3 }, "review": { "done": 0, "total": 0 } },
          "warnings": []
        }
        """
        let response = try HermesScheduleJSON.decode(HermesTodayResponse.self, from: json)
        let snapshot = LearningTodaySnapshot.make(from: response)
        let sections = LearningTodaySnapshot.projectSections(from: snapshot.rows)
        XCTAssertEqual(sections.map(\.projectName), ["LC", "Agent"])
        XCTAssertEqual(sections[0].rows.map(\.pending.taskId), ["a", "c"])
    }

    func testDecodeMoveDryRun() throws {
        let json = """
        {
          "action": "move",
          "dry_run": true,
          "task_id": "t1",
          "delta_days": 1,
          "changes": [
            { "task_id": "t1", "title": "A", "old_date": "2026-06-07", "new_date": "2026-06-08" }
          ],
          "affected_count": 1
        }
        """

        let move = try HermesScheduleJSON.decode(HermesMoveResponse.self, from: json)
        XCTAssertTrue(move.dryRun == true)
        XCTAssertEqual(move.changes.count, 1)
        XCTAssertTrue(move.succeeded)
    }

    func testPendingAutoRollDaysFromPendingField() throws {
        let json = """
        {
          "date": "2026-06-08",
          "is_rest_day": false,
          "pending_count": 1,
          "pending": [
            {
              "index": 1,
              "task_id": "t1",
              "title": "Rolled",
              "project_id": "p1",
              "project_name": "P",
              "duration_minutes": 30,
              "task_type": "study",
              "scheduled_date": "2026-06-08",
              "auto_roll_days": 3
            }
          ],
          "study": { "tasks": [], "total_minutes": 30, "budget": 90 },
          "review": { "tasks": [], "total_minutes": 0, "budget": 60 },
          "warnings": []
        }
        """

        let response = try HermesScheduleJSON.decode(HermesTodayResponse.self, from: json)
        let snapshot = LearningTodaySnapshot.make(from: response)
        XCTAssertEqual(snapshot.rows.first?.autoRollDays, 3)
    }

    func testDecodeWeekLoadResponse() throws {
        let json = """
        {
          "from_date": "2026-06-08",
          "days": 2,
          "days_data": [
            {
              "date": "2026-06-08",
              "total_minutes": 120,
              "budget": 90,
              "over_capacity": true,
              "is_rest_day": false
            },
            {
              "date": "2026-06-09",
              "total_minutes": 0,
              "budget": 0,
              "over_capacity": false,
              "is_rest_day": true
            }
          ]
        }
        """

        let week = try HermesScheduleJSON.decode(HermesWeekLoadResponse.self, from: json)
        XCTAssertEqual(week.daysData.count, 2)
        XCTAssertTrue(week.daysData[0].overCapacity)
        XCTAssertTrue(week.daysData[1].isRestDay)
    }

    func testActiveProjectOptionsFromStatus() throws {
        let json = """
        [
          { "project_id": "b", "name": "Beta", "status": "active" },
          { "project_id": "a", "name": "Alpha", "status": "active" },
          { "project_id": "z", "name": "Zzz", "status": "paused" }
        ]
        """
        let status = try HermesScheduleJSON.decode([HermesStatusProject].self, from: json)
        let options = HermesActiveProjects.options(from: status)
        XCTAssertEqual(options.map(\.id), ["a", "b"])
    }

    func testLearningCapacityFormattingHours() {
        XCTAssertEqual(LearningCapacityFormatting.formatLoad(totalMinutes: 148, budgetMinutes: 300), "2.5 小时 / 5 小时")
        XCTAssertEqual(LearningCapacityFormatting.formatHours(fromMinutes: 90), "1.5 小时")
        XCTAssertEqual(LearningCapacityFormatting.minutes(fromHours: 5), 300)
    }

    func testDecodeStatusProjectWithNextTask() throws {
        let json = """
        [
          {
            "project_id": "lc_review",
            "name": "LC Review",
            "status": "active",
            "deadline": "2026-08-15",
            "progress": "1/27",
            "percent": 4,
            "next_task": {
              "title": "Ch4",
              "scheduled_date": "2026-06-08",
              "duration_minutes": 45
            }
          }
        ]
        """
        let projects = try HermesScheduleJSON.decode([HermesStatusProject].self, from: json)
        XCTAssertEqual(projects.first?.nextTask?.title, "Ch4")
        XCTAssertEqual(projects.first?.nextTask?.durationMinutes, 45)
    }

    func testDecodeScheduleRangeResponse() throws {
        let json = """
        {
          "from_date": "2026-06-01",
          "to_date": "2026-07-16",
          "truncated": false,
          "deadlines": [
            { "project_id": "lc_review", "name": "LC", "deadline": "2026-07-16" }
          ],
          "days": [
            {
              "date": "2026-06-09",
              "is_rest_day": false,
              "study_minutes": 77,
              "review_minutes": 0,
              "budget_study": 180,
              "budget_review": 60,
              "over_capacity": false,
              "tasks": [
                {
                  "task_id": "lc_review_task_3",
                  "project_id": "lc_review",
                  "project_name": "LC",
                  "title": "Lesson 3",
                  "duration_minutes": 77,
                  "task_type": null,
                  "status": "pending",
                  "after_project_deadline": false
                }
              ]
            }
          ]
        }
        """
        let response = try HermesScheduleJSON.decode(HermesScheduleRangeResponse.self, from: json)
        XCTAssertEqual(response.days.count, 1)
        XCTAssertEqual(response.days.first?.tasks.first?.taskId, "lc_review_task_3")
    }

    func testDecodeSetDeadlineResponse() throws {
        let json = """
        {
          "project_id": "lc_review",
          "name": "LC Review",
          "old_deadline": "2026-07-01",
          "new_deadline": "2026-08-15",
          "repacked": true,
          "repack_scope": "all_active",
          "feasible": true,
          "affected_project_ids": ["lc_review", "agents"],
          "project_cadences": [
            {
              "project_id": "lc_review",
              "remaining_study_tasks": 25,
              "eligible_study_days": 25,
              "min_preferred_daily": 1,
              "max_preferred_daily": 1,
              "moved_task_count": 3
            }
          ],
          "changes": [
            {
              "project_id": "lc_review",
              "task_id": "lc_review_task_2",
              "title": "Ch2",
              "old_date": "2026-06-08",
              "new_date": "2026-06-09"
            }
          ],
          "overflow_count": 0,
          "overflow_tasks": [],
          "capacity_conflicts": [],
          "deadline_exceeded": false
        }
        """
        let response = try HermesScheduleJSON.decode(HermesSetDeadlineResponse.self, from: json)
        XCTAssertTrue(response.succeeded)
        XCTAssertEqual(response.repackScope, "all_active")
        XCTAssertEqual(response.feasible, true)
        XCTAssertEqual(response.affectedProjectIds?.count, 2)
        XCTAssertEqual(response.projectCadences?.first?.minPreferredDaily, 1)
        XCTAssertEqual(response.changes?.first?.projectId, "lc_review")
    }

    func testDecodeInfeasibleSetDeadlineResponse() throws {
        let json = """
        {
          "project_id": "lc_review",
          "name": "LC Review",
          "old_deadline": "2026-07-01",
          "new_deadline": "2026-06-01",
          "repacked": true,
          "repack_scope": "all_active",
          "feasible": false,
          "overflow_count": 2,
          "overflow_tasks": [
            { "project_id": "lc_review", "task_id": "t1", "title": "A", "scheduled_date": "2026-06-10" }
          ],
          "capacity_conflicts": [
            { "type": "study_capacity_exceeded", "date": "2026-06-10", "load_minutes": 521, "capacity": 300, "over_by": 221 }
          ],
          "changes": [],
          "deadline_exceeded": true,
          "dry_run": true
        }
        """
        let response = try HermesScheduleJSON.decode(HermesSetDeadlineResponse.self, from: json)
        XCTAssertFalse(response.isFeasiblePreview)
        XCTAssertEqual(response.capacityConflicts?.first?.overBy, 221)
    }

    func testDecodeDeleteProjectResponse() throws {
        let json = """
        {
          "action": "delete-project",
          "project_id": "agents",
          "name": "Agent Course",
          "tasks_removed": 19
        }
        """
        let response = try HermesScheduleJSON.decode(HermesDeleteProjectResponse.self, from: json)
        XCTAssertTrue(response.succeeded)
        XCTAssertEqual(response.projectId, "agents")
        XCTAssertEqual(response.tasksRemoved, 19)
    }

    func testProjectStatusOrderingActiveFirst() {
        let projects = [
            HermesStatusProject(projectId: "z", name: "Zeta", status: "paused", deadline: nil, progress: nil, percent: nil, deadlineExceeded: nil, nextTask: nil),
            HermesStatusProject(projectId: "b", name: "Beta", status: "active", deadline: nil, progress: nil, percent: nil, deadlineExceeded: nil, nextTask: nil),
            HermesStatusProject(projectId: "a", name: "Alpha", status: "active", deadline: nil, progress: nil, percent: nil, deadlineExceeded: nil, nextTask: nil),
        ]
        let sorted = LearningProjectStatusOrdering.sorted(projects)
        XCTAssertEqual(sorted.map(\.projectId), ["a", "b", "z"])
    }

    func testDecodeErrorEnvelope() {
        XCTAssertThrowsError(
            try HermesScheduleJSON.decode(HermesTodayResponse.self, from: #"{"error":"Cannot move task before today"}"#)
        ) { error in
            XCTAssertEqual((error as? HermesCLIError)?.message, "Cannot move task before today")
        }
    }
}
