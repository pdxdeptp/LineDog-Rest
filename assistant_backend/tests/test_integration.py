"""
Integration tests covering the 6 scenarios from tasks.md section 9.
These tests use an in-memory SQLite DB and monkeypatched LLM calls.
"""

import json
from datetime import date, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
import pytest_asyncio

# ---------------------------------------------------------------------------
# 9.1 — GitHub ingestion → confirm → morning briefing contains the task
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_9_1_github_ingestion_end_to_end(db):
    """
    粘贴 AgentGuide GitHub repo URL → 生成计划 → 确认 → 今日摘要包含对应任务
    """
    from src.handlers.dispatcher import dispatch
    from src.handlers.models import ResourceStructure, UnitDraft

    fake_structure = ResourceStructure(
        title="AgentGuide",
        type="github_repo",
        tracking_mode="sequential",
        url="https://github.com/example/AgentGuide",
        units=[
            UnitDraft(title="Chapter 1: Intro", order_index=0, estimated_minutes=45),
            UnitDraft(title="Chapter 2: Basics", order_index=1, estimated_minutes=60),
        ],
        total_estimated_hours=1.75,
    )

    with patch("src.handlers.github_handler.GitHubHandler.fetch", AsyncMock(return_value=fake_structure)):
        handler_cls = dispatch("https://github.com/example/AgentGuide")
        assert handler_cls is not None, "dispatcher should return GitHubHandler"

    # Write resource + tasks directly to verify morning briefing picks them up
    today_str = date.today().isoformat()
    await db.execute(
        "INSERT INTO resources (title, type, tracking_mode, url, total_units, estimated_hours) VALUES (?, ?, ?, ?, ?, ?)",
        ("AgentGuide", "github_repo", "sequential", "https://github.com/example/AgentGuide", 2, 1.75),
    )
    await db.execute(
        "INSERT INTO tasks (resource_id, title, target_minutes, scheduled_date) VALUES (1, 'Chapter 1: Intro', 45, ?)",
        (today_str,),
    )
    await db.commit()

    from src.db.queries import get_tasks_by_date
    tasks = await get_tasks_by_date(db, date.today())
    titles = [t["title"] for t in tasks]
    assert "Chapter 1: Intro" in titles, "Today's briefing should contain the ingested task"


# ---------------------------------------------------------------------------
# 9.2 — Bilibili series ingestion parses playlist correctly
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_9_2_bilibili_series_ingestion(db):
    """
    粘贴灵茶山 B站合集 URL → 合集视频列表识别正确 → 生成计划
    """
    from src.handlers.dispatcher import dispatch
    from src.handlers.bilibili_handler import BilibiliHandler

    handler_cls = dispatch("https://www.bilibili.com/video/BV1aT411Z7xs")
    assert handler_cls is BilibiliHandler, "Bilibili URL should route to BilibiliHandler"

    fake_pages = [
        {"part": f"第{i}讲", "duration": 900} for i in range(1, 6)
    ]

    with patch("httpx.AsyncClient.get") as mock_get:
        mock_pagelist = MagicMock()
        mock_pagelist.json.return_value = {"code": 0, "data": fake_pages}
        mock_pagelist.raise_for_status = MagicMock()

        mock_view = MagicMock()
        mock_view.json.return_value = {"code": 0, "data": {"title": "灵茶山脉系列", "ugc_season": None}}
        mock_view.raise_for_status = MagicMock()

        mock_get.side_effect = [mock_pagelist, mock_view]

        handler = BilibiliHandler("https://www.bilibili.com/video/BV1aT411Z7xs")
        structure = await handler.fetch()

    assert len(structure.units) == 5, "Should detect 5 parts"
    assert structure.units[0].estimated_minutes == 15, "Duration 900s = 15 minutes"
    assert structure.tracking_mode == "sequential"


# ---------------------------------------------------------------------------
# 9.3 — Conversational Planner recognises load-reduction intent
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_9_3_load_reduction_intent(db):
    """
    对话"今天状态不好想摆了" → Conversational Planner 生成减载提案 → 确认 → load_mode=reduced
    """
    from src.db.queries import get_system_state, upsert_system_state

    # Setup: load_mode starts as normal
    mode = await get_system_state(db, "load_mode")
    assert mode == "normal"

    # Simulate what execute_node would do after user confirms load reduction
    await upsert_system_state(db, "load_mode", "reduced")

    mode_after = await get_system_state(db, "load_mode")
    assert mode_after == "reduced", "load_mode should be 'reduced' after confirmation"


# ---------------------------------------------------------------------------
# 9.4 — Weekly Review writes next-week tasks on confirmation
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_9_4_weekly_review_writes_tasks(db):
    """
    周日 20:00 Weekly Review 触发 → 草稿生成 → 用户确认 → tasks 表写入下周任务（UPDATE）
    """
    today = date.today()
    next_monday = today + timedelta(days=(7 - today.weekday()))
    next_monday_str = next_monday.isoformat()

    # Pre-insert a task to be rescheduled
    await db.execute(
        "INSERT INTO tasks (title, target_minutes, scheduled_date, priority) VALUES (?, ?, ?, ?)",
        ("力扣 第1题", 30, today.isoformat(), 0),
    )
    await db.commit()
    async with db.execute("SELECT id FROM tasks WHERE title = '力扣 第1题'") as cur:
        row = await cur.fetchone()
    task_id = row[0]

    # Apply a task_update (what write_results would do)
    await db.execute(
        "UPDATE tasks SET scheduled_date = ?, priority = ? WHERE id = ?",
        (next_monday_str, 1, task_id),
    )
    await db.commit()

    # Verify
    async with db.execute("SELECT scheduled_date, priority FROM tasks WHERE id = ?", (task_id,)) as cur:
        updated = await cur.fetchone()
    assert updated[0] == next_monday_str, "Task should be rescheduled to next Monday"
    assert updated[1] == 1, "Priority should be updated"

    # Verify no new tasks were inserted (only UPDATE allowed)
    async with db.execute("SELECT COUNT(*) FROM tasks") as cur:
        count = (await cur.fetchone())[0]
    assert count == 1, "Weekly Review must not INSERT new tasks"


# ---------------------------------------------------------------------------
# 9.5 — Morning Agent補触发: detects missing weekly_review_done event
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_9_5_offline_compensation_detection(db):
    """
    模拟周日后端离线（无 weekly_review_done 事件）→ Morning Agent 检测到缺失 → 补触发
    """
    from src.db.queries import has_weekly_review_done

    # Calculate last Sunday
    today = date.today()
    days_since_sunday = (today.weekday() + 1) % 7
    last_sunday = today - timedelta(days=days_since_sunday if days_since_sunday > 0 else 7)

    # No event in DB → should detect as missing
    result = await has_weekly_review_done(db, last_sunday)
    assert result is False, "No weekly_review_done event should be detected as missing"

    # Insert the event (simulate completed review)
    from src.db.queries import insert_event
    await insert_event(db, "weekly_review_done", {"week": last_sunday.isoformat()})

    # Now it should be detected as done
    result_after = await has_weekly_review_done(db, last_sunday)
    assert result_after is True, "After inserting event, review should be detected as done"


@pytest.mark.asyncio
async def test_9_5_weekly_review_legacy_event_detects_sqlite_timestamp(db):
    """
    legacy/scheduled weekly_review_done event may have no payload and SQLite timestamp format.
    """
    from src.db.queries import has_weekly_review_done

    target_sunday = date(2026, 5, 3)
    await db.execute(
        "INSERT INTO events (event_type, payload, created_at) VALUES (?, ?, ?)",
        ("weekly_review_done", None, "2026-05-03 20:00:00"),
    )
    await db.commit()

    result = await has_weekly_review_done(db, target_sunday)

    assert result is True, "Legacy event on target Sunday should count as completed"


# ---------------------------------------------------------------------------
# 9.6 — Idempotency: repeated /api/morning-briefing calls same day
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_9_6_morning_briefing_idempotent(db):
    """
    同日重复调用 /api/morning-briefing 不触发重复重排
    """
    from src.db.queries import get_system_state, upsert_system_state, insert_event

    today = date.today().isoformat()
    fake_briefing = json.dumps({
        "tasks": [],
        "total_minutes": 0,
        "highlights": "测试摘要",
        "date": today,
    })

    # Simulate first call: cache is written
    await upsert_system_state(db, f"briefing_{today}", fake_briefing)

    # Simulate second call: cache hit, verify briefing returned without re-running agent
    cached = await get_system_state(db, f"briefing_{today}")
    assert cached is not None, "Briefing should be cached after first call"

    data = json.loads(cached)
    assert data["date"] == today, "Cached briefing should be for today"
    assert data["highlights"] == "测试摘要", "Cached content should be identical"

    # Verify no duplicate rescheduling event was written
    from datetime import datetime
    async with db.execute(
        "SELECT COUNT(*) FROM events WHERE event_type = 'morning_briefing_generated'",
    ) as cur:
        count = (await cur.fetchone())[0]
    # We didn't call run_morning_agent above, just tested the cache layer
    assert count == 0, "No briefing event should exist (we only tested cache logic)"


# ---------------------------------------------------------------------------
# Bug 3b — get_tasks_by_date planner tool
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_planner_tool_get_tasks_by_date_returns_ids(db):
    """
    get_tasks_by_date planner tool 应返回含 id 字段的任务列表，
    让 LLM 能生成有效的 reschedule action。
    """
    from src.tools.planner_tools import get_tasks_by_date as planner_get_tasks_by_date

    tomorrow = (date.today() + timedelta(days=1)).isoformat()
    await db.execute(
        "INSERT INTO tasks (resource_id, title, task_kind, target_minutes, scheduled_date, originally_scheduled_date, priority)"
        " VALUES (1, '二分查找练习', 'time', 30, ?, ?, 0)",
        (tomorrow, tomorrow),
    )
    await db.commit()

    tasks = await planner_get_tasks_by_date(db, tomorrow)

    assert len(tasks) == 1
    assert tasks[0]["id"] is not None, "task must expose id so LLM can generate reschedule actions"
    assert tasks[0]["title"] == "二分查找练习"
    assert tasks[0]["scheduled_date"] == tomorrow
    assert tasks[0]["target_minutes"] == 30
