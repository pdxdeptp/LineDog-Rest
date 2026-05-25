"""Persistence helpers for study intake items."""

import json
from typing import Any

import aiosqlite


def _row_to_dict(row: Any) -> dict:
    return dict(row)


def _json_dumps(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True)


def _metadata_to_db(metadata: dict | None) -> str | None:
    return _json_dumps(metadata) if metadata is not None else None


async def _fetch_intake_item(db: aiosqlite.Connection, client_request_id: str) -> dict:
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
