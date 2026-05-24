import os

import aiosqlite
import pytest


async def _fetchall(db: aiosqlite.Connection, sql: str, params: tuple = ()) -> list[dict]:
    async with db.execute(sql, params) as cur:
        rows = await cur.fetchall()
    return [dict(row) for row in rows]


async def _seed_calendar_facts(db_path: str) -> None:
    async with aiosqlite.connect(db_path) as db:
        await db.execute("INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)", ("daily_capacity_min", "60"))
        await db.executemany(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (2201, "Active Calendar Project", "study_project", "sequential", "https://example.com/active", "active", 4),
                (2202, "Completed Calendar Project", "study_project", "sequential", "https://example.com/completed", "completed", 1),
                (2203, "Archived Calendar Project", "study_project", "sequential", "https://example.com/archived", "archived", 1),
                (2204, "Non Study Calendar Resource", "web", "sequential", "https://example.com/web", "active", 1),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at)
            VALUES (?, ?, ?, 'time', ?, ?, ?, ?)
            """,
            [
                (2301, 2201, "Pending overloaded task", 40, "2026-06-01", 9, None),
                (2302, 2201, "Completed overloaded task", 25, "2026-06-01", 8, "2026-05-23T10:00:00+00:00"),
                (2303, 2201, "Null target task", None, "2026-06-02", 7, None),
                (2304, 2201, "At capacity task", 60, "2026-06-03", 6, None),
                (2305, 2202, "Completed project task", 90, "2026-06-01", 5, None),
                (2306, 2203, "Archived project task", 90, "2026-06-02", 4, None),
                (2307, 2204, "Non study task", 90, "2026-06-03", 3, None),
                (2308, 2201, "Outside window task", 120, "2026-06-04", 2, None),
            ],
        )
        await db.commit()


@pytest.mark.asyncio
async def test_calendar_load_aggregates_active_study_tasks_for_every_day_and_is_read_only(client):
    await _seed_calendar_facts(os.environ["DB_PATH"])

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        before_tasks = await _fetchall(
            db,
            "SELECT id, scheduled_date FROM tasks ORDER BY id",
        )
        before_events = await _fetchall(db, "SELECT id, event_type, payload FROM events ORDER BY id")

    response = await client.get("/api/study-views/calendar?start=2026-06-01&end=2026-06-03")

    assert response.status_code == 200, response.text
    assert response.json() == {
        "start_date": "2026-06-01",
        "end_date": "2026-06-03",
        "daily_capacity_minutes": 60,
        "days": [
            {
                "date": "2026-06-01",
                "scheduled_task_count": 2,
                "total_target_minutes": 65,
                "completed_task_count": 1,
                "rest_day": False,
                "available_capacity_minutes": 0,
                "over_capacity": True,
            },
            {
                "date": "2026-06-02",
                "scheduled_task_count": 1,
                "total_target_minutes": 0,
                "completed_task_count": 0,
                "rest_day": False,
                "available_capacity_minutes": 60,
                "over_capacity": False,
            },
            {
                "date": "2026-06-03",
                "scheduled_task_count": 1,
                "total_target_minutes": 60,
                "completed_task_count": 0,
                "rest_day": False,
                "available_capacity_minutes": 0,
                "over_capacity": False,
            },
        ],
    }

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        after_tasks = await _fetchall(
            db,
            "SELECT id, scheduled_date FROM tasks ORDER BY id",
        )
        after_events = await _fetchall(db, "SELECT id, event_type, payload FROM events ORDER BY id")

    assert after_tasks == before_tasks
    assert after_events == before_events


@pytest.mark.asyncio
async def test_calendar_load_returns_empty_day_buckets_and_falls_back_to_default_capacity(client):
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.execute("UPDATE system_state SET value = ? WHERE key = ?", ("not-an-int", "daily_capacity_min"))
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (2401, "Fallback Capacity Project", "study_project", "sequential", "https://example.com/fallback", "active", 1),
        )
        await db.execute(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, priority)
            VALUES (?, ?, ?, 'time', ?, ?, ?)
            """,
            (2501, 2401, "Over fallback capacity", 61, "2026-07-02", 9),
        )
        await db.commit()

    response = await client.get("/api/study-views/calendar?start=2026-07-01&end=2026-07-03")

    assert response.status_code == 200, response.text
    assert response.json()["daily_capacity_minutes"] == 60
    assert response.json()["days"] == [
        {
            "date": "2026-07-01",
            "scheduled_task_count": 0,
            "total_target_minutes": 0,
            "completed_task_count": 0,
            "rest_day": False,
            "available_capacity_minutes": 60,
            "over_capacity": False,
        },
        {
            "date": "2026-07-02",
            "scheduled_task_count": 1,
            "total_target_minutes": 61,
            "completed_task_count": 0,
            "rest_day": False,
            "available_capacity_minutes": 0,
            "over_capacity": True,
        },
        {
            "date": "2026-07-03",
            "scheduled_task_count": 0,
            "total_target_minutes": 0,
            "completed_task_count": 0,
            "rest_day": False,
            "available_capacity_minutes": 60,
            "over_capacity": False,
        },
    ]


@pytest.mark.asyncio
async def test_calendar_load_recalculates_over_capacity_after_persisted_task_fact_changes_without_moving_tasks(client):
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.execute("INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)", ("daily_capacity_min", "60"))
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                2801,
                "Adjustment Calendar Project",
                "study_project",
                "sequential",
                "https://example.com/adjustment-calendar",
                "active",
                2,
            ),
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, priority)
            VALUES (?, ?, ?, 'time', ?, ?, ?)
            """,
            [
                (2901, 2801, "Already on day", 40, "2026-08-01", 9),
                (2902, 2801, "Moved by adjustment", 25, "2026-08-02", 8),
            ],
        )
        await db.execute("UPDATE tasks SET scheduled_date = ? WHERE id = ?", ("2026-08-01", 2902))
        await db.commit()

        db.row_factory = aiosqlite.Row
        before_tasks = await _fetchall(db, "SELECT id, scheduled_date FROM tasks ORDER BY id")

    response = await client.get("/api/study-views/calendar?start=2026-08-01&end=2026-08-02")

    assert response.status_code == 200, response.text
    assert response.json()["days"] == [
        {
            "date": "2026-08-01",
            "scheduled_task_count": 2,
            "total_target_minutes": 65,
            "completed_task_count": 0,
            "rest_day": True,
            "available_capacity_minutes": 0,
            "over_capacity": True,
        },
        {
            "date": "2026-08-02",
            "scheduled_task_count": 0,
            "total_target_minutes": 0,
            "completed_task_count": 0,
            "rest_day": False,
            "available_capacity_minutes": 60,
            "over_capacity": False,
        },
    ]

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        after_tasks = await _fetchall(db, "SELECT id, scheduled_date FROM tasks ORDER BY id")

    assert after_tasks == before_tasks


@pytest.mark.asyncio
async def test_calendar_load_requires_valid_date_window(client):
    missing_response = await client.get("/api/study-views/calendar?start=2026-06-01")
    invalid_response = await client.get("/api/study-views/calendar?start=not-a-date&end=2026-06-03")

    assert missing_response.status_code == 422
    assert invalid_response.status_code == 422
