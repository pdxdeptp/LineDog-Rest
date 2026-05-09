import json
from datetime import date, datetime, timedelta
from typing import Any

import aiosqlite


async def get_tasks_by_date(db: aiosqlite.Connection, target_date: date) -> list[dict]:
    async with db.execute(
        "SELECT * FROM tasks WHERE scheduled_date = ? ORDER BY priority DESC, id ASC",
        (target_date.isoformat(),),
    ) as cursor:
        rows = await cursor.fetchall()
        cols = [d[0] for d in cursor.description]
        return [dict(zip(cols, r)) for r in rows]


async def get_incomplete_yesterday(db: aiosqlite.Connection) -> list[dict]:
    yesterday = (date.today() - timedelta(days=1)).isoformat()
    async with db.execute(
        "SELECT * FROM tasks WHERE scheduled_date = ? AND completed_at IS NULL ORDER BY priority DESC",
        (yesterday,),
    ) as cursor:
        rows = await cursor.fetchall()
        cols = [d[0] for d in cursor.description]
        return [dict(zip(cols, r)) for r in rows]


async def get_resource_progress(db: aiosqlite.Connection, resource_id: int) -> dict:
    async with db.execute(
        "SELECT id, title, tracking_mode, total_units, completed_units, actual_minutes_total, estimated_hours, deadline, status, speed_factor "
        "FROM resources WHERE id = ?",
        (resource_id,),
    ) as cursor:
        row = await cursor.fetchone()
        if not row:
            return {}
        cols = [d[0] for d in cursor.description]
        return dict(zip(cols, row))


async def get_all_active_resources(db: aiosqlite.Connection) -> list[dict]:
    async with db.execute(
        "SELECT * FROM resources WHERE status = 'active'",
    ) as cursor:
        rows = await cursor.fetchall()
        cols = [d[0] for d in cursor.description]
        return [dict(zip(cols, r)) for r in rows]


async def check_capacity(db: aiosqlite.Connection, start: date, end: date, daily_capacity_min: int) -> dict[str, int]:
    result: dict[str, int] = {}
    current = start
    while current <= end:
        async with db.execute(
            "SELECT COALESCE(SUM(target_minutes), 0) FROM tasks WHERE scheduled_date = ? AND completed_at IS NULL",
            (current.isoformat(),),
        ) as cursor:
            (used,) = await cursor.fetchone()
        result[current.isoformat()] = max(0, daily_capacity_min - (used or 0))
        current += timedelta(days=1)
    return result


async def upsert_system_state(db: aiosqlite.Connection, key: str, value: str) -> None:
    await db.execute(
        "INSERT INTO system_state (key, value, updated_at) VALUES (?, ?, CURRENT_TIMESTAMP) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at",
        (key, value),
    )
    await db.commit()


async def get_system_state(db: aiosqlite.Connection, key: str) -> str | None:
    async with db.execute("SELECT value FROM system_state WHERE key = ?", (key,)) as cursor:
        row = await cursor.fetchone()
        return row[0] if row else None


async def insert_event(db: aiosqlite.Connection, event_type: str, payload: dict | None = None) -> None:
    await db.execute(
        "INSERT INTO events (event_type, payload) VALUES (?, ?)",
        (event_type, json.dumps(payload) if payload else None),
    )
    await db.commit()


async def has_weekly_review_done(db: aiosqlite.Connection, target_sunday: date) -> bool:
    day_start = datetime.combine(target_sunday, datetime.min.time()).isoformat()
    day_end = datetime.combine(target_sunday, datetime.max.time()).isoformat()
    async with db.execute(
        "SELECT 1 FROM events WHERE event_type = 'weekly_review_done' AND created_at BETWEEN ? AND ? LIMIT 1",
        (day_start, day_end),
    ) as cursor:
        return await cursor.fetchone() is not None


async def get_task_stats(db: aiosqlite.Connection, period: str) -> dict:
    today = date.today()
    if period == "today":
        start, end = today, today
    elif period == "this_week":
        start = today - timedelta(days=today.weekday())
        end = start + timedelta(days=6)
    elif period == "last_week":
        start = today - timedelta(days=today.weekday() + 7)
        end = start + timedelta(days=6)
    else:
        start, end = today, today

    async with db.execute(
        "SELECT COUNT(*) as total, "
        "SUM(CASE WHEN completed_at IS NOT NULL THEN 1 ELSE 0 END) as completed "
        "FROM tasks WHERE scheduled_date BETWEEN ? AND ?",
        (start.isoformat(), end.isoformat()),
    ) as cursor:
        row = await cursor.fetchone()
        total, completed = row[0] or 0, row[1] or 0

    return {
        "period": period,
        "total": total,
        "completed": completed,
        "completion_rate": round(completed / total, 2) if total > 0 else 0.0,
        "start": start.isoformat(),
        "end": end.isoformat(),
    }


async def reschedule_task(db: aiosqlite.Connection, task_id: int, new_date: date) -> None:
    await db.execute(
        "UPDATE tasks SET scheduled_date = ?, reschedule_count = reschedule_count + 1 WHERE id = ?",
        (new_date.isoformat(), task_id),
    )
    await db.commit()


async def complete_task(db: aiosqlite.Connection, task_id: int, actual_minutes: int | None = None) -> dict:
    now = datetime.utcnow().isoformat()
    await db.execute(
        "UPDATE tasks SET completed_at = ?, actual_minutes = ? WHERE id = ?",
        (now, actual_minutes, task_id),
    )
    async with db.execute("SELECT unit_id, resource_id, target_minutes FROM tasks WHERE id = ?", (task_id,)) as cur:
        task = await cur.fetchone()
    if task:
        unit_id, resource_id, target_minutes = task
        if unit_id:
            await db.execute(
                "UPDATE units SET status = 'completed', completed_at = ?, actual_minutes = ? WHERE id = ?",
                (now, actual_minutes or target_minutes, unit_id),
            )
        if resource_id:
            await db.execute(
                "UPDATE resources SET completed_units = completed_units + 1, "
                "actual_minutes_total = actual_minutes_total + ? WHERE id = ?",
                (actual_minutes or target_minutes or 0, resource_id),
            )
            async with db.execute(
                "SELECT total_units, completed_units FROM resources WHERE id = ?", (resource_id,)
            ) as cur:
                res = await cur.fetchone()
            if res and res[0] and res[1] >= res[0]:
                await db.execute(
                    "UPDATE resources SET status = 'completed' WHERE id = ?", (resource_id,)
                )
                await insert_event(db, "resource_completed", {"resource_id": resource_id})
    await db.commit()
    await insert_event(db, "task_completed", {"task_id": task_id})
    return {"task_id": task_id, "completed_at": now}


async def get_resource_reschedule_stats(db: aiosqlite.Connection, resource_id: int, days: int = 14) -> dict:
    cutoff = (date.today() - timedelta(days=days)).isoformat()
    async with db.execute(
        "SELECT COUNT(*) as total, "
        "SUM(CASE WHEN reschedule_count > 0 THEN 1 ELSE 0 END) as rescheduled, "
        "SUM(CASE WHEN completed_at IS NOT NULL THEN 1 ELSE 0 END) as completed "
        "FROM tasks WHERE resource_id = ? AND created_at >= ?",
        (resource_id, cutoff),
    ) as cursor:
        row = await cursor.fetchone()
        total, rescheduled, completed = row[0] or 0, row[1] or 0, row[2] or 0

    return {
        "resource_id": resource_id,
        "total": total,
        "rescheduled": rescheduled,
        "completed": completed,
        "reschedule_rate": round(rescheduled / total, 2) if total > 0 else 0.0,
        "completion_rate": round(completed / total, 2) if total > 0 else 0.0,
    }
