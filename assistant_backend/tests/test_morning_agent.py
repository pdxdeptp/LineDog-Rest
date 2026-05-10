from contextlib import asynccontextmanager
from datetime import date
from types import SimpleNamespace

import pytest


@pytest.mark.asyncio
async def test_today_briefing_tasks_include_link_contract(db, monkeypatch):
    from src.agents import morning_agent

    today = date.today().isoformat()

    await db.execute(
        "INSERT INTO resources (id, title, type, tracking_mode, url, total_units, estimated_hours) "
        "VALUES (?, ?, ?, ?, ?, ?, ?)",
        (1, "Linked Course", "web", "sequential", "https://example.com/course", 1, 1.0),
    )
    await db.execute(
        "INSERT INTO resources (id, title, type, tracking_mode, url, total_units, estimated_hours) "
        "VALUES (?, ?, ?, ?, ?, ?, ?)",
        (2, "Offline Notes", "pdf", "sequential", None, 1, 1.0),
    )
    await db.execute(
        "INSERT INTO units (id, resource_id, title, order_index, estimated_minutes) VALUES (?, ?, ?, ?, ?)",
        (1, 1, "Lesson 1", 0, 25),
    )
    await db.executemany(
        "INSERT INTO tasks (unit_id, resource_id, title, target_minutes, scheduled_date, priority) "
        "VALUES (?, ?, ?, ?, ?, ?)",
        [
            (1, 1, "Watch linked lesson", 25, today, 7),
            (None, 2, "Read offline notes", 15, today, 3),
            (None, None, "Standalone review", 10, today, 1),
        ],
    )
    await db.commit()

    @asynccontextmanager
    async def use_test_db():
        yield db

    class FakeLLM:
        def __init__(self, **_kwargs):
            pass

        async def ainvoke(self, _messages):
            return SimpleNamespace(content="今日按计划稳步推进。")

    monkeypatch.setattr(morning_agent, "get_db", lambda: use_test_db())
    monkeypatch.setattr(morning_agent, "ChatGoogleGenerativeAI", FakeLLM)
    async def fake_read_plan_md(_path):
        return ""

    monkeypatch.setattr(morning_agent, "read_plan_md", fake_read_plan_md)

    result = await morning_agent._generate_briefing_node({
        "reordered_tasks": [],
        "speed_factor_adjustments": [],
    })

    tasks = {task["title"]: task for task in result["briefing"]["tasks"]}
    expected_fields = {
        "id",
        "title",
        "target_minutes",
        "completed_at",
        "resource_title",
        "priority",
        "resource_url",
        "unit_url",
    }

    assert expected_fields <= tasks["Watch linked lesson"].keys()
    assert tasks["Watch linked lesson"]["resource_url"] == "https://example.com/course"
    assert tasks["Watch linked lesson"]["unit_url"] is None

    assert tasks["Read offline notes"]["resource_url"] is None
    assert tasks["Read offline notes"]["unit_url"] is None

    assert tasks["Standalone review"]["resource_title"] is None
    assert tasks["Standalone review"]["resource_url"] is None
    assert tasks["Standalone review"]["unit_url"] is None
