"""
Planner tools — Python functions called by LangGraph graph nodes.
These are NOT LangChain tool wrappers; they are plain async functions
that accept an aiosqlite connection as the first argument.
"""
from __future__ import annotations

import asyncio
from datetime import date, datetime
from typing import Any

import aiosqlite

from ..db.plan_md import read_plan_md, snapshot_to_db, write_plan_md
from ..db import queries


async def get_current_plan(db: aiosqlite.Connection, plan_path: str) -> str:
    """Return the full text of plan.md."""
    return await read_plan_md(plan_path)


async def get_task_stats(db: aiosqlite.Connection, period: str) -> dict:
    """Return task completion statistics for the given period.

    period: "today" | "this_week" | "last_week"
    """
    return await queries.get_task_stats(db, period)


async def get_resource_progress(db: aiosqlite.Connection, resource_id: int) -> dict:
    """Return progress metadata for a single learning resource."""
    return await queries.get_resource_progress(db, resource_id)


async def check_capacity(db: aiosqlite.Connection, start: str, end: str) -> dict:
    """Return remaining daily capacity (minutes) for each day in [start, end].

    start / end: ISO date strings, e.g. "2026-05-08".
    Daily capacity is read from system_state key 'daily_capacity_min';
    defaults to 120 minutes if the key is absent.
    """
    raw = await queries.get_system_state(db, "daily_capacity_min")
    daily_capacity_min: int = int(raw) if raw else 120

    start_date = date.fromisoformat(start)
    end_date = date.fromisoformat(end)
    return await queries.check_capacity(db, start_date, end_date, daily_capacity_min)


async def update_tasks(db: aiosqlite.Connection, patch: list[dict]) -> dict:
    """Describe the pending changes without writing to the database.

    patch items:
        {
            "action": "update" | "reschedule",
            "task_id": int,
            "scheduled_date": "YYYY-MM-DD",   # required for reschedule
            "priority": int                    # optional for update
        }

    Returns a dict with a human-readable description and the structured
    pending_changes list so the caller can decide whether to commit them.
    """
    descriptions: list[str] = []
    pending: list[dict] = []

    for item in patch:
        action = item.get("action", "update")
        task_id = item["task_id"]

        if action == "reschedule":
            new_date = item.get("scheduled_date", "")
            descriptions.append(
                f"将任务 #{task_id} 重排到 {new_date}"
            )
            pending.append(
                {"action": "reschedule", "task_id": task_id, "scheduled_date": new_date}
            )
        else:
            parts: list[str] = []
            update_payload: dict[str, Any] = {"action": "update", "task_id": task_id}
            if "priority" in item:
                parts.append(f"优先级 → {item['priority']}")
                update_payload["priority"] = item["priority"]
            if "scheduled_date" in item:
                parts.append(f"日期 → {item['scheduled_date']}")
                update_payload["scheduled_date"] = item["scheduled_date"]
            descriptions.append(
                f"更新任务 #{task_id}：{'、'.join(parts) if parts else '无字段变更'}"
            )
            pending.append(update_payload)

    return {
        "pendingChanges": pending,
        "description": "\n".join(descriptions),
        "count": len(pending),
    }


async def rewrite_plan(
    db: aiosqlite.Connection,
    plan_path: str,
    content: str,
    triggered_by: str = "conversational_planner",
) -> None:
    """Overwrite plan.md and snapshot the new version to the database."""
    await write_plan_md(plan_path, content)
    await snapshot_to_db(db, content, triggered_by)
