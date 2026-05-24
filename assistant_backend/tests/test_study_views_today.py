from datetime import date, timedelta
import os

import aiosqlite
import pytest


async def _seed_today_view_facts(db_path: str) -> int:
    today = date.today()
    tomorrow = today + timedelta(days=1)

    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, estimated_hours)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                101,
                "Deterministic Algorithms",
                "study_project",
                "sequential",
                "https://example.com/algorithms",
                "active",
                3,
                1.5,
            ),
        )
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, estimated_hours)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                102,
                "Completed Course",
                "study_project",
                "sequential",
                "https://example.com/completed",
                "completed",
                1,
                0.5,
            ),
        )
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, estimated_hours)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                103,
                "Archived Course",
                "study_project",
                "sequential",
                "https://example.com/archived",
                "archived",
                1,
                0.5,
            ),
        )
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, estimated_hours)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                104,
                "Legacy Resource",
                "web",
                "sequential",
                "https://example.com/legacy",
                "active",
                1,
                0.5,
            ),
        )
        await db.execute(
            """
            INSERT INTO units
                (id, resource_id, title, order_index, estimated_minutes)
            VALUES (?, ?, ?, ?, ?)
            """,
            (201, 101, "Graph Search", 0, 35),
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, unit_id, resource_id, title, target_minutes, scheduled_date, priority, completed_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (301, 201, 101, "Watch BFS lesson", 35, today.isoformat(), 9, None),
                (302, None, 101, "Tomorrow active task", 20, tomorrow.isoformat(), 8, None),
                (303, None, 102, "Completed project task", 15, today.isoformat(), 7, None),
                (304, None, 103, "Archived project task", 15, today.isoformat(), 6, None),
                (305, None, 104, "Legacy active task", 15, today.isoformat(), 5, None),
            ],
        )
        await db.commit()

    return 301


@pytest.mark.asyncio
async def test_today_study_view_returns_persisted_active_project_tasks_without_morning_agent(
    client,
    monkeypatch,
):
    from src.routers import morning

    async def fail_if_called():
        raise AssertionError("Today study view must not invoke the morning agent")

    monkeypatch.setattr(morning, "run_morning_agent", fail_if_called)
    task_id = await _seed_today_view_facts(os.environ["DB_PATH"])

    response = await client.get("/api/study-views/today")

    assert response.status_code == 200
    payload = response.json()
    assert payload["date"] == date.today().isoformat()
    assert payload["tasks"] == [
        {
            "id": task_id,
            "title": "Watch BFS lesson",
            "target_minutes": 35,
            "completed_at": None,
            "project_id": 101,
            "project_title": "Deterministic Algorithms",
            "resource_id": 101,
            "resource_title": "Deterministic Algorithms",
            "resource_url": "https://example.com/algorithms",
            "unit_id": 201,
            "unit_title": "Graph Search",
            "unit_url": None,
        }
    ]
