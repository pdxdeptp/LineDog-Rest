import json
from datetime import UTC, date, datetime, timedelta
from typing import Any

import aiosqlite


class ResourceNotFoundError(Exception):
    pass


class ResourceNotActiveError(Exception):
    pass


class ResourceDeadlineEditNotAllowedError(Exception):
    pass


class ResourceTaskInsertNotAllowedError(Exception):
    pass


class TaskDeleteNotAllowedError(Exception):
    pass


class TaskNotFoundError(Exception):
    pass


class TaskMovePastDateError(Exception):
    pass


class TaskMoveNotAllowedError(Exception):
    pass


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
        "SELECT * FROM resources WHERE status = 'active' ORDER BY id ASC",
    ) as cursor:
        rows = await cursor.fetchall()
        cols = [d[0] for d in cursor.description]
        return [dict(zip(cols, r)) for r in rows]


async def get_today_study_view_tasks(db: aiosqlite.Connection, target_date: date) -> list[dict]:
    async with db.execute(
        """
        SELECT
            t.id,
            t.title,
            t.target_minutes,
            t.completed_at,
            r.id AS project_id,
            r.title AS project_title,
            r.id AS resource_id,
            r.title AS resource_title,
            r.url AS resource_url,
            u.id AS unit_id,
            u.title AS unit_title,
            NULL AS unit_url,
            COALESCE(t.auto_roll_days, 0) AS rolled_day_count
        FROM tasks t
        JOIN resources r ON r.id = t.resource_id
        LEFT JOIN units u ON u.id = t.unit_id
        WHERE t.scheduled_date = ?
          AND r.status = 'active'
          AND r.type = 'study_project'
        ORDER BY t.priority DESC, t.id ASC
        """,
        (target_date.isoformat(),),
    ) as cursor:
        rows = await cursor.fetchall()
        cols = [d[0] for d in cursor.description]
        tasks = [dict(zip(cols, r)) for r in rows]

    for task in tasks:
        task["rolled_day_count"] = int(task["rolled_day_count"] or 0)
        task["show_rolled_badge"] = task["rolled_day_count"] >= 3

    return tasks


async def get_study_project_overview(db: aiosqlite.Connection) -> dict[str, list[dict]]:
    async with db.execute(
        """
        WITH task_progress AS (
            SELECT
                resource_id,
                COUNT(*) AS task_total,
                SUM(CASE WHEN completed_at IS NOT NULL THEN 1 ELSE 0 END) AS task_completed,
                SUM(COALESCE(target_minutes, 0)) AS task_target_minutes,
                SUM(
                    CASE
                        WHEN completed_at IS NOT NULL THEN COALESCE(actual_minutes, target_minutes, 0)
                        ELSE 0
                    END
                ) AS task_actual_minutes
            FROM tasks
            GROUP BY resource_id
        ),
        expected_late_projects AS (
            SELECT
                r.id AS resource_id,
                1 AS expected_late
            FROM resources r
            JOIN tasks t ON t.resource_id = r.id
            WHERE r.type = 'study_project'
              AND r.status = 'active'
              AND r.deadline IS NOT NULL
              AND t.completed_at IS NULL
              AND date(t.scheduled_date) > date(r.deadline)
            GROUP BY r.id
        )
        SELECT
            r.id,
            r.title,
            COALESCE(tp.task_completed, 0) AS completed_units,
            COALESCE(tp.task_total, 0) AS total_units,
            COALESCE(tp.task_target_minutes, 0) AS target_minutes,
            COALESCE(tp.task_actual_minutes, 0) AS actual_minutes,
            r.deadline,
            COALESCE(el.expected_late, 0) AS expected_late,
            r.status
        FROM resources r
        LEFT JOIN task_progress tp ON tp.resource_id = r.id
        LEFT JOIN expected_late_projects el ON el.resource_id = r.id
        WHERE r.type = 'study_project'
          AND r.status IN ('active', 'completed')
        ORDER BY r.id ASC
        """,
    ) as cursor:
        rows = await cursor.fetchall()
        cols = [d[0] for d in cursor.description]

    projects = []
    for row in rows:
        project = dict(zip(cols, row))
        completed_units = project["completed_units"] or 0
        total_units = project["total_units"] or 0
        project["progress_ratio"] = round(completed_units / total_units, 2) if total_units else 0.0
        project["expected_late"] = bool(project["expected_late"])
        projects.append(project)

    return {
        "active_projects": [project for project in projects if project["status"] == "active"],
        "completed_projects": [project for project in projects if project["status"] == "completed"],
    }


def _parse_daily_capacity_minutes(raw: str | None) -> int:
    try:
        capacity = int(raw) if raw is not None else 60
    except (TypeError, ValueError):
        return 60
    return capacity if capacity > 0 else 60


def _normalize_rest_weekdays(values: list[Any] | None) -> list[int]:
    if not values:
        return []
    normalized = set()
    for value in values:
        try:
            weekday = int(value)
        except (TypeError, ValueError):
            continue
        if 0 <= weekday <= 6:
            normalized.add(weekday)
    return sorted(normalized)


def _normalize_rest_dates(values: list[Any] | None) -> list[str]:
    if not values:
        return []
    normalized = set()
    for value in values:
        if isinstance(value, date):
            normalized.add(value.isoformat())
        elif isinstance(value, str):
            try:
                normalized.add(date.fromisoformat(value[:10]).isoformat())
            except ValueError:
                continue
    return sorted(normalized)


def _parse_rest_json(raw: str | None, default: list[Any]) -> list[Any]:
    if raw is None:
        return default
    try:
        parsed = json.loads(raw)
    except (TypeError, json.JSONDecodeError):
        return default
    return parsed if isinstance(parsed, list) else default


async def get_study_rest_day_settings(db: aiosqlite.Connection) -> dict:
    weekly = _normalize_rest_weekdays(
        _parse_rest_json(await get_system_state(db, "study_rest_weekdays"), [5])
    )
    dates = _normalize_rest_dates(
        _parse_rest_json(await get_system_state(db, "study_rest_dates"), [])
    )
    return {
        "weekly_weekdays": weekly,
        "one_off_dates": dates,
    }


async def update_study_rest_day_settings(
    db: aiosqlite.Connection,
    weekly_weekdays: list[int],
    one_off_dates: list[date],
    today: date | None = None,
) -> dict:
    effective_today = today or date.today()
    new_weekly = _normalize_rest_weekdays(weekly_weekdays)
    new_dates = _normalize_rest_dates(one_off_dates)

    await db.execute("BEGIN IMMEDIATE")
    try:
        old_settings = await get_study_rest_day_settings(db)
        old_weekly = old_settings["weekly_weekdays"]
        old_dates = old_settings["one_off_dates"]

        added_weekly = sorted(set(new_weekly) - set(old_weekly))
        removed_weekly = sorted(set(old_weekly) - set(new_weekly))
        added_dates = sorted(set(new_dates) - set(old_dates))
        removed_dates = sorted(set(old_dates) - set(new_dates))
        cascade = await _cascade_for_added_rest_days(
            db,
            added_weekly,
            added_dates,
            old_weekly,
            old_dates,
            effective_today,
        )

        await db.execute(
            """
            INSERT INTO system_state (key, value, updated_at)
            VALUES (?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(key) DO UPDATE SET
                value = excluded.value,
                updated_at = excluded.updated_at
            """,
            ("study_rest_weekdays", json.dumps(new_weekly)),
        )
        await db.execute(
            """
            INSERT INTO system_state (key, value, updated_at)
            VALUES (?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(key) DO UPDATE SET
                value = excluded.value,
                updated_at = excluded.updated_at
            """,
            ("study_rest_dates", json.dumps(new_dates)),
        )

        payload = {
            "old_weekly_weekdays": old_weekly,
            "new_weekly_weekdays": new_weekly,
            "added_weekly_weekdays": added_weekly,
            "removed_weekly_weekdays": removed_weekly,
            "old_one_off_dates": old_dates,
            "new_one_off_dates": new_dates,
            "added_one_off_dates": added_dates,
            "removed_one_off_dates": removed_dates,
            "source": "manual_rest_day_settings",
        }
        await db.execute(
            "INSERT INTO events (event_type, payload) VALUES (?, ?)",
            ("study_rest_days_updated", json.dumps(payload)),
        )
        if cascade["affected_task_ids"]:
            await db.execute(
                "INSERT INTO events (event_type, payload) VALUES (?, ?)",
                ("study_rest_day_cascaded", json.dumps(cascade)),
            )
        await db.commit()
    except Exception:
        await db.rollback()
        raise

    return {
        "weekly_weekdays": new_weekly,
        "one_off_dates": new_dates,
        "added_weekly_weekdays": added_weekly,
        "removed_weekly_weekdays": removed_weekly,
        "added_one_off_dates": added_dates,
        "removed_one_off_dates": removed_dates,
        "source": "manual_rest_day_settings",
    }


async def _cascade_for_added_rest_days(
    db: aiosqlite.Connection,
    added_weekly: list[int],
    added_dates: list[str],
    old_weekly: list[int],
    old_dates: list[str],
    today: date,
) -> dict:
    async with db.execute(
        """
        SELECT MAX(date(t.scheduled_date)) AS horizon
        FROM tasks t
        JOIN resources r ON r.id = t.resource_id
        WHERE r.type = 'study_project'
          AND r.status = 'active'
          AND t.completed_at IS NULL
          AND date(t.scheduled_date) >= date(?)
        """,
        (today.isoformat(),),
    ) as cursor:
        horizon_row = await cursor.fetchone()

    horizon_text = horizon_row["horizon"] if horizon_row else None
    if horizon_text is None:
        return {
            "source": "manual_rest_day_settings",
            "affected_task_ids": [],
            "occurrences": [],
            "changes": [],
        }

    horizon = date.fromisoformat(horizon_text)
    old_weekly_set = set(old_weekly)
    old_date_set = set(old_dates)
    occurrences = set()
    for weekday in added_weekly:
        occurrence = today + timedelta(days=(weekday - today.weekday()) % 7)
        while occurrence <= horizon:
            if occurrence.isoformat() not in old_date_set:
                occurrences.add(occurrence)
            occurrence += timedelta(days=7)
    for date_text in added_dates:
        rest_date = date.fromisoformat(date_text)
        if (
            rest_date >= today
            and rest_date <= horizon
            and rest_date.weekday() not in old_weekly_set
        ):
            occurrences.add(rest_date)

    now = datetime.now(UTC).isoformat()
    original_dates: dict[int, str] = {}
    latest_dates: dict[int, str] = {}
    project_ids: dict[int, int] = {}
    occurrence_payloads = []

    for occurrence in sorted(occurrences):
        async with db.execute(
            """
            SELECT
                t.id,
                t.resource_id,
                t.scheduled_date
            FROM tasks t
            JOIN resources r ON r.id = t.resource_id
            WHERE r.type = 'study_project'
              AND r.status = 'active'
              AND t.completed_at IS NULL
              AND date(t.scheduled_date) >= date(?)
            ORDER BY date(t.scheduled_date), t.id
            """,
            (occurrence.isoformat(),),
        ) as cursor:
            affected = await cursor.fetchall()

        affected_ids = [int(task["id"]) for task in affected]
        if affected_ids:
            occurrence_payloads.append(
                {
                    "date": occurrence.isoformat(),
                    "affected_task_ids": affected_ids,
                    "date_delta_days": 1,
                }
            )
        for task in affected:
            task_id = int(task["id"])
            old_date = task["scheduled_date"][:10]
            new_date = (date.fromisoformat(old_date) + timedelta(days=1)).isoformat()
            original_dates.setdefault(task_id, old_date)
            latest_dates[task_id] = new_date
            project_ids[task_id] = int(task["resource_id"])
            await db.execute(
                """
                UPDATE tasks
                SET scheduled_date = ?,
                    auto_roll_days = 0,
                    last_auto_rolled_at = NULL,
                    user_adjusted_at = ?
                WHERE id = ?
                  AND completed_at IS NULL
                """,
                (new_date, now, task_id),
            )

    affected_task_ids = sorted(original_dates)
    changes = [
        {
            "task_id": task_id,
            "project_id": project_ids[task_id],
            "original_date": original_dates[task_id],
            "new_date": latest_dates[task_id],
            "date_delta_days": (
                date.fromisoformat(latest_dates[task_id])
                - date.fromisoformat(original_dates[task_id])
            ).days,
        }
        for task_id in affected_task_ids
    ]
    return {
        "source": "manual_rest_day_settings",
        "affected_task_ids": affected_task_ids,
        "occurrences": occurrence_payloads,
        "changes": changes,
    }


async def get_study_calendar_load(db: aiosqlite.Connection, start: date, end: date) -> dict:
    daily_capacity_minutes = _parse_daily_capacity_minutes(await get_system_state(db, "daily_capacity_min"))
    rest_day_settings = await get_study_rest_day_settings(db)
    rest_weekdays = set(rest_day_settings["weekly_weekdays"])
    rest_dates = set(rest_day_settings["one_off_dates"])
    async with db.execute(
        """
        SELECT
            t.scheduled_date AS date,
            COUNT(*) AS scheduled_task_count,
            SUM(COALESCE(t.target_minutes, 0)) AS total_target_minutes,
            SUM(CASE WHEN t.completed_at IS NOT NULL THEN 1 ELSE 0 END) AS completed_task_count
        FROM tasks t
        JOIN resources r ON r.id = t.resource_id
        WHERE t.scheduled_date BETWEEN ? AND ?
          AND r.status = 'active'
          AND r.type = 'study_project'
        GROUP BY t.scheduled_date
        """,
        (start.isoformat(), end.isoformat()),
    ) as cursor:
        rows = await cursor.fetchall()
        cols = [d[0] for d in cursor.description]

    aggregates = {row["date"]: row for row in (dict(zip(cols, r)) for r in rows)}
    days = []
    current = start
    while current <= end:
        day = current.isoformat()
        aggregate = aggregates.get(day, {})
        total_target_minutes = aggregate.get("total_target_minutes") or 0
        is_rest_day = current.weekday() in rest_weekdays or day in rest_dates
        day_capacity_minutes = 0 if is_rest_day else daily_capacity_minutes
        days.append(
            {
                "date": day,
                "scheduled_task_count": aggregate.get("scheduled_task_count") or 0,
                "total_target_minutes": total_target_minutes,
                "completed_task_count": aggregate.get("completed_task_count") or 0,
                "rest_day": is_rest_day,
                "available_capacity_minutes": max(0, day_capacity_minutes - total_target_minutes),
                "over_capacity": total_target_minutes > day_capacity_minutes,
            }
        )
        current += timedelta(days=1)

    return {
        "start_date": start.isoformat(),
        "end_date": end.isoformat(),
        "daily_capacity_minutes": daily_capacity_minutes,
        "days": days,
    }


async def rollover_unfinished_study_tasks(db: aiosqlite.Connection, today: date) -> dict:
    today_iso = today.isoformat()
    rolled_tasks: list[dict[str, Any]] = []

    await db.execute("BEGIN IMMEDIATE")
    try:
        async with db.execute(
            """
            SELECT
                t.id,
                t.resource_id,
                t.scheduled_date,
                COALESCE(t.auto_roll_days, 0) AS auto_roll_days
            FROM tasks t
            JOIN resources r ON r.id = t.resource_id
            WHERE r.type = 'study_project'
              AND r.status = 'active'
              AND t.completed_at IS NULL
              AND date(t.scheduled_date) < date(?)
              AND (
                  t.last_auto_rolled_at IS NULL
                  OR date(t.last_auto_rolled_at) < date(?)
              )
            ORDER BY t.scheduled_date ASC, t.id ASC
            """,
            (today_iso, today_iso),
        ) as cursor:
            candidates = await cursor.fetchall()

        for task in candidates:
            original_date = date.fromisoformat(task["scheduled_date"][:10])
            rolled_days = (today - original_date).days
            if rolled_days <= 0:
                continue

            auto_roll_days = int(task["auto_roll_days"] or 0) + rolled_days
            update_cursor = await db.execute(
                """
                UPDATE tasks
                SET scheduled_date = ?,
                    auto_roll_days = ?,
                    last_auto_rolled_at = ?
                WHERE id = ?
                  AND completed_at IS NULL
                  AND date(scheduled_date) = date(?)
                  AND (
                      last_auto_rolled_at IS NULL
                      OR date(last_auto_rolled_at) < date(?)
                  )
                """,
                (
                    today_iso,
                    auto_roll_days,
                    today_iso,
                    task["id"],
                    task["scheduled_date"],
                    today_iso,
                ),
            )
            if update_cursor.rowcount != 1:
                continue

            payload = {
                "task_id": task["id"],
                "resource_id": task["resource_id"],
                "original_date": task["scheduled_date"],
                "new_date": today_iso,
                "rolled_days": rolled_days,
                "source": "auto_rollover",
            }
            await db.execute(
                "INSERT INTO events (event_type, payload) VALUES (?, ?)",
                ("study_task_rolled_over", json.dumps(payload)),
            )
            rolled_tasks.append(
                {
                    "task_id": task["id"],
                    "project_id": task["resource_id"],
                    "old_date": task["scheduled_date"],
                    "new_date": today_iso,
                    "rolled_days": rolled_days,
                    "auto_roll_days": auto_roll_days,
                }
            )

        await db.commit()
    except Exception:
        await db.rollback()
        raise

    return {
        "date": today_iso,
        "rolled_count": len(rolled_tasks),
        "rolled_tasks": rolled_tasks,
    }


async def move_active_study_task(db: aiosqlite.Connection, task_id: int, new_date: date, today: date) -> dict:
    if new_date < today:
        raise TaskMovePastDateError

    now = datetime.now(UTC).isoformat()

    await db.execute("BEGIN IMMEDIATE")
    try:
        async with db.execute(
            """
            SELECT
                t.id,
                t.resource_id,
                t.scheduled_date,
                t.completed_at,
                r.type AS resource_type,
                r.status AS resource_status,
                u.order_index AS unit_order_index
            FROM tasks t
            JOIN resources r ON r.id = t.resource_id
            LEFT JOIN units u ON u.id = t.unit_id
            WHERE t.id = ?
            """,
            (task_id,),
        ) as cursor:
            selected = await cursor.fetchone()

        if not selected:
            await db.rollback()
            raise TaskNotFoundError
        if (
            selected["resource_type"] != "study_project"
            or selected["resource_status"] != "active"
            or selected["completed_at"] is not None
        ):
            await db.rollback()
            raise TaskMoveNotAllowedError

        original_date = date.fromisoformat(selected["scheduled_date"][:10])
        delta = (new_date - original_date).days

        async with db.execute(
            """
            SELECT
                t.id,
                t.resource_id,
                t.scheduled_date,
                u.order_index AS unit_order_index
            FROM tasks t
            LEFT JOIN units u ON u.id = t.unit_id
            WHERE t.resource_id = ?
              AND t.completed_at IS NULL
            """,
            (selected["resource_id"],),
        ) as cursor:
            same_project_unfinished = await cursor.fetchall()

        def project_order_key(task: aiosqlite.Row) -> tuple[int, int, str, int]:
            unit_order = task["unit_order_index"]
            if unit_order is not None:
                return (0, int(unit_order), task["scheduled_date"], int(task["id"]))
            return (1, 0, task["scheduled_date"], int(task["id"]))

        ordered_tasks = sorted(same_project_unfinished, key=project_order_key)
        selected_index = next(
            index for index, task in enumerate(ordered_tasks) if int(task["id"]) == task_id
        )
        affected_tasks = ordered_tasks[selected_index:]

        changes = []
        for task in affected_tasks:
            old_date = date.fromisoformat(task["scheduled_date"][:10])
            shifted_date = old_date + timedelta(days=delta)
            changes.append(
                {
                    "task_id": int(task["id"]),
                    "project_id": int(task["resource_id"]),
                    "old_date": task["scheduled_date"],
                    "new_date": shifted_date.isoformat(),
                }
            )

        if any(date.fromisoformat(change["new_date"]) < today for change in changes):
            raise TaskMovePastDateError

        for change in changes:
            await db.execute(
                """
                UPDATE tasks
                SET scheduled_date = ?,
                    auto_roll_days = 0,
                    last_auto_rolled_at = NULL,
                    user_adjusted_at = ?
                WHERE id = ?
                  AND completed_at IS NULL
                """,
                (change["new_date"], now, change["task_id"]),
            )

        event_changes = [
            {
                "task_id": change["task_id"],
                "project_id": change["project_id"],
                "original_date": change["old_date"],
                "new_date": change["new_date"],
            }
            for change in changes
        ]
        await db.execute(
            "INSERT INTO events (event_type, payload) VALUES (?, ?)",
            (
                "study_task_moved",
                json.dumps(
                    {
                        "task_id": task_id,
                        "resource_id": int(selected["resource_id"]),
                        "affected_task_ids": [change["task_id"] for change in changes],
                        "changes": event_changes,
                        "source": "manual_move",
                    }
                ),
            ),
        )
        await db.commit()
    except Exception:
        await db.rollback()
        raise

    return {
        "task_id": task_id,
        "source": "manual_move",
        "affected_count": len(changes),
        "changes": changes,
    }


async def preview_active_study_project_shift(
    db: aiosqlite.Connection,
    project_id: int,
    delta_days: int,
    today: date | None = None,
) -> dict:
    async with db.execute(
        """
        SELECT id, type, status, deadline
        FROM resources
        WHERE id = ?
        """,
        (project_id,),
    ) as cursor:
        project = await cursor.fetchone()

    if not project or project["type"] != "study_project" or project["status"] != "active":
        return {
            "status": "unsupported",
            "mutates": False,
            "message": "project is not an active study project",
        }

    async with db.execute(
        """
        SELECT
            t.id,
            t.resource_id,
            t.scheduled_date,
            u.order_index AS unit_order_index
        FROM tasks t
        LEFT JOIN units u ON u.id = t.unit_id
        WHERE t.resource_id = ?
          AND t.completed_at IS NULL
        """,
        (project_id,),
    ) as cursor:
        unfinished_tasks = await cursor.fetchall()

    def project_order_key(task: aiosqlite.Row) -> tuple[int, int, str, int]:
        unit_order = task["unit_order_index"]
        if unit_order is not None:
            return (0, int(unit_order), task["scheduled_date"], int(task["id"]))
        return (1, 0, task["scheduled_date"], int(task["id"]))

    ordered_tasks = sorted(unfinished_tasks, key=project_order_key)
    changes = []
    for task in ordered_tasks:
        old_date = date.fromisoformat(task["scheduled_date"][:10])
        changes.append(
            {
                "task_id": int(task["id"]),
                "project_id": int(task["resource_id"]),
                "old_date": old_date.isoformat(),
                "new_date": (old_date + timedelta(days=delta_days)).isoformat(),
            }
        )

    effective_today = today or date.today()
    if any(date.fromisoformat(change["new_date"]) < effective_today for change in changes):
        return {
            "status": "unsupported",
            "mutates": False,
            "message": "preview would move a task before today",
        }

    deadline = project["deadline"]
    before_expected_late = False
    after_expected_late = False
    if deadline:
        deadline_date = date.fromisoformat(deadline[:10])
        before_expected_late = any(
            date.fromisoformat(change["old_date"]) > deadline_date for change in changes
        )
        after_expected_late = any(
            date.fromisoformat(change["new_date"]) > deadline_date for change in changes
        )

    over_capacity_impact = await _preview_over_capacity_impact(db, changes)

    return {
        "status": "preview",
        "source": "dialogue_preview",
        "command": "project_shift",
        "project_id": project_id,
        "delta_days": delta_days,
        "affected_task_ids": [change["task_id"] for change in changes],
        "changes": changes,
        "red_state_impact": {
            "expected_late": {
                "before": before_expected_late,
                "after": after_expected_late,
            },
            "over_capacity": over_capacity_impact,
        },
        "mutates": False,
    }


async def _preview_over_capacity_impact(
    db: aiosqlite.Connection,
    changes: list[dict[str, Any]],
) -> dict:
    if not changes:
        return {
            "before_dates": [],
            "after_dates": [],
            "new_over_capacity_dates": [],
        }

    changed_dates = sorted(
        {change["old_date"] for change in changes} | {change["new_date"] for change in changes}
    )
    changed_task_dates = {change["task_id"]: change["new_date"] for change in changes}
    placeholders = ",".join("?" for _ in changed_dates)
    async with db.execute(
        f"""
        SELECT
            t.id,
            t.scheduled_date,
            COALESCE(t.target_minutes, 0) AS target_minutes
        FROM tasks t
        JOIN resources r ON r.id = t.resource_id
        WHERE r.status = 'active'
          AND r.type = 'study_project'
          AND (
              t.scheduled_date IN ({placeholders})
              OR t.id IN ({",".join("?" for _ in changed_task_dates)})
          )
        """,
        (*changed_dates, *changed_task_dates.keys()),
    ) as cursor:
        tasks = await cursor.fetchall()

    daily_capacity_minutes = _parse_daily_capacity_minutes(await get_system_state(db, "daily_capacity_min"))
    rest_day_settings = await get_study_rest_day_settings(db)
    rest_weekdays = set(rest_day_settings["weekly_weekdays"])
    rest_dates = set(rest_day_settings["one_off_dates"])

    before_loads = {day: 0 for day in changed_dates}
    after_loads = {day: 0 for day in changed_dates}
    for task in tasks:
        before_date = task["scheduled_date"][:10]
        target_minutes = int(task["target_minutes"] or 0)
        if before_date in before_loads:
            before_loads[before_date] += target_minutes

        after_date = changed_task_dates.get(int(task["id"]), before_date)
        if after_date in after_loads:
            after_loads[after_date] += target_minutes

    def over_capacity_dates(loads: dict[str, int]) -> list[str]:
        over_dates = []
        for day, total_minutes in sorted(loads.items()):
            current = date.fromisoformat(day)
            capacity = 0 if current.weekday() in rest_weekdays or day in rest_dates else daily_capacity_minutes
            if total_minutes > capacity:
                over_dates.append(day)
        return over_dates

    before_dates = over_capacity_dates(before_loads)
    after_dates = over_capacity_dates(after_loads)
    return {
        "before_dates": before_dates,
        "after_dates": after_dates,
        "new_over_capacity_dates": sorted(set(after_dates) - set(before_dates)),
    }


async def update_active_study_project_deadline(
    db: aiosqlite.Connection,
    project_id: int,
    new_deadline: date,
) -> dict:
    new_deadline_iso = new_deadline.isoformat()

    await db.execute("BEGIN IMMEDIATE")
    try:
        async with db.execute(
            """
            SELECT id, type, status, deadline
            FROM resources
            WHERE id = ?
            """,
            (project_id,),
        ) as cursor:
            project = await cursor.fetchone()

        if not project:
            await db.rollback()
            raise ResourceNotFoundError
        if project["type"] != "study_project" or project["status"] != "active":
            await db.rollback()
            raise ResourceDeadlineEditNotAllowedError

        old_deadline = project["deadline"]
        await db.execute(
            "UPDATE resources SET deadline = ? WHERE id = ?",
            (new_deadline_iso, project_id),
        )
        payload = {
            "project_id": project_id,
            "old_deadline": old_deadline,
            "new_deadline": new_deadline_iso,
            "source": "deadline_edit",
        }
        await db.execute(
            "INSERT INTO events (event_type, payload) VALUES (?, ?)",
            ("study_project_deadline_updated", json.dumps(payload)),
        )
        await db.commit()
    except Exception:
        await db.rollback()
        raise

    return payload


async def insert_active_study_project_task(
    db: aiosqlite.Connection,
    project_id: int,
    title: str,
    target_minutes: int,
    scheduled_date: date,
) -> dict:
    scheduled_date_iso = scheduled_date.isoformat()
    normalized_title = title.strip()

    await db.execute("BEGIN IMMEDIATE")
    try:
        async with db.execute(
            """
            SELECT id, type, status
            FROM resources
            WHERE id = ?
            """,
            (project_id,),
        ) as cursor:
            project = await cursor.fetchone()

        if not project:
            await db.rollback()
            raise ResourceNotFoundError
        if project["type"] != "study_project" or project["status"] != "active":
            await db.rollback()
            raise ResourceTaskInsertNotAllowedError

        async with db.execute(
            """
            SELECT MIN(u.order_index) AS insertion_order
            FROM tasks t
            JOIN units u ON u.id = t.unit_id
            WHERE t.resource_id = ?
              AND t.completed_at IS NULL
              AND date(t.scheduled_date) > date(?)
            """,
            (project_id, scheduled_date_iso),
        ) as cursor:
            insertion_row = await cursor.fetchone()

        insertion_order = insertion_row["insertion_order"] if insertion_row else None
        if insertion_order is None:
            async with db.execute(
                """
                SELECT COALESCE(MAX(order_index), 0) + 1 AS next_order
                FROM units
                WHERE resource_id = ?
                """,
                (project_id,),
            ) as cursor:
                next_order_row = await cursor.fetchone()
            insertion_order = int(next_order_row["next_order"])
        else:
            insertion_order = int(insertion_order)
            await db.execute(
                """
                UPDATE units
                SET order_index = order_index + 1
                WHERE resource_id = ?
                  AND order_index >= ?
                """,
                (project_id, insertion_order),
            )

        unit_cursor = await db.execute(
            """
            INSERT INTO units
                (resource_id, title, order_index, estimated_minutes, status)
            VALUES (?, ?, ?, ?, 'pending')
            """,
            (project_id, normalized_title, insertion_order, target_minutes),
        )
        unit_id = int(unit_cursor.lastrowid)

        cursor = await db.execute(
            """
            INSERT INTO tasks
                (
                    unit_id,
                    resource_id,
                    title,
                    task_kind,
                    target_minutes,
                    scheduled_date,
                    originally_scheduled_date,
                    completed_at
                )
            VALUES (?, ?, ?, 'time', ?, ?, ?, NULL)
            """,
            (
                unit_id,
                project_id,
                normalized_title,
                target_minutes,
                scheduled_date_iso,
                scheduled_date_iso,
            ),
        )
        task_id = int(cursor.lastrowid)
        payload = {
            "project_id": project_id,
            "task_id": task_id,
            "scheduled_date": scheduled_date_iso,
            "target_minutes": target_minutes,
            "title": normalized_title,
            "source": "manual_insert",
        }
        await db.execute(
            "INSERT INTO events (event_type, payload) VALUES (?, ?)",
            ("study_task_inserted", json.dumps(payload)),
        )
        await db.commit()
    except Exception:
        await db.rollback()
        raise

    return payload


async def delete_active_study_task(db: aiosqlite.Connection, task_id: int) -> dict:
    await db.execute("BEGIN IMMEDIATE")
    try:
        async with db.execute(
            """
            SELECT
                t.id,
                t.unit_id,
                t.resource_id,
                t.title,
                t.target_minutes,
                t.scheduled_date,
                t.completed_at,
                r.type AS resource_type,
                r.status AS resource_status
            FROM tasks t
            JOIN resources r ON r.id = t.resource_id
            WHERE t.id = ?
            """,
            (task_id,),
        ) as cursor:
            task = await cursor.fetchone()

        if not task:
            await db.rollback()
            raise TaskNotFoundError
        if (
            task["resource_type"] != "study_project"
            or task["resource_status"] != "active"
            or task["completed_at"] is not None
        ):
            await db.rollback()
            raise TaskDeleteNotAllowedError

        project_id = int(task["resource_id"])
        unit_id = int(task["unit_id"]) if task["unit_id"] is not None else None
        today = date.today().isoformat()
        payload = {
            "project_id": project_id,
            "task_id": task_id,
            "scheduled_date": task["scheduled_date"],
            "target_minutes": task["target_minutes"],
            "title": task["title"],
            "source": "manual_delete",
            "project_completed": False,
        }

        cursor = await db.execute(
            """
            DELETE FROM tasks
            WHERE id = ?
              AND completed_at IS NULL
            """,
            (task_id,),
        )
        if cursor.rowcount != 1:
            await db.rollback()
            raise TaskDeleteNotAllowedError

        if unit_id is not None:
            await db.execute(
                """
                DELETE FROM units
                WHERE id = ?
                  AND resource_id = ?
                  AND status != 'completed'
                  AND completed_at IS NULL
                  AND NOT EXISTS (
                      SELECT 1 FROM tasks WHERE unit_id = ?
                  )
                """,
                (unit_id, project_id, unit_id),
            )

        async with db.execute(
            """
            SELECT
                COUNT(*) AS total_units,
                SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_units
            FROM units
            WHERE resource_id = ?
            """,
            (project_id,),
        ) as cursor:
            unit_counts = await cursor.fetchone()

        total_units = int(unit_counts["total_units"] or 0)
        completed_units = int(unit_counts["completed_units"] or 0)
        await db.execute(
            """
            UPDATE resources
            SET total_units = ?,
                completed_units = ?
            WHERE id = ?
            """,
            (total_units, completed_units, project_id),
        )

        async with db.execute(
            """
            SELECT COUNT(*) AS unfinished_count
            FROM tasks
            WHERE resource_id = ?
              AND completed_at IS NULL
            """,
            (project_id,),
        ) as cursor:
            row = await cursor.fetchone()

        if int(row["unfinished_count"] or 0) == 0:
            complete_cursor = await db.execute(
                """
                UPDATE resources
                SET status = 'completed'
                WHERE id = ?
                  AND status = 'active'
                """,
                (project_id,),
            )
            if complete_cursor.rowcount == 1:
                payload["project_completed"] = True

        await db.execute(
            "INSERT INTO events (event_type, payload) VALUES (?, ?)",
            ("study_task_deleted", json.dumps(payload)),
        )
        await db.execute("DELETE FROM system_state WHERE key = ?", (f"briefing_{today}",))
        if payload["project_completed"]:
            await db.execute(
                "INSERT INTO events (event_type, payload) VALUES (?, ?)",
                (
                    "resource_completed",
                    json.dumps({"resource_id": project_id, "source": "manual_delete"}),
                ),
            )
        await db.commit()
    except Exception:
        await db.rollback()
        raise

    return {
        "project_id": payload["project_id"],
        "task_id": payload["task_id"],
        "scheduled_date": payload["scheduled_date"],
        "source": payload["source"],
        "project_completed": payload["project_completed"],
    }


async def mark_active_resource_complete(
    db: aiosqlite.Connection,
    resource_id: int,
    source: str = "user_action",
) -> dict:
    now = datetime.now(UTC).isoformat()
    today = date.today().isoformat()

    await db.execute("BEGIN IMMEDIATE")
    try:
        cursor = await db.execute(
            """
            UPDATE resources
            SET status = 'completed',
                completed_units = CASE
                    WHEN COALESCE(completed_units, 0) > COALESCE(total_units, 0)
                    THEN completed_units
                    ELSE COALESCE(total_units, 0)
                END
            WHERE id = ? AND status = 'active'
            """,
            (resource_id,),
        )
        if cursor.rowcount != 1:
            async with db.execute(
                "SELECT status FROM resources WHERE id = ?",
                (resource_id,),
            ) as status_cursor:
                row = await status_cursor.fetchone()
            await db.rollback()
            if not row:
                raise ResourceNotFoundError
            raise ResourceNotActiveError

        await db.execute(
            """
            UPDATE units
            SET status = 'completed', completed_at = COALESCE(completed_at, ?)
            WHERE resource_id = ? AND status != 'completed'
            """,
            (now, resource_id),
        )
        await db.execute(
            """
            UPDATE tasks
            SET completed_at = ?
            WHERE resource_id = ?
              AND scheduled_date >= ?
              AND completed_at IS NULL
            """,
            (now, resource_id, today),
        )
        await db.execute(
            "INSERT INTO events (event_type, payload) VALUES (?, ?)",
            (
                "resource_completed",
                json.dumps({"resource_id": resource_id, "source": source}),
            ),
        )
        await db.execute("DELETE FROM system_state WHERE key = ?", (f"briefing_{today}",))
        await db.commit()
    except Exception:
        await db.rollback()
        raise

    return await get_resource_progress(db, resource_id)


async def archive_active_resource(
    db: aiosqlite.Connection,
    resource_id: int,
    source: str = "user_action",
) -> dict:
    today = date.today().isoformat()

    await db.execute("BEGIN IMMEDIATE")
    try:
        cursor = await db.execute(
            "UPDATE resources SET status = 'archived' WHERE id = ? AND status = 'active'",
            (resource_id,),
        )
        if cursor.rowcount != 1:
            async with db.execute(
                "SELECT status FROM resources WHERE id = ?",
                (resource_id,),
            ) as status_cursor:
                row = await status_cursor.fetchone()
            await db.rollback()
            if not row:
                raise ResourceNotFoundError
            raise ResourceNotActiveError

        await db.execute(
            """
            DELETE FROM tasks
            WHERE resource_id = ?
              AND scheduled_date >= ?
              AND completed_at IS NULL
            """,
            (resource_id, today),
        )
        await db.execute(
            "INSERT INTO events (event_type, payload) VALUES (?, ?)",
            (
                "resource_archived",
                json.dumps({"resource_id": resource_id, "source": source}),
            ),
        )
        await db.execute("DELETE FROM system_state WHERE key = ?", (f"briefing_{today}",))
        await db.commit()
    except Exception:
        await db.rollback()
        raise

    return await get_resource_progress(db, resource_id)


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
    target_iso = target_sunday.isoformat()
    async with db.execute(
        "SELECT payload, created_at FROM events WHERE event_type = 'weekly_review_done'",
    ) as cursor:
        rows = await cursor.fetchall()

    for payload_raw, created_at in rows:
        if isinstance(created_at, str) and created_at[:10] == target_iso:
            return True
        if not payload_raw:
            continue
        try:
            payload = json.loads(payload_raw)
        except json.JSONDecodeError:
            continue
        week = payload.get("week")
        if week == target_iso or (isinstance(week, str) and target_iso in week.split("/")):
            return True
    return False


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
    now = datetime.now(UTC).isoformat()

    await db.execute("BEGIN IMMEDIATE")
    try:
        async with db.execute(
            """
            SELECT unit_id, resource_id, target_minutes, completed_at
            FROM tasks
            WHERE id = ?
            """,
            (task_id,),
        ) as cur:
            task = await cur.fetchone()

        if not task:
            raise TaskNotFoundError

        unit_id, resource_id, target_minutes, completed_at = task
        if completed_at is not None:
            await db.execute(
                """
                UPDATE tasks
                SET auto_roll_days = 0,
                    last_auto_rolled_at = NULL
                WHERE id = ?
                """,
                (task_id,),
            )
            await db.commit()
            return {"task_id": task_id, "completed_at": completed_at}

        minutes = actual_minutes if actual_minutes is not None else (target_minutes or 0)
        unit_already_completed = False
        if unit_id:
            async with db.execute("SELECT status FROM units WHERE id = ?", (unit_id,)) as cur:
                unit = await cur.fetchone()
            unit_already_completed = bool(unit and unit[0] == "completed")

        await db.execute(
            """
            UPDATE tasks
            SET completed_at = ?,
                actual_minutes = ?,
                auto_roll_days = 0,
                last_auto_rolled_at = NULL
            WHERE id = ?
            """,
            (now, minutes, task_id),
        )
        if unit_id:
            await db.execute(
                """
                UPDATE units
                SET status = 'completed',
                    completed_at = COALESCE(completed_at, ?),
                    actual_minutes = COALESCE(actual_minutes, ?)
                WHERE id = ?
                """,
                (now, minutes, unit_id),
            )
        if resource_id:
            completed_unit_delta = 0 if unit_id and unit_already_completed else 1
            await db.execute(
                """
                UPDATE resources
                SET completed_units = COALESCE(completed_units, 0) + ?,
                    actual_minutes_total = COALESCE(actual_minutes_total, 0) + ?
                WHERE id = ?
                """,
                (completed_unit_delta, minutes, resource_id),
            )

        await db.execute(
            "INSERT INTO events (event_type, payload) VALUES (?, ?)",
            ("task_completed", json.dumps({"task_id": task_id})),
        )
        if resource_id:
            async with db.execute(
                """
                SELECT
                    r.type,
                    r.status,
                    COUNT(t.id) AS task_count,
                    SUM(CASE WHEN t.completed_at IS NULL THEN 1 ELSE 0 END) AS unfinished_count
                FROM resources r
                LEFT JOIN tasks t ON t.resource_id = r.id
                WHERE r.id = ?
                GROUP BY r.id
                """,
                (resource_id,),
            ) as cur:
                resource_progress = await cur.fetchone()

            if (
                resource_progress
                and resource_progress[0] == "study_project"
                and resource_progress[1] == "active"
                and (resource_progress[2] or 0) > 0
                and (resource_progress[3] or 0) == 0
            ):
                cursor = await db.execute(
                    "UPDATE resources SET status = 'completed' WHERE id = ? AND status = 'active'",
                    (resource_id,),
                )
                if cursor.rowcount == 1:
                    await db.execute(
                        "INSERT INTO events (event_type, payload) VALUES (?, ?)",
                        (
                            "resource_completed",
                            json.dumps({"resource_id": resource_id, "source": "task_completion"}),
                        ),
                    )
        await db.commit()
    except Exception:
        await db.rollback()
        raise

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
