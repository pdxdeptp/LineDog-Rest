import hashlib
import inspect
import json
import os
from copy import deepcopy
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


def _resign_proposal_for_test(proposal: dict) -> dict:
    canonical = {
        "id": proposal["id"],
        "trigger": proposal["trigger"],
        "reason": {
            key: value
            for key, value in proposal["reason"].items()
            if key != "summary"
        },
        "affected_project_ids": proposal["affected_project_ids"],
        "affected_task_ids": proposal["affected_task_ids"],
        "preview": proposal["preview"],
        "previewed_changes": proposal["previewed_changes"],
        "red_state_impact": proposal["red_state_impact"],
    }
    proposal["signature_payload"] = canonical
    proposal["signature"] = hashlib.sha256(
        json.dumps(
            {"version": proposal["signature_version"], "payload": canonical},
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    ).hexdigest()
    return proposal


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


async def _seed_after_adjustment_red_state_facts(db_path: str) -> dict[str, str]:
    today = date.today()
    tomorrow = today + timedelta(days=1)
    day_after = today + timedelta(days=2)
    later_day = today + timedelta(days=3)

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
        await db.executemany(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    8701,
                    "New Late Project",
                    "study_project",
                    "sequential",
                    "https://example.com/new-late",
                    "active",
                    1,
                    tomorrow.isoformat(),
                ),
                (
                    8702,
                    "Existing Late Project",
                    "study_project",
                    "sequential",
                    "https://example.com/existing-late",
                    "active",
                    1,
                    tomorrow.isoformat(),
                ),
                (
                    8703,
                    "New Capacity Project",
                    "study_project",
                    "sequential",
                    "https://example.com/new-capacity",
                    "active",
                    2,
                    later_day.isoformat(),
                ),
                (
                    8704,
                    "Existing Capacity Project",
                    "study_project",
                    "sequential",
                    "https://example.com/existing-capacity",
                    "active",
                    2,
                    later_day.isoformat(),
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
                (8801, 8701, "New late task", 30, day_after.isoformat(), 8, None, 0, None, None),
                (8802, 8702, "Existing late task", 30, day_after.isoformat(), 7, None, 0, None, None),
                (8803, 8703, "New capacity anchor", 40, tomorrow.isoformat(), 6, None, 0, None, None),
                (8804, 8703, "New capacity overflow", 35, tomorrow.isoformat(), 5, None, 0, None, None),
                (8805, 8704, "Existing capacity anchor", 40, day_after.isoformat(), 4, None, 0, None, None),
                (8806, 8704, "Existing capacity overflow", 35, day_after.isoformat(), 3, None, 0, None, None),
            ],
        )
        await db.commit()

    return {
        "tomorrow": tomorrow.isoformat(),
        "day_after": day_after.isoformat(),
    }


async def _seed_after_adjustment_lag_only_facts(db_path: str) -> dict[str, str]:
    today = date.today()
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
                8901,
                "Lag Only Project",
                "study_project",
                "sequential",
                "https://example.com/lag-only",
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
                (8911, 8901, "Rolled task", 25, today.isoformat(), 10, None, 3, today.isoformat(), None),
                (8912, 8901, "Follow-up", 10, tomorrow.isoformat(), 9, None, 0, None, None),
            ],
        )
        await db.commit()

    return {"today": today.isoformat()}


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
async def test_after_adjustment_proposals_include_only_newly_created_red_state_options(client):
    days = await _seed_after_adjustment_red_state_facts(os.environ["DB_PATH"])
    before = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-smart-mode/proposals",
        json={
            "trigger": "after_adjustment",
            "previous_expected_late_project_ids": [8702],
            "previous_over_capacity_dates": [days["day_after"]],
        },
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["enabled"] is True
    assert body["trigger"] == "after_adjustment"
    assert [option["id"] for option in body["options"]] == [
        "smart-after-adjustment-expected-late-project-8701",
        f"smart-after-adjustment-over-capacity-day-{days['tomorrow']}",
    ]
    assert all(option["trigger"] == "after_adjustment" for option in body["options"])
    assert all(option["preview"]["trigger"] == "after_adjustment" for option in body["options"])
    assert all(option["preview"]["mutates"] is False for option in body["options"])

    late_option, capacity_option = body["options"]
    assert late_option["reason"]["type"] == "expected_late_project"
    assert late_option["affected_project_ids"] == [8701]
    assert late_option["previewed_changes"] == [
        {
            "project_id": 8701,
            "field": "deadline",
            "old_deadline": days["tomorrow"],
            "new_deadline": days["day_after"],
        }
    ]
    assert capacity_option["reason"]["type"] == "over_capacity_day"
    assert capacity_option["reason"]["date"] == days["tomorrow"]
    assert capacity_option["affected_project_ids"] == [8703]
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before


@pytest.mark.asyncio
async def test_after_adjustment_proposals_stay_empty_for_existing_red_state(client):
    days = await _seed_after_adjustment_red_state_facts(os.environ["DB_PATH"])

    existing_red_response = await client.post(
        "/api/study-smart-mode/proposals",
        json={
            "trigger": "after_adjustment",
            "previous_expected_late_project_ids": [8701, 8702],
            "previous_over_capacity_dates": [days["tomorrow"], days["day_after"]],
        },
    )

    assert existing_red_response.status_code == 200, existing_red_response.text
    assert existing_red_response.json() == {
        "enabled": True,
        "trigger": "after_adjustment",
        "options": [],
    }


@pytest.mark.asyncio
async def test_after_adjustment_partial_expected_late_context_does_not_return_capacity_options(client):
    await _seed_after_adjustment_red_state_facts(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-smart-mode/proposals",
        json={
            "trigger": "after_adjustment",
            "previous_expected_late_project_ids": [8702],
        },
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["enabled"] is True
    assert body["trigger"] == "after_adjustment"
    assert [option["id"] for option in body["options"]] == [
        "smart-after-adjustment-expected-late-project-8701",
    ]
    assert all(option["reason"]["type"] == "expected_late_project" for option in body["options"])


@pytest.mark.asyncio
async def test_after_adjustment_partial_capacity_context_does_not_return_expected_late_options(client):
    days = await _seed_after_adjustment_red_state_facts(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-smart-mode/proposals",
        json={
            "trigger": "after_adjustment",
            "previous_over_capacity_dates": [days["day_after"]],
        },
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["enabled"] is True
    assert body["trigger"] == "after_adjustment"
    assert [option["id"] for option in body["options"]] == [
        f"smart-after-adjustment-over-capacity-day-{days['tomorrow']}",
    ]
    assert all(option["reason"]["type"] == "over_capacity_day" for option in body["options"])


@pytest.mark.asyncio
async def test_after_adjustment_proposals_stay_empty_for_lag_only_even_with_context(client):
    await _seed_after_adjustment_lag_only_facts(os.environ["DB_PATH"])

    lag_response = await client.post(
        "/api/study-smart-mode/proposals",
        json={
            "trigger": "after_adjustment",
            "previous_expected_late_project_ids": [],
            "previous_over_capacity_dates": [],
        },
    )

    assert lag_response.status_code == 200, lag_response.text
    assert lag_response.json() == {
        "enabled": True,
        "trigger": "after_adjustment",
        "options": [],
    }


@pytest.mark.asyncio
async def test_disabled_smart_mode_suppresses_after_adjustment_proposals(client):
    days = await _seed_after_adjustment_red_state_facts(os.environ["DB_PATH"])
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.execute(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            ("study_smart_mode_enabled", "false"),
        )
        await db.commit()

    response = await client.post(
        "/api/study-smart-mode/proposals",
        json={
            "trigger": "after_adjustment",
            "previous_expected_late_project_ids": [8702],
            "previous_over_capacity_dates": [days["day_after"]],
        },
    )

    assert response.status_code == 200, response.text
    assert response.json() == {
        "enabled": False,
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


@pytest.mark.asyncio
async def test_apply_current_expected_late_proposal_extends_deadline_and_records_event(client):
    days = await _seed_morning_proposal_facts(os.environ["DB_PATH"])
    proposals_response = await client.post("/api/study-smart-mode/proposals", json={"trigger": "morning"})
    proposals = proposals_response.json()["options"]
    selected = next(
        option
        for option in proposals
        if option["preview"]["command"] == "extend_project_deadline"
    )

    response = await client.post(
        "/api/study-smart-mode/proposals/apply",
        json={"proposal": selected},
    )

    assert response.status_code == 200, response.text
    assert response.json() == {
        "status": "applied",
        "source": "smart_mode_apply",
        "proposal_id": selected["id"],
        "signature": selected["signature"],
        "trigger": "morning",
        "command": "extend_project_deadline",
        "affected_project_ids": [8102],
        "affected_task_ids": [8203],
        "applied_changes": selected["previewed_changes"],
        "mutates": True,
        "refresh": {"today": True, "project_overview": True, "calendar": True},
    }

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        resources = await _fetchall(
            db,
            "SELECT id, deadline FROM resources WHERE id IN (8101, 8102, 8103) ORDER BY id",
        )
        events = await _fetchall(
            db,
            """
            SELECT event_type, payload
            FROM events
            WHERE event_type = 'study_smart_mode_proposal_applied'
            ORDER BY id
            """,
        )

    assert resources == [
        {
            "id": 8101,
            "deadline": (date.fromisoformat(days["today"]) + timedelta(days=30)).isoformat(),
        },
        {"id": 8102, "deadline": days["late_task_day"]},
        {
            "id": 8103,
            "deadline": (date.fromisoformat(days["today"]) + timedelta(days=30)).isoformat(),
        },
    ]
    assert len(events) == 1
    assert json.loads(events[0]["payload"]) == {
        "source": "smart_mode_apply",
        "proposal_id": selected["id"],
        "signature": selected["signature"],
        "signature_payload": selected["signature_payload"],
        "trigger": "morning",
        "command": "extend_project_deadline",
        "reason": selected["reason"],
        "affected_project_ids": [8102],
        "affected_task_ids": [8203],
        "red_state_impact": selected["red_state_impact"],
        "selected_preview": selected["preview"],
        "applied_changes": selected["previewed_changes"],
    }


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("command", "changed_task_ids", "unchanged_task_ids"),
    [
        ("make_room_after_lag", [8202], [8201, 8203, 8204, 8205]),
        ("move_task_from_over_capacity_day", [8205], [8201, 8202, 8203, 8204]),
    ],
)
async def test_apply_current_task_date_proposal_writes_exact_previewed_changes_and_event(
    client,
    command,
    changed_task_ids,
    unchanged_task_ids,
):
    await _seed_morning_proposal_facts(os.environ["DB_PATH"])
    before = await _snapshot_mutation_guard(os.environ["DB_PATH"])
    proposals_response = await client.post("/api/study-smart-mode/proposals", json={"trigger": "morning"})
    proposals = proposals_response.json()["options"]
    selected = next(option for option in proposals if option["preview"]["command"] == command)

    response = await client.post(
        "/api/study-smart-mode/proposals/apply",
        json={"proposal": selected},
    )

    assert response.status_code == 200, response.text
    assert response.json() == {
        "status": "applied",
        "source": "smart_mode_apply",
        "proposal_id": selected["id"],
        "signature": selected["signature"],
        "trigger": "morning",
        "command": command,
        "affected_project_ids": selected["affected_project_ids"],
        "affected_task_ids": selected["affected_task_ids"],
        "applied_changes": selected["previewed_changes"],
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
            WHERE event_type = 'study_smart_mode_proposal_applied'
            ORDER BY id
            """,
        )

    task_by_id = {task["id"]: task for task in tasks}
    before_task_by_id = {task["id"]: task for task in before["tasks"]}
    expected_new_dates = {
        change["task_id"]: change["new_date"] for change in selected["previewed_changes"]
    }
    for task_id in changed_task_ids:
        assert task_by_id[task_id]["scheduled_date"] == expected_new_dates[task_id]
        assert task_by_id[task_id]["auto_roll_days"] == 0
        assert task_by_id[task_id]["last_auto_rolled_at"] is None
        assert task_by_id[task_id]["user_adjusted_at"] is not None
    for task_id in unchanged_task_ids:
        assert task_by_id[task_id] == before_task_by_id[task_id]

    assert len(events) == 1
    assert json.loads(events[0]["payload"]) == {
        "source": "smart_mode_apply",
        "proposal_id": selected["id"],
        "signature": selected["signature"],
        "signature_payload": selected["signature_payload"],
        "trigger": "morning",
        "command": command,
        "reason": selected["reason"],
        "affected_project_ids": selected["affected_project_ids"],
        "affected_task_ids": selected["affected_task_ids"],
        "red_state_impact": selected["red_state_impact"],
        "selected_preview": selected["preview"],
        "applied_changes": selected["previewed_changes"],
    }


@pytest.mark.asyncio
async def test_apply_rejects_stale_proposal_after_current_facts_drift_without_mutation(client):
    days = await _seed_morning_proposal_facts(os.environ["DB_PATH"])
    proposals_response = await client.post("/api/study-smart-mode/proposals", json={"trigger": "morning"})
    selected = next(
        option
        for option in proposals_response.json()["options"]
        if option["preview"]["command"] == "extend_project_deadline"
    )

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.execute(
            "UPDATE resources SET deadline = ? WHERE id = ?",
            (days["day_after"], 8102),
        )
        await db.commit()
    before_apply = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-smart-mode/proposals/apply",
        json={"proposal": selected},
    )

    assert response.status_code == 200, response.text
    assert response.json() == {
        "status": "stale_proposal",
        "mutates": False,
        "message": "submitted proposal does not match the current active plan",
    }
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before_apply


@pytest.mark.asyncio
async def test_apply_rejects_disabled_smart_mode_without_mutation(client):
    await _seed_morning_proposal_facts(os.environ["DB_PATH"])
    proposals_response = await client.post("/api/study-smart-mode/proposals", json={"trigger": "morning"})
    selected = proposals_response.json()["options"][0]
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.execute(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            ("study_smart_mode_enabled", "false"),
        )
        await db.commit()
    before_apply = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-smart-mode/proposals/apply",
        json={"proposal": selected},
    )

    assert response.status_code == 200, response.text
    assert response.json() == {
        "status": "disabled",
        "mutates": False,
        "message": "smart mode is disabled",
    }
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before_apply


@pytest.mark.asyncio
async def test_apply_rejects_unsupported_signed_command_without_mutation(client):
    await _seed_morning_proposal_facts(os.environ["DB_PATH"])
    proposals_response = await client.post("/api/study-smart-mode/proposals", json={"trigger": "morning"})
    selected = deepcopy(proposals_response.json()["options"][0])
    selected["preview"]["command"] = "rewrite_entire_study_plan"
    selected = _resign_proposal_for_test(selected)
    before_apply = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-smart-mode/proposals/apply",
        json={"proposal": selected},
    )

    assert response.status_code == 200, response.text
    assert response.json() == {
        "status": "unsupported",
        "mutates": False,
        "message": "submitted proposal is unsupported",
    }
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before_apply


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "request_body",
    [
        {},
        {"proposal": {}},
        {"proposal": {"id": "not-a-recognized-smart-mode-proposal"}},
    ],
)
async def test_apply_rejects_missing_or_unrecognized_selected_proposal_without_mutation(
    client,
    request_body,
):
    await _seed_morning_proposal_facts(os.environ["DB_PATH"])
    before_apply = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-smart-mode/proposals/apply",
        json=request_body,
    )

    assert response.status_code == 200, response.text
    assert response.json()["status"] == "unsupported"
    assert response.json()["mutates"] is False
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before_apply


@pytest.mark.asyncio
@pytest.mark.parametrize("tamper_target", ["preview", "signature_payload"])
async def test_apply_rejects_tampered_proposal_without_mutation(client, tamper_target):
    await _seed_morning_proposal_facts(os.environ["DB_PATH"])
    proposals_response = await client.post("/api/study-smart-mode/proposals", json={"trigger": "morning"})
    selected = deepcopy(proposals_response.json()["options"][0])
    if tamper_target == "preview":
        selected["preview"]["delta_days"] = 99
    else:
        selected["signature_payload"]["previewed_changes"] = []
    before_apply = await _snapshot_mutation_guard(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-smart-mode/proposals/apply",
        json={"proposal": selected},
    )

    assert response.status_code == 200, response.text
    assert response.json()["status"] in {"stale_proposal", "unsupported"}
    assert response.json()["mutates"] is False
    assert await _snapshot_mutation_guard(os.environ["DB_PATH"]) == before_apply


def test_smart_mode_router_uses_public_capacity_preview_helper():
    from src.routers import study_smart_mode

    source = inspect.getsource(study_smart_mode)
    assert "_preview_over_capacity_impact" not in source
