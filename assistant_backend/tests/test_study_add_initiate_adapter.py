"""Add / Initiate orchestration adapter contract tests."""

import pytest


async def _fetchall(db, sql: str, params: tuple = ()) -> list[dict]:
    async with db.execute(sql, params) as cursor:
        rows = await cursor.fetchall()
        return [dict(row) for row in rows]


async def _make_add_initiate_review_draft(db, client_request_id: str = "req-review-draft"):
    from src.study_plan.add_initiate import (
        confirm_add_initiate_anchors,
        confirm_add_initiate_role,
        start_add_initiate_session,
    )

    started = await start_add_initiate_session(
        db,
        client_request_id=client_request_id,
        raw_input="Learn caching by 2026-08-01.",
        source_type="text_goal",
    )
    role = await confirm_add_initiate_role(
        db,
        session_id=started["sessionId"],
        intake_item_id=started["intakeItemId"],
        confirmed_role="new_plan",
        title="Learn Caching",
        metadata={"deadline": "2026-08-01", "capacity_minutes": 45},
    )
    review = await confirm_add_initiate_anchors(
        db,
        session_id=started["sessionId"],
        draft_id=role["draftId"],
        deadline="2026-08-01",
        deadline_type="hard",
        capacity_minutes=45,
        target_output="caching notes",
        target_depth="apply",
        assumptions={"deadline": {"accepted": True}},
        compiler=lambda anchor_request: {
            "schema_version": 1,
            "status": "draft_review",
            "summary": "Caching plan",
            "assumptions": anchor_request["assumptions"],
            "tasks": [
                {
                    "id": "task-1",
                    "title": "Read caching notes",
                    "estimated_minutes": 45,
                    "schedule_slices": [{"date": "2026-07-01", "target_minutes": 45}],
                }
            ],
        },
        scheduler=lambda package, **kwargs: {
            **package,
            "status": "draft_review",
            "activation_eligibility": {
                "activation_ready": True,
                "schedule_version": "sched-v1",
            },
        },
    )
    return started, role, review


@pytest.mark.asyncio
async def test_add_initiate_start_session_tracks_identity_progress_and_no_active_tasks(db):
    from src.study_plan.add_initiate import (
        ADD_INITIATE_PROGRESS_STAGES,
        AddInitiateProgressBuffer,
        start_add_initiate_session,
    )

    progress = AddInitiateProgressBuffer()

    response = await start_add_initiate_session(
        db,
        client_request_id="req-add-initiate-session",
        raw_input="Build a deadline-driven backend interview prep plan by August 1.",
        source_type="interview_prep",
        progress=progress,
    )

    assert response["sessionId"] == "add-initiate-1"
    assert response["clientRequestId"] == "req-add-initiate-session"
    assert response["intakeItemId"] == 1
    assert response["recommendedRole"] == "new_plan"
    assert response["reviewState"] == "role_review"
    assert response["stage"] == "role_review"
    assert response["createsActiveTasks"] is False
    assert "routing_item" in ADD_INITIATE_PROGRESS_STAGES

    events = progress.events_for("add-initiate-1")
    assert [event["stage"] for event in events] == [
        "analyzing_input",
        "routing_item",
        "role_review",
    ]
    assert all(event["sessionId"] == "add-initiate-1" for event in events)
    assert all(event["createsActiveTasks"] is False for event in events)
    assert await _fetchall(db, "SELECT id FROM tasks") == []


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("raw_input", "source_type", "expected_role"),
    [
        (
            "Keep this as reference material: https://docs.python.org/3/library/asyncio.html",
            "url",
            "reference_material",
        ),
        (
            "Save this repo for later reading: https://github.com/example/later",
            "github_repo",
            "later_resource",
        ),
    ],
)
async def test_add_initiate_start_session_uses_canonical_stored_non_plan_stage(
    db,
    raw_input,
    source_type,
    expected_role,
):
    from src.study_plan.add_initiate import start_add_initiate_session

    response = await start_add_initiate_session(
        db,
        client_request_id=f"req-add-initiate-{expected_role}",
        raw_input=raw_input,
        source_type=source_type,
    )

    assert response["recommendedRole"] == expected_role
    assert response["stage"] == "stored_non_plan"
    assert response["reviewState"] == "stored_non_plan"
    assert response["nextAction"] == "confirm_non_plan_storage"
    assert response["createsActiveTasks"] is False
    assert await _fetchall(db, "SELECT id FROM tasks") == []


@pytest.mark.asyncio
async def test_add_initiate_start_session_ambiguous_route_returns_needs_input(db):
    from src.study_plan.add_initiate import start_add_initiate_session

    response = await start_add_initiate_session(
        db,
        client_request_id="req-add-initiate-ambiguous",
        raw_input="Maybe put this somewhere for the compiler thing.",
        source_type="unknown",
    )

    assert response["recommendedRole"] == "later_resource"
    assert response["confidence"] == "low"
    assert response["stage"] == "needs_input"
    assert response["reviewState"] == "needs_input"
    assert response["clarificationQuestion"]["prompt"].count("?") == 1
    assert response["createsActiveTasks"] is False
    assert await _fetchall(db, "SELECT id FROM tasks") == []


@pytest.mark.asyncio
async def test_add_initiate_role_anchor_option_and_activation_contract_wraps_helpers(db):
    from src.study_plan.add_initiate import (
        AddInitiateProgressBuffer,
        activate_add_initiate_draft,
        apply_add_initiate_option_effect,
        confirm_add_initiate_anchors,
        confirm_add_initiate_role,
        start_add_initiate_session,
    )

    progress = AddInitiateProgressBuffer()
    started = await start_add_initiate_session(
        db,
        client_request_id="req-add-initiate-plan",
        raw_input="Learn FastAPI by 2026-08-01.",
        source_type="text_goal",
        progress=progress,
    )

    role = await confirm_add_initiate_role(
        db,
        session_id=started["sessionId"],
        intake_item_id=started["intakeItemId"],
        confirmed_role="new_plan",
        title="Learn FastAPI",
        metadata={"deadline": "2026-08-01", "capacity_minutes": 45},
        progress=progress,
    )

    assert role["sessionId"] == started["sessionId"]
    assert role["reviewState"] == "anchor_review"
    assert role["draftId"]
    assert role["draftVersion"] == 1
    assert role["createsActiveTasks"] is False

    calls: list[str] = []

    def compiler(anchor_request):
        calls.append("compiler")
        return {
            "schema_version": 1,
            "status": "draft_review",
            "summary": "FastAPI plan",
            "assumptions": anchor_request["assumptions"],
            "phases": [],
            "tasks": [
                {
                    "id": "task-1",
                    "title": "Read routing docs",
                    "estimated_minutes": 45,
                    "classification": "essential",
                    "schedule_slices": [
                        {
                            "date": "2026-07-01",
                            "target_minutes": 45,
                        }
                    ],
                }
            ],
        }

    def scheduler(package, **kwargs):
        calls.append("scheduler")
        updated = dict(package)
        updated["status"] = "draft_review"
        updated["review_summary"] = {"deadline_fit": "on_track"}
        updated["activation_eligibility"] = {
            "activation_ready": True,
            "schedule_version": "sched-v1",
        }
        return updated

    review = await confirm_add_initiate_anchors(
        db,
        session_id=started["sessionId"],
        draft_id=role["draftId"],
        deadline="2026-08-01",
        deadline_type="hard",
        capacity_minutes=45,
        target_output="working FastAPI notes",
        target_depth="apply",
        assumptions={"deadline": {"accepted": True}},
        compiler=compiler,
        scheduler=scheduler,
        progress=progress,
    )

    assert calls == ["compiler", "scheduler"]
    assert review["reviewState"] == "draft_review"
    assert review["draftId"] == role["draftId"]
    assert review["draftVersion"] == 1
    assert review["createsActiveTasks"] is False
    assert "generating_phases" in [event["stage"] for event in progress.events_for(started["sessionId"])]
    assert await _fetchall(db, "SELECT id FROM tasks") == []

    activated = await activate_add_initiate_draft(
        db,
        session_id=started["sessionId"],
        draft_id=role["draftId"],
        draft_version=review["draftVersion"],
        progress=progress,
    )

    assert activated["reviewState"] == "activated"
    assert activated["createsActiveTasks"] is True
    assert activated["draftId"] == role["draftId"]
    assert activated["draftVersion"] == 1
    assert await _fetchall(db, "SELECT id FROM tasks") == [{"id": 1}]


@pytest.mark.asyncio
async def test_add_initiate_stale_option_effect_is_not_activation_failure(db):
    from src.study_plan.add_initiate import (
        apply_add_initiate_option_effect,
        confirm_add_initiate_anchors,
        confirm_add_initiate_role,
        start_add_initiate_session,
    )

    started = await start_add_initiate_session(
        db,
        client_request_id="req-add-initiate-stale-option",
        raw_input="Learn caching by 2026-08-01.",
        source_type="text_goal",
    )
    role = await confirm_add_initiate_role(
        db,
        session_id=started["sessionId"],
        intake_item_id=started["intakeItemId"],
        confirmed_role="new_plan",
        title="Learn Caching",
        metadata={"deadline": "2026-08-01", "capacity_minutes": 45},
    )

    def compiler(anchor_request):
        return {
            "schema_version": 1,
            "status": "draft_review",
            "summary": "Caching plan",
            "assumptions": anchor_request["assumptions"],
            "tasks": [
                {
                    "id": "task-1",
                    "title": "Read caching notes",
                    "estimated_minutes": 45,
                    "schedule_slices": [{"date": "2026-07-01", "target_minutes": 45}],
                }
            ],
        }

    review = await confirm_add_initiate_anchors(
        db,
        session_id=started["sessionId"],
        draft_id=role["draftId"],
        deadline="2026-08-01",
        deadline_type="hard",
        capacity_minutes=45,
        target_output="caching notes",
        target_depth="apply",
        assumptions={"deadline": {"accepted": True}},
        compiler=compiler,
        scheduler=lambda package, **kwargs: {
            **package,
            "status": "draft_review",
            "activation_eligibility": {
                "activation_ready": True,
                "schedule_version": "sched-v1",
            },
        },
    )

    with pytest.raises(ValueError, match="stale draft option requested"):
        await apply_add_initiate_option_effect(
            db,
            session_id=started["sessionId"],
            draft_id=role["draftId"],
            draft_version=review["draftVersion"] - 1,
            option_id="reduce_scope",
        )
    assert await _fetchall(db, "SELECT id FROM tasks") == []


@pytest.mark.asyncio
async def test_add_initiate_option_effect_persists_new_latest_version_and_stales_old_requests(db):
    from src.study_plan.add_initiate import (
        activate_add_initiate_draft,
        apply_add_initiate_option_effect,
        confirm_add_initiate_anchors,
        confirm_add_initiate_role,
        start_add_initiate_session,
    )
    from src.study_plan.lifecycle import fetch_latest_draft_package

    started = await start_add_initiate_session(
        db,
        client_request_id="req-add-initiate-persist-option",
        raw_input="Learn caching by 2026-08-01.",
        source_type="text_goal",
    )
    role = await confirm_add_initiate_role(
        db,
        session_id=started["sessionId"],
        intake_item_id=started["intakeItemId"],
        confirmed_role="new_plan",
        title="Learn Caching",
        metadata={"deadline": "2026-08-01", "capacity_minutes": 90},
    )

    def compiler(anchor_request):
        return {
            "schema_version": 1,
            "status": "draft_review",
            "summary": "Caching plan",
            "assumptions": anchor_request["assumptions"],
            "tasks": [
                {
                    "id": "task-essential",
                    "title": "Read caching notes",
                    "estimated_minutes": 45,
                    "classification": "essential",
                    "schedule_slices": [{"date": "2026-07-01", "target_minutes": 45}],
                },
                {
                    "id": "task-optional",
                    "title": "Build optional cache demo",
                    "estimated_minutes": 30,
                    "classification": "optional",
                    "schedule_slices": [{"date": "2026-07-02", "target_minutes": 30}],
                },
            ],
        }

    review = await confirm_add_initiate_anchors(
        db,
        session_id=started["sessionId"],
        draft_id=role["draftId"],
        deadline="2026-08-01",
        deadline_type="hard",
        capacity_minutes=90,
        target_output="caching notes",
        target_depth="apply",
        assumptions={"deadline": {"accepted": True}},
        compiler=compiler,
        scheduler=lambda package, **kwargs: {
            **package,
            "status": "draft_review",
            "deadline": kwargs["deadline"],
            "deadline_type": kwargs["deadline_type"],
            "daily_capacity_min": kwargs["daily_capacity_min"],
            "activation_eligibility": {
                "activation_ready": True,
                "schedule_version": "sched-v1",
            },
        },
    )

    option = await apply_add_initiate_option_effect(
        db,
        session_id=started["sessionId"],
        draft_id=role["draftId"],
        draft_version=review["draftVersion"],
        option_id="lower_depth",
        parameters={"requested_depth": "survey"},
    )

    assert option["reviewState"] == "needs_input"
    assert option["draftVersion"] == review["draftVersion"] + 1
    latest = await fetch_latest_draft_package(db, role["draftId"])
    assert latest["draft_version"] == option["draftVersion"]
    assert latest["option_effect"]["id"] == "lower_depth"
    assert latest["compiler_recompute_required"]["reason"] == "lower_depth"

    with pytest.raises(ValueError, match="stale draft activation requested"):
        await activate_add_initiate_draft(
            db,
            session_id=started["sessionId"],
            draft_id=role["draftId"],
            draft_version=review["draftVersion"],
        )

    with pytest.raises(ValueError, match="stale draft option requested"):
        await apply_add_initiate_option_effect(
            db,
            session_id=started["sessionId"],
            draft_id=role["draftId"],
            draft_version=review["draftVersion"],
            option_id="accept_buffer_risk",
        )
    assert await _fetchall(db, "SELECT id FROM tasks") == []


@pytest.mark.asyncio
async def test_add_initiate_store_for_later_persists_recoverable_latest_without_active_tasks(db):
    from src.study_plan.add_initiate import (
        activate_add_initiate_draft,
        apply_add_initiate_option_effect,
        confirm_add_initiate_anchors,
        confirm_add_initiate_role,
        start_add_initiate_session,
    )
    from src.study_plan.lifecycle import fetch_latest_draft_package

    started = await start_add_initiate_session(
        db,
        client_request_id="req-add-initiate-store-option",
        raw_input="Learn indexes by 2026-08-01.",
        source_type="text_goal",
    )
    role = await confirm_add_initiate_role(
        db,
        session_id=started["sessionId"],
        intake_item_id=started["intakeItemId"],
        confirmed_role="new_plan",
        title="Learn Indexes",
        metadata={"deadline": "2026-08-01", "capacity_minutes": 45},
    )
    review = await confirm_add_initiate_anchors(
        db,
        session_id=started["sessionId"],
        draft_id=role["draftId"],
        deadline="2026-08-01",
        deadline_type="hard",
        capacity_minutes=45,
        target_output="index notes",
        target_depth="apply",
        assumptions={"deadline": {"accepted": True}},
        compiler=lambda anchor_request: {
            "schema_version": 1,
            "status": "draft_review",
            "summary": "Index plan",
            "assumptions": anchor_request["assumptions"],
            "tasks": [
                {
                    "id": "task-1",
                    "title": "Read index notes",
                    "estimated_minutes": 45,
                    "schedule_slices": [{"date": "2026-07-01", "target_minutes": 45}],
                }
            ],
        },
        scheduler=lambda package, **kwargs: {
            **package,
            "status": "draft_review",
            "activation_eligibility": {
                "activation_ready": True,
                "schedule_version": "sched-v1",
            },
        },
    )

    stored = await apply_add_initiate_option_effect(
        db,
        session_id=started["sessionId"],
        draft_id=role["draftId"],
        draft_version=review["draftVersion"],
        option_id="store_for_later",
    )

    assert stored["reviewState"] == "stored_non_plan"
    assert stored["draftVersion"] == review["draftVersion"] + 1
    assert stored["createsActiveTasks"] is False
    latest = await fetch_latest_draft_package(db, role["draftId"])
    assert latest["draft_version"] == stored["draftVersion"]
    assert latest["option_effect"]["id"] == "store_for_later"
    assert latest["storage_state"]["status"] == "stored_for_later"
    assert latest["activation_eligibility"]["activation_ready"] is False

    activation = await activate_add_initiate_draft(
        db,
        session_id=started["sessionId"],
        draft_id=role["draftId"],
        draft_version=stored["draftVersion"],
    )
    assert activation["reviewState"] == "activation_failed"
    assert activation["createsActiveTasks"] is False
    assert await _fetchall(db, "SELECT id FROM tasks") == []


@pytest.mark.asyncio
async def test_lifecycle_meaningful_edit_rejects_stale_expected_latest_version(db):
    from src.study_plan.lifecycle import create_meaningful_draft_edit_version

    _, role, review = await _make_add_initiate_review_draft(
        db,
        client_request_id="req-add-initiate-lifecycle-stale",
    )

    first = await create_meaningful_draft_edit_version(
        db,
        draft_id=role["draftId"],
        edit_kind="option_effect:test",
        expected_latest_version=review["draftVersion"],
        package_updates={
            "status": "draft_review",
            "summary": "first edit",
            "option_effect": {"id": "first"},
        },
    )

    assert first["draft_version"] == review["draftVersion"] + 1
    with pytest.raises(ValueError, match="stale draft option requested"):
        await create_meaningful_draft_edit_version(
            db,
            draft_id=role["draftId"],
            edit_kind="option_effect:duplicate",
            expected_latest_version=review["draftVersion"],
            package_updates={
                "status": "draft_review",
                "summary": "duplicate edit",
                "option_effect": {"id": "duplicate"},
            },
        )
    assert (await _fetchall(
        db,
        """
        SELECT latest_version
        FROM study_project_drafts
        WHERE id = ?
        """,
        (role["draftId"],),
    )) == [{"latest_version": first["draft_version"]}]


@pytest.mark.asyncio
async def test_add_initiate_mutations_reject_foreign_session_without_active_tasks(db):
    from src.study_plan.add_initiate import (
        activate_add_initiate_draft,
        apply_add_initiate_option_effect,
        confirm_add_initiate_anchors,
        confirm_add_initiate_role,
        start_add_initiate_session,
    )

    started = await start_add_initiate_session(
        db,
        client_request_id="req-add-initiate-session-owner",
        raw_input="Learn queues by 2026-08-01.",
        source_type="text_goal",
    )
    foreign_session = "add-initiate-999"

    with pytest.raises(ValueError, match="session mismatch"):
        await confirm_add_initiate_role(
            db,
            session_id=foreign_session,
            intake_item_id=started["intakeItemId"],
            confirmed_role="new_plan",
            title="Learn Queues",
            metadata={"deadline": "2026-08-01", "capacity_minutes": 45},
        )

    _, role, review = await _make_add_initiate_review_draft(
        db,
        client_request_id="req-add-initiate-session-owner-review",
    )
    with pytest.raises(ValueError, match="session mismatch"):
        await confirm_add_initiate_anchors(
            db,
            session_id=foreign_session,
            draft_id=role["draftId"],
            deadline="2026-08-01",
            deadline_type="hard",
            capacity_minutes=45,
            target_output="queue notes",
            target_depth="apply",
        )
    with pytest.raises(ValueError, match="session mismatch"):
        await apply_add_initiate_option_effect(
            db,
            session_id=foreign_session,
            draft_id=role["draftId"],
            draft_version=review["draftVersion"],
            option_id="lower_depth",
            parameters={"requested_depth": "survey"},
        )
    with pytest.raises(ValueError, match="session mismatch"):
        await activate_add_initiate_draft(
            db,
            session_id=foreign_session,
            draft_id=role["draftId"],
            draft_version=review["draftVersion"],
        )
    assert await _fetchall(db, "SELECT id FROM tasks") == []


@pytest.mark.asyncio
async def test_add_initiate_anchor_needs_input_preserves_session_without_active_tasks(db):
    from src.study_plan.add_initiate import (
        confirm_add_initiate_anchors,
        confirm_add_initiate_role,
        start_add_initiate_session,
    )

    started = await start_add_initiate_session(
        db,
        client_request_id="req-add-initiate-needs-input",
        raw_input="Maybe learn distributed systems deeply.",
        source_type="text_goal",
    )
    role = await confirm_add_initiate_role(
        db,
        session_id=started["sessionId"],
        intake_item_id=started["intakeItemId"],
        confirmed_role="new_plan",
        title="Distributed Systems",
        metadata={"deadline": "2026-08-01", "capacity_minutes": 45},
    )

    def compiler(anchor_request):
        return {
            "schema_version": 1,
            "status": "needs_input",
            "summary": "Need one depth answer.",
            "assumptions": anchor_request["assumptions"],
            "missing_input": {
                "questionId": "target_depth",
                "prompt": "How deep should this go?",
            },
        }

    response = await confirm_add_initiate_anchors(
        db,
        session_id=started["sessionId"],
        draft_id=role["draftId"],
        deadline="2026-08-01",
        deadline_type="hard",
        capacity_minutes=45,
        target_output="system design notes",
        target_depth="unknown",
        assumptions={"deadline": {"accepted": True}},
        compiler=compiler,
    )

    assert response["sessionId"] == started["sessionId"]
    assert response["draftId"] == role["draftId"]
    assert response["draftVersion"] == 1
    assert response["reviewState"] == "needs_input"
    assert response["createsActiveTasks"] is False
    assert await _fetchall(db, "SELECT id FROM tasks") == []


def test_add_initiate_progress_buffer_rejects_stale_session_and_draft_events():
    from src.study_plan.add_initiate import AddInitiateProgressBuffer

    progress = AddInitiateProgressBuffer()
    progress.record("session-new", "draft_review", draft_id=7, draft_version=2)

    accepted = progress.record_if_current(
        current_session_id="session-new",
        current_draft_id=7,
        current_draft_version=2,
        event={
            "sessionId": "session-new",
            "stage": "preparing_review",
            "draftId": 7,
            "draftVersion": 2,
        },
    )
    stale_session = progress.record_if_current(
        current_session_id="session-new",
        current_draft_id=7,
        current_draft_version=2,
        event={
            "sessionId": "session-old",
            "stage": "draft_review",
            "draftId": 7,
            "draftVersion": 2,
        },
    )
    stale_draft = progress.record_if_current(
        current_session_id="session-new",
        current_draft_id=7,
        current_draft_version=2,
        event={
            "sessionId": "session-new",
            "stage": "draft_review",
            "draftId": 7,
            "draftVersion": 1,
        },
    )

    assert accepted is True
    assert stale_session is False
    assert stale_draft is False
    assert [event["stage"] for event in progress.events_for("session-new")] == [
        "draft_review",
        "preparing_review",
    ]
