import json
import os

import aiosqlite
import pytest


async def _fetchall(db: aiosqlite.Connection, sql: str, params: tuple = ()) -> list[dict]:
    async with db.execute(sql, params) as cur:
        rows = await cur.fetchall()
    return [dict(row) for row in rows]


async def _seed_rest_day_calendar_project(db_path: str) -> None:
    async with aiosqlite.connect(db_path) as db:
        await db.execute("INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)", ("daily_capacity_min", "60"))
        await db.executemany(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            [
                ("study_rest_weekdays", "[1]"),
                ("study_rest_dates", '["2026-09-03"]'),
            ],
        )
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                7101,
                "Rest Day Calendar Project",
                "study_project",
                "sequential",
                "https://example.com/rest-days",
                "active",
                2,
                "2026-09-30",
            ),
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, priority)
            VALUES (?, ?, ?, 'time', ?, ?, ?)
            """,
            [
                (7201, 7101, "Task on weekly rest day", 30, "2026-09-01", 9),
                (7202, 7101, "Task on one-off rest day", 20, "2026-09-03", 8),
            ],
        )
        await db.commit()


@pytest.mark.asyncio
async def test_get_rest_day_settings_returns_defaults_from_system_state(client):
    response = await client.get("/api/study-plan-adjustment/rest-days")

    assert response.status_code == 200, response.text
    assert response.json() == {
        "weekly_weekdays": [5],
        "one_off_dates": [],
    }


@pytest.mark.asyncio
async def test_put_rest_day_settings_normalizes_persists_and_records_add_remove_event(client):
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.executemany(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            [
                ("study_rest_weekdays", "[2, 5]"),
                ("study_rest_dates", '["2026-06-10"]'),
            ],
        )
        await db.commit()

    response = await client.put(
        "/api/study-plan-adjustment/rest-days",
        json={
            "weekly_weekdays": [6, 5, 6],
            "one_off_dates": ["2026-06-12", "2026-06-01", "2026-06-12"],
        },
    )

    assert response.status_code == 200, response.text
    assert response.json() == {
        "weekly_weekdays": [5, 6],
        "one_off_dates": ["2026-06-01", "2026-06-12"],
        "added_weekly_weekdays": [6],
        "removed_weekly_weekdays": [2],
        "added_one_off_dates": ["2026-06-01", "2026-06-12"],
        "removed_one_off_dates": ["2026-06-10"],
        "source": "manual_rest_day_settings",
    }

    get_response = await client.get("/api/study-plan-adjustment/rest-days")
    assert get_response.status_code == 200, get_response.text
    assert get_response.json() == {
        "weekly_weekdays": [5, 6],
        "one_off_dates": ["2026-06-01", "2026-06-12"],
    }

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        state = await _fetchall(
            db,
            """
            SELECT key, value
            FROM system_state
            WHERE key IN ('study_rest_weekdays', 'study_rest_dates')
            ORDER BY key
            """,
        )
        events = await _fetchall(
            db,
            """
            SELECT event_type, payload
            FROM events
            WHERE event_type = 'study_rest_days_updated'
            ORDER BY id
            """,
        )

    assert {row["key"]: json.loads(row["value"]) for row in state} == {
        "study_rest_dates": ["2026-06-01", "2026-06-12"],
        "study_rest_weekdays": [5, 6],
    }
    assert len(events) == 1
    assert json.loads(events[0]["payload"]) == {
        "old_weekly_weekdays": [2, 5],
        "new_weekly_weekdays": [5, 6],
        "added_weekly_weekdays": [6],
        "removed_weekly_weekdays": [2],
        "old_one_off_dates": ["2026-06-10"],
        "new_one_off_dates": ["2026-06-01", "2026-06-12"],
        "added_one_off_dates": ["2026-06-01", "2026-06-12"],
        "removed_one_off_dates": ["2026-06-10"],
        "source": "manual_rest_day_settings",
    }


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "payload",
    [
        {"weekly_weekdays": [-1], "one_off_dates": ["2026-06-01"]},
        {"weekly_weekdays": [7], "one_off_dates": ["2026-06-01"]},
        {"weekly_weekdays": [5], "one_off_dates": ["not-a-date"]},
    ],
)
async def test_put_rest_day_settings_rejects_invalid_payload_without_mutation_or_event(client, payload):
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.executemany(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            [
                ("study_rest_weekdays", "[5]"),
                ("study_rest_dates", "[]"),
            ],
        )
        await db.commit()

    response = await client.put("/api/study-plan-adjustment/rest-days", json=payload)

    assert response.status_code == 422
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        state = await _fetchall(
            db,
            """
            SELECT key, value
            FROM system_state
            WHERE key IN ('study_rest_weekdays', 'study_rest_dates')
            ORDER BY key
            """,
        )
        events = await _fetchall(db, "SELECT id FROM events WHERE event_type = 'study_rest_days_updated'")

    assert {row["key"]: json.loads(row["value"]) for row in state} == {
        "study_rest_dates": [],
        "study_rest_weekdays": [5],
    }
    assert events == []


@pytest.mark.asyncio
async def test_calendar_marks_weekly_and_one_off_rest_days_with_zero_available_capacity(client):
    await _seed_rest_day_calendar_project(os.environ["DB_PATH"])

    response = await client.get("/api/study-views/calendar?start=2026-09-01&end=2026-09-03")

    assert response.status_code == 200, response.text
    assert response.json()["days"] == [
        {
            "date": "2026-09-01",
            "scheduled_task_count": 1,
            "total_target_minutes": 30,
            "completed_task_count": 0,
            "rest_day": True,
            "available_capacity_minutes": 0,
            "over_capacity": True,
        },
        {
            "date": "2026-09-02",
            "scheduled_task_count": 0,
            "total_target_minutes": 0,
            "completed_task_count": 0,
            "rest_day": False,
            "available_capacity_minutes": 60,
            "over_capacity": False,
        },
        {
            "date": "2026-09-03",
            "scheduled_task_count": 1,
            "total_target_minutes": 20,
            "completed_task_count": 0,
            "rest_day": True,
            "available_capacity_minutes": 0,
            "over_capacity": True,
        },
    ]


@pytest.mark.asyncio
async def test_removing_rest_day_updates_calendar_availability_without_moving_existing_tasks(client):
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.executemany(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            [
                ("daily_capacity_min", "60"),
                ("study_rest_weekdays", "[0]"),
                ("study_rest_dates", "[]"),
            ],
        )
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                7301,
                "Rest Day Removal Project",
                "study_project",
                "sequential",
                "https://example.com/rest-day-removal",
                "active",
                2,
                "2026-10-31",
            ),
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, priority)
            VALUES (?, ?, ?, 'time', ?, ?, ?)
            """,
            [
                (7401, 7301, "Task stays on removed rest day", 40, "2026-10-05", 9),
                (7402, 7301, "Successor stays put", 25, "2026-10-06", 8),
            ],
        )
        await db.commit()

    before_response = await client.get("/api/study-views/calendar?start=2026-10-05&end=2026-10-06")
    update_response = await client.put(
        "/api/study-plan-adjustment/rest-days",
        json={"weekly_weekdays": [], "one_off_dates": []},
    )
    after_response = await client.get("/api/study-views/calendar?start=2026-10-05&end=2026-10-06")

    assert before_response.status_code == 200, before_response.text
    assert before_response.json()["days"][0]["rest_day"] is True
    assert before_response.json()["days"][0]["available_capacity_minutes"] == 0
    assert update_response.status_code == 200, update_response.text
    assert update_response.json()["removed_weekly_weekdays"] == [0]
    assert after_response.status_code == 200, after_response.text
    assert after_response.json()["days"] == [
        {
            "date": "2026-10-05",
            "scheduled_task_count": 1,
            "total_target_minutes": 40,
            "completed_task_count": 0,
            "rest_day": False,
            "available_capacity_minutes": 20,
            "over_capacity": False,
        },
        {
            "date": "2026-10-06",
            "scheduled_task_count": 1,
            "total_target_minutes": 25,
            "completed_task_count": 0,
            "rest_day": False,
            "available_capacity_minutes": 35,
            "over_capacity": False,
        },
    ]

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        tasks = await _fetchall(db, "SELECT id, scheduled_date FROM tasks ORDER BY id")

    assert tasks == [
        {"id": 7401, "scheduled_date": "2026-10-05"},
        {"id": 7402, "scheduled_date": "2026-10-06"},
    ]


@pytest.mark.asyncio
async def test_adding_new_rest_days_cascades_unfinished_active_study_tasks_chronologically(client):
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.executemany(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            [
                ("study_rest_weekdays", "[]"),
                ("study_rest_dates", "[]"),
            ],
        )
        await db.executemany(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    7501,
                    "Cascade Study Project",
                    "study_project",
                    "sequential",
                    "https://example.com/rest-day-cascade",
                    "active",
                    5,
                    "2026-06-30",
                ),
                (
                    7502,
                    "Completed Study Project",
                    "study_project",
                    "sequential",
                    "https://example.com/completed-study",
                    "completed",
                    1,
                    "2026-06-30",
                ),
                (
                    7503,
                    "Non-study Project",
                    "course",
                    "sequential",
                    "https://example.com/non-study",
                    "active",
                    1,
                    "2026-06-30",
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
                    last_auto_rolled_at
                )
            VALUES (?, ?, ?, 'time', ?, ?, ?, ?, ?, ?)
            """,
            [
                (7601, 7501, "Before new rest day", 20, "2026-05-24", 9, None, 3, "2026-05-24T08:00:00+00:00"),
                (7602, 7501, "On one-off rest day", 20, "2026-05-25", 8, None, 2, "2026-05-24T08:00:00+00:00"),
                (7603, 7501, "On weekly rest day", 20, "2026-05-26", 7, None, 1, "2026-05-24T08:00:00+00:00"),
                (7604, 7501, "After both rest days", 20, "2026-05-27", 6, None, 4, "2026-05-24T08:00:00+00:00"),
                (7605, 7501, "Completed task stays", 20, "2026-05-25", 5, "2026-05-24T09:00:00+00:00", 5, "2026-05-24T08:00:00+00:00"),
                (7606, 7502, "Completed project task stays", 20, "2026-05-25", 4, None, 6, "2026-05-24T08:00:00+00:00"),
                (7607, 7503, "Non-study task stays", 20, "2026-05-25", 3, None, 7, "2026-05-24T08:00:00+00:00"),
            ],
        )
        await db.commit()

    from datetime import date
    from src.db.queries import update_study_rest_day_settings

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        result = await update_study_rest_day_settings(
            db,
            weekly_weekdays=[1],
            one_off_dates=[date(2026, 5, 25)],
            today=date(2026, 5, 24),
        )

    assert result["added_weekly_weekdays"] == [1]
    assert result["added_one_off_dates"] == ["2026-05-25"]

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        tasks = await _fetchall(
            db,
            """
            SELECT
                id,
                scheduled_date,
                auto_roll_days,
                last_auto_rolled_at,
                user_adjusted_at
            FROM tasks
            WHERE id BETWEEN 7601 AND 7607
            ORDER BY id
            """,
        )
        events = await _fetchall(
            db,
            """
            SELECT event_type, payload
            FROM events
            WHERE event_type IN ('study_rest_days_updated', 'study_rest_day_cascaded')
            ORDER BY id
            """,
        )

    assert tasks == [
        {
            "id": 7601,
            "scheduled_date": "2026-05-24",
            "auto_roll_days": 3,
            "last_auto_rolled_at": "2026-05-24T08:00:00+00:00",
            "user_adjusted_at": None,
        },
        {
            "id": 7602,
            "scheduled_date": "2026-05-27",
            "auto_roll_days": 0,
            "last_auto_rolled_at": None,
            "user_adjusted_at": tasks[1]["user_adjusted_at"],
        },
        {
            "id": 7603,
            "scheduled_date": "2026-05-28",
            "auto_roll_days": 0,
            "last_auto_rolled_at": None,
            "user_adjusted_at": tasks[2]["user_adjusted_at"],
        },
        {
            "id": 7604,
            "scheduled_date": "2026-05-29",
            "auto_roll_days": 0,
            "last_auto_rolled_at": None,
            "user_adjusted_at": tasks[3]["user_adjusted_at"],
        },
        {
            "id": 7605,
            "scheduled_date": "2026-05-25",
            "auto_roll_days": 5,
            "last_auto_rolled_at": "2026-05-24T08:00:00+00:00",
            "user_adjusted_at": None,
        },
        {
            "id": 7606,
            "scheduled_date": "2026-05-25",
            "auto_roll_days": 6,
            "last_auto_rolled_at": "2026-05-24T08:00:00+00:00",
            "user_adjusted_at": None,
        },
        {
            "id": 7607,
            "scheduled_date": "2026-05-25",
            "auto_roll_days": 7,
            "last_auto_rolled_at": "2026-05-24T08:00:00+00:00",
            "user_adjusted_at": None,
        },
    ]
    assert all(task["user_adjusted_at"] is not None for task in tasks[1:4])

    assert [event["event_type"] for event in events] == [
        "study_rest_days_updated",
        "study_rest_day_cascaded",
    ]
    cascade_payload = json.loads(events[1]["payload"])
    assert cascade_payload == {
        "source": "manual_rest_day_settings",
        "affected_task_ids": [7602, 7603, 7604],
        "occurrences": [
            {
                "date": "2026-05-25",
                "affected_task_ids": [7602, 7603, 7604],
                "date_delta_days": 1,
            },
            {
                "date": "2026-05-26",
                "affected_task_ids": [7602, 7603, 7604],
                "date_delta_days": 1,
            },
        ],
        "changes": [
            {
                "task_id": 7602,
                "project_id": 7501,
                "original_date": "2026-05-25",
                "new_date": "2026-05-27",
                "date_delta_days": 2,
            },
            {
                "task_id": 7603,
                "project_id": 7501,
                "original_date": "2026-05-26",
                "new_date": "2026-05-28",
                "date_delta_days": 2,
            },
            {
                "task_id": 7604,
                "project_id": 7501,
                "original_date": "2026-05-27",
                "new_date": "2026-05-29",
                "date_delta_days": 2,
            },
        ],
    }


@pytest.mark.asyncio
async def test_adding_weekly_rest_day_cascades_each_future_occurrence_until_plan_horizon(client):
    from datetime import date
    from src.db.queries import update_study_rest_day_settings

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.executemany(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            [
                ("study_rest_weekdays", "[]"),
                ("study_rest_dates", "[]"),
            ],
        )
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                7701,
                "Multi-week Cascade Project",
                "study_project",
                "sequential",
                "https://example.com/multi-week-rest",
                "active",
                3,
                "2026-06-30",
            ),
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, priority)
            VALUES (?, ?, ?, 'time', ?, ?, ?)
            """,
            [
                (7801, 7701, "Before first Tuesday", 20, "2026-05-25", 9),
                (7802, 7701, "After second Tuesday", 20, "2026-06-03", 8),
            ],
        )
        await db.commit()

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        await update_study_rest_day_settings(
            db,
            weekly_weekdays=[1],
            one_off_dates=[],
            today=date(2026, 5, 24),
        )

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        tasks = await _fetchall(db, "SELECT id, scheduled_date FROM tasks WHERE id BETWEEN 7801 AND 7802 ORDER BY id")
        events = await _fetchall(
            db,
            """
            SELECT payload
            FROM events
            WHERE event_type = 'study_rest_day_cascaded'
            ORDER BY id
            """,
        )

    assert tasks == [
        {"id": 7801, "scheduled_date": "2026-05-25"},
        {"id": 7802, "scheduled_date": "2026-06-05"},
    ]
    assert json.loads(events[0]["payload"])["occurrences"] == [
        {
            "date": "2026-05-26",
            "affected_task_ids": [7802],
            "date_delta_days": 1,
        },
        {
            "date": "2026-06-02",
            "affected_task_ids": [7802],
            "date_delta_days": 1,
        },
    ]


@pytest.mark.asyncio
async def test_new_one_off_date_already_covered_by_old_weekly_rest_day_does_not_cascade_again(client):
    from datetime import date
    from src.db.queries import update_study_rest_day_settings

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.executemany(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            [
                ("study_rest_weekdays", "[0]"),
                ("study_rest_dates", "[]"),
            ],
        )
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                7901,
                "Existing Weekly Rest Project",
                "study_project",
                "sequential",
                "https://example.com/existing-weekly-rest",
                "active",
                1,
                "2026-06-30",
            ),
        )
        await db.execute(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, priority)
            VALUES (?, ?, ?, 'time', ?, ?, ?)
            """,
            (8001, 7901, "Already on old Monday rest day", 20, "2026-05-25", 9),
        )
        await db.commit()

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        result = await update_study_rest_day_settings(
            db,
            weekly_weekdays=[0],
            one_off_dates=[date(2026, 5, 25)],
            today=date(2026, 5, 24),
        )

    assert result["added_one_off_dates"] == ["2026-05-25"]

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        tasks = await _fetchall(db, "SELECT id, scheduled_date FROM tasks WHERE id = 8001")
        cascade_events = await _fetchall(db, "SELECT id FROM events WHERE event_type = 'study_rest_day_cascaded'")

    assert tasks == [{"id": 8001, "scheduled_date": "2026-05-25"}]
    assert cascade_events == []


@pytest.mark.asyncio
async def test_adding_rest_day_with_no_affected_tasks_does_not_record_cascade_event(client):
    from datetime import date
    from src.db.queries import update_study_rest_day_settings

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.executemany(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            [
                ("study_rest_weekdays", "[]"),
                ("study_rest_dates", "[]"),
            ],
        )
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                8101,
                "Past-only Project",
                "study_project",
                "sequential",
                "https://example.com/no-affected-rest",
                "active",
                1,
                "2026-06-30",
            ),
        )
        await db.execute(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, priority)
            VALUES (?, ?, ?, 'time', ?, ?, ?)
            """,
            (8201, 8101, "Before new rest day", 20, "2026-05-24", 9),
        )
        await db.commit()

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        await update_study_rest_day_settings(
            db,
            weekly_weekdays=[],
            one_off_dates=[date(2026, 5, 25)],
            today=date(2026, 5, 24),
        )

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        cascade_events = await _fetchall(db, "SELECT id FROM events WHERE event_type = 'study_rest_day_cascaded'")

    assert cascade_events == []
