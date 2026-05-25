"""Minimal draft study project lifecycle persistence."""

import json
from datetime import date
from typing import Any

import aiosqlite


def _iso(value: date | str) -> str:
    return value.isoformat() if isinstance(value, date) else value


async def _fetch_draft(db: aiosqlite.Connection, draft_id: int) -> dict[str, Any]:
    async with db.execute(
        """
        SELECT id, intake_item_id, title, source_url, deadline, status,
               schema_version, draft_version, latest_version, calibration_level,
               draft_kind, target_plan_id, capacity_minutes, clarification_skipped,
               activated_resource_id
        FROM study_project_drafts
        WHERE id = ?
        """,
        (draft_id,),
    ) as cursor:
        row = await cursor.fetchone()
    if not row:
        raise ValueError(f"Study project draft not found: {draft_id}")

    draft = dict(row)
    draft["clarification_skipped"] = bool(draft["clarification_skipped"])

    async with db.execute(
        """
        SELECT title, order_index, estimated_minutes, scheduled_date, target_minutes
        FROM study_project_draft_tasks
        WHERE draft_id = ?
        ORDER BY order_index ASC
        """,
        (draft_id,),
    ) as cursor:
        rows = await cursor.fetchall()
    draft["tasks"] = [dict(task) for task in rows]
    return draft


async def create_draft_study_project(
    db: aiosqlite.Connection,
    *,
    title: str,
    source_url: str,
    deadline: date | str,
    capacity_minutes: int,
    clarification_skipped: bool,
    tasks: list[dict[str, Any]],
    intake_item_id: int | None = None,
    draft_kind: str = "new_plan",
    target_plan_id: int | None = None,
    calibration_level: str = "standard",
) -> dict[str, Any]:
    await db.execute("BEGIN IMMEDIATE")
    try:
        if intake_item_id is not None:
            async with db.execute(
                """
                SELECT id
                FROM study_project_drafts
                WHERE intake_item_id = ?
                  AND draft_kind = ?
                  AND status IN (
                      'review', 'draft_review', 'anchor_review', 'compiling',
                      'needs_input', 'compile_failed', 'infeasible_review', 'activating'
                  )
                ORDER BY id ASC
                LIMIT 1
                """,
                (intake_item_id, draft_kind),
            ) as cursor:
                existing = await cursor.fetchone()
            if existing is not None:
                await db.commit()
                return await _fetch_draft(db, int(existing["id"]))

        metadata = {
            "intake_item_id": intake_item_id,
            "source_url": source_url,
            "deadline": _iso(deadline),
            "capacity_minutes": capacity_minutes,
            "clarification_skipped": clarification_skipped,
            "duration_estimates": [task["estimated_minutes"] for task in tasks],
        }
        cursor = await db.execute(
            """
            INSERT INTO study_project_drafts
                (intake_item_id, title, source_url, deadline, status,
                 schema_version, draft_version, latest_version, calibration_level,
                 draft_kind, target_plan_id, capacity_minutes, clarification_skipped,
                 metadata)
            VALUES (?, ?, ?, ?, 'review', 1, 1, 1, ?, ?, ?, ?, ?, ?)
            """,
            (
                intake_item_id,
                title,
                source_url,
                _iso(deadline),
                calibration_level,
                draft_kind,
                target_plan_id,
                capacity_minutes,
                int(clarification_skipped),
                json.dumps(metadata),
            ),
        )
        draft_id = cursor.lastrowid

        await db.executemany(
            """
            INSERT INTO study_project_draft_tasks
                (draft_id, title, order_index, estimated_minutes, scheduled_date, target_minutes)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    draft_id,
                    task["title"],
                    index,
                    task["estimated_minutes"],
                    _iso(task["scheduled_date"]),
                    task["target_minutes"],
                )
                for index, task in enumerate(tasks)
            ],
        )
        await db.commit()
    except Exception:
        await db.rollback()
        raise

    return await _fetch_draft(db, draft_id)


async def cancel_draft_study_project(
    db: aiosqlite.Connection,
    draft_id: int,
) -> dict[str, Any]:
    await db.execute(
        "UPDATE study_project_drafts SET status = 'cancelled' WHERE id = ? AND status = 'review'",
        (draft_id,),
    )
    await db.commit()
    return await _fetch_draft(db, draft_id)


async def confirm_draft_study_project(
    db: aiosqlite.Connection,
    draft_id: int,
) -> dict[str, Any]:
    await db.execute("BEGIN IMMEDIATE")
    try:
        transition = await db.execute(
            """
            UPDATE study_project_drafts
            SET status = 'activating'
            WHERE id = ? AND status = 'review'
            """,
            (draft_id,),
        )
        if transition.rowcount != 1:
            await db.rollback()
            raise ValueError(f"Study project draft is not reviewable: {draft_id}")

        draft = await _fetch_draft(db, draft_id)
        resource_cursor = await db.execute(
            """
            INSERT INTO resources
                (title, type, tracking_mode, url, status, total_units, deadline)
            VALUES (?, 'study_project', 'sequential', ?, 'active', ?, ?)
            """,
            (
                draft["title"],
                draft["source_url"],
                len(draft["tasks"]),
                draft["deadline"],
            ),
        )
        resource_id = resource_cursor.lastrowid

        for task in draft["tasks"]:
            unit_cursor = await db.execute(
                """
                INSERT INTO units
                    (resource_id, title, order_index, estimated_minutes, status)
                VALUES (?, ?, ?, ?, 'pending')
                """,
                (
                    resource_id,
                    task["title"],
                    task["order_index"],
                    task["estimated_minutes"],
                ),
            )
            unit_id = unit_cursor.lastrowid
            await db.execute(
                """
                INSERT INTO tasks
                    (unit_id, resource_id, title, task_kind, target_minutes,
                     scheduled_date, originally_scheduled_date)
                VALUES (?, ?, ?, 'time', ?, ?, ?)
                """,
                (
                    unit_id,
                    resource_id,
                    task["title"],
                    task["target_minutes"],
                    task["scheduled_date"],
                    task["scheduled_date"],
                ),
            )

        await db.execute(
            """
            UPDATE study_project_drafts
            SET status = 'confirmed', activated_resource_id = ?
            WHERE id = ? AND status = 'activating'
            """,
            (resource_id, draft_id),
        )

        payload = {
            "draft_id": draft_id,
            "resource_id": resource_id,
            "source_url": draft["source_url"],
            "deadline": draft["deadline"],
            "capacity_minutes": draft["capacity_minutes"],
            "clarification_skipped": draft["clarification_skipped"],
            "duration_estimates": [task["estimated_minutes"] for task in draft["tasks"]],
        }
        await db.execute(
            "INSERT INTO events (event_type, payload) VALUES (?, ?)",
            ("study_project_activated", json.dumps(payload)),
        )
        await db.commit()
    except Exception:
        await db.rollback()
        raise

    return {
        "id": draft_id,
        "resource_id": resource_id,
        "status": "active",
        "source_url": draft["source_url"],
        "deadline": draft["deadline"],
        "capacity_minutes": draft["capacity_minutes"],
        "clarification_skipped": draft["clarification_skipped"],
    }
