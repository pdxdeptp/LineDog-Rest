import os
from datetime import date, timedelta

import aiosqlite
import pytest


async def _fetchall(db: aiosqlite.Connection, sql: str, params: tuple = ()) -> list[dict]:
    async with db.execute(sql, params) as cursor:
        rows = await cursor.fetchall()
    return [dict(row) for row in rows]


async def _seed_dialogue_preview_project(db_path: str) -> dict[str, str]:
    today = date.today()
    first_day = today + timedelta(days=1)
    second_day = today + timedelta(days=3)
    completed_day = today + timedelta(days=4)
    other_project_day = today + timedelta(days=10)
    deadline = today + timedelta(days=8)

    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            ("daily_capacity_min", "60"),
        )
        await db.execute(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            ("study_rest_weekdays", "[]"),
        )
        await db.execute(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            ("study_rest_dates", "[]"),
        )
        await db.executemany(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    6101,
                    "Dialogue Preview Project",
                    "study_project",
                    "sequential",
                    "https://example.com/dialogue-preview",
                    "active",
                    3,
                    deadline.isoformat(),
                ),
                (
                    6102,
                    "Other Active Study Project",
                    "study_project",
                    "sequential",
                    "https://example.com/other",
                    "active",
                    1,
                    (today + timedelta(days=30)).isoformat(),
                ),
            ],
        )
        await db.executemany(
            """
            INSERT INTO units
                (id, resource_id, title, order_index, estimated_minutes, status)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [
                (6201, 6101, "First unit", 1, 40, "pending"),
                (6202, 6101, "Second unit", 2, 30, "pending"),
                (6203, 6101, "Completed unit", 3, 20, "completed"),
                (6204, 6102, "Other unit", 1, 30, "pending"),
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
                (6301, 6201, 6101, "First unfinished task", 40, first_day.isoformat(), 9, None, 2, today.isoformat(), None),
                (6302, 6202, 6101, "Second unfinished task", 30, second_day.isoformat(), 8, None, 3, today.isoformat(), None),
                (
                    6303,
                    6203,
                    6101,
                    "Completed task",
                    20,
                    completed_day.isoformat(),
                    7,
                    "2026-05-20T10:00:00+00:00",
                    4,
                    today.isoformat(),
                    None,
                ),
                (6304, 6204, 6102, "Other project task", 30, other_project_day.isoformat(), 6, None, 5, today.isoformat(), None),
            ],
        )
        await db.commit()

    return {
        "first_day": first_day.isoformat(),
        "second_day": second_day.isoformat(),
        "first_day_plus_week": (first_day + timedelta(days=7)).isoformat(),
        "second_day_plus_week": (second_day + timedelta(days=7)).isoformat(),
        "first_day_plus_three": (first_day + timedelta(days=3)).isoformat(),
        "second_day_plus_three": (second_day + timedelta(days=3)).isoformat(),
        "completed_day": completed_day.isoformat(),
        "other_project_day": other_project_day.isoformat(),
    }


async def _seed_dialogue_preview_capacity_project(db_path: str) -> dict[str, str]:
    today = date.today()
    moving_day = today + timedelta(days=1)
    crowded_day = today + timedelta(days=3)
    rest_day = today + timedelta(days=5)

    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            ("daily_capacity_min", "60"),
        )
        await db.execute(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            ("study_rest_weekdays", "[]"),
        )
        await db.execute(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            ("study_rest_dates", f'["{rest_day.isoformat()}"]'),
        )
        await db.executemany(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    6401,
                    "Dialogue Capacity Project",
                    "study_project",
                    "sequential",
                    "https://example.com/dialogue-capacity",
                    "active",
                    2,
                    (today + timedelta(days=30)).isoformat(),
                ),
                (
                    6402,
                    "Other Load Project",
                    "study_project",
                    "sequential",
                    "https://example.com/other-load",
                    "active",
                    1,
                    (today + timedelta(days=30)).isoformat(),
                ),
            ],
        )
        await db.executemany(
            """
            INSERT INTO units
                (id, resource_id, title, order_index, estimated_minutes, status)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [
                (6501, 6401, "Moving unit", 1, 30, "pending"),
                (6502, 6401, "Rest-day unit", 2, 15, "pending"),
                (6503, 6402, "Existing load unit", 1, 40, "pending"),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, unit_id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at)
            VALUES (?, ?, ?, ?, 'time', ?, ?, ?, ?)
            """,
            [
                (6601, 6501, 6401, "Moving onto crowded day", 30, moving_day.isoformat(), 9, None),
                (6602, 6502, 6401, "Moving onto rest day", 15, (rest_day - timedelta(days=2)).isoformat(), 8, None),
                (6603, 6503, 6402, "Other project load", 40, crowded_day.isoformat(), 7, None),
            ],
        )
        await db.commit()

    return {
        "moving_day": moving_day.isoformat(),
        "crowded_day": crowded_day.isoformat(),
        "rest_day": rest_day.isoformat(),
    }


async def _snapshot_mutation_guard(db_path: str) -> dict[str, list[dict]]:
    async with aiosqlite.connect(db_path) as db:
        db.row_factory = aiosqlite.Row
        return {
            "tasks": await _fetchall(
                db,
                """
                SELECT id, scheduled_date, auto_roll_days, last_auto_rolled_at, user_adjusted_at
                FROM tasks
                ORDER BY id
                """,
            ),
            "resources": await _fetchall(
                db,
                "SELECT id, deadline, status FROM resources ORDER BY id",
            ),
            "events": await _fetchall(
                db,
                "SELECT id, event_type, payload FROM events ORDER BY id",
            ),
            "system_state": await _fetchall(
                db,
                "SELECT key, value FROM system_state ORDER BY key",
            ),
        }


@pytest.mark.asyncio
async def test_dialogue_preview_pushes_explicit_project_by_one_week_without_mutation(client):
    days = await _seed_dialogue_preview_project(os.environ["DB_PATH"])
    before = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-plan-adjustment/dialogue/preview",
        json={"instruction": "push project 6101 by one week"},
    )

    assert response.status_code == 200, response.text
    assert response.json() == {
        "status": "preview",
        "source": "dialogue_preview",
        "command": "project_shift",
        "project_id": 6101,
        "delta_days": 7,
        "affected_task_ids": [6301, 6302],
        "changes": [
            {
                "task_id": 6301,
                "project_id": 6101,
                "old_date": days["first_day"],
                "new_date": days["first_day_plus_week"],
            },
            {
                "task_id": 6302,
                "project_id": 6101,
                "old_date": days["second_day"],
                "new_date": days["second_day_plus_week"],
            },
        ],
        "red_state_impact": {
            "expected_late": {
                "before": False,
                "after": True,
            },
            "over_capacity": {
                "before_dates": [],
                "after_dates": [],
                "new_over_capacity_dates": [],
            },
        },
        "mutates": False,
    }
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before


@pytest.mark.asyncio
async def test_dialogue_preview_uses_request_project_id_for_this_project_delay_without_mutation(client):
    days = await _seed_dialogue_preview_project(os.environ["DB_PATH"])
    before = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-plan-adjustment/dialogue/preview",
        json={"instruction": "delay this project by 3 days", "project_id": 6101},
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["status"] == "preview"
    assert body["source"] == "dialogue_preview"
    assert body["command"] == "project_shift"
    assert body["project_id"] == 6101
    assert body["delta_days"] == 3
    assert body["affected_task_ids"] == [6301, 6302]
    assert body["changes"] == [
        {
            "task_id": 6301,
            "project_id": 6101,
            "old_date": days["first_day"],
            "new_date": days["first_day_plus_three"],
        },
        {
            "task_id": 6302,
            "project_id": 6101,
            "old_date": days["second_day"],
            "new_date": days["second_day_plus_three"],
        },
    ]
    assert body["red_state_impact"]["expected_late"] == {"before": False, "after": False}
    assert body["red_state_impact"]["over_capacity"] == {
        "before_dates": [],
        "after_dates": [],
        "new_over_capacity_dates": [],
    }
    assert body["mutates"] is False
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before


@pytest.mark.asyncio
async def test_dialogue_preview_reports_capacity_and_rest_day_impact_without_mutation(client):
    days = await _seed_dialogue_preview_capacity_project(os.environ["DB_PATH"])
    before = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-plan-adjustment/dialogue/preview",
        json={"instruction": "push project 6401 by 2 days"},
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["status"] == "preview"
    assert body["changes"] == [
        {
            "task_id": 6601,
            "project_id": 6401,
            "old_date": days["moving_day"],
            "new_date": days["crowded_day"],
        },
        {
            "task_id": 6602,
            "project_id": 6401,
            "old_date": (date.fromisoformat(days["rest_day"]) - timedelta(days=2)).isoformat(),
            "new_date": days["rest_day"],
        },
    ]
    assert body["red_state_impact"]["over_capacity"] == {
        "before_dates": [],
        "after_dates": [days["crowded_day"], days["rest_day"]],
        "new_over_capacity_dates": [days["crowded_day"], days["rest_day"]],
    }
    assert body["mutates"] is False
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "payload",
    [
        {"instruction": "do not push project 6101 by one week"},
        {"instruction": "push project 6101 by one week and delete task 1"},
        {"instruction": "push project 6101 by one week and project 6102 by one week"},
        {"instruction": "push project 6101 by 3 days ago"},
        {"instruction": "push project 6101 by 0 days"},
        {"instruction": "push project 6101 by 366 days"},
        {"instruction": "push project 6101 by 53 weeks"},
        {"instruction": "push project 6101 by one week", "project_id": 6102},
    ],
)
async def test_dialogue_preview_rejects_unsafe_or_out_of_bounds_commands_without_mutation(client, payload):
    await _seed_dialogue_preview_project(os.environ["DB_PATH"])
    before = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post("/api/study-plan-adjustment/dialogue/preview", json=payload)

    assert response.status_code == 200, response.text
    assert response.json()["status"] == "unsupported"
    assert response.json()["mutates"] is False
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before


@pytest.mark.asyncio
async def test_dialogue_preview_rejects_shift_that_would_move_task_before_today_without_mutation(client):
    today = date.today()
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                6701,
                "Past Boundary Project",
                "study_project",
                "sequential",
                "https://example.com/past-boundary",
                "active",
                1,
                (today + timedelta(days=30)).isoformat(),
            ),
        )
        await db.execute(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at)
            VALUES (?, ?, ?, 'time', ?, ?, ?, ?)
            """,
            (6801, 6701, "Already today", 30, today.isoformat(), 9, None),
        )
        await db.commit()
    before = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-plan-adjustment/dialogue/preview",
        json={"instruction": "push project 6701 by -1 days"},
    )

    assert response.status_code == 200, response.text
    assert response.json()["status"] == "unsupported"
    assert response.json()["mutates"] is False
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before
