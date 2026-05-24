import json
import os
from datetime import date

import aiosqlite
import pytest


async def _fetchone(db: aiosqlite.Connection, sql: str, params: tuple = ()) -> dict | None:
    async with db.execute(sql, params) as cur:
        row = await cur.fetchone()
    return dict(row) if row else None


async def _fetchall(db: aiosqlite.Connection, sql: str, params: tuple = ()) -> list[dict]:
    async with db.execute(sql, params) as cur:
        rows = await cur.fetchall()
    return [dict(row) for row in rows]


async def _seed_completion_facts(db_path: str) -> int:
    today = date.today().isoformat()
    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, completed_units, actual_minutes_total)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                501,
                "Study Views Completion",
                "study_project",
                "sequential",
                "https://example.com/study-views",
                "active",
                2,
                0,
                10,
            ),
        )
        await db.executemany(
            """
            INSERT INTO units
                (id, resource_id, title, order_index, estimated_minutes, status, completed_at, actual_minutes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (601, 501, "Completion Semantics", 0, 35, "pending", None, None),
                (602, 501, "Remaining Unit", 1, 25, "pending", None, None),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, unit_id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at, actual_minutes)
            VALUES (?, ?, ?, ?, 'time', ?, ?, ?, ?, ?)
            """,
            [
                (701, 601, 501, "Complete task once", 35, today, 9, None, None),
                (702, 602, 501, "Still pending", 25, today, 8, None, None),
            ],
        )
        await db.commit()

    return 701


async def _seed_same_unit_tasks(db_path: str) -> tuple[int, int]:
    today = date.today().isoformat()
    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, completed_units, actual_minutes_total)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                801,
                "Same Unit Tasks",
                "study_project",
                "sequential",
                "https://example.com/same-unit",
                "active",
                1,
                0,
                0,
            ),
        )
        await db.execute(
            """
            INSERT INTO units
                (id, resource_id, title, order_index, estimated_minutes, status, completed_at, actual_minutes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (901, 801, "One Unit", 0, 60, "pending", None, None),
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, unit_id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at)
            VALUES (?, ?, ?, ?, 'time', ?, ?, ?, ?)
            """,
            [
                (1001, 901, 801, "First task in unit", 30, today, 9, None),
                (1002, 901, 801, "Second task in unit", 20, today, 8, None),
            ],
        )
        await db.commit()

    return 1001, 1002


async def _seed_final_task_study_project(db_path: str) -> int:
    today = date.today().isoformat()
    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, completed_units, actual_minutes_total, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                2201,
                "Final Task Study Project",
                "study_project",
                "sequential",
                "https://example.com/final-study",
                "active",
                2,
                1,
                30,
                "2026-06-30",
            ),
        )
        await db.executemany(
            """
            INSERT INTO units
                (id, resource_id, title, order_index, estimated_minutes, status, completed_at, actual_minutes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (2301, 2201, "Already Complete", 0, 30, "completed", "2026-05-22T10:00:00+00:00", 30),
                (2302, 2201, "Final Unit", 1, 45, "pending", None, None),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, unit_id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at, actual_minutes)
            VALUES (?, ?, ?, ?, 'time', ?, ?, ?, ?, ?)
            """,
            [
                (2401, 2301, 2201, "Previously finished task", 30, today, 9, "2026-05-22T10:00:00+00:00", 30),
                (2402, 2302, 2201, "Finish the project", 45, today, 8, None, None),
            ],
        )
        await db.commit()

    return 2402


async def _seed_final_task_non_study_resource(db_path: str) -> int:
    today = date.today().isoformat()
    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, completed_units, actual_minutes_total)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                2501,
                "Legacy Active Resource",
                "web",
                "sequential",
                "https://example.com/legacy-final",
                "active",
                1,
                0,
                0,
            ),
        )
        await db.execute(
            """
            INSERT INTO tasks
                (id, unit_id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at, actual_minutes)
            VALUES (?, ?, ?, ?, 'time', ?, ?, ?, ?, ?)
            """,
            (2601, None, 2501, "Finish legacy resource", 20, today, 9, None, None),
        )
        await db.commit()

    return 2601


async def _seed_rolled_task_completion_facts(db_path: str) -> int:
    today = date.today()
    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, completed_units, actual_minutes_total)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                3901,
                "Rolled Completion Project",
                "study_project",
                "sequential",
                "https://example.com/rolled-completion",
                "active",
                2,
                0,
                0,
            ),
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at, auto_roll_days, last_auto_rolled_at)
            VALUES (?, ?, ?, 'time', ?, ?, ?, ?, ?, ?)
            """,
            [
                (4001, 3901, "Complete rolled task", 30, today.isoformat(), 9, None, 4, today.isoformat()),
                (4002, 3901, "Keep project active", 20, today.isoformat(), 8, None, 0, None),
            ],
        )
        await db.commit()

    return 4001


@pytest.mark.asyncio
async def test_task_completion_updates_v2_facts_and_duplicate_completion_is_idempotent(client):
    task_id = await _seed_completion_facts(os.environ["DB_PATH"])

    first_response = await client.post(
        f"/api/tasks/{task_id}/complete",
        json={"actual_minutes": 42},
    )
    duplicate_response = await client.post(
        f"/api/tasks/{task_id}/complete",
        json={"actual_minutes": 99},
    )

    assert first_response.status_code == 200, first_response.text
    assert duplicate_response.status_code == 200, duplicate_response.text
    first_completed_at = first_response.json()["completed_at"]
    assert duplicate_response.json()["completed_at"] == first_completed_at

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        task = await _fetchone(
            db,
            "SELECT completed_at, actual_minutes FROM tasks WHERE id = ?",
            (task_id,),
        )
        unit = await _fetchone(
            db,
            "SELECT status, completed_at, actual_minutes FROM units WHERE id = 601",
        )
        resource = await _fetchone(
            db,
            """
            SELECT status, completed_units, actual_minutes_total
            FROM resources
            WHERE id = 501
            """,
        )
        events = await _fetchall(
            db,
            """
            SELECT event_type, payload
            FROM events
            WHERE event_type = 'task_completed'
            ORDER BY id
            """,
        )

    assert task == {"completed_at": first_completed_at, "actual_minutes": 42}
    assert unit == {
        "status": "completed",
        "completed_at": first_completed_at,
        "actual_minutes": 42,
    }
    assert resource == {
        "status": "active",
        "completed_units": 1,
        "actual_minutes_total": 52,
    }
    assert len(events) == 1
    assert json.loads(events[0]["payload"]) == {"task_id": task_id}

    today_response = await client.get("/api/study-views/today")

    assert today_response.status_code == 200, today_response.text
    tasks_by_id = {task["id"]: task for task in today_response.json()["tasks"]}
    assert tasks_by_id[task_id]["completed_at"] == first_completed_at
    assert tasks_by_id[702]["completed_at"] is None


@pytest.mark.asyncio
async def test_task_completion_counts_a_linked_unit_once_and_does_not_auto_complete_project(client):
    first_task_id, second_task_id = await _seed_same_unit_tasks(os.environ["DB_PATH"])

    first_response = await client.post(
        f"/api/tasks/{first_task_id}/complete",
        json={"actual_minutes": 31},
    )

    assert first_response.status_code == 200, first_response.text
    first_completed_at = first_response.json()["completed_at"]

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        resource_after_first = await _fetchone(
            db,
            "SELECT status, completed_units, actual_minutes_total FROM resources WHERE id = 801",
        )
        unit_after_first = await _fetchone(
            db,
            "SELECT status, completed_at, actual_minutes FROM units WHERE id = 901",
        )
        resource_completed_events = await _fetchall(
            db,
            "SELECT id FROM events WHERE event_type = 'resource_completed'",
        )

    assert resource_after_first == {
        "status": "active",
        "completed_units": 1,
        "actual_minutes_total": 31,
    }
    assert unit_after_first == {
        "status": "completed",
        "completed_at": first_completed_at,
        "actual_minutes": 31,
    }
    assert resource_completed_events == []

    today_response = await client.get("/api/study-views/today")

    assert today_response.status_code == 200, today_response.text
    tasks_by_id = {task["id"]: task for task in today_response.json()["tasks"]}
    assert tasks_by_id[first_task_id]["completed_at"] == first_completed_at
    assert tasks_by_id[second_task_id]["completed_at"] is None

    second_response = await client.post(
        f"/api/tasks/{second_task_id}/complete",
        json={"actual_minutes": 22},
    )

    assert second_response.status_code == 200, second_response.text

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        resource_after_second = await _fetchone(
            db,
            "SELECT completed_units, actual_minutes_total FROM resources WHERE id = 801",
        )
        unit_after_second = await _fetchone(
            db,
            "SELECT completed_at, actual_minutes FROM units WHERE id = 901",
        )

    assert resource_after_second == {
        "completed_units": 1,
        "actual_minutes_total": 53,
    }
    assert unit_after_second == {
        "completed_at": first_completed_at,
        "actual_minutes": 31,
    }


@pytest.mark.asyncio
async def test_completing_unknown_task_returns_404_without_task_completed_event(client):
    response = await client.post("/api/tasks/999999/complete", json={"actual_minutes": 15})

    assert response.status_code == 404, response.text
    assert response.json()["detail"] == "Task not found"

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        events = await _fetchall(
            db,
            "SELECT id FROM events WHERE event_type = 'task_completed'",
        )

    assert events == []


@pytest.mark.asyncio
async def test_final_study_project_task_completes_project_preserves_history_and_is_idempotent(client):
    task_id = await _seed_final_task_study_project(os.environ["DB_PATH"])

    first_response = await client.post(
        f"/api/tasks/{task_id}/complete",
        json={"actual_minutes": 50},
    )
    duplicate_response = await client.post(
        f"/api/tasks/{task_id}/complete",
        json={"actual_minutes": 99},
    )

    assert first_response.status_code == 200, first_response.text
    assert duplicate_response.status_code == 200, duplicate_response.text
    completed_at = first_response.json()["completed_at"]
    assert duplicate_response.json()["completed_at"] == completed_at

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        resource = await _fetchone(
            db,
            "SELECT status, completed_units, actual_minutes_total FROM resources WHERE id = 2201",
        )
        rows = {
            "resources": await _fetchall(db, "SELECT id FROM resources WHERE id = 2201"),
            "units": await _fetchall(db, "SELECT id FROM units WHERE resource_id = 2201 ORDER BY id"),
            "tasks": await _fetchall(db, "SELECT id FROM tasks WHERE resource_id = 2201 ORDER BY id"),
        }
        events = await _fetchall(
            db,
            """
            SELECT event_type, payload
            FROM events
            WHERE event_type IN ('task_completed', 'resource_completed')
            ORDER BY id
            """,
        )

    assert resource == {
        "status": "completed",
        "completed_units": 2,
        "actual_minutes_total": 80,
    }
    assert rows == {
        "resources": [{"id": 2201}],
        "units": [{"id": 2301}, {"id": 2302}],
        "tasks": [{"id": 2401}, {"id": 2402}],
    }
    assert [event["event_type"] for event in events] == ["task_completed", "resource_completed"]
    assert json.loads(events[0]["payload"]) == {"task_id": task_id}
    assert json.loads(events[1]["payload"]) == {"resource_id": 2201, "source": "task_completion"}

    today_response = await client.get("/api/study-views/today")
    overview_response = await client.get("/api/study-views/projects")

    assert today_response.status_code == 200, today_response.text
    assert overview_response.status_code == 200, overview_response.text
    assert today_response.json()["tasks"] == []
    assert overview_response.json()["active_projects"] == []
    assert overview_response.json()["completed_projects"] == [
        {
            "id": 2201,
            "title": "Final Task Study Project",
            "completed_units": 2,
            "total_units": 2,
            "progress_ratio": 1.0,
            "target_minutes": 75,
            "actual_minutes": 80,
            "deadline": "2026-06-30",
            "expected_late": False,
            "status": "completed",
        }
    ]


@pytest.mark.asyncio
async def test_final_task_for_non_study_resource_does_not_auto_complete_resource(client):
    task_id = await _seed_final_task_non_study_resource(os.environ["DB_PATH"])

    response = await client.post(f"/api/tasks/{task_id}/complete", json={"actual_minutes": 25})

    assert response.status_code == 200, response.text
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        resource = await _fetchone(
            db,
            "SELECT status, completed_units, actual_minutes_total FROM resources WHERE id = 2501",
        )
        resource_completed_events = await _fetchall(
            db,
            "SELECT id FROM events WHERE event_type = 'resource_completed'",
        )

    assert resource == {
        "status": "active",
        "completed_units": 1,
        "actual_minutes_total": 25,
    }
    assert resource_completed_events == []


@pytest.mark.asyncio
async def test_completing_rolled_task_resets_rollover_markers_and_clears_active_badge(client):
    task_id = await _seed_rolled_task_completion_facts(os.environ["DB_PATH"])

    response = await client.post(f"/api/tasks/{task_id}/complete", json={"actual_minutes": 33})

    assert response.status_code == 200, response.text
    completed_at = response.json()["completed_at"]

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        task = await _fetchone(
            db,
            """
            SELECT completed_at, actual_minutes, auto_roll_days, last_auto_rolled_at
            FROM tasks
            WHERE id = ?
            """,
            (task_id,),
        )

    assert task == {
        "completed_at": completed_at,
        "actual_minutes": 33,
        "auto_roll_days": 0,
        "last_auto_rolled_at": None,
    }

    today_response = await client.get("/api/study-views/today")

    assert today_response.status_code == 200, today_response.text
    tasks = today_response.json()["tasks"]
    active_task_ids = {task["id"] for task in tasks if task["completed_at"] is None}
    assert task_id not in active_task_ids
    completed_payload = next(task for task in tasks if task["id"] == task_id)
    assert completed_payload["rolled_day_count"] == 0
    assert completed_payload["show_rolled_badge"] is False
