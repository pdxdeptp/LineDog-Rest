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


async def _seed_manual_move_facts(db_path: str) -> dict[str, str]:
    today = date.today()
    selected_day = today + timedelta(days=1)
    new_day = today + timedelta(days=4)
    earlier_day = today
    later_day = today + timedelta(days=3)
    completed_day = today + timedelta(days=5)
    other_project_day = today + timedelta(days=3)

    async with aiosqlite.connect(db_path) as db:
        await db.executemany(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (4101, "Active Manual Move Project", "study_project", "sequential", "https://example.com/active", "active", 5),
                (4102, "Other Active Project", "study_project", "sequential", "https://example.com/other", "active", 1),
            ],
        )
        await db.executemany(
            """
            INSERT INTO units
                (id, resource_id, title, order_index, estimated_minutes, status)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [
                (4201, 4101, "Earlier unit", 1, 30, "pending"),
                (4202, 4101, "Selected unit", 2, 30, "pending"),
                (4203, 4101, "Later unit", 3, 30, "pending"),
                (4204, 4101, "Completed unit", 4, 30, "completed"),
                (4205, 4102, "Other unit", 1, 30, "pending"),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (
                    id,
                    unit_id,
                    resource_id,
                    title,
                    task_kind,
                    target_minutes,
                    scheduled_date,
                    priority,
                    completed_at,
                    auto_roll_days,
                    last_auto_rolled_at,
                    user_adjusted_at
                )
            VALUES (?, ?, ?, ?, 'time', ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (4301, 4201, 4101, "Earlier same project task", 30, earlier_day.isoformat(), 9, None, 2, today.isoformat(), None),
                (4302, 4202, 4101, "Selected task", 30, selected_day.isoformat(), 8, None, 4, today.isoformat(), None),
                (4303, 4203, 4101, "Later same project task", 30, later_day.isoformat(), 7, None, 5, today.isoformat(), None),
                (
                    4304,
                    4204,
                    4101,
                    "Completed same project task",
                    30,
                    completed_day.isoformat(),
                    6,
                    "2026-05-20T10:00:00+00:00",
                    6,
                    today.isoformat(),
                    None,
                ),
                (4305, 4205, 4102, "Other project task", 30, other_project_day.isoformat(), 5, None, 7, today.isoformat(), None),
            ],
        )
        await db.commit()

    return {
        "today": today.isoformat(),
        "selected_day": selected_day.isoformat(),
        "new_day": new_day.isoformat(),
        "earlier_day": earlier_day.isoformat(),
        "later_day": later_day.isoformat(),
        "later_shifted_day": (later_day + timedelta(days=3)).isoformat(),
        "completed_day": completed_day.isoformat(),
        "other_project_day": other_project_day.isoformat(),
    }


async def _seed_move_that_would_cascade_before_today(db_path: str) -> dict[str, str | None]:
    today = date.today()
    selected_day = today + timedelta(days=1)
    later_by_order_day = today
    selected_adjusted_at = "2026-05-20T10:00:00+00:00"
    later_adjusted_at = "2026-05-21T10:00:00+00:00"

    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (4401, "Cascade Past Boundary Project", "study_project", "sequential", "https://example.com/past-cascade", "active", 2),
        )
        await db.executemany(
            """
            INSERT INTO units
                (id, resource_id, title, order_index, estimated_minutes, status)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [
                (4402, 4401, "Selected future unit", 1, 30, "pending"),
                (4403, 4401, "Later by order unit", 2, 30, "pending"),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (
                    id,
                    unit_id,
                    resource_id,
                    title,
                    task_kind,
                    target_minutes,
                    scheduled_date,
                    priority,
                    completed_at,
                    auto_roll_days,
                    last_auto_rolled_at,
                    user_adjusted_at
                )
            VALUES (?, ?, ?, ?, 'time', ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (4404, 4402, 4401, "Selected future task", 30, selected_day.isoformat(), 8, None, 4, today.isoformat(), selected_adjusted_at),
                (4405, 4403, 4401, "Later task already today", 30, later_by_order_day.isoformat(), 7, None, 5, today.isoformat(), later_adjusted_at),
            ],
        )
        await db.commit()

    return {
        "today": today.isoformat(),
        "selected_day": selected_day.isoformat(),
        "later_by_order_day": later_by_order_day.isoformat(),
        "selected_adjusted_at": selected_adjusted_at,
        "later_adjusted_at": later_adjusted_at,
    }


@pytest.mark.asyncio
async def test_move_unfinished_active_study_task_cascades_later_same_project_tasks_only(client):
    days = await _seed_manual_move_facts(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-plan-adjustment/tasks/4302/move",
        json={"scheduled_date": days["new_day"]},
    )

    assert response.status_code == 200, response.text
    assert response.json() == {
        "task_id": 4302,
        "source": "manual_move",
        "affected_count": 2,
        "changes": [
            {
                "task_id": 4302,
                "project_id": 4101,
                "old_date": days["selected_day"],
                "new_date": days["new_day"],
            },
            {
                "task_id": 4303,
                "project_id": 4101,
                "old_date": days["later_day"],
                "new_date": days["later_shifted_day"],
            },
        ],
    }

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        tasks = await _fetchall(
            db,
            """
            SELECT id, scheduled_date, auto_roll_days, last_auto_rolled_at, user_adjusted_at
            FROM tasks
            ORDER BY id
            """,
        )
        events = await _fetchall(
            db,
            """
            SELECT event_type, payload
            FROM events
            WHERE event_type = 'study_task_moved'
            ORDER BY id
            """,
        )

    assert tasks == [
        {
            "id": 4301,
            "scheduled_date": days["earlier_day"],
            "auto_roll_days": 2,
            "last_auto_rolled_at": days["today"],
            "user_adjusted_at": None,
        },
        {
            "id": 4302,
            "scheduled_date": days["new_day"],
            "auto_roll_days": 0,
            "last_auto_rolled_at": None,
            "user_adjusted_at": tasks[1]["user_adjusted_at"],
        },
        {
            "id": 4303,
            "scheduled_date": days["later_shifted_day"],
            "auto_roll_days": 0,
            "last_auto_rolled_at": None,
            "user_adjusted_at": tasks[2]["user_adjusted_at"],
        },
        {
            "id": 4304,
            "scheduled_date": days["completed_day"],
            "auto_roll_days": 6,
            "last_auto_rolled_at": days["today"],
            "user_adjusted_at": None,
        },
        {
            "id": 4305,
            "scheduled_date": days["other_project_day"],
            "auto_roll_days": 7,
            "last_auto_rolled_at": days["today"],
            "user_adjusted_at": None,
        },
    ]
    assert tasks[1]["user_adjusted_at"] is not None
    assert tasks[2]["user_adjusted_at"] is not None
    assert len(events) == 1
    assert json.loads(events[0]["payload"]) == {
        "task_id": 4302,
        "resource_id": 4101,
        "affected_task_ids": [4302, 4303],
        "changes": [
            {
                "task_id": 4302,
                "project_id": 4101,
                "original_date": days["selected_day"],
                "new_date": days["new_day"],
            },
            {
                "task_id": 4303,
                "project_id": 4101,
                "original_date": days["later_day"],
                "new_date": days["later_shifted_day"],
            },
        ],
        "source": "manual_move",
    }


@pytest.mark.asyncio
async def test_move_rejects_past_target_without_mutating_tasks_or_events(client):
    days = await _seed_manual_move_facts(os.environ["DB_PATH"])
    past_day = (date.today() - timedelta(days=1)).isoformat()

    response = await client.post(
        "/api/study-plan-adjustment/tasks/4302/move",
        json={"scheduled_date": past_day},
    )

    assert response.status_code == 400, response.text

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        selected_task = await _fetchone(
            db,
            """
            SELECT scheduled_date, auto_roll_days, last_auto_rolled_at, user_adjusted_at
            FROM tasks
            WHERE id = 4302
            """,
        )
        later_task = await _fetchone(
            db,
            """
            SELECT scheduled_date, auto_roll_days, last_auto_rolled_at, user_adjusted_at
            FROM tasks
            WHERE id = 4303
            """,
        )
        events = await _fetchall(
            db,
            "SELECT id FROM events WHERE event_type = 'study_task_moved'",
        )

    assert selected_task == {
        "scheduled_date": days["selected_day"],
        "auto_roll_days": 4,
        "last_auto_rolled_at": days["today"],
        "user_adjusted_at": None,
    }
    assert later_task == {
        "scheduled_date": days["later_day"],
        "auto_roll_days": 5,
        "last_auto_rolled_at": days["today"],
        "user_adjusted_at": None,
    }
    assert events == []


@pytest.mark.asyncio
async def test_move_rejects_when_cascade_would_shift_affected_task_before_today_without_mutation(client):
    days = await _seed_move_that_would_cascade_before_today(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-plan-adjustment/tasks/4404/move",
        json={"scheduled_date": days["today"]},
    )

    assert response.status_code == 400, response.text

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        tasks = await _fetchall(
            db,
            """
            SELECT id, scheduled_date, auto_roll_days, last_auto_rolled_at, user_adjusted_at
            FROM tasks
            WHERE id IN (4404, 4405)
            ORDER BY id
            """,
        )
        events = await _fetchall(
            db,
            "SELECT id FROM events WHERE event_type = 'study_task_moved'",
        )

    assert tasks == [
        {
            "id": 4404,
            "scheduled_date": days["selected_day"],
            "auto_roll_days": 4,
            "last_auto_rolled_at": days["today"],
            "user_adjusted_at": days["selected_adjusted_at"],
        },
        {
            "id": 4405,
            "scheduled_date": days["later_by_order_day"],
            "auto_roll_days": 5,
            "last_auto_rolled_at": days["today"],
            "user_adjusted_at": days["later_adjusted_at"],
        },
    ]
    assert events == []
