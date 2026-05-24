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


def _expected_calendar_day(
    day: str,
    scheduled_task_count: int,
    total_target_minutes: int,
    completed_task_count: int = 0,
) -> dict:
    rest_day = date.fromisoformat(day).weekday() == 5
    capacity = 0 if rest_day else 60
    return {
        "date": day,
        "scheduled_task_count": scheduled_task_count,
        "total_target_minutes": total_target_minutes,
        "completed_task_count": completed_task_count,
        "rest_day": rest_day,
        "available_capacity_minutes": max(0, capacity - total_target_minutes),
        "over_capacity": total_target_minutes > capacity,
    }


async def _seed_delete_project(db_path: str) -> dict[str, str]:
    today = date.today()
    delete_day = today + timedelta(days=1)
    later_day = today + timedelta(days=3)
    other_day = today + timedelta(days=3)

    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            ("daily_capacity_min", "60"),
        )
        await db.executemany(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, completed_units, actual_minutes_total, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    6101,
                    "Delete Active Project",
                    "study_project",
                    "sequential",
                    "https://example.com/delete",
                    "active",
                    3,
                    1,
                    30,
                    (today + timedelta(days=10)).isoformat(),
                ),
                (
                    6102,
                    "Other Delete Project",
                    "study_project",
                    "sequential",
                    "https://example.com/other-delete",
                    "active",
                    1,
                    0,
                    0,
                    (today + timedelta(days=10)).isoformat(),
                ),
            ],
        )
        await db.executemany(
            """
            INSERT INTO units
                (id, resource_id, title, order_index, estimated_minutes, actual_minutes, status, completed_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (6201, 6101, "Completed unit", 1, 30, 30, "completed", "2026-05-20T10:00:00+00:00"),
                (6202, 6101, "Deleted unit", 2, 35, None, "pending", None),
                (6203, 6101, "Later unit", 3, 45, None, "pending", None),
                (6204, 6102, "Other unit", 1, 25, None, "pending", None),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, unit_id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at, actual_minutes)
            VALUES (?, ?, ?, ?, 'time', ?, ?, ?, ?, ?)
            """,
            [
                (6301, 6201, 6101, "Completed history task", 30, today.isoformat(), 9, "2026-05-20T10:00:00+00:00", 30),
                (6302, 6202, 6101, "Delete this unfinished task", 35, delete_day.isoformat(), 8, None, None),
                (6303, 6203, 6101, "Later same project task", 45, later_day.isoformat(), 7, None, None),
                (6304, 6204, 6102, "Other project task", 25, other_day.isoformat(), 6, None, None),
            ],
        )
        await db.commit()

    return {
        "delete_day": delete_day.isoformat(),
        "later_day": later_day.isoformat(),
        "other_day": other_day.isoformat(),
    }


async def _seed_last_unfinished_project(db_path: str) -> dict[str, str]:
    today = date.today()
    delete_day = today + timedelta(days=2)

    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, completed_units, actual_minutes_total, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                6401,
                "Delete Completes Project",
                "study_project",
                "sequential",
                "https://example.com/delete-completes",
                "active",
                2,
                1,
                40,
                (today + timedelta(days=6)).isoformat(),
            ),
        )
        await db.executemany(
            """
            INSERT INTO units
                (id, resource_id, title, order_index, estimated_minutes, actual_minutes, status, completed_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (6501, 6401, "Already done unit", 1, 40, 40, "completed", "2026-05-20T10:00:00+00:00"),
                (6502, 6401, "Last scheduled unit", 2, 50, None, "pending", None),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, unit_id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at, actual_minutes)
            VALUES (?, ?, ?, ?, 'time', ?, ?, ?, ?, ?)
            """,
            [
                (6601, 6501, 6401, "Already done task", 40, today.isoformat(), 9, "2026-05-20T10:00:00+00:00", 40),
                (6602, 6502, 6401, "Last unfinished task", 50, delete_day.isoformat(), 8, None, None),
            ],
        )
        await db.commit()

    return {"delete_day": delete_day.isoformat()}


async def _seed_taskless_completion_project(db_path: str) -> dict[str, str]:
    today = date.today()
    delete_day = today + timedelta(days=4)

    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, completed_units, actual_minutes_total, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                6901,
                "Delete Leaves No History Project",
                "study_project",
                "sequential",
                "https://example.com/delete-no-history",
                "active",
                1,
                0,
                0,
                (today + timedelta(days=8)).isoformat(),
            ),
        )
        await db.execute(
            """
            INSERT INTO units
                (id, resource_id, title, order_index, estimated_minutes, actual_minutes, status, completed_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (6902, 6901, "Only pending unit", 1, 20, None, "pending", None),
        )
        await db.execute(
            """
            INSERT INTO tasks
                (id, unit_id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at, actual_minutes)
            VALUES (?, ?, ?, ?, 'time', ?, ?, ?, ?, ?)
            """,
            (6903, 6902, 6901, "Only unfinished task", 20, delete_day.isoformat(), 9, None, None),
        )
        await db.commit()

    return {"delete_day": delete_day.isoformat()}


async def _seed_rejection_facts(db_path: str) -> None:
    today = date.today().isoformat()
    async with aiosqlite.connect(db_path) as db:
        await db.executemany(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (6701, "Active Rejection Project", "study_project", "sequential", "https://example.com/active-reject", "active", 1),
                (6702, "Completed Rejection Project", "study_project", "sequential", "https://example.com/completed-reject", "completed", 1),
                (6703, "Non Study Rejection Resource", "web", "sequential", "https://example.com/non-study-reject", "active", 1),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at)
            VALUES (?, ?, ?, 'time', ?, ?, ?, ?)
            """,
            [
                (6801, 6701, "Completed task cannot delete", 25, today, 9, "2026-05-21T10:00:00+00:00"),
                (6802, 6702, "Completed project task cannot delete", 25, today, 8, None),
                (6803, 6703, "Non study task cannot delete", 25, today, 7, None),
            ],
        )
        await db.commit()


@pytest.mark.asyncio
async def test_delete_unfinished_active_study_task_removes_only_that_task_and_recalculates_calendar(client):
    days = await _seed_delete_project(os.environ["DB_PATH"])
    today = date.today().isoformat()
    yesterday = (date.today() - timedelta(days=1)).isoformat()
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.executemany(
            "INSERT INTO system_state (key, value) VALUES (?, ?)",
            [
                (f"briefing_{today}", "stale today briefing"),
                (f"briefing_{yesterday}", "older briefing"),
            ],
        )
        await db.commit()

    response = await client.delete("/api/study-plan-adjustment/tasks/6302")
    calendar_response = await client.get(
        f"/api/study-views/calendar?start={days['delete_day']}&end={days['later_day']}"
    )

    assert response.status_code == 200, response.text
    assert response.json() == {
        "project_id": 6101,
        "task_id": 6302,
        "scheduled_date": days["delete_day"],
        "source": "manual_delete",
        "project_completed": False,
    }
    assert calendar_response.status_code == 200, calendar_response.text
    assert calendar_response.json()["days"] == [
        _expected_calendar_day(days["delete_day"], scheduled_task_count=0, total_target_minutes=0),
        _expected_calendar_day(
            (date.fromisoformat(days["delete_day"]) + timedelta(days=1)).isoformat(),
            scheduled_task_count=0,
            total_target_minutes=0,
        ),
        _expected_calendar_day(days["later_day"], scheduled_task_count=2, total_target_minutes=70),
    ]

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        tasks = await _fetchall(
            db,
            """
            SELECT id, resource_id, title, scheduled_date, completed_at
            FROM tasks
            ORDER BY id
            """,
        )
        events = await _fetchall(
            db,
            "SELECT event_type, payload FROM events WHERE event_type = 'study_task_deleted' ORDER BY id",
        )
        briefing_rows = await _fetchall(
            db,
            "SELECT key, value FROM system_state WHERE key LIKE 'briefing_%' ORDER BY key",
        )

    assert tasks == [
        {
            "id": 6301,
            "resource_id": 6101,
            "title": "Completed history task",
            "scheduled_date": date.today().isoformat(),
            "completed_at": "2026-05-20T10:00:00+00:00",
        },
        {
            "id": 6303,
            "resource_id": 6101,
            "title": "Later same project task",
            "scheduled_date": days["later_day"],
            "completed_at": None,
        },
        {
            "id": 6304,
            "resource_id": 6102,
            "title": "Other project task",
            "scheduled_date": days["other_day"],
            "completed_at": None,
        },
    ]
    assert len(events) == 1
    assert json.loads(events[0]["payload"]) == {
        "project_id": 6101,
        "task_id": 6302,
        "scheduled_date": days["delete_day"],
        "target_minutes": 35,
        "title": "Delete this unfinished task",
        "source": "manual_delete",
        "project_completed": False,
    }
    assert briefing_rows == [{"key": f"briefing_{yesterday}", "value": "older briefing"}]


@pytest.mark.asyncio
async def test_delete_last_unfinished_task_completes_project_and_preserves_completed_history(client):
    days = await _seed_last_unfinished_project(os.environ["DB_PATH"])

    response = await client.delete("/api/study-plan-adjustment/tasks/6602")
    overview_response = await client.get("/api/study-views/projects")

    assert response.status_code == 200, response.text
    assert response.json() == {
        "project_id": 6401,
        "task_id": 6602,
        "scheduled_date": days["delete_day"],
        "source": "manual_delete",
        "project_completed": True,
    }
    assert overview_response.status_code == 200, overview_response.text
    assert overview_response.json()["active_projects"] == []
    assert overview_response.json()["completed_projects"] == [
        {
            "id": 6401,
            "title": "Delete Completes Project",
            "completed_units": 1,
            "total_units": 1,
            "progress_ratio": 1.0,
            "target_minutes": 40,
            "actual_minutes": 40,
            "deadline": (date.today() + timedelta(days=6)).isoformat(),
            "expected_late": False,
            "status": "completed",
        }
    ]

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        resource = await _fetchone(
            db,
            """
            SELECT id, status, total_units, completed_units, actual_minutes_total
            FROM resources
            WHERE id = 6401
            """,
        )
        units = await _fetchall(db, "SELECT id, resource_id, status, completed_at FROM units ORDER BY id")
        tasks = await _fetchall(
            db,
            "SELECT id, resource_id, title, completed_at, actual_minutes FROM tasks ORDER BY id",
        )
        events = await _fetchall(
            db,
            "SELECT event_type, payload FROM events ORDER BY id",
        )

    assert resource == {
        "id": 6401,
        "status": "completed",
        "total_units": 1,
        "completed_units": 1,
        "actual_minutes_total": 40,
    }
    assert units == [
        {"id": 6501, "resource_id": 6401, "status": "completed", "completed_at": "2026-05-20T10:00:00+00:00"},
    ]
    assert tasks == [
        {
            "id": 6601,
            "resource_id": 6401,
            "title": "Already done task",
            "completed_at": "2026-05-20T10:00:00+00:00",
            "actual_minutes": 40,
        }
    ]
    assert [event["event_type"] for event in events] == ["study_task_deleted", "resource_completed"]
    assert json.loads(events[0]["payload"])["project_completed"] is True
    assert json.loads(events[1]["payload"]) == {"resource_id": 6401, "source": "manual_delete"}


@pytest.mark.asyncio
async def test_delete_only_task_completes_project_without_stale_total_units_or_pending_unit(client):
    days = await _seed_taskless_completion_project(os.environ["DB_PATH"])

    response = await client.delete("/api/study-plan-adjustment/tasks/6903")
    overview_response = await client.get("/api/study-views/projects")

    assert response.status_code == 200, response.text
    assert response.json() == {
        "project_id": 6901,
        "task_id": 6903,
        "scheduled_date": days["delete_day"],
        "source": "manual_delete",
        "project_completed": True,
    }
    assert overview_response.status_code == 200, overview_response.text
    assert overview_response.json()["active_projects"] == []
    assert overview_response.json()["completed_projects"] == [
        {
            "id": 6901,
            "title": "Delete Leaves No History Project",
            "completed_units": 0,
            "total_units": 0,
            "progress_ratio": 0.0,
            "target_minutes": 0,
            "actual_minutes": 0,
            "deadline": (date.today() + timedelta(days=8)).isoformat(),
            "expected_late": False,
            "status": "completed",
        }
    ]

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        resource = await _fetchone(
            db,
            """
            SELECT id, status, total_units, completed_units
            FROM resources
            WHERE id = 6901
            """,
        )
        units = await _fetchall(db, "SELECT id FROM units WHERE resource_id = 6901")
        tasks = await _fetchall(db, "SELECT id FROM tasks WHERE resource_id = 6901")

    assert resource == {"id": 6901, "status": "completed", "total_units": 0, "completed_units": 0}
    assert units == []
    assert tasks == []


@pytest.mark.asyncio
async def test_delete_rejects_completed_project_non_study_completed_task_and_missing_task_without_mutation(client):
    await _seed_rejection_facts(os.environ["DB_PATH"])

    completed_task_response = await client.delete("/api/study-plan-adjustment/tasks/6801")
    completed_project_response = await client.delete("/api/study-plan-adjustment/tasks/6802")
    non_study_response = await client.delete("/api/study-plan-adjustment/tasks/6803")
    missing_response = await client.delete("/api/study-plan-adjustment/tasks/999999")

    assert completed_task_response.status_code == 409, completed_task_response.text
    assert completed_project_response.status_code == 409, completed_project_response.text
    assert non_study_response.status_code == 409, non_study_response.text
    assert missing_response.status_code == 404, missing_response.text

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        tasks = await _fetchall(
            db,
            "SELECT id, resource_id, title, completed_at FROM tasks ORDER BY id",
        )
        resources = await _fetchall(db, "SELECT id, status FROM resources ORDER BY id")
        events = await _fetchall(db, "SELECT id FROM events")

    assert tasks == [
        {
            "id": 6801,
            "resource_id": 6701,
            "title": "Completed task cannot delete",
            "completed_at": "2026-05-21T10:00:00+00:00",
        },
        {
            "id": 6802,
            "resource_id": 6702,
            "title": "Completed project task cannot delete",
            "completed_at": None,
        },
        {
            "id": 6803,
            "resource_id": 6703,
            "title": "Non study task cannot delete",
            "completed_at": None,
        },
    ]
    assert resources == [
        {"id": 6701, "status": "active"},
        {"id": 6702, "status": "completed"},
        {"id": 6703, "status": "active"},
    ]
    assert events == []
