"""Study plan API router tests."""

import os

import aiosqlite
import pytest


async def _fetchone(sql: str, params: tuple = ()) -> dict | None:
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(sql, params) as cursor:
            row = await cursor.fetchone()
    return dict(row) if row else None


async def _fetchall(sql: str, params: tuple = ()) -> list[dict]:
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(sql, params) as cursor:
            rows = await cursor.fetchall()
    return [dict(row) for row in rows]


async def _insert_active_task_load(
    *,
    scheduled_date: str,
    target_minutes: int = 30,
) -> None:
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        resource_cursor = await db.execute(
            """
            INSERT INTO resources (title, type, tracking_mode, status, total_units)
            VALUES ('Existing Study Project', 'study_project', 'sequential', 'active', 1)
            """
        )
        resource_id = int(resource_cursor.lastrowid)
        unit_cursor = await db.execute(
            """
            INSERT INTO units (resource_id, title, order_index, estimated_minutes, status)
            VALUES (?, 'Existing Unit', 0, ?, 'pending')
            """,
            (resource_id, target_minutes),
        )
        unit_id = int(unit_cursor.lastrowid)
        await db.execute(
            """
            INSERT INTO tasks
                (unit_id, resource_id, title, target_minutes, scheduled_date,
                 originally_scheduled_date, completed_at)
            VALUES (?, ?, 'Existing Task', ?, ?, ?, NULL)
            """,
            (unit_id, resource_id, target_minutes, scheduled_date, scheduled_date),
        )
        await db.commit()


async def _start_draft(client, *, deadline: str = "2026-06-30", capacity: int = 60) -> int:
    response = await client.post(
        "/api/study-plan/start",
        json={
            "url": "https://example.com/distributed-systems-primer",
            "deadline": deadline,
            "capacity_minutes": capacity,
        },
    )
    assert response.status_code == 200
    return response.json()["draft_id"]


async def _submit_skipped_clarification(client, draft_id: int) -> dict:
    response = await client.post(
        f"/api/study-plan/drafts/{draft_id}/clarification",
        json={"answers": {}, "clarification_skipped": True},
    )
    assert response.status_code == 200
    return response.json()


async def _draft_task_rows(draft_id: int) -> list[dict]:
    return await _fetchall(
        """
        SELECT title, order_index, estimated_minutes, scheduled_date, target_minutes
        FROM study_project_draft_tasks
        WHERE draft_id = ?
        ORDER BY order_index
        """,
        (draft_id,),
    )


@pytest.mark.asyncio
async def test_main_lifespan_registers_study_plan_start_route(client):
    from src.main import app

    paths = {getattr(route, "path", None) for route in app.routes}

    assert "/api/study-plan/start" in paths


@pytest.mark.asyncio
async def test_start_endpoint_returns_review_draft_and_clarification_without_active_resources(client):
    response = await client.post(
        "/api/study-plan/start",
        json={
            "url": "https://example.com/distributed-systems-primer",
            "deadline": "2026-06-30",
            "capacity_minutes": 75,
        },
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["draft_id"] > 0
    assert payload["clarification"]["version"] == "d30-guided-clarification-v1"
    assert len(payload["clarification"]["questions"]) <= 3
    assert payload["clarification"]["skip_action"]["uses_defaults"] is True

    draft = await _fetchone(
        """
        SELECT source_url, deadline, status, capacity_minutes, clarification_skipped
        FROM study_project_drafts
        WHERE id = ?
        """,
        (payload["draft_id"],),
    )
    assert draft == {
        "source_url": "https://example.com/distributed-systems-primer",
        "deadline": "2026-06-30",
        "status": "review",
        "capacity_minutes": 75,
        "clarification_skipped": 0,
    }
    assert await _fetchall(
        "SELECT id FROM study_project_draft_tasks WHERE draft_id = ?",
        (payload["draft_id"],),
    ) == []
    assert await _fetchall("SELECT id FROM resources WHERE status = 'active'") == []
    assert await _fetchall("SELECT id FROM tasks") == []


@pytest.mark.asyncio
async def test_submit_clarification_returns_review_draft_tasks_and_low_calibration_when_skipped(client):
    draft_id = await _start_draft(client, capacity=45)

    draft = await _submit_skipped_clarification(client, draft_id)

    assert draft["id"] == draft_id
    assert draft["status"] == "review"
    assert draft["source_url"] == "https://example.com/distributed-systems-primer"
    assert draft["clarification_skipped"] is True
    assert draft["low_calibration"] is True
    assert draft["expected_late"] is False
    assert draft["over_capacity_days"] == []
    assert [task["order_index"] for task in draft["tasks"]] == list(range(len(draft["tasks"])))
    assert [task["title"] for task in draft["tasks"]] == [
        "Review Distributed Systems Primer overview",
        "Practice Distributed Systems Primer application",
    ]

    stored_tasks = await _fetchall(
        """
        SELECT title, order_index, estimated_minutes, scheduled_date, target_minutes
        FROM study_project_draft_tasks
        WHERE draft_id = ?
        ORDER BY order_index
        """,
        (draft_id,),
    )
    assert stored_tasks == draft["tasks"]
    assert await _fetchall("SELECT id FROM resources WHERE status = 'active'") == []
    assert await _fetchall("SELECT id FROM tasks") == []


@pytest.mark.asyncio
async def test_submit_clarification_marks_existing_load_over_capacity_without_reshuffling(client):
    control_draft_id = await _start_draft(client, capacity=45)
    control = await _submit_skipped_clarification(client, control_draft_id)
    expected_dates = [task["scheduled_date"] for task in control["tasks"]]
    existing_date = expected_dates[0]
    await _insert_active_task_load(scheduled_date=existing_date, target_minutes=30)

    draft_id = await _start_draft(client, capacity=45)
    draft = await _submit_skipped_clarification(client, draft_id)

    assert [task["scheduled_date"] for task in draft["tasks"]] == expected_dates
    assert draft["over_capacity_days"] == [
        {
            "date": existing_date,
            "scheduled_minutes": 45,
            "existing_minutes": 30,
            "capacity_minutes": 45,
            "over_by_minutes": 30,
        }
    ]


@pytest.mark.asyncio
async def test_submit_clarification_returns_409_without_tasks_when_draft_stales_before_persist(
    client,
    monkeypatch,
):
    from src.routers import study_plan as router_module

    draft_id = await _start_draft(client, capacity=45)
    original_replace = router_module._replace_draft_tasks

    async def cancel_before_replace(db, target_draft_id, tasks):
        if target_draft_id == draft_id:
            await db.execute(
                "UPDATE study_project_drafts SET status = 'cancelled' WHERE id = ?",
                (draft_id,),
            )
        await original_replace(db, target_draft_id, tasks)

    monkeypatch.setattr(router_module, "_replace_draft_tasks", cancel_before_replace)

    response = await client.post(
        f"/api/study-plan/drafts/{draft_id}/clarification",
        json={"answers": {}, "clarification_skipped": True},
    )
    stored_tasks = await _draft_task_rows(draft_id)

    assert (response.status_code, stored_tasks) == (409, [])


@pytest.mark.asyncio
async def test_duration_update_recomputes_review_draft_schedule_without_confirming(client):
    draft_id = await _start_draft(client, deadline="2026-06-02", capacity=50)
    initial_draft = await _submit_skipped_clarification(client, draft_id)
    existing_date = initial_draft["tasks"][0]["scheduled_date"]
    await _insert_active_task_load(scheduled_date=existing_date, target_minutes=30)

    response = await client.put(
        f"/api/study-plan/drafts/{draft_id}/tasks/0/duration",
        json={"estimated_minutes": 90},
    )

    assert response.status_code == 200
    draft = response.json()
    assert draft["status"] == "review"
    assert draft["tasks"][0]["estimated_minutes"] == 90
    assert draft["tasks"][0]["target_minutes"] == 90
    assert isinstance(draft["expected_late"], bool)
    assert draft["over_capacity_days"] == [
        {
            "date": existing_date,
            "scheduled_minutes": 90,
            "existing_minutes": 30,
            "capacity_minutes": 50,
            "over_by_minutes": 70,
        }
    ]
    assert draft["tasks"][0]["scheduled_date"] == existing_date

    stored_task = await _fetchone(
        """
        SELECT estimated_minutes, target_minutes
        FROM study_project_draft_tasks
        WHERE draft_id = ? AND order_index = 0
        """,
        (draft_id,),
    )
    assert stored_task == {"estimated_minutes": 90, "target_minutes": 90}


@pytest.mark.asyncio
async def test_duration_update_returns_409_without_replacing_tasks_when_draft_stales_before_persist(
    client,
    monkeypatch,
):
    from src.routers import study_plan as router_module

    draft_id = await _start_draft(client, deadline="2026-06-02", capacity=50)
    await _submit_skipped_clarification(client, draft_id)
    original_tasks = await _draft_task_rows(draft_id)
    original_replace = router_module._replace_draft_tasks

    async def confirm_before_replace(db, target_draft_id, tasks):
        if target_draft_id == draft_id:
            await db.execute(
                "UPDATE study_project_drafts SET status = 'confirmed' WHERE id = ?",
                (draft_id,),
            )
        await original_replace(db, target_draft_id, tasks)

    monkeypatch.setattr(router_module, "_replace_draft_tasks", confirm_before_replace)

    response = await client.put(
        f"/api/study-plan/drafts/{draft_id}/tasks/0/duration",
        json={"estimated_minutes": 90},
    )
    stored_tasks = await _draft_task_rows(draft_id)

    assert (response.status_code, stored_tasks) == (409, original_tasks)


@pytest.mark.asyncio
async def test_cancel_endpoint_marks_draft_cancelled_without_active_resources_or_tasks(client):
    draft_id = await _start_draft(client)

    response = await client.post(f"/api/study-plan/drafts/{draft_id}/cancel")

    assert response.status_code == 200
    payload = response.json()
    assert payload["id"] == draft_id
    assert payload["status"] == "cancelled"
    assert await _fetchall("SELECT id FROM resources WHERE status = 'active'") == []
    assert await _fetchall("SELECT id FROM tasks") == []


@pytest.mark.asyncio
async def test_confirm_endpoint_creates_active_resource_and_tasks_only_after_confirmation(client):
    draft_id = await _start_draft(client, capacity=45)
    draft = await _submit_skipped_clarification(client, draft_id)
    assert await _fetchall("SELECT id FROM resources WHERE status = 'active'") == []
    assert await _fetchall("SELECT id FROM tasks") == []

    response = await client.post(f"/api/study-plan/drafts/{draft_id}/confirm")

    assert response.status_code == 200
    payload = response.json()
    assert payload["id"] == draft_id
    assert payload["status"] == "active"
    assert payload["source_url"] == "https://example.com/distributed-systems-primer"
    assert payload["deadline"] == "2026-06-30"
    assert payload["capacity_minutes"] == 45
    assert payload["clarification_skipped"] is True
    assert payload["resource_id"] > 0

    resource = await _fetchone(
        """
        SELECT type, tracking_mode, url, status, total_units, deadline
        FROM resources
        WHERE id = ?
        """,
        (payload["resource_id"],),
    )
    assert resource == {
        "type": "study_project",
        "tracking_mode": "sequential",
        "url": "https://example.com/distributed-systems-primer",
        "status": "active",
        "total_units": len(draft["tasks"]),
        "deadline": "2026-06-30",
    }
    active_tasks = await _fetchall(
        """
        SELECT title, target_minutes, scheduled_date
        FROM tasks
        WHERE resource_id = ?
        ORDER BY id
        """,
        (payload["resource_id"],),
    )
    assert len(active_tasks) == len(draft["tasks"])
    assert [task["title"] for task in active_tasks] == [task["title"] for task in draft["tasks"]]
