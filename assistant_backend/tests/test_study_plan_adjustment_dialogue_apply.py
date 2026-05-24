import copy
import json
import os
from datetime import date, timedelta

import aiosqlite
import pytest


async def _fetchall(db: aiosqlite.Connection, sql: str, params: tuple = ()) -> list[dict]:
    async with db.execute(sql, params) as cursor:
        rows = await cursor.fetchall()
    return [dict(row) for row in rows]


async def _seed_dialogue_apply_project(db_path: str) -> dict[str, str]:
    today = date.today()
    first_day = today + timedelta(days=1)
    second_day = today + timedelta(days=3)
    completed_day = today + timedelta(days=4)
    other_project_day = today + timedelta(days=10)

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
                    7101,
                    "Dialogue Apply Project",
                    "study_project",
                    "sequential",
                    "https://example.com/dialogue-apply",
                    "active",
                    3,
                    (today + timedelta(days=8)).isoformat(),
                ),
                (
                    7102,
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
                (7201, 7101, "First unit", 1, 40, "pending"),
                (7202, 7101, "Second unit", 2, 30, "pending"),
                (7203, 7101, "Completed unit", 3, 20, "completed"),
                (7204, 7102, "Other unit", 1, 30, "pending"),
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
                (
                    7301,
                    7201,
                    7101,
                    "First unfinished task",
                    40,
                    first_day.isoformat(),
                    9,
                    None,
                    2,
                    today.isoformat(),
                    None,
                ),
                (
                    7302,
                    7202,
                    7101,
                    "Second unfinished task",
                    30,
                    second_day.isoformat(),
                    8,
                    None,
                    3,
                    today.isoformat(),
                    None,
                ),
                (
                    7303,
                    7203,
                    7101,
                    "Completed task",
                    20,
                    completed_day.isoformat(),
                    7,
                    "2026-05-20T10:00:00+00:00",
                    4,
                    today.isoformat(),
                    None,
                ),
                (
                    7304,
                    7204,
                    7102,
                    "Other project task",
                    30,
                    other_project_day.isoformat(),
                    6,
                    None,
                    5,
                    today.isoformat(),
                    None,
                ),
            ],
        )
        await db.commit()

    return {
        "today": today.isoformat(),
        "first_day": first_day.isoformat(),
        "second_day": second_day.isoformat(),
        "first_day_plus_week": (first_day + timedelta(days=7)).isoformat(),
        "second_day_plus_week": (second_day + timedelta(days=7)).isoformat(),
        "completed_day": completed_day.isoformat(),
        "other_project_day": other_project_day.isoformat(),
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
            "events": await _fetchall(
                db,
                "SELECT id, event_type, payload FROM events ORDER BY id",
            ),
        }


async def _seed_dialogue_apply_empty_project(db_path: str) -> None:
    today = date.today()
    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                7401,
                "Dialogue Apply Empty Project",
                "study_project",
                "sequential",
                "https://example.com/dialogue-empty",
                "active",
                1,
                (today + timedelta(days=30)).isoformat(),
            ),
        )
        await db.execute(
            """
            INSERT INTO units
                (id, resource_id, title, order_index, estimated_minutes, status)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (7501, 7401, "Already completed unit", 1, 30, "completed"),
        )
        await db.execute(
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
                    completed_at
                )
            VALUES (?, ?, ?, ?, 'time', ?, ?, ?, ?)
            """,
            (
                7601,
                7501,
                7401,
                "Already completed task",
                30,
                (today + timedelta(days=1)).isoformat(),
                9,
                "2026-05-20T10:00:00+00:00",
            ),
        )
        await db.commit()


@pytest.mark.asyncio
async def test_dialogue_apply_writes_exact_previewed_changes_and_refresh_contract(client):
    days = await _seed_dialogue_apply_project(os.environ["DB_PATH"])
    preview_response = await client.post(
        "/api/study-plan-adjustment/dialogue/preview",
        json={"instruction": "push project 7101 by one week"},
    )
    preview = preview_response.json()

    response = await client.post(
        "/api/study-plan-adjustment/dialogue/apply",
        json={"instruction": "push project 7101 by one week", "preview": preview},
    )

    assert response.status_code == 200, response.text
    assert response.json() == {
        "status": "applied",
        "source": "dialogue_apply",
        "command": "project_shift",
        "project_id": 7101,
        "delta_days": 7,
        "affected_task_ids": [7301, 7302],
        "changes": preview["changes"],
        "mutates": True,
        "refresh": {"today": True, "project_overview": True, "calendar": True},
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
            WHERE event_type = 'study_dialogue_adjustment_applied'
            ORDER BY id
            """,
        )

    assert tasks == [
        {
            "id": 7301,
            "scheduled_date": days["first_day_plus_week"],
            "auto_roll_days": 0,
            "last_auto_rolled_at": None,
            "user_adjusted_at": tasks[0]["user_adjusted_at"],
        },
        {
            "id": 7302,
            "scheduled_date": days["second_day_plus_week"],
            "auto_roll_days": 0,
            "last_auto_rolled_at": None,
            "user_adjusted_at": tasks[1]["user_adjusted_at"],
        },
        {
            "id": 7303,
            "scheduled_date": days["completed_day"],
            "auto_roll_days": 4,
            "last_auto_rolled_at": days["today"],
            "user_adjusted_at": None,
        },
        {
            "id": 7304,
            "scheduled_date": days["other_project_day"],
            "auto_roll_days": 5,
            "last_auto_rolled_at": days["today"],
            "user_adjusted_at": None,
        },
    ]
    assert tasks[0]["user_adjusted_at"] is not None
    assert tasks[1]["user_adjusted_at"] is not None
    assert len(events) == 1
    assert json.loads(events[0]["payload"]) == {
        "source": "dialogue_apply",
        "command": "project_shift",
        "project_id": 7101,
        "delta_days": 7,
        "affected_task_ids": [7301, 7302],
        "changes": [
            {
                "task_id": 7301,
                "project_id": 7101,
                "original_date": days["first_day"],
                "new_date": days["first_day_plus_week"],
            },
            {
                "task_id": 7302,
                "project_id": 7101,
                "original_date": days["second_day"],
                "new_date": days["second_day_plus_week"],
            },
        ],
    }


@pytest.mark.asyncio
async def test_dialogue_apply_rejects_preview_when_red_state_impact_drifted_without_mutation_or_event(
    client,
):
    await _seed_dialogue_apply_project(os.environ["DB_PATH"])
    preview_response = await client.post(
        "/api/study-plan-adjustment/dialogue/preview",
        json={"instruction": "push project 7101 by one week"},
    )
    preview = preview_response.json()
    assert preview["red_state_impact"]["over_capacity"]["after_dates"] == []

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.execute(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            ("daily_capacity_min", "20"),
        )
        await db.commit()
    before = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-plan-adjustment/dialogue/apply",
        json={"instruction": "push project 7101 by one week", "preview": preview},
    )

    assert response.status_code == 200, response.text
    assert response.json()["status"] == "stale_preview"
    assert response.json()["mutates"] is False
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before


@pytest.mark.asyncio
async def test_dialogue_preview_and_apply_reject_empty_project_shift_without_mutation_or_event(client):
    await _seed_dialogue_apply_empty_project(os.environ["DB_PATH"])
    before = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    preview_response = await client.post(
        "/api/study-plan-adjustment/dialogue/preview",
        json={"instruction": "push project 7401 by one week"},
    )

    assert preview_response.status_code == 200, preview_response.text
    preview = preview_response.json()
    assert preview["status"] == "unsupported"
    assert preview["mutates"] is False

    apply_response = await client.post(
        "/api/study-plan-adjustment/dialogue/apply",
        json={"instruction": "push project 7401 by one week", "preview": preview},
    )

    assert apply_response.status_code == 200, apply_response.text
    assert apply_response.json()["status"] in {"unsupported", "stale_preview"}
    assert apply_response.json()["mutates"] is False
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before


@pytest.mark.asyncio
async def test_dialogue_apply_rejects_duplicate_affected_task_ids_without_mutation_or_event(client):
    await _seed_dialogue_apply_project(os.environ["DB_PATH"])
    preview_response = await client.post(
        "/api/study-plan-adjustment/dialogue/preview",
        json={"instruction": "push project 7101 by one week"},
    )
    preview = copy.deepcopy(preview_response.json())
    preview["affected_task_ids"] = [7301, 7301]
    before = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-plan-adjustment/dialogue/apply",
        json={"instruction": "push project 7101 by one week", "preview": preview},
    )

    assert response.status_code == 200, response.text
    assert response.json()["status"] == "stale_preview"
    assert response.json()["mutates"] is False
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "payload",
    [
        {"instruction": "delete all tasks", "preview": {"status": "unsupported", "mutates": False}},
        {"instruction": "push this project by one week"},
    ],
)
async def test_dialogue_apply_rejects_unsupported_or_ambiguous_instruction_without_mutation(
    client,
    payload,
):
    await _seed_dialogue_apply_project(os.environ["DB_PATH"])
    before = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post("/api/study-plan-adjustment/dialogue/apply", json=payload)

    assert response.status_code == 200, response.text
    assert response.json()["status"] == "unsupported"
    assert response.json()["mutates"] is False
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before


@pytest.mark.asyncio
async def test_dialogue_apply_rejects_tampered_preview_without_mutation_or_event(client):
    await _seed_dialogue_apply_project(os.environ["DB_PATH"])
    preview_response = await client.post(
        "/api/study-plan-adjustment/dialogue/preview",
        json={"instruction": "push project 7101 by one week"},
    )
    preview = copy.deepcopy(preview_response.json())
    preview["changes"][0]["new_date"] = (date.today() + timedelta(days=90)).isoformat()
    before = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-plan-adjustment/dialogue/apply",
        json={"instruction": "push project 7101 by one week", "preview": preview},
    )

    assert response.status_code == 200, response.text
    assert response.json()["status"] == "stale_preview"
    assert response.json()["mutates"] is False
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before


@pytest.mark.asyncio
async def test_dialogue_apply_rejects_stale_preview_after_task_date_changes_without_mutation_or_event(
    client,
):
    await _seed_dialogue_apply_project(os.environ["DB_PATH"])
    preview_response = await client.post(
        "/api/study-plan-adjustment/dialogue/preview",
        json={"instruction": "push project 7101 by one week"},
    )
    preview = preview_response.json()

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.execute(
            "UPDATE tasks SET scheduled_date = ? WHERE id = ?",
            ((date.today() + timedelta(days=2)).isoformat(), 7301),
        )
        await db.commit()
    before = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-plan-adjustment/dialogue/apply",
        json={"instruction": "push project 7101 by one week", "preview": preview},
    )

    assert response.status_code == 200, response.text
    assert response.json()["status"] == "stale_preview"
    assert response.json()["mutates"] is False
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before
