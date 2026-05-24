import json
import os
from datetime import date, timedelta

import aiosqlite
import pytest


async def _fetchall(db: aiosqlite.Connection, sql: str, params: tuple = ()) -> list[dict]:
    async with db.execute(sql, params) as cursor:
        rows = await cursor.fetchall()
    return [dict(row) for row in rows]


async def _seed_insert_project(db_path: str) -> dict[str, str]:
    today = date.today()
    scheduled_day = today + timedelta(days=2)
    existing_day = today + timedelta(days=3)
    late_day = today + timedelta(days=7)
    deadline = today + timedelta(days=5)

    async with aiosqlite.connect(db_path) as db:
        await db.execute("INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)", ("daily_capacity_min", "60"))
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                5101,
                "Task Insert Active Project",
                "study_project",
                "sequential",
                "https://example.com/insert",
                "active",
                2,
                deadline.isoformat(),
            ),
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at)
            VALUES (?, ?, ?, 'time', ?, ?, ?, ?)
            """,
            [
                (5201, 5101, "Existing first task", 25, scheduled_day.isoformat(), 9, None),
                (5202, 5101, "Existing later task", 30, existing_day.isoformat(), 8, None),
            ],
        )
        await db.commit()

    return {
        "scheduled_day": scheduled_day.isoformat(),
        "existing_day": existing_day.isoformat(),
        "late_day": late_day.isoformat(),
        "deadline": deadline.isoformat(),
    }


async def _seed_ordered_insert_project(db_path: str) -> dict[str, str]:
    today = date.today()
    scheduled_day = today + timedelta(days=2)
    existing_day = today + timedelta(days=3)
    moved_insert_day = today + timedelta(days=4)
    moved_existing_day = today + timedelta(days=5)

    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                5401,
                "Ordered Insert Project",
                "study_project",
                "sequential",
                "https://example.com/ordered-insert",
                "active",
                2,
                (today + timedelta(days=10)).isoformat(),
            ),
        )
        await db.executemany(
            """
            INSERT INTO units
                (id, resource_id, title, order_index, estimated_minutes, status)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [
                (5402, 5401, "First ordered unit", 1, 25, "pending"),
                (5403, 5401, "Second ordered unit", 2, 30, "pending"),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, unit_id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at)
            VALUES (?, ?, ?, ?, 'time', ?, ?, ?, ?)
            """,
            [
                (5404, 5402, 5401, "First ordered task", 25, scheduled_day.isoformat(), 9, None),
                (5405, 5403, 5401, "Second ordered task", 30, existing_day.isoformat(), 8, None),
            ],
        )
        await db.commit()

    return {
        "scheduled_day": scheduled_day.isoformat(),
        "existing_day": existing_day.isoformat(),
        "moved_insert_day": moved_insert_day.isoformat(),
        "moved_existing_day": moved_existing_day.isoformat(),
    }


@pytest.mark.asyncio
async def test_insert_active_project_task_creates_unfinished_task_without_cascade_and_records_event(client):
    days = await _seed_insert_project(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-plan-adjustment/projects/5101/tasks",
        json={
            "title": "Inserted manual task",
            "target_minutes": 30,
            "scheduled_date": days["scheduled_day"],
        },
    )

    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["project_id"] == 5101
    assert payload["scheduled_date"] == days["scheduled_day"]
    assert payload["source"] == "manual_insert"
    assert payload["target_minutes"] == 30
    assert payload["title"] == "Inserted manual task"
    assert isinstance(payload["task_id"], int)

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        tasks = await _fetchall(
            db,
            """
            SELECT
                id,
                unit_id,
                resource_id,
                title,
                task_kind,
                target_minutes,
                scheduled_date,
                originally_scheduled_date,
                completed_at,
                auto_roll_days,
                last_auto_rolled_at,
                user_adjusted_at
            FROM tasks
            WHERE resource_id = 5101
            ORDER BY id
            """,
        )
        events = await _fetchall(
            db,
            """
            SELECT event_type, payload
            FROM events
            WHERE event_type = 'study_task_inserted'
            ORDER BY id
            """,
        )

    assert tasks == [
        {
            "id": 5201,
            "unit_id": None,
            "resource_id": 5101,
            "title": "Existing first task",
            "task_kind": "time",
            "target_minutes": 25,
            "scheduled_date": days["scheduled_day"],
            "originally_scheduled_date": None,
            "completed_at": None,
            "auto_roll_days": 0,
            "last_auto_rolled_at": None,
            "user_adjusted_at": None,
        },
        {
            "id": 5202,
            "unit_id": None,
            "resource_id": 5101,
            "title": "Existing later task",
            "task_kind": "time",
            "target_minutes": 30,
            "scheduled_date": days["existing_day"],
            "originally_scheduled_date": None,
            "completed_at": None,
            "auto_roll_days": 0,
            "last_auto_rolled_at": None,
            "user_adjusted_at": None,
        },
        {
            "id": payload["task_id"],
            "unit_id": tasks[2]["unit_id"],
            "resource_id": 5101,
            "title": "Inserted manual task",
            "task_kind": "time",
            "target_minutes": 30,
            "scheduled_date": days["scheduled_day"],
            "originally_scheduled_date": days["scheduled_day"],
            "completed_at": None,
            "auto_roll_days": 0,
            "last_auto_rolled_at": None,
            "user_adjusted_at": None,
        },
    ]
    assert tasks[2]["unit_id"] is not None
    assert len(events) == 1
    assert events[0]["event_type"] == "study_task_inserted"
    assert json.loads(events[0]["payload"]) == {
        "project_id": 5101,
        "task_id": payload["task_id"],
        "scheduled_date": days["scheduled_day"],
        "target_minutes": 30,
        "title": "Inserted manual task",
        "source": "manual_insert",
    }


@pytest.mark.asyncio
async def test_inserted_task_gets_project_order_fact_so_later_move_cascades_successors(client):
    days = await _seed_ordered_insert_project(os.environ["DB_PATH"])

    insert_response = await client.post(
        "/api/study-plan-adjustment/projects/5401/tasks",
        json={
            "title": "Inserted between ordered tasks",
            "target_minutes": 20,
            "scheduled_date": days["scheduled_day"],
        },
    )
    assert insert_response.status_code == 200, insert_response.text
    inserted_task_id = insert_response.json()["task_id"]

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        after_insert = await _fetchall(
            db,
            """
            SELECT
                t.id,
                t.unit_id,
                t.scheduled_date,
                u.order_index
            FROM tasks t
            LEFT JOIN units u ON u.id = t.unit_id
            WHERE t.resource_id = 5401
            ORDER BY u.order_index, t.id
            """,
        )

    assert after_insert == [
        {"id": 5404, "unit_id": 5402, "scheduled_date": days["scheduled_day"], "order_index": 1},
        {
            "id": inserted_task_id,
            "unit_id": after_insert[1]["unit_id"],
            "scheduled_date": days["scheduled_day"],
            "order_index": 2,
        },
        {"id": 5405, "unit_id": 5403, "scheduled_date": days["existing_day"], "order_index": 3},
    ]
    assert after_insert[1]["unit_id"] is not None

    move_response = await client.post(
        f"/api/study-plan-adjustment/tasks/{inserted_task_id}/move",
        json={"scheduled_date": days["moved_insert_day"]},
    )

    assert move_response.status_code == 200, move_response.text
    assert move_response.json()["changes"] == [
        {
            "task_id": inserted_task_id,
            "project_id": 5401,
            "old_date": days["scheduled_day"],
            "new_date": days["moved_insert_day"],
        },
        {
            "task_id": 5405,
            "project_id": 5401,
            "old_date": days["existing_day"],
            "new_date": days["moved_existing_day"],
        },
    ]

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        after_move = await _fetchall(
            db,
            """
            SELECT id, scheduled_date
            FROM tasks
            WHERE resource_id = 5401
            ORDER BY id
            """,
        )

    assert after_move == [
        {"id": 5404, "scheduled_date": days["scheduled_day"]},
        {"id": 5405, "scheduled_date": days["moved_existing_day"]},
        {"id": inserted_task_id, "scheduled_date": days["moved_insert_day"]},
    ]


@pytest.mark.asyncio
async def test_inserted_task_after_deadline_recalculates_expected_late_without_repair(client):
    days = await _seed_insert_project(os.environ["DB_PATH"])

    insert_response = await client.post(
        "/api/study-plan-adjustment/projects/5101/tasks",
        json={
            "title": "Late inserted task",
            "target_minutes": 20,
            "scheduled_date": days["late_day"],
        },
    )
    overview_response = await client.get("/api/study-views/projects")

    assert insert_response.status_code == 200, insert_response.text
    assert overview_response.status_code == 200, overview_response.text
    active_project = overview_response.json()["active_projects"][0]
    assert active_project["id"] == 5101
    assert active_project["expected_late"] is True

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        tasks = await _fetchall(
            db,
            "SELECT id, scheduled_date FROM tasks WHERE resource_id = 5101 ORDER BY id",
        )

    assert tasks == [
        {"id": 5201, "scheduled_date": days["scheduled_day"]},
        {"id": 5202, "scheduled_date": days["existing_day"]},
        {"id": insert_response.json()["task_id"], "scheduled_date": days["late_day"]},
    ]


@pytest.mark.asyncio
async def test_inserted_task_can_make_calendar_over_capacity_without_moving_tasks(client):
    days = await _seed_insert_project(os.environ["DB_PATH"])

    insert_response = await client.post(
        "/api/study-plan-adjustment/projects/5101/tasks",
        json={
            "title": "Capacity pushing task",
            "target_minutes": 40,
            "scheduled_date": days["scheduled_day"],
        },
    )
    calendar_response = await client.get(
        f"/api/study-views/calendar?start={days['scheduled_day']}&end={days['scheduled_day']}"
    )

    assert insert_response.status_code == 200, insert_response.text
    assert calendar_response.status_code == 200, calendar_response.text
    assert calendar_response.json()["days"] == [
        {
            "date": days["scheduled_day"],
            "scheduled_task_count": 2,
            "total_target_minutes": 65,
            "completed_task_count": 0,
            "over_capacity": True,
        }
    ]

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        tasks = await _fetchall(
            db,
            "SELECT id, scheduled_date FROM tasks WHERE resource_id = 5101 ORDER BY id",
        )

    assert tasks == [
        {"id": 5201, "scheduled_date": days["scheduled_day"]},
        {"id": 5202, "scheduled_date": days["existing_day"]},
        {"id": insert_response.json()["task_id"], "scheduled_date": days["scheduled_day"]},
    ]


@pytest.mark.asyncio
async def test_insert_rejects_completed_and_non_study_projects_without_mutation_or_event(client):
    scheduled_day = (date.today() + timedelta(days=2)).isoformat()
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.executemany(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    5301,
                    "Completed Study Project",
                    "study_project",
                    "sequential",
                    "https://example.com/completed",
                    "completed",
                    1,
                    "2026-06-01",
                ),
                (
                    5302,
                    "Active Non Study Resource",
                    "web",
                    "sequential",
                    "https://example.com/web",
                    "active",
                    1,
                    "2026-06-02",
                ),
            ],
        )
        await db.commit()

    completed_response = await client.post(
        "/api/study-plan-adjustment/projects/5301/tasks",
        json={"title": "Should not insert", "target_minutes": 30, "scheduled_date": scheduled_day},
    )
    non_study_response = await client.post(
        "/api/study-plan-adjustment/projects/5302/tasks",
        json={"title": "Should not insert", "target_minutes": 30, "scheduled_date": scheduled_day},
    )
    missing_response = await client.post(
        "/api/study-plan-adjustment/projects/999999/tasks",
        json={"title": "Should not insert", "target_minutes": 30, "scheduled_date": scheduled_day},
    )

    assert completed_response.status_code == 409, completed_response.text
    assert non_study_response.status_code == 409, non_study_response.text
    assert missing_response.status_code == 404, missing_response.text
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        tasks = await _fetchall(
            db,
            "SELECT id FROM tasks WHERE resource_id IN (5301, 5302) ORDER BY id",
        )
        events = await _fetchall(
            db,
            "SELECT id FROM events WHERE event_type = 'study_task_inserted'",
        )

    assert tasks == []
    assert events == []


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "payload",
    [
        {"title": "", "target_minutes": 30, "scheduled_date": "2026-06-01"},
        {"title": "   ", "target_minutes": 30, "scheduled_date": "2026-06-01"},
        {"title": "Invalid minutes", "target_minutes": 0, "scheduled_date": "2026-06-01"},
    ],
)
async def test_insert_rejects_invalid_payload_without_mutation_or_event(client, payload):
    await _seed_insert_project(os.environ["DB_PATH"])

    response = await client.post("/api/study-plan-adjustment/projects/5101/tasks", json=payload)

    assert response.status_code == 422, response.text
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        tasks = await _fetchall(db, "SELECT id FROM tasks WHERE resource_id = 5101 ORDER BY id")
        events = await _fetchall(
            db,
            "SELECT id FROM events WHERE event_type = 'study_task_inserted'",
        )

    assert tasks == [{"id": 5201}, {"id": 5202}]
    assert events == []
