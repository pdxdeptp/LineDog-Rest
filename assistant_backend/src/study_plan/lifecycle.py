"""Minimal draft study project lifecycle persistence."""

import json
from copy import deepcopy
from datetime import date, datetime, timezone
from typing import Any

import aiosqlite

DRAFT_SCHEMA_VERSION = 1
DRAFT_KINDS = {"new_plan", "existing_plan_phase", "existing_plan_scheduled_work"}
OPEN_DRAFT_STATUSES = {
    "review",
    "anchor_review",
    "compiling",
    "needs_input",
    "compile_failed",
    "infeasible_review",
    "draft_review",
    "activating",
}
DRAFT_PACKAGE_STATUSES = {
    "review",
    "anchor_review",
    "compiling",
    "needs_input",
    "compile_failed",
    "infeasible_review",
    "draft_review",
}
PACKAGE_CORE_FIELDS = {
    "schema_version",
    "draft_id",
    "draft_version",
    "intake_id",
    "status",
    "summary",
    "assumptions",
    "phases",
    "tasks",
    "review_summary",
    "activation_eligibility",
}
ACTIVATABLE_PACKAGE_STATUSES = {"draft_review", "infeasible_review"}
DRAFT_PACKAGE_TRANSITIONS = {
    "anchor_review": {"compiling"},
    "compiling": {"needs_input", "compile_failed", "draft_review", "infeasible_review"},
    "needs_input": {"anchor_review"},
    "compile_failed": {"anchor_review"},
    "infeasible_review": {"draft_review"},
    "draft_review": set(),
    "review": {"draft_review"},
}


def _iso(value: date | str) -> str:
    return value.isoformat() if isinstance(value, date) else value


def _json_dumps(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True)


def _json_loads(raw: str | None, fallback: Any) -> Any:
    if raw is None:
        return deepcopy(fallback)
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return deepcopy(fallback)


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _validate_draft_package_status(status: str) -> None:
    if status not in DRAFT_PACKAGE_STATUSES:
        raise ValueError(f"unsupported draft package status: {status}")


def _validate_draft_package_transition(current_status: str, next_status: str) -> None:
    _validate_draft_package_status(next_status)
    if current_status == next_status:
        return
    if next_status not in DRAFT_PACKAGE_TRANSITIONS.get(current_status, set()):
        raise ValueError(f"invalid draft package transition: {current_status} -> {next_status}")


def _ensure_draft_allows_package_write(draft: dict[str, Any]) -> None:
    if draft["status"] not in OPEN_DRAFT_STATUSES:
        raise ValueError(f"cannot modify closed draft: {draft['status']}")


async def _ensure_draft_version_storage(db: aiosqlite.Connection) -> None:
    await db.execute(
        """
        CREATE TABLE IF NOT EXISTS study_project_draft_versions (
            id                     INTEGER PRIMARY KEY,
            draft_id               INTEGER NOT NULL REFERENCES study_project_drafts(id),
            draft_version          INTEGER NOT NULL,
            schema_version         INTEGER NOT NULL DEFAULT 1,
            status                 TEXT    NOT NULL,
            summary                TEXT,
            assumptions            TEXT    NOT NULL DEFAULT '{}',
            package_json           TEXT    NOT NULL DEFAULT '{}',
            phases                 TEXT    NOT NULL DEFAULT '[]',
            tasks                  TEXT    NOT NULL DEFAULT '[]',
            review_summary         TEXT    NOT NULL DEFAULT '{}',
            activation_eligibility TEXT    NOT NULL DEFAULT '{}',
            created_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(draft_id, draft_version)
        )
        """
    )
    await db.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_study_project_draft_versions_latest
        ON study_project_draft_versions(draft_id, draft_version)
        """
    )


async def _fetch_draft_header(db: aiosqlite.Connection, draft_id: int) -> dict[str, Any]:
    async with db.execute(
        """
        SELECT id, intake_item_id, title, source_url, deadline, status,
               schema_version, draft_version, latest_version, calibration_level,
               draft_kind, target_plan_id, capacity_minutes, clarification_skipped,
               metadata, activated_resource_id, created_at, updated_at
        FROM study_project_drafts
        WHERE id = ?
        """,
        (draft_id,),
    ) as cursor:
        row = await cursor.fetchone()
    if row is None:
        raise ValueError(f"Study project draft not found: {draft_id}")
    header = dict(row)
    header["clarification_skipped"] = bool(header["clarification_skipped"])
    header["metadata"] = _json_loads(header.get("metadata"), {})
    return header


async def _fetch_draft_shell(db: aiosqlite.Connection, draft_id: int) -> dict[str, Any]:
    header = await _fetch_draft_header(db, draft_id)
    display_metadata = header["metadata"].get("display_metadata") or {}
    return {
        "id": header["id"],
        "intake_item_id": header["intake_item_id"],
        "title": header["title"],
        "source_url": header["source_url"],
        "deadline": header["deadline"],
        "status": header["status"],
        "schema_version": header["schema_version"],
        "draft_version": header["draft_version"],
        "latest_version": header["latest_version"],
        "calibration_level": header["calibration_level"],
        "draft_kind": header["draft_kind"],
        "target_plan_id": header["target_plan_id"],
        "capacity_minutes": header["capacity_minutes"],
        "clarification_skipped": header["clarification_skipped"],
        "metadata": header["metadata"],
        "display_metadata": display_metadata,
        "activated_resource_id": header["activated_resource_id"],
    }


async def _validate_draft_target_plan(
    db: aiosqlite.Connection,
    *,
    draft_kind: str,
    target_plan_id: int | None,
) -> None:
    if draft_kind not in DRAFT_KINDS:
        raise ValueError("unsupported draft kind")
    if draft_kind == "new_plan":
        if target_plan_id is not None:
            raise ValueError("new_plan drafts cannot target an existing plan")
        return
    if target_plan_id is None:
        raise ValueError("target_plan_id must reference an active study plan")
    async with db.execute(
        """
        SELECT id
        FROM resources
        WHERE id = ? AND status = 'active' AND type = 'study_project'
        """,
        (target_plan_id,),
    ) as cursor:
        row = await cursor.fetchone()
    if row is None:
        raise ValueError("target_plan_id must reference an active study plan")


def _package_payload(
    *,
    draft: dict[str, Any],
    draft_version: int,
    status: str,
    summary: str | None,
    assumptions: dict[str, Any],
    phases: list[dict[str, Any]],
    tasks: list[dict[str, Any]],
    review_summary: dict[str, Any],
    activation_eligibility: dict[str, Any],
    extra: dict[str, Any] | None = None,
) -> dict[str, Any]:
    payload = {
        "schema_version": DRAFT_SCHEMA_VERSION,
        "draft_id": draft["id"],
        "draft_version": draft_version,
        "intake_id": draft["intake_item_id"],
        "status": status,
        "summary": summary,
        "assumptions": assumptions,
        "phases": phases,
        "tasks": tasks,
        "review_summary": review_summary,
        "activation_eligibility": activation_eligibility,
    }
    if extra:
        payload.update(extra)
    return payload


async def _upsert_draft_version(
    db: aiosqlite.Connection,
    *,
    draft: dict[str, Any],
    draft_version: int,
    status: str,
    summary: str | None = None,
    assumptions: dict[str, Any] | None = None,
    phases: list[dict[str, Any]] | None = None,
    tasks: list[dict[str, Any]] | None = None,
    review_summary: dict[str, Any] | None = None,
    activation_eligibility: dict[str, Any] | None = None,
    extra_package_fields: dict[str, Any] | None = None,
) -> dict[str, Any]:
    _validate_draft_package_status(status)
    assumptions = assumptions or {}
    phases = phases or []
    tasks = tasks or []
    review_summary = review_summary or {}
    activation_eligibility = activation_eligibility or {}
    package = _package_payload(
        draft=draft,
        draft_version=draft_version,
        status=status,
        summary=summary,
        assumptions=assumptions,
        phases=phases,
        tasks=tasks,
        review_summary=review_summary,
        activation_eligibility=activation_eligibility,
        extra=extra_package_fields,
    )
    await db.execute(
        """
        INSERT INTO study_project_draft_versions (
            draft_id, draft_version, schema_version, status, summary,
            assumptions, package_json, phases, tasks, review_summary,
            activation_eligibility
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(draft_id, draft_version) DO UPDATE SET
            schema_version = excluded.schema_version,
            status = excluded.status,
            summary = excluded.summary,
            assumptions = excluded.assumptions,
            package_json = excluded.package_json,
            phases = excluded.phases,
            tasks = excluded.tasks,
            review_summary = excluded.review_summary,
            activation_eligibility = excluded.activation_eligibility,
            updated_at = CURRENT_TIMESTAMP
        """,
        (
            draft["id"],
            draft_version,
            DRAFT_SCHEMA_VERSION,
            status,
            summary,
            _json_dumps(assumptions),
            _json_dumps(package),
            _json_dumps(phases),
            _json_dumps(tasks),
            _json_dumps(review_summary),
            _json_dumps(activation_eligibility),
        ),
    )
    return package


def _unknown_legacy_assumptions(draft: dict[str, Any]) -> dict[str, Any]:
    return {
        "deadline": {
            "value": draft.get("deadline"),
            "provenance": "unknown",
            "accepted": False,
        },
        "capacity": {
            "daily_minutes": draft.get("capacity_minutes"),
            "provenance": "unknown",
            "accepted": False,
        },
        "target_output": {
            "value": None,
            "provenance": "unknown",
            "accepted": False,
        },
        "target_depth": {
            "value": None,
            "provenance": "unknown",
            "accepted": False,
        },
        "buffer_policy": {
            "value": None,
            "provenance": "unknown",
            "accepted": False,
        },
        "rest_days": {
            "weekdays": [],
            "unavailable_dates": [],
            "provenance": "unknown",
            "accepted": False,
        },
        "source_roles": {
            "value": {},
            "provenance": "unknown",
            "accepted": False,
        },
    }


def _legacy_package_from_draft(
    draft: dict[str, Any],
    draft_version: int,
) -> dict[str, Any]:
    metadata_assumptions = draft["metadata"].get("assumptions")
    assumptions = (
        metadata_assumptions
        if isinstance(metadata_assumptions, dict) and metadata_assumptions
        else _unknown_legacy_assumptions(draft)
    )
    return _package_payload(
        draft=draft,
        draft_version=draft_version,
        status=draft["status"],
        summary=draft["title"],
        assumptions=assumptions,
        phases=[],
        tasks=[],
        review_summary={"provenance": "legacy_header"},
        activation_eligibility={
            "activation_ready": False,
            "provenance": "unknown",
        },
        extra={
            "recovered_from": "legacy_draft_header",
            "provenance": "unknown",
        },
    )


async def _fetch_version_row(
    db: aiosqlite.Connection,
    draft_id: int,
    draft_version: int,
) -> dict[str, Any] | None:
    async with db.execute(
        """
        SELECT draft_id, draft_version, schema_version, status, summary,
               assumptions, package_json, phases, tasks, review_summary,
               activation_eligibility
        FROM study_project_draft_versions
        WHERE draft_id = ? AND draft_version = ?
        """,
        (draft_id, draft_version),
    ) as cursor:
        row = await cursor.fetchone()
    return dict(row) if row else None


async def _has_draft_version_rows(db: aiosqlite.Connection, draft_id: int) -> bool:
    async with db.execute(
        """
        SELECT 1
        FROM study_project_draft_versions
        WHERE draft_id = ?
        LIMIT 1
        """,
        (draft_id,),
    ) as cursor:
        return await cursor.fetchone() is not None


async def _latest_activatable_package_version(
    db: aiosqlite.Connection,
    draft_id: int,
) -> int | None:
    async with db.execute(
        f"""
        SELECT MAX(draft_version) AS draft_version
        FROM study_project_draft_versions
        WHERE draft_id = ?
          AND status IN ({",".join("?" for _ in ACTIVATABLE_PACKAGE_STATUSES)})
        """,
        (draft_id, *sorted(ACTIVATABLE_PACKAGE_STATUSES)),
    ) as cursor:
        row = await cursor.fetchone()
    if row is None or row["draft_version"] is None:
        return None
    return int(row["draft_version"])


def _package_from_version_row(row: dict[str, Any]) -> dict[str, Any]:
    package = _json_loads(row["package_json"], {})
    package.update(
        {
            "draft_id": row["draft_id"],
            "draft_version": row["draft_version"],
            "schema_version": row["schema_version"],
            "status": row["status"],
            "summary": row["summary"],
            "assumptions": _json_loads(row["assumptions"], {}),
            "phases": _json_loads(row["phases"], []),
            "tasks": _json_loads(row["tasks"], []),
            "review_summary": _json_loads(row["review_summary"], {}),
            "activation_eligibility": _json_loads(row["activation_eligibility"], {}),
        }
    )
    return package


async def create_or_load_draft_shell(
    db: aiosqlite.Connection,
    *,
    intake_item_id: int,
    title: str,
    source_url: str,
    deadline: date | str,
    capacity_minutes: int,
    clarification_skipped: bool = False,
    draft_kind: str = "new_plan",
    target_plan_id: int | None = None,
    calibration_level: str = "standard",
    assumptions: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Create or return the open draft shell for an intake item and draft kind."""
    await _ensure_draft_version_storage(db)
    await _validate_draft_target_plan(
        db,
        draft_kind=draft_kind,
        target_plan_id=target_plan_id,
    )
    await db.execute("BEGIN IMMEDIATE")
    try:
        async with db.execute(
            f"""
            SELECT id
            FROM study_project_drafts
            WHERE intake_item_id = ?
              AND draft_kind = ?
              AND (
                  (target_plan_id IS NULL AND ? IS NULL)
                  OR target_plan_id = ?
              )
              AND status IN ({",".join("?" for _ in OPEN_DRAFT_STATUSES)})
            ORDER BY id ASC
            LIMIT 1
            """,
            (
                intake_item_id,
                draft_kind,
                target_plan_id,
                target_plan_id,
                *sorted(OPEN_DRAFT_STATUSES),
            ),
        ) as cursor:
            existing = await cursor.fetchone()
        if existing is not None:
            await db.commit()
            return await _fetch_draft_shell(db, int(existing["id"]))

        metadata = {
            "assumptions": assumptions or {},
            "display_metadata": {},
            "source_url": source_url,
            "deadline": _iso(deadline),
            "capacity_minutes": capacity_minutes,
        }
        cursor = await db.execute(
            """
            INSERT INTO study_project_drafts
                (intake_item_id, title, source_url, deadline, status,
                 schema_version, draft_version, latest_version, calibration_level,
                 draft_kind, target_plan_id, capacity_minutes, clarification_skipped,
                 metadata)
            VALUES (?, ?, ?, ?, 'anchor_review', ?, 1, 1, ?, ?, ?, ?, ?, ?)
            """,
            (
                intake_item_id,
                title,
                source_url,
                _iso(deadline),
                DRAFT_SCHEMA_VERSION,
                calibration_level,
                draft_kind,
                target_plan_id,
                capacity_minutes,
                int(clarification_skipped),
                _json_dumps(metadata),
            ),
        )
        draft_id = int(cursor.lastrowid)
        draft = await _fetch_draft_header(db, draft_id)
        await _upsert_draft_version(
            db,
            draft=draft,
            draft_version=1,
            status="anchor_review",
            summary=None,
            assumptions=assumptions or {},
        )
        await db.commit()
    except Exception:
        await db.rollback()
        raise

    return await _fetch_draft_shell(db, draft_id)


async def save_draft_compiler_package_shell(
    db: aiosqlite.Connection,
    *,
    draft_id: int,
    status: str,
    summary: str | None = None,
    assumptions: dict[str, Any] | None = None,
    phases: list[dict[str, Any]] | None = None,
    tasks: list[dict[str, Any]] | None = None,
    review_summary: dict[str, Any] | None = None,
    activation_eligibility: dict[str, Any] | None = None,
    missing_input: dict[str, Any] | None = None,
    validation_errors: list[dict[str, Any]] | None = None,
    risk_report: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Persist a compiler package shell for the current draft version."""
    await _ensure_draft_version_storage(db)
    _validate_draft_package_status(status)
    extra = {
        key: value
        for key, value in {
            "missing_input": missing_input,
            "validation_errors": validation_errors,
            "risk_report": risk_report,
        }.items()
        if value is not None
    }
    await db.execute("BEGIN IMMEDIATE")
    try:
        draft = await _fetch_draft_header(db, draft_id)
        _ensure_draft_allows_package_write(draft)
        draft_version = int(draft["latest_version"])
        _validate_draft_package_transition(draft["status"], status)
        package = await _upsert_draft_version(
            db,
            draft=draft,
            draft_version=draft_version,
            status=status,
            summary=summary,
            assumptions=assumptions,
            phases=phases,
            tasks=tasks,
            review_summary=review_summary,
            activation_eligibility=activation_eligibility,
            extra_package_fields=extra,
        )
        metadata = dict(draft["metadata"])
        metadata["assumptions"] = assumptions or {}
        metadata["latest_package_summary"] = summary
        await db.execute(
            """
            UPDATE study_project_drafts
            SET status = ?, schema_version = ?, draft_version = ?,
                latest_version = ?, metadata = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (
                status,
                DRAFT_SCHEMA_VERSION,
                draft_version,
                draft_version,
                _json_dumps(metadata),
                draft_id,
            ),
        )
        await db.commit()
    except Exception:
        await db.rollback()
        raise
    return package


async def fetch_draft_package_version(
    db: aiosqlite.Connection,
    draft_id: int,
    draft_version: int,
) -> dict[str, Any]:
    await _ensure_draft_version_storage(db)
    row = await _fetch_version_row(db, draft_id, draft_version)
    if row is None:
        draft = await _fetch_draft_header(db, draft_id)
        if draft_version != int(draft["latest_version"]) or await _has_draft_version_rows(
            db, draft_id
        ):
            raise ValueError(f"Draft package version not found: {draft_id}@{draft_version}")
        synthetic = _legacy_package_from_draft(draft, draft_version)
        should_commit = not db.in_transaction
        try:
            package = await _upsert_draft_version(
                db,
                draft=draft,
                draft_version=draft_version,
                status=synthetic["status"],
                summary=synthetic["summary"],
                assumptions=synthetic["assumptions"],
                review_summary=synthetic["review_summary"],
                activation_eligibility=synthetic["activation_eligibility"],
                extra_package_fields={
                    key: value
                    for key, value in synthetic.items()
                    if key not in PACKAGE_CORE_FIELDS
                },
            )
        except Exception:
            if should_commit:
                await db.rollback()
            raise
        if should_commit:
            await db.commit()
        return package
    return _package_from_version_row(row)


async def fetch_latest_draft_package(
    db: aiosqlite.Connection,
    draft_id: int,
) -> dict[str, Any]:
    draft = await _fetch_draft_header(db, draft_id)
    return await fetch_draft_package_version(db, draft_id, int(draft["latest_version"]))


async def create_meaningful_draft_edit_version(
    db: aiosqlite.Connection,
    *,
    draft_id: int,
    edit_kind: str,
    package_updates: dict[str, Any],
    expected_latest_version: int | None = None,
) -> dict[str, Any]:
    """Create a snapshot version after an edit that affects plan semantics."""
    await _ensure_draft_version_storage(db)
    await db.execute("BEGIN IMMEDIATE")
    try:
        draft = await _fetch_draft_header(db, draft_id)
        _ensure_draft_allows_package_write(draft)
        latest_version = int(draft["latest_version"])
        if (
            expected_latest_version is not None
            and latest_version != int(expected_latest_version)
        ):
            raise ValueError("stale draft option requested")
        latest_row = await _fetch_version_row(db, draft_id, latest_version)
        if latest_row is None:
            raise ValueError(f"Draft package version not found: {draft_id}@{latest_version}")
        latest = _package_from_version_row(latest_row)
        next_version = latest_version + 1
        updated = deepcopy(latest)
        updated.update(package_updates)
        updated["draft_version"] = next_version
        updated["edit_kind"] = edit_kind
        status = updated.get("status") or draft["status"]
        _validate_draft_package_transition(draft["status"], status)
        extra_fields = {
            key: value
            for key, value in updated.items()
            if key not in PACKAGE_CORE_FIELDS
        }
        package = await _upsert_draft_version(
            db,
            draft=draft,
            draft_version=next_version,
            status=status,
            summary=updated.get("summary"),
            assumptions=updated.get("assumptions") or {},
            phases=updated.get("phases") or [],
            tasks=updated.get("tasks") or [],
            review_summary=updated.get("review_summary") or {},
            activation_eligibility=updated.get("activation_eligibility") or {},
            extra_package_fields=extra_fields,
        )
        metadata = dict(draft["metadata"])
        metadata["assumptions"] = package["assumptions"]
        metadata["latest_package_summary"] = package.get("summary")
        await db.execute(
            """
            UPDATE study_project_drafts
            SET status = ?, draft_version = ?, latest_version = ?,
                metadata = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (status, next_version, next_version, _json_dumps(metadata), draft_id),
        )
        await db.commit()
    except Exception:
        await db.rollback()
        raise
    return package


async def update_draft_display_metadata(
    db: aiosqlite.Connection,
    *,
    draft_id: int,
    display_metadata: dict[str, Any],
) -> dict[str, Any]:
    """Update display-only metadata without creating a new draft version."""
    draft = await _fetch_draft_header(db, draft_id)
    metadata = dict(draft["metadata"])
    metadata["display_metadata"] = display_metadata
    await db.execute(
        """
        UPDATE study_project_drafts
        SET metadata = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
        """,
        (_json_dumps(metadata), draft_id),
    )
    await db.commit()
    return await _fetch_draft_shell(db, draft_id)


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


def _activation_ready_schedule_version(package: dict[str, Any]) -> str | None:
    eligibility = package.get("activation_eligibility") or {}
    return (
        eligibility.get("schedule_version")
        or package.get("schedule_version")
        or package.get("schedule", {}).get("version")
    )


def _package_activation_units(package: dict[str, Any]) -> list[dict[str, Any]]:
    eligibility = package.get("activation_eligibility") or {}
    package_tasks = package.get("tasks") or []
    if package.get("status") not in ACTIVATABLE_PACKAGE_STATUSES or not eligibility.get(
        "activation_ready"
    ):
        raise ValueError("draft package is not activation-ready")
    if not package_tasks:
        raise ValueError("draft package is not activation-ready: missing task data")

    units: list[dict[str, Any]] = []
    for index, task in enumerate(package_tasks):
        slices = task.get("schedule_slices") or task.get("schedule") or []
        if not isinstance(slices, list) or not slices:
            raise ValueError("draft package is not activation-ready: missing schedule slices")

        title = task.get("title")
        if not title:
            raise ValueError("draft package is not activation-ready: missing task title")

        active_slices: list[dict[str, Any]] = []
        total_minutes = 0
        for schedule_slice in slices:
            if not isinstance(schedule_slice, dict):
                raise ValueError("draft package is not activation-ready: invalid schedule slice")
            scheduled_date = schedule_slice.get("scheduled_date") or schedule_slice.get("date")
            target_minutes = schedule_slice.get("target_minutes")
            if not scheduled_date or target_minutes is None:
                raise ValueError("draft package is not activation-ready: incomplete schedule slice")
            minutes = int(target_minutes)
            total_minutes += minutes
            active_slices.append(
                {
                    "title": schedule_slice.get("title") or title,
                    "scheduled_date": _iso(scheduled_date),
                    "target_minutes": minutes,
                }
            )

        units.append(
            {
                "title": title,
                "order_index": index,
                "estimated_minutes": int(
                    task.get("estimate_minutes")
                    or task.get("estimated_minutes")
                    or total_minutes
                ),
                "slices": active_slices,
            }
        )
    return units


def _legacy_activation_units(draft: dict[str, Any]) -> list[dict[str, Any]]:
    if not draft["tasks"]:
        raise ValueError("Study plan draft has no tasks")
    return [
        {
            "title": task["title"],
            "order_index": int(task["order_index"]),
            "estimated_minutes": int(task["estimated_minutes"]),
            "slices": [
                {
                    "title": task["title"],
                    "scheduled_date": task["scheduled_date"],
                    "target_minutes": int(task["target_minutes"]),
                }
            ],
        }
        for task in draft["tasks"]
    ]


async def _next_unit_order_index(db: aiosqlite.Connection, resource_id: int) -> int:
    async with db.execute(
        """
        SELECT
            COALESCE(MAX(u.order_index) + 1, 0) AS next_from_units,
            COALESCE(r.total_units, 0) AS next_from_resource
        FROM resources r
        LEFT JOIN units u ON u.resource_id = r.id
        WHERE r.id = ?
        GROUP BY r.id
        """,
        (resource_id,),
    ) as cursor:
        row = await cursor.fetchone()
    if row is None:
        raise ValueError("target_plan_id must reference an active study plan")
    return max(int(row["next_from_units"]), int(row["next_from_resource"]))


async def _insert_activation_units(
    db: aiosqlite.Connection,
    *,
    resource_id: int,
    units: list[dict[str, Any]],
    start_order_index: int,
) -> list[int]:
    created_task_ids: list[int] = []
    for offset, unit in enumerate(units):
        unit_cursor = await db.execute(
            """
            INSERT INTO units
                (resource_id, title, order_index, estimated_minutes, status)
            VALUES (?, ?, ?, ?, 'pending')
            """,
            (
                resource_id,
                unit["title"],
                start_order_index + offset,
                unit["estimated_minutes"],
            ),
        )
        unit_id = int(unit_cursor.lastrowid)
        for schedule_slice in unit["slices"]:
            task_cursor = await db.execute(
                """
                INSERT INTO tasks
                    (unit_id, resource_id, title, task_kind, target_minutes,
                     scheduled_date, originally_scheduled_date)
                VALUES (?, ?, ?, 'time', ?, ?, ?)
                """,
                (
                    unit_id,
                    resource_id,
                    schedule_slice["title"],
                    schedule_slice["target_minutes"],
                    schedule_slice["scheduled_date"],
                    schedule_slice["scheduled_date"],
                ),
            )
            created_task_ids.append(int(task_cursor.lastrowid))
    return created_task_ids


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
                  AND (
                      (target_plan_id IS NULL AND ? IS NULL)
                      OR target_plan_id = ?
                  )
                  AND status IN (
                      'review', 'draft_review', 'anchor_review', 'compiling',
                      'needs_input', 'compile_failed', 'infeasible_review', 'activating'
                  )
                ORDER BY id ASC
                LIMIT 1
                """,
                (intake_item_id, draft_kind, target_plan_id, target_plan_id),
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
    await db.execute("BEGIN IMMEDIATE")
    try:
        draft = await _fetch_draft_header(db, draft_id)
        if draft["activated_resource_id"] is not None or draft["status"] == "active_plan":
            raise ValueError("cannot discard an already activated draft")
        if draft["status"] in {"discarded", "cancelled"}:
            await db.commit()
            return await _fetch_draft(db, draft_id)
        if draft["status"] not in OPEN_DRAFT_STATUSES:
            raise ValueError(f"cannot discard draft from state: {draft['status']}")
        await db.execute(
            """
            UPDATE study_project_drafts
            SET status = 'discarded', updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (draft_id,),
        )
        await db.commit()
    except Exception:
        await db.rollback()
        raise
    return await _fetch_draft(db, draft_id)


async def confirm_draft_study_project(
    db: aiosqlite.Connection,
    draft_id: int,
    *,
    draft_version: int | None = None,
    actor: str | None = None,
    source: str | None = None,
) -> dict[str, Any]:
    await db.execute("BEGIN IMMEDIATE")
    try:
        header = await _fetch_draft_header(db, draft_id)
        if header["activated_resource_id"] is not None or header["status"] == "active_plan":
            raise ValueError("already_activated")

        requested_version = int(draft_version or header["draft_version"])
        header_latest_version = int(header["latest_version"])

        draft = await _fetch_draft(db, draft_id)
        package: dict[str, Any] | None = None
        schedule_version: str | None = None
        use_legacy_review = (
            header["status"] == "review"
            and requested_version == int(header["draft_version"])
            and draft["tasks"]
        )
        if not use_legacy_review:
            latest_activatable_version = await _latest_activatable_package_version(db, draft_id)
            if latest_activatable_version is None:
                raise ValueError(f"Study project draft is not reviewable: {draft_id}")
            if requested_version != latest_activatable_version:
                raise ValueError("stale draft activation requested")
            package = await fetch_draft_package_version(db, draft_id, requested_version)
            units = _package_activation_units(package)
            schedule_version = _activation_ready_schedule_version(package)
            if not schedule_version:
                raise ValueError("draft package is not activation-ready: missing schedule version")
        else:
            units = _legacy_activation_units(draft)

        transition = await db.execute(
            """
            UPDATE study_project_drafts
            SET status = 'activating', updated_at = CURRENT_TIMESTAMP
            WHERE id = ? AND status = ? AND latest_version = ?
            """,
            (draft_id, header["status"], header_latest_version),
        )
        if transition.rowcount != 1:
            raise ValueError("stale draft activation requested")

        if header["draft_kind"] == "new_plan":
            resource_cursor = await db.execute(
                """
                INSERT INTO resources
                    (title, type, tracking_mode, url, status, total_units, deadline)
                VALUES (?, 'study_project', 'sequential', ?, 'active', ?, ?)
                """,
                (
                    draft["title"],
                    draft["source_url"],
                    len(units),
                    draft["deadline"],
                ),
            )
            resource_id = int(resource_cursor.lastrowid)
            target_plan_id = None
            start_order_index = 0
        else:
            target_plan_id = header["target_plan_id"]
            await _validate_draft_target_plan(
                db,
                draft_kind=header["draft_kind"],
                target_plan_id=target_plan_id,
            )
            resource_id = int(target_plan_id)
            start_order_index = await _next_unit_order_index(db, resource_id)

        created_task_ids = await _insert_activation_units(
            db,
            resource_id=resource_id,
            units=units,
            start_order_index=start_order_index,
        )

        if header["draft_kind"] != "new_plan":
            await db.execute(
                """
                UPDATE resources
                SET total_units = COALESCE(total_units, 0) + ?
                WHERE id = ?
                """,
                (len(units), resource_id),
            )

        await db.execute(
            """
            UPDATE study_project_drafts
            SET status = 'active_plan', activated_resource_id = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ? AND status = 'activating'
            """,
            (resource_id, draft_id),
        )

        payload = {
            "draft_id": draft_id,
            "intake_item_id": draft["intake_item_id"],
            "activated_draft_version": requested_version,
            "schedule_version": schedule_version,
            "resource_id": resource_id,
            "target_plan_id": target_plan_id,
            "created_active_task_ids": created_task_ids,
            "actor": actor,
            "source": source,
            "activated_at": _utc_now_iso(),
            "draft_kind": header["draft_kind"],
            "assumptions": package["assumptions"] if package else {},
            "source_url": draft["source_url"],
            "deadline": draft["deadline"],
            "capacity_minutes": draft["capacity_minutes"],
            "clarification_skipped": draft["clarification_skipped"],
            "duration_estimates": [task["estimated_minutes"] for task in draft["tasks"]],
        }
        await db.execute(
            "INSERT INTO events (event_type, payload) VALUES (?, ?)",
            ("study_project_activated", _json_dumps(payload)),
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
