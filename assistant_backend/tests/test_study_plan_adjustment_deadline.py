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


async def _seed_deadline_edit_project(db_path: str) -> dict[str, str]:
    today = date.today()
    on_time_deadline = today + timedelta(days=10)
    early_deadline = today + timedelta(days=3)
    later_deadline = today + timedelta(days=14)
    task_one_day = today + timedelta(days=1)
    task_two_day = today + timedelta(days=7)

    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                4501,
                "Deadline Edit Active Project",
                "study_project",
                "sequential",
                "https://example.com/deadline-edit",
                "active",
                2,
                on_time_deadline.isoformat(),
            ),
        )
        await db.executemany(
            """
            INSERT INTO units
                (id, resource_id, title, order_index, estimated_minutes, status)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [
                (4502, 4501, "Near unit", 1, 30, "pending"),
                (4503, 4501, "Late unit", 2, 30, "pending"),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, unit_id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at)
            VALUES (?, ?, ?, ?, 'time', ?, ?, ?, ?)
            """,
            [
                (4504, 4502, 4501, "Near task", 30, task_one_day.isoformat(), 8, None),
                (4505, 4503, 4501, "Later task", 30, task_two_day.isoformat(), 7, None),
            ],
        )
        await db.commit()

    return {
        "on_time_deadline": on_time_deadline.isoformat(),
        "early_deadline": early_deadline.isoformat(),
        "later_deadline": later_deadline.isoformat(),
        "task_one_day": task_one_day.isoformat(),
        "task_two_day": task_two_day.isoformat(),
    }


@pytest.mark.asyncio
async def test_deadline_edit_recalculates_expected_late_without_moving_tasks(client):
    days = await _seed_deadline_edit_project(os.environ["DB_PATH"])

    early_response = await client.post(
        "/api/study-plan-adjustment/projects/4501/deadline",
        json={"deadline": days["early_deadline"]},
    )
    early_overview = await client.get("/api/study-views/projects")

    assert early_response.status_code == 200, early_response.text
    assert early_response.json() == {
        "project_id": 4501,
        "old_deadline": days["on_time_deadline"],
        "new_deadline": days["early_deadline"],
        "source": "deadline_edit",
    }
    assert early_overview.status_code == 200, early_overview.text
    assert early_overview.json()["active_projects"][0]["expected_late"] is True

    later_response = await client.post(
        "/api/study-plan-adjustment/projects/4501/deadline",
        json={"deadline": days["later_deadline"]},
    )
    later_overview = await client.get("/api/study-views/projects")

    assert later_response.status_code == 200, later_response.text
    assert later_response.json() == {
        "project_id": 4501,
        "old_deadline": days["early_deadline"],
        "new_deadline": days["later_deadline"],
        "source": "deadline_edit",
    }
    assert later_overview.status_code == 200, later_overview.text
    assert later_overview.json()["active_projects"][0]["expected_late"] is False

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        resource = await _fetchone(db, "SELECT deadline FROM resources WHERE id = 4501")
        tasks = await _fetchall(
            db,
            "SELECT id, scheduled_date FROM tasks WHERE resource_id = 4501 ORDER BY id",
        )
        events = await _fetchall(
            db,
            """
            SELECT event_type, payload
            FROM events
            WHERE event_type = 'study_project_deadline_updated'
            ORDER BY id
            """,
        )

    assert resource == {"deadline": days["later_deadline"]}
    assert tasks == [
        {"id": 4504, "scheduled_date": days["task_one_day"]},
        {"id": 4505, "scheduled_date": days["task_two_day"]},
    ]
    assert [json.loads(event["payload"]) for event in events] == [
        {
            "project_id": 4501,
            "old_deadline": days["on_time_deadline"],
            "new_deadline": days["early_deadline"],
            "source": "deadline_edit",
        },
        {
            "project_id": 4501,
            "old_deadline": days["early_deadline"],
            "new_deadline": days["later_deadline"],
            "source": "deadline_edit",
        },
    ]


@pytest.mark.asyncio
@pytest.mark.parametrize("payload", [{}, {"deadline": None}, {"deadline": ""}])
async def test_deadline_edit_rejects_missing_or_empty_deadline_without_mutation_or_event(client, payload):
    days = await _seed_deadline_edit_project(os.environ["DB_PATH"])

    response = await client.post(
        "/api/study-plan-adjustment/projects/4501/deadline",
        json=payload,
    )

    assert response.status_code == 422, response.text
    assert (
        "v2 active plans require deadlines for late-state detection"
        in json.dumps(response.json()["detail"]).lower()
    )
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        resource = await _fetchone(db, "SELECT deadline FROM resources WHERE id = 4501")
        events = await _fetchall(
            db,
            "SELECT id FROM events WHERE event_type = 'study_project_deadline_updated'",
        )

    assert resource == {"deadline": days["on_time_deadline"]}
    assert events == []


@pytest.mark.asyncio
async def test_deadline_edit_rejects_completed_or_non_study_projects_without_mutation_or_event(client):
    new_deadline = (date.today() + timedelta(days=20)).isoformat()
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.executemany(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    4601,
                    "Completed Study Project",
                    "study_project",
                    "sequential",
                    "https://example.com/completed",
                    "completed",
                    1,
                    "2026-06-01",
                ),
                (
                    4602,
                    "Active Non Study Resource",
                    "web",
                    "sequential",
                    "https://example.com/web",
                    "active",
                    1,
                    "2026-06-02",
                ),
            ],
        )
        await db.commit()

    completed_response = await client.post(
        "/api/study-plan-adjustment/projects/4601/deadline",
        json={"deadline": new_deadline},
    )
    non_study_response = await client.post(
        "/api/study-plan-adjustment/projects/4602/deadline",
        json={"deadline": new_deadline},
    )

    assert completed_response.status_code == 409, completed_response.text
    assert non_study_response.status_code == 409, non_study_response.text
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        resources = await _fetchall(
            db,
            "SELECT id, deadline FROM resources WHERE id IN (4601, 4602) ORDER BY id",
        )
        events = await _fetchall(
            db,
            "SELECT id FROM events WHERE event_type = 'study_project_deadline_updated'",
        )

    assert resources == [
        {"id": 4601, "deadline": "2026-06-01"},
        {"id": 4602, "deadline": "2026-06-02"},
    ]
    assert events == []
