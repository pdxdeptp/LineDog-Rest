import json
import os
from datetime import date, timedelta

import aiosqlite
import pytest


async def _fetchall(db: aiosqlite.Connection, sql: str, params: tuple = ()) -> list[dict]:
    async with db.execute(sql, params) as cursor:
        rows = await cursor.fetchall()
    return [dict(row) for row in rows]


async def _fetchone(db: aiosqlite.Connection, sql: str, params: tuple = ()) -> dict | None:
    async with db.execute(sql, params) as cursor:
        row = await cursor.fetchone()
    return dict(row) if row else None


async def _seed_rollover_facts(db_path: str) -> dict[str, str]:
    today = date.today()
    old_day = today - timedelta(days=3)
    completed_old_day = today - timedelta(days=2)
    tomorrow = today + timedelta(days=1)
    async with aiosqlite.connect(db_path) as db:
        await db.executemany(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (3101, "Active Rollover Project", "study_project", "sequential", "https://example.com/active", "active", 3),
                (3102, "Completed Project", "study_project", "sequential", "https://example.com/completed", "completed", 1),
                (3103, "Active Non Study Resource", "web", "sequential", "https://example.com/web", "active", 1),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at, auto_roll_days, last_auto_rolled_at)
            VALUES (?, ?, ?, 'time', ?, ?, ?, ?, ?, ?)
            """,
            [
                (3301, 3101, "Overdue unfinished task", 45, old_day.isoformat(), 9, None, 0, None),
                (3302, 3101, "Same project future task", 45, tomorrow.isoformat(), 8, None, 0, None),
                (
                    3303,
                    3101,
                    "Completed overdue task",
                    30,
                    completed_old_day.isoformat(),
                    7,
                    "2026-05-20T10:00:00+00:00",
                    0,
                    None,
                ),
                (3304, 3102, "Completed project overdue task", 30, old_day.isoformat(), 6, None, 0, None),
                (3305, 3103, "Non study overdue task", 30, old_day.isoformat(), 5, None, 0, None),
            ],
        )
        await db.commit()

    return {
        "today": today.isoformat(),
        "old_day": old_day.isoformat(),
        "completed_old_day": completed_old_day.isoformat(),
        "tomorrow": tomorrow.isoformat(),
    }


@pytest.mark.asyncio
async def test_rollover_moves_only_unfinished_active_study_tasks_without_same_project_cascade(client):
    days = await _seed_rollover_facts(os.environ["DB_PATH"])

    response = await client.post("/api/study-plan-adjustment/rollover")

    assert response.status_code == 200, response.text
    assert response.json() == {
        "date": days["today"],
        "rolled_count": 1,
        "rolled_tasks": [
            {
                "task_id": 3301,
                "project_id": 3101,
                "old_date": days["old_day"],
                "new_date": days["today"],
                "rolled_days": 3,
                "auto_roll_days": 3,
            }
        ],
    }

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        tasks = await _fetchall(
            db,
            """
            SELECT id, scheduled_date, auto_roll_days, last_auto_rolled_at
            FROM tasks
            ORDER BY id
            """,
        )
        events = await _fetchall(
            db,
            """
            SELECT event_type, payload
            FROM events
            WHERE event_type = 'study_task_rolled_over'
            ORDER BY id
            """,
        )

    assert tasks == [
        {
            "id": 3301,
            "scheduled_date": days["today"],
            "auto_roll_days": 3,
            "last_auto_rolled_at": days["today"],
        },
        {
            "id": 3302,
            "scheduled_date": days["tomorrow"],
            "auto_roll_days": 0,
            "last_auto_rolled_at": None,
        },
        {
            "id": 3303,
            "scheduled_date": days["completed_old_day"],
            "auto_roll_days": 0,
            "last_auto_rolled_at": None,
        },
        {
            "id": 3304,
            "scheduled_date": days["old_day"],
            "auto_roll_days": 0,
            "last_auto_rolled_at": None,
        },
        {
            "id": 3305,
            "scheduled_date": days["old_day"],
            "auto_roll_days": 0,
            "last_auto_rolled_at": None,
        },
    ]
    assert len(events) == 1
    assert json.loads(events[0]["payload"]) == {
        "task_id": 3301,
        "resource_id": 3101,
        "original_date": days["old_day"],
        "new_date": days["today"],
        "rolled_days": 3,
        "source": "auto_rollover",
    }


@pytest.mark.asyncio
async def test_rollover_is_idempotent_for_repeated_same_day_calls(client):
    days = await _seed_rollover_facts(os.environ["DB_PATH"])

    first_response = await client.post("/api/study-plan-adjustment/rollover")
    second_response = await client.post("/api/study-plan-adjustment/rollover")

    assert first_response.status_code == 200, first_response.text
    assert second_response.status_code == 200, second_response.text
    assert first_response.json()["rolled_count"] == 1
    assert second_response.json() == {
        "date": days["today"],
        "rolled_count": 0,
        "rolled_tasks": [],
    }

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        task = await _fetchone(
            db,
            """
            SELECT scheduled_date, auto_roll_days, last_auto_rolled_at
            FROM tasks
            WHERE id = 3301
            """,
        )
        events = await _fetchall(
            db,
            "SELECT id FROM events WHERE event_type = 'study_task_rolled_over'",
        )

    assert task == {
        "scheduled_date": days["today"],
        "auto_roll_days": 3,
        "last_auto_rolled_at": days["today"],
    }
    assert len(events) == 1
