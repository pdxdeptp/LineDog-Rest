from datetime import date, timedelta
import inspect
import os

import aiosqlite
import pytest


EMPTY_SMART_BRIEFING_SNAPSHOT = {
    "today": {"tasks": []},
    "projects": {"active_projects": [], "completed_projects": []},
    "calendar": {"days": []},
}


async def _seed_smart_briefing_facts(db_path: str) -> dict[str, str]:
    today = date.today()
    yesterday = today - timedelta(days=1)
    tomorrow = today + timedelta(days=1)
    late_day = today + timedelta(days=2)

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
        await db.executemany(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    6101,
                    "Smart Snapshot Project",
                    "study_project",
                    "sequential",
                    "https://example.com/smart",
                    "active",
                    3,
                    tomorrow.isoformat(),
                ),
                (
                    6102,
                    "Archived Smart Project",
                    "study_project",
                    "sequential",
                    "https://example.com/archived-smart",
                    "archived",
                    1,
                    tomorrow.isoformat(),
                ),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at, auto_roll_days, last_auto_rolled_at)
            VALUES (?, ?, ?, 'time', ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    6201,
                    6101,
                    "Rolled smart task",
                    40,
                    yesterday.isoformat(),
                    10,
                    None,
                    2,
                    None,
                ),
                (6202, 6101, "Today smart task", 25, today.isoformat(), 9, None, 0, None),
                (6203, 6101, "Late unfinished task", 20, late_day.isoformat(), 8, None, 0, None),
                (6204, 6101, "Over capacity task", 45, tomorrow.isoformat(), 7, None, 0, None),
                (6205, 6101, "Also over capacity", 30, tomorrow.isoformat(), 6, None, 0, None),
                (6206, 6102, "Archived ignored", 120, today.isoformat(), 5, None, 0, None),
            ],
        )
        await db.commit()

    return {
        "today": today.isoformat(),
        "tomorrow": tomorrow.isoformat(),
    }


@pytest.mark.asyncio
async def test_smart_morning_briefing_returns_fact_only_snapshot_without_v1_agent(
    client,
    monkeypatch,
):
    from src.routers import morning

    async def fail_if_called():
        raise AssertionError("Smart briefing must not invoke the v1 Morning Agent")

    monkeypatch.setattr(morning, "run_morning_agent", fail_if_called)
    days = await _seed_smart_briefing_facts(os.environ["DB_PATH"])

    response = await client.get("/api/study-smart-mode/morning-briefing")

    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["enabled"] is True
    assert payload["date"] == days["today"]
    assert [option["id"] for option in payload["options"]] == [
        "smart-morning-rolled-task-lag-6201",
        "smart-morning-expected-late-project-6101",
        f"smart-morning-over-capacity-day-{days['today']}",
        f"smart-morning-over-capacity-day-{days['tomorrow']}",
    ]
    assert payload["trigger_eligible"] is True
    assert (
        payload["summary"]
        == "2 tasks today across 1 active project; 1 lagging task; "
        "1 expected-late project; 2 over-capacity days."
    )

    snapshot = payload["snapshot"]
    assert [task["id"] for task in snapshot["today"]["tasks"]] == [6201, 6202]
    rolled_task = snapshot["today"]["tasks"][0]
    assert rolled_task["rolled_day_count"] == 3
    assert rolled_task["show_rolled_badge"] is True
    assert snapshot["rollover"]["rolled_tasks"] == [
        {
            "task_id": 6201,
            "project_id": 6101,
            "old_date": (date.fromisoformat(days["today"]) - timedelta(days=1)).isoformat(),
            "new_date": days["today"],
            "rolled_days": 1,
            "auto_roll_days": 3,
        }
    ]
    assert [project["id"] for project in snapshot["projects"]["active_projects"]] == [6101]
    assert snapshot["projects"]["active_projects"][0]["expected_late"] is True

    calendar_days = snapshot["calendar"]["days"]
    over_capacity_days = [day for day in calendar_days if day["over_capacity"]]
    assert [day["date"] for day in over_capacity_days] == [days["today"], days["tomorrow"]]

    assert payload["issues"] == [
        {"type": "rolled_task_lag", "task_id": 6201, "project_id": 6101, "rolled_day_count": 3},
        {"type": "expected_late_project", "project_id": 6101},
        {"type": "over_capacity_day", "date": days["today"]},
        {"type": "over_capacity_day", "date": days["tomorrow"]},
    ]


@pytest.mark.asyncio
async def test_smart_morning_briefing_stays_quiet_without_issues(client):
    today = date.today()
    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        await db.execute(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            ("study_smart_mode_enabled", "true"),
        )
        await db.execute(
            "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
            ("study_rest_weekdays", "[]"),
        )
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                6301,
                "Quiet Smart Project",
                "study_project",
                "sequential",
                "https://example.com/quiet",
                "active",
                1,
                (today + timedelta(days=10)).isoformat(),
            ),
        )
        await db.execute(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, priority, completed_at, auto_roll_days)
            VALUES (?, ?, ?, 'time', ?, ?, ?, ?, ?)
            """,
            (6302, 6301, "Quiet task", 25, today.isoformat(), 5, None, 0),
        )
        await db.commit()

    response = await client.get("/api/study-smart-mode/morning-briefing")

    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["enabled"] is True
    assert payload["summary"] == (
        "1 task today across 1 active project; 0 lagging tasks; "
        "0 expected-late projects; 0 over-capacity days."
    )
    assert payload["issues"] == []
    assert payload["options"] == []
    assert payload["trigger_eligible"] is False


def test_smart_mode_router_has_no_v1_morning_agent_dependency():
    from src.routers import study_smart_mode

    source = inspect.getsource(study_smart_mode)
    assert "run_morning_agent" not in source
    assert "morning_agent" not in source
    assert "today-briefing" not in source


def test_empty_morning_briefing_uses_fresh_snapshot_objects():
    from src.routers.study_smart_mode import _empty_morning_briefing

    first = _empty_morning_briefing(date.today())
    first["snapshot"]["today"]["tasks"].append({"id": 1})

    second = _empty_morning_briefing(date.today())

    assert second["snapshot"] == EMPTY_SMART_BRIEFING_SNAPSHOT


@pytest.mark.asyncio
async def test_disabled_smart_morning_briefing_fails_closed_without_v1_agent(client, monkeypatch):
    from src.routers import morning

    async def fail_if_called():
        raise AssertionError("Disabled smart briefing must not invoke the v1 Morning Agent")

    monkeypatch.setattr(morning, "run_morning_agent", fail_if_called)

    response = await client.get("/api/study-smart-mode/morning-briefing")

    assert response.status_code == 200
    assert response.json() == {
        "enabled": False,
        "date": date.today().isoformat(),
        "summary": "",
        "snapshot": EMPTY_SMART_BRIEFING_SNAPSHOT,
        "issues": [],
        "options": [],
        "trigger_eligible": False,
    }
