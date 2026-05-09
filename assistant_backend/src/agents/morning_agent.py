"""
Morning Agent

LangGraph graph: START → check_weekly_review → [cond] → run_weekly_review? → reorder_tasks → generate_briefing → END

Triggered once per day via macOS LaunchAgent → POST /api/morning-briefing
Idempotent: if today's briefing already exists in events, returns cached result.
"""

from __future__ import annotations

import asyncio
import json
import logging
from datetime import date, datetime, timedelta
from typing import Any

import aiosqlite
from langchain_core.messages import HumanMessage, SystemMessage
from langchain_google_genai import ChatGoogleGenerativeAI
from langgraph.graph import END, START, StateGraph
from typing_extensions import TypedDict

from ..config import GEMINI_API_KEY, GEMINI_MODEL, PLAN_MD_PATH
from ..db.connection import get_db
from ..db.plan_md import read_plan_md
from ..db.queries import (
    get_all_active_resources,
    get_incomplete_yesterday,
    get_system_state,
    get_tasks_by_date,
    has_weekly_review_done,
    insert_event,
    reschedule_task,
    upsert_system_state,
)

logger = logging.getLogger(__name__)


class MorningState(TypedDict):
    today: str
    needs_weekly_review: bool
    weekly_review_done: bool
    incomplete_yesterday: list[dict]
    reordered_tasks: list[dict]
    briefing: dict  # {summary, tasks, total_minutes, highlights}
    speed_factor_adjustments: list[dict]


def _last_sunday() -> date:
    today = date.today()
    days_since_sunday = (today.weekday() + 1) % 7
    if days_since_sunday == 0:
        return today - timedelta(days=7)
    return today - timedelta(days=days_since_sunday)


async def _check_weekly_review_node(state: MorningState) -> dict:
    async with get_db() as db:
        last_sun = _last_sunday()
        already_done = await has_weekly_review_done(db, last_sun)
    return {"needs_weekly_review": not already_done}


def _route_weekly_review(state: MorningState) -> str:
    return "run_weekly_review" if state["needs_weekly_review"] else "reorder_tasks"


async def _run_weekly_review_node(state: MorningState) -> dict:
    """Automated weekly review triggered by Morning Agent (no interrupt)."""
    from .weekly_review_agent import run_weekly_review_for_morning_agent

    async with get_db() as db:
        await run_weekly_review_for_morning_agent(db)

    return {"weekly_review_done": True}


async def _reorder_tasks_node(state: MorningState) -> dict:
    """Reschedule yesterday's incomplete tasks into today or nearest available slot."""
    today = date.today()
    async with get_db() as db:
        incomplete = await get_incomplete_yesterday(db)
        daily_cap_str = await get_system_state(db, "daily_capacity_min")
        load_mode = await get_system_state(db, "load_mode") or "normal"
        cap_key = "reduced_capacity_min" if load_mode == "reduced" else "daily_capacity_min"
        daily_cap = int(await get_system_state(db, cap_key) or "300")

        today_tasks = await get_tasks_by_date(db, today)
        used_minutes = sum(t.get("target_minutes") or 0 for t in today_tasks if not t.get("completed_at"))
        remaining = daily_cap - used_minutes

        sorted_incomplete = sorted(incomplete, key=lambda t: -(t.get("priority") or 0))
        reordered: list[dict] = []

        for task in sorted_incomplete:
            task_mins = task.get("target_minutes") or 0
            if task_mins <= remaining:
                target_date = today
                remaining -= task_mins
            else:
                target_date = await _find_next_available_slot(db, today, task_mins, daily_cap)

            await reschedule_task(db, task["id"], target_date)
            await insert_event(db, "task_rescheduled", {
                "task_id": task["id"],
                "from_date": task.get("scheduled_date"),
                "to_date": target_date.isoformat(),
            })
            reordered.append({**task, "new_scheduled_date": target_date.isoformat()})

    return {"incomplete_yesterday": incomplete, "reordered_tasks": reordered}


async def _find_next_available_slot(
    db: aiosqlite.Connection, start: date, needed_minutes: int, daily_cap: int
) -> date:
    candidate = start
    for _ in range(60):
        tasks = await get_tasks_by_date(db, candidate)
        used = sum(t.get("target_minutes") or 0 for t in tasks if not t.get("completed_at"))
        if daily_cap - used >= needed_minutes:
            return candidate
        candidate += timedelta(days=1)
    return start + timedelta(days=1)


async def _calibrate_speed_factors_node(state: MorningState) -> dict:
    """Speed factor calibration (task 8.2): adjust resource.speed_factor based on recent performance."""
    from ..db.queries import get_resource_reschedule_stats

    adjustments: list[dict] = []
    async with get_db() as db:
        resources = await get_all_active_resources(db)
        for resource in resources:
            stats = await get_resource_reschedule_stats(db, resource["id"])
            if stats["total"] < 5:
                continue

            current_speed = float(resource.get("speed_factor") or 1.0)
            reschedule_rate = stats["reschedule_rate"]
            completion_rate = stats["completion_rate"]

            new_speed = current_speed
            if reschedule_rate > 0.4 and current_speed > 0.5:
                new_speed = round(current_speed * 0.9, 2)
            elif completion_rate > 0.9 and reschedule_rate < 0.1 and current_speed < 2.0:
                new_speed = round(current_speed * 1.05, 2)

            if new_speed != current_speed:
                await db.execute(
                    "UPDATE resources SET speed_factor = ? WHERE id = ?",
                    (new_speed, resource["id"]),
                )
                await db.commit()
                await insert_event(db, "speed_factor_changed", {
                    "resource_id": resource["id"],
                    "old_factor": current_speed,
                    "new_factor": new_speed,
                })
                adjustments.append({
                    "resource_id": resource["id"],
                    "title": resource["title"],
                    "old_factor": current_speed,
                    "new_factor": new_speed,
                })

    return {"speed_factor_adjustments": adjustments}


async def _generate_briefing_node(state: MorningState) -> dict:
    """Generate today's briefing summary using LLM."""
    today = date.today()
    async with get_db() as db:
        today_tasks = await get_tasks_by_date(db, today)
        resources = await get_all_active_resources(db)
        plan_content = await read_plan_md(PLAN_MD_PATH)
        load_mode = await get_system_state(db, "load_mode") or "normal"

    total_minutes = sum(t.get("target_minutes") or 0 for t in today_tasks if not t.get("completed_at"))

    resource_map = {r["id"]: r for r in resources}
    tasks_with_context = []
    for t in today_tasks:
        res = resource_map.get(t.get("resource_id"))
        tasks_with_context.append({
            "id": t["id"],
            "title": t["title"],
            "target_minutes": t.get("target_minutes"),
            "completed_at": t.get("completed_at"),
            "resource_title": res["title"] if res else None,
            "priority": t.get("priority", 0),
        })

    reordered_count = len(state.get("reordered_tasks") or [])

    llm = ChatGoogleGenerativeAI(model=GEMINI_MODEL, google_api_key=GEMINI_API_KEY)
    prompt_parts = [
        f"今天是 {today.strftime('%Y年%m月%d日')}，负荷模式：{load_mode}。",
        f"今日任务共 {len(today_tasks)} 项，预估总时长 {total_minutes} 分钟。",
        f"昨日未完成任务已重排 {reordered_count} 项。",
        "",
        "当前各资料进度：",
    ]
    for r in resources:
        total = r.get("total_units") or 0
        done = r.get("completed_units") or 0
        pct = round(done / total * 100) if total else 0
        prompt_parts.append(f"- {r['title']}: {done}/{total} ({pct}%)")

    if state.get("speed_factor_adjustments"):
        prompt_parts.append("\n速度系数已调整：")
        for adj in state["speed_factor_adjustments"]:
            direction = "偏慢" if adj["new_factor"] < adj["old_factor"] else "偏快"
            prompt_parts.append(f"- {adj['title']} 实际速度{direction}，速度系数 {adj['old_factor']} → {adj['new_factor']}")

    prompt_parts += [
        "",
        "请生成一句简洁的今日状态摘要（15-30字），客观反映当前进度状态，可以是激励或提醒，不要过于煽情。",
        "只返回这一句话，不要其他内容。",
    ]

    try:
        response = await llm.ainvoke([HumanMessage(content="\n".join(prompt_parts))])
        highlights = response.content.strip()
    except Exception:
        highlights = f"今日共 {len(today_tasks)} 项任务，预估 {total_minutes} 分钟。"

    briefing = {
        "tasks": tasks_with_context,
        "total_minutes": total_minutes,
        "highlights": highlights,
        "date": today.isoformat(),
        "load_mode": load_mode,
    }

    async with get_db() as db:
        await insert_event(db, "morning_briefing_generated", {"date": today.isoformat()})
        await upsert_system_state(db, f"briefing_{today.isoformat()}", json.dumps(briefing))

    return {"briefing": briefing}


def _build_morning_graph():
    graph = StateGraph(MorningState)
    graph.add_node("check_weekly_review", _check_weekly_review_node)
    graph.add_node("run_weekly_review", _run_weekly_review_node)
    graph.add_node("reorder_tasks", _reorder_tasks_node)
    graph.add_node("calibrate_speed", _calibrate_speed_factors_node)
    graph.add_node("generate_briefing", _generate_briefing_node)

    graph.add_edge(START, "check_weekly_review")
    graph.add_conditional_edges("check_weekly_review", _route_weekly_review, {
        "run_weekly_review": "run_weekly_review",
        "reorder_tasks": "reorder_tasks",
    })
    graph.add_edge("run_weekly_review", "reorder_tasks")
    graph.add_edge("reorder_tasks", "calibrate_speed")
    graph.add_edge("calibrate_speed", "generate_briefing")
    graph.add_edge("generate_briefing", END)

    return graph.compile()


_graph = None


def _get_graph():
    global _graph
    if _graph is None:
        _graph = _build_morning_graph()
    return _graph


async def run_morning_agent() -> dict:
    """Run morning agent. Returns briefing dict. Idempotent within same calendar day."""
    today = date.today().isoformat()

    async with get_db() as db:
        cached = await get_system_state(db, f"briefing_{today}")
        if cached:
            try:
                return json.loads(cached)
            except Exception:
                pass

    graph = _get_graph()
    initial_state: MorningState = {
        "today": today,
        "needs_weekly_review": False,
        "weekly_review_done": False,
        "incomplete_yesterday": [],
        "reordered_tasks": [],
        "briefing": {},
        "speed_factor_adjustments": [],
    }
    result = await graph.ainvoke(initial_state)
    return result.get("briefing", {})
