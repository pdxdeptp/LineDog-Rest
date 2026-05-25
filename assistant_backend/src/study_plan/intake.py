"""Persistence and routing helpers for study intake items."""

import json
import re
from datetime import date
from typing import Any
from urllib.parse import urlparse

import aiosqlite

from .lifecycle import create_or_load_draft_shell

UNKNOWN_DRAFT_DEADLINE = "9999-12-31"


def _row_to_dict(row: Any) -> dict:
    return dict(row)


def _json_dumps(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True)


def _metadata_to_db(metadata: dict | None) -> str | None:
    return _json_dumps(metadata) if metadata is not None else None


def _metadata_deadline_value(metadata: dict | None) -> str | None:
    value = (metadata or {}).get("deadline") or (metadata or {}).get("target_deadline")
    if isinstance(value, date):
        return value.isoformat()
    return str(value) if value else None


def _metadata_deadline(metadata: dict | None) -> str:
    return _metadata_deadline_value(metadata) or UNKNOWN_DRAFT_DEADLINE


def _metadata_capacity_minutes(metadata: dict | None) -> int:
    value = (metadata or {}).get("capacity_minutes") or (metadata or {}).get(
        "daily_capacity_min"
    )
    return int(value) if value is not None else 60


def _metadata_assumptions(metadata: dict | None) -> dict[str, Any]:
    assumptions = (metadata or {}).get("assumptions")
    normalized = dict(assumptions) if isinstance(assumptions, dict) else {}
    deadline = _metadata_deadline_value(metadata)
    if "deadline" not in normalized:
        normalized["deadline"] = (
            {
                "value": deadline,
                "provenance": "user_provided",
                "accepted": True,
            }
            if deadline
            else {
                "value": None,
                "provenance": "unknown",
                "accepted": False,
                "needs_input": True,
            }
        )
    if "capacity" not in normalized:
        capacity_provided = (metadata or {}).get("capacity_minutes") is not None or (
            metadata or {}
        ).get("daily_capacity_min") is not None
        normalized["capacity"] = {
            "daily_minutes": _metadata_capacity_minutes(metadata),
            "provenance": "user_provided" if capacity_provided else "system_default",
            "accepted": True,
        }
    return normalized


def _draft_kind_for_attachment_mode(attachment_mode: str) -> str:
    return {
        "draft_phase": "existing_plan_phase",
        "scheduled_work": "existing_plan_scheduled_work",
    }[attachment_mode]


ROLES = {
    "new_plan",
    "attach_to_existing_plan",
    "reference_material",
    "later_resource",
    "immediate_one_off",
}

ATTACHMENT_MODES = {"material_only", "draft_phase", "scheduled_work"}
INTERNAL_REASON_PREFIXES = (
    "existing_plan_candidate:",
    "selected_existing_plan:",
    "canonical_repo_role:",
    "attachment_mode:",
)


def _text_blob(*parts: str | None) -> str:
    return " ".join(part for part in parts if part).lower()


def _contains_any(text: str, terms: tuple[str, ...]) -> bool:
    return any(term in text for term in terms)


def _title_from_input(raw_input: str) -> str:
    parsed = urlparse(raw_input.strip().split()[0])
    if parsed.scheme and parsed.netloc:
        candidate = parsed.path.rstrip("/").split("/")[-1] or parsed.netloc
    else:
        candidate = raw_input.strip().splitlines()[0][:80]
    title = re.sub(r"[-_]+", " ", candidate).strip()
    return title.title() if title else "Study Intake Item"


def _canonical_repo_role(text: str) -> str | None:
    if "github.com" not in text:
        return None
    if _contains_any(text, ("clone", "rebuild", "portfolio project")):
        return "clone_rebuild_target"
    if _contains_any(text, ("attach", "support", "project material")):
        return "project_material"
    if _contains_any(text, ("reference", "docs", "source")):
        return "reference_source"
    if _contains_any(text, ("later", "someday", "backlog")):
        return "later_reading"
    return "main_learning_object"


def _recommend_role(
    *,
    raw_input: str,
    source_type: str,
    user_hint: str | None = None,
    canonical_repo_role: str | None = None,
) -> dict[str, Any]:
    text = _text_blob(raw_input, source_type, user_hint)
    reasons: list[str] = [f"source_type:{source_type}"]

    if _contains_any(text, ("attach", "existing", "current project", "my project", "portfolio plan")):
        reasons.append("existing_plan_language")
        return {
            "role": "attach_to_existing_plan",
            "confidence": "high",
            "reason_codes": reasons,
        }

    if _contains_any(text, ("today", "tomorrow", "email myself", "remind me")):
        reasons.append("one_off_action_language")
        return {
            "role": "immediate_one_off",
            "confidence": "medium",
            "reason_codes": reasons,
        }

    if _contains_any(text, ("reference", "docs", "documentation", "lecture", "notes from")):
        reasons.append("reference_language")
        return {
            "role": "reference_material",
            "confidence": "high",
            "reason_codes": reasons,
        }

    if _contains_any(text, ("later", "someday", "eventually", "backlog")):
        reasons.append("later_language")
        confidence = "medium" if "later" in text else "low"
        return {
            "role": "later_resource",
            "confidence": confidence,
            "reason_codes": reasons,
        }

    if canonical_repo_role == "clone_rebuild_target":
        reasons.append("repo_clone_rebuild_target")
        return {
            "role": "new_plan",
            "confidence": "high",
            "reason_codes": reasons,
        }

    if _contains_any(text, ("learn", "study plan", "deadline", " by ", "weekly plan", "deadline-driven")):
        reasons.append("planning_language")
        return {
            "role": "new_plan",
            "confidence": "high",
            "reason_codes": reasons,
        }

    reasons.append("ambiguous_routing_language")
    return {
        "role": "later_resource",
        "confidence": "low",
        "reason_codes": reasons,
    }


def _suggest_attachment_mode(raw_input: str, user_hint: str | None = None) -> str:
    text = _text_blob(raw_input, user_hint)
    if _contains_any(text, ("scheduled", "schedule", "practice", "next week", "task")):
        return "scheduled_work"
    if _contains_any(text, ("phase", "milestone", "draft")):
        return "draft_phase"
    return "material_only"


def _clarification_question(default_role: str) -> dict[str, Any]:
    return {
        "prompt": "Should this become a new plan, attach to an existing plan, be stored as reference, saved for later, or treated as a one-off action?",
        "recommendedDefault": default_role,
        "options": [
            "new_plan",
            "attach_to_existing_plan",
            "reference_material",
            "later_resource",
            "immediate_one_off",
        ],
    }


async def _active_plan_candidates(db: aiosqlite.Connection) -> list[dict[str, Any]]:
    async with db.execute(
        """
        SELECT id, title
        FROM resources
        WHERE status = 'active' AND type = 'study_project'
        ORDER BY id ASC
        """
    ) as cursor:
        rows = await cursor.fetchall()
    return [{"id": row["id"], "title": row["title"]} for row in rows]


async def _ensure_active_plan_candidate(
    db: aiosqlite.Connection, existing_plan_id: int
) -> dict[str, Any]:
    async with db.execute(
        """
        SELECT id, title
        FROM resources
        WHERE id = ? AND status = 'active' AND type = 'study_project'
        """,
        (existing_plan_id,),
    ) as cursor:
        row = await cursor.fetchone()
    if row is None:
        raise ValueError("existing_plan_id must reference an active study plan")
    return {"id": row["id"], "title": row["title"]}


def _next_action(
    *,
    role: str,
    confidence: str,
    candidates: list[dict[str, Any]],
    existing_plan_id: int | None = None,
) -> str:
    if confidence == "low":
        return "answer_routing_question"
    if role in {"reference_material", "later_resource"}:
        return "confirm_non_plan_storage"
    if role == "attach_to_existing_plan":
        if existing_plan_id is not None and candidates:
            return "role_review"
        return "select_attachment_target" if candidates else "answer_routing_question"
    return "role_review"


def _candidate_reason(candidate: dict[str, Any]) -> str:
    return f"existing_plan_candidate:{candidate['id']}:{candidate['title']}"


def _selected_plan_reason(candidate: dict[str, Any]) -> str:
    return f"selected_existing_plan:{candidate['id']}:{candidate['title']}"


def _candidates_from_reasons(reason_codes: list[str]) -> list[dict[str, Any]]:
    candidates: list[dict[str, Any]] = []
    for reason in reason_codes:
        if reason.startswith("existing_plan_candidate:"):
            _, plan_id, title = reason.split(":", 2)
            candidates.append({"id": int(plan_id), "title": title})
    return candidates


def _selected_plan_from_reasons(reason_codes: list[str]) -> dict[str, Any] | None:
    for reason in reason_codes:
        if reason.startswith("selected_existing_plan:"):
            _, plan_id, title = reason.split(":", 2)
            return {"id": int(plan_id), "title": title}
    return None


def _canonical_repo_role_from_reasons(reason_codes: list[str]) -> str | None:
    for reason in reason_codes:
        if reason.startswith("canonical_repo_role:"):
            return reason.split(":", 1)[1]
    return None


def _attachment_mode_from_reasons(reason_codes: list[str]) -> str | None:
    for reason in reason_codes:
        if reason.startswith("attachment_mode:"):
            return reason.split(":", 1)[1]
    return None


def _public_reason_codes(reason_codes: list[str]) -> list[str]:
    return [reason for reason in reason_codes if not reason.startswith(INTERNAL_REASON_PREFIXES)]


def _route_payload(
    *,
    item: dict[str, Any],
    canonical_repo_role: str | None,
    attachment_mode: str | None,
    candidates: list[dict[str, Any]],
    clarification_question: dict[str, Any] | None,
    preview_summary: dict[str, Any] | None = None,
    existing_plan_id: int | None = None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "intakeItemId": item["id"],
        "recommendedRole": item["recommended_role"],
        "confidence": item["confidence"],
        "reasonCodes": _public_reason_codes(item["reason_codes"]),
        "nextAction": item["next_action"],
        "createsActiveTasks": False,
    }
    if preview_summary is not None:
        payload["previewSummary"] = preview_summary
    if canonical_repo_role is not None:
        payload["canonicalRepoRole"] = canonical_repo_role
    if attachment_mode is not None:
        payload["attachmentModeSuggestion"] = attachment_mode
    if item["recommended_role"] == "attach_to_existing_plan":
        payload["existingPlanCandidates"] = candidates
    if existing_plan_id is not None:
        payload["existingPlanId"] = existing_plan_id
    if clarification_question is not None:
        payload["clarificationQuestion"] = clarification_question
    return payload


def _route_payload_from_stored_item(item: dict[str, Any]) -> dict[str, Any]:
    raw_input = item["raw_input"]
    source_type = item["source_type"]
    reason_codes = item["reason_codes"]
    selected_candidate = _selected_plan_from_reasons(reason_codes)
    candidates = [selected_candidate] if selected_candidate is not None else _candidates_from_reasons(reason_codes)
    next_action = item["next_action"]
    stored_attachment_mode = _attachment_mode_from_reasons(reason_codes)
    return _route_payload(
        item=item,
        canonical_repo_role=(
            _canonical_repo_role_from_reasons(reason_codes)
            or _canonical_repo_role(_text_blob(raw_input))
        ),
        attachment_mode=(
            stored_attachment_mode or _suggest_attachment_mode(raw_input)
            if item["recommended_role"] == "attach_to_existing_plan"
            else None
        ),
        candidates=candidates,
        clarification_question=(
            _clarification_question(item["recommended_role"])
            if next_action == "answer_routing_question"
            else None
        ),
        preview_summary={"title": _title_from_input(raw_input), "sourceType": source_type},
        existing_plan_id=selected_candidate["id"] if selected_candidate is not None else None,
    )


async def _fetch_intake_item(
    db: aiosqlite.Connection, client_request_id: str, *, missing_ok: bool = False
) -> dict | None:
    async with db.execute(
        """
        SELECT
            id,
            client_request_id,
            raw_input,
            source_type,
            recommended_role,
            confidence,
            reason_codes,
            next_action,
            confirmation_state,
            calibration_level,
            created_at
        FROM study_intake_items
        WHERE client_request_id = ?
        """,
        (client_request_id,),
    ) as cursor:
        row = await cursor.fetchone()
    if row is None and missing_ok:
        return None
    if row is None:
        raise RuntimeError("intake item was not persisted")
    item = _row_to_dict(row)
    item["reason_codes"] = json.loads(item["reason_codes"])
    return item


async def _fetch_non_plan_item(db: aiosqlite.Connection, intake_item_id: int) -> dict:
    async with db.execute(
        """
        SELECT id, intake_item_id, role, title, url, metadata, created_at
        FROM study_intake_non_plan_items
        WHERE intake_item_id = ?
        """,
        (intake_item_id,),
    ) as cursor:
        row = await cursor.fetchone()
    if row is None:
        raise RuntimeError("non-plan item was not persisted")
    item = _row_to_dict(row)
    item["metadata"] = json.loads(item["metadata"]) if item["metadata"] else None
    return item


async def _fetch_plan_attachment(db: aiosqlite.Connection, intake_item_id: int) -> dict:
    async with db.execute(
        """
        SELECT id, intake_item_id, target_plan_id, attachment_mode, title, metadata, created_at
        FROM study_intake_plan_attachments
        WHERE intake_item_id = ?
        """,
        (intake_item_id,),
    ) as cursor:
        row = await cursor.fetchone()
    if row is None:
        raise RuntimeError("plan attachment was not persisted")
    attachment = _row_to_dict(row)
    attachment["metadata"] = json.loads(attachment["metadata"]) if attachment["metadata"] else None
    return attachment


async def create_intake_item(
    db: aiosqlite.Connection,
    *,
    client_request_id: str,
    raw_input: str,
    source_type: str,
    recommended_role: str,
    confidence: str,
    reason_codes: list[str] | None = None,
    next_action: str = "role_review",
    confirmation_state: str = "pending",
    calibration_level: str = "standard",
) -> dict:
    """Create or return a study intake item keyed by client request id."""
    await db.execute(
        """
        INSERT OR IGNORE INTO study_intake_items (
            client_request_id,
            raw_input,
            source_type,
            recommended_role,
            confidence,
            reason_codes,
            next_action,
            confirmation_state,
            calibration_level
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            client_request_id,
            raw_input,
            source_type,
            recommended_role,
            confidence,
            _json_dumps(reason_codes or []),
            next_action,
            confirmation_state,
            calibration_level,
        ),
    )
    await db.commit()
    return await _fetch_intake_item(db, client_request_id)


async def route_intake_submission(
    db: aiosqlite.Connection,
    *,
    client_request_id: str,
    raw_input: str,
    source_type: str,
    user_hint: str | None = None,
    existing_plan_id: int | None = None,
) -> dict[str, Any]:
    """Create an intake item and return the first-version routing contract."""
    existing = await _fetch_intake_item(db, client_request_id, missing_ok=True)
    if existing is not None:
        return _route_payload_from_stored_item(existing)

    canonical_repo_role = _canonical_repo_role(_text_blob(raw_input, user_hint))
    recommendation = _recommend_role(
        raw_input=raw_input,
        source_type=source_type,
        user_hint=user_hint,
        canonical_repo_role=canonical_repo_role,
    )
    validated_existing_plan = None
    if existing_plan_id is not None:
        validated_existing_plan = await _ensure_active_plan_candidate(db, existing_plan_id)
    selected_candidate = (
        validated_existing_plan
        if recommendation["role"] == "attach_to_existing_plan"
        else None
    )
    candidates = []
    if recommendation["role"] == "attach_to_existing_plan":
        candidates = (
            [selected_candidate]
            if selected_candidate is not None
            else await _active_plan_candidates(db)
        )
    reason_codes = list(recommendation["reason_codes"])
    if canonical_repo_role is not None:
        reason_codes.append(f"canonical_repo_role:{canonical_repo_role}")
    if selected_candidate is not None:
        reason_codes.append(_selected_plan_reason(selected_candidate))
    if recommendation["role"] == "attach_to_existing_plan":
        reason_codes.extend(_candidate_reason(candidate) for candidate in candidates)
    if recommendation["role"] == "attach_to_existing_plan" and not candidates:
        reason_codes.append("no_existing_plan_candidate")

    attachment_mode = (
        _suggest_attachment_mode(raw_input, user_hint)
        if recommendation["role"] == "attach_to_existing_plan"
        else None
    )
    if attachment_mode is not None:
        reason_codes.append(f"attachment_mode:{attachment_mode}")
    next_action = _next_action(
        role=recommendation["role"],
        confidence=recommendation["confidence"],
        candidates=candidates,
        existing_plan_id=selected_candidate["id"] if selected_candidate is not None else None,
    )
    item = await create_intake_item(
        db,
        client_request_id=client_request_id,
        raw_input=raw_input,
        source_type=source_type,
        recommended_role=recommendation["role"],
        confidence=recommendation["confidence"],
        reason_codes=reason_codes,
        next_action=next_action,
        calibration_level="low" if recommendation["confidence"] == "low" else "standard",
    )
    return _route_payload_from_stored_item(item)


async def _fetch_intake_item_by_id(db: aiosqlite.Connection, intake_item_id: int) -> dict:
    async with db.execute(
        """
        SELECT
            id,
            client_request_id,
            raw_input,
            source_type,
            recommended_role,
            confidence,
            reason_codes,
            next_action,
            confirmation_state,
            calibration_level,
            created_at
        FROM study_intake_items
        WHERE id = ?
        """,
        (intake_item_id,),
    ) as cursor:
        row = await cursor.fetchone()
    if row is None:
        raise ValueError("intake item not found")
    item = _row_to_dict(row)
    item["reason_codes"] = json.loads(item["reason_codes"])
    return item


async def confirm_intake_route(
    db: aiosqlite.Connection,
    *,
    intake_item_id: int,
    confirmed_role: str,
    title: str,
    url: str | None = None,
    existing_plan_id: int | None = None,
    attachment_mode: str | None = None,
    canonical_repo_role: str | None = None,
    metadata: dict | None = None,
) -> dict[str, Any]:
    """Confirm an intake route without creating active scheduled work."""
    if confirmed_role not in ROLES:
        raise ValueError("unsupported confirmed role")

    item = await _fetch_intake_item_by_id(db, intake_item_id)
    base: dict[str, Any] = {
        "intakeItemId": intake_item_id,
        "recommendedRole": item["recommended_role"],
        "confirmedRole": confirmed_role,
        "createsActiveTasks": False,
    }
    if canonical_repo_role is not None:
        base["canonicalRepoRole"] = canonical_repo_role

    if confirmed_role in {"reference_material", "later_resource", "immediate_one_off"}:
        stored = await confirm_non_plan_resource(
            db,
            intake_item_id=intake_item_id,
            role=confirmed_role,
            title=title,
            url=url,
            metadata=metadata,
        )
        return base | {
            "nextAction": "confirm_non_plan_storage",
            "outcome": "stored_non_plan",
            "storedItemId": stored["id"],
        }

    if confirmed_role == "attach_to_existing_plan":
        if existing_plan_id is None or attachment_mode is None:
            return base | {
                "nextAction": "select_attachment_target",
                "outcome": "needs_attachment_target",
            }
        if attachment_mode not in ATTACHMENT_MODES:
            raise ValueError("unsupported attachment mode")
        target_plan = await _ensure_active_plan_candidate(db, existing_plan_id)
        if attachment_mode == "material_only":
            attachment = await attach_material_to_plan(
                db,
                intake_item_id=intake_item_id,
                target_plan_id=target_plan["id"],
                attachment_mode=attachment_mode,
                title=title,
                metadata=metadata,
            )
            return base | {
                "nextAction": "confirm_non_plan_storage",
                "outcome": "stored_plan_attachment",
                "attachmentId": attachment["id"],
            }
        shell = await create_or_load_draft_shell(
            db,
            intake_item_id=intake_item_id,
            title=title,
            source_url=url or (metadata or {}).get("source_url") or item["raw_input"],
            deadline=_metadata_deadline(metadata),
            capacity_minutes=_metadata_capacity_minutes(metadata),
            draft_kind=_draft_kind_for_attachment_mode(attachment_mode),
            target_plan_id=target_plan["id"],
            calibration_level=item["calibration_level"],
            assumptions=_metadata_assumptions(metadata),
        )
        await db.execute(
            """
            UPDATE study_intake_items
            SET confirmation_state = 'awaiting_anchor_review'
            WHERE id = ?
            """,
            (intake_item_id,),
        )
        await db.commit()
        return base | {
            "nextAction": "handoff_to_anchor_review",
            "outcome": "awaiting_anchor_review",
            "existingPlanId": target_plan["id"],
            "targetPlanId": target_plan["id"],
            "attachmentMode": attachment_mode,
            "draftId": shell["id"],
            "draftKind": shell["draft_kind"],
        }

    shell = await create_or_load_draft_shell(
        db,
        intake_item_id=intake_item_id,
        title=title,
        source_url=url or (metadata or {}).get("source_url") or item["raw_input"],
        deadline=_metadata_deadline(metadata),
        capacity_minutes=_metadata_capacity_minutes(metadata),
        draft_kind="new_plan",
        target_plan_id=None,
        calibration_level=item["calibration_level"],
        assumptions=_metadata_assumptions(metadata),
    )
    await db.execute(
        """
        UPDATE study_intake_items
        SET confirmation_state = 'awaiting_anchor_review'
        WHERE id = ?
        """,
        (intake_item_id,),
    )
    await db.commit()
    return base | {
        "nextAction": "handoff_to_anchor_review",
        "outcome": "awaiting_anchor_review",
        "targetPlanId": None,
        "draftId": shell["id"],
        "draftKind": shell["draft_kind"],
    }


async def confirm_non_plan_resource(
    db: aiosqlite.Connection,
    *,
    intake_item_id: int,
    role: str,
    title: str,
    url: str | None = None,
    metadata: dict | None = None,
) -> dict:
    """Persist a reference or later item outside active scheduling."""
    await db.execute("BEGIN")
    try:
        await db.execute(
            """
            INSERT INTO study_intake_non_plan_items (
                intake_item_id,
                role,
                title,
                url,
                metadata
            )
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(intake_item_id) DO NOTHING
            """,
            (intake_item_id, role, title, url, _metadata_to_db(metadata)),
        )
        item = await _fetch_non_plan_item(db, intake_item_id)
        await db.execute(
            """
            UPDATE study_intake_items
            SET confirmation_state = 'confirmed'
            WHERE id = ?
            """,
            (intake_item_id,),
        )
        await db.commit()
    except Exception:
        await db.rollback()
        raise
    return item


async def attach_material_to_plan(
    db: aiosqlite.Connection,
    *,
    intake_item_id: int,
    target_plan_id: int,
    attachment_mode: str,
    title: str,
    metadata: dict | None = None,
) -> dict:
    """Persist an intake attachment without adding scheduled work."""
    await db.execute("BEGIN")
    try:
        await db.execute(
            """
            INSERT INTO study_intake_plan_attachments (
                intake_item_id,
                target_plan_id,
                attachment_mode,
                title,
                metadata
            )
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(intake_item_id) DO NOTHING
            """,
            (
                intake_item_id,
                target_plan_id,
                attachment_mode,
                title,
                _metadata_to_db(metadata),
            ),
        )
        attachment = await _fetch_plan_attachment(db, intake_item_id)
        await db.execute(
            """
            UPDATE study_intake_items
            SET confirmation_state = 'confirmed'
            WHERE id = ?
            """,
            (intake_item_id,),
        )
        await db.commit()
    except Exception:
        await db.rollback()
        raise
    return attachment
