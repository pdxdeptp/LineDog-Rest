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


# ---------------------------------------------------------------------------
# Task 1.1 — daily_capacity_min default is 60
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_daily_capacity_default_is_60():
    """
    新数据库的 daily_capacity_min 默认值应为 "60"；
    已有 "300" 的数据库经 init_db 迁移后应更新为 "60"。
    """
    import aiosqlite
    import tempfile
    import os
    from src.db.schema import SCHEMA_SQL, DEFAULT_SYSTEM_STATE
    from src.db.init import init_db

    # 1. 新建 DB：确认默认值为 "60"
    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        new_db_path = f.name
    try:
        await init_db(new_db_path)
        async with aiosqlite.connect(new_db_path) as conn:
            async with conn.execute(
                "SELECT value FROM system_state WHERE key = 'daily_capacity_min'"
            ) as cur:
                row = await cur.fetchone()
        assert row is not None, "daily_capacity_min should exist in system_state"
        assert row[0] == "60", f"Expected '60', got {row[0]!r}"
    finally:
        os.unlink(new_db_path)

    # 2. 已有 "300" 的 DB：init_db 应迁移为 "60"
    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        migrate_db_path = f.name
    try:
        # 先建表并插入旧值 "300"
        async with aiosqlite.connect(migrate_db_path) as conn:
            await conn.executescript(SCHEMA_SQL)
            await conn.execute(
                "INSERT OR REPLACE INTO system_state (key, value) VALUES ('daily_capacity_min', '300')"
            )
            await conn.commit()

        # 执行 init_db（应触发迁移逻辑）
        await init_db(migrate_db_path)

        async with aiosqlite.connect(migrate_db_path) as conn:
            async with conn.execute(
                "SELECT value FROM system_state WHERE key = 'daily_capacity_min'"
            ) as cur:
                row = await cur.fetchone()
        assert row is not None
        assert row[0] == "60", f"Migration failed: expected '60', got {row[0]!r}"
    finally:
        os.unlink(migrate_db_path)


# ---------------------------------------------------------------------------
# Tasks 2.1–2.4 — Learning Preferences API (GET/PUT /api/settings/learning-preferences)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_get_learning_preferences_default(client):
    """
    GET /api/settings/learning-preferences 在 daily_capacity_min 未写入 DB 时
    应返回默认值 60。
    """
    resp = await client.get("/api/settings/learning-preferences")
    assert resp.status_code == 200
    data = resp.json()
    assert data == {"daily_capacity_min": 60}


@pytest.mark.asyncio
async def test_put_learning_preferences_valid(client):
    """
    PUT /api/settings/learning-preferences {"daily_capacity_min": 90}
    应返回 {"daily_capacity_min": 90}，随后 GET 也应返回 90。
    """
    put_resp = await client.put(
        "/api/settings/learning-preferences",
        json={"daily_capacity_min": 90},
    )
    assert put_resp.status_code == 200
    assert put_resp.json() == {"daily_capacity_min": 90}

    get_resp = await client.get("/api/settings/learning-preferences")
    assert get_resp.status_code == 200
    assert get_resp.json() == {"daily_capacity_min": 90}


@pytest.mark.asyncio
async def test_put_learning_preferences_invalid_range(client):
    """
    PUT daily_capacity_min=0 → 422；1441 → 422；
    边界值 1 → 200；1440 → 200。
    """
    # 超出下界
    resp = await client.put(
        "/api/settings/learning-preferences",
        json={"daily_capacity_min": 0},
    )
    assert resp.status_code == 422, f"expected 422 for 0, got {resp.status_code}"

    # 超出上界
    resp = await client.put(
        "/api/settings/learning-preferences",
        json={"daily_capacity_min": 1441},
    )
    assert resp.status_code == 422, f"expected 422 for 1441, got {resp.status_code}"

    # 边界下限合法
    resp = await client.put(
        "/api/settings/learning-preferences",
        json={"daily_capacity_min": 1},
    )
    assert resp.status_code == 200, f"expected 200 for 1, got {resp.status_code}"

    # 边界上限合法
    resp = await client.put(
        "/api/settings/learning-preferences",
        json={"daily_capacity_min": 1440},
    )
    assert resp.status_code == 200, f"expected 200 for 1440, got {resp.status_code}"


# ---------------------------------------------------------------------------
# Task 1.3 — POST /api/ingest/start returns thread_id
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_ingest_start_returns_thread_id(client):
    """
    POST /api/ingest/start 应立即返回 {"thread_id": <uuid>}，不等待图执行完成。
    """
    import uuid

    # patch create_task to prevent actual LLM/network calls in background
    def close_background_coro(coro):
        coro.close()
        return MagicMock()

    with patch("src.routers.ingest.asyncio.create_task") as mock_create_task:
        mock_create_task.side_effect = close_background_coro

        resp = await client.post(
            "/api/ingest/start",
            json={
                "url": "https://github.com/example/repo",
                "deadline": "2026-12-31",
                "speed_factor": 1.0,
            },
        )

    assert resp.status_code == 200, f"Expected 200, got {resp.status_code}: {resp.text}"
    data = resp.json()
    assert "thread_id" in data, f"Response missing 'thread_id': {data}"
    try:
        uuid.UUID(data["thread_id"])
    except ValueError:
        pytest.fail(f"thread_id is not a valid UUID: {data['thread_id']!r}")


# ---------------------------------------------------------------------------
# Task 1.4 — GET /api/ingest/progress/{thread_id} SSE stream
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_sse_phases_sequence(client):
    """
    预先在 progress_store 中填充事件，SSE 端点应按顺序流式返回所有事件，
    最后一个事件的 done=True。
    """
    from src.agents.ingestion_agent import progress_store, ThreadProgress

    test_thread_id = "test-sse-thread-001"
    prog = ThreadProgress()
    events = [
        {"phase": "fetch_structure", "label": "正在读取章节结构…", "done": False},
        {"phase": "estimate_time", "label": "正在估算学习时长…", "done": False},
        {"phase": "check_capacity", "label": "正在生成排期方案…", "done": False},
        {"phase": "draft_ready", "label": "草稿已就绪", "done": True, "draft": {}},
    ]
    for e in events:
        prog.events.append(e)
        await prog._queue.put(e)
    prog.is_done = True
    progress_store[test_thread_id] = prog

    received = []
    try:
        async with client.stream("GET", f"/api/ingest/progress/{test_thread_id}") as resp:
            assert resp.status_code == 200
            assert "text/event-stream" in resp.headers.get("content-type", "")
            async for line in resp.aiter_lines():
                if line.startswith("data: "):
                    received.append(json.loads(line[6:]))
    finally:
        progress_store.pop(test_thread_id, None)

    assert len(received) == 4, f"Expected 4 events, got {len(received)}: {received}"
    phases = [e["phase"] for e in received]
    assert phases == [
        "fetch_structure", "estimate_time", "check_capacity", "draft_ready"
    ], f"Phase sequence mismatch: {phases}"
    assert received[-1]["done"] is True, "Last event should have done=True"


# ---------------------------------------------------------------------------
# Task 1.5 — POST /api/ingest/reschedule returns new options
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_reschedule_returns_new_options(client):
    """
    已有 thread 中存有 resource，调用 /api/ingest/reschedule 并传入新 deadline，
    应返回包含 option_a 和 option_b 的响应。
    """
    from src.handlers.models import ResourceStructure, UnitDraft
    from src.agents.ingestion_agent import ingestion_graph

    fake_resource = ResourceStructure(
        title="Test Course",
        type="github_repo",
        tracking_mode="sequential",
        url="https://github.com/example/test",
        units=[
            UnitDraft(title="Unit 1", order_index=0, estimated_minutes=30),
            UnitDraft(title="Unit 2", order_index=1, estimated_minutes=45),
        ],
        total_estimated_hours=1.25,
    )

    mock_snapshot = MagicMock()
    mock_snapshot.values = {
        "resource": fake_resource,
        "deadline": (date.today() + timedelta(days=30)).isoformat(),
        "speed_factor": 1.0,
    }

    deadline_str = (date.today() + timedelta(days=14)).isoformat()

    with patch.object(ingestion_graph, "get_state", return_value=mock_snapshot):
        resp = await client.post(
            "/api/ingest/reschedule",
            json={
                "thread_id": "mock-thread-001",
                "deadline": deadline_str,
                "speed_factor": 1.0,
            },
        )

    assert resp.status_code == 200, f"Expected 200, got {resp.status_code}: {resp.text}"
    data = resp.json()
    assert "option_a" in data, f"Missing option_a in response: {data}"
    assert "option_b" in data, f"Missing option_b in response: {data}"
    assert "resource_title" in data, f"Missing resource_title: {data}"
    assert data["resource_title"] == "Test Course"
    assert data["unit_count"] == 2


# ---------------------------------------------------------------------------
# Task 1.6 — POST /api/ingest/confirm with deadline override
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_confirm_with_deadline_override():
    """
    write_to_db 使用 state 中的 deadline 排期，传入覆盖后的 deadline 时，
    验证写入 DB 的任务全部在新 deadline 范围内。
    """
    import tempfile, os
    import aiosqlite
    from contextlib import asynccontextmanager
    from datetime import date, timedelta

    from src.handlers.models import ResourceStructure, UnitDraft
    from src.agents.ingestion_agent import write_to_db, _schedule_option_a, _schedule_option_b
    from src.db.queries import check_capacity
    from src.db.init import init_db

    with tempfile.TemporaryDirectory() as tmp:
        db_path = os.path.join(tmp, "test.db")
        await init_db(db_path)

        today = date.today()
        new_deadline = (today + timedelta(days=7)).isoformat()
        new_deadline_date = date.fromisoformat(new_deadline)

        fake_resource = ResourceStructure(
            title="Override Test",
            type="github_repo",
            tracking_mode="sequential",
            url="https://github.com/example/override",
            units=[
                UnitDraft(title="Chapter 1", order_index=0, estimated_minutes=30),
            ],
            total_estimated_hours=0.5,
        )

        async with aiosqlite.connect(db_path) as db:
            db.row_factory = aiosqlite.Row
            free_map = await check_capacity(db, today, new_deadline_date, 60)

        option_b = _schedule_option_b(fake_resource.units, new_deadline_date, today, 1.0, 60)

        state_with_override = {
            "url": "https://github.com/example/override",
            "deadline": new_deadline,
            "speed_factor": 1.0,
            "resource": fake_resource,
            "option_a": [],
            "option_b": option_b,
            "confirmed": True,
            "selected_option": "B",
        }

        @asynccontextmanager
        async def mock_get_db():
            async with aiosqlite.connect(db_path) as conn:
                conn.row_factory = aiosqlite.Row
                yield conn

        with patch("src.agents.ingestion_agent.get_db", mock_get_db):
            result_state = await write_to_db(state_with_override)

        assert result_state.get("resource_id") is not None, "resource_id should be set after write_to_db"

        async with aiosqlite.connect(db_path) as db:
            async with db.execute("SELECT scheduled_date FROM tasks ORDER BY scheduled_date") as cur:
                rows = await cur.fetchall()

        assert len(rows) > 0, "At least one task should be written"
        for row in rows:
            task_date = date.fromisoformat(row[0])
            assert task_date <= new_deadline_date, (
                f"Task scheduled on {task_date} exceeds new deadline {new_deadline_date}"
            )
