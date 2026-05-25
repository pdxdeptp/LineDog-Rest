"""Study intake data/idempotency tests."""

from datetime import date

import pytest


async def _fetchall(db, sql: str, params: tuple = ()) -> list[dict]:
    async with db.execute(sql, params) as cursor:
        rows = await cursor.fetchall()
        return [dict(row) for row in rows]


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
