"""Study intake data/idempotency tests."""

import json
from datetime import date

import pytest


class _GitHubResponse:
    def __init__(self, status_code: int, payload: dict):
        self.status_code = status_code
        self._payload = payload

    def json(self) -> dict:
        return self._payload


class _GitHubClient:
    def __init__(self, responses: dict[str, _GitHubResponse]):
        self.responses = responses
        self.requested_urls: list[str] = []

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False

    async def get(self, url: str, **kwargs):
        self.requested_urls.append(url)
        for marker, response in self.responses.items():
            if marker in url:
                return response
        return _GitHubResponse(404, {})


async def _fetchall(db, sql: str, params: tuple = ()) -> list[dict]:
    async with db.execute(sql, params) as cursor:
        rows = await cursor.fetchall()
        return [dict(row) for row in rows]


async def _fetchone(db, sql: str, params: tuple = ()) -> dict | None:
    async with db.execute(sql, params) as cursor:
        row = await cursor.fetchone()
        return dict(row) if row else None


@pytest.mark.asyncio
async def test_idempotency_reuses_intake_item_and_non_plan_resource(db):
    from src.study_plan.intake import (
        confirm_non_plan_resource,
        create_intake_item,
    )

    first = await create_intake_item(
        db,
        client_request_id="req-reference-1",
        raw_input="Save the SQLite query planner docs as a reference.",
        source_type="text_goal",
        recommended_role="reference_material",
        confidence="high",
        reason_codes=["explicit_reference"],
    )
    second = await create_intake_item(
        db,
        client_request_id="req-reference-1",
        raw_input="Retried body should not replace the original.",
        source_type="pasted_note",
        recommended_role="later_resource",
        confidence="low",
        reason_codes=["retry"],
    )

    assert second == first

    first_resource = await confirm_non_plan_resource(
        db,
        intake_item_id=first["id"],
        role="reference_material",
        title="SQLite query planner",
        url="https://sqlite.org/queryplanner.html",
    )
    second_resource = await confirm_non_plan_resource(
        db,
        intake_item_id=first["id"],
        role="reference_material",
        title="Duplicate retry",
        url="https://example.com/duplicate",
    )

    assert second_resource == first_resource
    assert await _fetchall(db, "SELECT id FROM study_intake_items") == [{"id": first["id"]}]
    assert await _fetchall(db, "SELECT id FROM study_intake_non_plan_items") == [
        {"id": first_resource["id"]}
    ]


@pytest.mark.asyncio
async def test_non_plan_and_material_only_outcomes_are_excluded_from_today(db):
    from src.db.queries import get_today_study_view_tasks
    from src.study_plan.intake import (
        attach_material_to_plan,
        confirm_non_plan_resource,
        create_intake_item,
    )

    project_cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Existing Study Project', 'study_project', 'sequential', 'active', 1)
        """
    )
    project_id = int(project_cursor.lastrowid)

    reference = await create_intake_item(
        db,
        client_request_id="req-reference-2",
        raw_input="Reference article for later study.",
        source_type="url",
        recommended_role="reference_material",
        confidence="medium",
    )
    later = await create_intake_item(
        db,
        client_request_id="req-later-1",
        raw_input="https://github.com/example/later-reading",
        source_type="github_repo",
        recommended_role="later_resource",
        confidence="medium",
    )
    material = await create_intake_item(
        db,
        client_request_id="req-material-1",
        raw_input="Paste these notes into the active project context.",
        source_type="pasted_note",
        recommended_role="attach_to_existing_plan",
        confidence="high",
    )

    await confirm_non_plan_resource(
        db,
        intake_item_id=reference["id"],
        role="reference_material",
        title="Reference article",
    )
    await confirm_non_plan_resource(
        db,
        intake_item_id=later["id"],
        role="later_resource",
        title="Later GitHub repo",
        url="https://github.com/example/later-reading",
    )
    await attach_material_to_plan(
        db,
        intake_item_id=material["id"],
        target_plan_id=project_id,
        attachment_mode="material_only",
        title="Supporting notes",
    )

    assert await get_today_study_view_tasks(db, date.today()) == []
    assert await _fetchall(db, "SELECT id FROM tasks") == []


@pytest.mark.asyncio
async def test_today_exclusion_for_immediate_one_off_until_explicit_action(db):
    from src.db.queries import get_today_study_view_tasks
    from src.study_plan.intake import create_intake_item

    item = await create_intake_item(
        db,
        client_request_id="req-one-off-1",
        raw_input="Email myself the repo link today.",
        source_type="text_goal",
        recommended_role="immediate_one_off",
        confidence="medium",
        next_action="explicit_user_action",
    )

    assert item["recommended_role"] == "immediate_one_off"
    assert item["next_action"] == "explicit_user_action"
    assert await get_today_study_view_tasks(db, date.today()) == []
    assert await _fetchall(db, "SELECT id FROM tasks") == []


@pytest.mark.asyncio
async def test_confirm_non_plan_resource_preserves_pending_when_child_insert_fails(db):
    from src.study_plan.intake import (
        confirm_non_plan_resource,
        create_intake_item,
    )

    item = await create_intake_item(
        db,
        client_request_id="req-reference-invalid-title",
        raw_input="Save this item, but the confirmation payload is malformed.",
        source_type="text_goal",
        recommended_role="reference_material",
        confidence="high",
    )

    with pytest.raises(Exception):
        await confirm_non_plan_resource(
            db,
            intake_item_id=item["id"],
            role="reference_material",
            title=None,
        )

    assert await _fetchall(
        db,
        "SELECT confirmation_state FROM study_intake_items WHERE id = ?",
        (item["id"],),
    ) == [{"confirmation_state": "pending"}]
    assert await _fetchall(
        db,
        "SELECT id FROM study_intake_non_plan_items WHERE intake_item_id = ?",
        (item["id"],),
    ) == []


@pytest.mark.asyncio
async def test_attach_material_to_plan_preserves_pending_when_child_insert_fails(db):
    from src.study_plan.intake import (
        attach_material_to_plan,
        create_intake_item,
    )

    project_cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Existing Study Project', 'study_project', 'sequential', 'active', 1)
        """
    )
    project_id = int(project_cursor.lastrowid)
    await db.commit()

    item = await create_intake_item(
        db,
        client_request_id="req-material-invalid-title",
        raw_input="Attach this material, but the confirmation payload is malformed.",
        source_type="pasted_note",
        recommended_role="attach_to_existing_plan",
        confidence="high",
    )

    with pytest.raises(Exception):
        await attach_material_to_plan(
            db,
            intake_item_id=item["id"],
            target_plan_id=project_id,
            attachment_mode="material_only",
            title=None,
        )

    assert await _fetchall(
        db,
        "SELECT confirmation_state FROM study_intake_items WHERE id = ?",
        (item["id"],),
    ) == [{"confirmation_state": "pending"}]
    assert await _fetchall(
        db,
        "SELECT id FROM study_intake_plan_attachments WHERE intake_item_id = ?",
        (item["id"],),
    ) == []


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("source_type", "raw_input", "expected_role"),
    [
        ("text_goal", "Learn FastAPI deeply by June 30 with a weekly study plan.", "new_plan"),
        ("url", "https://example.com/sqlite-query-planner-guide reference docs", "reference_material"),
        ("github_repo", "https://github.com/example/clone-target rebuild this app as a portfolio project", "new_plan"),
        ("pasted_note", "Notes from the TCP lecture: congestion control, retransmission, cwnd.", "reference_material"),
        ("existing_project_description", "Add this auth checklist to my existing Study Project.", "attach_to_existing_plan"),
        ("interview_prep", "Practice system design interview questions tomorrow.", "immediate_one_off"),
        ("resume_project_material", "Attach this resume bullet draft to my portfolio plan.", "attach_to_existing_plan"),
        ("unknown", "maybe something with rust eventually", "later_resource"),
    ],
)
async def test_route_helper_supports_first_version_input_types(
    db,
    source_type,
    raw_input,
    expected_role,
):
    from src.study_plan.intake import route_intake_submission

    if expected_role == "attach_to_existing_plan":
        await db.execute(
            """
            INSERT INTO resources (title, type, tracking_mode, status, total_units)
            VALUES ('Study Project', 'study_project', 'sequential', 'active', 1)
            """
        )
        await db.commit()

    result = await route_intake_submission(
        db,
        client_request_id=f"req-input-{source_type}",
        raw_input=raw_input,
        source_type=source_type,
    )

    assert result["intakeItemId"]
    assert result["recommendedRole"] == expected_role
    assert result["createsActiveTasks"] is False
    assert result["nextAction"] in {
        "role_review",
        "answer_routing_question",
        "confirm_non_plan_storage",
        "select_attachment_target",
        "handoff_to_anchor_review",
    }
    assert result["confidence"] in {"high", "medium", "low"}
    assert result["reasonCodes"]


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("raw_input", "source_type", "expected_role", "expected_next_action"),
    [
        ("Build a deadline-driven Rust learning plan by July 15.", "text_goal", "new_plan", "role_review"),
        ("Attach these OAuth notes to my existing backend plan.", "pasted_note", "attach_to_existing_plan", "answer_routing_question"),
        ("Keep this as reference material: https://docs.python.org/3/library/asyncio.html", "url", "reference_material", "confirm_non_plan_storage"),
        ("Save this repo for later reading: https://github.com/example/later", "github_repo", "later_resource", "confirm_non_plan_storage"),
        ("Remind me to email myself this article today.", "text_goal", "immediate_one_off", "role_review"),
    ],
)
async def test_role_recommendations_include_confidence_reasons_and_next_action(
    db,
    raw_input,
    source_type,
    expected_role,
    expected_next_action,
):
    from src.study_plan.intake import route_intake_submission

    result = await route_intake_submission(
        db,
        client_request_id=f"req-role-{expected_role}",
        raw_input=raw_input,
        source_type=source_type,
    )

    assert result["recommendedRole"] == expected_role
    assert result["nextAction"] == expected_next_action
    assert result["confidence"] in {"high", "medium"}
    assert isinstance(result["reasonCodes"], list)
    assert result["createsActiveTasks"] is False


@pytest.mark.asyncio
async def test_low_confidence_ambiguous_route_asks_exactly_one_question(db):
    from src.study_plan.intake import route_intake_submission

    result = await route_intake_submission(
        db,
        client_request_id="req-ambiguous-role",
        raw_input="Maybe put this somewhere for the compiler thing.",
        source_type="unknown",
    )

    assert result["recommendedRole"] == "later_resource"
    assert result["confidence"] == "low"
    assert result["nextAction"] == "answer_routing_question"
    assert result["createsActiveTasks"] is False
    assert result["clarificationQuestion"]["prompt"].count("?") == 1
    assert result["clarificationQuestion"]["recommendedDefault"] == "later_resource"
    assert len(result["clarificationQuestion"]["options"]) == 5


@pytest.mark.asyncio
async def test_existing_plan_target_selection_for_one_multiple_and_no_candidates(db):
    from src.study_plan.intake import route_intake_submission

    one_cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Compiler Study Project', 'study_project', 'sequential', 'active', 1)
        """
    )
    one_id = int(one_cursor.lastrowid)
    await db.commit()

    one = await route_intake_submission(
        db,
        client_request_id="req-one-candidate",
        raw_input="Attach these parser notes to my compiler project.",
        source_type="pasted_note",
    )

    assert one["recommendedRole"] == "attach_to_existing_plan"
    assert one["nextAction"] == "select_attachment_target"
    assert one["existingPlanCandidates"] == [{"id": one_id, "title": "Compiler Study Project"}]

    await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Backend Study Project', 'study_project', 'sequential', 'active', 1)
        """
    )
    await db.commit()

    multiple = await route_intake_submission(
        db,
        client_request_id="req-multiple-candidates",
        raw_input="Attach these deployment notes to my existing project.",
        source_type="pasted_note",
    )

    assert multiple["recommendedRole"] == "attach_to_existing_plan"
    assert multiple["nextAction"] == "select_attachment_target"
    assert len(multiple["existingPlanCandidates"]) == 2

    await db.execute("UPDATE resources SET status = 'archived'")
    await db.commit()

    none = await route_intake_submission(
        db,
        client_request_id="req-no-candidates",
        raw_input="Attach these notes to my existing project.",
        source_type="pasted_note",
    )

    assert none["recommendedRole"] == "attach_to_existing_plan"
    assert none["nextAction"] == "answer_routing_question"
    assert none["existingPlanCandidates"] == []
    assert "no_existing_plan_candidate" in none["reasonCodes"]


@pytest.mark.asyncio
async def test_route_retry_uses_stored_item_contract_not_retry_body_or_candidates(db):
    from src.study_plan.intake import route_intake_submission

    first = await route_intake_submission(
        db,
        client_request_id="req-route-stable-retry",
        raw_input="https://github.com/acme/clone-target rebuild this as a portfolio project",
        source_type="github_repo",
        user_hint="clone/rebuild target, make a new study plan",
    )

    await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Backend Study Project', 'study_project', 'sequential', 'active', 1)
        """
    )
    await db.commit()

    retry = await route_intake_submission(
        db,
        client_request_id="req-route-stable-retry",
        raw_input="Attach this as scheduled reference material to my existing project later.",
        source_type="pasted_note",
        user_hint="attach to existing project as scheduled work later",
    )

    assert retry == first
    assert retry["recommendedRole"] == "new_plan"
    assert retry["canonicalRepoRole"] == "clone_rebuild_target"
    assert retry["previewSummary"] == first["previewSummary"]
    assert "attachmentModeSuggestion" not in retry
    assert "existingPlanCandidates" not in retry
    assert "clarificationQuestion" not in retry


@pytest.mark.asyncio
async def test_route_retry_preserves_user_hint_canonical_repo_role_when_raw_repo_is_generic(db):
    from src.study_plan.intake import route_intake_submission

    first = await route_intake_submission(
        db,
        client_request_id="req-route-retry-hint-canonical-role",
        raw_input="https://github.com/acme/app",
        source_type="github_repo",
        user_hint="clone/rebuild target",
    )

    retry = await route_intake_submission(
        db,
        client_request_id="req-route-retry-hint-canonical-role",
        raw_input="https://github.com/acme/app",
        source_type="github_repo",
        user_hint="keep as the main learning object",
    )

    assert first["canonicalRepoRole"] == "clone_rebuild_target"
    assert retry == first
    assert retry["canonicalRepoRole"] == "clone_rebuild_target"
    assert not any(
        reason.startswith("canonical_repo_role:") for reason in retry["reasonCodes"]
    )


@pytest.mark.asyncio
async def test_route_retry_preserves_user_hint_attachment_mode(db):
    from src.study_plan.intake import route_intake_submission

    await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Backend Study Project', 'study_project', 'sequential', 'active', 1)
        """
    )
    await db.commit()

    first = await route_intake_submission(
        db,
        client_request_id="req-route-retry-hint-attachment-mode",
        raw_input="Attach these notes to my existing backend project.",
        source_type="pasted_note",
        user_hint="schedule this as work for next week",
    )

    retry = await route_intake_submission(
        db,
        client_request_id="req-route-retry-hint-attachment-mode",
        raw_input="Attach these notes to my existing backend project.",
        source_type="pasted_note",
        user_hint="just keep this as material only",
    )

    assert first["attachmentModeSuggestion"] == "scheduled_work"
    assert retry == first
    assert retry["attachmentModeSuggestion"] == "scheduled_work"
    assert not any(reason.startswith("attachment_mode:") for reason in retry["reasonCodes"])


@pytest.mark.asyncio
async def test_route_uses_existing_plan_id_as_selected_attachment_target(db):
    from src.study_plan.intake import route_intake_submission

    first_cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Compiler Study Project', 'study_project', 'sequential', 'active', 1)
        """
    )
    first_id = int(first_cursor.lastrowid)
    second_cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Backend Study Project', 'study_project', 'sequential', 'active', 1)
        """
    )
    second_id = int(second_cursor.lastrowid)
    await db.commit()

    route = await route_intake_submission(
        db,
        client_request_id="req-selected-existing-plan",
        raw_input="Attach these parser notes to my existing compiler project.",
        source_type="pasted_note",
        existing_plan_id=second_id,
    )

    assert first_id != second_id
    assert route["recommendedRole"] == "attach_to_existing_plan"
    assert route["existingPlanCandidates"] == [
        {"id": second_id, "title": "Backend Study Project"}
    ]
    assert route["existingPlanId"] == second_id
    assert route["nextAction"] == "role_review"
    assert route["createsActiveTasks"] is False


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("raw_input", "source_type", "expected_role"),
    [
        ("Learn FastAPI by June 30", "text_goal", "new_plan"),
        ("reference docs for FastAPI", "url", "reference_material"),
        ("Save FastAPI release notes for later", "url", "later_resource"),
        ("Email myself the FastAPI link today", "text_goal", "immediate_one_off"),
    ],
)
async def test_route_rejects_invalid_existing_plan_id_before_creating_non_attach_item(
    db,
    raw_input,
    source_type,
    expected_role,
):
    from src.study_plan.intake import route_intake_submission

    client_request_id = f"req-invalid-existing-plan-{expected_role}"
    cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Archived Study Project', 'study_project', 'sequential', 'archived', 1)
        """
    )
    archived_plan_id = int(cursor.lastrowid)
    await db.commit()

    with pytest.raises(ValueError, match="active study plan"):
        await route_intake_submission(
            db,
            client_request_id=client_request_id,
            raw_input=raw_input,
            source_type=source_type,
            existing_plan_id=archived_plan_id,
        )

    assert await _fetchall(
        db,
        "SELECT id FROM study_intake_items WHERE client_request_id = ?",
        (client_request_id,),
    ) == []


@pytest.mark.asyncio
async def test_planning_beats_practice_one_off_language(db):
    from src.study_plan.intake import route_intake_submission

    route = await route_intake_submission(
        db,
        client_request_id="req-planning-beats-practice",
        raw_input="Practice algorithms by July 15 with a weekly plan",
        source_type="text_goal",
    )

    assert route["recommendedRole"] == "new_plan"
    assert route["nextAction"] == "role_review"
    assert "planning_language" in route["reasonCodes"]
    assert "one_off_action_language" not in route["reasonCodes"]


@pytest.mark.asyncio
@pytest.mark.parametrize("target_status", ["archived", None])
async def test_invalid_target_material_only_raises_without_attachment_or_state_change(
    db,
    target_status,
):
    from src.study_plan.intake import confirm_intake_route, create_intake_item

    existing_plan_id = 999_001
    if target_status is not None:
        cursor = await db.execute(
            """
            INSERT INTO resources (title, type, tracking_mode, status, total_units)
            VALUES ('Archived Study Project', 'study_project', 'sequential', ?, 1)
            """,
            (target_status,),
        )
        existing_plan_id = int(cursor.lastrowid)
        await db.commit()

    item = await create_intake_item(
        db,
        client_request_id=f"req-invalid-target-material-{target_status}",
        raw_input="Attach these notes to my project.",
        source_type="pasted_note",
        recommended_role="attach_to_existing_plan",
        confidence="high",
    )

    with pytest.raises(ValueError, match="active study plan"):
        await confirm_intake_route(
            db,
            intake_item_id=item["id"],
            confirmed_role="attach_to_existing_plan",
            existing_plan_id=existing_plan_id,
            attachment_mode="material_only",
            title="Parser notes",
        )

    assert await _fetchall(
        db,
        "SELECT confirmation_state FROM study_intake_items WHERE id = ?",
        (item["id"],),
    ) == [{"confirmation_state": "pending"}]
    assert await _fetchall(
        db,
        "SELECT id FROM study_intake_plan_attachments WHERE intake_item_id = ?",
        (item["id"],),
    ) == []


@pytest.mark.asyncio
@pytest.mark.parametrize("attachment_mode", ["scheduled_work", "draft_phase"])
async def test_invalid_target_anchor_modes_raise_and_keep_intake_pending(
    db,
    attachment_mode,
):
    from src.study_plan.intake import confirm_intake_route, create_intake_item

    cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Archived Study Project', 'study_project', 'sequential', 'archived', 1)
        """
    )
    archived_plan_id = int(cursor.lastrowid)
    await db.commit()

    item = await create_intake_item(
        db,
        client_request_id=f"req-invalid-target-{attachment_mode}",
        raw_input="Attach this work to the archived project.",
        source_type="pasted_note",
        recommended_role="attach_to_existing_plan",
        confidence="high",
    )

    with pytest.raises(ValueError, match="active study plan"):
        await confirm_intake_route(
            db,
            intake_item_id=item["id"],
            confirmed_role="attach_to_existing_plan",
            existing_plan_id=archived_plan_id,
            attachment_mode=attachment_mode,
            title="Retry practice",
        )

    assert await _fetchall(
        db,
        "SELECT confirmation_state FROM study_intake_items WHERE id = ?",
        (item["id"],),
    ) == [{"confirmation_state": "pending"}]
    assert await _fetchall(
        db,
        "SELECT id FROM study_intake_plan_attachments WHERE intake_item_id = ?",
        (item["id"],),
    ) == []


@pytest.mark.asyncio
async def test_route_idempotency_response_uses_stored_item_after_insert_race(
    db,
    monkeypatch,
):
    import src.study_plan.intake as intake

    original_create = intake.create_intake_item

    async def create_loses_race(*args, **kwargs):
        await original_create(
            args[0],
            client_request_id=kwargs["client_request_id"],
            raw_input="https://github.com/acme/app",
            source_type="github_repo",
            recommended_role="new_plan",
            confidence="high",
            reason_codes=[
                "source_type:github_repo",
                "repo_clone_rebuild_target",
                "canonical_repo_role:clone_rebuild_target",
            ],
            next_action="role_review",
        )
        return await original_create(*args, **kwargs)

    monkeypatch.setattr(intake, "create_intake_item", create_loses_race)

    response = await intake.route_intake_submission(
        db,
        client_request_id="req-idempotency-lost-race-response",
        raw_input="Attach these notes to my existing project as scheduled work.",
        source_type="pasted_note",
        user_hint="attach to existing project as scheduled work",
    )

    assert response["recommendedRole"] == "new_plan"
    assert response["canonicalRepoRole"] == "clone_rebuild_target"
    assert response["previewSummary"] == {
        "title": "App",
        "sourceType": "github_repo",
    }
    assert "attachmentModeSuggestion" not in response
    assert "existingPlanCandidates" not in response
    assert "clarificationQuestion" not in response


@pytest.mark.asyncio
async def test_scheduled_work_confirmation_requires_target_and_attachment_mode(db):
    from src.study_plan.intake import confirm_intake_route, route_intake_submission

    cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Backend Study Project', 'study_project', 'sequential', 'active', 1)
        """
    )
    plan_id = int(cursor.lastrowid)
    await db.commit()

    route = await route_intake_submission(
        db,
        client_request_id="req-scheduled-work",
        raw_input="Add scheduled retry practice to my backend project next week.",
        source_type="existing_project_description",
    )

    missing_target = await confirm_intake_route(
        db,
        intake_item_id=route["intakeItemId"],
        confirmed_role="attach_to_existing_plan",
        attachment_mode="scheduled_work",
        title="Retry practice",
    )
    assert missing_target["nextAction"] == "select_attachment_target"
    assert missing_target["createsActiveTasks"] is False

    missing_mode = await confirm_intake_route(
        db,
        intake_item_id=route["intakeItemId"],
        confirmed_role="attach_to_existing_plan",
        existing_plan_id=plan_id,
        title="Retry practice",
    )
    assert missing_mode["nextAction"] == "select_attachment_target"
    assert missing_mode["createsActiveTasks"] is False

    ready = await confirm_intake_route(
        db,
        intake_item_id=route["intakeItemId"],
        confirmed_role="attach_to_existing_plan",
        existing_plan_id=plan_id,
        attachment_mode="scheduled_work",
        title="Retry practice",
    )
    assert ready["nextAction"] == "handoff_to_anchor_review"
    assert ready["outcome"] == "awaiting_anchor_review"
    assert ready["createsActiveTasks"] is False


@pytest.mark.asyncio
async def test_new_plan_handoff_persists_draft_kind_shell_without_active_tasks(db):
    from src.study_plan.intake import confirm_intake_route, create_intake_item

    item = await create_intake_item(
        db,
        client_request_id="req-new-plan-handoff-draft-kind",
        raw_input="Learn SQLite by August.",
        source_type="text_goal",
        recommended_role="new_plan",
        confidence="high",
    )

    handoff = await confirm_intake_route(
        db,
        intake_item_id=item["id"],
        confirmed_role="new_plan",
        title="Learn SQLite",
        url="https://example.com/sqlite",
        metadata={
            "deadline": "2026-08-15",
            "capacity_minutes": 75,
            "assumptions": {
                "deadline": {"value": "2026-08-15", "provenance": "user_provided"},
                "capacity": {"daily_minutes": 75, "provenance": "user_provided"},
            },
        },
    )

    assert handoff["nextAction"] == "handoff_to_anchor_review"
    assert handoff["outcome"] == "awaiting_anchor_review"
    assert handoff["draftId"] > 0
    assert handoff["draftKind"] == "new_plan"
    assert handoff["targetPlanId"] is None
    assert handoff["createsActiveTasks"] is False
    assert await _fetchone(
        db,
        """
        SELECT intake_item_id, status, draft_kind, target_plan_id, draft_version,
               latest_version
        FROM study_project_drafts
        WHERE id = ?
        """,
        (handoff["draftId"],),
    ) == {
        "intake_item_id": item["id"],
        "status": "anchor_review",
        "draft_kind": "new_plan",
        "target_plan_id": None,
        "draft_version": 1,
        "latest_version": 1,
    }
    assert await _fetchall(db, "SELECT id FROM tasks") == []


@pytest.mark.asyncio
async def test_new_plan_handoff_without_deadline_records_unknown_assumption_not_today(db):
    from src.study_plan.intake import confirm_intake_route, create_intake_item

    item = await create_intake_item(
        db,
        client_request_id="req-new-plan-unknown-deadline",
        raw_input="Learn SQLite when I have time.",
        source_type="text_goal",
        recommended_role="new_plan",
        confidence="high",
    )

    handoff = await confirm_intake_route(
        db,
        intake_item_id=item["id"],
        confirmed_role="new_plan",
        title="Learn SQLite",
        metadata={"capacity_minutes": 75},
    )
    stored = await _fetchone(
        db,
        "SELECT deadline, metadata FROM study_project_drafts WHERE id = ?",
        (handoff["draftId"],),
    )
    metadata = json.loads(stored["metadata"])

    assert stored["deadline"] == "9999-12-31"
    assert stored["deadline"] != date.today().isoformat()
    assert metadata["deadline"] == "9999-12-31"
    assert metadata["assumptions"]["deadline"] == {
        "value": None,
        "provenance": "unknown",
        "accepted": False,
        "needs_input": True,
    }
    assert metadata["assumptions"]["capacity"] == {
        "daily_minutes": 75,
        "provenance": "user_provided",
        "accepted": True,
    }


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("attachment_mode", "expected_draft_kind"),
    [
        ("draft_phase", "existing_plan_phase"),
        ("scheduled_work", "existing_plan_scheduled_work"),
    ],
)
async def test_existing_plan_handoff_persists_draft_phase_and_scheduled_work_targets(
    db,
    attachment_mode,
    expected_draft_kind,
):
    from src.study_plan.intake import confirm_intake_route, create_intake_item

    cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Backend Study Project', 'study_project', 'sequential', 'active', 1)
        """
    )
    plan_id = int(cursor.lastrowid)
    await db.commit()
    item = await create_intake_item(
        db,
        client_request_id=f"req-{attachment_mode}-target-draft-kind",
        raw_input="Attach this work to my backend project.",
        source_type="existing_project_description",
        recommended_role="attach_to_existing_plan",
        confidence="high",
    )

    handoff = await confirm_intake_route(
        db,
        intake_item_id=item["id"],
        confirmed_role="attach_to_existing_plan",
        existing_plan_id=plan_id,
        attachment_mode=attachment_mode,
        title="Retry practice",
        metadata={"deadline": "2026-08-20", "capacity_minutes": 40},
    )

    assert handoff["nextAction"] == "handoff_to_anchor_review"
    assert handoff["outcome"] == "awaiting_anchor_review"
    assert handoff["draftId"] > 0
    assert handoff["draftKind"] == expected_draft_kind
    assert handoff["existingPlanId"] == plan_id
    assert handoff["targetPlanId"] == plan_id
    assert handoff["attachmentMode"] == attachment_mode
    assert await _fetchone(
        db,
        """
        SELECT intake_item_id, status, draft_kind, target_plan_id
        FROM study_project_drafts
        WHERE id = ?
        """,
        (handoff["draftId"],),
    ) == {
        "intake_item_id": item["id"],
        "status": "anchor_review",
        "draft_kind": expected_draft_kind,
        "target_plan_id": plan_id,
    }
    assert await _fetchall(db, "SELECT id FROM study_intake_plan_attachments") == []
    assert await _fetchall(db, "SELECT id FROM tasks") == []


@pytest.mark.asyncio
async def test_existing_plan_handoff_idempotency_respects_target_plan_id(db):
    from src.study_plan.intake import confirm_intake_route, create_intake_item

    first_cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Compiler Study Project', 'study_project', 'sequential', 'active', 1)
        """
    )
    first_plan_id = int(first_cursor.lastrowid)
    second_cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Backend Study Project', 'study_project', 'sequential', 'active', 1)
        """
    )
    second_plan_id = int(second_cursor.lastrowid)
    await db.commit()
    item = await create_intake_item(
        db,
        client_request_id="req-existing-plan-retarget-draft",
        raw_input="Attach retry practice to the selected project.",
        source_type="existing_project_description",
        recommended_role="attach_to_existing_plan",
        confidence="high",
    )

    first = await confirm_intake_route(
        db,
        intake_item_id=item["id"],
        confirmed_role="attach_to_existing_plan",
        existing_plan_id=first_plan_id,
        attachment_mode="scheduled_work",
        title="Retry practice",
        metadata={"deadline": "2026-08-20", "capacity_minutes": 40},
    )
    second = await confirm_intake_route(
        db,
        intake_item_id=item["id"],
        confirmed_role="attach_to_existing_plan",
        existing_plan_id=second_plan_id,
        attachment_mode="scheduled_work",
        title="Retry practice",
        metadata={"deadline": "2026-08-21", "capacity_minutes": 40},
    )

    assert first["draftId"] != second["draftId"]
    assert first["targetPlanId"] == first_plan_id
    assert second["targetPlanId"] == second_plan_id
    assert await _fetchall(
        db,
        """
        SELECT id, target_plan_id
        FROM study_project_drafts
        WHERE intake_item_id = ?
        ORDER BY id
        """,
        (item["id"],),
    ) == [
        {"id": first["draftId"], "target_plan_id": first_plan_id},
        {"id": second["draftId"], "target_plan_id": second_plan_id},
    ]


@pytest.mark.asyncio
async def test_api_route_contract_and_canonical_repo_role_are_separate(client):
    response = await client.post(
        "/api/study-intake/route",
        json={
            "clientRequestId": "req-api-contract",
            "rawInput": "https://github.com/example/app rebuild this as a clone project",
            "sourceType": "github_repo",
            "userHint": "clone/rebuild target, make a new study plan",
        },
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["intakeItemId"]
    assert payload["recommendedRole"] == "new_plan"
    assert payload["canonicalRepoRole"] == "clone_rebuild_target"
    assert payload["canonicalRepoRole"] != payload["recommendedRole"]
    assert payload["createsActiveTasks"] is False
    assert payload["nextAction"] == "role_review"
    assert payload["reasonCodes"]
    assert payload["confidence"] in {"high", "medium"}


@pytest.mark.asyncio
async def test_api_route_accepts_existing_plan_id_as_selected_target(client):
    import os

    import aiosqlite

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        first_cursor = await db.execute(
            """
            INSERT INTO resources (title, type, tracking_mode, status, total_units)
            VALUES ('Compiler Study Project', 'study_project', 'sequential', 'active', 1)
            """
        )
        first_id = int(first_cursor.lastrowid)
        second_cursor = await db.execute(
            """
            INSERT INTO resources (title, type, tracking_mode, status, total_units)
            VALUES ('Backend Study Project', 'study_project', 'sequential', 'active', 1)
            """
        )
        second_id = int(second_cursor.lastrowid)
        await db.commit()

    response = await client.post(
        "/api/study-intake/route",
        json={
            "clientRequestId": "req-api-existing-plan-target",
            "rawInput": "Attach these parser notes to my existing compiler project.",
            "sourceType": "pasted_note",
            "existingPlanId": second_id,
        },
    )

    assert first_id != second_id
    assert response.status_code == 200
    payload = response.json()
    assert payload["recommendedRole"] == "attach_to_existing_plan"
    assert payload["existingPlanCandidates"] == [
        {"id": second_id, "title": "Backend Study Project"}
    ]
    assert payload["existingPlanId"] == second_id
    assert payload["nextAction"] == "role_review"
    assert payload["createsActiveTasks"] is False


@pytest.mark.asyncio
async def test_api_route_invalid_existing_plan_id_returns_400_without_intake_row(client):
    import os

    import aiosqlite

    client_request_id = "req-api-invalid-existing-plan-target"
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        cursor = await db.execute(
            """
            INSERT INTO resources (title, type, tracking_mode, status, total_units)
            VALUES ('Archived Study Project', 'study_project', 'sequential', 'archived', 1)
            """
        )
        archived_plan_id = int(cursor.lastrowid)
        await db.commit()

    response = await client.post(
        "/api/study-intake/route",
        json={
            "clientRequestId": client_request_id,
            "rawInput": "Attach these parser notes to my existing archived project.",
            "sourceType": "pasted_note",
            "existingPlanId": archived_plan_id,
        },
    )

    assert response.status_code == 400
    assert "active study plan" in response.json()["detail"]

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        async with db.execute(
            "SELECT id FROM study_intake_items WHERE client_request_id = ?",
            (client_request_id,),
        ) as cursor:
            rows = await cursor.fetchall()

    assert rows == []


@pytest.mark.asyncio
async def test_api_route_invalid_existing_plan_id_for_non_attach_returns_400_without_intake_row(
    client,
):
    import os

    import aiosqlite

    client_request_id = "req-api-invalid-existing-plan-non-attach"
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        cursor = await db.execute(
            """
            INSERT INTO resources (title, type, tracking_mode, status, total_units)
            VALUES ('Archived Study Project', 'study_project', 'sequential', 'archived', 1)
            """
        )
        archived_plan_id = int(cursor.lastrowid)
        await db.commit()

    response = await client.post(
        "/api/study-intake/route",
        json={
            "clientRequestId": client_request_id,
            "rawInput": "Learn FastAPI by June 30",
            "sourceType": "text_goal",
            "existingPlanId": archived_plan_id,
        },
    )

    assert response.status_code == 400
    assert "active study plan" in response.json()["detail"]

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        async with db.execute(
            "SELECT id FROM study_intake_items WHERE client_request_id = ?",
            (client_request_id,),
        ) as cursor:
            rows = await cursor.fetchall()

    assert rows == []


@pytest.mark.asyncio
async def test_empty_metadata_round_trips_for_intake_children(db):
    from src.study_plan.intake import (
        attach_material_to_plan,
        confirm_non_plan_resource,
        create_intake_item,
    )

    project_cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Existing Study Project', 'study_project', 'sequential', 'active', 1)
        """
    )
    project_id = int(project_cursor.lastrowid)
    await db.commit()

    reference = await create_intake_item(
        db,
        client_request_id="req-reference-empty-metadata",
        raw_input="Save this reference with empty metadata.",
        source_type="text_goal",
        recommended_role="reference_material",
        confidence="high",
    )
    material = await create_intake_item(
        db,
        client_request_id="req-material-empty-metadata",
        raw_input="Attach this material with empty metadata.",
        source_type="pasted_note",
        recommended_role="attach_to_existing_plan",
        confidence="high",
    )

    resource = await confirm_non_plan_resource(
        db,
        intake_item_id=reference["id"],
        role="reference_material",
        title="Reference with empty metadata",
        metadata={},
    )
    attachment = await attach_material_to_plan(
        db,
        intake_item_id=material["id"],
        target_plan_id=project_id,
        attachment_mode="material_only",
        title="Attachment with empty metadata",
        metadata={},
    )

    assert resource["metadata"] == {}
    assert attachment["metadata"] == {}


@pytest.mark.asyncio
async def test_github_preview_returns_shallow_metadata_without_active_structure(monkeypatch):
    import base64

    from src.study_plan.intake_preview import preview_github_repo

    readme = """# Build a Tiny Compiler

## Overview
Intro material.

## Parser
Parsing notes.

## Code Generation
Backend notes.
"""
    fake_client = _GitHubClient(
        {
            "/repos/acme/compiler-course/readme": _GitHubResponse(
                200,
                {
                    "encoding": "base64",
                    "content": base64.b64encode(readme.encode()).decode(),
                },
            ),
            "/repos/acme/compiler-course/git/trees/HEAD": _GitHubResponse(
                200,
                {
                    "tree": [
                        {"path": "src", "type": "tree"},
                        {"path": "docs", "type": "tree"},
                        {"path": "lessons", "type": "tree"},
                        {"path": "lessons/01-parser", "type": "tree"},
                    ]
                },
            ),
            "/repos/acme/compiler-course": _GitHubResponse(
                200,
                {
                    "full_name": "acme/compiler-course",
                    "description": "Clone and rebuild a tiny compiler workshop",
                    "topics": ["compiler", "workshop"],
                },
            ),
        }
    )
    monkeypatch.setattr(
        "src.handlers.github_handler.httpx.AsyncClient",
        lambda: fake_client,
    )

    preview = await preview_github_repo(
        "https://github.com/acme/compiler-course",
        user_hint="I want to clone and rebuild this project",
    )

    assert preview.title == "acme/compiler-course"
    assert preview.description == "Clone and rebuild a tiny compiler workshop"
    assert preview.source_type == "github_repo"
    assert preview.url == "https://github.com/acme/compiler-course"
    assert preview.readme_outline == ["Overview", "Parser", "Code Generation"]
    assert preview.topics == ["compiler", "workshop"]
    assert preview.coarse_directory_signals == ["docs", "lessons", "src"]
    assert preview.fetch_status == "available"
    assert preview.calibration == "medium"
    assert preview.canonical_repo_role == "clone_rebuild_target"
    assert not hasattr(preview, "units")


@pytest.mark.asyncio
async def test_github_preview_fetch_failure_returns_low_calibration_unknowns(monkeypatch):
    from src.study_plan.intake_preview import preview_github_repo

    fake_client = _GitHubClient({})
    monkeypatch.setattr(
        "src.handlers.github_handler.httpx.AsyncClient",
        lambda: fake_client,
    )

    preview = await preview_github_repo("https://github.com/acme/missing-course")

    assert preview.title == "acme/missing-course"
    assert preview.description is None
    assert preview.readme_outline == []
    assert preview.topics == []
    assert preview.coarse_directory_signals == []
    assert preview.fetch_status == "unavailable"
    assert preview.calibration == "low"
    assert preview.canonical_repo_role is None
    assert not hasattr(preview, "units")


@pytest.mark.asyncio
async def test_github_preview_does_not_fabricate_structure_or_call_llm(monkeypatch):
    from src.study_plan.intake_preview import preview_github_repo

    async def fail_if_called(*args, **kwargs):
        raise AssertionError("preview must not use LLM fallback")

    fake_client = _GitHubClient(
        {
            "/repos/acme/name-only/readme": _GitHubResponse(404, {}),
            "/repos/acme/name-only/git/trees/HEAD": _GitHubResponse(200, {"tree": []}),
            "/repos/acme/name-only": _GitHubResponse(
                200,
                {
                    "full_name": "acme/name-only",
                    "description": None,
                    "topics": [],
                },
            ),
        }
    )
    monkeypatch.setattr(
        "src.handlers.github_handler.httpx.AsyncClient",
        lambda: fake_client,
    )
    monkeypatch.setattr("src.handlers.github_handler._llm_fallback", fail_if_called)
    monkeypatch.setattr("src.handlers.github_handler._llm_parse_readme", fail_if_called)

    preview = await preview_github_repo("https://github.com/acme/name-only")

    assert preview.title == "acme/name-only"
    assert preview.readme_outline == []
    assert preview.coarse_directory_signals == []
    assert preview.calibration == "low"
    assert preview.canonical_repo_role is None
    assert not hasattr(preview, "units")


@pytest.mark.asyncio
async def test_legacy_github_fallback_marks_generated_unit_synthetic(monkeypatch):
    from src.handlers.github_handler import GitHubHandler

    fake_client = _GitHubClient({})
    monkeypatch.setattr(
        "src.handlers.github_handler.httpx.AsyncClient",
        lambda: fake_client,
    )

    structure = await GitHubHandler("https://github.com/acme/name-only").fetch()

    assert len(structure.units) == 1
    assert structure.units[0].title == "name-only"
    assert structure.units[0].is_synthetic is True
    assert structure.units[0].calibration == "low"


@pytest.mark.asyncio
async def test_github_preview_user_hint_takes_precedence_over_metadata_and_readme(monkeypatch):
    import base64

    from src.study_plan.intake_preview import preview_github_repo

    readme = "## Tutorial\nLearn this workshop as a full course."
    fake_client = _GitHubClient(
        {
            "/repos/acme/mixed-signals/readme": _GitHubResponse(
                200,
                {
                    "encoding": "base64",
                    "content": base64.b64encode(readme.encode()).decode(),
                },
            ),
            "/repos/acme/mixed-signals/git/trees/HEAD": _GitHubResponse(200, {"tree": []}),
            "/repos/acme/mixed-signals": _GitHubResponse(
                200,
                {
                    "full_name": "acme/mixed-signals",
                    "description": "Documentation tutorial for learning later",
                    "topics": ["tutorial"],
                },
            ),
        }
    )
    monkeypatch.setattr(
        "src.handlers.github_handler.httpx.AsyncClient",
        lambda: fake_client,
    )

    preview = await preview_github_repo(
        "https://github.com/acme/mixed-signals",
        user_hint="Use this as material for my existing project",
    )

    assert preview.canonical_repo_role == "project_material"


@pytest.mark.asyncio
async def test_github_preview_marks_partial_when_only_some_sources_succeed(monkeypatch):
    import base64

    from src.study_plan.intake_preview import preview_github_repo

    readme = "## Notes\nReference material."
    fake_client = _GitHubClient(
        {
            "/repos/acme/partial/readme": _GitHubResponse(
                200,
                {
                    "encoding": "base64",
                    "content": base64.b64encode(readme.encode()).decode(),
                },
            ),
            "/repos/acme/partial/git/trees/HEAD": _GitHubResponse(404, {}),
            "/repos/acme/partial": _GitHubResponse(
                200,
                {
                    "full_name": "acme/partial",
                    "description": "Reference source",
                    "topics": [],
                },
            ),
        }
    )
    monkeypatch.setattr(
        "src.handlers.github_handler.httpx.AsyncClient",
        lambda: fake_client,
    )

    preview = await preview_github_repo("https://github.com/acme/partial")

    assert preview.fetch_status == "partial"
    assert preview.description == "Reference source"
    assert preview.readme_outline == ["Notes"]
    assert preview.coarse_directory_signals == []


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("user_hint", "expected_role"),
    [
        ("This is the main repo I want to learn", "main_learning_object"),
        ("Keep this as API documentation reference", "reference_source"),
        ("I want to clone and rebuild this app", "clone_rebuild_target"),
        ("Attach as material for my existing project", "project_material"),
        ("Bookmark this for later reading", "later_reading"),
    ],
)
async def test_github_preview_covers_all_canonical_repo_roles(
    monkeypatch,
    user_hint,
    expected_role,
):
    from src.study_plan.intake_preview import preview_github_repo

    fake_client = _GitHubClient(
        {
            "/repos/acme/role-case/readme": _GitHubResponse(404, {}),
            "/repos/acme/role-case/git/trees/HEAD": _GitHubResponse(404, {}),
            "/repos/acme/role-case": _GitHubResponse(
                200,
                {
                    "full_name": "acme/role-case",
                    "description": "Generic repository",
                    "topics": [],
                },
            ),
        }
    )
    monkeypatch.setattr(
        "src.handlers.github_handler.httpx.AsyncClient",
        lambda: fake_client,
    )

    preview = await preview_github_repo("https://github.com/acme/role-case", user_hint=user_hint)

    assert preview.canonical_repo_role == expected_role
