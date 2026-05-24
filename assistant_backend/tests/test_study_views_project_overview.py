import os
from datetime import date

import aiosqlite
import pytest


async def _seed_project_overview_facts(db_path: str) -> tuple[int, int]:
    today = date.today().isoformat()
    async with aiosqlite.connect(db_path) as db:
        await db.executemany(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, completed_units, actual_minutes_total, estimated_hours, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    1101,
                    "Active Study Project",
                    "study_project",
                    "sequential",
                    "https://example.com/active",
                    "active",
                    2,
                    0,
                    999,
                    1.5,
                    "2026-06-10",
                ),
                (
                    1102,
                    "Completed Study Project",
                    "study_project",
                    "sequential",
                    "https://example.com/completed",
                    "completed",
                    1,
                    1,
                    45,
                    0.75,
                    "2026-05-30",
                ),
                (
                    1103,
                    "Archived Study Project",
                    "study_project",
                    "sequential",
                    "https://example.com/archived",
                    "archived",
                    1,
                    0,
                    0,
                    0.5,
                    "2026-05-31",
                ),
                (
                    1104,
                    "Active Non Study Resource",
                    "web",
                    "sequential",
                    "https://example.com/web",
                    "active",
                    1,
                    0,
                    0,
                    0.5,
                    "2026-06-01",
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
                (1201, 1101, "Done Unit", 0, 30, 40, "completed", "2026-05-22T10:00:00+00:00"),
                (1202, 1101, "Pending Unit", 1, 60, None, "pending", None),
                (1203, 1102, "Completed History Unit", 0, 45, 45, "completed", "2026-05-20T10:00:00+00:00"),
                (1204, 1103, "Archived Unit", 0, 25, None, "pending", None),
                (1205, 1104, "Non Study Unit", 0, 25, None, "pending", None),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, unit_id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at, actual_minutes)
            VALUES (?, ?, ?, ?, 'time', ?, ?, ?, ?, ?)
            """,
            [
                (1301, 1201, 1101, "Finished active task", 30, today, 9, "2026-05-22T10:00:00+00:00", 40),
                (1302, 1202, 1101, "Pending active task", 60, today, 8, None, None),
                (1303, 1203, 1102, "Finished completed task", 45, today, 7, "2026-05-20T10:00:00+00:00", 45),
                (1304, 1204, 1103, "Archived task", 25, today, 6, None, None),
                (1305, 1205, 1104, "Non study task", 25, today, 5, None, None),
            ],
        )
        await db.commit()

    return 1302, 1101


async def _seed_three_task_active_project(db_path: str) -> tuple[int, int]:
    today = date.today().isoformat()
    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, completed_units, actual_minutes_total, estimated_hours, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                1401,
                "Three Task Active Project",
                "study_project",
                "sequential",
                "https://example.com/three-task",
                "active",
                3,
                1,
                30,
                2.0,
                "2026-06-15",
            ),
        )
        await db.executemany(
            """
            INSERT INTO units
                (id, resource_id, title, order_index, estimated_minutes, actual_minutes, status, completed_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (1501, 1401, "Done Unit", 0, 30, 30, "completed", "2026-05-22T10:00:00+00:00"),
                (1502, 1401, "Pending Unit 1", 1, 45, None, "pending", None),
                (1503, 1401, "Pending Unit 2", 2, 60, None, "pending", None),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, unit_id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at, actual_minutes)
            VALUES (?, ?, ?, ?, 'time', ?, ?, ?, ?, ?)
            """,
            [
                (1601, 1501, 1401, "Finished first task", 30, today, 9, "2026-05-22T10:00:00+00:00", 30),
                (1602, 1502, 1401, "Pending middle task", 45, today, 8, None, None),
                (1603, 1503, 1401, "Pending final task", 60, today, 7, None, None),
            ],
        )
        await db.commit()

    return 1602, 1401


@pytest.mark.asyncio
async def test_project_overview_returns_active_study_projects_and_completed_history_only(client):
    await _seed_project_overview_facts(os.environ["DB_PATH"])

    response = await client.get("/api/study-views/projects")

    assert response.status_code == 200, response.text
    assert response.json() == {
        "active_projects": [
            {
                "id": 1101,
                "title": "Active Study Project",
                "completed_units": 1,
                "total_units": 2,
                "progress_ratio": 0.5,
                "target_minutes": 90,
                "actual_minutes": 40,
                "deadline": "2026-06-10",
                "expected_late": False,
                "status": "active",
            }
        ],
        "completed_projects": [
            {
                "id": 1102,
                "title": "Completed Study Project",
                "completed_units": 1,
                "total_units": 1,
                "progress_ratio": 1.0,
                "target_minutes": 45,
                "actual_minutes": 45,
                "deadline": "2026-05-30",
                "expected_late": False,
                "status": "completed",
            }
        ],
    }


@pytest.mark.asyncio
async def test_project_overview_recalculates_progress_from_unit_and_task_facts(client):
    await _seed_project_overview_facts(os.environ["DB_PATH"])

    response = await client.get("/api/study-views/projects")

    assert response.status_code == 200, response.text
    active_project = response.json()["active_projects"][0]
    assert active_project["completed_units"] == 1
    assert active_project["total_units"] == 2
    assert active_project["progress_ratio"] == 0.5
    assert active_project["actual_minutes"] == 40


@pytest.mark.asyncio
async def test_project_overview_reflects_task_completion_without_stale_cache(client):
    pending_task_id, project_id = await _seed_three_task_active_project(os.environ["DB_PATH"])

    complete_response = await client.post(
        f"/api/tasks/{pending_task_id}/complete",
        json={"actual_minutes": 55},
    )
    overview_response = await client.get("/api/study-views/projects")

    assert complete_response.status_code == 200, complete_response.text
    assert overview_response.status_code == 200, overview_response.text
    active_project = overview_response.json()["active_projects"][0]
    assert active_project["id"] == project_id
    assert active_project["completed_units"] == 2
    assert active_project["total_units"] == 3
    assert active_project["progress_ratio"] == 0.67
    assert active_project["actual_minutes"] == 85


@pytest.mark.asyncio
async def test_project_overview_counts_tasks_when_multiple_tasks_share_one_unit(client):
    today = date.today().isoformat()
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, completed_units, actual_minutes_total, estimated_hours, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                1701,
                "Shared Unit Project",
                "study_project",
                "sequential",
                "https://example.com/shared-unit",
                "active",
                1,
                1,
                20,
                1.0,
                "2026-06-20",
            ),
        )
        await db.execute(
            """
            INSERT INTO units
                (id, resource_id, title, order_index, estimated_minutes, actual_minutes, status, completed_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (1801, 1701, "Shared Unit", 0, 60, 20, "completed", "2026-05-22T10:00:00+00:00"),
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, unit_id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at, actual_minutes)
            VALUES (?, ?, ?, ?, 'time', ?, ?, ?, ?, ?)
            """,
            [
                (1901, 1801, 1701, "Completed shared unit task", 20, today, 9, "2026-05-22T10:00:00+00:00", 20),
                (1902, 1801, 1701, "Pending shared unit task", 40, today, 8, None, None),
            ],
        )
        await db.commit()

    response = await client.get("/api/study-views/projects")

    assert response.status_code == 200, response.text
    active_project = response.json()["active_projects"][0]
    assert active_project["id"] == 1701
    assert active_project["completed_units"] == 1
    assert active_project["total_units"] == 2
    assert active_project["progress_ratio"] == 0.5


@pytest.mark.asyncio
async def test_project_overview_reports_zero_progress_when_active_project_has_no_tasks(client):
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, completed_units, actual_minutes_total, estimated_hours, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                1951,
                "Taskless Active Project",
                "study_project",
                "sequential",
                "https://example.com/taskless",
                "active",
                5,
                3,
                90,
                2.0,
                "2026-06-22",
            ),
        )
        await db.commit()

    response = await client.get("/api/study-views/projects")

    assert response.status_code == 200, response.text
    active_project = response.json()["active_projects"][0]
    assert active_project["id"] == 1951
    assert active_project["completed_units"] == 0
    assert active_project["total_units"] == 0
    assert active_project["progress_ratio"] == 0.0
    assert active_project["target_minutes"] == 0
    assert active_project["actual_minutes"] == 0


@pytest.mark.asyncio
async def test_project_overview_uses_target_fallback_for_auto_completed_task_without_actual_minutes(client):
    today = date.today().isoformat()
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, completed_units, actual_minutes_total, estimated_hours, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                2001,
                "No Unit Project",
                "study_project",
                "sequential",
                "https://example.com/no-unit",
                "active",
                1,
                0,
                0,
                1.0,
                "2026-06-25",
            ),
        )
        await db.execute(
            """
            INSERT INTO tasks
                (id, unit_id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at, actual_minutes)
            VALUES (?, ?, ?, ?, 'time', ?, ?, ?, ?, ?)
            """,
            (2101, None, 2001, "No unit task", 35, today, 9, None, None),
        )
        await db.commit()

    complete_response = await client.post(f"/api/tasks/2101/complete", json={})
    overview_response = await client.get("/api/study-views/projects")

    assert complete_response.status_code == 200, complete_response.text
    assert overview_response.status_code == 200, overview_response.text
    payload = overview_response.json()
    assert payload["active_projects"] == []
    completed_project = payload["completed_projects"][0]
    assert completed_project["id"] == 2001
    assert completed_project["completed_units"] == 1
    assert completed_project["total_units"] == 1
    assert completed_project["actual_minutes"] == 35

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        async with db.execute("SELECT actual_minutes FROM tasks WHERE id = 2101") as cursor:
            task = await cursor.fetchone()

    assert task[0] == 35


@pytest.mark.asyncio
async def test_project_overview_marks_active_project_expected_late_from_unfinished_task_facts(client):
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.executemany(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    2601,
                    "Late Active Study Project",
                    "study_project",
                    "sequential",
                    "https://example.com/late",
                    "active",
                    2,
                    "2026-06-10",
                ),
                (
                    2602,
                    "Completed Late History Project",
                    "study_project",
                    "sequential",
                    "https://example.com/completed-late",
                    "completed",
                    1,
                    "2026-06-10",
                ),
                (
                    2603,
                    "Non Study Late Resource",
                    "web",
                    "sequential",
                    "https://example.com/non-study-late",
                    "active",
                    1,
                    "2026-06-10",
                ),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at)
            VALUES (?, ?, ?, 'time', ?, ?, ?, ?)
            """,
            [
                (2701, 2601, "Finished after deadline", 30, "2026-06-12", 9, "2026-06-12T10:00:00+00:00"),
                (2702, 2601, "Unfinished after deadline", 30, "2026-06-13", 8, None),
                (2703, 2602, "Completed project late task", 30, "2026-06-13", 7, None),
                (2704, 2603, "Non study late task", 30, "2026-06-13", 6, None),
            ],
        )
        await db.commit()

        async with db.execute("SELECT id, scheduled_date FROM tasks ORDER BY id") as cursor:
            before_tasks = await cursor.fetchall()

    response = await client.get("/api/study-views/projects")

    assert response.status_code == 200, response.text
    active_project = response.json()["active_projects"][0]
    completed_project = response.json()["completed_projects"][0]
    assert active_project["id"] == 2601
    assert active_project["expected_late"] is True
    assert completed_project["id"] == 2602
    assert completed_project["expected_late"] is False

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        async with db.execute("SELECT id, scheduled_date FROM tasks ORDER BY id") as cursor:
            after_tasks = await cursor.fetchall()

    assert after_tasks == before_tasks
