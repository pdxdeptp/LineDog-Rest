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


async def _fetchone(db: aiosqlite.Connection, sql: str, params: tuple = ()) -> dict | None:
    async with db.execute(sql, params) as cur:
        row = await cur.fetchone()
    return dict(row) if row else None


async def _seed_today_rollover_badge_facts(db_path: str) -> dict[str, str]:
    today = date.today()
    old_day = today - timedelta(days=3)
    tomorrow = today + timedelta(days=1)

    async with aiosqlite.connect(db_path) as db:
        await db.executemany(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (3501, "Today Rollover Badge", "study_project", "sequential", "https://example.com/badge", "active", 2),
                (3502, "Archived Badge Project", "study_project", "sequential", "https://example.com/archived-badge", "archived", 1),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at, auto_roll_days, last_auto_rolled_at)
            VALUES (?, ?, ?, 'time', ?, ?, ?, ?, ?, ?)
            """,
            [
                (3601, 3501, "Overdue badge task", 45, old_day.isoformat(), 9, None, 0, None),
                (3602, 3501, "Future same project task", 30, tomorrow.isoformat(), 8, None, 0, None),
                (3603, 3502, "Archived overdue task", 20, old_day.isoformat(), 7, None, 0, None),
            ],
        )
        await db.commit()

    return {
        "today": today.isoformat(),
        "old_day": old_day.isoformat(),
        "tomorrow": tomorrow.isoformat(),
    }


async def _seed_today_under_threshold_badge_facts(db_path: str) -> None:
    today = date.today().isoformat()

    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (3701, "Today Under Threshold", "study_project", "sequential", "https://example.com/under", "active", 1),
        )
        await db.execute(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at, auto_roll_days, last_auto_rolled_at)
            VALUES (?, ?, ?, 'time', ?, ?, ?, ?, ?, ?)
            """,
            (3801, 3701, "Already rolled twice", 30, today, 9, None, 2, today),
        )
        await db.commit()


async def _activate_package_draft_for_today(db_path: str) -> int:
    from src.study_plan import lifecycle

    today = date.today().isoformat()
    async with aiosqlite.connect(db_path) as db:
        db.row_factory = aiosqlite.Row
        cursor = await db.execute(
            """
            INSERT INTO study_intake_items
                (client_request_id, raw_input, source_type, recommended_role, confidence)
            VALUES ('req-today-package-activation', 'learn today activation',
                    'text_goal', 'new_plan', 'high')
            """
        )
        await db.commit()
        shell = await lifecycle.create_or_load_draft_shell(
            db,
            intake_item_id=int(cursor.lastrowid),
            title="Today Package Activation",
            source_url="https://example.com/today-package",
            deadline=today,
            capacity_minutes=45,
            assumptions={"deadline": {"value": today, "accepted": True}},
        )
        await lifecycle.save_draft_compiler_package_shell(
            db,
            draft_id=shell["id"],
            status="compiling",
            summary="Ready for compiler",
            assumptions={"deadline": {"value": today, "accepted": True}},
        )
        await lifecycle.save_draft_compiler_package_shell(
            db,
            draft_id=shell["id"],
            status="draft_review",
            summary="Ready for today",
            assumptions={"deadline": {"value": today, "accepted": True}},
            phases=[{"phase_id": "today-phase", "title": "Today Phase"}],
            tasks=[
                {
                    "stable_task_id": "today-task",
                    "phase_id": "today-phase",
                    "title": "Do persisted activation work",
                    "estimate_minutes": 45,
                    "schedule_slices": [
                        {
                            "schedule_slice_id": "today-slice",
                            "scheduled_date": today,
                            "target_minutes": 45,
                        }
                    ],
                }
            ],
            activation_eligibility={
                "activation_ready": True,
                "schedule_version": "today-schedule-v1",
            },
        )
        activated = await lifecycle.confirm_draft_study_project(db, shell["id"])
        return int(activated["resource_id"])


async def _make_add_initiate_draft_for_today(db_path: str) -> dict:
    from src.study_plan.add_initiate import (
        confirm_add_initiate_anchors,
        confirm_add_initiate_role,
        start_add_initiate_session,
    )

    today = date.today().isoformat()
    async with aiosqlite.connect(db_path) as db:
        db.row_factory = aiosqlite.Row
        started = await start_add_initiate_session(
            db,
            client_request_id="req-today-add-initiate-draft",
            raw_input="Learn Today Draft Silence by tomorrow.",
            source_type="text_goal",
        )
        role = await confirm_add_initiate_role(
            db,
            session_id=started["sessionId"],
            intake_item_id=started["intakeItemId"],
            confirmed_role="new_plan",
            title="Today Add Initiate Draft",
            metadata={"deadline": today, "capacity_minutes": 45},
        )
        review = await confirm_add_initiate_anchors(
            db,
            session_id=started["sessionId"],
            draft_id=role["draftId"],
            deadline=today,
            deadline_type="hard",
            capacity_minutes=45,
            target_output="quiet draft notes",
            target_depth="apply",
            assumptions={"deadline": {"accepted": True}},
            compiler=lambda anchor_request: {
                "schema_version": 1,
                "status": "draft_review",
                "summary": "Quiet draft",
                "assumptions": anchor_request["assumptions"],
                "tasks": [
                    {
                        "id": "quiet-today-task",
                        "title": "Quiet draft task",
                        "estimated_minutes": 45,
                        "schedule_slices": [{"date": today, "target_minutes": 45}],
                    }
                ],
            },
            scheduler=lambda package, **kwargs: {
                **package,
                "status": "draft_review",
                "activation_eligibility": {
                    "activation_ready": True,
                    "schedule_version": "quiet-today-v1",
                },
            },
        )

        return {
            "today": today,
            "session_id": started["sessionId"],
            "draft_id": role["draftId"],
            "draft_version": review["draftVersion"],
        }


async def _activate_add_initiate_draft_for_today(db_path: str, draft: dict) -> dict:
    from src.study_plan.add_initiate import activate_add_initiate_draft

    async with aiosqlite.connect(db_path) as db:
        db.row_factory = aiosqlite.Row
        return await activate_add_initiate_draft(
            db,
            session_id=draft["session_id"],
            draft_id=draft["draft_id"],
            draft_version=draft["draft_version"],
        )


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
            "rolled_day_count": 0,
            "show_rolled_badge": False,
        }
    ]


@pytest.mark.asyncio
async def test_today_study_view_reads_tasks_created_from_persisted_package_activation(client):
    resource_id = await _activate_package_draft_for_today(os.environ["DB_PATH"])

    response = await client.get("/api/study-views/today")

    assert response.status_code == 200
    payload = response.json()
    assert payload["tasks"] == [
        {
            "id": 1,
            "title": "Do persisted activation work",
            "target_minutes": 45,
            "completed_at": None,
            "project_id": resource_id,
            "project_title": "Today Package Activation",
            "resource_id": resource_id,
            "resource_title": "Today Package Activation",
            "resource_url": "https://example.com/today-package",
            "unit_id": 1,
            "unit_title": "Do persisted activation work",
            "unit_url": None,
            "rolled_day_count": 0,
            "show_rolled_badge": False,
        }
    ]


@pytest.mark.asyncio
async def test_today_study_view_excludes_add_initiate_draft_until_activation(client):
    draft = await _make_add_initiate_draft_for_today(os.environ["DB_PATH"])

    draft_response = await client.get("/api/study-views/today")

    assert draft_response.status_code == 200, draft_response.text
    assert draft_response.json() == {
        "date": draft["today"],
        "tasks": [],
    }

    activation = await _activate_add_initiate_draft_for_today(os.environ["DB_PATH"], draft)
    active_response = await client.get("/api/study-views/today")

    assert activation["createsActiveTasks"] is True
    assert active_response.status_code == 200, active_response.text
    assert [task["title"] for task in active_response.json()["tasks"]] == ["Quiet draft task"]


@pytest.mark.asyncio
async def test_today_study_view_rolls_over_overdue_tasks_and_exposes_threshold_badge(client):
    days = await _seed_today_rollover_badge_facts(os.environ["DB_PATH"])

    response = await client.get("/api/study-views/today")

    assert response.status_code == 200, response.text
    payload = response.json()
    tasks_by_id = {task["id"]: task for task in payload["tasks"]}
    assert tasks_by_id[3601]["rolled_day_count"] == 3
    assert tasks_by_id[3601]["show_rolled_badge"] is True
    assert 3602 not in tasks_by_id

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        db.row_factory = aiosqlite.Row
        rolled_task = await _fetchone(
            db,
            """
            SELECT scheduled_date, auto_roll_days, last_auto_rolled_at
            FROM tasks
            WHERE id = 3601
            """,
        )
        future_task = await _fetchone(
            db,
            "SELECT scheduled_date, auto_roll_days, last_auto_rolled_at FROM tasks WHERE id = 3602",
        )

    assert rolled_task == {
        "scheduled_date": days["today"],
        "auto_roll_days": 3,
        "last_auto_rolled_at": days["today"],
    }
    assert future_task == {
        "scheduled_date": days["tomorrow"],
        "auto_roll_days": 0,
        "last_auto_rolled_at": None,
    }


@pytest.mark.asyncio
async def test_today_study_view_exposes_rolled_count_without_badge_below_threshold(client):
    await _seed_today_under_threshold_badge_facts(os.environ["DB_PATH"])

    response = await client.get("/api/study-views/today")

    assert response.status_code == 200, response.text
    task = response.json()["tasks"][0]
    assert task["id"] == 3801
    assert task["rolled_day_count"] == 2
    assert task["show_rolled_badge"] is False
