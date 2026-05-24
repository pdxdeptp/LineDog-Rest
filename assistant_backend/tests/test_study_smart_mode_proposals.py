import hashlib
import inspect
import json
import os
from datetime import date, timedelta

import aiosqlite
import pytest


async def _fetchall(db: aiosqlite.Connection, sql: str, params: tuple = ()) -> list[dict]:
    async with db.execute(sql, params) as cursor:
        rows = await cursor.fetchall()
    return [dict(row) for row in rows]


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
        }


async def _seed_morning_proposal_facts(db_path: str, smart_mode_enabled: bool = True) -> dict[str, str]:
    today = date.today()
    tomorrow = today + timedelta(days=1)
    day_after = today + timedelta(days=2)
    late_task_day = today + timedelta(days=4)

    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            ("study_smart_mode_enabled", "true" if smart_mode_enabled else "false"),
        )
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
                    8101,
                    "Lag Project",
                    "study_project",
                    "sequential",
                    "https://example.com/lag",
                    "active",
                    2,
                    (today + timedelta(days=30)).isoformat(),
                ),
                (
                    8102,
                    "Late Project",
                    "study_project",
                    "sequential",
                    "https://example.com/late",
                    "active",
                    1,
                    tomorrow.isoformat(),
                ),
                (
                    8103,
                    "Capacity Project",
                    "study_project",
                    "sequential",
                    "https://example.com/capacity",
                    "active",
                    2,
                    (today + timedelta(days=30)).isoformat(),
                ),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (
                    id,
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
            VALUES (?, ?, ?, 'time', ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (8201, 8101, "Rolled task", 25, today.isoformat(), 10, None, 3, today.isoformat(), None),
                (8202, 8101, "Lag follow-up", 10, tomorrow.isoformat(), 9, None, 0, None, None),
                (8203, 8102, "Late task", 30, late_task_day.isoformat(), 8, None, 0, None, None),
                (8204, 8103, "Capacity anchor", 45, tomorrow.isoformat(), 7, None, 0, None, None),
                (8205, 8103, "Capacity overflow", 30, tomorrow.isoformat(), 6, None, 0, None, None),
            ],
        )
        await db.commit()

    return {
        "today": today.isoformat(),
        "tomorrow": tomorrow.isoformat(),
        "day_after": day_after.isoformat(),
        "late_task_day": late_task_day.isoformat(),
    }


async def _seed_pending_rollover_proposal_facts(db_path: str) -> dict[str, str]:
    today = date.today()
    yesterday = today - timedelta(days=1)
    tomorrow = today + timedelta(days=1)

    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            ("study_smart_mode_enabled", "true"),
        )
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
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                8301,
                "Pending Rollover Project",
                "study_project",
                "sequential",
                "https://example.com/pending-rollover",
                "active",
                2,
                (today + timedelta(days=30)).isoformat(),
            ),
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (
                    id,
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
            VALUES (?, ?, ?, 'time', ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (8401, 8301, "Yesterday unfinished task", 25, yesterday.isoformat(), 9, None, 2, None, None),
                (8402, 8301, "Follow-up task", 20, tomorrow.isoformat(), 8, None, 0, None, None),
            ],
        )
        await db.commit()

    return {
        "today": today.isoformat(),
        "yesterday": yesterday.isoformat(),
        "tomorrow": tomorrow.isoformat(),
    }


async def _seed_over_capacity_selection_facts(db_path: str) -> dict[str, str]:
    today = date.today()
    overloaded_day = today + timedelta(days=1)
    followup_day = today + timedelta(days=2)
    followup_new_day = today + timedelta(days=3)

    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            ("study_smart_mode_enabled", "true"),
        )
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
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                8501,
                "Capacity Selection Project",
                "study_project",
                "sequential",
                "https://example.com/capacity-selection",
                "active",
                3,
                (today + timedelta(days=30)).isoformat(),
            ),
        )
        await db.executemany(
            """
            INSERT INTO units
                (id, resource_id, title, order_index, estimated_minutes, status)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [
                (8511, 8501, "Early overloaded unit", 1, 30, "pending"),
                (8512, 8501, "Later overloaded unit", 2, 35, "pending"),
                (8513, 8501, "Follow-up unit", 3, 15, "pending"),
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
                (8601, 8511, 8501, "Low priority early overloaded task", 30, overloaded_day.isoformat(), 1, None, 0, None, None),
                (8602, 8512, 8501, "Later overloaded task", 35, overloaded_day.isoformat(), 9, None, 0, None, None),
                (8603, 8513, 8501, "Later cascading task", 15, followup_day.isoformat(), 8, None, 0, None, None),
            ],
        )
        await db.commit()

    return {
        "overloaded_day": overloaded_day.isoformat(),
        "followup_day": followup_day.isoformat(),
        "followup_new_day": followup_new_day.isoformat(),
    }


@pytest.mark.asyncio
async def test_disabled_smart_mode_suppresses_morning_proposals_even_when_red_facts_exist(client):
    await _seed_morning_proposal_facts(os.environ["DB_PATH"], smart_mode_enabled=False)
    before = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post("/api/study-smart-mode/proposals", json={"trigger": "morning"})

    assert response.status_code == 200, response.text
    assert response.json() == {
        "enabled": False,
        "trigger": "morning",
        "options": [],
    }
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before


@pytest.mark.asyncio
async def test_morning_proposals_do_not_roll_over_or_write_events_before_apply(client):
    days = await _seed_pending_rollover_proposal_facts(os.environ["DB_PATH"])
    before = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post("/api/study-smart-mode/proposals", json={"trigger": "morning"})

    assert response.status_code == 200, response.text
    body = response.json()
    assert [option["id"] for option in body["options"]] == [
        "smart-morning-rolled-task-lag-8401",
    ]
    assert body["options"][0]["reason"]["rolled_day_count"] == 3
    assert body["options"][0]["previewed_changes"] == [
        {
            "task_id": 8402,
            "project_id": 8301,
            "old_date": days["tomorrow"],
            "new_date": (date.fromisoformat(days["tomorrow"]) + timedelta(days=1)).isoformat(),
        }
    ]
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before


@pytest.mark.asyncio
async def test_after_adjustment_trigger_stays_empty_for_this_slice(client):
    await _seed_morning_proposal_facts(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-smart-mode/proposals",
        json={"trigger": "after_adjustment"},
    )

    assert response.status_code == 200, response.text
    assert response.json() == {
        "enabled": True,
        "trigger": "after_adjustment",
        "options": [],
    }


@pytest.mark.asyncio
async def test_morning_proposals_include_structured_previews_for_lag_late_and_capacity(client):
    days = await _seed_morning_proposal_facts(os.environ["DB_PATH"])
    before = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post("/api/study-smart-mode/proposals", json={"trigger": "morning"})

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["enabled"] is True
    assert body["trigger"] == "morning"
    assert [option["id"] for option in body["options"]] == [
        "smart-morning-rolled-task-lag-8201",
        "smart-morning-expected-late-project-8102",
        f"smart-morning-over-capacity-day-{days['tomorrow']}",
    ]
    assert len({option["signature"] for option in body["options"]}) == 3
    assert all(len(option["signature"]) == 64 for option in body["options"])
    assert all(option["trigger"] == "morning" for option in body["options"])
    assert all(option["preview"]["status"] == "preview" for option in body["options"])
    assert all(option["preview"]["mutates"] is False for option in body["options"])
    assert all(option["summary"] for option in body["options"])
    assert all(option["tradeoff"] for option in body["options"])
    assert all(option["signature_version"] == 1 for option in body["options"])
    for option in body["options"]:
        canonical = option["signature_payload"]
        assert "summary" not in json.dumps(canonical)
        assert "tradeoff" not in json.dumps(canonical)
        expected_signature = hashlib.sha256(
            json.dumps(
                {"version": option["signature_version"], "payload": canonical},
                sort_keys=True,
                separators=(",", ":"),
            ).encode("utf-8")
        ).hexdigest()
        assert option["signature"] == expected_signature

    by_id = {option["id"]: option for option in body["options"]}
    lag_option = by_id["smart-morning-rolled-task-lag-8201"]
    assert lag_option["reason"]["type"] == "rolled_task_lag"
    assert lag_option["reason"]["task_id"] == 8201
    assert lag_option["reason"]["project_id"] == 8101
    assert lag_option["reason"]["rolled_day_count"] == 3
    assert lag_option["affected_project_ids"] == [8101]
    assert lag_option["affected_task_ids"] == [8201, 8202]
    assert lag_option["preview"]["command"] == "make_room_after_lag"
    assert lag_option["previewed_changes"] == [
        {
            "task_id": 8202,
            "project_id": 8101,
            "old_date": days["tomorrow"],
            "new_date": days["day_after"],
        }
    ]
    assert lag_option["red_state_impact"]["expected_late"] == {
        "before": False,
        "after": False,
        "before_project_ids": [],
        "after_project_ids": [],
    }

    late_option = by_id["smart-morning-expected-late-project-8102"]
    assert late_option["reason"]["type"] == "expected_late_project"
    assert late_option["affected_project_ids"] == [8102]
    assert late_option["affected_task_ids"] == [8203]
    assert late_option["preview"]["command"] == "extend_project_deadline"
    assert late_option["previewed_changes"] == [
        {
            "project_id": 8102,
            "field": "deadline",
            "old_deadline": days["tomorrow"],
            "new_deadline": days["late_task_day"],
        }
    ]
    assert late_option["red_state_impact"]["expected_late"] == {
        "before": True,
        "after": False,
        "before_project_ids": [8102],
        "after_project_ids": [],
    }

    capacity_option = by_id[f"smart-morning-over-capacity-day-{days['tomorrow']}"]
    assert capacity_option["reason"]["type"] == "over_capacity_day"
    assert capacity_option["affected_project_ids"] == [8103]
    assert capacity_option["affected_task_ids"] == [8205]
    assert capacity_option["preview"]["command"] == "move_task_from_over_capacity_day"
    assert capacity_option["previewed_changes"] == [
        {
            "task_id": 8205,
            "project_id": 8103,
            "old_date": days["tomorrow"],
            "new_date": days["day_after"],
        }
    ]
    assert capacity_option["red_state_impact"]["over_capacity"] == {
        "before_dates": [days["tomorrow"]],
        "after_dates": [],
        "new_over_capacity_dates": [],
        "resolved_over_capacity_dates": [days["tomorrow"]],
    }

    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before

    repeat = await client.post("/api/study-smart-mode/proposals", json={"trigger": "morning"})
    assert repeat.status_code == 200, repeat.text
    assert repeat.json()["options"] == body["options"]

    briefing = await client.get("/api/study-smart-mode/morning-briefing")
    assert briefing.status_code == 200, briefing.text
    assert briefing.json()["options"] == body["options"]


@pytest.mark.asyncio
async def test_over_capacity_option_selects_latest_overloaded_task_and_names_cascade(client):
    days = await _seed_over_capacity_selection_facts(os.environ["DB_PATH"])

    response = await client.post("/api/study-smart-mode/proposals", json={"trigger": "morning"})

    assert response.status_code == 200, response.text
    [option] = response.json()["options"]
    assert option["id"] == f"smart-morning-over-capacity-day-{days['overloaded_day']}"
    assert option["preview"]["selection_policy"] == {
        "strategy": "minimize_same_project_cascade_before_priority",
        "candidate_task_ids": [8601, 8602],
        "candidate_evaluations": [
            {
                "task_id": 8601,
                "priority": 1,
                "cascade_count": 3,
                "cascading_affected_task_ids": [8601, 8602, 8603],
            },
            {
                "task_id": 8602,
                "priority": 9,
                "cascade_count": 2,
                "cascading_affected_task_ids": [8602, 8603],
            },
        ],
        "selected_task_id": 8602,
        "cascading_affected_task_ids": [8602, 8603],
        "selection_reason": (
            "Selected task 8602 because it has the smallest same-project cascade "
            "(2 tasks), before using priority as a tie-breaker."
        ),
    }
    assert option["affected_task_ids"] == [8602, 8603]
    assert option["previewed_changes"] == [
        {
            "task_id": 8602,
            "project_id": 8501,
            "old_date": days["overloaded_day"],
            "new_date": days["followup_day"],
        },
        {
            "task_id": 8603,
            "project_id": 8501,
            "old_date": days["followup_day"],
            "new_date": days["followup_new_day"],
        },
    ]
    assert "1 later same-project task" in option["tradeoff"]
    assert "smaller same-project cascade before priority" in option["tradeoff"]
    assert "higher-priority task may move" in option["tradeoff"]


def test_smart_mode_router_uses_public_capacity_preview_helper():
    from src.routers import study_smart_mode

    source = inspect.getsource(study_smart_mode)
    assert "_preview_over_capacity_impact" not in source
