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

    // MARK: Add / Initiate Session Contract

    func testAddInitiateSessionModelsDecodeSessionReviewAndProgressIdentity() throws {
        let session = try decode(AddInitiateSessionResponse.self, from: """
        {
            "sessionId": "add-initiate-42",
            "clientRequestId": "req-42",
            "intakeItemId": 42,
            "draftId": 101,
            "draftVersion": 3,
            "stage": "draft_review",
            "reviewState": "draft_review",
            "recommendedRole": "new_plan",
            "confirmedRole": "new_plan",
            "confidence": "high",
            "reasonCodes": ["planning_language"],
            "nextAction": "review_draft",
            "createsActiveTasks": false
        }
        """)
        let event = try decode(AddInitiateProgressEvent.self, from: """
        {
            "sessionId": "add-initiate-42",
            "clientRequestId": "req-42",
            "stage": "preparing_review",
            "reviewState": "draft_review",
            "draftId": 101,
            "draftVersion": 3,
            "createsActiveTasks": false,
            "done": false
        }
        """)
        let stored = try decode(AddInitiateSessionResponse.self, from: """
        {
            "sessionId": "add-initiate-43",
            "clientRequestId": "req-43",
            "intakeItemId": 43,
            "stage": "stored_non_plan",
            "reviewState": "stored_non_plan",
            "recommendedRole": "reference_material",
            "nextAction": "confirm_non_plan_storage",
            "createsActiveTasks": false
        }
        """)
        let needsInput = try decode(AddInitiateSessionResponse.self, from: """
        {
            "sessionId": "add-initiate-44",
            "clientRequestId": "req-44",
            "intakeItemId": 44,
            "stage": "needs_input",
            "reviewState": "needs_input",
            "recommendedRole": "later_resource",
            "confidence": "low",
            "nextAction": "answer_routing_question",
            "createsActiveTasks": false,
            "clarificationQuestion": {
                "prompt": "Where should this go?",
                "recommendedDefault": "later_resource",
                "options": ["new_plan", "later_resource"]
            }
        }
        """)
        let role = try decode(AddInitiateSessionResponse.self, from: """
        {
            "sessionId": "add-initiate-45",
            "clientRequestId": "req-45",
            "intakeItemId": 45,
            "stage": "role_review",
            "reviewState": "role_review",
            "recommendedRole": "attach_to_existing_plan",
            "confidence": "high",
            "nextAction": "role_review",
            "attachmentModeSuggestion": "material_only",
            "canonicalRepoRole": "project_material",
            "existingPlanCandidates": [{"id": 7, "title": "Compiler Study"}],
            "createsActiveTasks": false
        }
        """)
        let review = try decode(AddInitiateSessionResponse.self, from: """
        {
            "sessionId": "add-initiate-46",
            "clientRequestId": "req-46",
            "intakeItemId": 46,
            "draftId": 90,
            "draftVersion": 2,
            "stage": "draft_review",
            "reviewState": "draft_review",
            "createsActiveTasks": false,
            "reviewPackage": {
                "draft_version": 2,
                "summary": "Review package",
                "option_effect": {"id": "lower_depth"}
            },
            "activationResult": {
                "status": "active",
                "resource_id": 10
            }
        }
        """)

        XCTAssertEqual(session.sessionId, "add-initiate-42")
        XCTAssertEqual(session.intakeItemId, 42)
        XCTAssertEqual(session.draftId, 101)
        XCTAssertEqual(session.draftVersion, 3)
        XCTAssertEqual(session.stage, .draftReview)
        XCTAssertEqual(session.reviewState, .draftReview)
        XCTAssertFalse(session.createsActiveTasks)
        XCTAssertEqual(event.stage, .preparingReview)
        XCTAssertEqual(event.reviewState, .draftReview)
        XCTAssertEqual(event.draftVersion, 3)
        XCTAssertEqual(stored.stage, .storedNonPlan)
        XCTAssertEqual(stored.reviewState, .storedNonPlan)
        XCTAssertFalse(stored.createsActiveTasks)
        XCTAssertEqual(needsInput.clarificationQuestion?["prompt"]?.value as? String, "Where should this go?")
        XCTAssertEqual(role.attachmentModeSuggestion, "material_only")
        XCTAssertEqual(role.canonicalRepoRole, "project_material")
        XCTAssertEqual(role.existingPlanCandidates?.first?["title"]?.value as? String, "Compiler Study")
        XCTAssertEqual(review.reviewPackage?["summary"]?.value as? String, "Review package")
        XCTAssertEqual(review.activationResult?["status"]?.value as? String, "active")
    }

    func testAddInitiateRequestBodiesEncodeCamelCaseContractKeys() throws {
        let start = AddInitiateStartSessionRequest(
            clientRequestId: "req-start",
            rawInput: "Learn FastAPI by August",
            sourceType: "text_goal",
            userHint: "new plan",
            existingPlanId: nil
        )
        let role = AddInitiateRoleConfirmationRequest(
            sessionId: "add-initiate-1",
            intakeItemId: 1,
            confirmedRole: "attach_to_existing_plan",
            title: "FastAPI notes",
            url: "https://example.com/fastapi",
            existingPlanId: 7,
            attachmentMode: "material_only",
            canonicalRepoRole: nil,
            metadata: ["source": AnyCodable("manual")]
        )
        let anchors = AddInitiateAnchorConfirmationRequest(
            sessionId: "add-initiate-1",
            draftId: 9,
            intakeItemId: 1,
            deadline: "2026-08-01",
            deadlineType: "hard",
            capacityMinutes: 45,
            targetOutput: "working notes",
            targetDepth: "apply",
            assumptions: ["deadline": AnyCodable(["accepted": true])],
            restWeekdays: [6],
            unavailableDates: ["2026-07-04"],
            bufferPolicy: "standard",
            loadShape: "steady"
        )
        let option = AddInitiateOptionEffectRequest(
            sessionId: "add-initiate-1",
            draftId: 9,
            draftVersion: 2,
            optionId: "increase_capacity",
            parameters: ["new_daily_capacity_min": AnyCodable(60)]
        )
        let activation = AddInitiateActivationRequest(
            sessionId: "add-initiate-1",
            draftId: 9,
            draftVersion: 2
        )

        let startPayload = try jsonDictionary(from: start)
        XCTAssertEqual(startPayload["clientRequestId"] as? String, "req-start")
        XCTAssertEqual(startPayload["rawInput"] as? String, "Learn FastAPI by August")
        XCTAssertEqual(startPayload["sourceType"] as? String, "text_goal")
        XCTAssertNil(startPayload["client_request_id"])

        let rolePayload = try jsonDictionary(from: role)
        XCTAssertEqual(rolePayload["sessionId"] as? String, "add-initiate-1")
        XCTAssertEqual(rolePayload["intakeItemId"] as? Int, 1)
        XCTAssertEqual(rolePayload["confirmedRole"] as? String, "attach_to_existing_plan")
        XCTAssertEqual(rolePayload["existingPlanId"] as? Int, 7)
        XCTAssertEqual(rolePayload["attachmentMode"] as? String, "material_only")

        let anchorPayload = try jsonDictionary(from: anchors)
        XCTAssertEqual(anchorPayload["deadlineType"] as? String, "hard")
        XCTAssertEqual(anchorPayload["capacityMinutes"] as? Int, 45)
        XCTAssertEqual(anchorPayload["targetOutput"] as? String, "working notes")
        XCTAssertEqual(anchorPayload["targetDepth"] as? String, "apply")

        let optionPayload = try jsonDictionary(from: option)
        XCTAssertEqual(optionPayload["draftVersion"] as? Int, 2)
        XCTAssertEqual(optionPayload["optionId"] as? String, "increase_capacity")

        let activationPayload = try jsonDictionary(from: activation)
        XCTAssertEqual(activationPayload["draftId"] as? Int, 9)
        XCTAssertEqual(activationPayload["draftVersion"] as? Int, 2)
    }

    func testAddInitiateAPIClientUsesAdapterEndpointsAndNotLegacyURLIngest() async throws {
        let client = makeRecordingClient(responseBody: """
        {
            "sessionId": "add-initiate-1",
            "clientRequestId": "req-start",
            "intakeItemId": 1,
            "stage": "role_review",
            "reviewState": "role_review",
            "recommendedRole": "new_plan",
            "confidence": "high",
            "reasonCodes": ["planning_language"],
            "nextAction": "role_review",
            "createsActiveTasks": false
        }
        """)
        _ = try await client.startAddInitiateSession(
            AddInitiateStartSessionRequest(
                clientRequestId: "req-start",
                rawInput: "Learn FastAPI",
                sourceType: "text_goal"
            )
        )

        var request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/study-intake/add-initiate/sessions")
        XCTAssertNotEqual(request.url?.path, "/api/ingest/start")

        let roleClient = makeRecordingClient(responseBody: """
        {"sessionId":"add-initiate-1","clientRequestId":"req-start","intakeItemId":1,"draftId":8,"draftVersion":1,"stage":"anchor_review","reviewState":"anchor_review","confirmedRole":"new_plan","createsActiveTasks":false}
        """)
        _ = try await roleClient.confirmAddInitiateRole(
            AddInitiateRoleConfirmationRequest(
                sessionId: "add-initiate-1",
                intakeItemId: 1,
                confirmedRole: "new_plan",
                title: "Learn FastAPI"
            )
        )
        request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/study-intake/add-initiate/role")

        let anchorsClient = makeRecordingClient(responseBody: """
        {"sessionId":"add-initiate-1","clientRequestId":"req-start","intakeItemId":1,"draftId":8,"draftVersion":1,"stage":"draft_review","reviewState":"draft_review","createsActiveTasks":false}
        """)
        _ = try await anchorsClient.confirmAddInitiateAnchors(
            AddInitiateAnchorConfirmationRequest(
                sessionId: "add-initiate-1",
                draftId: 8,
                intakeItemId: 1,
                deadline: "2026-08-01",
                deadlineType: "hard",
                capacityMinutes: 45,
                targetOutput: "notes",
                targetDepth: "apply"
            )
        )
        request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/study-intake/add-initiate/anchors")

        let optionClient = makeRecordingClient(responseBody: """
        {"sessionId":"add-initiate-1","draftId":8,"draftVersion":2,"stage":"draft_review","reviewState":"draft_review","createsActiveTasks":false}
        """)
        _ = try await optionClient.applyAddInitiateOptionEffect(
            AddInitiateOptionEffectRequest(
                sessionId: "add-initiate-1",
                draftId: 8,
                draftVersion: 1,
                optionId: "reduce_scope"
            )
        )
        request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/study-intake/add-initiate/options")

        let activationClient = makeRecordingClient(responseBody: """
        {"sessionId":"add-initiate-1","draftId":8,"draftVersion":2,"stage":"activated","reviewState":"activated","createsActiveTasks":true,"resourceId":10}
        """)
        _ = try await activationClient.activateAddInitiateDraft(
            AddInitiateActivationRequest(
                sessionId: "add-initiate-1",
                draftId: 8,
                draftVersion: 2
            )
        )
        request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/study-intake/add-initiate/activate")
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

    func testSmartModeSettingDecodesAndUpdateEncodesEnabledFlag() throws {
        let setting = try decode(StudySmartModeSettings.self, from: """
        {"enabled": false}
        """)
        let update = StudySmartModeSettings(enabled: true)

        let payload = try jsonDictionary(from: update)

        XCTAssertEqual(setting.enabled, false)
        XCTAssertEqual(payload["enabled"] as? Bool, true)
        XCTAssertNil(payload["is_enabled"])
    }

    func testSmartMorningBriefingDecodesSnakeCaseFactsAndOptions() throws {
        let briefing = try decode(StudySmartMorningBriefing.self, from: """
        {
            "enabled": true,
            "date": "2026-06-01",
            "summary": "Two study-plan issues need attention.",
            "snapshot": {
                "today": {"tasks": []},
                "projects": {"active_projects": [], "completed_projects": []},
                "calendar": {"days": []},
                "rollover": {"date": "2026-06-01", "rolled_count": 0, "rolled_tasks": []}
            },
            "issues": [
                {
                    "type": "rolled_task_lag",
                    "task_id": 42,
                    "project_id": 7,
                    "rolled_day_count": 3
                }
            ],
            "options": [
                {
                    "id": "smart-morning-expected-late-project-7",
                    "trigger": "morning",
                    "reason": {
                        "type": "expected_late_project",
                        "project_id": 7,
                        "deadline": "2026-06-10",
                        "latest_task_date": "2026-06-14",
                        "summary": "Project 7 has unfinished work after its deadline."
                    },
                    "affected_project_ids": [7],
                    "affected_task_ids": [42, 43],
                    "preview": {
                        "status": "preview",
                        "source": "smart_mode_preview",
                        "command": "extend_project_deadline",
                        "trigger": "morning",
                        "project_id": 7,
                        "old_deadline": "2026-06-10",
                        "new_deadline": "2026-06-14",
                        "changes": [{"project_id": 7, "field": "deadline", "old_deadline": "2026-06-10", "new_deadline": "2026-06-14"}],
                        "mutates": false
                    },
                    "previewed_changes": [
                        {"project_id": 7, "field": "deadline", "old_deadline": "2026-06-10", "new_deadline": "2026-06-14"}
                    ],
                    "red_state_impact": {
                        "expected_late": {"before": true, "after": false},
                        "over_capacity": {
                            "before_dates": ["2026-06-11"],
                            "after_dates": [],
                            "new_over_capacity_dates": [],
                            "resolved_over_capacity_dates": ["2026-06-11"]
                        }
                    },
                    "summary": "Extend project 7's deadline to 2026-06-14.",
                    "tradeoff": "Keeps task dates unchanged but moves the project commitment later.",
                    "signature_version": 1,
                    "signature": "abc123",
                    "signature_payload": {
                        "id": "smart-morning-expected-late-project-7",
                        "trigger": "morning",
                        "reason": {"type": "expected_late_project", "project_id": 7, "deadline": "2026-06-10", "latest_task_date": "2026-06-14"},
                        "affected_project_ids": [7],
                        "affected_task_ids": [42, 43],
                        "preview": {"status": "preview", "source": "smart_mode_preview", "command": "extend_project_deadline", "trigger": "morning", "project_id": 7, "old_deadline": "2026-06-10", "new_deadline": "2026-06-14", "changes": [{"project_id": 7, "field": "deadline", "old_deadline": "2026-06-10", "new_deadline": "2026-06-14"}], "mutates": false},
                        "previewed_changes": [{"project_id": 7, "field": "deadline", "old_deadline": "2026-06-10", "new_deadline": "2026-06-14"}],
                        "red_state_impact": {"expected_late": {"before": true, "after": false}, "over_capacity": {"before_dates": ["2026-06-11"], "after_dates": [], "new_over_capacity_dates": [], "resolved_over_capacity_dates": ["2026-06-11"]}}
                    }
                }
            ],
            "trigger_eligible": true
        }
        """)

        XCTAssertTrue(briefing.enabled)
        XCTAssertEqual(briefing.date, "2026-06-01")
        XCTAssertEqual(briefing.summary, "Two study-plan issues need attention.")
        XCTAssertEqual(briefing.issues.first?.type, "rolled_task_lag")
        XCTAssertEqual(briefing.issues.first?.projectId, 7)
        XCTAssertEqual(briefing.issues.first?.rolledDayCount, 3)
        XCTAssertEqual(briefing.options.first?.trigger, .morning)
        XCTAssertEqual(briefing.options.first?.affectedProjectIds, [7])
        XCTAssertEqual(briefing.options.first?.reason["type"]?.value as? String, "expected_late_project")
        XCTAssertEqual(briefing.options.first?.preview["command"]?.value as? String, "extend_project_deadline")
        XCTAssertEqual(briefing.options.first?.preview["mutates"]?.value as? Bool, false)
        XCTAssertEqual(briefing.options.first?.redStateImpact?.expectedLate?.after, false)
        XCTAssertEqual(briefing.options.first?.signatureVersion, 1)
        XCTAssertEqual(briefing.options.first?.mutates, false)
        XCTAssertTrue(briefing.triggerEligible)
    }

    func testSmartProposalOptionDecodesStructuredPreviewAndSignaturePayload() throws {
        let option = try decode(StudySmartProposalOption.self, from: """
        {
            "id": "after-adjustment-spread-42",
            "trigger": "after_adjustment",
            "reason": {
                "type": "over_capacity_day",
                "date": "2026-06-10",
                "summary": "2026-06-10 is over capacity."
            },
            "affected_project_ids": [7],
            "affected_task_ids": [42],
            "preview": {
                "status": "preview",
                "source": "smart_mode_preview",
                "command": "move_task_from_over_capacity_day",
                "trigger": "after_adjustment",
                "date": "2026-06-10",
                "task_id": 42,
                "new_date": "2026-06-12",
                "selection_policy": {"selected_task_id": 42},
                "changes": [{"task_id": 42, "project_id": 7, "old_date": "2026-06-10", "new_date": "2026-06-12"}],
                "mutates": false
            },
            "previewed_changes": [
                {"task_id": 42, "project_id": 7, "old_date": "2026-06-10", "new_date": "2026-06-12"}
            ],
            "red_state_impact": {
                "expected_late": {"before": false, "after": false},
                "over_capacity": {
                    "before_dates": ["2026-06-10"],
                    "after_dates": [],
                    "new_over_capacity_dates": [],
                    "resolved_over_capacity_dates": ["2026-06-10"]
                }
            },
            "summary": "Move task 42 off 2026-06-10.",
            "tradeoff": "Reduces the overloaded day by pushing task 42 later.",
            "signature_version": 1,
            "signature": "sig-42",
            "signature_payload": {"current_facts": {"over_capacity_dates": ["2026-06-10"]}},
            "mutates": false
        }
        """)

        let selectionPolicy = try XCTUnwrap(option.preview["selection_policy"]?.value as? [String: AnyCodable])
        let signatureFacts = try XCTUnwrap(option.signaturePayload["current_facts"]?.value as? [String: AnyCodable])

        XCTAssertEqual(option.id, "after-adjustment-spread-42")
        XCTAssertEqual(option.trigger, .afterAdjustment)
        XCTAssertEqual(option.reason["type"]?.value as? String, "over_capacity_day")
        XCTAssertEqual(option.reason["date"]?.value as? String, "2026-06-10")
        XCTAssertEqual(option.affectedTaskIds, [42])
        XCTAssertEqual(option.preview["command"]?.value as? String, "move_task_from_over_capacity_day")
        XCTAssertEqual(selectionPolicy["selected_task_id"]?.value as? Int, 42)
        XCTAssertEqual(option.previewedChanges.first?.taskId, 42)
        XCTAssertEqual(signatureFacts["over_capacity_dates"]?.value as? [String], ["2026-06-10"])
        XCTAssertEqual(option.signatureVersion, 1)
        XCTAssertEqual(option.signature, "sig-42")
        XCTAssertFalse(option.mutates)
    }

    func testSmartProposalGenerationRequestEncodesBackendPreviousRedStateFields() throws {
        let request = StudySmartProposalGenerationRequest(
            trigger: .afterAdjustment,
            previousExpectedLateProjectIds: [8702],
            previousOverCapacityDates: ["2026-06-12"]
        )

        let payload = try jsonDictionary(from: request)

        XCTAssertEqual(payload["trigger"] as? String, "after_adjustment")
        XCTAssertEqual(payload["previous_expected_late_project_ids"] as? [Int], [8702])
        XCTAssertEqual(payload["previous_over_capacity_dates"] as? [String], ["2026-06-12"])
        XCTAssertNil(payload["previous_facts"])
        XCTAssertNil(payload["current_facts"])
        XCTAssertNil(payload["context"])
    }

    func testSmartProposalApplyRequestAndResultsUseSelectedProposalPreview() throws {
        let proposal = sampleStudySmartProposalOption()
        let request = StudySmartProposalApplyRequest(proposal: proposal)

        let payload = try jsonDictionary(from: request)
        let encodedProposal = try XCTUnwrap(payload["proposal"] as? [String: Any])
        XCTAssertEqual(encodedProposal["id"] as? String, "morning-extend-deadline-7")
        XCTAssertNil(encodedProposal["mutates"])
        let encodedPreview = try XCTUnwrap(encodedProposal["preview"] as? [String: Any])
        XCTAssertEqual(encodedPreview["mutates"] as? Bool, false)

        let afterAdjustmentRequest = StudySmartProposalApplyRequest(
            proposal: sampleStudySmartProposalOption(),
            previousExpectedLateProjectIds: [8702],
            previousOverCapacityDates: ["2026-06-12"]
        )
        let afterAdjustmentPayload = try jsonDictionary(from: afterAdjustmentRequest)
        XCTAssertNotNil(afterAdjustmentPayload["proposal"] as? [String: Any])
        XCTAssertEqual(afterAdjustmentPayload["previous_expected_late_project_ids"] as? [Int], [8702])
        XCTAssertEqual(afterAdjustmentPayload["previous_over_capacity_dates"] as? [String], ["2026-06-12"])
        XCTAssertNil(afterAdjustmentPayload["previous_facts"])
        XCTAssertNil(afterAdjustmentPayload["current_facts"])
        XCTAssertNil(afterAdjustmentPayload["context"])

        let applied = try decode(StudySmartProposalApplyResult.self, from: """
        {
            "status": "applied",
            "source": "smart_mode_apply",
            "proposal_id": "morning-extend-deadline-7",
            "signature": "abc123",
            "trigger": "morning",
            "command": "extend_project_deadline",
            "affected_project_ids": [7],
            "affected_task_ids": [42],
            "applied_changes": [{"project_id": 7, "field": "deadline", "old_deadline": "2026-06-10", "new_deadline": "2026-06-14"}],
            "mutates": true,
            "refresh": {"today": true, "project_overview": true, "calendar": true}
        }
        """)
        let stale = try decode(StudySmartProposalApplyResult.self, from: """
        {"status": "stale_proposal", "mutates": false, "message": "submitted proposal does not match the current active plan"}
        """)
        let disabled = try decode(StudySmartProposalApplyResult.self, from: """
        {"status": "disabled", "mutates": false, "message": "smart mode is disabled"}
        """)
        let unsupported = try decode(StudySmartProposalApplyResult.self, from: """
        {"status": "unsupported", "mutates": false, "message": "submitted proposal is unsupported"}
        """)

        XCTAssertEqual(applied.status, "applied")
        XCTAssertEqual(applied.source, "smart_mode_apply")
        XCTAssertEqual(applied.proposalId, "morning-extend-deadline-7")
        XCTAssertEqual(applied.appliedChanges?.first?.field, "deadline")
        XCTAssertEqual(applied.refresh?.calendar, true)
        XCTAssertEqual(stale.status, "stale_proposal")
        XCTAssertEqual(disabled.message, "smart mode is disabled")
        XCTAssertEqual(unsupported.mutates, false)
        XCTAssertNil(stale.refresh)
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

    func testStudySmartModeClientRequestsUseNewEndpointsAndNeverLegacyRoutes() async throws {
        let settingsFetchClient = makeRecordingClient(responseBody: """
        {"enabled": false}
        """)
        _ = try await settingsFetchClient.fetchStudySmartModeSettings()
        var request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/study-smart-mode/settings")

        let settingsUpdateClient = makeRecordingClient(responseBody: """
        {"enabled": true}
        """)
        _ = try await settingsUpdateClient.updateStudySmartModeSettings(StudySmartModeSettings(enabled: true))
        request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        var body = try XCTUnwrap(request.httpBodyStreamData)
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.url?.path, "/api/study-smart-mode/settings")
        XCTAssertEqual(payload["enabled"] as? Bool, true)

        let briefingClient = makeRecordingClient(responseBody: """
        {
            "enabled": true,
            "date": "2026-06-01",
            "summary": "Quiet day.",
            "snapshot": {
                "today": {"tasks": []},
                "projects": {"active_projects": [], "completed_projects": []},
                "calendar": {"days": []},
                "rollover": {"date": "2026-06-01", "rolled_count": 0, "rolled_tasks": []}
            },
            "issues": [],
            "options": [],
            "trigger_eligible": false
        }
        """)
        _ = try await briefingClient.fetchStudySmartMorningBriefing()
        request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/study-smart-mode/morning-briefing")

        let proposalsClient = makeRecordingClient(responseBody: """
        {"enabled": true, "trigger": "after_adjustment", "options": []}
        """)
        _ = try await proposalsClient.generateStudySmartProposals(
            StudySmartProposalGenerationRequest(
                trigger: .afterAdjustment,
                previousExpectedLateProjectIds: [8702],
                previousOverCapacityDates: ["2026-06-12"]
            )
        )
        request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        body = try XCTUnwrap(request.httpBodyStreamData)
        payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/study-smart-mode/proposals")
        XCTAssertEqual(payload["trigger"] as? String, "after_adjustment")
        XCTAssertEqual(payload["previous_expected_late_project_ids"] as? [Int], [8702])
        XCTAssertEqual(payload["previous_over_capacity_dates"] as? [String], ["2026-06-12"])
        XCTAssertNil(payload["previous_facts"])

        let applyClient = makeRecordingClient(responseBody: """
        {"status": "applied", "mutates": true, "refresh": {"today": true, "project_overview": true, "calendar": true}}
        """)
        _ = try await applyClient.applyStudySmartProposal(
            StudySmartProposalApplyRequest(
                proposal: sampleStudySmartProposalOption(),
                previousExpectedLateProjectIds: [8702],
                previousOverCapacityDates: ["2026-06-12"]
            )
        )
        request = try XCTUnwrap(URLProtocolBackedAPIClientTests.lastRequest)
        body = try XCTUnwrap(request.httpBodyStreamData)
        payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/study-smart-mode/proposals/apply")
        XCTAssertNotNil(payload["proposal"] as? [String: Any])
        XCTAssertEqual(payload["previous_expected_late_project_ids"] as? [Int], [8702])
        XCTAssertEqual(payload["previous_over_capacity_dates"] as? [String], ["2026-06-12"])
        XCTAssertNil(payload["previous_facts"])

        let clientSource = try sourceFile("MalDaze/LearningAssistant/AssistantAPIClient.swift")
        for methodName in [
            "fetchStudySmartModeSettings",
            "updateStudySmartModeSettings",
            "fetchStudySmartMorningBriefing",
            "generateStudySmartProposals",
            "applyStudySmartProposal"
        ] {
            let source = try methodSource(named: methodName, in: clientSource)
            XCTAssertFalse(source.contains("/api/today-briefing"))
            XCTAssertFalse(source.contains("/api/chat"))
            XCTAssertFalse(source.contains("/api/chat/confirm"))
        }
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

    private func methodSource(named name: String, in source: String) throws -> String {
        let start = try XCTUnwrap(source.range(of: "func \(name)"))
        let remaining = source[start.lowerBound...]
        let end = remaining.range(of: "\n    func ", options: [], range: remaining.index(after: remaining.startIndex)..<remaining.endIndex)?.lowerBound ?? remaining.endIndex
        return String(remaining[..<end])
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

final class LearningAssistantTests: XCTestCase {

    func testAssistantBottomNavigationUsesFullRectangularHitTargetsAndImmediateSelection() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        let buttonSource = try bottomNavigationButtonSource(in: source)

        XCTAssertTrue(
            buttonSource.contains("vm.selectedPanelTab = tab"),
            "Bottom navigation should update selectedPanelTab directly in the button action before destination refresh work can run."
        )
        XCTAssertTrue(
            buttonSource.contains(".contentShape(Rectangle())"),
            "Bottom navigation labels should expose the full visible rectangle as the hit target, not just glyph bounds."
        )
        XCTAssertTrue(
            buttonSource.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"),
            "Bottom navigation items should keep a stable equal-width layout across the bar."
        )
        XCTAssertTrue(
            buttonSource.contains("vm.selectedPanelTab == tab ? Color.accentColor : Color.secondary"),
            "Bottom navigation selected styling should be derived from selectedPanelTab immediately after the click."
        )
    }

    private func sourceFile(_ relativePath: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let url = projectRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func bottomNavigationButtonSource(in source: String) throws -> String {
        let signature = "private func bottomNavigationButton(_ tab: AssistantPanelTab) -> some View"
        let start = try XCTUnwrap(source.range(of: signature), "bottomNavigationButton source section not found")
        let remaining = source[start.lowerBound...]
        let end = try XCTUnwrap(
            remaining.range(of: "\n    }\n}\n\n@ViewBuilder"),
            "bottomNavigationButton source section end not found"
        )
        return String(remaining[..<end.lowerBound])
    }
}

final class LearningAssistantUISourceTests: XCTestCase {

    func testAssistantPanelUsesDashboardHomeAndBottomNavigationInsteadOfSegmentedTabs() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("selectedPanelTab"))
        XCTAssertTrue(source.contains("bottomNavigationBar"))
        XCTAssertTrue(source.contains("首页"))
        XCTAssertTrue(source.contains("立项"))
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

    func testAssistantPanelAddResourceUsesAddInitiateView() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("case .addResource:"))
        XCTAssertTrue(source.contains("AddInitiateView(vm: vm)"))
        XCTAssertFalse(source.contains("case .addResource:\n            IngestionView(vm: vm)"))
        XCTAssertFalse(source.contains("case .addResource:\n            StudyPlanIntakeView(vm: vm)"))
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

    func testAssistantPanelTodayShowsRolledBadgeAndMoveTaskWiring() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("showRolledBadge"))
        XCTAssertTrue(source.contains("rolledDayCount"))
        XCTAssertTrue(source.contains("已滚动"))
        XCTAssertTrue(source.contains("滚动"))
        XCTAssertTrue(source.contains("vm.moveStudyTask(id: task.id, scheduledDate:"))
        XCTAssertTrue(source.contains("todayStudyTask(for: task.id)"))
    }

    func testAssistantPanelTodayMoveRequiresUserChangedDateBeforeEnabling() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("todayMoveDateChanged(for: task)"))
        XCTAssertTrue(source.contains(".disabled(!todayMoveDateChanged(for: task) || todayMoveDate(for: task).isEmpty || vm.isAdjustingStudyPlan)"))
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

    func testAssistantPanelProjectOverviewShowsExpectedLateAndDeadlineEditWiring() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private struct ProjectOverviewView"),
              let end = source[start.upperBound...].range(of: "private struct StudyPlanIntakeView") else {
            XCTFail("ProjectOverviewView source section not found")
            return
        }
        let projectSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(projectSource.contains("expectedLate"))
        XCTAssertTrue(projectSource.contains("预计晚于截止日期"))
        XCTAssertTrue(projectSource.contains(".foregroundStyle(.red)"))
        XCTAssertTrue(projectSource.contains("vm.updateStudyProjectDeadline(projectId: project.id, deadline:"))
        XCTAssertTrue(projectSource.contains("isCompletedHistory"))
        XCTAssertTrue(projectSource.contains("if !isCompletedHistory"))
    }

    func testAssistantPanelCalendarDisplaysDailyLoadAndFetchesDefaultWindow() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("private struct StudyCalendarLoadView"))
        XCTAssertTrue(source.contains("vm.studyCalendarLoad"))
        XCTAssertTrue(source.contains("fetchDefaultWindowIfNeeded"))
        XCTAssertTrue(source.contains("vm.fetchStudyCalendarLoad(start: start, end: end)"))
        XCTAssertTrue(source.contains("scheduledTaskCount"))
        XCTAssertTrue(source.contains("totalTargetMinutes"))
        XCTAssertTrue(source.contains("completedTaskCount"))
        XCTAssertTrue(source.contains("overCapacity"))
        XCTAssertTrue(source.contains("restDay"))
        XCTAssertTrue(source.contains("availableCapacityMinutes"))
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

    func testAssistantPanelCalendarSourceHasAdjustmentMutationWiring() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private struct StudyCalendarLoadView"),
              let end = source[start.upperBound...].range(of: "private struct ProjectOverviewView") else {
            XCTFail("StudyCalendarLoadView source section not found")
            return
        }
        let calendarSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(calendarSource.contains("vm.insertStudyProjectTask("))
        XCTAssertTrue(calendarSource.contains("vm.deleteStudyTask(id:"))
        XCTAssertTrue(calendarSource.contains("vm.moveStudyTask(id:"))
        XCTAssertTrue(calendarSource.contains("restDay"))
        XCTAssertTrue(calendarSource.contains("availableCapacityMinutes"))
        XCTAssertTrue(calendarSource.contains("overCapacity"))
        XCTAssertTrue(calendarSource.contains("添加任务"))
        XCTAssertTrue(calendarSource.contains("删除任务"))
        XCTAssertTrue(calendarSource.contains("移动任务"))
        XCTAssertFalse(calendarSource.contains("moveVisibleTasks"))
    }

    func testAssistantPanelCalendarAdjustmentControlsAreSplitForNarrowColumn() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private struct StudyCalendarLoadView"),
              let end = source[start.upperBound...].range(of: "private struct ProjectOverviewView") else {
            XCTFail("StudyCalendarLoadView source section not found")
            return
        }
        let calendarSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(calendarSource.contains("private var calendarAddTaskControls"))
        XCTAssertTrue(calendarSource.contains("private var calendarDeleteTaskControls"))
        XCTAssertTrue(calendarSource.contains("private var calendarMoveTaskControls"))
        XCTAssertTrue(calendarSource.contains("calendarAddTaskControls"))
        XCTAssertTrue(calendarSource.contains("calendarDeleteTaskControls"))
        XCTAssertTrue(calendarSource.contains("calendarMoveTaskControls"))
        XCTAssertTrue(calendarSource.contains("VStack(alignment: .leading, spacing: 8)"))
        XCTAssertFalse(calendarSource.contains("Divider()\n\n                    Text(\"移动任务\")"))
    }

    func testAssistantPanelSettingsWiresRestDayFetchAndUpdate() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")

        XCTAssertTrue(source.contains("case .settings:"))
        XCTAssertTrue(source.contains("StudySettingsView(vm: vm)"))
        XCTAssertTrue(source.contains("private struct StudySettingsView"))
        XCTAssertTrue(source.contains("vm.fetchStudyRestDaySettings()"))
        XCTAssertTrue(source.contains("vm.updateStudyRestDaySettings("))
        XCTAssertTrue(source.contains("studyRestDaySettings"))
        XCTAssertTrue(source.contains("休息日"))
    }

    func testAssistantPanelSettingsShowsContextualRestDayErrorOnlyAfterRestDayOperation() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private struct StudySettingsView"),
              let end = source[start.upperBound...].range(of: "private struct StudyPlanAdjustmentView") else {
            XCTFail("StudySettingsView source section not found")
            return
        }
        let settingsSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(settingsSource.contains("hasTouchedRestDaySettings"))
        XCTAssertTrue(settingsSource.contains("restDayErrorMessage"))
        XCTAssertTrue(settingsSource.contains("休息日设置失败"))
        XCTAssertFalse(settingsSource.contains("Label(error, systemImage: \"exclamationmark.triangle\")"))
    }

    func testAssistantPanelSettingsWiresStudySmartModeToggleToViewModelSettingUpdate() throws {
        let panelSource = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        let viewModelSource = try sourceFile("MalDaze/LearningAssistant/LearningAssistantViewModel.swift")
        guard let start = panelSource.range(of: "private struct StudySettingsView"),
              let end = panelSource[start.upperBound...].range(of: "private struct StudyPlanAdjustmentView") else {
            XCTFail("StudySettingsView source section not found")
            return
        }
        let settingsSource = String(panelSource[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(settingsSource.contains("Toggle(\"智能学习模式\""))
        XCTAssertTrue(settingsSource.contains("默认关闭"))
        XCTAssertTrue(settingsSource.contains("vm.isStudySmartModeEnabled"))
        XCTAssertTrue(settingsSource.contains("Task { await vm.updateStudySmartModeSetting(isOn) }"))
        XCTAssertTrue(settingsSource.contains("vm.studySmartSettingsMessage"))
        XCTAssertTrue(viewModelSource.contains("func updateStudySmartModeSetting(_ enabled: Bool) async"))
        XCTAssertTrue(viewModelSource.contains("api.updateStudySmartModeSettings(StudySmartModeSettings(enabled: enabled))"))
        XCTAssertFalse(settingsSource.contains("fetchTodayBriefing()"))
        XCTAssertFalse(settingsSource.contains("sendMessage"))
        XCTAssertFalse(settingsSource.contains("confirmProposal"))
        XCTAssertFalse(settingsSource.contains("chatMessages"))
        XCTAssertFalse(settingsSource.contains("currentProposal"))
    }

    func testLearningAssistantAPIInjectionUsesSendableProtocolWithoutUnsafeBypass() throws {
        let viewModelSource = try sourceFile("MalDaze/LearningAssistant/LearningAssistantViewModel.swift")
        let protocolSource = try sourceFile("MalDaze/LearningAssistant/AssistantAPIClientProtocol.swift")
        let clientSource = try sourceFile("MalDaze/LearningAssistant/AssistantAPIClient.swift")

        XCTAssertFalse(viewModelSource.contains("nonisolated(unsafe) let api"))
        XCTAssertTrue(viewModelSource.contains("let api: any AssistantAPIClientProtocol"))
        XCTAssertTrue(protocolSource.contains("protocol AssistantAPIClientProtocol: Sendable"))
        XCTAssertTrue(clientSource.contains("final class AssistantAPIClient: @unchecked Sendable"))
    }

    func testAssistantPanelDashboardDisplaysStudySmartMorningBriefingAndProposalSurface() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private var homeDashboard"),
              let end = source[start.upperBound...].range(of: "private var dashboardSummarySection") else {
            XCTFail("homeDashboard source section not found")
            return
        }
        let dashboardSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(dashboardSource.contains("studySmartDashboardSection"))
        XCTAssertTrue(source.contains("private var studySmartDashboardSection"))
        XCTAssertTrue(source.contains("vm.studySmartMorningBriefing"))
        XCTAssertTrue(source.contains("vm.studySmartProposalOptions"))
        XCTAssertTrue(source.contains("vm.studySmartProposalMessage"))
        XCTAssertTrue(source.contains("智能晨间简报"))
        XCTAssertTrue(source.contains("StudySmartOptionsStrip(vm: vm, placement: .dashboard)"))
    }

    func testAssistantPanelDashboardSmartSectionVisibilityUsesMorningScopedStateOnly() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private var studySmartDashboardSection"),
              let end = source[start.upperBound...].range(of: "private var dashboardSummarySection") else {
            XCTFail("studySmartDashboardSection source section not found")
            return
        }
        let dashboardSmartSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(dashboardSmartSource.contains("dashboardVisibleStudySmartOptions"))
        XCTAssertTrue(dashboardSmartSource.contains("dashboardVisibleStudySmartMessage != nil"))
        XCTAssertFalse(dashboardSmartSource.contains("!vm.studySmartProposalOptions.isEmpty"))
        XCTAssertFalse(dashboardSmartSource.contains("|| vm.studySmartProposalMessage != nil"))
        XCTAssertTrue(source.contains("private var dashboardVisibleStudySmartMessage: String?"))
        guard let messageStart = source.range(of: "private var dashboardVisibleStudySmartMessage: String?"),
              let messageEnd = source[messageStart.upperBound...].range(of: "private var dashboardSummarySection") else {
            XCTFail("dashboardVisibleStudySmartMessage source section not found")
            return
        }
        let messageSource = String(source[messageStart.lowerBound..<messageEnd.lowerBound])
        XCTAssertTrue(messageSource.contains("StudySmartOptionsFilter.visibleMessage"))
        XCTAssertTrue(messageSource.contains("messageTrigger: vm.studySmartProposalMessageTrigger"))
        XCTAssertTrue(messageSource.contains("placement: .dashboard"))
    }

    func testAssistantPanelSmartProposalCardsAreParallelPreviewOnlyWithPerOptionApplyAndIgnore() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private struct StudySmartOptionsStrip"),
              let end = source[start.upperBound...].range(of: "private struct StudySettingsView") else {
            XCTFail("StudySmartOptionsStrip source section not found")
            return
        }
        let smartSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(smartSource.contains("ScrollView(.horizontal"))
        XCTAssertTrue(smartSource.contains("LazyHStack"))
        XCTAssertTrue(smartSource.contains("ForEach(visibleOptions, id: \\.id)"))
        XCTAssertFalse(smartSource.contains("ForEach(vm.studySmartProposalOptions"))
        XCTAssertTrue(smartSource.contains("Task { await vm.applyStudySmartProposal(option) }"))
        XCTAssertTrue(smartSource.contains("vm.ignoreStudySmartProposals()"))
        XCTAssertTrue(smartSource.contains("previewedChanges"))
        XCTAssertTrue(smartSource.contains("redStateImpact"))
        XCTAssertTrue(smartSource.contains("studySmartProposalMessage"))
        XCTAssertFalse(smartSource.contains("ChatView"))
        XCTAssertFalse(smartSource.contains("sendMessage"))
        XCTAssertFalse(smartSource.contains("confirmProposal"))
        XCTAssertFalse(smartSource.contains("chatMessages"))
        XCTAssertFalse(smartSource.contains("currentProposal"))
    }

    func testAssistantPanelSmartProposalStripUsesVisibleOptionsAndAvoidsLegacyChatState() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private struct StudySmartOptionsStrip"),
              let end = source[start.upperBound...].range(of: "private struct StudySettingsView") else {
            XCTFail("StudySmartOptionsStrip source section not found")
            return
        }
        let smartSource = String(source[start.lowerBound..<end.lowerBound])
        let forbiddenTokens = [
            "ForEach(vm.studySmartProposalOptions",
            "ChatView",
            "chatMessages",
            "currentProposal",
            "sendMessage",
            "confirmProposal",
            "fetchTodayBriefing"
        ]

        XCTAssertTrue(smartSource.contains("ForEach(visibleOptions, id: \\.id)"))
        XCTAssertTrue(smartSource.contains("vm.isStudySmartModeEnabled"))
        XCTAssertTrue(smartSource.contains("StudySmartOptionsFilter.visibleOptions"))
        XCTAssertTrue(smartSource.contains("messageTrigger: vm.studySmartProposalMessageTrigger"))
        for token in forbiddenTokens {
            XCTAssertFalse(smartSource.contains(token), "StudySmartOptionsStrip must not reference \(token)")
        }
    }

    func testAssistantPanelSmartProposalPlacementsFilterTriggers() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "enum StudySmartOptionsFilter"),
              let end = source[start.upperBound...].range(of: "private struct StudySmartOptionsStrip") else {
            XCTFail("StudySmartOptionsFilter source section not found")
            return
        }
        let smartSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(smartSource.contains("case .dashboard:\n            return trigger == .morning"))
        XCTAssertTrue(smartSource.contains("case .adjustment:\n            return trigger == .afterAdjustment"))
    }

    func testStudySmartOptionsPlacementHelperFiltersByTrigger() {
        let morning = sampleStudySmartProposalOption(trigger: .morning)
        let afterAdjustment = sampleStudySmartProposalOption(trigger: .afterAdjustment)
        let options = [morning, afterAdjustment]

        XCTAssertEqual(
            StudySmartOptionsFilter.visibleOptions(options, placement: .dashboard).map(\.trigger),
            [.morning]
        )
        XCTAssertEqual(
            StudySmartOptionsFilter.visibleOptions(options, placement: .adjustment).map(\.trigger),
            [.afterAdjustment]
        )
    }

    func testStudySmartOptionsDashboardMessageRequiresDashboardVisibleOption() {
        let morning = sampleStudySmartProposalOption(trigger: .morning)
        let afterAdjustment = sampleStudySmartProposalOption(trigger: .afterAdjustment)

        XCTAssertNil(
            StudySmartOptionsFilter.visibleMessage(
                "after-adjustment message",
                options: [afterAdjustment],
                placement: .dashboard
            )
        )
        XCTAssertNil(
            StudySmartOptionsFilter.visibleMessage(
                "global message without dashboard option",
                options: [],
                placement: .dashboard
            )
        )
        XCTAssertEqual(
            StudySmartOptionsFilter.visibleMessage(
                "morning message",
                options: [morning],
                placement: .dashboard
            ),
            "morning message"
        )
        XCTAssertEqual(
            StudySmartOptionsFilter.visibleMessage(
                "after-adjustment message",
                options: [afterAdjustment],
                placement: .adjustment
            ),
            "after-adjustment message"
        )
    }

    func testStudySmartOptionsMessagesRequireMatchingPlacementContext() {
        let morning = sampleStudySmartProposalOption(trigger: .morning)
        let afterAdjustment = sampleStudySmartProposalOption(trigger: .afterAdjustment)

        XCTAssertEqual(
            StudySmartOptionsFilter.visibleMessage(
                "morning scoped empty message",
                messageTrigger: .morning,
                options: [],
                placement: .dashboard
            ),
            "morning scoped empty message"
        )
        XCTAssertNil(
            StudySmartOptionsFilter.visibleMessage(
                "morning scoped empty message",
                messageTrigger: .morning,
                options: [],
                placement: .adjustment
            )
        )
        XCTAssertEqual(
            StudySmartOptionsFilter.visibleMessage(
                "adjustment scoped empty message",
                messageTrigger: .afterAdjustment,
                options: [],
                placement: .adjustment
            ),
            "adjustment scoped empty message"
        )
        XCTAssertNil(
            StudySmartOptionsFilter.visibleMessage(
                "adjustment scoped empty message",
                messageTrigger: .afterAdjustment,
                options: [],
                placement: .dashboard
            )
        )
        XCTAssertEqual(
            StudySmartOptionsFilter.visibleMessage(
                "morning message",
                options: [morning],
                placement: .dashboard
            ),
            "morning message"
        )
        XCTAssertNil(
            StudySmartOptionsFilter.visibleMessage(
                "morning message",
                options: [morning],
                placement: .adjustment
            )
        )
        XCTAssertEqual(
            StudySmartOptionsFilter.visibleMessage(
                "after-adjustment message",
                options: [afterAdjustment],
                placement: .adjustment
            ),
            "after-adjustment message"
        )
        XCTAssertNil(
            StudySmartOptionsFilter.visibleMessage(
                "after-adjustment message",
                options: [afterAdjustment],
                placement: .dashboard
            )
        )
        XCTAssertNil(
            StudySmartOptionsFilter.visibleMessage(
                "智能建议已过期，请刷新后重试。",
                options: [],
                placement: .adjustment
            )
        )
        XCTAssertNil(
            StudySmartOptionsFilter.visibleMessage(
                "智能建议已应用。",
                options: [],
                placement: .adjustment
            )
        )
    }

    func testAssistantPanelAdjustmentContextDisplaysStudySmartOptionsWithoutLegacyChatState() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private struct StudyPlanAdjustmentView"),
              let end = source[start.upperBound...].range(of: "#if DEBUG") else {
            XCTFail("StudyPlanAdjustmentView source section not found")
            return
        }
        let adjustmentSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(adjustmentSource.contains("StudySmartOptionsStrip(vm: vm, placement: .adjustment)"))
        XCTAssertFalse(adjustmentSource.contains("ChatView"))
        XCTAssertFalse(adjustmentSource.contains("sendMessage"))
        XCTAssertFalse(adjustmentSource.contains("confirmProposal"))
        XCTAssertFalse(adjustmentSource.contains("chatMessages"))
        XCTAssertFalse(adjustmentSource.contains("currentProposal"))
    }

    func testAssistantPanelAdjustPlanUsesPreviewApplyFlowWithoutOldChatRoute() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private struct StudyPlanAdjustmentView"),
              let end = source[start.upperBound...].range(of: "#if DEBUG") else {
            XCTFail("StudyPlanAdjustmentView source section not found")
            return
        }
        let adjustmentSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(source.contains("case .adjustPlan:"))
        XCTAssertTrue(source.contains("StudyPlanAdjustmentView(vm: vm)"))
        XCTAssertTrue(adjustmentSource.contains("private struct StudyPlanAdjustmentView"))
        XCTAssertTrue(adjustmentSource.contains("vm.previewStudyDialogueAdjustment(instruction:"))
        XCTAssertTrue(adjustmentSource.contains("vm.applyStudyDialogueAdjustment(instruction:"))
        XCTAssertTrue(adjustmentSource.contains("studyDialogueAdjustmentPreview"))
        XCTAssertTrue(adjustmentSource.contains("studyDialogueAdjustmentResult"))
        XCTAssertTrue(adjustmentSource.contains("redStateImpact"))
        XCTAssertFalse(source.contains("case .adjustPlan:\n            ChatView(vm: vm)"))
        XCTAssertFalse(adjustmentSource.contains("sendMessage(message:"))
        XCTAssertFalse(adjustmentSource.contains("confirmProposal"))
    }

    func testAssistantPanelAdjustPlanApplyRequiresPreviewForCurrentInput() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private struct StudyPlanAdjustmentView"),
              let end = source[start.upperBound...].range(of: "#if DEBUG") else {
            XCTFail("StudyPlanAdjustmentView source section not found")
            return
        }
        let adjustmentSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(adjustmentSource.contains("@State private var previewedInstruction"))
        XCTAssertTrue(adjustmentSource.contains("@State private var previewedProjectId"))
        XCTAssertTrue(adjustmentSource.contains("private var hasCurrentPreview"))
        XCTAssertTrue(adjustmentSource.contains("previewedInstruction == trimmedInstruction"))
        XCTAssertTrue(adjustmentSource.contains("previewedProjectId == projectId"))
        XCTAssertTrue(adjustmentSource.contains(".disabled(!hasCurrentPreview || vm.isAdjustingStudyPlan)"))
        XCTAssertTrue(adjustmentSource.contains("previewedInstruction = nil"))
        XCTAssertTrue(adjustmentSource.contains("previewedProjectId = nil"))
        XCTAssertTrue(adjustmentSource.contains("vm.studyPlanAdjustmentError == nil"))
        XCTAssertTrue(adjustmentSource.contains("previewedInstruction = trimmedInstruction"))
        XCTAssertTrue(adjustmentSource.contains("previewedProjectId = projectId"))
    }

    func testAssistantPanelAdjustPlanShowsContextualDialogueErrorOnlyAfterDialogueOperation() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private struct StudyPlanAdjustmentView"),
              let end = source[start.upperBound...].range(of: "#if DEBUG") else {
            XCTFail("StudyPlanAdjustmentView source section not found")
            return
        }
        let adjustmentSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(adjustmentSource.contains("hasTouchedDialogueAdjustment"))
        XCTAssertTrue(adjustmentSource.contains("dialogueAdjustmentErrorMessage"))
        XCTAssertTrue(adjustmentSource.contains("计划调整失败"))
        XCTAssertFalse(adjustmentSource.contains("Label(error, systemImage: \"exclamationmark.triangle\")"))
    }

    func testDefaultModeRedStateSectionsStayFactOnlyWithoutSmartSuggestionsOrRepairWiring() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let calendarStart = source.range(of: "private struct StudyCalendarLoadView"),
              let projectStart = source.range(of: "private struct ProjectOverviewView"),
              let intakeStart = source.range(of: "private struct StudyPlanIntakeView"),
              let adjustmentStart = source.range(of: "private struct StudyPlanAdjustmentView"),
              let debugStart = source.range(of: "#if DEBUG") else {
            XCTFail("Expected study view source sections not found")
            return
        }

        let calendarSource = String(source[calendarStart.lowerBound..<projectStart.lowerBound])
        let projectSource = String(source[projectStart.lowerBound..<intakeStart.lowerBound])
        let adjustmentSource = String(source[adjustmentStart.lowerBound..<debugStart.lowerBound])
        let redStateSections = [
            ("calendar", calendarSource),
            ("project", projectSource),
            ("adjustment", adjustmentSource)
        ]
        let forbiddenTokens = [
            "smart suggestion", "suggestion card", "auto repair", "automatic repair",
            "repair plan", "proposal", "ChatView", "sendMessage", "confirmChat",
            "currentProposal", "chatMessages", "智能建议", "建议卡", "自动修复", "修复方案"
        ]

        XCTAssertTrue(source.contains("defaultModeSilentRedStateFact"))
        for (name, section) in redStateSections {
            XCTAssertTrue(section.contains("defaultModeSilentRedStateFact"), "\(name) red-state section must use the fact-only silent-mode guard")
            let lowercasedSection = section.lowercased()
            for token in forbiddenTokens {
                XCTAssertFalse(lowercasedSection.contains(token.lowercased()), "\(name) red-state section must not contain \(token)")
            }
        }
        XCTAssertTrue(projectSource.contains("expectedLate"))
        XCTAssertTrue(calendarSource.contains("overCapacity"))
        XCTAssertTrue(calendarSource.contains("restDay"))
        XCTAssertTrue(adjustmentSource.contains("redStateImpact"))
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

    func testAddInitiateSurfaceLabelsInputTypesAndAvoidsLegacyURLOnlyPrimaryWording() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        let viewModelSource = try sourceFile("MalDaze/LearningAssistant/LearningAssistantViewModel.swift")
        guard let start = source.range(of: "private struct AddInitiateView"),
              let end = source[start.upperBound...].range(of: "private func progressRow") else {
            XCTFail("AddInitiateView source section not found")
            return
        }
        let addSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(source.contains("case .addResource:"))
        XCTAssertTrue(source.contains("AddInitiateView(vm: vm)"))
        XCTAssertTrue(source.contains("case .addResource: return \"添加/立项\""))
        XCTAssertTrue(addSource.contains("Add / Initiate"))
        XCTAssertTrue(addSource.contains("添加 / 立项"))
        XCTAssertTrue(viewModelSource.contains("text_goal"))
        XCTAssertTrue(viewModelSource.contains("url"))
        XCTAssertTrue(viewModelSource.contains("github_repo"))
        XCTAssertTrue(viewModelSource.contains("existing_project_snippet"))
        XCTAssertTrue(viewModelSource.contains("interview_prep_item"))
        XCTAssertTrue(viewModelSource.contains("resume_project_note"))
        XCTAssertTrue(viewModelSource.contains("note_snippet"))
        XCTAssertTrue(addSource.contains("vm.startAddInitiateSession"))
        XCTAssertFalse(addSource.contains("学习资料 URL"))
        XCTAssertFalse(addSource.contains("vm.startStudyPlan(url:"))
        XCTAssertFalse(addSource.contains("vm.startIngestion"))
    }

    func testAddInitiateRoleReviewShowsReasonConfidenceSwitchingAndAttachmentModes() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        let viewModelSource = try sourceFile("MalDaze/LearningAssistant/LearningAssistantViewModel.swift")
        guard let start = source.range(of: "private struct AddInitiateView"),
              let end = source[start.upperBound...].range(of: "private func progressRow") else {
            XCTFail("AddInitiateView source section not found")
            return
        }
        let addSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(addSource.contains("recommendedRole"))
        XCTAssertTrue(addSource.contains("confidence"))
        XCTAssertTrue(addSource.contains("reasonCodes"))
        XCTAssertTrue(viewModelSource.contains("new_plan"))
        XCTAssertTrue(viewModelSource.contains("attach_to_existing_plan"))
        XCTAssertTrue(viewModelSource.contains("reference_material"))
        XCTAssertTrue(viewModelSource.contains("later_resource"))
        XCTAssertTrue(viewModelSource.contains("one_off_action"))
        XCTAssertTrue(viewModelSource.contains("existingPlanCandidates"))
        XCTAssertTrue(viewModelSource.contains("material_only"))
        XCTAssertTrue(viewModelSource.contains("draft_phase"))
        XCTAssertTrue(viewModelSource.contains("scheduled_work"))
        XCTAssertTrue(viewModelSource.contains("辅助材料"))
        XCTAssertTrue(addSource.contains("vm.confirmAddInitiateRole"))
    }

    func testAddInitiateRoleReviewSeedingResetsPerSessionSelections() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private struct AddInitiateView"),
              let end = source[start.upperBound...].range(of: "private struct StudyPlanIntakeView") else {
            XCTFail("AddInitiateView source section not found")
            return
        }
        let addSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(addSource.contains("seededRoleReviewIdentity"))
        XCTAssertTrue(addSource.contains("selectedExistingPlanID = vm.addInitiateExistingPlanCandidates.first?.id"))
        XCTAssertTrue(addSource.contains("selectedAttachmentMode = .materialOnly"))
        XCTAssertFalse(addSource.contains("selectedExistingPlanID = selectedExistingPlanID ??"))
    }

    func testAddInitiateAnchorAndRecoveryUISourceExposesStateMachineTokensAndOnePrimaryRule() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private struct AddInitiateView"),
              let end = source[start.upperBound...].range(of: "private struct StudyPlanIntakeView") else {
            XCTFail("AddInitiateView source section not found")
            return
        }
        let addSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(addSource.contains("confirmAddInitiateAnchors"))
        XCTAssertTrue(addSource.contains("addInitiateDeadline"))
        XCTAssertTrue(addSource.contains("addInitiateCapacityMinutes"))
        XCTAssertTrue(addSource.contains("addInitiateTargetOutput"))
        XCTAssertTrue(addSource.contains("addInitiateTargetDepth"))
        XCTAssertTrue(addSource.contains("addInitiateAssumptionsText"))
        XCTAssertTrue(addSource.contains("needs_input"))
        XCTAssertTrue(addSource.contains("compile_failed"))
        XCTAssertTrue(addSource.contains("infeasible_review"))
        XCTAssertTrue(addSource.contains("draft_review"))
        XCTAssertTrue(addSource.contains("activation_failed"))
        XCTAssertTrue(addSource.contains("addInitiatePrimaryActionCount"))
        XCTAssertTrue(addSource.contains("cancelAddInitiateFlow"))
    }

    func testAddInitiateReviewStatesHideInputPrimaryWireRecoveryActionsAndAvoidVisibleRawTokens() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private struct AddInitiateView"),
              let end = source[start.upperBound...].range(of: "private struct StudyPlanIntakeView") else {
            XCTFail("AddInitiateView source section not found")
            return
        }
        let addSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(addSource.contains("canShowAddInitiateInputPrimaryAction"))
        XCTAssertTrue(addSource.contains("await vm.activateAddInitiateDraft()"))
        XCTAssertTrue(addSource.contains("vm.prepareForNewAddInitiateInput()"))
        XCTAssertTrue(addSource.contains("vm.addInitiateAssumptionsText"))
        XCTAssertTrue(addSource.contains("vm.addInitiateFlowState == .needsInput"))
        XCTAssertFalse(addSource.contains("analyzing_input / routing_item"))
        XCTAssertFalse(addSource.contains("planning_progress\")"))
        XCTAssertFalse(addSource.contains("deadline type"))
        XCTAssertFalse(addSource.contains("Text(\"soft\")"))
        XCTAssertFalse(addSource.contains("Text(\"hard\")"))
        XCTAssertFalse(addSource.contains("title: \"cancelled\""))
    }

    func testAddInitiateDraftReviewUISourceIsSummaryFirstWithExplicitExpansionControls() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private struct AddInitiateView"),
              let end = source[start.upperBound...].range(of: "private struct StudyPlanIntakeView") else {
            XCTFail("AddInitiateView source section not found")
            return
        }
        let addSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(addSource.contains("addInitiateDraftReviewSummary"))
        XCTAssertTrue(addSource.contains("首周摘要"))
        XCTAssertTrue(addSource.contains("缓冲"))
        XCTAssertTrue(addSource.contains("低能量 fallback"))
        XCTAssertTrue(addSource.contains("容量风险"))
        XCTAssertTrue(addSource.contains("截止风险"))
        XCTAssertTrue(addSource.contains("DisclosureGroup(\"完整排期\""))
        XCTAssertTrue(addSource.contains("DisclosureGroup(\"来源细节\""))
        XCTAssertTrue(addSource.contains("DisclosureGroup(\"单项编辑\""))
        XCTAssertTrue(addSource.contains("ForEach(summary.fullScheduleDays"))
        XCTAssertTrue(addSource.contains("ForEach(day.items"))
        XCTAssertTrue(addSource.contains("editableTaskRow"))
        XCTAssertTrue(addSource.contains("TextField(\"任务标题\""))
        XCTAssertTrue(addSource.contains("Stepper(value: addInitiateTaskEditMinutesBinding"))
        XCTAssertTrue(addSource.contains("vm.beginAddInitiateTaskEdit(item)"))
        XCTAssertFalse(addSource.contains("disabledEditRow"))
        XCTAssertFalse(addSource.contains(".disabled(true)"))
        XCTAssertFalse(addSource.contains("共 \\(summary.fullScheduleDayCount) 天，默认只展示首周摘要。"))
        XCTAssertFalse(addSource.contains("可编辑项 \\(summary.editableTaskCount) 个，编辑后需重新审阅。"))
    }

    func testAddInitiateInfeasibleAndActivationUISourceUsesCanonicalOptionsRetryEditCancel() throws {
        let source = try sourceFile("MalDaze/LearningAssistant/AssistantPanelView.swift")
        guard let start = source.range(of: "private struct AddInitiateView"),
              let end = source[start.upperBound...].range(of: "private struct StudyPlanIntakeView") else {
            XCTFail("AddInitiateView source section not found")
            return
        }
        let addSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(addSource.contains("addInitiateInfeasibleOptionChoices"))
        XCTAssertTrue(addSource.contains("option.optionId"))
        XCTAssertTrue(addSource.contains("option.localizedLabel"))
        XCTAssertTrue(addSource.contains("applyAddInitiateOptionEffect(optionId: option.optionId)"))
        XCTAssertTrue(addSource.contains("canActivateAddInitiateDraft"))
        XCTAssertTrue(addSource.contains("editAddInitiateDraft"))
        XCTAssertTrue(addSource.contains("重试激活"))
        XCTAssertTrue(addSource.contains("继续编辑"))
        XCTAssertTrue(addSource.contains("取消"))
        XCTAssertTrue(addSource.contains("case .optionEffectProgress"))
        XCTAssertTrue(addSource.contains("infeasibleReviewCard(isApplyingOption: true)"))
        XCTAssertFalse(addSource.contains("draftReviewCard(isApplyingOption: true)"))
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

    func testStartAddInitiateSessionUsesAdapterAndStoresRoleReviewState() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Ship an agent-browser demo", sourceType: .textGoal)

        XCTAssertEqual(mock.startAddInitiateSessionCallCount, 1)
        XCTAssertEqual(mock.lastAddInitiateStartRequest?.rawInput, "Ship an agent-browser demo")
        XCTAssertEqual(mock.lastAddInitiateStartRequest?.sourceType, "text_goal")
        XCTAssertFalse(mock.lastAddInitiateStartRequest?.clientRequestId.isEmpty ?? true)
        XCTAssertNil(mock.lastStudyPlanStartURL)
        XCTAssertNil(mock.lastConfirmIngestionConfirmed)
        XCTAssertEqual(vm.addInitiateSession?.sessionId, "add-initiate-1")
        XCTAssertEqual(vm.addInitiateSession?.reviewState, .roleReview)
        XCTAssertEqual(vm.addInitiateRecommendedRole, "attach_to_existing_plan")
        XCTAssertEqual(vm.addInitiateStage, .roleReview)
        XCTAssertFalse(vm.isStartingAddInitiateSession)
        XCTAssertNil(vm.addInitiateError)
    }

    func testStartAddInitiateGitHubRepoUsesAdapterAndNotLegacyStartPaths() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "https://github.com/example/repo", sourceType: .githubRepo)

        XCTAssertEqual(mock.startAddInitiateSessionCallCount, 1)
        XCTAssertEqual(mock.lastAddInitiateStartRequest?.rawInput, "https://github.com/example/repo")
        XCTAssertEqual(mock.lastAddInitiateStartRequest?.sourceType, "github_repo")
        XCTAssertEqual(mock.startIngestionCallCount, 0)
        XCTAssertNil(mock.lastStudyPlanStartURL)
        XCTAssertEqual(vm.addInitiateSession?.reviewState, .roleReview)
    }

    func testConfirmAddInitiateMaterialOnlyAttachmentIsQuietAndMapsSupportingMaterialRole() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateMaterialAttachedSession()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "MalDaze note", sourceType: .noteSnippet)
        await vm.confirmAddInitiateRole(
            title: "MalDaze note",
            confirmedRole: .supportingMaterial,
            existingPlanId: 7,
            attachmentMode: .materialOnly
        )

        XCTAssertEqual(mock.confirmAddInitiateRoleCallCount, 1)
        XCTAssertEqual(mock.lastAddInitiateRoleRequest?.sessionId, "add-initiate-1")
        XCTAssertEqual(mock.lastAddInitiateRoleRequest?.intakeItemId, 11)
        XCTAssertEqual(mock.lastAddInitiateRoleRequest?.confirmedRole, "attach_to_existing_plan")
        XCTAssertEqual(mock.lastAddInitiateRoleRequest?.attachmentMode, "material_only")
        XCTAssertEqual(mock.lastAddInitiateRoleRequest?.existingPlanId, 7)
        XCTAssertEqual(vm.addInitiateSession?.reviewState, .materialAttached)
        XCTAssertEqual(vm.addInitiateStage, .materialAttached)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 0)
        XCTAssertEqual(mock.fetchResourcesCallCount, 0)
    }

    func testConfirmAddInitiateNonAttachmentRolesDoNotLeakExistingPlanOrAttachmentMode() async {
        let roles: [AddInitiateRoleChoice] = [.newPlan, .referenceMaterial, .laterResource, .oneOffAction]

        for role in roles {
            let mock = MockAssistantAPIClient()
            mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
            mock.addInitiateRoleResult = sampleAddInitiateMaterialAttachedSession()
            let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

            await vm.startAddInitiateSession(rawInput: "Candidate \(role.rawValue)", sourceType: .textGoal)
            await vm.confirmAddInitiateRole(
                title: "Candidate \(role.rawValue)",
                confirmedRole: role,
                existingPlanId: 7,
                attachmentMode: .scheduledWork
            )

            XCTAssertEqual(mock.confirmAddInitiateRoleCallCount, 1)
            let expectedRole = role == .oneOffAction ? "immediate_one_off" : role.rawValue
            XCTAssertEqual(mock.lastAddInitiateRoleRequest?.confirmedRole, expectedRole)
            XCTAssertNil(mock.lastAddInitiateRoleRequest?.existingPlanId, "\(role.rawValue) must not send existingPlanId")
            XCTAssertNil(mock.lastAddInitiateRoleRequest?.attachmentMode, "\(role.rawValue) must not send attachmentMode")
        }
    }

    func testConfirmAddInitiateAttachmentModesMapDraftPhaseAndScheduledWork() async {
        let cases: [(AddInitiateAttachmentMode, String, String)] = [
            (.draftPhase, "draft_phase", "Phase notes"),
            (.scheduledWork, "scheduled_work", "Scheduled notes")
        ]

        for (mode, expectedMode, title) in cases {
            let mock = MockAssistantAPIClient()
            mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
            mock.addInitiateRoleResult = sampleAddInitiateMaterialAttachedSession()
            let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

            await vm.startAddInitiateSession(rawInput: title, sourceType: .noteSnippet)
            await vm.confirmAddInitiateRole(
                title: title,
                confirmedRole: .attachToExistingPlan,
                existingPlanId: 7,
                attachmentMode: mode
            )

            XCTAssertEqual(mock.confirmAddInitiateRoleCallCount, 1)
            XCTAssertEqual(mock.lastAddInitiateRoleRequest?.confirmedRole, "attach_to_existing_plan")
            XCTAssertEqual(mock.lastAddInitiateRoleRequest?.existingPlanId, 7)
            XCTAssertEqual(mock.lastAddInitiateRoleRequest?.attachmentMode, expectedMode)
        }
    }

    func testConfirmAddInitiateSupportingMaterialRequiresExistingPlanBeforeCallingAPI() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Loose note", sourceType: .noteSnippet)
        await vm.confirmAddInitiateRole(
            title: "Loose note",
            confirmedRole: .supportingMaterial,
            existingPlanId: nil,
            attachmentMode: .materialOnly
        )

        XCTAssertEqual(mock.confirmAddInitiateRoleCallCount, 0)
        XCTAssertNil(mock.lastAddInitiateRoleRequest)
        XCTAssertNotNil(vm.addInitiateError)
        XCTAssertEqual(vm.addInitiateSession?.reviewState, .roleReview)
    }

    func testConfirmAddInitiateAttachToExistingPlanRequiresPlanAndModeBeforeCallingAPI() async {
        let missingPlan = MockAssistantAPIClient()
        missingPlan.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        var vm = LearningAssistantViewModel(api: missingPlan, autoLoadWhenReady: false)
        await vm.startAddInitiateSession(rawInput: "Attach me", sourceType: .noteSnippet)
        await vm.confirmAddInitiateRole(
            title: "Attach me",
            confirmedRole: .attachToExistingPlan,
            existingPlanId: nil,
            attachmentMode: .draftPhase
        )
        XCTAssertEqual(missingPlan.confirmAddInitiateRoleCallCount, 0)
        XCTAssertNotNil(vm.addInitiateError)

        let missingMode = MockAssistantAPIClient()
        missingMode.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        vm = LearningAssistantViewModel(api: missingMode, autoLoadWhenReady: false)
        await vm.startAddInitiateSession(rawInput: "Attach me", sourceType: .noteSnippet)
        await vm.confirmAddInitiateRole(
            title: "Attach me",
            confirmedRole: .attachToExistingPlan,
            existingPlanId: 7,
            attachmentMode: nil
        )
        XCTAssertEqual(missingMode.confirmAddInitiateRoleCallCount, 0)
        XCTAssertNotNil(vm.addInitiateError)
    }

    func testConfirmAddInitiateStaleFailureDoesNotOverwriteNewSessionErrorOrOfflineState() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession(sessionId: "add-initiate-old", clientRequestId: "req-old", intakeItemId: 11)
        mock.addInitiateRoleError = NSError(domain: "AddInitiateRole", code: 500)
        mock.addInitiateRoleDelayNanoseconds = 100_000_000
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Old", sourceType: .noteSnippet)
        let firstConfirm = Task {
            await vm.confirmAddInitiateRole(
                title: "Old",
                confirmedRole: .attachToExistingPlan,
                existingPlanId: 7,
                attachmentMode: .draftPhase
            )
        }
        await mock.waitForAddInitiateRoleCallCount(1)

        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession(sessionId: "add-initiate-new", clientRequestId: "req-new", intakeItemId: 12)
        await vm.startAddInitiateSession(rawInput: "New", sourceType: .textGoal)
        await firstConfirm.value

        XCTAssertEqual(vm.addInitiateSession?.sessionId, "add-initiate-new")
        XCTAssertNil(vm.addInitiateError)
        XCTAssertFalse(vm.isOffline)
    }

    func testConfirmAddInitiateAnchorsUsesAdapterShowsPlanningProgressAndPreservesNeedsInputContext() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateNeedsInputSession()
        mock.addInitiateAnchorDelayNanoseconds = 100_000_000
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Build a Swift testing course", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Swift testing", confirmedRole: .newPlan)

        vm.addInitiateDeadline = "2026-07-01"
        vm.addInitiateDeadlineType = "hard"
        vm.addInitiateCapacityMinutes = 75
        vm.addInitiateTargetOutput = "working course outline"
        vm.addInitiateTargetDepth = "apply"
        vm.addInitiateAcceptedAssumptions = ["weekdays only", "no weekends"]

        let confirmation = Task { await vm.confirmAddInitiateAnchors() }
        await mock.waitForAddInitiateAnchorCallCount(1)

        XCTAssertEqual(vm.addInitiateFlowState, .planningProgress)
        await confirmation.value

        XCTAssertEqual(mock.confirmAddInitiateAnchorCallCount, 1)
        XCTAssertEqual(mock.lastAddInitiateAnchorRequest?.sessionId, "add-initiate-1")
        XCTAssertEqual(mock.lastAddInitiateAnchorRequest?.draftId, 501)
        XCTAssertEqual(mock.lastAddInitiateAnchorRequest?.intakeItemId, 11)
        XCTAssertEqual(mock.lastAddInitiateAnchorRequest?.deadline, "2026-07-01")
        XCTAssertEqual(mock.lastAddInitiateAnchorRequest?.deadlineType, "hard")
        XCTAssertEqual(mock.lastAddInitiateAnchorRequest?.capacityMinutes, 75)
        XCTAssertEqual(mock.lastAddInitiateAnchorRequest?.targetOutput, "working course outline")
        XCTAssertEqual(mock.lastAddInitiateAnchorRequest?.targetDepth, "apply")
        XCTAssertEqual(mock.lastAddInitiateAnchorRequest?.assumptions?["accepted"]?.value as? [String], ["weekdays only", "no weekends"])
        XCTAssertEqual(vm.addInitiateFlowState, .needsInput)
        XCTAssertEqual(vm.addInitiateRawInput, "Build a Swift testing course")
        XCTAssertEqual(vm.addInitiateSession?.confirmedRole, "new_plan")
        XCTAssertEqual(vm.addInitiateDeadline, "2026-07-01")
        XCTAssertEqual(vm.addInitiatePrimaryActionCount, 1)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 0)
    }

    func testNeedsInputKeepsAnchorsEditableAndSubmitsAnswerWithKnownContext() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResultsQueue = [
            DelayedAddInitiateSessionResult(session: sampleAddInitiateNeedsInputSession(), delayNanoseconds: 0),
            DelayedAddInitiateSessionResult(session: sampleAddInitiateDraftReviewSession(), delayNanoseconds: 0)
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Design a debugging sprint", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Debugging sprint", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-07-10"
        vm.addInitiateDeadlineType = "hard"
        vm.addInitiateCapacityMinutes = 50
        vm.addInitiateTargetOutput = "debugging playbook"
        vm.addInitiateTargetDepth = "apply"
        vm.addInitiateAssumptionsText = "weekdays only"

        await vm.confirmAddInitiateAnchors()
        XCTAssertEqual(vm.addInitiateFlowState, .needsInput)

        vm.addInitiateCapacityMinutes = 65
        vm.addInitiateAssumptionsText = "weekdays only\nskip backend work"
        vm.addInitiateNeedsInputAnswer = "Exclude backend work"
        await vm.answerAddInitiateNeedsInput()

        XCTAssertEqual(mock.confirmAddInitiateAnchorCallCount, 2)
        XCTAssertEqual(mock.lastAddInitiateAnchorRequest?.capacityMinutes, 65)
        XCTAssertEqual(mock.lastAddInitiateAnchorRequest?.assumptions?["accepted"]?.value as? [String], [
            "weekdays only",
            "skip backend work",
            "Exclude backend work"
        ])
        XCTAssertEqual(vm.addInitiateFlowState, .draftReview)
    }

    func testCompileFailedRetryReusesRetainedAnchorsAndCanReachDraftReview() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateCompileFailedSession()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Rebuild easyagent repo", sourceType: .githubRepo)
        await vm.confirmAddInitiateRole(title: "easyagent rebuild", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-08-15"
        vm.addInitiateDeadlineType = "soft"
        vm.addInitiateCapacityMinutes = 45
        vm.addInitiateTargetOutput = "repo rebuild plan"
        vm.addInitiateTargetDepth = "understand"
        vm.addInitiateAcceptedAssumptions = ["focus on architecture"]

        await vm.confirmAddInitiateAnchors()

        XCTAssertEqual(vm.addInitiateFlowState, .compileFailed)
        XCTAssertEqual(vm.addInitiatePrimaryActionCount, 1)
        XCTAssertEqual(mock.confirmAddInitiateAnchorCallCount, 1)

        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession()
        await vm.retryAddInitiatePlanning()

        XCTAssertEqual(mock.confirmAddInitiateAnchorCallCount, 2)
        XCTAssertEqual(mock.lastAddInitiateAnchorRequest?.deadline, "2026-08-15")
        XCTAssertEqual(mock.lastAddInitiateAnchorRequest?.capacityMinutes, 45)
        XCTAssertEqual(mock.lastAddInitiateAnchorRequest?.targetOutput, "repo rebuild plan")
        XCTAssertEqual(mock.lastAddInitiateAnchorRequest?.targetDepth, "understand")
        XCTAssertEqual(vm.addInitiateFlowState, .draftReview)
        XCTAssertEqual(vm.addInitiatePrimaryActionCount, 1)
    }

    func testStaleAnchorResponseCannotOverwriteNewerSession() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession(sessionId: "add-initiate-old", clientRequestId: "req-old", intakeItemId: 11)
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession(sessionId: "add-initiate-old", clientRequestId: "req-old", intakeItemId: 11, draftId: 501)
        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession(sessionId: "add-initiate-old", clientRequestId: "req-old", intakeItemId: 11, draftId: 501, draftVersion: 1)
        mock.addInitiateAnchorDelayNanoseconds = 100_000_000
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Old plan", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Old plan", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-07-01"
        vm.addInitiateTargetOutput = "old output"
        vm.addInitiateTargetDepth = "apply"

        let oldConfirmation = Task { await vm.confirmAddInitiateAnchors() }
        await mock.waitForAddInitiateAnchorCallCount(1)

        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession(sessionId: "add-initiate-new", clientRequestId: "req-new", intakeItemId: 12)
        await vm.startAddInitiateSession(rawInput: "New plan", sourceType: .noteSnippet)
        await oldConfirmation.value

        XCTAssertEqual(vm.addInitiateSession?.sessionId, "add-initiate-new")
        XCTAssertEqual(vm.addInitiateFlowState, .roleReview)
        XCTAssertNil(vm.addInitiateError)
    }

    func testSameSessionAnchorResponseWithNilOrOlderDraftVersionCannotOverwriteNewerDraft() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession(draftVersion: 1)
        mock.addInitiateAnchorResultsQueue = [
            DelayedAddInitiateSessionResult(
                session: sampleAddInitiateDraftReviewSession(draftVersion: nil),
                delayNanoseconds: 100_000_000
            ),
            DelayedAddInitiateSessionResult(
                session: sampleAddInitiateDraftReviewSession(draftVersion: 2),
                delayNanoseconds: 0
            )
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Protect new draft", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Protect new draft", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-07-12"
        vm.addInitiateTargetOutput = "draft"
        vm.addInitiateTargetDepth = "apply"

        let staleConfirm = Task { await vm.confirmAddInitiateAnchors() }
        await mock.waitForAddInitiateAnchorCallCount(1)
        await vm.confirmAddInitiateAnchors()
        XCTAssertEqual(vm.addInitiateSession?.draftVersion, 2)

        await staleConfirm.value

        XCTAssertEqual(mock.confirmAddInitiateAnchorCallCount, 2)
        XCTAssertEqual(vm.addInitiateSession?.draftVersion, 2)
        XCTAssertEqual(vm.addInitiateFlowState, .draftReview)
    }

    func testCancelInvalidatesInFlightAnchorResponse() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession()
        mock.addInitiateAnchorDelayNanoseconds = 100_000_000
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Cancel while planning", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Cancel while planning", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-07-14"
        vm.addInitiateTargetOutput = "draft"
        vm.addInitiateTargetDepth = "apply"

        let confirmation = Task { await vm.confirmAddInitiateAnchors() }
        await mock.waitForAddInitiateAnchorCallCount(1)
        vm.cancelAddInitiateFlow()
        await confirmation.value

        XCTAssertEqual(vm.addInitiateFlowState, .cancelled)
        XCTAssertNotEqual(vm.addInitiateSession?.reviewState, .draftReview)
    }

    func testNewStartSupersedesInFlightStartAndIgnoresOldResponse() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResultsQueue = [
            DelayedAddInitiateSessionResult(
                session: sampleAddInitiateRoleReviewSession(sessionId: "start-old", clientRequestId: "req-old", intakeItemId: 11),
                delayNanoseconds: 100_000_000
            ),
            DelayedAddInitiateSessionResult(
                session: sampleAddInitiateRoleReviewSession(sessionId: "start-new", clientRequestId: "req-new", intakeItemId: 12),
                delayNanoseconds: 0
            )
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        let firstStart = Task { await vm.startAddInitiateSession(rawInput: "Old start", sourceType: .textGoal) }
        await mock.waitForAddInitiateStartCallCount(1)
        await vm.startAddInitiateSession(rawInput: "New start", sourceType: .noteSnippet)
        await firstStart.value

        XCTAssertEqual(mock.startAddInitiateSessionCallCount, 2)
        XCTAssertEqual(vm.addInitiateSession?.sessionId, "start-new")
        XCTAssertEqual(vm.addInitiateRawInput, "New start")
    }

    func testNewSessionAnchorConfirmIsNotBlockedByOldInFlightAnchorConfirm() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResultsQueue = [
            DelayedAddInitiateSessionResult(
                session: sampleAddInitiateRoleReviewSession(sessionId: "anchor-old", clientRequestId: "req-old", intakeItemId: 11),
                delayNanoseconds: 0
            ),
            DelayedAddInitiateSessionResult(
                session: sampleAddInitiateRoleReviewSession(sessionId: "anchor-new", clientRequestId: "req-new", intakeItemId: 12),
                delayNanoseconds: 0
            )
        ]
        mock.addInitiateRoleResultsQueue = [
            sampleAddInitiateAnchorReviewSession(sessionId: "anchor-old", clientRequestId: "req-old", intakeItemId: 11, draftId: 501),
            sampleAddInitiateAnchorReviewSession(sessionId: "anchor-new", clientRequestId: "req-new", intakeItemId: 12, draftId: 502)
        ]
        mock.addInitiateAnchorResultsQueue = [
            DelayedAddInitiateSessionResult(
                session: sampleAddInitiateDraftReviewSession(sessionId: "anchor-old", clientRequestId: "req-old", intakeItemId: 11, draftId: 501, draftVersion: 2),
                delayNanoseconds: 100_000_000
            ),
            DelayedAddInitiateSessionResult(
                session: sampleAddInitiateDraftReviewSession(sessionId: "anchor-new", clientRequestId: "req-new", intakeItemId: 12, draftId: 502, draftVersion: 1),
                delayNanoseconds: 0
            )
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Old anchor", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Old anchor", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-07-15"
        vm.addInitiateTargetOutput = "old draft"
        vm.addInitiateTargetDepth = "apply"
        let oldConfirm = Task { await vm.confirmAddInitiateAnchors() }
        await mock.waitForAddInitiateAnchorCallCount(1)

        await vm.startAddInitiateSession(rawInput: "New anchor", sourceType: .noteSnippet)
        await vm.confirmAddInitiateRole(title: "New anchor", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-07-16"
        vm.addInitiateTargetOutput = "new draft"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()
        await oldConfirm.value

        XCTAssertEqual(mock.confirmAddInitiateAnchorCallCount, 2)
        XCTAssertEqual(vm.addInitiateSession?.sessionId, "anchor-new")
        XCTAssertEqual(vm.addInitiateSession?.draftId, 502)
        XCTAssertEqual(vm.addInitiateFlowState, .draftReview)
    }

    func testCancelAddInitiateBeforeActivationIsQuietAndHasOnePrimaryAction() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Draft only", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Draft only", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-09-01"
        vm.addInitiateTargetOutput = "draft"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()

        vm.cancelAddInitiateFlow()

        XCTAssertEqual(vm.addInitiateFlowState, .cancelled)
        XCTAssertEqual(vm.addInitiatePrimaryActionCount, 1)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 0)
        XCTAssertEqual(mock.fetchResourcesCallCount, 0)
    }

    func testOptionEffectStaleResponseCannotOverwriteNewerSession() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession(sessionId: "option-old", clientRequestId: "req-old", intakeItemId: 11)
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession(sessionId: "option-old", clientRequestId: "req-old", intakeItemId: 11, draftId: 501)
        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession(sessionId: "option-old", clientRequestId: "req-old", intakeItemId: 11, draftId: 501, draftVersion: 1)
        mock.addInitiateOptionResult = sampleAddInitiateDraftReviewSession(sessionId: "option-old", clientRequestId: "req-old", intakeItemId: 11, draftId: 501, draftVersion: 2)
        mock.addInitiateOptionDelayNanoseconds = 100_000_000
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Old option", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Old option", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-10-01"
        vm.addInitiateTargetOutput = "draft"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()

        let optionTask = Task { await vm.applyAddInitiateOptionEffect(optionId: "reduce_scope") }
        await mock.waitForAddInitiateOptionCallCount(1)
        XCTAssertEqual(vm.addInitiateFlowState, .optionEffectProgress)

        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession(sessionId: "option-new", clientRequestId: "req-new", intakeItemId: 12)
        await vm.startAddInitiateSession(rawInput: "New option", sourceType: .noteSnippet)
        await optionTask.value

        XCTAssertEqual(mock.lastAddInitiateOptionRequest?.draftVersion, 1)
        XCTAssertEqual(vm.addInitiateSession?.sessionId, "option-new")
        XCTAssertEqual(vm.addInitiateFlowState, .roleReview)
    }

    func testActivationFailurePreservesDraftIdentityAndDoesNotRefreshActiveSurfaces() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession(draftVersion: 3)
        mock.addInitiateActivationResult = sampleAddInitiateActivationFailedSession(draftVersion: 3)
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Activate later", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Activate later", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-11-01"
        vm.addInitiateTargetOutput = "draft"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()

        await vm.activateAddInitiateDraft()

        XCTAssertEqual(mock.activateAddInitiateDraftCallCount, 1)
        XCTAssertEqual(mock.lastAddInitiateActivationRequest?.draftId, 501)
        XCTAssertEqual(mock.lastAddInitiateActivationRequest?.draftVersion, 3)
        XCTAssertEqual(vm.addInitiateFlowState, .activationFailed)
        XCTAssertEqual(vm.addInitiatePrimaryActionCount, 1)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 0)
    }

    func testActivationFailedRetryCallsActivationAPIWithPreservedDraftVersion() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession(draftVersion: 3)
        mock.addInitiateActivationResult = sampleAddInitiateActivationFailedSession(draftVersion: 3)
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Retry activation", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Retry activation", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-11-02"
        vm.addInitiateTargetOutput = "draft"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()
        await vm.activateAddInitiateDraft()

        mock.addInitiateActivationResult = sampleAddInitiateActivatedSession(draftVersion: 3)
        await vm.activateAddInitiateDraft()

        XCTAssertEqual(mock.activateAddInitiateDraftCallCount, 2)
        XCTAssertEqual(mock.lastAddInitiateActivationRequest?.draftId, 501)
        XCTAssertEqual(mock.lastAddInitiateActivationRequest?.draftVersion, 3)
        XCTAssertEqual(vm.addInitiateFlowState, .activated)
    }

    func testDraftReviewSummaryUsesFirstSevenDaysRiskFactsAndFallbackMetadata() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession(
            draftVersion: 3,
            reviewPackage: sampleAddInitiateDraftReviewPackage(dayCount: 8)
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Ship AgentGuide rebuild", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "AgentGuide rebuild", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-06-12"
        vm.addInitiateDeadlineType = "hard"
        vm.addInitiateCapacityMinutes = 75
        vm.addInitiateTargetOutput = "reviewable rebuild plan"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()

        let summary = vm.addInitiateDraftReviewSummary
        XCTAssertEqual(summary?.roleLabel, "新计划")
        XCTAssertEqual(summary?.targetOutput, "reviewable rebuild plan")
        XCTAssertEqual(summary?.assumptions, ["weekdays only", "ship demo first"])
        XCTAssertEqual(summary?.firstWeekDays.count, 7)
        XCTAssertEqual(summary?.firstWeekDays.map(\.date), [
            "2026-06-01",
            "2026-06-02",
            "2026-06-03",
            "2026-06-04",
            "2026-06-05",
            "2026-06-06",
            "2026-06-07"
        ])
        XCTAssertEqual(summary?.firstWeekDays.first?.plannedMinutes, 60)
        XCTAssertEqual(summary?.firstWeekDays.first?.loadStateLabel, "预算内")
        XCTAssertEqual(summary?.firstWeekDays.first?.fallbackCue, "低能量：skim notes，风险：范围可见")
        XCTAssertEqual(summary?.bufferSummary, "预留缓冲：2026-06-06；缓冲被侵蚀")
        XCTAssertEqual(summary?.fallbackSummary, "替代执行：skim notes；风险影响：范围可见")
        XCTAssertEqual(summary?.capacityRiskFacts, [
            "必要工作 480 分钟",
            "可用容量 420 分钟",
            "容量缺口 60 分钟",
            "超载日期 2026-06-03",
            "预计延期 task-7",
            "已有负荷 2026-06-04"
        ])
        XCTAssertEqual(summary?.deadlineRisk, "硬截止日期压力")
        XCTAssertFalse(summary?.rendersEveryScheduledItemByDefault ?? true)
    }

    func testDraftReviewFirstWeekUsesShorterAvailableWindow() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession(
            reviewPackage: sampleAddInitiateDraftReviewPackage(dayCount: 3)
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Short window", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Short window", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-06-03"
        vm.addInitiateTargetOutput = "short plan"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()

        XCTAssertEqual(vm.addInitiateDraftReviewSummary?.firstWeekDays.count, 3)
    }

    func testInfeasibleOptionsUseCanonicalLocalizedLabelsAndFilterLateFinishForHardDeadlines() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateInfeasibleReviewSession(deadlineType: "hard")
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Hard deadline rebuild", sourceType: .githubRepo)
        await vm.confirmAddInitiateRole(title: "Hard deadline rebuild", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-06-05"
        vm.addInitiateDeadlineType = "hard"
        vm.addInitiateTargetOutput = "working rebuild"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()

        let options = vm.addInitiateInfeasibleOptionChoices
        XCTAssertEqual(options.map(\.optionId), ["reduce_scope", "lower_depth", "extend_deadline", "store_for_later"])
        XCTAssertEqual(options.map(\.localizedLabel), ["缩小范围", "降低深度", "调整截止日期", "存为稍后处理"])
        XCTAssertFalse(options.map(\.optionId).contains("accept_late_finish"))
    }

    func testInfeasibleReviewProjectsConcreteRiskFacts() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateInfeasibleReviewSession(deadlineType: "hard")
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Risk facts", sourceType: .githubRepo)
        await vm.confirmAddInitiateRole(title: "Risk facts", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-06-05"
        vm.addInitiateTargetOutput = "risk review"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()

        XCTAssertEqual(vm.addInitiateInfeasibleRiskFacts, [
            "容量缺口 90 分钟",
            "超载日期 2026-06-04",
            "预计延期 task-2",
            "缓冲被侵蚀",
            "低校准"
        ])
    }

    func testDraftReviewPerTaskEditDraftRecordsLocallyWithoutActiveRefresh() async throws {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession(
            reviewPackage: sampleAddInitiateDraftReviewPackage(dayCount: 2)
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Editable draft", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Editable draft", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-06-12"
        vm.addInitiateTargetOutput = "editable plan"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()

        let item = try XCTUnwrap(vm.addInitiateDraftReviewSummary?.fullScheduleDays.first?.items.first)
        vm.beginAddInitiateTaskEdit(item)
        vm.updateAddInitiateTaskEditTitle(itemId: item.id, title: "Edited task title")
        vm.updateAddInitiateTaskEditMinutes(itemId: item.id, minutes: 35)

        XCTAssertEqual(vm.addInitiateTaskEditDrafts[item.id]?.title, "Edited task title")
        XCTAssertEqual(vm.addInitiateTaskEditDrafts[item.id]?.minutes, 35)
        XCTAssertEqual(vm.addInitiateFlowState, .draftReview)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 0)
    }

    func testOptionEffectAcceptsNewReviewStorageAndFocusedNeedsInputResults() async {
        let newReview = MockAssistantAPIClient()
        newReview.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        newReview.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        newReview.addInitiateAnchorResult = sampleAddInitiateInfeasibleReviewSession()
        newReview.addInitiateOptionResult = sampleAddInitiateDraftReviewSession(draftVersion: 4)
        var vm = LearningAssistantViewModel(api: newReview, autoLoadWhenReady: false)
        await vm.startAddInitiateSession(rawInput: "Option review", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Option review", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-06-10"
        vm.addInitiateTargetOutput = "review"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()
        await vm.applyAddInitiateOptionEffect(optionId: "reduce_scope")
        XCTAssertEqual(vm.addInitiateFlowState, .draftReview)
        XCTAssertEqual(vm.addInitiateSession?.draftVersion, 4)

        let storage = MockAssistantAPIClient()
        storage.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        storage.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        storage.addInitiateAnchorResult = sampleAddInitiateInfeasibleReviewSession()
        storage.addInitiateOptionResult = sampleAddInitiateStoredLaterSession()
        vm = LearningAssistantViewModel(api: storage, autoLoadWhenReady: false)
        await vm.startAddInitiateSession(rawInput: "Store later", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Store later", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-06-10"
        vm.addInitiateTargetOutput = "stored"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()
        await vm.applyAddInitiateOptionEffect(optionId: "store_for_later")
        XCTAssertEqual(vm.addInitiateFlowState, .nonPlanTerminal)
        XCTAssertEqual(vm.addInitiateSession?.reviewState, .storedNonPlan)

        let needsInput = MockAssistantAPIClient()
        needsInput.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        needsInput.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        needsInput.addInitiateAnchorResult = sampleAddInitiateInfeasibleReviewSession()
        needsInput.addInitiateOptionResult = sampleAddInitiateNeedsInputSession(draftVersion: 2)
        vm = LearningAssistantViewModel(api: needsInput, autoLoadWhenReady: false)
        await vm.startAddInitiateSession(rawInput: "Need one answer", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Need one answer", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-06-10"
        vm.addInitiateTargetOutput = "needs input"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()
        await vm.applyAddInitiateOptionEffect(optionId: "answer_one_question")
        XCTAssertEqual(vm.addInitiateFlowState, .needsInput)
    }

    func testOptionEffectCompilerRecomputeHandoffReturnsToAnchorReview() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateInfeasibleReviewSession()
        mock.addInitiateOptionResult = sampleAddInitiateNeedsInputSession(draftVersion: 2)
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Recompute handoff", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Recompute handoff", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-06-10"
        vm.addInitiateTargetOutput = "recomputed"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()
        await vm.applyAddInitiateOptionEffect(optionId: "lower_depth")

        XCTAssertEqual(mock.lastAddInitiateOptionRequest?.optionId, "lower_depth")
        XCTAssertEqual(vm.addInitiateFlowState, .needsInput)
        XCTAssertEqual(vm.addInitiateSession?.reviewState, .needsInput)
        XCTAssertEqual(vm.addInitiateSession?.draftVersion, 2)
    }

    func testOptionEffectSendsParametersFromAnchorsFocusedAnswerAndLocalTaskEdits() async throws {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession(
            draftVersion: 2,
            reviewPackage: sampleAddInitiateDraftReviewPackage(dayCount: 2)
        )
        mock.addInitiateOptionResult = sampleAddInitiateDraftReviewSession(draftVersion: 3)
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Parameterized options", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Parameterized options", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-06-20"
        vm.addInitiateCapacityMinutes = 95
        vm.addInitiateTargetOutput = "parameterized review"
        vm.addInitiateTargetDepth = "skim"
        await vm.confirmAddInitiateAnchors()
        mock.addInitiateOptionResult = sampleAddInitiateDraftReviewSession(
            draftVersion: 2,
            reviewPackage: sampleAddInitiateDraftReviewPackage(dayCount: 2)
        )

        await vm.applyAddInitiateOptionEffect(optionId: "lower_depth")
        XCTAssertEqual(mock.lastAddInitiateOptionRequest?.parameters?.keys.sorted(), ["requested_depth"])
        XCTAssertEqual(mock.lastAddInitiateOptionRequest?.parameters?["requested_depth"]?.value as? String, "skim")

        await vm.applyAddInitiateOptionEffect(optionId: "increase_capacity")
        XCTAssertEqual(mock.lastAddInitiateOptionRequest?.parameters?.keys.sorted(), ["new_daily_capacity_min"])
        XCTAssertEqual(mock.lastAddInitiateOptionRequest?.parameters?["new_daily_capacity_min"]?.value as? Int, 95)

        await vm.applyAddInitiateOptionEffect(optionId: "extend_deadline")
        XCTAssertEqual(mock.lastAddInitiateOptionRequest?.parameters?.keys.sorted(), ["new_deadline"])
        XCTAssertEqual(mock.lastAddInitiateOptionRequest?.parameters?["new_deadline"]?.value as? String, "2026-06-20")

        vm.addInitiateNeedsInputAnswer = "Skip chapter 9."
        await vm.applyAddInitiateOptionEffect(optionId: "answer_one_question")
        XCTAssertNil(mock.lastAddInitiateOptionRequest?.parameters)

        let item = try XCTUnwrap(vm.addInitiateDraftReviewSummary?.fullScheduleDays.first?.items.first)
        vm.beginAddInitiateTaskEdit(item)
        vm.updateAddInitiateTaskEditTitle(itemId: item.id, title: "Edited task")
        vm.updateAddInitiateTaskEditMinutes(itemId: item.id, minutes: 35)
        await vm.applyAddInitiateOptionEffect(optionId: "edit_estimates")
        XCTAssertEqual(mock.lastAddInitiateOptionRequest?.parameters?.keys.sorted(), ["estimate_edits"])
        let estimateEdits = mock.lastAddInitiateOptionRequest?.parameters?["estimate_edits"]?.value as? [String: Int]
        XCTAssertEqual(estimateEdits?[item.id], 35)

        await vm.applyAddInitiateOptionEffect(optionId: "rebalance")
        XCTAssertEqual(mock.lastAddInitiateOptionRequest?.parameters?.keys.sorted(), ["load_shape"])
        XCTAssertEqual(mock.lastAddInitiateOptionRequest?.parameters?["load_shape"]?.value as? String, "steady")
    }

    func testActivationFailedWithoutReviewPackagePreservesCurrentDraftSummary() async {
        let preservedPackage = sampleAddInitiateDraftReviewPackage(dayCount: 2)
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession(
            draftVersion: 3,
            reviewPackage: preservedPackage
        )
        mock.addInitiateActivationResult = sampleAddInitiateActivationFailedSession(
            draftVersion: 3,
            reviewPackage: nil
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Preserve failed activation", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Preserve failed activation", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-06-20"
        vm.addInitiateTargetOutput = "reviewable rebuild plan"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()
        await vm.activateAddInitiateDraft()

        XCTAssertEqual(vm.addInitiateFlowState, .activationFailed)
        XCTAssertEqual(vm.addInitiateDraftReviewSummary?.targetOutput, "reviewable rebuild plan")
        XCTAssertEqual(vm.addInitiateDraftReviewSummary?.fullScheduleDayCount, 2)
    }

    func testStaleDraftActivationIsBlockedBeforeCallingAPIAndEditCancelRetryPathsRemainAvailable() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession(
            draftVersion: 2,
            reviewPackage: sampleAddInitiateDraftReviewPackage(dayCount: 2, latestDraftVersion: 3)
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Stale draft", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Stale draft", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-06-12"
        vm.addInitiateTargetOutput = "stale"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()

        XCTAssertFalse(vm.canActivateAddInitiateDraft)
        await vm.activateAddInitiateDraft()
        XCTAssertEqual(mock.activateAddInitiateDraftCallCount, 0)
        XCTAssertEqual(vm.addInitiateError, "草案已变更，请先重新载入最新版本。")

        vm.editAddInitiateDraft()
        XCTAssertEqual(vm.addInitiateFlowState, .anchorReview)
        XCTAssertEqual(vm.addInitiateSession?.draftVersion, 2)

        vm.cancelAddInitiateFlow()
        XCTAssertEqual(vm.addInitiateFlowState, .cancelled)
    }

    func testPackageDraftVersionMismatchBlocksActivationAndRetry() async {
        let package = sampleAddInitiateDraftReviewPackage(dayCount: 2, packageDraftVersion: 3)
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession(draftVersion: 2, reviewPackage: package)
        mock.addInitiateActivationResult = sampleAddInitiateActivationFailedSession(draftVersion: 2, reviewPackage: package)
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Package mismatch", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Package mismatch", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-06-20"
        vm.addInitiateTargetOutput = "mismatch"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()

        XCTAssertFalse(vm.canActivateAddInitiateDraft)
        await vm.activateAddInitiateDraft()
        XCTAssertEqual(mock.activateAddInitiateDraftCallCount, 0)

        mock.addInitiateAnchorResult = sampleAddInitiateActivationFailedSession(draftVersion: 2, reviewPackage: package)
        await vm.confirmAddInitiateAnchors()
        XCTAssertEqual(vm.addInitiateFlowState, .activationFailed)
        XCTAssertFalse(vm.canActivateAddInitiateDraft)
        await vm.activateAddInitiateDraft()
        XCTAssertEqual(mock.activateAddInitiateDraftCallCount, 0)
    }

    func testDraftReviewSummaryParsesCamelCaseReviewPackageAndLatestDraftVersion() async {
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession(
            draftVersion: 2,
            reviewPackage: sampleAddInitiateCamelCaseDraftReviewPackage(latestDraftVersion: 4)
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Camel review", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Camel review", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-06-20"
        vm.addInitiateTargetOutput = "camel review plan"
        vm.addInitiateTargetDepth = "overview"
        await vm.confirmAddInitiateAnchors()

        let summary = vm.addInitiateDraftReviewSummary
        XCTAssertEqual(summary?.firstWeekDays.first?.plannedMinutes, 70)
        XCTAssertEqual(summary?.firstWeekDays.first?.loadStateLabel, "使用缓冲")
        XCTAssertEqual(summary?.firstWeekDays.first?.fallbackCue, "低能量：outline only，风险：保留范围")
        XCTAssertEqual(summary?.fullScheduleDays.first?.items.first?.id, "camel-task")
        XCTAssertEqual(summary?.fullScheduleDays.first?.items.first?.minutes, 70)
        XCTAssertEqual(summary?.sourceDetailLines, ["标题: Camel Guide", "类型: GitHub 仓库"])
        XCTAssertEqual(summary?.deadlineRisk, "硬截止日期压力")
        XCTAssertFalse(vm.canActivateAddInitiateDraft)
    }

    func testVisibleReviewProjectionHumanizesUnknownRawIds() async {
        let package = sampleAddInitiateDraftReviewPackage(
            dayCount: 1,
            loadState: "deep_focus_required",
            deadlineRisk: "custom_date_window_risk",
            sourceDetails: ["source_kind": "github_repo"]
        )
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession(reviewPackage: package)
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Humanize raw ids", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Humanize raw ids", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-06-20"
        vm.addInitiateTargetOutput = "humanized"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()

        let summary = vm.addInitiateDraftReviewSummary
        XCTAssertEqual(summary?.firstWeekDays.first?.loadStateLabel, "Deep focus required")
        XCTAssertEqual(summary?.deadlineRisk, "Custom date window risk")
        XCTAssertEqual(summary?.sourceDetailLines, ["来源类型: GitHub 仓库"])

        let optionPackage: [String: AnyCodable] = [
            "risk_report": AnyCodable([
                "canonical_infeasibility_option_ids": ["custom_option_id"]
            ])
        ]
        mock.addInitiateAnchorResult = sampleAddInitiateInfeasibleReviewSession(
            deadlineType: "soft",
            reviewPackage: optionPackage
        )
        await vm.confirmAddInitiateAnchors()
        XCTAssertEqual(vm.addInitiateInfeasibleOptionChoices.first?.localizedLabel, "Custom option id")
    }

    func testOptionEffectNewDraftClearsLocalTaskEditDraftsForReusedTaskId() async throws {
        let package = sampleAddInitiateDraftReviewPackage(dayCount: 1)
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession(draftVersion: 2, reviewPackage: package)
        mock.addInitiateOptionResult = sampleAddInitiateDraftReviewSession(draftVersion: 3, reviewPackage: package)
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Clear local edits", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Clear local edits", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-06-20"
        vm.addInitiateTargetOutput = "clear edits"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()

        let item = try XCTUnwrap(vm.addInitiateDraftReviewSummary?.fullScheduleDays.first?.items.first)
        vm.beginAddInitiateTaskEdit(item)
        vm.updateAddInitiateTaskEditTitle(itemId: item.id, title: "Stale local title")
        XCTAssertFalse(vm.addInitiateTaskEditDrafts.isEmpty)

        await vm.applyAddInitiateOptionEffect(optionId: "reduce_scope")

        XCTAssertEqual(vm.addInitiateSession?.draftVersion, 3)
        XCTAssertTrue(vm.addInitiateTaskEditDrafts.isEmpty)
        XCTAssertEqual(vm.addInitiateTaskEditTitle(for: item), item.title)
    }

    func testAnchorReconfirmationNewDraftClearsLocalTaskEditDraftsForReusedTaskId() async throws {
        let package = sampleAddInitiateDraftReviewPackage(dayCount: 1)
        let mock = MockAssistantAPIClient()
        mock.addInitiateStartResult = sampleAddInitiateRoleReviewSession()
        mock.addInitiateRoleResult = sampleAddInitiateAnchorReviewSession()
        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession(draftVersion: 2, reviewPackage: package)
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.startAddInitiateSession(rawInput: "Anchor clear edits", sourceType: .textGoal)
        await vm.confirmAddInitiateRole(title: "Anchor clear edits", confirmedRole: .newPlan)
        vm.addInitiateDeadline = "2026-06-20"
        vm.addInitiateTargetOutput = "anchor clears edits"
        vm.addInitiateTargetDepth = "apply"
        await vm.confirmAddInitiateAnchors()

        let item = try XCTUnwrap(vm.addInitiateDraftReviewSummary?.fullScheduleDays.first?.items.first)
        vm.beginAddInitiateTaskEdit(item)
        vm.updateAddInitiateTaskEditTitle(itemId: item.id, title: "Stale anchor title")
        XCTAssertFalse(vm.addInitiateTaskEditDrafts.isEmpty)

        mock.addInitiateAnchorResult = sampleAddInitiateDraftReviewSession(draftVersion: 3, reviewPackage: package)
        vm.editAddInitiateDraft()
        await vm.confirmAddInitiateAnchors()

        XCTAssertEqual(vm.addInitiateSession?.draftVersion, 3)
        XCTAssertTrue(vm.addInitiateTaskEditDrafts.isEmpty)
        XCTAssertEqual(vm.addInitiateTaskEditTitle(for: item), item.title)
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

    func testAutoLoadDisabledIgnoresBackendReadyNotificationUntilDashboardOpen() async throws {
        let mock = MockAssistantAPIClient()
        let backend = MockBackendLifecycle()
        backend.isReady = false
        let vm = LearningAssistantViewModel(
            api: mock,
            backendLifecycle: backend,
            autoLoadWhenReady: false
        )

        XCTAssertFalse(vm.isConnecting)
        NotificationCenter.default.post(name: .backendDidBecomeReady, object: nil)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(vm.isConnecting)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 0)
        XCTAssertEqual(mock.fetchResourcesCallCount, 0)

        await vm.refreshForDashboardOpen()
        XCTAssertTrue(vm.isConnecting)
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

    func testManualAdjustmentMutationsDoNotInvokeChatProposalOrSmartRepairFlow() async {
        let mock = MockAssistantAPIClient()
        mock.studyCalendarLoadResult = sampleStudyCalendarLoad(start: "2026-06-01", end: "2026-06-30")
        mock.studyProjectOverviewResult = sampleStudyProjectOverview(
            activeProjects: [
                sampleStudyProjectSummaryJSON(
                    id: 7,
                    title: "Manual Red State",
                    completedUnits: 1,
                    totalUnits: 4,
                    progressRatio: 0.25,
                    status: "active",
                    expectedLate: true
                )
            ]
        )
        mock.studyRestDaySettingsUpdateResult = sampleStudyRestDaySettingsUpdateResult(
            weeklyWeekdays: [5],
            oneOffDates: ["2026-06-20"]
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchStudyCalendarLoad(start: "2026-06-01", end: "2026-06-30")
        mock.studyCalendarLoadResult = sampleStudyCalendarLoad(
            start: "2026-06-01",
            end: "2026-06-30",
            dayJSON: """
            {
                "date": "2026-06-21",
                "scheduled_task_count": 3,
                "total_target_minutes": 180,
                "completed_task_count": 0,
                "available_capacity_minutes": 75,
                "over_capacity": true,
                "rest_day": false
            }
            """
        )

        await vm.moveStudyTask(id: 42, scheduledDate: "2026-06-21")
        await vm.updateStudyProjectDeadline(projectId: 7, deadline: "2026-06-15")
        await vm.insertStudyProjectTask(
            projectId: 7,
            title: "Manual overload",
            targetMinutes: 180,
            scheduledDate: "2026-06-21"
        )
        await vm.deleteStudyTask(id: 99)
        await vm.updateStudyRestDaySettings(
            StudyRestDaySettings(weeklyWeekdays: [5], oneOffDates: ["2026-06-20"])
        )

        XCTAssertEqual(vm.studyProjectOverview?.activeProjects.first?.expectedLate, true)
        XCTAssertEqual(vm.studyCalendarLoad?.days.first?.overCapacity, true)
        XCTAssertEqual(mock.moveStudyTaskCallCount, 1)
        XCTAssertEqual(mock.updateStudyProjectDeadlineCallCount, 1)
        XCTAssertEqual(mock.insertStudyProjectTaskCallCount, 1)
        XCTAssertEqual(mock.deleteStudyTaskCallCount, 1)
        XCTAssertEqual(mock.updateStudyRestDaySettingsCallCount, 1)
        XCTAssertEqual(mock.sendMessageCallCount, 0)
        XCTAssertEqual(mock.confirmChatCallCount, 0)
        XCTAssertTrue(vm.chatMessages.isEmpty)
        XCTAssertNil(vm.currentProposal)
        XCTAssertNil(vm.studyDialogueAdjustmentPreview)
        XCTAssertNil(vm.studyDialogueAdjustmentResult)
        XCTAssertNil(vm.studyPlanAdjustmentError)
    }

    // MARK: 6.3 Study Smart Mode ViewModel

    func testDashboardDefaultSmartModeRemainsSilentAndDoesNotTouchLegacyProposalState() async {
        let mock = MockAssistantAPIClient()
        mock.studySmartModeSettingsResult = StudySmartModeSettings(enabled: false)
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.chatMessages = [ChatMessage(role: .assistant, text: "legacy")]
        vm.currentProposal = "legacy proposal"

        await vm.fetchDashboard()

        XCTAssertEqual(mock.fetchStudySmartModeSettingsCallCount, 1)
        XCTAssertEqual(mock.fetchStudySmartMorningBriefingCallCount, 0)
        XCTAssertEqual(mock.generateStudySmartProposalsCallCount, 0)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
        XCTAssertFalse(vm.isStudySmartModeEnabled)
        XCTAssertNil(vm.studySmartMorningBriefing)
        XCTAssertTrue(vm.studySmartProposalOptions.isEmpty)
        XCTAssertEqual(vm.chatMessages.map(\.text), ["legacy"])
        XCTAssertEqual(vm.currentProposal, "legacy proposal")
    }

    func testDashboardDefaultSmartModeKeepsRedStateFactsFactOnlyAndClearsStraySmartState() async {
        let mock = MockAssistantAPIClient()
        mock.studySmartModeSettingsResult = StudySmartModeSettings(enabled: false)
        mock.studyTodayViewResult = sampleStudyTodayView(tasks: [
            sampleStudyViewTaskJSON(
                id: 42,
                title: "Rolled task",
                targetMinutes: 30,
                projectTitle: "Lag Project",
                rolledDayCount: 4
            )
        ])
        mock.studyProjectOverviewResult = sampleStudyProjectOverview(activeProjects: [
            sampleStudyProjectSummaryJSON(
                id: 7,
                title: "Expected late",
                completedUnits: 1,
                totalUnits: 4,
                progressRatio: 0.25,
                status: "active",
                expectedLate: true
            )
        ])
        mock.studyCalendarLoadResult = sampleStudyCalendarLoad(
            start: "2026-06-01",
            end: "2026-06-07",
            dayJSON: """
            {
                "date": "2026-06-03",
                "scheduled_task_count": 3,
                "total_target_minutes": 180,
                "completed_task_count": 0,
                "available_capacity_minutes": 75,
                "over_capacity": true,
                "rest_day": false
            }
            """
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07")
        vm.studySmartProposalOptions = [sampleStudySmartProposalOption()]
        vm.studySmartProposalMessage = "stale smart proposal"

        await vm.fetchDashboard()

        XCTAssertEqual(vm.studyTodayView?.tasks.first?.rolledDayCount, 4)
        XCTAssertEqual(vm.studyProjectOverview?.activeProjects.first?.expectedLate, true)
        XCTAssertEqual(vm.studyCalendarLoad?.days.first?.overCapacity, true)
        XCTAssertEqual(mock.fetchStudySmartModeSettingsCallCount, 1)
        XCTAssertEqual(mock.fetchStudySmartMorningBriefingCallCount, 0)
        XCTAssertEqual(mock.generateStudySmartProposalsCallCount, 0)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
        XCTAssertEqual(mock.sendMessageCallCount, 0)
        XCTAssertEqual(mock.confirmChatCallCount, 0)
        XCTAssertNil(vm.studySmartMorningBriefing)
        XCTAssertTrue(vm.studySmartProposalOptions.isEmpty)
        XCTAssertNil(vm.studySmartProposalMessage)
        XCTAssertTrue(vm.chatMessages.isEmpty)
        XCTAssertNil(vm.currentProposal)
    }

    func testDisabledStudySmartModeRejectsStrayProposalApplyWithoutSmartOrLegacyCalls() async {
        let mock = MockAssistantAPIClient()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        let option = sampleStudySmartProposalOption()
        vm.isStudySmartModeEnabled = false
        vm.studySmartProposalOptions = [option]
        vm.studySmartProposalMessage = "stale smart proposal"
        vm.chatMessages = [ChatMessage(role: .assistant, text: "legacy")]
        vm.currentProposal = "legacy proposal"

        await vm.applyStudySmartProposal(option)

        XCTAssertEqual(mock.applyStudySmartProposalCallCount, 0)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 0)
        XCTAssertEqual(mock.fetchResourcesCallCount, 0)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 0)
        XCTAssertEqual(mock.sendMessageCallCount, 0)
        XCTAssertEqual(mock.confirmChatCallCount, 0)
        XCTAssertTrue(vm.studySmartProposalOptions.isEmpty)
        XCTAssertNil(vm.studySmartProposalMessage)
        XCTAssertEqual(vm.chatMessages.map(\.text), ["legacy"])
        XCTAssertEqual(vm.currentProposal, "legacy proposal")
    }

    func testDashboardEnabledSmartModeFetchesMorningBriefingAndStoresProposalOptions() async {
        let mock = MockAssistantAPIClient()
        mock.studySmartModeSettingsResult = StudySmartModeSettings(enabled: true)
        mock.studySmartMorningBriefingResult = sampleStudySmartMorningBriefing()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        vm.studySmartProposalMessage = "old proposal status"

        await vm.fetchDashboard()

        XCTAssertEqual(mock.fetchStudySmartModeSettingsCallCount, 1)
        XCTAssertEqual(mock.fetchStudySmartMorningBriefingCallCount, 1)
        XCTAssertEqual(mock.generateStudySmartProposalsCallCount, 0)
        XCTAssertEqual(mock.fetchBriefingCallCount, 0)
        XCTAssertEqual(mock.sendMessageCallCount, 0)
        XCTAssertEqual(mock.confirmChatCallCount, 0)
        XCTAssertTrue(vm.isStudySmartModeEnabled)
        XCTAssertEqual(vm.studySmartMorningBriefing?.summary, "One study-plan issue needs attention.")
        XCTAssertEqual(vm.studySmartProposalOptions.map(\.id), ["morning-extend-deadline-7"])
        XCTAssertNil(vm.studySmartProposalMessage)
        XCTAssertTrue(vm.chatMessages.isEmpty)
        XCTAssertNil(vm.currentProposal)
    }

    func testEnableStudySmartModeReportsBriefingFailureWithoutClearingPersistedEnabledState() async {
        let mock = MockAssistantAPIClient()
        mock.studySmartModeSettingsResult = StudySmartModeSettings(enabled: false)
        mock.studySmartMorningBriefingError = AssistantOfflineError()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.updateStudySmartModeSetting(true)

        XCTAssertEqual(mock.updateStudySmartModeSettingsCallCount, 1)
        XCTAssertEqual(mock.fetchStudySmartMorningBriefingCallCount, 1)
        XCTAssertTrue(vm.isStudySmartModeEnabled)
        XCTAssertTrue(vm.isOffline)
        XCTAssertNil(vm.studySmartMorningBriefing)
        XCTAssertTrue(vm.studySmartProposalOptions.isEmpty)
        XCTAssertEqual(vm.studySmartProposalMessage, "智能模式已开启，但晨间简报暂时无法加载。请稍后刷新。")
        XCTAssertEqual(vm.studySmartProposalMessageTrigger, .morning)
        XCTAssertNil(vm.studySmartSettingsMessage)
        XCTAssertEqual(
            StudySmartOptionsFilter.visibleMessage(
                vm.studySmartProposalMessage,
                messageTrigger: vm.studySmartProposalMessageTrigger,
                options: vm.studySmartProposalOptions,
                placement: .dashboard
            ),
            "智能模式已开启，但晨间简报暂时无法加载。请稍后刷新。"
        )
        XCTAssertNil(
            StudySmartOptionsFilter.visibleMessage(
                vm.studySmartProposalMessage,
                messageTrigger: vm.studySmartProposalMessageTrigger,
                options: vm.studySmartProposalOptions,
                placement: .adjustment
            )
        )
        XCTAssertEqual(mock.sendMessageCallCount, 0)
        XCTAssertEqual(mock.confirmChatCallCount, 0)
        XCTAssertTrue(vm.chatMessages.isEmpty)
        XCTAssertNil(vm.currentProposal)
    }

    func testStudySmartModeSettingFailureUsesSettingsMessageWithoutLegacyChatOrProposalMessage() async {
        let mock = MockAssistantAPIClient()
        mock.shouldThrowOffline = true
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        await vm.updateStudySmartModeSetting(true)

        XCTAssertEqual(mock.updateStudySmartModeSettingsCallCount, 1)
        XCTAssertEqual(mock.fetchStudySmartMorningBriefingCallCount, 0)
        XCTAssertNil(vm.studySmartProposalMessage)
        XCTAssertNil(vm.studySmartProposalMessageTrigger)
        XCTAssertEqual(vm.studySmartSettingsMessage, "智能模式设置更新失败，请稍后重试。")
        XCTAssertEqual(mock.sendMessageCallCount, 0)
        XCTAssertEqual(mock.confirmChatCallCount, 0)
        XCTAssertTrue(vm.chatMessages.isEmpty)
        XCTAssertNil(vm.currentProposal)
    }

    func testStudySmartModeSettingUpdateUsesLatestUserIntentWhenRequestsCompleteOutOfOrder() async {
        let mock = MockAssistantAPIClient()
        mock.studySmartModeSettingsUpdateResultsQueue = [
            DelayedStudySmartModeSettingsUpdateResult(
                settings: StudySmartModeSettings(enabled: true),
                delayNanoseconds: 100_000_000
            ),
            DelayedStudySmartModeSettingsUpdateResult(
                settings: StudySmartModeSettings(enabled: false),
                delayNanoseconds: 0
            )
        ]
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)

        let enable = Task {
            await vm.updateStudySmartModeSetting(true)
        }
        await mock.waitForStudySmartModeSettingsUpdateCallCount(1)
        let disable = Task {
            await vm.updateStudySmartModeSetting(false)
        }

        await enable.value
        await disable.value

        XCTAssertEqual(mock.updateStudySmartModeSettingsCallCount, 2)
        XCTAssertEqual(mock.lastUpdatedStudySmartModeSettings?.enabled, false)
        XCTAssertFalse(vm.isStudySmartModeEnabled)
        XCTAssertNil(vm.studySmartMorningBriefing)
        XCTAssertTrue(vm.studySmartProposalOptions.isEmpty)
        XCTAssertNil(vm.studySmartProposalMessage)
    }

    func testIgnoreStudySmartProposalsClearsOptionsWithoutMutationOrLegacyChat() async {
        let mock = MockAssistantAPIClient()
        mock.studySmartModeSettingsResult = StudySmartModeSettings(enabled: true)
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchDashboard()

        vm.ignoreStudySmartProposals()

        XCTAssertTrue(vm.studySmartProposalOptions.isEmpty)
        XCTAssertEqual(mock.applyStudySmartProposalCallCount, 0)
        XCTAssertEqual(mock.sendMessageCallCount, 0)
        XCTAssertEqual(mock.confirmChatCallCount, 0)
        XCTAssertTrue(vm.chatMessages.isEmpty)
        XCTAssertNil(vm.currentProposal)
    }

    func testApplySelectedStudySmartProposalUsesSelectedOptionAndRefreshesFactsAndLoadedCalendar() async {
        let mock = MockAssistantAPIClient()
        mock.studySmartModeSettingsResult = StudySmartModeSettings(enabled: true)
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchDashboard()
        await vm.fetchStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07")
        let option = try! XCTUnwrap(vm.studySmartProposalOptions.first)

        await vm.applyStudySmartProposal(option)

        XCTAssertEqual(mock.applyStudySmartProposalCallCount, 1)
        XCTAssertEqual(mock.lastStudySmartProposalApplyRequest?.proposal.id, option.id)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 2)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 2)
        XCTAssertEqual(mock.fetchResourcesCallCount, 2)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 2)
        XCTAssertTrue(vm.studySmartProposalOptions.isEmpty)
        XCTAssertEqual(vm.studySmartProposalMessage, "智能建议已应用。")
        XCTAssertEqual(mock.sendMessageCallCount, 0)
        XCTAssertEqual(mock.confirmChatCallCount, 0)
        XCTAssertTrue(vm.chatMessages.isEmpty)
        XCTAssertNil(vm.currentProposal)
    }

    func testApplyStudySmartProposalDashboardRefreshFailureDoesNotProceedToCalendarOrMaskOffline() async {
        let mock = MockAssistantAPIClient()
        mock.studySmartModeSettingsResult = StudySmartModeSettings(enabled: true)
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchDashboard()
        await vm.fetchStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07")
        let calendarCallsBeforeApply = mock.fetchStudyCalendarLoadCallCount
        let option = try! XCTUnwrap(vm.studySmartProposalOptions.first)
        mock.shouldThrowResources = true

        await vm.applyStudySmartProposal(option)

        XCTAssertEqual(mock.applyStudySmartProposalCallCount, 1)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 2)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 2)
        XCTAssertEqual(mock.fetchResourcesCallCount, 2)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, calendarCallsBeforeApply)
        XCTAssertTrue(vm.isOffline)
        XCTAssertEqual(vm.studyViewError, "学习视图刷新失败，请稍后重试。")
    }

    func testStaleStudySmartProposalApplyClearsOptionsWithoutRefreshingOrMutatingLegacyChat() async {
        let mock = MockAssistantAPIClient()
        mock.studySmartProposalApplyResult = StudySmartProposalApplyResult(
            status: "stale_proposal",
            source: "smart_mode_apply",
            proposalId: "morning-extend-deadline-7",
            signature: "abc123",
            trigger: .morning,
            command: nil,
            affectedProjectIds: nil,
            affectedTaskIds: nil,
            appliedChanges: nil,
            mutates: false,
            refresh: StudyRefreshContract(today: true, projectOverview: true, calendar: true),
            message: nil
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        let option = sampleStudySmartProposalOption()
        vm.isStudySmartModeEnabled = true
        vm.studySmartProposalOptions = [option]

        await vm.applyStudySmartProposal(option)

        XCTAssertEqual(mock.applyStudySmartProposalCallCount, 1)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 0)
        XCTAssertEqual(mock.fetchResourcesCallCount, 0)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 0)
        XCTAssertTrue(vm.studySmartProposalOptions.isEmpty)
        XCTAssertEqual(vm.studySmartProposalMessage, "智能建议已过期，请刷新后重试。")
        XCTAssertTrue(vm.chatMessages.isEmpty)
        XCTAssertNil(vm.currentProposal)
    }

    func testApplyRejectsCapturedStudySmartProposalWhenSameIdSignatureChanged() async {
        let mock = MockAssistantAPIClient()
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        let currentOption = sampleStudySmartProposalOption(signature: "new-signature")
        let capturedStaleOption = sampleStudySmartProposalOption(signature: "old-signature")
        vm.isStudySmartModeEnabled = true
        vm.studySmartProposalOptions = [currentOption]
        vm.chatMessages = [ChatMessage(role: .assistant, text: "legacy")]
        vm.currentProposal = "legacy proposal"

        await vm.applyStudySmartProposal(capturedStaleOption)

        XCTAssertEqual(mock.applyStudySmartProposalCallCount, 0)
        XCTAssertEqual(mock.fetchStudyTodayViewCallCount, 0)
        XCTAssertEqual(mock.fetchStudyProjectOverviewCallCount, 0)
        XCTAssertEqual(mock.fetchResourcesCallCount, 0)
        XCTAssertEqual(mock.fetchStudyCalendarLoadCallCount, 0)
        XCTAssertEqual(vm.studySmartProposalOptions.map(\.signature), ["new-signature"])
        XCTAssertEqual(vm.studySmartProposalMessage, "智能建议已过期，请刷新后重试。")
        XCTAssertEqual(
            StudySmartOptionsFilter.visibleMessage(
                vm.studySmartProposalMessage,
                options: vm.studySmartProposalOptions,
                placement: .dashboard
            ),
            "智能建议已过期，请刷新后重试。"
        )
        XCTAssertNil(
            StudySmartOptionsFilter.visibleMessage(
                vm.studySmartProposalMessage,
                options: vm.studySmartProposalOptions,
                placement: .adjustment
            )
        )
        XCTAssertEqual(mock.sendMessageCallCount, 0)
        XCTAssertEqual(mock.confirmChatCallCount, 0)
        XCTAssertEqual(vm.chatMessages.map(\.text), ["legacy"])
        XCTAssertEqual(vm.currentProposal, "legacy proposal")
    }

    func testManualAdjustmentCreatesExpectedLateOrOverCapacityRedStateGeneratesAfterAdjustmentProposals() async {
        let mock = MockAssistantAPIClient()
        mock.studySmartModeSettingsResult = StudySmartModeSettings(enabled: true)
        mock.studyProjectOverviewResult = sampleStudyProjectOverview(activeProjects: [
            sampleStudyProjectSummaryJSON(
                id: 7,
                title: "Before",
                completedUnits: 1,
                totalUnits: 4,
                progressRatio: 0.25,
                status: "active",
                expectedLate: false
            )
        ])
        mock.studyCalendarLoadResult = sampleStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07")
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchDashboard()
        await vm.fetchStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07")
        mock.studyProjectOverviewResult = sampleStudyProjectOverview(activeProjects: [
            sampleStudyProjectSummaryJSON(
                id: 7,
                title: "After",
                completedUnits: 1,
                totalUnits: 4,
                progressRatio: 0.25,
                status: "active",
                expectedLate: true
            )
        ])
        mock.studyCalendarLoadResult = sampleStudyCalendarLoad(
            start: "2026-06-01",
            end: "2026-06-07",
            dayJSON: """
            {
                "date": "2026-06-03",
                "scheduled_task_count": 3,
                "total_target_minutes": 180,
                "completed_task_count": 0,
                "available_capacity_minutes": 75,
                "over_capacity": true,
                "rest_day": false
            }
            """
        )
        mock.studySmartProposalGenerationResult = StudySmartProposalGenerationResponse(
            enabled: true,
            trigger: .afterAdjustment,
            options: [sampleStudySmartProposalOption(trigger: .afterAdjustment)],
            message: nil
        )

        await vm.moveStudyTask(id: 42, scheduledDate: "2026-06-03")

        XCTAssertEqual(mock.generateStudySmartProposalsCallCount, 1)
        XCTAssertEqual(mock.lastStudySmartProposalGenerationRequest?.trigger, .afterAdjustment)
        XCTAssertEqual(mock.lastStudySmartProposalGenerationRequest?.previousExpectedLateProjectIds, [])
        XCTAssertEqual(mock.lastStudySmartProposalGenerationRequest?.previousOverCapacityDates, [])
        XCTAssertEqual(vm.studySmartProposalOptions.map(\.trigger), [.afterAdjustment])
        XCTAssertEqual(mock.sendMessageCallCount, 0)
        XCTAssertEqual(mock.confirmChatCallCount, 0)
        XCTAssertTrue(vm.chatMessages.isEmpty)
        XCTAssertNil(vm.currentProposal)
    }

    func testAfterAdjustmentGeneratedProposalApplyIncludesGenerationRedStateContext() async {
        let mock = MockAssistantAPIClient()
        mock.studySmartModeSettingsResult = StudySmartModeSettings(enabled: true)
        mock.studyProjectOverviewResult = sampleStudyProjectOverview(activeProjects: [
            sampleStudyProjectSummaryJSON(
                id: 7,
                title: "Already Late",
                completedUnits: 1,
                totalUnits: 4,
                progressRatio: 0.25,
                status: "active",
                expectedLate: true
            ),
            sampleStudyProjectSummaryJSON(
                id: 8,
                title: "Before",
                completedUnits: 1,
                totalUnits: 4,
                progressRatio: 0.25,
                status: "active",
                expectedLate: false
            )
        ])
        mock.studyCalendarLoadResult = sampleStudyCalendarLoad(
            start: "2026-06-01",
            end: "2026-06-07",
            dayJSON: """
            {
                "date": "2026-06-02",
                "scheduled_task_count": 3,
                "total_target_minutes": 180,
                "completed_task_count": 0,
                "available_capacity_minutes": 75,
                "over_capacity": true,
                "rest_day": false
            }
            """
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchDashboard()
        await vm.fetchStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07")
        mock.studyProjectOverviewResult = sampleStudyProjectOverview(activeProjects: [
            sampleStudyProjectSummaryJSON(
                id: 7,
                title: "Already Late",
                completedUnits: 1,
                totalUnits: 4,
                progressRatio: 0.25,
                status: "active",
                expectedLate: true
            ),
            sampleStudyProjectSummaryJSON(
                id: 8,
                title: "Newly Late",
                completedUnits: 1,
                totalUnits: 4,
                progressRatio: 0.25,
                status: "active",
                expectedLate: true
            )
        ])
        mock.studyCalendarLoadResult = sampleStudyCalendarLoad(
            start: "2026-06-01",
            end: "2026-06-07",
            dayJSON: """
            {
                "date": "2026-06-03",
                "scheduled_task_count": 3,
                "total_target_minutes": 180,
                "completed_task_count": 0,
                "available_capacity_minutes": 75,
                "over_capacity": true,
                "rest_day": false
            }
            """
        )
        mock.studySmartProposalGenerationResult = StudySmartProposalGenerationResponse(
            enabled: true,
            trigger: .afterAdjustment,
            options: [sampleStudySmartProposalOption(trigger: .afterAdjustment)],
            message: nil
        )
        await vm.moveStudyTask(id: 42, scheduledDate: "2026-06-03")
        let option = try! XCTUnwrap(vm.studySmartProposalOptions.first)

        await vm.applyStudySmartProposal(option)

        XCTAssertEqual(mock.lastStudySmartProposalGenerationRequest?.previousExpectedLateProjectIds, [7])
        XCTAssertEqual(mock.lastStudySmartProposalGenerationRequest?.previousOverCapacityDates, ["2026-06-02"])
        XCTAssertEqual(mock.lastStudySmartProposalApplyRequest?.proposal.id, option.id)
        XCTAssertEqual(mock.lastStudySmartProposalApplyRequest?.previousExpectedLateProjectIds, [7])
        XCTAssertEqual(mock.lastStudySmartProposalApplyRequest?.previousOverCapacityDates, ["2026-06-02"])
        XCTAssertEqual(mock.sendMessageCallCount, 0)
        XCTAssertEqual(mock.confirmChatCallCount, 0)
    }

    func testSubsequentNonRedAdjustmentClearsAfterAdjustmentContextAndRejectsOldOptionApply() async {
        let mock = MockAssistantAPIClient()
        mock.studySmartModeSettingsResult = StudySmartModeSettings(enabled: true)
        mock.studyProjectOverviewResult = sampleStudyProjectOverview(activeProjects: [
            sampleStudyProjectSummaryJSON(
                id: 7,
                title: "Already Late",
                completedUnits: 1,
                totalUnits: 4,
                progressRatio: 0.25,
                status: "active",
                expectedLate: true
            ),
            sampleStudyProjectSummaryJSON(
                id: 8,
                title: "Before",
                completedUnits: 1,
                totalUnits: 4,
                progressRatio: 0.25,
                status: "active",
                expectedLate: false
            )
        ])
        mock.studyCalendarLoadResult = sampleStudyCalendarLoad(
            start: "2026-06-01",
            end: "2026-06-07",
            dayJSON: """
            {
                "date": "2026-06-02",
                "scheduled_task_count": 3,
                "total_target_minutes": 180,
                "completed_task_count": 0,
                "available_capacity_minutes": 75,
                "over_capacity": true,
                "rest_day": false
            }
            """
        )
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchDashboard()
        await vm.fetchStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07")
        mock.studyProjectOverviewResult = sampleStudyProjectOverview(activeProjects: [
            sampleStudyProjectSummaryJSON(
                id: 7,
                title: "Already Late",
                completedUnits: 1,
                totalUnits: 4,
                progressRatio: 0.25,
                status: "active",
                expectedLate: true
            ),
            sampleStudyProjectSummaryJSON(
                id: 8,
                title: "Newly Late",
                completedUnits: 1,
                totalUnits: 4,
                progressRatio: 0.25,
                status: "active",
                expectedLate: true
            )
        ])
        mock.studySmartProposalGenerationResult = StudySmartProposalGenerationResponse(
            enabled: true,
            trigger: .afterAdjustment,
            options: [sampleStudySmartProposalOption(trigger: .afterAdjustment)],
            message: nil
        )
        await vm.moveStudyTask(id: 42, scheduledDate: "2026-06-03")
        let oldOption = try! XCTUnwrap(vm.studySmartProposalOptions.first)

        mock.studyProjectOverviewResult = sampleStudyProjectOverview(activeProjects: [
            sampleStudyProjectSummaryJSON(
                id: 7,
                title: "Still Late",
                completedUnits: 1,
                totalUnits: 4,
                progressRatio: 0.25,
                status: "active",
                expectedLate: true
            ),
            sampleStudyProjectSummaryJSON(
                id: 8,
                title: "Still Late",
                completedUnits: 1,
                totalUnits: 4,
                progressRatio: 0.25,
                status: "active",
                expectedLate: true
            )
        ])
        mock.studyCalendarLoadResult = sampleStudyCalendarLoad(
            start: "2026-06-01",
            end: "2026-06-07",
            dayJSON: """
            {
                "date": "2026-06-02",
                "scheduled_task_count": 3,
                "total_target_minutes": 180,
                "completed_task_count": 0,
                "available_capacity_minutes": 75,
                "over_capacity": true,
                "rest_day": false
            }
            """
        )

        await vm.moveStudyTask(id: 42, scheduledDate: "2026-06-04")
        await vm.applyStudySmartProposal(oldOption)

        XCTAssertTrue(vm.studySmartProposalOptions.isEmpty)
        XCTAssertEqual(mock.generateStudySmartProposalsCallCount, 1)
        XCTAssertEqual(mock.applyStudySmartProposalCallCount, 0)
        XCTAssertNil(mock.lastStudySmartProposalApplyRequest)
    }

    func testManualAdjustmentFactsRefreshFailureDoesNotGenerateAfterAdjustmentProposalsOrMaskOffline() async {
        let mock = MockAssistantAPIClient()
        mock.studySmartModeSettingsResult = StudySmartModeSettings(enabled: true)
        mock.studyProjectOverviewResult = sampleStudyProjectOverview(activeProjects: [
            sampleStudyProjectSummaryJSON(
                id: 7,
                title: "Before",
                completedUnits: 1,
                totalUnits: 4,
                progressRatio: 0.25,
                status: "active",
                expectedLate: false
            )
        ])
        mock.studyCalendarLoadResult = sampleStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07")
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchDashboard()
        await vm.fetchStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07")
        mock.shouldThrowResources = true
        mock.studyProjectOverviewResult = sampleStudyProjectOverview(activeProjects: [
            sampleStudyProjectSummaryJSON(
                id: 7,
                title: "After",
                completedUnits: 1,
                totalUnits: 4,
                progressRatio: 0.25,
                status: "active",
                expectedLate: true
            )
        ])
        mock.studyCalendarLoadResult = sampleStudyCalendarLoad(
            start: "2026-06-01",
            end: "2026-06-07",
            dayJSON: """
            {
                "date": "2026-06-03",
                "scheduled_task_count": 3,
                "total_target_minutes": 180,
                "completed_task_count": 0,
                "available_capacity_minutes": 75,
                "over_capacity": true,
                "rest_day": false
            }
            """
        )

        await vm.moveStudyTask(id: 42, scheduledDate: "2026-06-03")

        XCTAssertEqual(mock.generateStudySmartProposalsCallCount, 0)
        XCTAssertTrue(vm.studySmartProposalOptions.isEmpty)
        XCTAssertTrue(vm.isOffline)
        XCTAssertEqual(vm.studyViewError, "学习视图刷新失败，请稍后重试。")
    }

    func testManualAdjustmentWithLagOnlyDoesNotGenerateAfterAdjustmentProposals() async {
        let mock = MockAssistantAPIClient()
        mock.studySmartModeSettingsResult = StudySmartModeSettings(enabled: true)
        mock.studyTodayViewResult = sampleStudyTodayView(tasks: [
            sampleStudyViewTaskJSON(
                id: 42,
                title: "Lag only",
                targetMinutes: 30,
                projectTitle: "Lag Project",
                rolledDayCount: 4
            )
        ])
        mock.studyProjectOverviewResult = sampleStudyProjectOverview(activeProjects: [
            sampleStudyProjectSummaryJSON(
                id: 7,
                title: "On Track",
                completedUnits: 1,
                totalUnits: 4,
                progressRatio: 0.25,
                status: "active",
                expectedLate: false
            )
        ])
        mock.studyCalendarLoadResult = sampleStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07")
        let vm = LearningAssistantViewModel(api: mock, autoLoadWhenReady: false)
        await vm.fetchDashboard()
        await vm.fetchStudyCalendarLoad(start: "2026-06-01", end: "2026-06-07")

        await vm.moveStudyTask(id: 42, scheduledDate: "2026-06-04")

        XCTAssertEqual(mock.generateStudySmartProposalsCallCount, 0)
        XCTAssertTrue(vm.studySmartProposalOptions.isEmpty)
        XCTAssertEqual(mock.sendMessageCallCount, 0)
        XCTAssertEqual(mock.confirmChatCallCount, 0)
        XCTAssertTrue(vm.chatMessages.isEmpty)
        XCTAssertNil(vm.currentProposal)
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

private struct DelayedAddInitiateSessionResult {
    let session: AddInitiateSessionResponse
    let delayNanoseconds: UInt64
}

private struct DelayedStudySmartModeSettingsUpdateResult {
    let settings: StudySmartModeSettings
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
    var studySmartModeSettingsResult = StudySmartModeSettings(enabled: false)
    var studySmartMorningBriefingResult = sampleStudySmartMorningBriefing()
    var studySmartProposalGenerationResult = sampleStudySmartProposalGenerationResponse()
    var studySmartProposalApplyResult = sampleStudySmartProposalApplyResult()
    var studySmartMorningBriefingError: Error?
    var studySmartModeSettingsUpdateResultsQueue: [DelayedStudySmartModeSettingsUpdateResult] = []
    var studyDialogueAdjustmentPreviewResult = sampleStudyDialogueAdjustmentPreview()
    var studyDialogueAdjustmentApplyResult = sampleStudyDialogueAdjustmentApplyResult()
    var addInitiateStartResult = sampleAddInitiateRoleReviewSession()
    var addInitiateStartDelayNanoseconds: UInt64 = 0
    var addInitiateStartResultsQueue: [DelayedAddInitiateSessionResult] = []
    var addInitiateRoleResult = sampleAddInitiateMaterialAttachedSession()
    var addInitiateRoleResultsQueue: [AddInitiateSessionResponse] = []
    var addInitiateRoleDelayNanoseconds: UInt64 = 0
    var addInitiateRoleError: Error?
    var addInitiateAnchorResult = sampleAddInitiateDraftReviewSession()
    var addInitiateAnchorResultsQueue: [DelayedAddInitiateSessionResult] = []
    var addInitiateAnchorDelayNanoseconds: UInt64 = 0
    var addInitiateAnchorError: Error?
    var addInitiateOptionResult = sampleAddInitiateDraftReviewSession()
    var addInitiateOptionDelayNanoseconds: UInt64 = 0
    var addInitiateOptionError: Error?
    var addInitiateActivationResult = sampleAddInitiateActivationFailedSession()
    var addInitiateActivationError: Error?
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
    private(set) var fetchStudySmartModeSettingsCallCount = 0
    private(set) var updateStudySmartModeSettingsCallCount = 0
    private(set) var lastUpdatedStudySmartModeSettings: StudySmartModeSettings?
    private(set) var fetchStudySmartMorningBriefingCallCount = 0
    private(set) var generateStudySmartProposalsCallCount = 0
    private(set) var lastStudySmartProposalGenerationRequest: StudySmartProposalGenerationRequest?
    private(set) var applyStudySmartProposalCallCount = 0
    private(set) var lastStudySmartProposalApplyRequest: StudySmartProposalApplyRequest?
    private(set) var previewStudyDialogueAdjustmentCallCount = 0
    private(set) var lastStudyDialoguePreviewInstruction: String?
    private(set) var lastStudyDialoguePreviewProjectId: Int?
    private(set) var applyStudyDialogueAdjustmentCallCount = 0
    private(set) var lastStudyDialogueApplyInstruction: String?
    private(set) var lastStudyDialogueApplyProjectId: Int?
    private(set) var lastStudyDialogueApplyPreview: StudyDialogueAdjustmentPreview?
    private(set) var startAddInitiateSessionCallCount = 0
    private(set) var lastAddInitiateStartRequest: AddInitiateStartSessionRequest?
    private(set) var confirmAddInitiateRoleCallCount = 0
    private(set) var lastAddInitiateRoleRequest: AddInitiateRoleConfirmationRequest?
    private(set) var confirmAddInitiateAnchorCallCount = 0
    private(set) var lastAddInitiateAnchorRequest: AddInitiateAnchorConfirmationRequest?
    private(set) var applyAddInitiateOptionEffectCallCount = 0
    private(set) var lastAddInitiateOptionRequest: AddInitiateOptionEffectRequest?
    private(set) var activateAddInitiateDraftCallCount = 0
    private(set) var lastAddInitiateActivationRequest: AddInitiateActivationRequest?
    private(set) var lastStudyCalendarLoadStart: String?
    private(set) var lastStudyCalendarLoadEnd: String?
    private(set) var lastCompleteResourceId: Int?
    private(set) var lastArchiveResourceId: Int?
    private(set) var completeResourceCallCount = 0
    private(set) var archiveResourceCallCount = 0
    private(set) var sendMessageCallCount = 0
    private(set) var confirmChatCallCount = 0
    private(set) var lastConfirmChatConfirmed: Bool?
    private(set) var startIngestionCallCount = 0
    private(set) var lastStartIngestionURL: String?
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
    private let studySmartModeSettingsUpdateGateLock = NSLock()
    private var studySmartModeSettingsUpdateCallCountContinuations: [(expected: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private let addInitiateStartGateLock = NSLock()
    private var addInitiateStartCallCountContinuations: [(expected: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private let addInitiateRoleGateLock = NSLock()
    private var addInitiateRoleCallCountContinuations: [(expected: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private let addInitiateAnchorGateLock = NSLock()
    private var addInitiateAnchorCallCountContinuations: [(expected: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private let addInitiateOptionGateLock = NSLock()
    private var addInitiateOptionCallCountContinuations: [(expected: Int, continuation: CheckedContinuation<Void, Never>)] = []

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

    func waitForStudySmartModeSettingsUpdateCallCount(_ expected: Int) async {
        await withCheckedContinuation { continuation in
            let shouldResumeImmediately = withStudySmartModeSettingsUpdateGateLock {
                if updateStudySmartModeSettingsCallCount >= expected {
                    return true
                }
                studySmartModeSettingsUpdateCallCountContinuations.append((expected, continuation))
                return false
            }
            if shouldResumeImmediately {
                continuation.resume()
            }
        }
    }

    func waitForAddInitiateRoleCallCount(_ expected: Int) async {
        await withCheckedContinuation { continuation in
            let shouldResumeImmediately = withAddInitiateRoleGateLock {
                if confirmAddInitiateRoleCallCount >= expected {
                    return true
                }
                addInitiateRoleCallCountContinuations.append((expected, continuation))
                return false
            }
            if shouldResumeImmediately {
                continuation.resume()
            }
        }
    }

    func waitForAddInitiateStartCallCount(_ expected: Int) async {
        await withCheckedContinuation { continuation in
            let shouldResumeImmediately = withAddInitiateStartGateLock {
                if startAddInitiateSessionCallCount >= expected {
                    return true
                }
                addInitiateStartCallCountContinuations.append((expected, continuation))
                return false
            }
            if shouldResumeImmediately {
                continuation.resume()
            }
        }
    }

    func waitForAddInitiateAnchorCallCount(_ expected: Int) async {
        await withCheckedContinuation { continuation in
            let shouldResumeImmediately = withAddInitiateAnchorGateLock {
                if confirmAddInitiateAnchorCallCount >= expected {
                    return true
                }
                addInitiateAnchorCallCountContinuations.append((expected, continuation))
                return false
            }
            if shouldResumeImmediately {
                continuation.resume()
            }
        }
    }

    func waitForAddInitiateOptionCallCount(_ expected: Int) async {
        await withCheckedContinuation { continuation in
            let shouldResumeImmediately = withAddInitiateOptionGateLock {
                if applyAddInitiateOptionEffectCallCount >= expected {
                    return true
                }
                addInitiateOptionCallCountContinuations.append((expected, continuation))
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

    func fetchStudySmartModeSettings() async throws -> StudySmartModeSettings {
        fetchStudySmartModeSettingsCallCount += 1
        if let adjustmentError { throw adjustmentError }
        if shouldThrowOffline { throw AssistantOfflineError() }
        return studySmartModeSettingsResult
    }

    func updateStudySmartModeSettings(_ settings: StudySmartModeSettings) async throws -> StudySmartModeSettings {
        updateStudySmartModeSettingsCallCount += 1
        lastUpdatedStudySmartModeSettings = settings
        signalStudySmartModeSettingsUpdateCallCountChanged()
        if let adjustmentError { throw adjustmentError }
        if shouldThrowOffline { throw AssistantOfflineError() }
        if !studySmartModeSettingsUpdateResultsQueue.isEmpty {
            let result = studySmartModeSettingsUpdateResultsQueue.removeFirst()
            if result.delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: result.delayNanoseconds)
            }
            studySmartModeSettingsResult = result.settings
            return studySmartModeSettingsResult
        }
        studySmartModeSettingsResult = settings
        return studySmartModeSettingsResult
    }

    func fetchStudySmartMorningBriefing() async throws -> StudySmartMorningBriefing {
        fetchStudySmartMorningBriefingCallCount += 1
        if let adjustmentError { throw adjustmentError }
        if let studySmartMorningBriefingError { throw studySmartMorningBriefingError }
        if shouldThrowOffline { throw AssistantOfflineError() }
        return studySmartMorningBriefingResult
    }

    func generateStudySmartProposals(
        _ request: StudySmartProposalGenerationRequest
    ) async throws -> StudySmartProposalGenerationResponse {
        generateStudySmartProposalsCallCount += 1
        lastStudySmartProposalGenerationRequest = request
        if let adjustmentError { throw adjustmentError }
        if shouldThrowOffline { throw AssistantOfflineError() }
        return studySmartProposalGenerationResult
    }

    func applyStudySmartProposal(
        _ request: StudySmartProposalApplyRequest
    ) async throws -> StudySmartProposalApplyResult {
        applyStudySmartProposalCallCount += 1
        lastStudySmartProposalApplyRequest = request
        if let adjustmentError { throw adjustmentError }
        if shouldThrowOffline { throw AssistantOfflineError() }
        return studySmartProposalApplyResult
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
        startIngestionCallCount += 1
        lastStartIngestionURL = url
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

    func startAddInitiateSession(
        _ request: AddInitiateStartSessionRequest
    ) async throws -> AddInitiateSessionResponse {
        startAddInitiateSessionCallCount += 1
        lastAddInitiateStartRequest = request
        signalAddInitiateStartCallCountChanged()
        if shouldThrowOffline { throw AssistantOfflineError() }
        if !addInitiateStartResultsQueue.isEmpty {
            let delayed = addInitiateStartResultsQueue.removeFirst()
            if delayed.delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayed.delayNanoseconds)
            }
            return delayed.session
        }
        if addInitiateStartDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: addInitiateStartDelayNanoseconds)
        }
        return addInitiateStartResult
    }

    func confirmAddInitiateRole(
        _ request: AddInitiateRoleConfirmationRequest
    ) async throws -> AddInitiateSessionResponse {
        confirmAddInitiateRoleCallCount += 1
        lastAddInitiateRoleRequest = request
        signalAddInitiateRoleCallCountChanged()
        if addInitiateRoleDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: addInitiateRoleDelayNanoseconds)
        }
        if let addInitiateRoleError { throw addInitiateRoleError }
        if shouldThrowOffline { throw AssistantOfflineError() }
        if !addInitiateRoleResultsQueue.isEmpty {
            return addInitiateRoleResultsQueue.removeFirst()
        }
        return addInitiateRoleResult
    }

    func confirmAddInitiateAnchors(
        _ request: AddInitiateAnchorConfirmationRequest
    ) async throws -> AddInitiateSessionResponse {
        confirmAddInitiateAnchorCallCount += 1
        lastAddInitiateAnchorRequest = request
        signalAddInitiateAnchorCallCountChanged()
        if addInitiateAnchorDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: addInitiateAnchorDelayNanoseconds)
        }
        if let addInitiateAnchorError { throw addInitiateAnchorError }
        if shouldThrowOffline { throw AssistantOfflineError() }
        if !addInitiateAnchorResultsQueue.isEmpty {
            let delayed = addInitiateAnchorResultsQueue.removeFirst()
            if delayed.delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayed.delayNanoseconds)
            }
            return delayed.session
        }
        return addInitiateAnchorResult
    }

    func applyAddInitiateOptionEffect(
        _ request: AddInitiateOptionEffectRequest
    ) async throws -> AddInitiateSessionResponse {
        applyAddInitiateOptionEffectCallCount += 1
        lastAddInitiateOptionRequest = request
        signalAddInitiateOptionCallCountChanged()
        if addInitiateOptionDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: addInitiateOptionDelayNanoseconds)
        }
        if let addInitiateOptionError { throw addInitiateOptionError }
        if shouldThrowOffline { throw AssistantOfflineError() }
        return addInitiateOptionResult
    }

    func activateAddInitiateDraft(
        _ request: AddInitiateActivationRequest
    ) async throws -> AddInitiateSessionResponse {
        activateAddInitiateDraftCallCount += 1
        lastAddInitiateActivationRequest = request
        if let addInitiateActivationError { throw addInitiateActivationError }
        if shouldThrowOffline { throw AssistantOfflineError() }
        return addInitiateActivationResult
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

    private func signalStudySmartModeSettingsUpdateCallCountChanged() {
        let continuations = withStudySmartModeSettingsUpdateGateLock {
            var ready: [CheckedContinuation<Void, Never>] = []
            studySmartModeSettingsUpdateCallCountContinuations.removeAll { waiter in
                if updateStudySmartModeSettingsCallCount >= waiter.expected {
                    ready.append(waiter.continuation)
                    return true
                }
                return false
            }
            return ready
        }
        continuations.forEach { $0.resume() }
    }

    private func withStudySmartModeSettingsUpdateGateLock<T>(_ body: () -> T) -> T {
        studySmartModeSettingsUpdateGateLock.lock()
        defer { studySmartModeSettingsUpdateGateLock.unlock() }
        return body()
    }

    private func signalAddInitiateStartCallCountChanged() {
        let continuations = withAddInitiateStartGateLock {
            var ready: [CheckedContinuation<Void, Never>] = []
            addInitiateStartCallCountContinuations.removeAll { waiter in
                if startAddInitiateSessionCallCount >= waiter.expected {
                    ready.append(waiter.continuation)
                    return true
                }
                return false
            }
            return ready
        }
        continuations.forEach { $0.resume() }
    }

    private func withAddInitiateStartGateLock<T>(_ body: () -> T) -> T {
        addInitiateStartGateLock.lock()
        defer { addInitiateStartGateLock.unlock() }
        return body()
    }

    private func signalAddInitiateRoleCallCountChanged() {
        let continuations = withAddInitiateRoleGateLock {
            var ready: [CheckedContinuation<Void, Never>] = []
            addInitiateRoleCallCountContinuations.removeAll { waiter in
                if confirmAddInitiateRoleCallCount >= waiter.expected {
                    ready.append(waiter.continuation)
                    return true
                }
                return false
            }
            return ready
        }
        continuations.forEach { $0.resume() }
    }

    private func withAddInitiateRoleGateLock<T>(_ body: () -> T) -> T {
        addInitiateRoleGateLock.lock()
        defer { addInitiateRoleGateLock.unlock() }
        return body()
    }

    private func signalAddInitiateAnchorCallCountChanged() {
        let continuations = withAddInitiateAnchorGateLock {
            var ready: [CheckedContinuation<Void, Never>] = []
            addInitiateAnchorCallCountContinuations.removeAll { waiter in
                if confirmAddInitiateAnchorCallCount >= waiter.expected {
                    ready.append(waiter.continuation)
                    return true
                }
                return false
            }
            return ready
        }
        continuations.forEach { $0.resume() }
    }

    private func withAddInitiateAnchorGateLock<T>(_ body: () -> T) -> T {
        addInitiateAnchorGateLock.lock()
        defer { addInitiateAnchorGateLock.unlock() }
        return body()
    }

    private func signalAddInitiateOptionCallCountChanged() {
        let continuations = withAddInitiateOptionGateLock {
            var ready: [CheckedContinuation<Void, Never>] = []
            addInitiateOptionCallCountContinuations.removeAll { waiter in
                if applyAddInitiateOptionEffectCallCount >= waiter.expected {
                    ready.append(waiter.continuation)
                    return true
                }
                return false
            }
            return ready
        }
        continuations.forEach { $0.resume() }
    }

    private func withAddInitiateOptionGateLock<T>(_ body: () -> T) -> T {
        addInitiateOptionGateLock.lock()
        defer { addInitiateOptionGateLock.unlock() }
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

private func sampleAddInitiateRoleReviewSession(
    sessionId: String = "add-initiate-1",
    clientRequestId: String = "req-add-1",
    intakeItemId: Int = 11,
    recommendedRole: String? = "attach_to_existing_plan"
) -> AddInitiateSessionResponse {
    AddInitiateSessionResponse(
        sessionId: sessionId,
        clientRequestId: clientRequestId,
        intakeItemId: intakeItemId,
        draftId: nil,
        draftVersion: nil,
        stage: .roleReview,
        reviewState: .roleReview,
        recommendedRole: recommendedRole,
        confirmedRole: nil,
        confidence: "high",
        reasonCodes: ["existing_project_context", "source_material"],
        nextAction: "role_review",
        createsActiveTasks: false,
        resourceId: nil,
        error: nil,
        clarificationQuestion: nil,
        existingPlanCandidates: [
            ["id": AnyCodable(7), "title": AnyCodable("MalDaze")]
        ],
        attachmentModeSuggestion: "material_only",
        canonicalRepoRole: nil,
        reviewPackage: nil,
        activationResult: nil
    )
}

private func sampleAddInitiateMaterialAttachedSession() -> AddInitiateSessionResponse {
    AddInitiateSessionResponse(
        sessionId: "add-initiate-1",
        clientRequestId: "req-add-1",
        intakeItemId: 11,
        draftId: nil,
        draftVersion: nil,
        stage: .materialAttached,
        reviewState: .materialAttached,
        recommendedRole: "attach_to_existing_plan",
        confirmedRole: "attach_to_existing_plan",
        confidence: "high",
        reasonCodes: ["existing_project_context"],
        nextAction: "done",
        createsActiveTasks: false,
        resourceId: 70,
        error: nil,
        clarificationQuestion: nil,
        existingPlanCandidates: nil,
        attachmentModeSuggestion: "material_only",
        canonicalRepoRole: nil,
        reviewPackage: nil,
        activationResult: nil
    )
}

private func sampleAddInitiateAnchorReviewSession(
    sessionId: String = "add-initiate-1",
    clientRequestId: String = "req-add-1",
    intakeItemId: Int = 11,
    draftId: Int = 501,
    draftVersion: Int? = 1
) -> AddInitiateSessionResponse {
    AddInitiateSessionResponse(
        sessionId: sessionId,
        clientRequestId: clientRequestId,
        intakeItemId: intakeItemId,
        draftId: draftId,
        draftVersion: draftVersion,
        stage: .anchorReview,
        reviewState: .anchorReview,
        recommendedRole: "new_plan",
        confirmedRole: "new_plan",
        confidence: "high",
        reasonCodes: ["plan_generating"],
        nextAction: "confirm_anchors",
        createsActiveTasks: false,
        resourceId: nil,
        error: nil,
        clarificationQuestion: nil,
        existingPlanCandidates: nil,
        attachmentModeSuggestion: nil,
        canonicalRepoRole: nil,
        reviewPackage: nil,
        activationResult: nil
    )
}

private func sampleAddInitiateNeedsInputSession(
    sessionId: String = "add-initiate-1",
    clientRequestId: String = "req-add-1",
    intakeItemId: Int = 11,
    draftId: Int = 501,
    draftVersion: Int? = 1
) -> AddInitiateSessionResponse {
    AddInitiateSessionResponse(
        sessionId: sessionId,
        clientRequestId: clientRequestId,
        intakeItemId: intakeItemId,
        draftId: draftId,
        draftVersion: draftVersion,
        stage: .needsInput,
        reviewState: .needsInput,
        recommendedRole: "new_plan",
        confirmedRole: "new_plan",
        confidence: "high",
        reasonCodes: ["missing_scope"],
        nextAction: "answer_question",
        createsActiveTasks: false,
        resourceId: nil,
        error: nil,
        clarificationQuestion: ["question": AnyCodable("What scope should be excluded?")],
        existingPlanCandidates: nil,
        attachmentModeSuggestion: nil,
        canonicalRepoRole: nil,
        reviewPackage: ["previousFacts": AnyCodable(["deadline": "2026-07-01"])],
        activationResult: nil
    )
}

private func sampleAddInitiateCompileFailedSession(
    sessionId: String = "add-initiate-1",
    clientRequestId: String = "req-add-1",
    intakeItemId: Int = 11,
    draftId: Int = 501,
    draftVersion: Int? = 1
) -> AddInitiateSessionResponse {
    AddInitiateSessionResponse(
        sessionId: sessionId,
        clientRequestId: clientRequestId,
        intakeItemId: intakeItemId,
        draftId: draftId,
        draftVersion: draftVersion,
        stage: .compileFailed,
        reviewState: .compileFailed,
        recommendedRole: "new_plan",
        confirmedRole: "new_plan",
        confidence: "high",
        reasonCodes: ["compiler_validation_failed"],
        nextAction: "retry",
        createsActiveTasks: false,
        resourceId: nil,
        error: "Compiler validation failed",
        clarificationQuestion: nil,
        existingPlanCandidates: nil,
        attachmentModeSuggestion: nil,
        canonicalRepoRole: nil,
        reviewPackage: ["previousFacts": AnyCodable(["capacityMinutes": 45])],
        activationResult: nil
    )
}

private func sampleAddInitiateDraftReviewSession(
    sessionId: String = "add-initiate-1",
    clientRequestId: String = "req-add-1",
    intakeItemId: Int = 11,
    draftId: Int = 501,
    draftVersion: Int? = 2,
    reviewPackage: [String: AnyCodable] = ["summary": AnyCodable("Feasible draft")]
) -> AddInitiateSessionResponse {
    AddInitiateSessionResponse(
        sessionId: sessionId,
        clientRequestId: clientRequestId,
        intakeItemId: intakeItemId,
        draftId: draftId,
        draftVersion: draftVersion,
        stage: .draftReview,
        reviewState: .draftReview,
        recommendedRole: "new_plan",
        confirmedRole: "new_plan",
        confidence: "high",
        reasonCodes: ["feasible_schedule"],
        nextAction: "review_draft",
        createsActiveTasks: false,
        resourceId: nil,
        error: nil,
        clarificationQuestion: nil,
        existingPlanCandidates: nil,
        attachmentModeSuggestion: nil,
        canonicalRepoRole: nil,
        reviewPackage: reviewPackage,
        activationResult: nil
    )
}

private func sampleAddInitiateInfeasibleReviewSession(
    sessionId: String = "add-initiate-1",
    clientRequestId: String = "req-add-1",
    intakeItemId: Int = 11,
    draftId: Int = 501,
    draftVersion: Int? = 2,
    deadlineType: String = "soft",
    reviewPackage: [String: AnyCodable]? = nil
) -> AddInitiateSessionResponse {
    AddInitiateSessionResponse(
        sessionId: sessionId,
        clientRequestId: clientRequestId,
        intakeItemId: intakeItemId,
        draftId: draftId,
        draftVersion: draftVersion,
        stage: .infeasibleReview,
        reviewState: .infeasibleReview,
        recommendedRole: "new_plan",
        confirmedRole: "new_plan",
        confidence: "high",
        reasonCodes: ["capacity_gap"],
        nextAction: "choose_option",
        createsActiveTasks: false,
        resourceId: nil,
        error: nil,
        clarificationQuestion: nil,
        existingPlanCandidates: nil,
        attachmentModeSuggestion: nil,
        canonicalRepoRole: nil,
        reviewPackage: reviewPackage ?? sampleAddInitiateInfeasibleReviewPackage(deadlineType: deadlineType),
        activationResult: nil
    )
}

private func sampleAddInitiateStoredLaterSession() -> AddInitiateSessionResponse {
    AddInitiateSessionResponse(
        sessionId: "add-initiate-1",
        clientRequestId: "req-add-1",
        intakeItemId: 11,
        draftId: nil,
        draftVersion: nil,
        stage: .storedNonPlan,
        reviewState: .storedNonPlan,
        recommendedRole: "new_plan",
        confirmedRole: "later_resource",
        confidence: "high",
        reasonCodes: ["stored_for_later"],
        nextAction: "done",
        createsActiveTasks: false,
        resourceId: nil,
        error: nil,
        clarificationQuestion: nil,
        existingPlanCandidates: nil,
        attachmentModeSuggestion: nil,
        canonicalRepoRole: nil,
        reviewPackage: nil,
        activationResult: nil
    )
}

private func sampleAddInitiateActivationFailedSession(
    sessionId: String = "add-initiate-1",
    clientRequestId: String = "req-add-1",
    intakeItemId: Int = 11,
    draftId: Int = 501,
    draftVersion: Int = 2,
    reviewPackage: [String: AnyCodable]? = ["summary": AnyCodable("Draft preserved")]
) -> AddInitiateSessionResponse {
    AddInitiateSessionResponse(
        sessionId: sessionId,
        clientRequestId: clientRequestId,
        intakeItemId: intakeItemId,
        draftId: draftId,
        draftVersion: draftVersion,
        stage: .activationFailed,
        reviewState: .activationFailed,
        recommendedRole: "new_plan",
        confirmedRole: "new_plan",
        confidence: "high",
        reasonCodes: ["activation_guard_failed"],
        nextAction: "retry_activation",
        createsActiveTasks: false,
        resourceId: nil,
        error: "Activation failed",
        clarificationQuestion: nil,
        existingPlanCandidates: nil,
        attachmentModeSuggestion: nil,
        canonicalRepoRole: nil,
        reviewPackage: reviewPackage,
        activationResult: nil
    )
}

private func sampleAddInitiateActivatedSession(
    sessionId: String = "add-initiate-1",
    clientRequestId: String = "req-add-1",
    intakeItemId: Int = 11,
    draftId: Int = 501,
    draftVersion: Int = 2
) -> AddInitiateSessionResponse {
    AddInitiateSessionResponse(
        sessionId: sessionId,
        clientRequestId: clientRequestId,
        intakeItemId: intakeItemId,
        draftId: draftId,
        draftVersion: draftVersion,
        stage: .activated,
        reviewState: .activated,
        recommendedRole: "new_plan",
        confirmedRole: "new_plan",
        confidence: "high",
        reasonCodes: ["activated"],
        nextAction: "done",
        createsActiveTasks: true,
        resourceId: 88,
        error: nil,
        clarificationQuestion: nil,
        existingPlanCandidates: nil,
        attachmentModeSuggestion: nil,
        canonicalRepoRole: nil,
        reviewPackage: ["summary": AnyCodable("Activated")],
        activationResult: ["status": AnyCodable("active"), "resource_id": AnyCodable(88)]
    )
}

private func sampleAddInitiateDraftReviewPackage(
    dayCount: Int,
    latestDraftVersion: Int? = nil,
    packageDraftVersion: Int? = nil,
    loadState: String? = nil,
    deadlineRisk: String = "hard_deadline_pressure",
    sourceDetails: [String: String]? = nil
) -> [String: AnyCodable] {
    let days: [[String: Any]] = (0..<dayCount).map { index in
        let fallbackMode: Any = index == 0 ? [
            "fallback_minutes": 15,
            "fallback_output": "skim notes",
            "risk_effect": "scope_visible"
        ] : NSNull()
        let day: [String: Any] = [
            "date": "2026-06-\(String(format: "%02d", index + 1))",
            "planned_minutes": index == 0 ? 60 : 45,
            "load_state": loadState ?? (index == 2 ? "over_capacity" : "within_budget"),
            "reserved_buffer": index == 5,
            "items": [
                [
                    "task_id": "task-\(index + 1)",
                    "scheduled_minutes": index == 0 ? 60 : 45,
                    "normal_mode": [
                        "title": "Task \(index + 1)",
                        "output": "normal output \(index + 1)"
                    ],
                    "fallback_mode": fallbackMode
                ]
            ]
        ]
        return day
    }
    var package: [String: Any] = [
        "role": "new_plan",
        "target_output": "reviewable rebuild plan",
        "target_depth": "apply",
        "deadline_type": "hard",
        "deadline_fit": "fits_with_risk",
        "assumptions": ["weekdays only", "ship demo first"],
        "scheduled_days": days,
        "risk_report": [
            "fits_as_written": false,
            "essential_work_minutes": 480,
            "available_execution_capacity_minutes": 420,
            "capacity_gap_minutes": 60,
            "overloaded_dates": ["2026-06-03"],
            "expected_late_tasks": ["task-7"],
            "buffer_days_reserved": ["2026-06-06"],
            "buffer_erosion": true,
            "existing_load_conflicts": ["2026-06-04"],
            "date_window_risk": deadlineRisk
        ],
        "source_details": sourceDetails ?? [
            "kind": "github_repo",
            "title": "AgentGuide"
        ]
    ]
    if let latestDraftVersion {
        package["latest_draft_version"] = latestDraftVersion
    }
    if let packageDraftVersion {
        package["draft_version"] = packageDraftVersion
    }
    return package.mapValues { AnyCodable($0) }
}

private func sampleAddInitiateCamelCaseDraftReviewPackage(
    latestDraftVersion: Int? = nil
) -> [String: AnyCodable] {
    var package: [String: Any] = [
        "role": "new_plan",
        "targetOutput": "camel review plan",
        "targetDepth": "overview",
        "deadlineType": "hard",
        "deadlineFit": "fits_with_risk",
        "assumptions": ["camel inputs"],
        "scheduledDays": [
            [
                "date": "2026-06-01",
                "plannedMinutes": 70,
                "loadState": "uses_buffer",
                "items": [
                    [
                        "taskId": "camel-task",
                        "scheduledMinutes": 70,
                        "normalMode": [
                            "title": "Camel Task",
                            "output": "normal"
                        ],
                        "fallbackMode": [
                            "fallbackOutput": "outline only",
                            "riskEffect": "preserves_scope"
                        ]
                    ]
                ]
            ]
        ],
        "riskReport": [
            "dateWindowRisk": "hard_deadline_pressure",
            "bufferErosion": true
        ],
        "sourceDetails": [
            "kind": "github_repo",
            "title": "Camel Guide"
        ]
    ]
    if let latestDraftVersion {
        package["latestDraftVersion"] = latestDraftVersion
    }
    return package.mapValues { AnyCodable($0) }
}

private func sampleAddInitiateInfeasibleReviewPackage(deadlineType: String) -> [String: AnyCodable] {
    [
        "deadline_type": AnyCodable(deadlineType),
        "risk_report": AnyCodable([
            "capacity_gap_minutes": 90,
            "overloaded_dates": ["2026-06-04"],
            "expected_late_tasks": ["task-2"],
            "buffer_erosion": true,
            "low_calibration": true,
            "canonical_infeasibility_option_ids": [
                "reduce_scope",
                "lower_depth",
                "extend_deadline",
                "accept_late_finish",
                "store_for_later"
            ]
        ]),
        "infeasibility_options": AnyCodable([
            ["id": "reduce_scope", "effect_type": "review_recompute"],
            ["id": "lower_depth", "effect_type": "compiler_recompute_required"],
            ["id": "extend_deadline", "effect_type": "review_recompute"],
            ["id": "accept_late_finish", "effect_type": "review_recompute"],
            ["id": "store_for_later", "effect_type": "storage"]
        ])
    ]
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
    unitTitle: String? = nil,
    rolledDayCount: Int = 0,
    showRolledBadge: Bool = false
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
        "unit_url": "https://example.com/unit/\(id)",
        "rolled_day_count": \(rolledDayCount),
        "show_rolled_badge": \(showRolledBadge)
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
    status: String,
    expectedLate: Bool = false
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
        "status": "\(status)",
        "expected_late": \(expectedLate)
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

private func sampleStudySmartMorningBriefing() -> StudySmartMorningBriefing {
    StudySmartMorningBriefing(
        enabled: true,
        date: "2026-06-01",
        summary: "One study-plan issue needs attention.",
        snapshot: [
            "today": AnyCodable(["tasks": []]),
            "projects": AnyCodable(["active_projects": [], "completed_projects": []]),
            "calendar": AnyCodable(["days": []])
        ],
        issues: [
            StudySmartBriefingIssue(
                type: "expected_late_project",
                projectId: 7,
                taskId: nil,
                rolledDayCount: nil,
                date: nil
            )
        ],
        options: [sampleStudySmartProposalOption()],
        triggerEligible: true
    )
}

private func sampleStudySmartProposalOption(
    trigger: StudySmartProposalTrigger = .morning,
    signature: String = "abc123"
) -> StudySmartProposalOption {
    StudySmartProposalOption(
        id: trigger == .morning ? "morning-extend-deadline-7" : "after-adjustment-extend-deadline-7",
        trigger: trigger,
        reason: [
            "type": AnyCodable("expected_late_project"),
            "project_id": AnyCodable(7),
            "deadline": AnyCodable("2026-06-10"),
            "latest_task_date": AnyCodable("2026-06-14")
        ],
        affectedProjectIds: [7],
        affectedTaskIds: [42],
        preview: [
            "status": AnyCodable("preview"),
            "source": AnyCodable("smart_mode_preview"),
            "command": AnyCodable("extend_project_deadline"),
            "trigger": AnyCodable(trigger.rawValue),
            "project_id": AnyCodable(7),
            "mutates": AnyCodable(false)
        ],
        previewedChanges: [
            StudySmartPreviewedChange(
                taskId: nil,
                projectId: 7,
                field: "deadline",
                oldDate: nil,
                newDate: nil,
                oldDeadline: "2026-06-10",
                newDeadline: "2026-06-14"
            )
        ],
        redStateImpact: StudyRedStateImpact(
            expectedLate: StudyExpectedLateImpact(before: true, after: false),
            overCapacity: nil
        ),
        summary: "Extend project 7's deadline to 2026-06-14.",
        tradeoff: "Keeps task dates unchanged but moves the project commitment later.",
        signatureVersion: 1,
        signature: signature,
        signaturePayload: [
            "trigger": AnyCodable(trigger.rawValue),
            "project_id": AnyCodable(7)
        ]
    )
}

private func sampleStudySmartProposalGenerationResponse() -> StudySmartProposalGenerationResponse {
    StudySmartProposalGenerationResponse(
        enabled: true,
        trigger: .morning,
        options: [sampleStudySmartProposalOption()],
        message: nil
    )
}

private func sampleStudySmartProposalApplyResult() -> StudySmartProposalApplyResult {
    StudySmartProposalApplyResult(
        status: "applied",
        source: "smart_mode_apply",
        proposalId: "morning-extend-deadline-7",
        signature: "abc123",
        trigger: .morning,
        command: "extend_project_deadline",
        affectedProjectIds: [7],
        affectedTaskIds: [42],
        appliedChanges: [
            StudySmartPreviewedChange(
                taskId: nil,
                projectId: 7,
                field: "deadline",
                oldDate: nil,
                newDate: nil,
                oldDeadline: "2026-06-10",
                newDeadline: "2026-06-14"
            )
        ],
        mutates: true,
        refresh: StudyRefreshContract(today: true, projectOverview: true, calendar: true),
        message: nil
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
