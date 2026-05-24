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

    // MARK: Study Plan v2 Draft Flow

    func testStudyPlanClarificationDecodesBoundedQuestionsDefaultsAndSkipAction() throws {
        let json = """
        {
            "version": "d30-guided-clarification-v1",
            "material_type": "documentation",
            "questions": [
                {
                    "id": "level_familiarity",
                    "prompt": "What is your current level?",
                    "options": [
                        {
                            "id": "recommended",
                            "label": "Use recommended familiarity",
                            "value": "some_familiarity",
                            "recommended": true,
                            "default": true
                        },
                        {
                            "id": "unsure_recommended",
                            "label": "Not sure / use recommended",
                            "value": "some_familiarity",
                            "uses_default": true
                        }
                    ]
                },
                {
                    "id": "goal_depth",
                    "prompt": "What goal should guide the plan?",
                    "allows_custom_text": false,
                    "options": []
                },
                {
                    "id": "focus_scope",
                    "prompt": "What focus or skip scope should guide the draft plan?",
                    "allows_custom_text": true,
                    "options": []
                }
            ],
            "defaults": {
                "level_familiarity": "some_familiarity",
                "goal_depth": "understand_and_apply",
                "focus_scope": "Consensus and replication"
            },
            "skip_action": {
                "id": "generate_rough_draft",
                "label": "Generate rough draft",
                "uses_defaults": true
            }
        }
        """

        let clarification = try decode(StudyPlanClarification.self, from: json)

        XCTAssertEqual(clarification.version, "d30-guided-clarification-v1")
        XCTAssertEqual(clarification.materialType, "documentation")
        XCTAssertLessThanOrEqual(clarification.questions.count, 3)
        XCTAssertFalse(clarification.questions[0].allowsCustomText)
        XCTAssertTrue(clarification.questions[2].allowsCustomText)
        XCTAssertEqual(clarification.defaults["focus_scope"], "Consensus and replication")
        XCTAssertEqual(clarification.skipAction.id, "generate_rough_draft")
        XCTAssertTrue(clarification.skipAction.usesDefaults)
        XCTAssertTrue(clarification.questions[0].options[0].recommended)
        XCTAssertTrue(clarification.questions[0].options[0].isDefault)
        XCTAssertTrue(clarification.questions[0].options[1].usesDefault)
    }

    func testStudyPlanStartResponseDecodesDraftIdAndClarificationWrapper() throws {
        let json = """
        {
            "draft_id": 42,
            "clarification": {
                "version": "d30-guided-clarification-v1",
                "material_type": "documentation",
                "questions": [
                    {
                        "id": "goal_depth",
                        "prompt": "What learning goal and target depth should the plan aim for?",
                        "options": [
                            {
                                "id": "recommended",
                                "label": "Use recommended goal",
                                "value": "understand_and_apply",
                                "recommended": true,
                                "default": true
                            }
                        ]
                    }
                ],
                "defaults": {
                    "goal_depth": "understand_and_apply"
                },
                "skip_action": {
                    "id": "generate_rough_draft",
                    "label": "Generate rough draft",
                    "uses_defaults": true
                }
            }
        }
        """

        let response = try decode(StudyPlanStartResponse.self, from: json)

        XCTAssertEqual(response.draftId, 42)
        XCTAssertEqual(response.clarification.version, "d30-guided-clarification-v1")
        XCTAssertEqual(response.clarification.materialType, "documentation")
        XCTAssertEqual(response.clarification.questions.first?.allowsCustomText, false)
        XCTAssertEqual(response.clarification.defaults["goal_depth"], "understand_and_apply")
    }

    func testStudyPlanSkipClarificationResponseDecodesDefaultsAndLowCalibrationMarker() throws {
        let json = """
        {
            "answers": {
                "level_familiarity": "some_familiarity",
                "goal_depth": "understand_and_apply"
            },
            "defaults": {
                "level_familiarity": "some_familiarity",
                "goal_depth": "understand_and_apply"
            },
            "clarification_skipped": true,
            "low_calibration": true
        }
        """

        let response = try decode(StudyPlanSkipClarificationResponse.self, from: json)

        XCTAssertEqual(response.answers["goal_depth"], "understand_and_apply")
        XCTAssertEqual(response.defaults["level_familiarity"], "some_familiarity")
        XCTAssertTrue(response.clarificationSkipped)
        XCTAssertTrue(response.lowCalibration)
    }

    func testStudyPlanDraftDecodesReviewStateTasksAndCapacityWarnings() throws {
        let json = """
        {
            "id": 42,
            "title": "Distributed Systems Primer",
            "source_url": "https://example.com/distributed-systems",
            "deadline": "2026-06-30",
            "status": "review",
            "capacity_minutes": 75,
            "clarification_skipped": true,
            "low_calibration": true,
            "tasks": [
                {
                    "title": "Read clocks chapter",
                    "order_index": 0,
                    "estimated_minutes": 45,
                    "scheduled_date": "2026-06-20",
                    "target_minutes": 45
                },
                {
                    "title": "Practice consensus exercises",
                    "order_index": 1,
                    "estimated_minutes": 90,
                    "scheduled_date": "2026-06-21",
                    "target_minutes": 75
                }
            ],
            "expected_late": true,
            "over_capacity_days": [
                {
                    "date": "2026-06-21",
                    "scheduled_minutes": 90,
                    "existing_minutes": 20,
                    "capacity_minutes": 75,
                    "over_by_minutes": 35
                }
            ]
        }
        """

        let draft = try decode(StudyPlanDraft.self, from: json)

        XCTAssertEqual(draft.id, 42)
        XCTAssertEqual(draft.title, "Distributed Systems Primer")
        XCTAssertEqual(draft.sourceURL, URL(string: "https://example.com/distributed-systems"))
        XCTAssertEqual(draft.status, "review")
        XCTAssertEqual(draft.capacityMinutes, 75)
        XCTAssertTrue(draft.clarificationSkipped)
        XCTAssertTrue(draft.lowCalibration)
        XCTAssertTrue(draft.expectedLate)
        XCTAssertEqual(draft.tasks.map(\.orderIndex), [0, 1])
        XCTAssertEqual(draft.tasks[1].estimatedMinutes, 90)
        XCTAssertEqual(draft.tasks[1].targetMinutes, 75)
        XCTAssertEqual(draft.overCapacityDays.first?.overByMinutes, 35)
    }

    func testStudyPlanRequestBodiesEncodeSnakeCaseFields() throws {
        let start = StudyPlanStartRequest(
            url: "https://example.com/course",
            deadline: "2026-07-01",
            capacityMinutes: 60
        )
        let clarification = StudyPlanClarificationSubmission(
            answers: ["goal_depth": "apply"],
            clarificationSkipped: true
        )
        let duration = StudyPlanDraftTaskDurationUpdateRequest(estimatedMinutes: 35)

        let startPayload = try jsonDictionary(from: start)
        XCTAssertEqual(startPayload["url"] as? String, "https://example.com/course")
        XCTAssertEqual(startPayload["deadline"] as? String, "2026-07-01")
        XCTAssertEqual(startPayload["capacity_minutes"] as? Int, 60)
        XCTAssertNil(startPayload["capacityMinutes"])

        let clarificationPayload = try jsonDictionary(from: clarification)
        XCTAssertEqual(clarificationPayload["clarification_skipped"] as? Bool, true)
        XCTAssertNil(clarificationPayload["clarificationSkipped"])
        let answers = clarificationPayload["answers"] as? [String: String]
        XCTAssertEqual(answers?["goal_depth"], "apply")

        let durationPayload = try jsonDictionary(from: duration)
        XCTAssertEqual(durationPayload["estimated_minutes"] as? Int, 35)
        XCTAssertNil(durationPayload["estimatedMinutes"])
    }

    func testStudyPlanActivationResultDecodesConfirmPayload() throws {
        let json = """
        {
            "id": 42,
            "resource_id": 101,
            "status": "active",
            "source_url": "https://example.com/distributed-systems",
            "deadline": "2026-06-30",
            "capacity_minutes": 75,
            "clarification_skipped": true
        }
        """

        let result = try decode(StudyPlanActivationResult.self, from: json)

        XCTAssertEqual(result.id, 42)
        XCTAssertEqual(result.resourceId, 101)
        XCTAssertEqual(result.status, "active")
        XCTAssertEqual(result.sourceURL, URL(string: "https://example.com/distributed-systems"))
        XCTAssertEqual(result.deadline, "2026-06-30")
        XCTAssertEqual(result.capacityMinutes, 75)
        XCTAssertTrue(result.clarificationSkipped)
    }

    func testAssistantAPIClientDefinesStudyPlanDraftFlowEndpoints() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantAPIClient.swift")

        XCTAssertTrue(source.contains("func startStudyPlan"))
        XCTAssertTrue(source.contains("-> StudyPlanStartResponse"))
        XCTAssertTrue(source.contains("func submitStudyPlanClarification"))
        XCTAssertTrue(source.contains("func updateStudyPlanDraftTaskDuration"))
        XCTAssertTrue(source.contains("func cancelStudyPlanDraft"))
        XCTAssertTrue(source.contains("func confirmStudyPlanDraft"))
        XCTAssertTrue(source.contains("\"/api/study-plan/start\""))
        XCTAssertTrue(source.contains("\"/api/study-plan/drafts/\\(draftId)/clarification\""))
        XCTAssertTrue(source.contains("\"/api/study-plan/drafts/\\(draftId)/tasks/\\(taskOrderIndex)/duration\""))
        XCTAssertTrue(source.contains("\"/api/study-plan/drafts/\\(draftId)/cancel\""))
        XCTAssertTrue(source.contains("\"/api/study-plan/drafts/\\(draftId)/confirm\""))
    }

    // MARK: Study Views

    func testStudyTodayViewDecodesTaskProjectResourceAndUnitFieldsWithSafeURLs() throws {
        let json = """
        {
            "date": "2026-05-23",
            "tasks": [
                {
                    "id": 10,
                    "title": "Read Swift Concurrency chapter",
                    "target_minutes": 45,
                    "completed_at": null,
                    "project_id": 2,
                    "project_title": "Swift Concurrency",
                    "resource_id": 7,
                    "resource_title": "Concurrency Guide",
                    "resource_url": "https://example.com/resource",
                    "unit_id": 11,
                    "unit_title": "Structured concurrency",
                    "unit_url": "http://example.com/unit"
                },
                {
                    "id": 11,
                    "title": "Review unsafe links",
                    "target_minutes": 10,
                    "completed_at": "2026-05-23T15:30:00",
                    "project_id": null,
                    "project_title": null,
                    "resource_id": null,
                    "resource_title": null,
                    "resource_url": "file:///Users/cpt/.ssh/id_rsa",
                    "unit_id": null,
                    "unit_title": null,
                    "unit_url": "maliciousapp://open"
                }
            ]
        }
        """

        let view = try decode(StudyTodayView.self, from: json)

        XCTAssertEqual(view.date, "2026-05-23")
        XCTAssertEqual(view.tasks.count, 2)
        XCTAssertEqual(view.tasks[0].id, 10)
        XCTAssertEqual(view.tasks[0].targetMinutes, 45)
        XCTAssertNil(view.tasks[0].completedAt)
        XCTAssertEqual(view.tasks[0].projectId, 2)
        XCTAssertEqual(view.tasks[0].projectTitle, "Swift Concurrency")
        XCTAssertEqual(view.tasks[0].resourceId, 7)
        XCTAssertEqual(view.tasks[0].resourceTitle, "Concurrency Guide")
        XCTAssertEqual(view.tasks[0].resourceURL, URL(string: "https://example.com/resource"))
        XCTAssertEqual(view.tasks[0].unitId, 11)
        XCTAssertEqual(view.tasks[0].unitTitle, "Structured concurrency")
        XCTAssertEqual(view.tasks[0].unitURL, URL(string: "http://example.com/unit"))
        XCTAssertTrue(view.tasks[1].isCompleted)
        XCTAssertNil(view.tasks[1].resourceURL)
        XCTAssertNil(view.tasks[1].unitURL)
    }

    func testStudyProjectOverviewDecodesActiveAndCompletedSections() throws {
        let json = """
        {
            "active_projects": [
                {
                    "id": 1,
                    "title": "Swift Concurrency",
                    "completed_units": 3,
                    "total_units": 10,
                    "progress_ratio": 0.3,
                    "target_minutes": 450,
                    "actual_minutes": 120,
                    "deadline": "2026-06-01",
                    "status": "active"
                }
            ],
            "completed_projects": [
                {
                    "id": 2,
                    "title": "Algorithms",
                    "completed_units": 8,
                    "total_units": 8,
                    "progress_ratio": 1.0,
                    "target_minutes": 360,
                    "actual_minutes": 390,
                    "deadline": null,
                    "status": "completed"
                }
            ]
        }
        """

        let overview = try decode(StudyProjectOverview.self, from: json)

        XCTAssertEqual(overview.activeProjects.count, 1)
        XCTAssertEqual(overview.completedProjects.count, 1)
        XCTAssertEqual(overview.activeProjects[0].completedUnits, 3)
        XCTAssertEqual(overview.activeProjects[0].totalUnits, 10)
        XCTAssertEqual(overview.activeProjects[0].progressRatio, 0.3, accuracy: 0.001)
        XCTAssertEqual(overview.activeProjects[0].targetMinutes, 450)
        XCTAssertEqual(overview.activeProjects[0].actualMinutes, 120)
        XCTAssertEqual(overview.activeProjects[0].deadline, "2026-06-01")
        XCTAssertEqual(overview.completedProjects[0].status, "completed")
    }

    func testStudyCalendarLoadDecodesCapacityAndDays() throws {
        let json = """
        {
            "start_date": "2026-05-23",
            "end_date": "2026-05-30",
            "daily_capacity_minutes": 75,
            "days": [
                {
                    "date": "2026-05-23",
                    "scheduled_task_count": 2,
                    "total_target_minutes": 80,
                    "completed_task_count": 1,
                    "over_capacity": true
                },
                {
                    "date": "2026-05-24",
                    "scheduled_task_count": 0,
                    "total_target_minutes": 0,
                    "completed_task_count": 0,
                    "over_capacity": false
                }
            ]
        }
        """

        let load = try decode(StudyCalendarLoad.self, from: json)

        XCTAssertEqual(load.startDate, "2026-05-23")
        XCTAssertEqual(load.endDate, "2026-05-30")
        XCTAssertEqual(load.dailyCapacityMinutes, 75)
        XCTAssertEqual(load.days.count, 2)
        XCTAssertEqual(load.days[0].scheduledTaskCount, 2)
        XCTAssertEqual(load.days[0].totalTargetMinutes, 80)
        XCTAssertEqual(load.days[0].completedTaskCount, 1)
        XCTAssertTrue(load.days[0].overCapacity)
        XCTAssertFalse(load.days[1].overCapacity)
    }

    func testStudyViewsDecodeAdjustmentFacts() throws {
        let todayJSON = """
        {
            "date": "2026-06-01",
            "tasks": [
                {
                    "id": 42,
                    "title": "Rolled task",
                    "target_minutes": 45,
                    "completed_at": null,
                    "project_id": 7,
                    "project_title": "Swift",
                    "resource_id": 7,
                    "resource_title": "Swift",
                    "resource_url": "https://example.com/swift",
                    "unit_id": 8,
                    "unit_title": "Actors",
                    "unit_url": "https://example.com/actors",
                    "rolled_day_count": 3,
                    "show_rolled_badge": true
                }
            ]
        }
        """
        let overviewJSON = """
        {
            "active_projects": [
                {
                    "id": 7,
                    "title": "Swift",
                    "completed_units": 1,
                    "total_units": 4,
                    "progress_ratio": 0.25,
                    "target_minutes": 200,
                    "actual_minutes": 50,
                    "deadline": "2026-06-03",
                    "expected_late": true,
                    "status": "active"
                }
            ],
            "completed_projects": []
        }
        """
        let calendarJSON = """
        {
            "start_date": "2026-06-01",
            "end_date": "2026-06-02",
            "daily_capacity_minutes": 75,
            "days": [
                {
                    "date": "2026-06-01",
                    "scheduled_task_count": 2,
                    "total_target_minutes": 90,
                    "completed_task_count": 0,
                    "rest_day": true,
                    "available_capacity_minutes": 0,
                    "over_capacity": true
                }
            ]
        }
        """

        let today = try decode(StudyTodayView.self, from: todayJSON)
        let overview = try decode(StudyProjectOverview.self, from: overviewJSON)
        let calendar = try decode(StudyCalendarLoad.self, from: calendarJSON)

        XCTAssertEqual(today.tasks.first?.rolledDayCount, 3)
        XCTAssertEqual(today.tasks.first?.showRolledBadge, true)
        XCTAssertEqual(overview.activeProjects.first?.expectedLate, true)
        XCTAssertEqual(calendar.days.first?.restDay, true)
        XCTAssertEqual(calendar.days.first?.availableCapacityMinutes, 0)
        XCTAssertEqual(calendar.days.first?.overCapacity, true)
    }

    func testStudyPlanAdjustmentRequestBodiesEncodeSnakeCaseFields() throws {
        let move = StudyTaskMoveRequest(scheduledDate: "2026-06-05")
        let deadline = StudyProjectDeadlineUpdateRequest(deadline: "2026-06-30")
        let insert = StudyTaskInsertRequest(
            title: "Practice actors",
            targetMinutes: 40,
            scheduledDate: "2026-06-06"
        )
        let restDays = StudyRestDaySettings(
            weeklyWeekdays: [5, 6],
            oneOffDates: ["2026-06-10"]
        )
        let dialogue = StudyDialogueAdjustmentRequest(
            instruction: "push this project by one week",
            projectId: 7
        )

        let movePayload = try jsonDictionary(from: move)
        XCTAssertEqual(movePayload["scheduled_date"] as? String, "2026-06-05")
        XCTAssertNil(movePayload["scheduledDate"])

        let deadlinePayload = try jsonDictionary(from: deadline)
        XCTAssertEqual(deadlinePayload["deadline"] as? String, "2026-06-30")

        let insertPayload = try jsonDictionary(from: insert)
        XCTAssertEqual(insertPayload["title"] as? String, "Practice actors")
        XCTAssertEqual(insertPayload["target_minutes"] as? Int, 40)
        XCTAssertEqual(insertPayload["scheduled_date"] as? String, "2026-06-06")
        XCTAssertNil(insertPayload["targetMinutes"])
        XCTAssertNil(insertPayload["scheduledDate"])

        let restPayload = try jsonDictionary(from: restDays)
        XCTAssertEqual(restPayload["weekly_weekdays"] as? [Int], [5, 6])
        XCTAssertEqual(restPayload["one_off_dates"] as? [String], ["2026-06-10"])

        let dialoguePayload = try jsonDictionary(from: dialogue)
        XCTAssertEqual(dialoguePayload["instruction"] as? String, "push this project by one week")
        XCTAssertEqual(dialoguePayload["project_id"] as? Int, 7)
        XCTAssertNil(dialoguePayload["projectId"])
    }

    func testStudyPlanAdjustmentResultsDecodeBackendPayloads() throws {
        let rolloverJSON = """
        {
            "date": "2026-06-01",
            "rolled_count": 1,
            "rolled_tasks": [
                {
                    "task_id": 42,
                    "project_id": 7,
                    "old_date": "2026-05-29",
                    "new_date": "2026-06-01",
                    "rolled_days": 3,
                    "auto_roll_days": 5
                }
            ]
        }
        """
        let moveJSON = """
        {
            "task_id": 42,
            "source": "manual_move",
            "affected_count": 2,
            "changes": [
                {"task_id": 42, "project_id": 7, "old_date": "2026-06-01", "new_date": "2026-06-03"},
                {"task_id": 43, "project_id": 7, "old_date": "2026-06-02", "new_date": "2026-06-04"}
            ]
        }
        """
        let restUpdateJSON = """
        {
            "weekly_weekdays": [5],
            "one_off_dates": ["2026-06-10"],
            "added_weekly_weekdays": [5],
            "removed_weekly_weekdays": [],
            "added_one_off_dates": ["2026-06-10"],
            "removed_one_off_dates": [],
            "source": "manual_rest_day_settings"
        }
        """
        let previewJSON = """
        {
            "status": "preview",
            "source": "dialogue_preview",
            "command": "project_shift",
            "project_id": 7,
            "delta_days": 7,
            "affected_task_ids": [42, 43],
            "changes": [
                {"task_id": 42, "project_id": 7, "old_date": "2026-06-01", "new_date": "2026-06-08"}
            ],
            "red_state_impact": {
                "expected_late": {"before": false, "after": true},
                "over_capacity": {
                    "before_dates": [],
                    "after_dates": ["2026-06-08"],
                    "new_over_capacity_dates": ["2026-06-08"]
                }
            },
            "mutates": false
        }
        """
        let applyJSON = """
        {
            "status": "applied",
            "source": "dialogue_apply",
            "command": "project_shift",
            "project_id": 7,
            "delta_days": 7,
            "affected_task_ids": [42],
            "changes": [
                {"task_id": 42, "project_id": 7, "old_date": "2026-06-01", "new_date": "2026-06-08"}
            ],
            "mutates": true,
            "refresh": {"today": true, "project_overview": true, "calendar": true}
        }
        """

        let rollover = try decode(StudyRolloverResult.self, from: rolloverJSON)
        let move = try decode(StudyTaskMoveResult.self, from: moveJSON)
        let restUpdate = try decode(StudyRestDaySettingsUpdateResult.self, from: restUpdateJSON)
        let preview = try decode(StudyDialogueAdjustmentPreview.self, from: previewJSON)
        let apply = try decode(StudyDialogueAdjustmentApplyResult.self, from: applyJSON)

        XCTAssertEqual(rollover.rolledCount, 1)
        XCTAssertEqual(rollover.rolledTasks.first?.autoRollDays, 5)
        XCTAssertEqual(move.source, "manual_move")
        XCTAssertEqual(move.changes.map(\.newDate), ["2026-06-03", "2026-06-04"])
        XCTAssertEqual(restUpdate.addedOneOffDates, ["2026-06-10"])
        XCTAssertEqual(preview.redStateImpact?.expectedLate?.after, true)
        XCTAssertEqual(preview.redStateImpact?.overCapacity?.newOverCapacityDates, ["2026-06-08"])
        XCTAssertEqual(apply.refresh?.projectOverview, true)
    }

    func testDialogueApplyRequestEncodesTypedPreviewObject() throws {
        let preview = StudyDialogueAdjustmentPreview(
            status: "preview",
            source: "dialogue_preview",
            command: "project_shift",
            projectId: 7,
            deltaDays: 7,
            affectedTaskIds: [42],
            changes: [
                StudyAdjustmentChange(
                    taskId: 42,
                    projectId: 7,
                    oldDate: "2026-06-01",
                    newDate: "2026-06-08"
                )
            ],
            redStateImpact: StudyRedStateImpact(
                expectedLate: StudyExpectedLateImpact(before: false, after: true),
                overCapacity: StudyOverCapacityImpact(
                    beforeDates: [],
                    afterDates: ["2026-06-08"],
                    newOverCapacityDates: ["2026-06-08"]
                )
            ),
            mutates: false,
            message: nil
        )
        let request = StudyDialogueAdjustmentApplyRequest(
            instruction: "push this project by one week",
            projectId: 7,
            preview: preview
        )

        let payload = try jsonDictionary(from: request)
        let encodedPreview = try XCTUnwrap(payload["preview"] as? [String: Any])
        let redStateImpact = try XCTUnwrap(encodedPreview["red_state_impact"] as? [String: Any])
        let expectedLate = try XCTUnwrap(redStateImpact["expected_late"] as? [String: Any])
        let overCapacity = try XCTUnwrap(redStateImpact["over_capacity"] as? [String: Any])

        XCTAssertEqual(payload["instruction"] as? String, "push this project by one week")
        XCTAssertEqual(payload["project_id"] as? Int, 7)
        XCTAssertEqual(encodedPreview["command"] as? String, "project_shift")
        XCTAssertEqual(expectedLate["after"] as? Bool, true)
        XCTAssertEqual(overCapacity["new_over_capacity_dates"] as? [String], ["2026-06-08"])
    }

    func testStudyPlanAdjustmentClientRequestsUseExpectedMethodsPathsAndBodies() async throws {
        let rolloverClient = makeRecordingClient(responseBody: """
        {"date":"2026-06-01","rolled_count":0,"rolled_tasks":[]}
        """)
        _ = try await rolloverClient.rolloverStudyTasks()
        var request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/study-plan-adjustment/rollover")

        let moveClient = makeRecordingClient(responseBody: """
        {"task_id":42,"source":"manual_move","affected_count":1,"changes":[{"task_id":42,"project_id":7,"old_date":"2026-06-01","new_date":"2026-06-05"}]}
        """)
        _ = try await moveClient.moveStudyTask(id: 42, scheduledDate: "2026-06-05")
        request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        var body = try XCTUnwrap(request.httpBodyStreamData)
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/study-plan-adjustment/tasks/42/move")
        XCTAssertEqual(payload["scheduled_date"] as? String, "2026-06-05")

        let deadlineClient = makeRecordingClient(responseBody: """
        {"project_id":7,"old_deadline":"2026-06-01","new_deadline":"2026-06-30","source":"deadline_edit"}
        """)
        _ = try await deadlineClient.updateStudyProjectDeadline(projectId: 7, deadline: "2026-06-30")
        request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        body = try XCTUnwrap(request.httpBodyStreamData)
        payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/study-plan-adjustment/projects/7/deadline")
        XCTAssertEqual(payload["deadline"] as? String, "2026-06-30")

        let insertClient = makeRecordingClient(responseBody: """
        {"project_id":7,"task_id":99,"scheduled_date":"2026-06-06","target_minutes":40,"title":"Practice actors","source":"manual_insert"}
        """)
        _ = try await insertClient.insertStudyProjectTask(
            projectId: 7,
            title: "Practice actors",
            targetMinutes: 40,
            scheduledDate: "2026-06-06"
        )
        request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        body = try XCTUnwrap(request.httpBodyStreamData)
        payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/study-plan-adjustment/projects/7/tasks")
        XCTAssertEqual(payload["target_minutes"] as? Int, 40)
        XCTAssertEqual(payload["scheduled_date"] as? String, "2026-06-06")

        let deleteClient = makeRecordingClient(responseBody: """
        {"project_id":7,"task_id":99,"scheduled_date":"2026-06-06","source":"manual_delete","project_completed":false}
        """)
        _ = try await deleteClient.deleteStudyTask(id: 99)
        request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.url?.path, "/api/study-plan-adjustment/tasks/99")
    }

    func testStudyPlanAdjustmentRestDayAndDialogueClientRequestsUseExpectedMethodsPathsAndBodies() async throws {
        let restFetchClient = makeRecordingClient(responseBody: """
        {"weekly_weekdays":[5],"one_off_dates":["2026-06-10"]}
        """)
        _ = try await restFetchClient.fetchStudyRestDaySettings()
        var request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/study-plan-adjustment/rest-days")

        let restUpdateClient = makeRecordingClient(responseBody: """
        {"weekly_weekdays":[5],"one_off_dates":["2026-06-10"],"added_weekly_weekdays":[5],"removed_weekly_weekdays":[],"added_one_off_dates":["2026-06-10"],"removed_one_off_dates":[],"source":"manual_rest_day_settings"}
        """)
        _ = try await restUpdateClient.updateStudyRestDaySettings(
            StudyRestDaySettings(weeklyWeekdays: [5], oneOffDates: ["2026-06-10"])
        )
        request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        var body = try XCTUnwrap(request.httpBodyStreamData)
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.url?.path, "/api/study-plan-adjustment/rest-days")
        XCTAssertEqual(payload["weekly_weekdays"] as? [Int], [5])
        XCTAssertEqual(payload["one_off_dates"] as? [String], ["2026-06-10"])

        let previewBody = """
        {
            "status":"preview",
            "source":"dialogue_preview",
            "command":"project_shift",
            "project_id":7,
            "delta_days":7,
            "affected_task_ids":[42],
            "changes":[{"task_id":42,"project_id":7,"old_date":"2026-06-01","new_date":"2026-06-08"}],
            "red_state_impact":{"expected_late":{"before":false,"after":false},"over_capacity":{"before_dates":[],"after_dates":[],"new_over_capacity_dates":[]}},
            "mutates":false
        }
        """
        let previewClient = makeRecordingClient(responseBody: previewBody)
        let preview = try await previewClient.previewStudyDialogueAdjustment(
            instruction: "push this project by one week",
            projectId: 7
        )
        request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        body = try XCTUnwrap(request.httpBodyStreamData)
        payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/study-plan-adjustment/dialogue/preview")
        XCTAssertEqual(payload["instruction"] as? String, "push this project by one week")
        XCTAssertEqual(payload["project_id"] as? Int, 7)

        let applyClient = makeRecordingClient(responseBody: """
        {"status":"applied","source":"dialogue_apply","command":"project_shift","project_id":7,"delta_days":7,"affected_task_ids":[42],"changes":[{"task_id":42,"project_id":7,"old_date":"2026-06-01","new_date":"2026-06-08"}],"mutates":true,"refresh":{"today":true,"project_overview":true,"calendar":true}}
        """)
        _ = try await applyClient.applyStudyDialogueAdjustment(
            instruction: "push this project by one week",
            projectId: 7,
            preview: preview
        )
        request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        body = try XCTUnwrap(request.httpBodyStreamData)
        payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/study-plan-adjustment/dialogue/apply")
        XCTAssertNotNil(payload["preview"] as? [String: Any])
    }

    func testTaskCompletionResultDecodesSnakeCaseFields() throws {
        let json = """
        {
            "task_id": 42,
            "completed_at": "2026-06-01T12:30:00"
        }
        """

        let result = try decode(TaskCompletionResult.self, from: json)

        XCTAssertEqual(result.taskId, 42)
        XCTAssertEqual(result.completedAt, "2026-06-01T12:30:00")
    }

    func testFetchStudyTodayViewRequestsGETPathAndDecodesResponse() async throws {
        let client = makeRecordingClient(
            responseBody: """
            {
                "date": "2026-06-01",
                "tasks": [
                    {
                        "id": 10,
                        "title": "Read",
                        "target_minutes": 25,
                        "completed_at": null,
                        "project_id": 1,
                        "project_title": "Swift",
                        "resource_id": 2,
                        "resource_title": "Book",
                        "resource_url": "https://example.com/book",
                        "unit_id": 3,
                        "unit_title": "Chapter",
                        "unit_url": "https://example.com/chapter"
                    }
                ]
            }
            """
        )

        let view = try await client.fetchStudyTodayView()

        let request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/study-views/today")
        XCTAssertEqual(view.date, "2026-06-01")
        XCTAssertEqual(view.tasks.first?.id, 10)
    }

    func testFetchStudyProjectOverviewRequestsGETPathAndDecodesResponse() async throws {
        let client = makeRecordingClient(
            responseBody: """
            {
                "active_projects": [
                    {
                        "id": 1,
                        "title": "Swift",
                        "completed_units": 1,
                        "total_units": 4,
                        "progress_ratio": 0.25,
                        "target_minutes": 200,
                        "actual_minutes": 50,
                        "deadline": "2026-06-30",
                        "status": "active"
                    }
                ],
                "completed_projects": []
            }
            """
        )

        let overview = try await client.fetchStudyProjectOverview()

        let request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/study-views/projects")
        XCTAssertEqual(overview.activeProjects.first?.title, "Swift")
        XCTAssertTrue(overview.completedProjects.isEmpty)
    }

    func testFetchStudyCalendarLoadRequestsGETPathQueryAndDecodesResponse() async throws {
        let client = makeRecordingClient(
            responseBody: """
            {
                "start_date": "2026-06-01",
                "end_date": "2026-06-07",
                "daily_capacity_minutes": 75,
                "days": [
                    {
                        "date": "2026-06-01",
                        "scheduled_task_count": 2,
                        "total_target_minutes": 80,
                        "completed_task_count": 1,
                        "over_capacity": true
                    }
                ]
            }
            """
        )

        let load = try await client.fetchStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07")

        let request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(components.path, "/api/study-views/calendar")
        XCTAssertEqual(queryItems["start"], "2026-06-01")
        XCTAssertEqual(queryItems["end"], "2026-06-07")
        XCTAssertEqual(load.startDate, "2026-06-01")
        XCTAssertEqual(load.days.first?.overCapacity, true)
    }

    func testCompleteTaskPostsSnakeCaseActualMinutesAndDecodesResult() async throws {
        let client = makeRecordingClient(
            responseBody: """
            {
                "task_id": 42,
                "completed_at": "2026-06-01T12:30:00"
            }
            """
        )

        let result = try await client.completeTask(id: 42, actualMinutes: 35)

        let request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        let body = try XCTUnwrap(request.httpBodyStreamData)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/tasks/42/complete")
        XCTAssertEqual(payload["actual_minutes"] as? Int, 35)
        XCTAssertNil(payload["actualMinutes"])
        XCTAssertEqual(result.taskId, 42)
        XCTAssertEqual(result.completedAt, "2026-06-01T12:30:00")
    }

    func testAssistantAPIClientDefinesStudyViewProtocolMethodsAndEndpoints() throws {
        let protocolSource = try sourceFile("MalDaze/LearningAssistant/AssistantAPIClientProtocol.swift")
        let clientSource = try sourceFile("MalDaze/LearningAssistant/AssistantAPIClient.swift")

        XCTAssertTrue(protocolSource.contains("func fetchStudyTodayView() async throws -> StudyTodayView"))
        XCTAssertTrue(protocolSource.contains("func fetchStudyProjectOverview() async throws -> StudyProjectOverview"))
        XCTAssertTrue(protocolSource.contains("func fetchStudyCalendarLoad(start: String, end: String) async throws -> StudyCalendarLoad"))
        XCTAssertTrue(clientSource.contains("func fetchStudyTodayView() async throws -> StudyTodayView"))
        XCTAssertTrue(clientSource.contains("func fetchStudyProjectOverview() async throws -> StudyProjectOverview"))
        XCTAssertTrue(clientSource.contains("func fetchStudyCalendarLoad(start: String, end: String) async throws -> StudyCalendarLoad"))
        XCTAssertTrue(clientSource.contains("\"/api/study-views/today\""))
        XCTAssertTrue(clientSource.contains("\"/api/study-views/projects\""))
        XCTAssertTrue(clientSource.contains("URLQueryItem(name: \"start\", value: start)"))
        XCTAssertTrue(clientSource.contains("URLQueryItem(name: \"end\", value: end)"))
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

    private func jsonDictionary<T: Encodable>(from value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func sourceFile(_ relativePath: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let url = projectRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func makeRecordingClient(responseBody: String, statusCode: Int = 200) -> AssistantAPIClient {
        URLProtocolBackedAPIClientTests.responseData = Data(responseBody.utf8)
        URLProtocolBackedAPIClientTests.statusCode = statusCode
        URLProtocolBackedAPIClientTests.lastRequest = nil

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolBackedAPIClientTests.self]
        return AssistantAPIClient(
            baseURL: URL(string: "http://example.test")!,
            session: URLSession(configuration: configuration)
        )
    }
}

private final class URLProtocolBackedAPIClientTests: URLProtocol {
    nonisolated(unsafe) static var responseData = Data()
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension URLRequest {
    var httpBodyStreamData: Data? {
        guard let stream = httpBodyStream else { return httpBody }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
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

    func testAssistantPanelPreviewFixtureCompletesTasksWithResult() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("func completeTask(id: Int, actualMinutes: Int?) async throws -> TaskCompletionResult"))
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

    func testAssistantPanelAddResourceUsesStudyPlanIntakeView() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("case .addResource:"))
        XCTAssertTrue(source.contains("StudyPlanIntakeView(vm: vm)"))
        XCTAssertFalse(source.contains("case .addResource:\n            IngestionView(vm: vm)"))
    }

    func testAssistantPanelExposesFirstClassStudyViewsInBottomNavigation() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("case .projectOverview:"))
        XCTAssertTrue(source.contains("case .calendar:"))
        XCTAssertTrue(source.contains("ProjectOverviewView(vm: vm)"))
        XCTAssertTrue(source.contains("StudyCalendarLoadView(vm: vm)"))
        XCTAssertTrue(source.contains("bottomNavigationButton(.projectOverview)"))
        XCTAssertTrue(source.contains("bottomNavigationButton(.calendar)"))
        XCTAssertTrue(source.contains("今日"))
        XCTAssertTrue(source.contains("项目总览"))
        XCTAssertTrue(source.contains("日历"))
    }

    func testAssistantPanelTodayViewDisplaysStudyTodayV2Facts() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("private var todayView"))
        XCTAssertTrue(source.contains("vm.studyTodayView"))
        XCTAssertTrue(source.contains("todayV2Facts"))
        XCTAssertTrue(source.contains("今日学习"))
        XCTAssertTrue(source.contains("v2 日期"))
        XCTAssertTrue(source.contains("项目"))
        XCTAssertTrue(source.contains("单元"))
    }

    func testAssistantPanelProjectOverviewDisplaysActiveCompletedAndFacts() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("private struct ProjectOverviewView"))
        XCTAssertTrue(source.contains("vm.studyProjectOverview"))
        XCTAssertTrue(source.contains("进行中项目"))
        XCTAssertTrue(source.contains("完成历史"))
        XCTAssertTrue(source.contains("progressRatio"))
        XCTAssertTrue(source.contains("deadline"))
        XCTAssertTrue(source.contains("status"))
        XCTAssertTrue(source.contains("targetMinutes"))
        XCTAssertTrue(source.contains("actualMinutes"))
    }

    func testAssistantPanelCalendarDisplaysReadOnlyDailyLoadAndFetchesDefaultWindow() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("private struct StudyCalendarLoadView"))
        XCTAssertTrue(source.contains("vm.studyCalendarLoad"))
        XCTAssertTrue(source.contains("fetchDefaultWindowIfNeeded"))
        XCTAssertTrue(source.contains("vm.fetchStudyCalendarLoad(start: start, end: end)"))
        XCTAssertTrue(source.contains("只读日历"))
        XCTAssertTrue(source.contains("scheduledTaskCount"))
        XCTAssertTrue(source.contains("totalTargetMinutes"))
        XCTAssertTrue(source.contains("completedTaskCount"))
        XCTAssertTrue(source.contains("overCapacity"))
    }

    func testAssistantPanelCalendarDefaultWindowCoversNextSeveralWeeks() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("defaultCalendarWindowDayOffset"))
        XCTAssertTrue(source.contains("value: Self.defaultCalendarWindowDayOffset"))
        XCTAssertTrue(source.contains("private static let defaultCalendarWindowDayOffset = 27"))
        XCTAssertFalse(source.contains("date(byAdding: .day, value: 6"))
    }

    func testAssistantPanelCalendarDefaultFetchSkipsLoadedOrInFlightRequest() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private func fetchDefaultWindowIfNeeded"),
              let end = source[start.upperBound...].range(of: "private func calendarLoadFact") else {
            XCTFail("fetchDefaultWindowIfNeeded source section not found")
            return
        }
        let fetchSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(fetchSource.contains("vm.studyCalendarLoad == nil"))
        XCTAssertTrue(fetchSource.contains("!vm.isFetchingStudyCalendarLoad"))
    }

    func testProjectOverviewProgressTextAndBarUseClampedRatioHelper() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("private func clampedProgressRatio(for project: StudyProjectSummary) -> Double"))
        XCTAssertTrue(source.contains("ratio.isFinite"))
        XCTAssertTrue(source.contains("ProgressView(value: clampedProgressRatio(for: project))"))
        XCTAssertTrue(source.contains("Int(clampedProgressRatio(for: project) * 100)"))
    }

    func testProjectOverviewFormatsStatusAndMissingDeadlineForDisplay() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("projectStatusLabel(for: project.status)"))
        XCTAssertTrue(source.contains("case \"active\": return \"进行中\""))
        XCTAssertTrue(source.contains("case \"completed\": return \"已完成\""))
        XCTAssertTrue(source.contains("projectDeadlineLabel(for: project.deadline)"))
        XCTAssertTrue(source.contains("return deadline ?? \"无截止日期\""))
        XCTAssertFalse(source.contains("Text(project.status)"))
        XCTAssertFalse(source.contains("project.deadline ?? \"无\""))
    }

    func testAssistantPanelCalendarSourceHasNoMutationWiring() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private struct StudyCalendarLoadView"),
              let end = source[start.upperBound...].range(of: "private struct ProjectOverviewView") else {
            XCTFail("StudyCalendarLoadView source section not found")
            return
        }
        let calendarSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertFalse(calendarSource.contains(".onMove"))
        XCTAssertFalse(calendarSource.contains(".onDelete"))
        XCTAssertFalse(calendarSource.localizedCaseInsensitiveContains("reschedule"))
        XCTAssertFalse(calendarSource.localizedCaseInsensitiveContains("delete"))
        XCTAssertFalse(calendarSource.localizedCaseInsensitiveContains("add task"))
        XCTAssertFalse(calendarSource.contains("moveVisibleTasks"))
    }

    func testStudyPlanIntakeReviewUIWiresDraftFlowControls() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("private struct StudyPlanIntakeView"))
        XCTAssertTrue(source.contains("private var studyPlanClarificationCard"))
        XCTAssertTrue(source.contains("private var studyPlanDraftReview"))
        XCTAssertTrue(source.contains("vm.startStudyPlan(url: urlText, deadline: deadline, capacityMinutes: capacityMinutes)"))
        XCTAssertTrue(source.contains("vm.submitStudyPlanClarification(answers: clarificationAnswers, skip: false)"))
        XCTAssertTrue(source.contains("vm.skipStudyPlanClarification()"))
        XCTAssertTrue(source.contains("vm.updateStudyPlanDraftTaskDuration(orderIndex: task.orderIndex, estimatedMinutes: minutes)"))
        XCTAssertTrue(source.contains("vm.cancelStudyPlanDraft()"))
        XCTAssertTrue(source.contains("vm.confirmStudyPlanDraft()"))
        XCTAssertTrue(source.contains("生成学习计划"))
        XCTAssertTrue(source.contains("生成粗略计划"))
        XCTAssertTrue(source.contains("确认创建计划"))
        XCTAssertTrue(source.contains("截止日期（必填）"))
        XCTAssertTrue(source.contains("低校准"))
        XCTAssertTrue(source.contains("超出每日容量"))
        XCTAssertTrue(source.contains("预计晚于截止日期"))
    }

    func testStudyPlanClarificationRadioOptionsUseUniqueOptionIdTagsAndSubmitAnswerValues() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("clarificationOptionSelectionBinding"))
        XCTAssertTrue(source.contains("answerValue(for: question"))
        XCTAssertTrue(source.contains(".tag(option.id)"))
        XCTAssertFalse(source.contains(".tag(option.value)"))
    }

    func testStudyPlanIntakeResetsClarificationAndDurationDraftsForNewDraftIdentity() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("lastClarificationDraftId"))
        XCTAssertTrue(source.contains("lastDurationDraftId"))
        XCTAssertTrue(source.contains("clarificationDraftId(for: clarification)"))
        XCTAssertTrue(source.contains("lastDurationDraftIdentity"))
        XCTAssertTrue(source.contains("durationDraftIdentity(for: draft)"))
        XCTAssertTrue(source.contains(".onChange(of: durationDraftIdentity(for: draft))"))
        XCTAssertTrue(source.contains("\\($0.orderIndex):\\($0.estimatedMinutes)"))
        XCTAssertTrue(source.contains("durationDrafts = Dictionary(uniqueKeysWithValues:"))
    }

    func testStudyPlanIntakeAcceptsDefaultDeadlineWithoutHiddenRequiredGate() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("DatePicker(\"截止日期（必填）\""))
        XCTAssertFalse(source.contains("hasSelectedDeadline"))
        XCTAssertFalse(source.contains("deadlineRequiredMessage"))
        XCTAssertFalse(source.contains("guard hasSelectedDeadline"))
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
        mock.studyTodayViewResult = sampleStudyTodayView(
            tasks: [
                sampleStudyViewTaskJSON(id: 1, title: "A", targetMinutes: 15, projectTitle: "R"),
                sampleStudyViewTaskJSON(id: 2, title: "B", targetMinutes: 20, projectTitle: "R")
            ]
        )
        mock.resourcesResult = [
            AssistantResource(id: 10, title: "R", trackingMode: "video",
                              completedUnits: 1, totalUnits: 5, actualMinutesTotal: 20,
                              deadline: nil, status: "active")
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.fetchDashboard()

        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 1)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 1)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
        XCTAssertEqual(mock.fetchResourcesCallCount, 1)
        XCTAssertFalse(vm.isOffline)
        XCTAssertEqual(vm.dashboardState.kind, .tasksToday)
        XCTAssertEqual(vm.dashboardState.taskCount, 2)
        XCTAssertEqual(vm.dashboardState.totalMinutes, 35)
        XCTAssertEqual(vm.dashboardState.highlights, "今日共 2 项学习任务，总计 35 分钟")
        XCTAssertEqual(vm.visibleTodayTasks.map(\.id), [1, 2])
    }

    func testDashboardEmptyDatabaseMarksAddResourceAsPrimaryAction() async {
        let mock = MockAssistantAPIClient()
        mock.studyTodayViewResult = sampleStudyTodayView(tasks: [])
        mock.resourcesResult = []
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.fetchDashboard()

        XCTAssertEqual(vm.dashboardState.kind, .emptyDatabase)
        XCTAssertEqual(vm.dashboardState.primaryAction, .addResource)
        XCTAssertTrue(vm.visibleTodayTasks.isEmpty)
    }

    func testDashboardNoTasksWithResourcesDoesNotSelectNextTask() async {
        let mock = MockAssistantAPIClient()
        mock.studyTodayViewResult = sampleStudyTodayView(tasks: [])
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
        mock.studyTodayViewResult = sampleStudyTodayView(
            tasks: [AssistantTask(id: 1, title: "A", targetMinutes: 15,
                                  completedAt: nil, resourceTitle: "R", priority: 1)].map {
                sampleStudyViewTaskJSON(id: $0.id, title: $0.title, targetMinutes: $0.targetMinutes, projectTitle: $0.resourceTitle)
            }
        )
        mock.resourcesResult = [
            AssistantResource(id: 10, title: "R", trackingMode: "video",
                              completedUnits: 1, totalUnits: 5, actualMinutesTotal: 20,
                              deadline: nil, status: "active")
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchDashboard()

        mock.shouldThrowResources = true
        mock.studyTodayViewResult = sampleStudyTodayView(
            tasks: [AssistantTask(id: 2, title: "B", targetMinutes: 20,
                                  completedAt: nil, resourceTitle: "R2", priority: 1)].map {
                sampleStudyViewTaskJSON(id: $0.id, title: $0.title, targetMinutes: $0.targetMinutes, projectTitle: $0.resourceTitle)
            }
        )
        await vm.fetchDashboard()

        XCTAssertTrue(vm.isOffline)
        XCTAssertEqual(vm.dashboardState.kind, .offline)
        XCTAssertEqual(vm.tasks.map(\.id), [1])
        XCTAssertEqual(vm.resources.map(\.id), [10])
        XCTAssertEqual(vm.visibleTodayTasks.map(\.id), [1])
    }

    func testConnectingWithCachedDashboardContentKeepsDashboardVisibleForBackgroundRefresh() async {
        let mock = MockAssistantAPIClient()
        mock.studyTodayViewResult = sampleStudyTodayView(
            tasks: [AssistantTask(id: 1, title: "Cached", targetMinutes: 15,
                                  completedAt: nil, resourceTitle: "R", priority: 1)].map {
                sampleStudyViewTaskJSON(id: $0.id, title: $0.title, targetMinutes: $0.targetMinutes, projectTitle: $0.resourceTitle)
            }
        )
        mock.resourcesResult = [
            AssistantResource(id: 10, title: "R", trackingMode: "video",
                              completedUnits: 1, totalUnits: 5, actualMinutesTotal: 20,
                              deadline: nil, status: "active")
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchDashboard()

        vm.isConnecting = true

        XCTAssertEqual(vm.dashboardState.kind, .tasksToday)
        XCTAssertTrue(vm.isConnecting)
    }

    func testDashboardOpenStartsLazyBackendWhenNotReadyAndKeepsConnecting() async {
        let mock = MockAssistantAPIClient()
        let backend = MockBackendLifecycle()
        backend.isReady = false
        backend.isStarting = false
        let vm = LearningAssistantViewModel(
            api: mock,
            backendLifecycle: backend,
            autoLoadWhenReady: false
        )

        await vm.refreshForDashboardOpen()

        XCTAssertEqual(backend.startIfNeededCallCount, 1)
        XCTAssertTrue(vm.isConnecting)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
        XCTAssertEqual(mock.fetchResourcesCallCount, 0)
    }

    func testFetchDashboardSerializesConcurrentRefreshesWithoutDroppingLaterRequest() async {
        let mock = MockAssistantAPIClient()
        mock.dashboardFetchDelayNanoseconds = 100_000_000
        mock.studyTodayViewResultsQueue = [
            sampleStudyTodayView(
                tasks: [
                    sampleStudyViewTaskJSON(id: 1, title: "Old", targetMinutes: 15, projectTitle: "R")
                ]
            ),
            sampleStudyTodayView(
                tasks: [
                    sampleStudyViewTaskJSON(id: 2, title: "New", targetMinutes: 20, projectTitle: "R2")
                ]
            )
        ]
        mock.studyProjectOverviewResultsQueue = [
            sampleStudyProjectOverview(activeProjects: [
                sampleStudyProjectSummaryJSON(id: 10, title: "R", completedUnits: 1, totalUnits: 5, progressRatio: 0.2, status: "active")
            ]),
            sampleStudyProjectOverview(activeProjects: [
                sampleStudyProjectSummaryJSON(id: 20, title: "R2", completedUnits: 2, totalUnits: 6, progressRatio: 0.33, status: "active")
            ])
        ]
        mock.resourcesResultsQueue = [
            [AssistantResource(id: 10, title: "R", trackingMode: "video",
                               completedUnits: 1, totalUnits: 5, actualMinutesTotal: 20,
                               deadline: nil, status: "active")],
            [AssistantResource(id: 20, title: "R2", trackingMode: "article",
                               completedUnits: 2, totalUnits: 6, actualMinutesTotal: 30,
                               deadline: nil, status: "active")]
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        async let first: Void = vm.fetchDashboard()
        async let second: Void = vm.fetchDashboard()
        _ = await (first, second)

        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 2)
        XCTAssertEqual(mock.fetchResourcesCallCount, 2)
        XCTAssertEqual(mock.maxConcurrentStudyTodayViewFetches, 1)
        XCTAssertEqual(mock.maxConcurrentResourceFetches, 1)
        XCTAssertEqual(vm.tasks.map(\.id), [2])
        XCTAssertEqual(vm.resources.map(\.id), [20])
        XCTAssertEqual(vm.dashboardState.highlights, "今日共 1 项学习任务，总计 20 分钟")
    }

    func testCompleteTaskQueuesRequiredRefreshWhenDashboardFetchAlreadyInFlight() async {
        let mock = MockAssistantAPIClient()
        mock.dashboardFetchDelayNanoseconds = 100_000_000
        mock.studyTodayViewResultsQueue = [
            sampleStudyTodayView(
                tasks: [
                    sampleStudyViewTaskJSON(id: 1, title: "Before completion", targetMinutes: 15, projectTitle: "R")
                ]
            ),
            sampleStudyTodayView(
                tasks: [
                    sampleStudyViewTaskJSON(
                        id: 1,
                        title: "After completion",
                        targetMinutes: 15,
                        completedAt: "2026-05-17T12:00:00",
                        projectTitle: "R"
                    )
                ]
            )
        ]
        mock.studyProjectOverviewResultsQueue = [
            sampleStudyProjectOverview(activeProjects: [
                sampleStudyProjectSummaryJSON(id: 10, title: "R", completedUnits: 1, totalUnits: 5, progressRatio: 0.2, status: "active")
            ]),
            sampleStudyProjectOverview(activeProjects: [
                sampleStudyProjectSummaryJSON(id: 10, title: "R", completedUnits: 2, totalUnits: 5, progressRatio: 0.4, status: "active")
            ])
        ]
        mock.resourcesResultsQueue = [
            [AssistantResource(id: 10, title: "R", trackingMode: "video",
                               completedUnits: 1, totalUnits: 5, actualMinutesTotal: 20,
                               deadline: nil, status: "active")],
            [AssistantResource(id: 10, title: "R", trackingMode: "video",
                               completedUnits: 2, totalUnits: 5, actualMinutesTotal: 35,
                               deadline: nil, status: "active")]
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        let task = AssistantTask(
            id: 1,
            title: "Before completion",
            targetMinutes: 15,
            completedAt: nil,
            resourceTitle: "R",
            priority: 1
        )

        async let openingFetch: Void = vm.fetchDashboard()
        try? await Task.sleep(nanoseconds: 20_000_000)
        await vm.completeTask(task)
        await openingFetch

        XCTAssertEqual(mock.lastCompleteTaskId, 1)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 2)
        XCTAssertEqual(mock.fetchResourcesCallCount, 2)
        XCTAssertEqual(mock.maxConcurrentStudyTodayViewFetches, 1)
        XCTAssertEqual(mock.maxConcurrentResourceFetches, 1)
        XCTAssertEqual(vm.tasks.first?.completedAt, "2026-05-17T12:00:00")
        XCTAssertEqual(vm.resources.first?.actualMinutesTotal, 35)
        XCTAssertEqual(vm.dashboardState.highlights, "今日共 1 项学习任务，总计 15 分钟")
    }

    func testLocalTaskDisplayOrderPersistsAndMergesChangedTaskSet() async {
        let mock = MockAssistantAPIClient()
        let defaults = UserDefaults(suiteName: "LearningAssistantTests.order.\(UUID().uuidString)")!
        mock.studyTodayViewResult = sampleStudyTodayView(
            tasks: [
                sampleStudyViewTaskJSON(id: 1, title: "A", targetMinutes: 10),
                sampleStudyViewTaskJSON(id: 2, title: "B", targetMinutes: 10),
                sampleStudyViewTaskJSON(id: 3, title: "C", targetMinutes: 10)
            ]
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

        mock.studyTodayViewResult = sampleStudyTodayView(
            tasks: [
                sampleStudyViewTaskJSON(id: 2, title: "B", targetMinutes: 10),
                sampleStudyViewTaskJSON(id: 3, title: "C", targetMinutes: 10),
                sampleStudyViewTaskJSON(id: 4, title: "D", targetMinutes: 10)
            ]
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
        mock.studyTodayViewResult = sampleStudyTodayView(
            tasks: [
                sampleStudyViewTaskJSON(id: 1, title: "A", targetMinutes: 10),
                sampleStudyViewTaskJSON(id: 2, title: "B", targetMinutes: 10)
            ]
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

    func testStudyPlanProtocolAndMockRepresentDraftFlow() async throws {
        let mock = MockAssistantAPIClient()
        mock.studyPlanStartResult = sampleStudyPlanStartResponse()
        mock.studyPlanDraftResult = sampleStudyPlanDraft()
        mock.studyPlanActivationResult = StudyPlanActivationResult(
            id: 42,
            resourceId: 101,
            status: "active",
            sourceURL: URL(string: "https://example.com/course")!,
            deadline: "2026-07-01",
            capacityMinutes: 60,
            clarificationSkipped: true
        )
        let api: any AssistantAPIClientProtocol = mock

        let start = try await api.startStudyPlan(
            url: "https://example.com/course",
            deadline: "2026-07-01",
            capacityMinutes: 60
        )
        let draft = try await api.submitStudyPlanClarification(
            draftId: start.draftId,
            answers: ["goal_depth": "apply"],
            skip: true
        )
        let updatedDraft = try await api.updateStudyPlanDraftTaskDuration(
            draftId: start.draftId,
            taskOrderIndex: 1,
            estimatedMinutes: 35
        )
        try await api.cancelStudyPlanDraft(draftId: start.draftId)
        let activation = try await api.confirmStudyPlanDraft(draftId: start.draftId)

        XCTAssertEqual(start.draftId, 42)
        XCTAssertEqual(start.clarification.version, "d30-guided-clarification-v1")
        XCTAssertEqual(draft.id, 42)
        XCTAssertEqual(updatedDraft.tasks.first?.estimatedMinutes, 25)
        XCTAssertEqual(activation.resourceId, 101)
        XCTAssertEqual(mock.lastStudyPlanStartURL, "https://example.com/course")
        XCTAssertEqual(mock.lastStudyPlanStartDeadline, "2026-07-01")
        XCTAssertEqual(mock.lastStudyPlanStartCapacityMinutes, 60)
        XCTAssertEqual(mock.lastStudyPlanClarificationDraftId, start.draftId)
        XCTAssertEqual(mock.lastStudyPlanClarificationAnswers["goal_depth"], "apply")
        XCTAssertEqual(mock.lastStudyPlanClarificationSkip, true)
        XCTAssertEqual(mock.lastStudyPlanDurationDraftId, start.draftId)
        XCTAssertEqual(mock.lastStudyPlanDurationTaskOrderIndex, 1)
        XCTAssertEqual(mock.lastStudyPlanDurationEstimatedMinutes, 35)
        XCTAssertEqual(mock.lastCancelledStudyPlanDraftId, start.draftId)
        XCTAssertEqual(mock.lastConfirmedStudyPlanDraftId, start.draftId)
    }

    func testStartStudyPlanStoresDraftIdAndClarificationAndClearsPreviousDraftError() async throws {
        let mock = MockAssistantAPIClient()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.studyPlanDraft = sampleStudyPlanDraft()
        vm.studyPlanError = "旧错误"
        let deadline = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-01T12:00:00Z"))

        await vm.startStudyPlan(
            url: "https://example.com/course",
            deadline: deadline,
            capacityMinutes: 75
        )

        XCTAssertEqual(vm.studyPlanDraftId, 42)
        XCTAssertEqual(vm.studyPlanClarification?.version, "d30-guided-clarification-v1")
        XCTAssertNil(vm.studyPlanDraft)
        XCTAssertNil(vm.studyPlanError)
        XCTAssertFalse(vm.isOffline)
        XCTAssertEqual(mock.lastStudyPlanStartURL, "https://example.com/course")
        XCTAssertEqual(mock.lastStudyPlanStartDeadline, "2026-07-01")
        XCTAssertEqual(mock.lastStudyPlanStartCapacityMinutes, 75)
    }

    func testStartStudyPlanFailurePreservesExistingDraftFlowAndResetsLoading() async throws {
        let mock = MockAssistantAPIClient()
        mock.shouldThrowOffline = true
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.studyPlanDraftId = 42
        vm.studyPlanClarification = sampleStudyPlanClarification()
        vm.studyPlanDraft = sampleStudyPlanDraft()
        let deadline = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-01T12:00:00Z"))

        await vm.startStudyPlan(
            url: "https://example.com/new-course",
            deadline: deadline,
            capacityMinutes: 90
        )

        XCTAssertEqual(vm.studyPlanDraftId, 42)
        XCTAssertEqual(vm.studyPlanClarification?.version, "d30-guided-clarification-v1")
        XCTAssertEqual(vm.studyPlanDraft?.id, 42)
        XCTAssertFalse(vm.isStartingStudyPlan)
        XCTAssertTrue(vm.isOffline)
        XCTAssertNotNil(vm.studyPlanError)
    }

    func testSkipStudyPlanClarificationUsesDefaultsAndStoresReviewDraft() async {
        let mock = MockAssistantAPIClient()
        mock.studyPlanDraftResult = sampleStudyPlanDraft(lowCalibration: true, clarificationSkipped: true)
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.studyPlanDraftId = 42
        vm.studyPlanClarification = sampleStudyPlanClarification()

        await vm.skipStudyPlanClarification()

        XCTAssertEqual(mock.lastStudyPlanClarificationDraftId, 42)
        XCTAssertEqual(mock.lastStudyPlanClarificationAnswers, ["goal_depth": "understand_and_apply"])
        XCTAssertEqual(mock.lastStudyPlanClarificationSkip, true)
        XCTAssertEqual(vm.studyPlanDraft?.status, "review")
        XCTAssertTrue(vm.studyPlanDraft?.lowCalibration ?? false)
        XCTAssertNil(mock.lastConfirmedStudyPlanDraftId)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
    }

    func testSubmitStudyPlanClarificationPassesAnswersWithoutSkip() async {
        let mock = MockAssistantAPIClient()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.studyPlanDraftId = 42

        await vm.submitStudyPlanClarification(
            answers: ["goal_depth": "mastery", "focus_scope": "consensus"],
            skip: false
        )

        XCTAssertEqual(mock.lastStudyPlanClarificationDraftId, 42)
        XCTAssertEqual(mock.lastStudyPlanClarificationAnswers["goal_depth"], "mastery")
        XCTAssertEqual(mock.lastStudyPlanClarificationAnswers["focus_scope"], "consensus")
        XCTAssertEqual(mock.lastStudyPlanClarificationSkip, false)
        XCTAssertEqual(vm.studyPlanDraft?.id, 42)
        XCTAssertNil(mock.lastConfirmedStudyPlanDraftId)
    }

    func testUpdateStudyPlanDraftTaskDurationKeepsDraftInReviewState() async {
        let mock = MockAssistantAPIClient()
        mock.studyPlanDraftResult = sampleStudyPlanDraft(estimatedMinutes: 45, status: "review")
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.studyPlanDraftId = 42
        vm.studyPlanDraft = sampleStudyPlanDraft(estimatedMinutes: 25, status: "review")

        await vm.updateStudyPlanDraftTaskDuration(orderIndex: 0, estimatedMinutes: 45)

        XCTAssertEqual(mock.lastStudyPlanDurationDraftId, 42)
        XCTAssertEqual(mock.lastStudyPlanDurationTaskOrderIndex, 0)
        XCTAssertEqual(mock.lastStudyPlanDurationEstimatedMinutes, 45)
        XCTAssertEqual(vm.studyPlanDraft?.status, "review")
        XCTAssertEqual(vm.studyPlanDraft?.tasks.first?.estimatedMinutes, 45)
        XCTAssertNil(mock.lastConfirmedStudyPlanDraftId)
    }

    func testUpdateStudyPlanDraftTaskDurationRequiresReviewDraftBeforeCallingAPI() async {
        let mock = MockAssistantAPIClient()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.studyPlanDraftId = 42
        vm.studyPlanClarification = sampleStudyPlanClarification()
        vm.studyPlanDraft = nil

        await vm.updateStudyPlanDraftTaskDuration(orderIndex: 0, estimatedMinutes: 45)

        XCTAssertNil(mock.lastStudyPlanDurationDraftId)
        XCTAssertNotNil(vm.studyPlanError)
        XCTAssertFalse(vm.isUpdatingStudyPlanDraft)
    }

    func testCancelStudyPlanDraftClearsLocalStateAndDoesNotRefreshDashboard() async {
        let mock = MockAssistantAPIClient()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.studyPlanDraftId = 42
        vm.studyPlanClarification = sampleStudyPlanClarification()
        vm.studyPlanDraft = sampleStudyPlanDraft()
        vm.studyPlanError = "待清理"

        await vm.cancelStudyPlanDraft()

        XCTAssertEqual(mock.lastCancelledStudyPlanDraftId, 42)
        XCTAssertNil(vm.studyPlanDraftId)
        XCTAssertNil(vm.studyPlanClarification)
        XCTAssertNil(vm.studyPlanDraft)
        XCTAssertNil(vm.studyPlanError)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
        XCTAssertEqual(mock.fetchResourcesCallCount, 0)
    }

    func testConfirmStudyPlanDraftRequiresExplicitConfirmAndRefreshesDashboardOnce() async {
        let mock = MockAssistantAPIClient()
        mock.studyTodayViewResult = sampleStudyTodayView(
            tasks: [
                sampleStudyViewTaskJSON(id: 7, title: "Activated", targetMinutes: 30, projectTitle: "Course")
            ]
        )
        mock.resourcesResult = [sampleResource(id: 101, title: "Course")]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.studyPlanDraftId = 42
        vm.studyPlanClarification = sampleStudyPlanClarification()
        vm.studyPlanDraft = sampleStudyPlanDraft()

        await vm.confirmStudyPlanDraft()

        XCTAssertEqual(mock.lastConfirmedStudyPlanDraftId, 42)
        XCTAssertNil(vm.studyPlanDraftId)
        XCTAssertNil(vm.studyPlanClarification)
        XCTAssertNil(vm.studyPlanDraft)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 1)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
        XCTAssertEqual(mock.fetchResourcesCallCount, 1)
        XCTAssertEqual(vm.tasks.map(\.id), [7])
        XCTAssertEqual(vm.resources.map(\.id), [101])
    }

    func testConfirmStudyPlanDraftRequiresReviewDraftBeforeCallingAPIOrRefreshingDashboard() async {
        let mock = MockAssistantAPIClient()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.studyPlanDraftId = 42
        vm.studyPlanClarification = sampleStudyPlanClarification()
        vm.studyPlanDraft = nil

        await vm.confirmStudyPlanDraft()

        XCTAssertNil(mock.lastConfirmedStudyPlanDraftId)
        XCTAssertEqual(mock.confirmStudyPlanDraftCallCount, 0)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
        XCTAssertEqual(mock.fetchResourcesCallCount, 0)
        XCTAssertNotNil(vm.studyPlanError)
        XCTAssertFalse(vm.isConfirmingStudyPlanDraft)
    }

    func testFetchDashboardLoadsStudyTodayAndProjectOverviewAsDefaultV2State() async {
        let mock = MockAssistantAPIClient()
        mock.briefingResult = TodayBriefing(
            tasks: [AssistantTask(id: 999, title: "Stale briefing task", targetMinutes: 5,
                                  completedAt: nil, resourceTitle: "Briefing", priority: 1)],
            totalMinutes: 5,
            highlights: "stale generated briefing"
        )
        mock.studyTodayViewResult = sampleStudyTodayView(
            tasks: [
                sampleStudyViewTaskJSON(
                    id: 10,
                    title: "Read actors",
                    targetMinutes: 45,
                    projectTitle: "Swift Concurrency",
                    resourceTitle: "Concurrency Guide",
                    unitTitle: "Actors"
                ),
                sampleStudyViewTaskJSON(
                    id: 11,
                    title: "Practice cancellation",
                    targetMinutes: 25,
                    projectTitle: "Swift Concurrency",
                    resourceTitle: "Concurrency Guide",
                    unitTitle: "Cancellation"
                )
            ]
        )
        mock.studyProjectOverviewResult = sampleStudyProjectOverview(
            activeProjects: [
                sampleStudyProjectSummaryJSON(
                    id: 1,
                    title: "Swift Concurrency",
                    completedUnits: 1,
                    totalUnits: 4,
                    progressRatio: 0.25,
                    status: "active"
                )
            ],
            completedProjects: []
        )

        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchDashboard()

        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 1)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 1)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
        XCTAssertEqual(vm.studyTodayView?.tasks.map(\.id), [10, 11])
        XCTAssertEqual(vm.studyProjectOverview?.activeProjects.map(\.title), ["Swift Concurrency"])
        XCTAssertEqual(vm.visibleTodayTasks.map(\.id), [10, 11])
        XCTAssertEqual(vm.tasks.map(\.title), ["Read actors", "Practice cancellation"])
        XCTAssertEqual(vm.todayTotalMinutes, 70)
        XCTAssertNotEqual(vm.todayHighlights, "stale generated briefing")
        XCTAssertFalse(vm.isOffline)
    }

    func testDashboardMapsStudyProjectTitleBeforeResourceTitleForVisibleTasks() async {
        let mock = MockAssistantAPIClient()
        mock.studyTodayViewResult = sampleStudyTodayView(
            tasks: [
                sampleStudyViewTaskJSON(
                    id: 12,
                    title: "Review replication",
                    targetMinutes: 35,
                    projectTitle: "Distributed Systems",
                    resourceTitle: "Course Notes"
                )
            ]
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.fetchDashboard()

        XCTAssertEqual(vm.visibleTodayTasks.first?.resourceTitle, "Distributed Systems")
        XCTAssertEqual(vm.tasks.first?.resourceTitle, "Distributed Systems")
    }

    func testCompleteTaskRefreshesStudyTodayAndProjectOverviewFromPersistedFacts() async {
        let mock = MockAssistantAPIClient()
        mock.studyTodayViewResultsQueue = [
            sampleStudyTodayView(
                tasks: [
                    sampleStudyViewTaskJSON(id: 20, title: "Before", targetMinutes: 30,
                                            completedAt: nil, projectTitle: "Algorithms")
                ]
            ),
            sampleStudyTodayView(
                tasks: [
                    sampleStudyViewTaskJSON(id: 20, title: "Before", targetMinutes: 30,
                                            completedAt: "2026-06-01T12:30:00", projectTitle: "Algorithms")
                ]
            )
        ]
        mock.studyProjectOverviewResultsQueue = [
            sampleStudyProjectOverview(
                activeProjects: [
                    sampleStudyProjectSummaryJSON(id: 2, title: "Algorithms",
                                                  completedUnits: 1, totalUnits: 2,
                                                  progressRatio: 0.5, status: "active")
                ],
                completedProjects: []
            ),
            sampleStudyProjectOverview(
                activeProjects: [],
                completedProjects: [
                    sampleStudyProjectSummaryJSON(id: 2, title: "Algorithms",
                                                  completedUnits: 2, totalUnits: 2,
                                                  progressRatio: 1.0, status: "completed")
                ]
            )
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchDashboard()

        let task = AssistantTask(id: 20, title: "Before", targetMinutes: 30,
                                 completedAt: nil, resourceTitle: "Algorithms", priority: 1)
        await vm.completeTask(task)

        XCTAssertEqual(mock.lastCompleteTaskId, 20)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 2)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 2)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
        XCTAssertEqual(vm.studyTodayView?.tasks.first?.completedAt, "2026-06-01T12:30:00")
        XCTAssertTrue(vm.visibleTodayTasks.first?.isCompleted ?? false)
        XCTAssertTrue(vm.studyProjectOverview?.activeProjects.isEmpty ?? false)
        XCTAssertEqual(vm.studyProjectOverview?.completedProjects.first?.status, "completed")
        XCTAssertEqual(vm.studyProjectOverview?.completedProjects.first?.progressRatio ?? 0, 1.0, accuracy: 0.001)
    }

    func testProjectOverviewStoresActiveAndCompletedHistorySections() async {
        let mock = MockAssistantAPIClient()
        mock.studyProjectOverviewResult = sampleStudyProjectOverview(
            activeProjects: [
                sampleStudyProjectSummaryJSON(id: 30, title: "Systems",
                                              completedUnits: 2, totalUnits: 5,
                                              progressRatio: 0.4, status: "active")
            ],
            completedProjects: [
                sampleStudyProjectSummaryJSON(id: 31, title: "Databases",
                                              completedUnits: 6, totalUnits: 6,
                                              progressRatio: 1.0, status: "completed")
            ]
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.fetchDashboard()

        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 1)
        XCTAssertEqual(vm.studyProjectOverview?.activeProjects.map(\.title), ["Systems"])
        XCTAssertEqual(vm.studyProjectOverview?.completedProjects.map(\.title), ["Databases"])
    }

    func testFetchStudyCalendarLoadStoresReadOnlyLoadState() async {
        let mock = MockAssistantAPIClient()
        mock.studyCalendarLoadResult = sampleStudyCalendarLoad(
            start: "2026-06-01",
            end: "2026-06-07",
            dayJSON: """
            {
                "date": "2026-06-01",
                "scheduled_task_count": 3,
                "total_target_minutes": 95,
                "completed_task_count": 1,
                "over_capacity": true
            }
            """
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.fetchStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07")

        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 1)
        XCTAssertEqual(mock.lastStudyCalendarLoadStart, "2026-06-01")
        XCTAssertEqual(mock.lastStudyCalendarLoadEnd, "2026-06-07")
        XCTAssertEqual(vm.studyCalendarLoad?.dailyCapacityMinutes, 75)
        XCTAssertEqual(vm.studyCalendarLoad?.days.first?.scheduledTaskCount, 3)
        XCTAssertEqual(vm.studyCalendarLoad?.days.first?.totalTargetMinutes, 95)
        XCTAssertEqual(vm.studyCalendarLoad?.days.first?.completedTaskCount, 1)
        XCTAssertEqual(vm.studyCalendarLoad?.days.first?.overCapacity, true)
        XCTAssertNil(mock.lastCompleteTaskId)
    }

    func testFetchStudyCalendarLoadKeepsLatestRangeWhenOlderRequestFinishesLast() async {
        let mock = MockAssistantAPIClient()
        mock.studyCalendarLoadResultsQueue = [
            DelayedStudyCalendarLoadResult(
                load: sampleStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07"),
                delayNanoseconds: 100_000_000
            ),
            DelayedStudyCalendarLoadResult(
                load: sampleStudyCalendarLoad(start: "2026-06-08", end: "2026-06-14"),
                delayNanoseconds: 0
            )
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        let olderRequest = Task {
            await vm.fetchStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07")
        }
        await mock.waitForStudyCalendarLoadCallCount(1)
        let newerRequest = Task {
            await vm.fetchStudyCalendarLoad(start: "2026-06-08", end: "2026-06-14")
        }
        await newerRequest.value
        await olderRequest.value

        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 2)
        XCTAssertEqual(vm.studyCalendarLoad?.startDate, "2026-06-08")
        XCTAssertEqual(vm.studyCalendarLoad?.endDate, "2026-06-14")
        XCTAssertNil(vm.studyCalendarLoadError)
        XCTAssertFalse(vm.isFetchingStudyCalendarLoad)
    }

    func testOlderStudyCalendarLoadCompletionDoesNotClearNewerLoadingState() async {
        let mock = MockAssistantAPIClient()
        mock.studyCalendarLoadResultsQueue = [
            DelayedStudyCalendarLoadResult(
                load: sampleStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07"),
                delayNanoseconds: 0
            ),
            DelayedStudyCalendarLoadResult(
                load: sampleStudyCalendarLoad(start: "2026-06-08", end: "2026-06-14"),
                delayNanoseconds: 100_000_000
            )
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        let olderRequest = Task {
            await vm.fetchStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07")
        }
        await mock.waitForStudyCalendarLoadCallCount(1)
        let newerRequest = Task {
            await vm.fetchStudyCalendarLoad(start: "2026-06-08", end: "2026-06-14")
        }
        await mock.waitForStudyCalendarLoadCallCount(2)
        await olderRequest.value

        XCTAssertTrue(vm.isFetchingStudyCalendarLoad)

        await newerRequest.value

        XCTAssertEqual(vm.studyCalendarLoad?.startDate, "2026-06-08")
        XCTAssertFalse(vm.isFetchingStudyCalendarLoad)
    }

    func testConfirmStudyPlanDraftIgnoresDuplicateSubmitWhileInFlight() async {
        let mock = MockAssistantAPIClient()
        mock.studyPlanConfirmDelayNanoseconds = 50_000_000
        mock.dashboardFetchDelayNanoseconds = 10_000_000
        mock.studyTodayViewResult = sampleStudyTodayView(
            tasks: [
                sampleStudyViewTaskJSON(id: 7, title: "Activated", targetMinutes: 30, projectTitle: "Course")
            ]
        )
        mock.resourcesResult = [sampleResource(id: 101, title: "Course")]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.studyPlanDraftId = 42
        vm.studyPlanClarification = sampleStudyPlanClarification()
        vm.studyPlanDraft = sampleStudyPlanDraft()

        let first = Task { await vm.confirmStudyPlanDraft() }
        await mock.waitForStudyPlanConfirmToStart()
        XCTAssertTrue(vm.isConfirmingStudyPlanDraft)
        XCTAssertEqual(mock.confirmStudyPlanDraftCallCount, 1)
        let second = Task { await vm.confirmStudyPlanDraft() }
        await first.value
        await second.value

        XCTAssertEqual(mock.confirmStudyPlanDraftCallCount, 1)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 1)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
        XCTAssertEqual(mock.fetchResourcesCallCount, 1)
        XCTAssertFalse(vm.isConfirmingStudyPlanDraft)
        XCTAssertNil(vm.studyPlanDraftId)
    }

    func testWaitForStudyPlanConfirmToStartReturnsWhenConfirmAlreadyStartedBeforeWaiterRegisters() async {
        let mock = MockAssistantAPIClient()

        mock.recordStudyPlanConfirmStartedForWaiterTest()
        await mock.waitForStudyPlanConfirmToStart()

        XCTAssertEqual(mock.confirmStudyPlanDraftCallCount, 1)
    }

    func testConfirmStudyPlanDraftBlocksStartAndStillClearsDraftAndRefreshesDashboard() async throws {
        let mock = MockAssistantAPIClient()
        mock.studyPlanConfirmDelayNanoseconds = 50_000_000
        mock.studyTodayViewResult = sampleStudyTodayView(
            tasks: [
                sampleStudyViewTaskJSON(id: 7, title: "Activated", targetMinutes: 30, projectTitle: "Course")
            ]
        )
        mock.resourcesResult = [sampleResource(id: 101, title: "Course")]
        mock.studyPlanStartResult = StudyPlanStartResponse(
            draftId: 84,
            clarification: sampleStudyPlanClarification()
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.studyPlanDraftId = 42
        vm.studyPlanClarification = sampleStudyPlanClarification()
        vm.studyPlanDraft = sampleStudyPlanDraft()
        let deadline = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-01T12:00:00Z"))

        let confirm = Task { await vm.confirmStudyPlanDraft() }
        await mock.waitForStudyPlanConfirmToStart()
        XCTAssertTrue(vm.isConfirmingStudyPlanDraft)
        await vm.startStudyPlan(
            url: "https://example.com/new-course",
            deadline: deadline,
            capacityMinutes: 90
        )
        await confirm.value

        XCTAssertNil(mock.lastStudyPlanStartURL)
        XCTAssertEqual(mock.lastConfirmedStudyPlanDraftId, 42)
        XCTAssertNil(vm.studyPlanDraftId)
        XCTAssertNil(vm.studyPlanClarification)
        XCTAssertNil(vm.studyPlanDraft)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 1)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
        XCTAssertEqual(mock.fetchResourcesCallCount, 1)
        XCTAssertEqual(vm.tasks.map(\.id), [7])
        XCTAssertEqual(vm.resources.map(\.id), [101])
        XCTAssertFalse(vm.isStartingStudyPlan)
        XCTAssertFalse(vm.isConfirmingStudyPlanDraft)
    }

    func testConfirmStudyPlanDraftBlocksCancelAndStillClearsDraftAndRefreshesDashboard() async {
        let mock = MockAssistantAPIClient()
        mock.studyPlanConfirmDelayNanoseconds = 50_000_000
        mock.studyTodayViewResult = sampleStudyTodayView(
            tasks: [
                sampleStudyViewTaskJSON(id: 7, title: "Activated", targetMinutes: 30, projectTitle: "Course")
            ]
        )
        mock.resourcesResult = [sampleResource(id: 101, title: "Course")]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.studyPlanDraftId = 42
        vm.studyPlanClarification = sampleStudyPlanClarification()
        vm.studyPlanDraft = sampleStudyPlanDraft()

        let confirm = Task { await vm.confirmStudyPlanDraft() }
        await mock.waitForStudyPlanConfirmToStart()
        XCTAssertTrue(vm.isConfirmingStudyPlanDraft)
        await vm.cancelStudyPlanDraft()
        await confirm.value

        XCTAssertNil(mock.lastCancelledStudyPlanDraftId)
        XCTAssertEqual(mock.lastConfirmedStudyPlanDraftId, 42)
        XCTAssertNil(vm.studyPlanDraftId)
        XCTAssertNil(vm.studyPlanClarification)
        XCTAssertNil(vm.studyPlanDraft)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 1)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
        XCTAssertEqual(mock.fetchResourcesCallCount, 1)
        XCTAssertFalse(vm.isConfirmingStudyPlanDraft)
    }

    func testStudyPlanAPIFailureSetsErrorAndDoesNotSilentlyConfirm() async {
        let mock = MockAssistantAPIClient()
        mock.shouldThrowOffline = true
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.studyPlanDraftId = 42
        vm.studyPlanClarification = sampleStudyPlanClarification()
        vm.studyPlanDraft = sampleStudyPlanDraft()

        await vm.confirmStudyPlanDraft()

        XCTAssertTrue(vm.isOffline)
        XCTAssertNotNil(vm.studyPlanError)
        XCTAssertEqual(vm.studyPlanDraftId, 42)
        XCTAssertNotNil(vm.studyPlanDraft)
        XCTAssertNil(mock.lastConfirmedStudyPlanDraftId)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
        XCTAssertEqual(mock.fetchResourcesCallCount, 0)
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
        XCTAssertGreaterThanOrEqual(mock.fetchStudyTodayViewCallCount, 1)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
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
        mock.studyTodayViewResult = sampleStudyTodayView(
            tasks: [
                sampleStudyViewTaskJSON(id: 7, title: "Next", targetMinutes: 20, projectTitle: "Remaining Resource")
            ]
        )
        let resource = sampleResource(id: 42, title: "Swift Concurrency Guide")
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.resources = [resource]

        await vm.completeResource(resource)

        XCTAssertEqual(mock.lastCompleteResourceId, 42)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 1)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
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
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 1)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
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
        mock.studyTodayViewResult = sampleStudyTodayView(
            tasks: [
                sampleStudyViewTaskJSON(id: 200, title: "Server Update", targetMinutes: 15, projectTitle: "Server")
            ]
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
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 1)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
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
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 1)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
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
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 1)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
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

    // MARK: 8.3 Study Plan Adjustment ViewModel

    func testRolloverCallsAdjustmentEndpointAndRefreshesDashboardAndLoadedCalendar() async {
        let mock = MockAssistantAPIClient()
        mock.studyTodayViewResult = sampleStudyTodayView(
            tasks: [
                sampleStudyViewTaskJSON(id: 42, title: "Rolled", targetMinutes: 25, projectTitle: "Swift")
            ]
        )
        mock.resourcesResult = [sampleResource(id: 7, title: "Swift")]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07")

        await vm.rolloverStudyTasks()

        XCTAssertEqual(mock.rolloverStudyTasksCallCount, 1)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 1)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 1)
        XCTAssertEqual(mock.fetchResourcesCallCount, 1)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 2)
        XCTAssertEqual(mock.lastStudyCalendarLoadStart, "2026-06-01")
        XCTAssertEqual(mock.lastStudyCalendarLoadEnd, "2026-06-07")
        XCTAssertEqual(vm.studyTodayView?.tasks.map(\.id), [42])
        XCTAssertNil(vm.studyPlanAdjustmentError)
        XCTAssertFalse(vm.isAdjustingStudyPlan)
        XCTAssertEqual(mock.sendMessageCallCount, 0)
        XCTAssertEqual(mock.confirmChatCallCount, 0)
    }

    func testMoveStudyTaskCallsAPIAndRefreshesPersistedFactsWithoutLocalCascade() async {
        let mock = MockAssistantAPIClient()
        mock.studyCalendarLoadResult = sampleStudyCalendarLoad(start: "2026-06-08", end: "2026-06-14")
        mock.studyTodayViewResult = sampleStudyTodayView(
            tasks: [
                sampleStudyViewTaskJSON(id: 42, title: "Moved from server", targetMinutes: 30, projectTitle: "Systems")
            ]
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchStudyCalendarLoad(start: "2026-06-08", end: "2026-06-14")

        await vm.moveStudyTask(id: 42, scheduledDate: "2026-06-12")

        XCTAssertEqual(mock.moveStudyTaskCallCount, 1)
        XCTAssertEqual(mock.lastMovedStudyTaskId, 42)
        XCTAssertEqual(mock.lastMovedStudyTaskScheduledDate, "2026-06-12")
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 1)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 1)
        XCTAssertEqual(mock.fetchResourcesCallCount, 1)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 2)
        XCTAssertEqual(mock.lastStudyCalendarLoadStart, "2026-06-08")
        XCTAssertEqual(mock.lastStudyCalendarLoadEnd, "2026-06-14")
        XCTAssertEqual(vm.visibleTodayTasks.map(\.id), [42])
        XCTAssertNil(vm.studyPlanAdjustmentError)
    }

    func testDeadlineEditRefreshesDashboardAndCalendarWithoutLocalTaskDateMutation() async {
        let mock = MockAssistantAPIClient()
        mock.studyCalendarLoadResult = sampleStudyCalendarLoad(start: "2026-06-15", end: "2026-06-21")
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchStudyCalendarLoad(start: "2026-06-15", end: "2026-06-21")

        await vm.updateStudyProjectDeadline(projectId: 7, deadline: "2026-07-01")

        XCTAssertEqual(mock.updateStudyProjectDeadlineCallCount, 1)
        XCTAssertEqual(mock.lastUpdatedStudyProjectDeadlineProjectId, 7)
        XCTAssertEqual(mock.lastUpdatedStudyProjectDeadline, "2026-07-01")
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 1)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 1)
        XCTAssertEqual(mock.fetchResourcesCallCount, 1)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 2)
        XCTAssertEqual(mock.lastStudyCalendarLoadStart, "2026-06-15")
        XCTAssertEqual(mock.lastStudyCalendarLoadEnd, "2026-06-21")
        XCTAssertNil(vm.studyPlanAdjustmentError)
    }

    func testInsertAndDeleteTaskCallAPIsAndRefreshDashboardAndCalendar() async {
        let mock = MockAssistantAPIClient()
        mock.studyCalendarLoadResult = sampleStudyCalendarLoad(start: "2026-06-01", end: "2026-06-30")
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchStudyCalendarLoad(start: "2026-06-01", end: "2026-06-30")

        await vm.insertStudyProjectTask(
            projectId: 7,
            title: "Practice actors",
            targetMinutes: 40,
            scheduledDate: "2026-06-10"
        )
        await vm.deleteStudyTask(id: 99)

        XCTAssertEqual(mock.insertStudyProjectTaskCallCount, 1)
        XCTAssertEqual(mock.lastInsertedStudyProjectId, 7)
        XCTAssertEqual(mock.lastInsertedStudyProjectTaskTitle, "Practice actors")
        XCTAssertEqual(mock.lastInsertedStudyProjectTaskTargetMinutes, 40)
        XCTAssertEqual(mock.lastInsertedStudyProjectTaskScheduledDate, "2026-06-10")
        XCTAssertEqual(mock.deleteStudyTaskCallCount, 1)
        XCTAssertEqual(mock.lastDeletedStudyTaskId, 99)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 2)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 2)
        XCTAssertEqual(mock.fetchResourcesCallCount, 2)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 3)
        XCTAssertEqual(mock.lastStudyCalendarLoadStart, "2026-06-01")
        XCTAssertEqual(mock.lastStudyCalendarLoadEnd, "2026-06-30")
        XCTAssertNil(vm.studyPlanAdjustmentError)
    }

    func testRestDayFetchAndUpdateStoreSettingsAndRefreshAfterMutation() async {
        let mock = MockAssistantAPIClient()
        mock.studyRestDaySettingsResult = StudyRestDaySettings(
            weeklyWeekdays: [0, 6],
            oneOffDates: ["2026-06-10"]
        )
        mock.studyRestDaySettingsUpdateResult = sampleStudyRestDaySettingsUpdateResult(
            weeklyWeekdays: [5],
            oneOffDates: ["2026-06-12"]
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.fetchStudyRestDaySettings()
        await vm.fetchStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07")
        await vm.updateStudyRestDaySettings(
            StudyRestDaySettings(weeklyWeekdays: [5], oneOffDates: ["2026-06-12"])
        )

        XCTAssertEqual(mock.fetchStudyRestDaySettingsCallCount, 1)
        XCTAssertEqual(mock.updateStudyRestDaySettingsCallCount, 1)
        XCTAssertEqual(mock.lastUpdatedStudyRestDaySettings?.weeklyWeekdays, [5])
        XCTAssertEqual(mock.lastUpdatedStudyRestDaySettings?.oneOffDates, ["2026-06-12"])
        XCTAssertEqual(vm.studyRestDaySettings?.weeklyWeekdays, [5])
        XCTAssertEqual(vm.studyRestDaySettings?.oneOffDates, ["2026-06-12"])
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 1)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 1)
        XCTAssertEqual(mock.fetchResourcesCallCount, 1)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 2)
        XCTAssertNil(vm.studyPlanAdjustmentError)
    }

    func testDialoguePreviewStoresTypedPreviewWithoutRefreshingOrMutatingDashboard() async {
        let mock = MockAssistantAPIClient()
        mock.studyDialogueAdjustmentPreviewResult = sampleStudyDialogueAdjustmentPreview(
            affectedTaskIds: [42, 43]
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.previewStudyDialogueAdjustment(
            instruction: "push this project by one week",
            projectId: 7
        )

        XCTAssertEqual(mock.previewStudyDialogueAdjustmentCallCount, 1)
        XCTAssertEqual(mock.lastStudyDialoguePreviewInstruction, "push this project by one week")
        XCTAssertEqual(mock.lastStudyDialoguePreviewProjectId, 7)
        XCTAssertEqual(vm.studyDialogueAdjustmentPreview?.affectedTaskIds, [42, 43])
        XCTAssertEqual(vm.studyDialogueAdjustmentPreview?.mutates, false)
        XCTAssertNil(vm.studyDialogueAdjustmentResult)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 0)
        XCTAssertEqual(mock.fetchResourcesCallCount, 0)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 0)
        XCTAssertEqual(mock.sendMessageCallCount, 0)
        XCTAssertEqual(mock.confirmChatCallCount, 0)
        XCTAssertNil(vm.studyPlanAdjustmentError)
    }

    func testDialogueApplyRequiresStoredPreviewThenClearsItAndRefreshes() async {
        let mock = MockAssistantAPIClient()
        let preview = sampleStudyDialogueAdjustmentPreview(affectedTaskIds: [42])
        mock.studyDialogueAdjustmentApplyResult = sampleStudyDialogueAdjustmentApplyResult(
            affectedTaskIds: [42]
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.applyStudyDialogueAdjustment(
            instruction: "push this project by one week",
            projectId: 7
        )
        XCTAssertEqual(mock.applyStudyDialogueAdjustmentCallCount, 0)
        XCTAssertNotNil(vm.studyPlanAdjustmentError)

        vm.studyPlanAdjustmentError = nil
        vm.studyDialogueAdjustmentPreview = preview
        await vm.fetchStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07")

        await vm.applyStudyDialogueAdjustment(
            instruction: "push this project by one week",
            projectId: 7
        )

        XCTAssertEqual(mock.applyStudyDialogueAdjustmentCallCount, 1)
        XCTAssertEqual(mock.lastStudyDialogueApplyInstruction, "push this project by one week")
        XCTAssertEqual(mock.lastStudyDialogueApplyProjectId, 7)
        XCTAssertEqual(mock.lastStudyDialogueApplyPreview?.affectedTaskIds, [42])
        XCTAssertNil(vm.studyDialogueAdjustmentPreview)
        XCTAssertEqual(vm.studyDialogueAdjustmentResult?.status, "applied")
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 1)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 1)
        XCTAssertEqual(mock.fetchResourcesCallCount, 1)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 2)
        XCTAssertEqual(mock.sendMessageCallCount, 0)
        XCTAssertEqual(mock.confirmChatCallCount, 0)
        XCTAssertNil(vm.studyPlanAdjustmentError)
    }

    func testAdjustmentFailureSetsErrorOfflineAndDoesNotRefresh() async {
        let mock = MockAssistantAPIClient()
        mock.adjustmentError = AssistantOfflineError()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.moveStudyTask(id: 42, scheduledDate: "2026-06-12")

        XCTAssertEqual(mock.moveStudyTaskCallCount, 1)
        XCTAssertTrue(vm.isOffline)
        XCTAssertNotNil(vm.studyPlanAdjustmentError)
        XCTAssertFalse(vm.isAdjustingStudyPlan)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 0)
    }

    func testDialoguePreviewFailurePreservesExistingPreviewAndDoesNotRefresh() async {
        let mock = MockAssistantAPIClient()
        let existingPreview = sampleStudyDialogueAdjustmentPreview(affectedTaskIds: [1])
        mock.adjustmentError = AssistantOfflineError()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.studyDialogueAdjustmentPreview = existingPreview

        await vm.previewStudyDialogueAdjustment(
            instruction: "ambiguous request",
            projectId: 7
        )

        XCTAssertEqual(mock.previewStudyDialogueAdjustmentCallCount, 1)
        XCTAssertEqual(vm.studyDialogueAdjustmentPreview?.affectedTaskIds, [1])
        XCTAssertTrue(vm.isOffline)
        XCTAssertNotNil(vm.studyPlanAdjustmentError)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 0)
    }

    func testDialogueApplyFailureKeepsPreviewAndDoesNotRefresh() async {
        let mock = MockAssistantAPIClient()
        let preview = sampleStudyDialogueAdjustmentPreview(affectedTaskIds: [42])
        mock.adjustmentError = AssistantOfflineError()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.studyDialogueAdjustmentPreview = preview

        await vm.applyStudyDialogueAdjustment(
            instruction: "push this project by one week",
            projectId: 7
        )

        XCTAssertEqual(mock.applyStudyDialogueAdjustmentCallCount, 1)
        XCTAssertEqual(vm.studyDialogueAdjustmentPreview?.affectedTaskIds, [42])
        XCTAssertNil(vm.studyDialogueAdjustmentResult)
        XCTAssertTrue(vm.isOffline)
        XCTAssertNotNil(vm.studyPlanAdjustmentError)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 0)
    }
}

// MARK: - Mock API Client

private struct DelayedStudyCalendarLoadResult {
    let load: StudyCalendarLoad
    let delayNanoseconds: UInt64
}

private final class MockAssistantAPIClient: AssistantAPIClientProtocol, @unchecked Sendable {

    // Configurable results
    var briefingResult = TodayBriefing(tasks: [], totalMinutes: 0, highlights: "")
    var resourcesResult: [AssistantResource] = []
    var ingestionResult: IngestionDraft?
    var chatResult: ChatResponse?
    var shouldThrowOffline = false
    var shouldThrowResources = false
    var shouldThrowResourceManagement = false
    var dashboardFetchDelayNanoseconds: UInt64 = 0
    var resourceManagementDelayNanoseconds: UInt64 = 0
    var studyPlanConfirmDelayNanoseconds: UInt64 = 0
    var briefingResultsQueue: [TodayBriefing] = []
    var resourcesResultsQueue: [[AssistantResource]] = []
    // New: for updated protocol methods
    var startIngestionThreadId: String = "mock-thread"
    var progressEvents: [IngestionProgressEvent] = []
    var rescheduleResult: IngestionDraftDetail?
    var rescheduleError: Error?
    var learningPreferencesResult = LearningPreferences(dailyCapacityMin: 60)
    var studyPlanStartResult = sampleStudyPlanStartResponse()
    var studyPlanDraftResult = sampleStudyPlanDraft()
    var studyPlanActivationResult = sampleStudyPlanActivationResult()
    var studyTodayViewResult: StudyTodayView?
    var studyProjectOverviewResult = sampleStudyProjectOverview()
    var studyCalendarLoadResult = sampleStudyCalendarLoad()
    var studyCalendarLoadResultsQueue: [DelayedStudyCalendarLoadResult] = []
    var studyRolloverResult = sampleStudyRolloverResult()
    var studyTaskMoveResult = sampleStudyTaskMoveResult()
    var studyProjectDeadlineUpdateResult = sampleStudyProjectDeadlineUpdateResult()
    var studyTaskInsertResult = sampleStudyTaskInsertResult()
    var studyTaskDeleteResult = sampleStudyTaskDeleteResult()
    var studyRestDaySettingsResult = StudyRestDaySettings(weeklyWeekdays: [], oneOffDates: [])
    var studyRestDaySettingsUpdateResult = sampleStudyRestDaySettingsUpdateResult()
    var studyDialogueAdjustmentPreviewResult = sampleStudyDialogueAdjustmentPreview()
    var studyDialogueAdjustmentApplyResult = sampleStudyDialogueAdjustmentApplyResult()
    var adjustmentError: Error?

    // Captured call arguments for assertions
    private(set) var fetchBriefingCallCount = 0
    private(set) var fetchResourcesCallCount = 0
    private(set) var fetchStudyTodayViewCallCount = 0
    private(set) var fetchStudyProjectOverviewCallCount = 0
    private(set) var fetchStudyCalendarLoadCallCount = 0
    private(set) var maxConcurrentBriefingFetches = 0
    private(set) var maxConcurrentResourceFetches = 0
    private(set) var maxConcurrentStudyTodayViewFetches = 0
    private var activeBriefingFetches = 0
    private var activeResourceFetches = 0
    private var activeStudyTodayViewFetches = 0
    var studyTodayViewResultsQueue: [StudyTodayView] = []
    var studyProjectOverviewResultsQueue: [StudyProjectOverview] = []
    private(set) var lastCompleteTaskId: Int?
    private(set) var rolloverStudyTasksCallCount = 0
    private(set) var moveStudyTaskCallCount = 0
    private(set) var lastMovedStudyTaskId: Int?
    private(set) var lastMovedStudyTaskScheduledDate: String?
    private(set) var updateStudyProjectDeadlineCallCount = 0
    private(set) var lastUpdatedStudyProjectDeadlineProjectId: Int?
    private(set) var lastUpdatedStudyProjectDeadline: String?
    private(set) var insertStudyProjectTaskCallCount = 0
    private(set) var lastInsertedStudyProjectId: Int?
    private(set) var lastInsertedStudyProjectTaskTitle: String?
    private(set) var lastInsertedStudyProjectTaskTargetMinutes: Int?
    private(set) var lastInsertedStudyProjectTaskScheduledDate: String?
    private(set) var deleteStudyTaskCallCount = 0
    private(set) var lastDeletedStudyTaskId: Int?
    private(set) var fetchStudyRestDaySettingsCallCount = 0
    private(set) var updateStudyRestDaySettingsCallCount = 0
    private(set) var lastUpdatedStudyRestDaySettings: StudyRestDaySettings?
    private(set) var previewStudyDialogueAdjustmentCallCount = 0
    private(set) var lastStudyDialoguePreviewInstruction: String?
    private(set) var lastStudyDialoguePreviewProjectId: Int?
    private(set) var applyStudyDialogueAdjustmentCallCount = 0
    private(set) var lastStudyDialogueApplyInstruction: String?
    private(set) var lastStudyDialogueApplyProjectId: Int?
    private(set) var lastStudyDialogueApplyPreview: StudyDialogueAdjustmentPreview?
    private(set) var lastStudyCalendarLoadStart: String?
    private(set) var lastStudyCalendarLoadEnd: String?
    private(set) var lastCompleteResourceId: Int?
    private(set) var lastArchiveResourceId: Int?
    private(set) var completeResourceCallCount = 0
    private(set) var archiveResourceCallCount = 0
    private(set) var sendMessageCallCount = 0
    private(set) var confirmChatCallCount = 0
    private(set) var lastConfirmChatConfirmed: Bool?
    private(set) var lastConfirmIngestionConfirmed: Bool?
    private(set) var lastConfirmIngestionOption: String?
    private(set) var lastConfirmIngestionDeadline: String?
    private(set) var lastConfirmIngestionSpeedFactor: Double?
    private(set) var lastRescheduleDeadline: String?
    private(set) var lastRescheduleSpeedFactor: Double?
    private(set) var lastStudyPlanStartURL: String?
    private(set) var lastStudyPlanStartDeadline: String?
    private(set) var lastStudyPlanStartCapacityMinutes: Int?
    private(set) var lastStudyPlanClarificationDraftId: Int?
    private(set) var lastStudyPlanClarificationAnswers: [String: String] = [:]
    private(set) var lastStudyPlanClarificationSkip: Bool?
    private(set) var lastStudyPlanDurationDraftId: Int?
    private(set) var lastStudyPlanDurationTaskOrderIndex: Int?
    private(set) var lastStudyPlanDurationEstimatedMinutes: Int?
    private(set) var lastCancelledStudyPlanDraftId: Int?
    private(set) var lastConfirmedStudyPlanDraftId: Int?
    private(set) var confirmStudyPlanDraftCallCount = 0
    private let studyPlanConfirmGateLock = NSLock()
    private var studyPlanConfirmStartedContinuations: [CheckedContinuation<Void, Never>] = []
    private let studyCalendarLoadGateLock = NSLock()
    private var studyCalendarLoadCallCountContinuations: [(expected: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func waitForStudyPlanConfirmToStart() async {
        await withCheckedContinuation { continuation in
            let shouldResumeImmediately = withStudyPlanConfirmGateLock {
                if confirmStudyPlanDraftCallCount > 0 {
                    return true
                }
                studyPlanConfirmStartedContinuations.append(continuation)
                return false
            }
            if shouldResumeImmediately {
                continuation.resume()
            }
        }
    }

    func recordStudyPlanConfirmStartedForWaiterTest() {
        signalStudyPlanConfirmStartedAfterRecordingCall()
    }

    func waitForStudyCalendarLoadCallCount(_ expected: Int) async {
        await withCheckedContinuation { continuation in
            let shouldResumeImmediately = withStudyCalendarLoadGateLock {
                if fetchStudyCalendarLoadCallCount >= expected {
                    return true
                }
                studyCalendarLoadCallCountContinuations.append((expected, continuation))
                return false
            }
            if shouldResumeImmediately {
                continuation.resume()
            }
        }
    }

    func fetchTodayBriefing() async throws -> TodayBriefing {
        fetchBriefingCallCount += 1
        activeBriefingFetches += 1
        maxConcurrentBriefingFetches = max(maxConcurrentBriefingFetches, activeBriefingFetches)
        defer { activeBriefingFetches -= 1 }
        if dashboardFetchDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: dashboardFetchDelayNanoseconds)
        }
        if shouldThrowOffline { throw AssistantOfflineError() }
        if !briefingResultsQueue.isEmpty {
            return briefingResultsQueue.removeFirst()
        }
        return briefingResult
    }

    func fetchStudyTodayView() async throws -> StudyTodayView {
        fetchStudyTodayViewCallCount += 1
        activeStudyTodayViewFetches += 1
        maxConcurrentStudyTodayViewFetches = max(maxConcurrentStudyTodayViewFetches, activeStudyTodayViewFetches)
        defer { activeStudyTodayViewFetches -= 1 }
        if dashboardFetchDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: dashboardFetchDelayNanoseconds)
        }
        if shouldThrowOffline { throw AssistantOfflineError() }
        if !studyTodayViewResultsQueue.isEmpty {
            return studyTodayViewResultsQueue.removeFirst()
        }
        if let studyTodayViewResult {
            return studyTodayViewResult
        }
        if !briefingResultsQueue.isEmpty {
            return sampleStudyTodayView(from: briefingResultsQueue.removeFirst())
        }
        return sampleStudyTodayView(from: briefingResult)
    }

    func fetchStudyProjectOverview() async throws -> StudyProjectOverview {
        fetchStudyProjectOverviewCallCount += 1
        if dashboardFetchDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: dashboardFetchDelayNanoseconds)
        }
        if shouldThrowOffline { throw AssistantOfflineError() }
        if !studyProjectOverviewResultsQueue.isEmpty {
            return studyProjectOverviewResultsQueue.removeFirst()
        }
        return studyProjectOverviewResult
    }

    func fetchStudyCalendarLoad(start: String, end: String) async throws -> StudyCalendarLoad {
        fetchStudyCalendarLoadCallCount += 1
        lastStudyCalendarLoadStart = start
        lastStudyCalendarLoadEnd = end
        signalStudyCalendarLoadCallCountChanged()
        if shouldThrowOffline { throw AssistantOfflineError() }
        if !studyCalendarLoadResultsQueue.isEmpty {
            let result = studyCalendarLoadResultsQueue.removeFirst()
            if result.delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: result.delayNanoseconds)
            }
            return result.load
        }
        return studyCalendarLoadResult
    }

    func completeTask(id: Int, actualMinutes: Int?) async throws -> TaskCompletionResult {
        if shouldThrowOffline { throw AssistantOfflineError() }
        lastCompleteTaskId = id
        return TaskCompletionResult(taskId: id, completedAt: "2026-06-01T12:30:00")
    }

    func rolloverStudyTasks() async throws -> StudyRolloverResult {
        rolloverStudyTasksCallCount += 1
        if let adjustmentError { throw adjustmentError }
        if shouldThrowOffline { throw AssistantOfflineError() }
        return studyRolloverResult
    }

    func moveStudyTask(id: Int, scheduledDate: String) async throws -> StudyTaskMoveResult {
        moveStudyTaskCallCount += 1
        lastMovedStudyTaskId = id
        lastMovedStudyTaskScheduledDate = scheduledDate
        if let adjustmentError { throw adjustmentError }
        if shouldThrowOffline { throw AssistantOfflineError() }
        return studyTaskMoveResult
    }

    func updateStudyProjectDeadline(projectId: Int, deadline: String) async throws -> StudyProjectDeadlineUpdateResult {
        updateStudyProjectDeadlineCallCount += 1
        lastUpdatedStudyProjectDeadlineProjectId = projectId
        lastUpdatedStudyProjectDeadline = deadline
        if let adjustmentError { throw adjustmentError }
        if shouldThrowOffline { throw AssistantOfflineError() }
        return studyProjectDeadlineUpdateResult
    }

    func insertStudyProjectTask(
        projectId: Int,
        title: String,
        targetMinutes: Int,
        scheduledDate: String
    ) async throws -> StudyTaskInsertResult {
        insertStudyProjectTaskCallCount += 1
        lastInsertedStudyProjectId = projectId
        lastInsertedStudyProjectTaskTitle = title
        lastInsertedStudyProjectTaskTargetMinutes = targetMinutes
        lastInsertedStudyProjectTaskScheduledDate = scheduledDate
        if let adjustmentError { throw adjustmentError }
        if shouldThrowOffline { throw AssistantOfflineError() }
        return studyTaskInsertResult
    }

    func deleteStudyTask(id: Int) async throws -> StudyTaskDeleteResult {
        deleteStudyTaskCallCount += 1
        lastDeletedStudyTaskId = id
        if let adjustmentError { throw adjustmentError }
        if shouldThrowOffline { throw AssistantOfflineError() }
        return studyTaskDeleteResult
    }

    func fetchStudyRestDaySettings() async throws -> StudyRestDaySettings {
        fetchStudyRestDaySettingsCallCount += 1
        if let adjustmentError { throw adjustmentError }
        if shouldThrowOffline { throw AssistantOfflineError() }
        return studyRestDaySettingsResult
    }

    func updateStudyRestDaySettings(_ settings: StudyRestDaySettings) async throws -> StudyRestDaySettingsUpdateResult {
        updateStudyRestDaySettingsCallCount += 1
        lastUpdatedStudyRestDaySettings = settings
        if let adjustmentError { throw adjustmentError }
        if shouldThrowOffline { throw AssistantOfflineError() }
        return studyRestDaySettingsUpdateResult
    }

    func previewStudyDialogueAdjustment(
        instruction: String,
        projectId: Int?
    ) async throws -> StudyDialogueAdjustmentPreview {
        previewStudyDialogueAdjustmentCallCount += 1
        lastStudyDialoguePreviewInstruction = instruction
        lastStudyDialoguePreviewProjectId = projectId
        if let adjustmentError { throw adjustmentError }
        if shouldThrowOffline { throw AssistantOfflineError() }
        return studyDialogueAdjustmentPreviewResult
    }

    func applyStudyDialogueAdjustment(
        instruction: String,
        projectId: Int?,
        preview: StudyDialogueAdjustmentPreview
    ) async throws -> StudyDialogueAdjustmentApplyResult {
        applyStudyDialogueAdjustmentCallCount += 1
        lastStudyDialogueApplyInstruction = instruction
        lastStudyDialogueApplyProjectId = projectId
        lastStudyDialogueApplyPreview = preview
        if let adjustmentError { throw adjustmentError }
        if shouldThrowOffline { throw AssistantOfflineError() }
        return studyDialogueAdjustmentApplyResult
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
        sendMessageCallCount += 1
        if shouldThrowOffline { throw AssistantOfflineError() }
        return chatResult ?? ChatResponse(threadId: "mock", response: "ok", proposal: nil)
    }

    func confirmChat(threadId: String, confirmed: Bool) async throws {
        confirmChatCallCount += 1
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

    func startStudyPlan(url: String, deadline: String, capacityMinutes: Int) async throws -> StudyPlanStartResponse {
        if shouldThrowOffline { throw AssistantOfflineError() }
        lastStudyPlanStartURL = url
        lastStudyPlanStartDeadline = deadline
        lastStudyPlanStartCapacityMinutes = capacityMinutes
        return studyPlanStartResult
    }

    func submitStudyPlanClarification(
        draftId: Int,
        answers: [String: String],
        skip: Bool
    ) async throws -> StudyPlanDraft {
        if shouldThrowOffline { throw AssistantOfflineError() }
        lastStudyPlanClarificationDraftId = draftId
        lastStudyPlanClarificationAnswers = answers
        lastStudyPlanClarificationSkip = skip
        return studyPlanDraftResult
    }

    func updateStudyPlanDraftTaskDuration(
        draftId: Int,
        taskOrderIndex: Int,
        estimatedMinutes: Int
    ) async throws -> StudyPlanDraft {
        if shouldThrowOffline { throw AssistantOfflineError() }
        lastStudyPlanDurationDraftId = draftId
        lastStudyPlanDurationTaskOrderIndex = taskOrderIndex
        lastStudyPlanDurationEstimatedMinutes = estimatedMinutes
        return studyPlanDraftResult
    }

    func cancelStudyPlanDraft(draftId: Int) async throws {
        if shouldThrowOffline { throw AssistantOfflineError() }
        lastCancelledStudyPlanDraftId = draftId
    }

    func confirmStudyPlanDraft(draftId: Int) async throws -> StudyPlanActivationResult {
        signalStudyPlanConfirmStartedAfterRecordingCall()
        if studyPlanConfirmDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: studyPlanConfirmDelayNanoseconds)
        }
        if shouldThrowOffline { throw AssistantOfflineError() }
        lastConfirmedStudyPlanDraftId = draftId
        return studyPlanActivationResult
    }

    private func signalStudyPlanConfirmStartedAfterRecordingCall() {
        let continuations = withStudyPlanConfirmGateLock {
            confirmStudyPlanDraftCallCount += 1
            let continuations = studyPlanConfirmStartedContinuations
            studyPlanConfirmStartedContinuations.removeAll()
            return continuations
        }
        continuations.forEach { $0.resume() }
    }

    private func withStudyPlanConfirmGateLock<T>(_ body: () -> T) -> T {
        studyPlanConfirmGateLock.lock()
        defer { studyPlanConfirmGateLock.unlock() }
        return body()
    }

    private func signalStudyCalendarLoadCallCountChanged() {
        let continuations = withStudyCalendarLoadGateLock {
            var ready: [CheckedContinuation<Void, Never>] = []
            studyCalendarLoadCallCountContinuations.removeAll { waiter in
                if fetchStudyCalendarLoadCallCount >= waiter.expected {
                    ready.append(waiter.continuation)
                    return true
                }
                return false
            }
            return ready
        }
        continuations.forEach { $0.resume() }
    }

    private func withStudyCalendarLoadGateLock<T>(_ body: () -> T) -> T {
        studyCalendarLoadGateLock.lock()
        defer { studyCalendarLoadGateLock.unlock() }
        return body()
    }

    func fetchResources() async throws -> [AssistantResource] {
        fetchResourcesCallCount += 1
        activeResourceFetches += 1
        maxConcurrentResourceFetches = max(maxConcurrentResourceFetches, activeResourceFetches)
        defer { activeResourceFetches -= 1 }
        if dashboardFetchDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: dashboardFetchDelayNanoseconds)
        }
        if shouldThrowOffline || shouldThrowResources { throw AssistantOfflineError() }
        if !resourcesResultsQueue.isEmpty {
            return resourcesResultsQueue.removeFirst()
        }
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

@MainActor
private final class MockBackendLifecycle: AppBackendLifecycleManaging {
    var isReady = false
    var isStarting = false
    private(set) var startIfNeededCallCount = 0
    private(set) var stopCallCount = 0

    func startIfNeeded() {
        startIfNeededCallCount += 1
        isStarting = true
    }

    func stop() {
        stopCallCount += 1
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

private func sampleStudyPlanClarification() -> StudyPlanClarification {
    StudyPlanClarification(
        version: "d30-guided-clarification-v1",
        materialType: "documentation",
        questions: [
            StudyPlanClarificationQuestion(
                id: "goal_depth",
                prompt: "What learning goal should guide the plan?",
                options: [
                    StudyPlanClarificationOption(
                        id: "recommended",
                        label: "Use recommended goal",
                        value: "understand_and_apply",
                        recommended: true,
                        isDefault: true
                    )
                ]
            )
        ],
        defaults: ["goal_depth": "understand_and_apply"],
        skipAction: StudyPlanSkipAction(
            id: "generate_rough_draft",
            label: "Generate rough draft",
            usesDefaults: true
        )
    )
}

private func sampleStudyPlanStartResponse() -> StudyPlanStartResponse {
    StudyPlanStartResponse(
        draftId: 42,
        clarification: sampleStudyPlanClarification()
    )
}

private func sampleStudyPlanDraft(
    estimatedMinutes: Int = 25,
    status: String = "review",
    lowCalibration: Bool = true,
    clarificationSkipped: Bool = true
) -> StudyPlanDraft {
    StudyPlanDraft(
        id: 42,
        title: "Sample Study Plan",
        sourceURL: URL(string: "https://example.com/course")!,
        deadline: "2026-07-01",
        status: status,
        capacityMinutes: 60,
        clarificationSkipped: clarificationSkipped,
        lowCalibration: lowCalibration,
        tasks: [
            StudyPlanDraftTask(
                title: "Map the course structure",
                orderIndex: 0,
                estimatedMinutes: estimatedMinutes,
                scheduledDate: "2026-06-20",
                targetMinutes: estimatedMinutes
            )
        ],
        expectedLate: false,
        overCapacityDays: []
    )
}

private func sampleStudyPlanActivationResult() -> StudyPlanActivationResult {
    StudyPlanActivationResult(
        id: 42,
        resourceId: 101,
        status: "active",
        sourceURL: URL(string: "https://example.com/course")!,
        deadline: "2026-07-01",
        capacityMinutes: 60,
        clarificationSkipped: true
    )
}

private func sampleStudyTodayView(
    date: String = "2026-06-01",
    tasks: [String] = []
) -> StudyTodayView {
    let taskPayload = tasks.isEmpty ? "" : tasks.joined(separator: ",")
    let json = """
    {
        "date": "\(date)",
        "tasks": [\(taskPayload)]
    }
    """
    return try! JSONDecoder().decode(StudyTodayView.self, from: Data(json.utf8))
}

private func sampleStudyTodayView(from briefing: TodayBriefing, date: String = "2026-06-01") -> StudyTodayView {
    func nullable(_ value: Any?) -> Any { value ?? NSNull() }
    let taskPayloads = briefing.tasks.map { task -> [String: Any] in
        [
            "id": task.id,
            "title": task.title,
            "target_minutes": task.targetMinutes,
            "completed_at": nullable(task.completedAt),
            "project_id": NSNull(),
            "project_title": NSNull(),
            "resource_id": NSNull(),
            "resource_title": nullable(task.resourceTitle),
            "resource_url": nullable(task.resourceURL?.absoluteString),
            "unit_id": NSNull(),
            "unit_title": NSNull(),
            "unit_url": nullable(task.unitURL?.absoluteString)
        ]
    }
    let payload: [String: Any] = [
        "date": date,
        "tasks": taskPayloads
    ]
    let data = try! JSONSerialization.data(withJSONObject: payload)
    return try! JSONDecoder().decode(StudyTodayView.self, from: data)
}

private func sampleStudyViewTaskJSON(
    id: Int,
    title: String,
    targetMinutes: Int,
    completedAt: String? = nil,
    projectTitle: String? = nil,
    resourceTitle: String? = nil,
    unitTitle: String? = nil
) -> String {
    """
    {
        "id": \(id),
        "title": "\(title)",
        "target_minutes": \(targetMinutes),
        "completed_at": \(completedAt.map { "\"\($0)\"" } ?? "null"),
        "project_id": 1,
        "project_title": \(projectTitle.map { "\"\($0)\"" } ?? "null"),
        "resource_id": 2,
        "resource_title": \(resourceTitle.map { "\"\($0)\"" } ?? "null"),
        "resource_url": "https://example.com/resource/\(id)",
        "unit_id": 3,
        "unit_title": \(unitTitle.map { "\"\($0)\"" } ?? "null"),
        "unit_url": "https://example.com/unit/\(id)"
    }
    """
}

private func sampleStudyProjectOverview(
    activeProjects: [String] = [],
    completedProjects: [String] = []
) -> StudyProjectOverview {
    let json = """
    {
        "active_projects": [\(activeProjects.joined(separator: ","))],
        "completed_projects": [\(completedProjects.joined(separator: ","))]
    }
    """
    return try! JSONDecoder().decode(StudyProjectOverview.self, from: Data(json.utf8))
}

private func sampleStudyProjectSummaryJSON(
    id: Int,
    title: String,
    completedUnits: Int,
    totalUnits: Int,
    progressRatio: Double,
    status: String
) -> String {
    """
    {
        "id": \(id),
        "title": "\(title)",
        "completed_units": \(completedUnits),
        "total_units": \(totalUnits),
        "progress_ratio": \(progressRatio),
        "target_minutes": 240,
        "actual_minutes": 90,
        "deadline": "2026-07-01",
        "status": "\(status)"
    }
    """
}

private func sampleStudyCalendarLoad(
    start: String = "2026-06-01",
    end: String = "2026-06-07",
    dayJSON: String = """
    {
        "date": "2026-06-01",
        "scheduled_task_count": 0,
        "total_target_minutes": 0,
        "completed_task_count": 0,
        "over_capacity": false
    }
    """
) -> StudyCalendarLoad {
    let json = """
    {
        "start_date": "\(start)",
        "end_date": "\(end)",
        "daily_capacity_minutes": 75,
        "days": [\(dayJSON)]
    }
    """
    return try! JSONDecoder().decode(StudyCalendarLoad.self, from: Data(json.utf8))
}

private func sampleStudyRolloverResult() -> StudyRolloverResult {
    StudyRolloverResult(
        date: "2026-06-01",
        rolledCount: 1,
        rolledTasks: [
            StudyRolloverTask(
                taskId: 42,
                projectId: 7,
                oldDate: "2026-05-31",
                newDate: "2026-06-01",
                rolledDays: 1,
                autoRollDays: 3
            )
        ]
    )
}

private func sampleStudyTaskMoveResult() -> StudyTaskMoveResult {
    StudyTaskMoveResult(
        taskId: 42,
        source: "manual_move",
        affectedCount: 2,
        changes: [
            StudyAdjustmentChange(taskId: 42, projectId: 7, oldDate: "2026-06-01", newDate: "2026-06-12"),
            StudyAdjustmentChange(taskId: 43, projectId: 7, oldDate: "2026-06-02", newDate: "2026-06-13")
        ]
    )
}

private func sampleStudyProjectDeadlineUpdateResult() -> StudyProjectDeadlineUpdateResult {
    StudyProjectDeadlineUpdateResult(
        projectId: 7,
        oldDeadline: "2026-06-30",
        newDeadline: "2026-07-01",
        source: "deadline_edit"
    )
}

private func sampleStudyTaskInsertResult() -> StudyTaskInsertResult {
    StudyTaskInsertResult(
        projectId: 7,
        taskId: 99,
        scheduledDate: "2026-06-10",
        targetMinutes: 40,
        title: "Practice actors",
        source: "manual_insert"
    )
}

private func sampleStudyTaskDeleteResult() -> StudyTaskDeleteResult {
    StudyTaskDeleteResult(
        projectId: 7,
        taskId: 99,
        scheduledDate: "2026-06-10",
        source: "manual_delete",
        projectCompleted: false
    )
}

private func sampleStudyRestDaySettingsUpdateResult(
    weeklyWeekdays: [Int] = [5],
    oneOffDates: [String] = ["2026-06-12"]
) -> StudyRestDaySettingsUpdateResult {
    StudyRestDaySettingsUpdateResult(
        weeklyWeekdays: weeklyWeekdays,
        oneOffDates: oneOffDates,
        addedWeeklyWeekdays: weeklyWeekdays,
        removedWeeklyWeekdays: [],
        addedOneOffDates: oneOffDates,
        removedOneOffDates: [],
        source: "manual_rest_day_settings"
    )
}

private func sampleStudyDialogueAdjustmentPreview(
    affectedTaskIds: [Int] = [42]
) -> StudyDialogueAdjustmentPreview {
    StudyDialogueAdjustmentPreview(
        status: "preview",
        source: "dialogue_preview",
        command: "project_shift",
        projectId: 7,
        deltaDays: 7,
        affectedTaskIds: affectedTaskIds,
        changes: affectedTaskIds.map {
            StudyAdjustmentChange(
                taskId: $0,
                projectId: 7,
                oldDate: "2026-06-01",
                newDate: "2026-06-08"
            )
        },
        redStateImpact: nil,
        mutates: false,
        message: nil
    )
}

private func sampleStudyDialogueAdjustmentApplyResult(
    affectedTaskIds: [Int] = [42]
) -> StudyDialogueAdjustmentApplyResult {
    StudyDialogueAdjustmentApplyResult(
        status: "applied",
        source: "dialogue_apply",
        command: "project_shift",
        projectId: 7,
        deltaDays: 7,
        affectedTaskIds: affectedTaskIds,
        changes: affectedTaskIds.map {
            StudyAdjustmentChange(
                taskId: $0,
                projectId: 7,
                oldDate: "2026-06-01",
                newDate: "2026-06-08"
            )
        },
        mutates: true,
        refresh: StudyRefreshContract(today: true, projectOverview: true, calendar: true),
        message: nil
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
