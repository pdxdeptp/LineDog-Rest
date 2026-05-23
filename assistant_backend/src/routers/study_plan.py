"""HTTP surface for the study-plan draft flow."""

from __future__ import annotations

import json
import re
from datetime import date
from typing import Any
from urllib.parse import urlparse

import aiosqlite
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from ..db.connection import get_db
from ..study_plan.clarification import (
    build_guided_clarification,
    build_skip_clarification_response,
)
from ..study_plan.decomposition import build_decomposition_pipeline
from ..study_plan.lifecycle import (
    cancel_draft_study_project,
    confirm_draft_study_project,
)
from ..study_plan.scheduling import plan_initial_draft_schedule

router = APIRouter()


class StartStudyPlanRequest(BaseModel):
    url: str = Field(min_length=1)
    deadline: date
    capacity_minutes: int = Field(gt=0)


class ClarificationSubmission(BaseModel):
    answers: dict[str, str] = Field(default_factory=dict)
    clarification_skipped: bool = False


class DurationUpdateRequest(BaseModel):
    estimated_minutes: int = Field(gt=0)


def _json_safe(value: Any) -> Any:
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, list):
        return [_json_safe(item) for item in value]
    if isinstance(value, dict):
        return {key: _json_safe(item) for key, item in value.items()}
    return value


def _title_from_url(url: str) -> str:
    parsed = urlparse(url)
    candidate = parsed.path.strip("/").split("/")[-1] or parsed.netloc or url
    title = re.sub(r"[-_]+", " ", candidate).strip()
    return title.title() if title else "Study Material"


def _source_preview(url: str) -> dict[str, Any]:
    title = _title_from_url(url)
    return {
        "title": title,
        "url": url,
        "material_type": "article",
        "suggested_focus": f"{title} essentials",
        "units": [
            {
                "title": f"Review {title} overview",
                "order_index": 0,
                "estimated_minutes": 45,
            },
            {
                "title": f"Practice {title} application",
                "order_index": 1,
                "estimated_minutes": 45,
            },
        ],
    }


def _decode_metadata(raw: str | None) -> dict[str, Any]:
    if not raw:
        return {}
    try:
        value = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return value if isinstance(value, dict) else {}


async def _fetch_draft(db: aiosqlite.Connection, draft_id: int) -> dict[str, Any]:
    async with db.execute(
        """
        SELECT id, title, source_url, deadline, status, capacity_minutes,
               clarification_skipped, metadata
        FROM study_project_drafts
        WHERE id = ?
        """,
        (draft_id,),
    ) as cursor:
        row = await cursor.fetchone()

    if row is None:
        raise HTTPException(status_code=404, detail="Study plan draft not found")

    draft = dict(row)
    draft["clarification_skipped"] = bool(draft["clarification_skipped"])
    draft["metadata"] = _decode_metadata(draft.get("metadata"))

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


def _draft_response(draft: dict[str, Any]) -> dict[str, Any]:
    metadata = draft.get("metadata") or {}
    return {
        "id": draft["id"],
        "title": draft["title"],
        "source_url": draft["source_url"],
        "deadline": draft["deadline"],
        "status": draft["status"],
        "capacity_minutes": draft["capacity_minutes"],
        "clarification_skipped": draft["clarification_skipped"],
        "low_calibration": bool(metadata.get("low_calibration", False)),
        "tasks": draft["tasks"],
        "expected_late": bool(metadata.get("expected_late", False)),
        "over_capacity_days": metadata.get("over_capacity_days") or [],
    }


def _ensure_review(draft: dict[str, Any]) -> None:
    if draft["status"] != "review":
        raise HTTPException(status_code=409, detail="Study plan draft is not in review")


def _clarification_payload(
    body: ClarificationSubmission,
    clarification: dict[str, Any],
) -> dict[str, Any]:
    if body.clarification_skipped:
        payload = build_skip_clarification_response(clarification)
        if body.answers:
            payload["answers"].update(body.answers)
        return payload

    return {
        "answers": body.answers,
        "defaults": dict(clarification.get("defaults") or {}),
        "clarification_skipped": False,
        "low_calibration": False,
    }


def _schedule_metadata(
    metadata: dict[str, Any],
    *,
    clarification: dict[str, Any],
    expected_late: bool,
    over_capacity_days: list[dict[str, Any]],
) -> dict[str, Any]:
    updated = dict(metadata)
    updated["clarification_response"] = _json_safe(clarification)
    updated["low_calibration"] = bool(clarification.get("low_calibration", False))
    updated["expected_late"] = expected_late
    updated["over_capacity_days"] = _json_safe(over_capacity_days)
    return updated


async def _replace_draft_tasks(
    db: aiosqlite.Connection,
    draft_id: int,
    tasks: list[dict[str, Any]],
) -> None:
    await db.execute("DELETE FROM study_project_draft_tasks WHERE draft_id = ?", (draft_id,))
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
                task["order_index"],
                task["estimated_minutes"],
                _json_safe(task["scheduled_date"]),
                task["target_minutes"],
            )
            for task in tasks
        ],
    )


async def _active_existing_daily_minutes(
    db: aiosqlite.Connection,
) -> dict[str, int]:
    async with db.execute(
        """
        SELECT t.scheduled_date, COALESCE(SUM(COALESCE(t.target_minutes, 0)), 0) AS minutes
        FROM tasks t
        JOIN resources r ON r.id = t.resource_id
        WHERE r.status = 'active'
          AND t.completed_at IS NULL
        GROUP BY t.scheduled_date
        """
    ) as cursor:
        rows = await cursor.fetchall()

    return {row["scheduled_date"]: int(row["minutes"]) for row in rows}


async def _ensure_review_for_write(db: aiosqlite.Connection, draft_id: int) -> None:
    async with db.execute(
        "SELECT status FROM study_project_drafts WHERE id = ?",
        (draft_id,),
    ) as cursor:
        row = await cursor.fetchone()

    if row is None:
        raise HTTPException(status_code=404, detail="Study plan draft not found")
    if row["status"] != "review":
        raise HTTPException(status_code=409, detail="Study plan draft is not in review")


async def _create_review_shell(
    db: aiosqlite.Connection,
    *,
    source: dict[str, Any],
    deadline: date,
    capacity_minutes: int,
    clarification: dict[str, Any],
) -> int:
    metadata = {
        "source": source,
        "clarification": clarification,
        "expected_late": False,
        "over_capacity_days": [],
        "low_calibration": False,
    }
    cursor = await db.execute(
        """
        INSERT INTO study_project_drafts
            (title, source_url, deadline, status, capacity_minutes,
             clarification_skipped, metadata)
        VALUES (?, ?, ?, 'review', ?, 0, ?)
        """,
        (
            source["title"],
            source["url"],
            deadline.isoformat(),
            capacity_minutes,
            json.dumps(_json_safe(metadata)),
        ),
    )
    await db.commit()
    return int(cursor.lastrowid)


async def _persist_clarification_result(
    db: aiosqlite.Connection,
    draft: dict[str, Any],
    clarification_response: dict[str, Any],
    pipeline: dict[str, Any],
) -> dict[str, Any]:
    metadata = _schedule_metadata(
        draft["metadata"],
        clarification=clarification_response,
        expected_late=bool(pipeline["expected_late"]),
        over_capacity_days=pipeline["over_capacity_days"],
    )
    try:
        await db.execute("BEGIN IMMEDIATE")
        await _ensure_review_for_write(db, draft["id"])
        await _replace_draft_tasks(db, draft["id"], pipeline["draft_tasks"])
        cursor = await db.execute(
            """
            UPDATE study_project_drafts
            SET clarification_skipped = ?, metadata = ?
            WHERE id = ? AND status = 'review'
            """,
            (
                int(clarification_response.get("clarification_skipped", False)),
                json.dumps(_json_safe(metadata)),
                draft["id"],
            ),
        )
        if cursor.rowcount != 1:
            raise HTTPException(status_code=409, detail="Study plan draft is not in review")
        await db.commit()
    except Exception:
        await db.rollback()
        raise
    return await _fetch_draft(db, draft["id"])


async def _reschedule_draft_tasks(
    db: aiosqlite.Connection,
    draft: dict[str, Any],
) -> dict[str, Any]:
    schedule = plan_initial_draft_schedule(
        [
            {
                "title": task["title"],
                "estimated_minutes": task["estimated_minutes"],
            }
            for task in draft["tasks"]
        ],
        start_date=date.today(),
        deadline=draft["deadline"],
        daily_capacity_minutes=draft["capacity_minutes"],
        existing_daily_minutes=await _active_existing_daily_minutes(db),
    )
    metadata = dict(draft["metadata"])
    metadata["expected_late"] = schedule["expected_late"]
    metadata["over_capacity_days"] = _json_safe(schedule["over_capacity_days"])

    try:
        await db.execute("BEGIN IMMEDIATE")
        await _ensure_review_for_write(db, draft["id"])
        await _replace_draft_tasks(db, draft["id"], schedule["scheduled_tasks"])
        cursor = await db.execute(
            "UPDATE study_project_drafts SET metadata = ? WHERE id = ? AND status = 'review'",
            (json.dumps(_json_safe(metadata)), draft["id"]),
        )
        if cursor.rowcount != 1:
            raise HTTPException(status_code=409, detail="Study plan draft is not in review")
        await db.commit()
    except Exception:
        await db.rollback()
        raise
    return await _fetch_draft(db, draft["id"])


@router.post("/study-plan/start")
async def start_study_plan(body: StartStudyPlanRequest) -> dict[str, Any]:
    source = _source_preview(body.url.strip())
    clarification = build_guided_clarification(source)
    async with get_db() as db:
        draft_id = await _create_review_shell(
            db,
            source=source,
            deadline=body.deadline,
            capacity_minutes=body.capacity_minutes,
            clarification=clarification,
        )
    return {"draft_id": draft_id, "clarification": clarification}


@router.post("/study-plan/drafts/{draft_id}/clarification")
async def submit_clarification(
    draft_id: int,
    body: ClarificationSubmission,
) -> dict[str, Any]:
    async with get_db() as db:
        draft = await _fetch_draft(db, draft_id)
        _ensure_review(draft)

        metadata = draft["metadata"]
        clarification = metadata.get("clarification") or {}
        source = metadata.get("source") or _source_preview(draft["source_url"])
        clarification_response = _clarification_payload(body, clarification)
        pipeline = build_decomposition_pipeline(
            source,
            clarification_response,
            start_date=date.today(),
            deadline=draft["deadline"],
            daily_capacity_minutes=draft["capacity_minutes"],
            existing_daily_minutes=await _active_existing_daily_minutes(db),
        )
        if pipeline["status"] != "draft_ready":
            raise HTTPException(
                status_code=422,
                detail=pipeline.get("message", "Could not generate study plan draft"),
            )

        updated = await _persist_clarification_result(
            db,
            draft,
            clarification_response,
            pipeline,
        )
    return _draft_response(updated)


@router.put("/study-plan/drafts/{draft_id}/tasks/{order_index}/duration")
async def update_task_duration(
    draft_id: int,
    order_index: int,
    body: DurationUpdateRequest,
) -> dict[str, Any]:
    async with get_db() as db:
        draft = await _fetch_draft(db, draft_id)
        _ensure_review(draft)
        if not any(task["order_index"] == order_index for task in draft["tasks"]):
            raise HTTPException(status_code=404, detail="Study plan draft task not found")

        for task in draft["tasks"]:
            if task["order_index"] == order_index:
                task["estimated_minutes"] = body.estimated_minutes

        updated = await _reschedule_draft_tasks(db, draft)
    return _draft_response(updated)


@router.post("/study-plan/drafts/{draft_id}/cancel")
async def cancel_draft(draft_id: int) -> dict[str, Any]:
    async with get_db() as db:
        try:
            await cancel_draft_study_project(db, draft_id)
        except ValueError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc
        draft = await _fetch_draft(db, draft_id)
    return _draft_response(draft)


@router.post("/study-plan/drafts/{draft_id}/confirm")
async def confirm_draft(draft_id: int) -> dict[str, Any]:
    async with get_db() as db:
        draft = await _fetch_draft(db, draft_id)
        _ensure_review(draft)
        if not draft["tasks"]:
            raise HTTPException(status_code=409, detail="Study plan draft has no tasks")
        try:
            return await confirm_draft_study_project(db, draft_id)
        except ValueError as exc:
            raise HTTPException(status_code=409, detail=str(exc)) from exc
