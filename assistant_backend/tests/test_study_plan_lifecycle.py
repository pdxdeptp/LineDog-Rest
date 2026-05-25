"""Study plan draft lifecycle tests."""

import importlib
import json
from datetime import date

import aiosqlite
import pytest


def _lifecycle_module():
    try:
        return importlib.import_module("src.study_plan.lifecycle")
    except ModuleNotFoundError as exc:
        pytest.fail(f"Expected study plan lifecycle module to exist: {exc}")


async def _fetchone(db: aiosqlite.Connection, sql: str, params: tuple = ()) -> dict | None:
    async with db.execute(sql, params) as cur:
        row = await cur.fetchone()
    return dict(row) if row else None


async def _fetchall(db: aiosqlite.Connection, sql: str, params: tuple = ()) -> list[dict]:
    async with db.execute(sql, params) as cur:
        rows = await cur.fetchall()
    return [dict(row) for row in rows]


class _FailingEventExecute:
    def __init__(self, operation):
        self._operation = operation
        self._cursor = None

    def __await__(self):
        return self._operation.__await__()

    async def __aenter__(self):
        self._cursor = await self._operation
        return self._cursor

    async def __aexit__(self, exc_type, exc, tb) -> None:
        if self._cursor is not None:
            await self._cursor.close()


class _FailingEventConnection:
    def __init__(self, conn: aiosqlite.Connection) -> None:
        self._conn = conn

    def execute(self, sql: str, params: tuple = ()):
        normalized = " ".join(sql.split()).lower()
        if normalized.startswith("insert into events"):
            raise RuntimeError("simulated event insert failure")
        return _FailingEventExecute(self._conn.execute(sql, params))

    def __getattr__(self, name: str):
        return getattr(self._conn, name)


class _BeforeBeginExecute:
    def __init__(self, operation, before_begin=None) -> None:
        self._operation = operation
        self._before_begin = before_begin
        self._cursor = None

    async def _execute(self):
        if self._before_begin:
            await self._before_begin()
        return await self._operation

    def __await__(self):
        return self._execute().__await__()

    async def __aenter__(self):
        self._cursor = await self._execute()
        return self._cursor

    async def __aexit__(self, exc_type, exc, tb) -> None:
        if self._cursor is not None:
            await self._cursor.close()


class _BeforeBeginConnection:
    def __init__(self, conn: aiosqlite.Connection, before_begin) -> None:
        self._conn = conn
        self._before_begin = before_begin

    def execute(self, sql: str, params: tuple = ()):
        before_begin = None
        if " ".join(sql.split()).lower() == "begin immediate":
            before_begin = self._before_begin
        return _BeforeBeginExecute(self._conn.execute(sql, params), before_begin)

    def __getattr__(self, name: str):
        return getattr(self._conn, name)


@pytest.mark.asyncio
async def test_create_draft_study_project_stays_in_review_without_active_daily_tasks(db):
    lifecycle = _lifecycle_module()

    draft = await lifecycle.create_draft_study_project(
        db,
        title="Learn SQLite Query Planning",
        source_url="https://example.com/sqlite-query-planning",
        deadline=date(2026, 6, 15),
        capacity_minutes=75,
        clarification_skipped=True,
        tasks=[
            {
                "title": "Read planner overview",
                "estimated_minutes": 45,
                "scheduled_date": date(2026, 6, 1),
                "target_minutes": 45,
            },
            {
                "title": "Inspect EXPLAIN examples",
                "estimated_minutes": 30,
                "scheduled_date": date(2026, 6, 2),
                "target_minutes": 30,
            },
        ],
    )

    assert draft["status"] == "review"
    assert draft["source_url"] == "https://example.com/sqlite-query-planning"
    assert draft["deadline"] == "2026-06-15"
    assert draft["capacity_minutes"] == 75
    assert draft["clarification_skipped"] is True
    assert [task["title"] for task in draft["tasks"]] == [
        "Read planner overview",
        "Inspect EXPLAIN examples",
    ]

    active_resources = await _fetchall(db, "SELECT id FROM resources WHERE status = 'active'")
    active_tasks = await _fetchall(db, "SELECT id FROM tasks")
    assert active_resources == []
    assert active_tasks == []


@pytest.mark.asyncio
async def test_create_draft_study_project_links_intake_item_idempotently_without_active_tasks(db):
    lifecycle = _lifecycle_module()
    cursor = await db.execute(
        """
        INSERT INTO study_intake_items
            (client_request_id, raw_input, source_type, recommended_role, confidence)
        VALUES ('req-draft-link', 'learn sqlite', 'url', 'new_plan', 'high')
        """
    )
    intake_item_id = int(cursor.lastrowid)
    await db.commit()

    first = await lifecycle.create_draft_study_project(
        db,
        title="Learn SQLite",
        source_url="https://example.com/sqlite",
        deadline=date(2026, 6, 15),
        capacity_minutes=60,
        clarification_skipped=False,
        intake_item_id=intake_item_id,
        tasks=[
            {
                "title": "Read SQLite intro",
                "estimated_minutes": 30,
                "scheduled_date": date(2026, 6, 1),
                "target_minutes": 30,
            }
        ],
    )
    second = await lifecycle.create_draft_study_project(
        db,
        title="Learn SQLite Again",
        source_url="https://example.com/sqlite-again",
        deadline=date(2026, 6, 20),
        capacity_minutes=90,
        clarification_skipped=True,
        intake_item_id=intake_item_id,
        tasks=[
            {
                "title": "This should not duplicate",
                "estimated_minutes": 90,
                "scheduled_date": date(2026, 6, 2),
                "target_minutes": 90,
            }
        ],
    )

    assert second["id"] == first["id"]
    assert first["intake_item_id"] == intake_item_id
    assert first["schema_version"] == 1
    assert first["draft_version"] == 1
    assert first["latest_version"] == 1
    assert first["calibration_level"] == "standard"
    assert first["draft_kind"] == "new_plan"
    assert first["target_plan_id"] is None
    assert first["status"] == "review"
    assert [task["title"] for task in second["tasks"]] == ["Read SQLite intro"]

    headers = await _fetchall(
        db,
        "SELECT id FROM study_project_drafts WHERE intake_item_id = ?",
        (intake_item_id,),
    )
    draft_tasks = await _fetchall(
        db,
        "SELECT id FROM study_project_draft_tasks WHERE draft_id = ?",
        (first["id"],),
    )
    assert headers == [{"id": first["id"]}]
    assert len(draft_tasks) == 1
    assert await _fetchall(db, "SELECT id FROM resources WHERE status = 'active'") == []
    assert await _fetchall(db, "SELECT id FROM tasks") == []


def _planning_assumptions(**overrides):
    assumptions = {
        "deadline": {
            "value": "2026-07-15",
            "type": "fixed",
            "provenance": "user_provided",
            "accepted": True,
        },
        "capacity": {
            "daily_minutes": 60,
            "per_date_overrides": {"2026-07-03": 30},
            "provenance": "system_default",
            "accepted": True,
        },
        "target_output": {
            "value": "working demo",
            "provenance": "parsed",
            "accepted": True,
        },
        "target_depth": {
            "value": "project",
            "provenance": "ai_assumed",
            "accepted": False,
            "user_edited": True,
        },
        "buffer_policy": {
            "value": "leave_20_percent",
            "provenance": "system_default",
            "accepted": True,
        },
        "rest_days": {
            "weekdays": [5],
            "unavailable_dates": ["2026-07-04"],
            "provenance": "user_provided",
            "accepted": True,
        },
        "source_roles": {
            "github_repo": "main_learning_object",
            "provenance": "parsed",
            "accepted": True,
        },
    }
    assumptions.update(overrides)
    return assumptions


async def _create_intake(db: aiosqlite.Connection, client_request_id: str) -> int:
    cursor = await db.execute(
        """
        INSERT INTO study_intake_items
            (client_request_id, raw_input, source_type, recommended_role, confidence)
        VALUES (?, 'learn durable activation', 'text_goal', 'new_plan', 'high')
        """,
        (client_request_id,),
    )
    await db.commit()
    return int(cursor.lastrowid)


async def _save_compiling_package(db: aiosqlite.Connection, lifecycle, draft_id: int) -> dict:
    return await lifecycle.save_draft_compiler_package_shell(
        db,
        draft_id=draft_id,
        status="compiling",
        summary="Compiling package",
        assumptions=_planning_assumptions(),
    )


async def _force_package_version(
    db: aiosqlite.Connection,
    *,
    draft_id: int,
    draft_version: int,
    intake_id: int | None,
    status: str,
    summary: str,
    assumptions: dict | None = None,
    tasks: list[dict] | None = None,
    activation_eligibility: dict | None = None,
) -> None:
    assumptions = assumptions or _planning_assumptions()
    tasks = tasks or []
    activation_eligibility = activation_eligibility or {"activation_ready": False}
    package = {
        "schema_version": 1,
        "draft_id": draft_id,
        "draft_version": draft_version,
        "intake_id": intake_id,
        "status": status,
        "summary": summary,
        "assumptions": assumptions,
        "phases": [],
        "tasks": tasks,
        "review_summary": {},
        "activation_eligibility": activation_eligibility,
    }
    await db.execute(
        """
        INSERT INTO study_project_draft_versions (
            draft_id, draft_version, schema_version, status, summary,
            assumptions, package_json, phases, tasks, review_summary,
            activation_eligibility
        )
        VALUES (?, ?, 1, ?, ?, ?, ?, '[]', ?, '{}', ?)
        """,
        (
            draft_id,
            draft_version,
            status,
            summary,
            json.dumps(assumptions, sort_keys=True),
            json.dumps(package, sort_keys=True),
            json.dumps(tasks, sort_keys=True),
            json.dumps(activation_eligibility, sort_keys=True),
        ),
    )
    await db.execute(
        """
        UPDATE study_project_drafts
        SET status = ?, draft_version = ?, latest_version = ?
        WHERE id = ?
        """,
        (status, draft_version, draft_version, draft_id),
    )
    await db.commit()


def _activation_ready_tasks(
    *,
    scheduled_date: str = "2026-08-10",
    include_slices: bool = True,
) -> list[dict]:
    task = {
        "stable_task_id": "task-activation-1",
        "phase_id": "phase-activation",
        "title": "Read activation notes",
        "estimate_minutes": 40,
    }
    if include_slices:
        task["schedule_slices"] = [
            {
                "schedule_slice_id": "slice-activation-1",
                "scheduled_date": scheduled_date,
                "target_minutes": 40,
            }
        ]
    return [task]


async def _create_activation_ready_shell(
    db: aiosqlite.Connection,
    lifecycle,
    *,
    client_request_id: str,
    draft_kind: str = "new_plan",
    target_plan_id: int | None = None,
    tasks: list[dict] | None = None,
    activation_eligibility: dict | None = None,
    status: str = "draft_review",
) -> dict:
    intake_item_id = await _create_intake(db, client_request_id)
    shell = await lifecycle.create_or_load_draft_shell(
        db,
        intake_item_id=intake_item_id,
        title="Durable Activation",
        source_url="https://example.com/durable-activation",
        deadline="2026-08-30",
        capacity_minutes=60,
        draft_kind=draft_kind,
        target_plan_id=target_plan_id,
        assumptions=_planning_assumptions(),
    )
    await _save_compiling_package(db, lifecycle, shell["id"])
    await lifecycle.save_draft_compiler_package_shell(
        db,
        draft_id=shell["id"],
        status=status,
        summary="Activation-ready draft",
        assumptions=_planning_assumptions(),
        phases=[{"phase_id": "phase-activation", "title": "Activation Phase"}],
        tasks=tasks if tasks is not None else _activation_ready_tasks(),
        review_summary={"headline": "Ready"},
        activation_eligibility=activation_eligibility
        if activation_eligibility is not None
        else {
            "activation_ready": True,
            "schedule_version": "schedule-v1",
        },
    )
    return await lifecycle.fetch_latest_draft_package(db, shell["id"])


@pytest.mark.asyncio
async def test_draft_package_persists_assumptions_provenance_and_latest_fetch(db):
    lifecycle = _lifecycle_module()
    cursor = await db.execute(
        """
        INSERT INTO study_intake_items
            (client_request_id, raw_input, source_type, recommended_role, confidence)
        VALUES ('req-assumptions-package', 'learn sqlite deeply', 'text_goal', 'new_plan', 'high')
        """
    )
    intake_item_id = int(cursor.lastrowid)
    await db.commit()

    shell = await lifecycle.create_or_load_draft_shell(
        db,
        intake_item_id=intake_item_id,
        title="Learn SQLite Deeply",
        source_url="https://example.com/sqlite",
        deadline=date(2026, 7, 15),
        capacity_minutes=60,
        calibration_level="standard",
        assumptions=_planning_assumptions(),
    )
    await _save_compiling_package(db, lifecycle, shell["id"])
    saved = await lifecycle.save_draft_compiler_package_shell(
        db,
        draft_id=shell["id"],
        status="needs_input",
        summary="Need the learner to pick a target output.",
        assumptions=_planning_assumptions(),
        review_summary={"headline": "Missing anchor"},
        activation_eligibility={"activation_ready": False, "reason": "missing_input"},
        missing_input={"facts": ["target_output"]},
    )
    latest = await lifecycle.fetch_latest_draft_package(db, shell["id"])

    assert saved["draft_version"] == 1
    assert latest["draft_id"] == shell["id"]
    assert latest["draft_version"] == 1
    assert latest["status"] == "needs_input"
    assert latest["summary"] == "Need the learner to pick a target output."
    assert latest["assumptions"]["deadline"]["provenance"] == "user_provided"
    assert latest["assumptions"]["capacity"] == {
        "daily_minutes": 60,
        "per_date_overrides": {"2026-07-03": 30},
        "provenance": "system_default",
        "accepted": True,
    }
    assert latest["assumptions"]["target_output"] == {
        "value": "working demo",
        "provenance": "parsed",
        "accepted": True,
    }
    assert latest["assumptions"]["target_depth"]["user_edited"] is True
    assert latest["assumptions"]["buffer_policy"] == {
        "value": "leave_20_percent",
        "provenance": "system_default",
        "accepted": True,
    }
    assert latest["assumptions"]["rest_days"] == {
        "weekdays": [5],
        "unavailable_dates": ["2026-07-04"],
        "provenance": "user_provided",
        "accepted": True,
    }
    assert latest["assumptions"]["source_roles"] == {
        "github_repo": "main_learning_object",
        "provenance": "parsed",
        "accepted": True,
    }
    assert latest["activation_eligibility"] == {
        "activation_ready": False,
        "reason": "missing_input",
    }


@pytest.mark.asyncio
async def test_save_package_shell_reloads_latest_version_inside_transaction(db):
    lifecycle = _lifecycle_module()
    cursor = await db.execute(
        """
        INSERT INTO study_intake_items
            (client_request_id, raw_input, source_type, recommended_role, confidence)
        VALUES ('req-package-transaction-latest', 'learn sqlite', 'text_goal', 'new_plan', 'high')
        """
    )
    intake_item_id = int(cursor.lastrowid)
    await db.commit()
    shell = await lifecycle.create_or_load_draft_shell(
        db,
        intake_item_id=intake_item_id,
        title="Learn SQLite",
        source_url="https://example.com/sqlite",
        deadline="2026-07-20",
        capacity_minutes=60,
    )
    await _save_compiling_package(db, lifecycle, shell["id"])
    await lifecycle.save_draft_compiler_package_shell(
        db,
        draft_id=shell["id"],
        status="needs_input",
        summary="Initial missing anchors",
        assumptions=_planning_assumptions(),
    )

    async def create_concurrent_latest_version() -> None:
        assumptions = _planning_assumptions(
            target_output={
                "value": "concurrent demo",
                "provenance": "user_provided",
                "accepted": True,
            }
        )
        package = {
            "schema_version": 1,
            "draft_id": shell["id"],
            "draft_version": 2,
            "intake_id": intake_item_id,
            "status": "compiling",
            "summary": "Concurrent user edit",
            "assumptions": assumptions,
            "phases": [],
            "tasks": [],
            "review_summary": {},
            "activation_eligibility": {"activation_ready": True},
        }
        await db.execute(
            """
            INSERT INTO study_project_draft_versions (
                draft_id, draft_version, schema_version, status, summary,
                assumptions, package_json, phases, tasks, review_summary,
                activation_eligibility
            )
            VALUES (?, 2, 1, 'compiling', 'Concurrent user edit',
                    ?, ?, '[]', '[]', '{}', ?)
            """,
            (
                shell["id"],
                json.dumps(assumptions, sort_keys=True),
                json.dumps(package, sort_keys=True),
                json.dumps({"activation_ready": True}, sort_keys=True),
            ),
        )
        await db.execute(
            """
            UPDATE study_project_drafts
            SET status = 'compiling', draft_version = 2, latest_version = 2
            WHERE id = ?
            """,
            (shell["id"],),
        )
        await db.commit()

    racing_db = _BeforeBeginConnection(db, create_concurrent_latest_version)

    package = await lifecycle.save_draft_compiler_package_shell(
        racing_db,
        draft_id=shell["id"],
        status="compile_failed",
        summary="Validation failed after concurrent edit",
        assumptions=_planning_assumptions(),
        validation_errors=[{"field": "deadline", "message": "too soon"}],
    )

    assert package["draft_version"] == 2
    assert package["status"] == "compile_failed"
    assert await _fetchone(
        db,
        "SELECT draft_version, latest_version FROM study_project_drafts WHERE id = ?",
        (shell["id"],),
    ) == {"draft_version": 2, "latest_version": 2}
    assert await _fetchall(
        db,
        """
        SELECT draft_version, status, summary
        FROM study_project_draft_versions
        WHERE draft_id = ?
        ORDER BY draft_version
        """,
        (shell["id"],),
    ) == [
        {
            "draft_version": 1,
            "status": "needs_input",
            "summary": "Initial missing anchors",
        },
        {
            "draft_version": 2,
            "status": "compile_failed",
            "summary": "Validation failed after concurrent edit",
        },
    ]


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "package_status",
    ["needs_input", "compile_failed", "infeasible_review", "draft_review"],
)
async def test_draft_package_shells_allow_blocked_statuses_without_schedule_tasks(
    db,
    package_status,
):
    lifecycle = _lifecycle_module()
    cursor = await db.execute(
        """
        INSERT INTO study_intake_items
            (client_request_id, raw_input, source_type, recommended_role, confidence)
        VALUES (?, 'learn compiler basics', 'text_goal', 'new_plan', 'high')
        """,
        (f"req-package-{package_status}",),
    )
    intake_item_id = int(cursor.lastrowid)
    await db.commit()

    shell = await lifecycle.create_or_load_draft_shell(
        db,
        intake_item_id=intake_item_id,
        title="Compiler Basics",
        source_url="https://example.com/compiler",
        deadline="2026-07-20",
        capacity_minutes=45,
    )
    await _save_compiling_package(db, lifecycle, shell["id"])

    package = await lifecycle.save_draft_compiler_package_shell(
        db,
        draft_id=shell["id"],
        status=package_status,
        summary=f"{package_status} shell",
        assumptions=_planning_assumptions(),
        review_summary={"status": package_status},
        activation_eligibility={"activation_ready": package_status == "draft_review"},
    )

    assert package["status"] == package_status
    assert package["phases"] == []
    assert package["tasks"] == []
    assert await _fetchall(db, "SELECT id FROM tasks") == []


@pytest.mark.asyncio
async def test_save_package_shell_rejects_unknown_package_status(db):
    lifecycle = _lifecycle_module()
    cursor = await db.execute(
        """
        INSERT INTO study_intake_items
            (client_request_id, raw_input, source_type, recommended_role, confidence)
        VALUES ('req-invalid-package-status', 'learn compiler basics', 'text_goal',
                'new_plan', 'high')
        """
    )
    intake_item_id = int(cursor.lastrowid)
    await db.commit()
    shell = await lifecycle.create_or_load_draft_shell(
        db,
        intake_item_id=intake_item_id,
        title="Compiler Basics",
        source_url="https://example.com/compiler",
        deadline="2026-07-20",
        capacity_minutes=45,
    )

    with pytest.raises(ValueError, match="status"):
        await lifecycle.save_draft_compiler_package_shell(
            db,
            draft_id=shell["id"],
            status="teleported",
            summary="Invalid lifecycle state",
            assumptions=_planning_assumptions(),
        )

    assert await _fetchone(
        db,
        "SELECT status, draft_version, latest_version FROM study_project_drafts WHERE id = ?",
        (shell["id"],),
    ) == {"status": "anchor_review", "draft_version": 1, "latest_version": 1}


@pytest.mark.asyncio
async def test_meaningful_edit_creates_new_draft_version_and_preserves_previous_package(db):
    lifecycle = _lifecycle_module()
    cursor = await db.execute(
        """
        INSERT INTO study_intake_items
            (client_request_id, raw_input, source_type, recommended_role, confidence)
        VALUES ('req-version-edit', 'learn fastapi', 'text_goal', 'new_plan', 'high')
        """
    )
    intake_item_id = int(cursor.lastrowid)
    await db.commit()
    shell = await lifecycle.create_or_load_draft_shell(
        db,
        intake_item_id=intake_item_id,
        title="Learn FastAPI",
        source_url="https://example.com/fastapi",
        deadline="2026-07-15",
        capacity_minutes=60,
    )
    await _save_compiling_package(db, lifecycle, shell["id"])
    first = await lifecycle.save_draft_compiler_package_shell(
        db,
        draft_id=shell["id"],
        status="draft_review",
        summary="Initial draft",
        assumptions=_planning_assumptions(),
        phases=[{"id": "phase-1", "title": "Basics"}],
        tasks=[{"stable_task_id": "task-1", "title": "Read docs", "estimate_minutes": 45}],
        activation_eligibility={"activation_ready": True},
    )

    second = await lifecycle.create_meaningful_draft_edit_version(
        db,
        draft_id=shell["id"],
        edit_kind="scope",
        package_updates={
            "summary": "Expanded project draft",
            "assumptions": _planning_assumptions(
                target_output={
                    "value": "deployed API",
                    "provenance": "user_provided",
                    "accepted": True,
                    "user_edited": True,
                }
            ),
            "tasks": [
                {"stable_task_id": "task-1", "title": "Read docs", "estimate_minutes": 45},
                {"stable_task_id": "task-2", "title": "Build endpoint", "estimate_minutes": 60},
            ],
        },
    )
    latest = await lifecycle.fetch_latest_draft_package(db, shell["id"])
    old = await lifecycle.fetch_draft_package_version(db, shell["id"], first["draft_version"])

    assert second["draft_version"] == 2
    assert latest["draft_version"] == 2
    assert latest["summary"] == "Expanded project draft"
    assert [task["title"] for task in latest["tasks"]] == ["Read docs", "Build endpoint"]
    assert old["draft_version"] == 1
    assert old["summary"] == "Initial draft"
    assert [task["title"] for task in old["tasks"]] == ["Read docs"]
    assert await _fetchone(
        db,
        "SELECT draft_version, latest_version FROM study_project_drafts WHERE id = ?",
        (shell["id"],),
    ) == {"draft_version": 2, "latest_version": 2}


@pytest.mark.asyncio
async def test_meaningful_edit_rejects_package_update_status_override(db):
    lifecycle = _lifecycle_module()
    cursor = await db.execute(
        """
        INSERT INTO study_intake_items
            (client_request_id, raw_input, source_type, recommended_role, confidence)
        VALUES ('req-invalid-edit-status', 'learn fastapi', 'text_goal', 'new_plan', 'high')
        """
    )
    intake_item_id = int(cursor.lastrowid)
    await db.commit()
    shell = await lifecycle.create_or_load_draft_shell(
        db,
        intake_item_id=intake_item_id,
        title="Learn FastAPI",
        source_url="https://example.com/fastapi",
        deadline="2026-07-15",
        capacity_minutes=60,
    )
    await _save_compiling_package(db, lifecycle, shell["id"])
    await lifecycle.save_draft_compiler_package_shell(
        db,
        draft_id=shell["id"],
        status="draft_review",
        summary="Initial draft",
        assumptions=_planning_assumptions(),
        activation_eligibility={"activation_ready": True},
    )

    with pytest.raises(ValueError, match="status"):
        await lifecycle.create_meaningful_draft_edit_version(
            db,
            draft_id=shell["id"],
            edit_kind="scope",
            package_updates={"status": "made_up", "summary": "Invalid status edit"},
        )

    assert await _fetchone(
        db,
        "SELECT status, draft_version, latest_version FROM study_project_drafts WHERE id = ?",
        (shell["id"],),
    ) == {"status": "draft_review", "draft_version": 1, "latest_version": 1}


@pytest.mark.asyncio
async def test_display_metadata_update_does_not_create_new_draft_version(db):
    lifecycle = _lifecycle_module()
    cursor = await db.execute(
        """
        INSERT INTO study_intake_items
            (client_request_id, raw_input, source_type, recommended_role, confidence)
        VALUES ('req-metadata-version', 'learn celery', 'text_goal', 'new_plan', 'high')
        """
    )
    intake_item_id = int(cursor.lastrowid)
    await db.commit()
    shell = await lifecycle.create_or_load_draft_shell(
        db,
        intake_item_id=intake_item_id,
        title="Learn Celery",
        source_url="https://example.com/celery",
        deadline="2026-07-25",
        capacity_minutes=60,
    )
    await _save_compiling_package(db, lifecycle, shell["id"])
    await lifecycle.save_draft_compiler_package_shell(
        db,
        draft_id=shell["id"],
        status="draft_review",
        summary="Review draft",
        assumptions=_planning_assumptions(),
    )

    updated = await lifecycle.update_draft_display_metadata(
        db,
        draft_id=shell["id"],
        display_metadata={"label": "Pinned", "color": "blue"},
    )
    latest = await lifecycle.fetch_latest_draft_package(db, shell["id"])
    version_rows = await _fetchall(
        db,
        "SELECT draft_version FROM study_project_draft_versions WHERE draft_id = ?",
        (shell["id"],),
    )

    assert updated["draft_version"] == 1
    assert updated["latest_version"] == 1
    assert updated["display_metadata"] == {"label": "Pinned", "color": "blue"}
    assert latest["draft_version"] == 1
    assert version_rows == [{"draft_version": 1}]


@pytest.mark.asyncio
async def test_fetch_latest_package_synthesizes_legacy_header_without_version_row(db):
    lifecycle = _lifecycle_module()
    cursor = await db.execute(
        """
        INSERT INTO study_project_drafts
            (title, source_url, deadline, status, capacity_minutes,
             clarification_skipped, metadata)
        VALUES ('Legacy Header', 'https://example.com/legacy', '2026-09-30',
                'review', 80, 0, '{}')
        """
    )
    draft_id = int(cursor.lastrowid)
    await db.commit()

    package = await lifecycle.fetch_latest_draft_package(db, draft_id)

    assert package["draft_id"] == draft_id
    assert package["draft_version"] == 1
    assert package["status"] == "review"
    assert package["summary"] == "Legacy Header"
    assert package["assumptions"]["deadline"] == {
        "value": "2026-09-30",
        "provenance": "unknown",
        "accepted": False,
    }
    assert package["assumptions"]["capacity"] == {
        "daily_minutes": 80,
        "provenance": "unknown",
        "accepted": False,
    }
    assert package["assumptions"]["target_output"]["provenance"] == "unknown"
    assert package["assumptions"]["target_depth"]["provenance"] == "unknown"
    assert package["assumptions"]["buffer_policy"]["provenance"] == "unknown"
    assert package["assumptions"]["rest_days"]["provenance"] == "unknown"
    assert package["assumptions"]["source_roles"]["provenance"] == "unknown"
    assert db.in_transaction is False

    updated = await lifecycle.save_draft_compiler_package_shell(
        db,
        draft_id=draft_id,
        status="draft_review",
        summary="Legacy package can be updated after fetch",
        assumptions=_planning_assumptions(),
    )

    assert updated["status"] == "draft_review"


@pytest.mark.asyncio
@pytest.mark.parametrize("closed_status", ["cancelled", "confirmed", "active_plan", "discarded"])
@pytest.mark.parametrize("entrypoint", ["save_package", "meaningful_edit"])
async def test_package_entrypoints_reject_closed_draft_without_reopening(
    db,
    closed_status,
    entrypoint,
):
    lifecycle = _lifecycle_module()
    draft = await lifecycle.create_draft_study_project(
        db,
        title=f"Closed {closed_status} Draft",
        source_url="https://example.com/closed-draft",
        deadline=date(2026, 8, 15),
        capacity_minutes=60,
        clarification_skipped=False,
        tasks=[
            {
                "title": "Draft-only task",
                "estimated_minutes": 45,
                "scheduled_date": date(2026, 8, 10),
                "target_minutes": 45,
            }
        ],
    )
    await lifecycle.fetch_latest_draft_package(db, draft["id"])
    if closed_status == "cancelled":
        await lifecycle.cancel_draft_study_project(db, draft["id"])
    else:
        await db.execute(
            """
            UPDATE study_project_drafts
            SET status = ?
            WHERE id = ?
            """,
            (closed_status, draft["id"]),
        )
        await db.commit()
    before = await _fetchone(
        db,
        "SELECT status, draft_version, latest_version FROM study_project_drafts WHERE id = ?",
        (draft["id"],),
    )

    with pytest.raises(ValueError, match="closed draft"):
        if entrypoint == "save_package":
            await lifecycle.save_draft_compiler_package_shell(
                db,
                draft_id=draft["id"],
                status="draft_review",
                summary="Should not reopen",
                assumptions=_planning_assumptions(),
            )
        else:
            await lifecycle.create_meaningful_draft_edit_version(
                db,
                draft_id=draft["id"],
                edit_kind="scope",
                package_updates={"summary": "Should not reopen"},
            )

    assert await _fetchone(
        db,
        "SELECT status, draft_version, latest_version FROM study_project_drafts WHERE id = ?",
        (draft["id"],),
    ) == before


@pytest.mark.asyncio
async def test_draft_kind_target_plan_linkage_requires_active_plan_for_existing_plan_shell(db):
    lifecycle = _lifecycle_module()
    active_cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Active Study Project', 'study_project', 'sequential', 'active', 1)
        """
    )
    active_plan_id = int(active_cursor.lastrowid)
    second_active_cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Second Active Study Project', 'study_project', 'sequential', 'active', 1)
        """
    )
    second_active_plan_id = int(second_active_cursor.lastrowid)
    archived_cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Archived Study Project', 'study_project', 'sequential', 'archived', 1)
        """
    )
    archived_plan_id = int(archived_cursor.lastrowid)
    intake_cursor = await db.execute(
        """
        INSERT INTO study_intake_items
            (client_request_id, raw_input, source_type, recommended_role, confidence)
        VALUES ('req-target-plan-shell', 'attach work', 'text_goal',
                'attach_to_existing_plan', 'high')
        """
    )
    intake_item_id = int(intake_cursor.lastrowid)
    await db.commit()

    shell = await lifecycle.create_or_load_draft_shell(
        db,
        intake_item_id=intake_item_id,
        title="Add retry practice",
        source_url="",
        deadline="2026-08-01",
        capacity_minutes=30,
        draft_kind="existing_plan_scheduled_work",
        target_plan_id=active_plan_id,
    )
    retry = await lifecycle.create_or_load_draft_shell(
        db,
        intake_item_id=intake_item_id,
        title="Duplicate should reuse shell",
        source_url="",
        deadline="2026-08-02",
        capacity_minutes=45,
        draft_kind="existing_plan_scheduled_work",
        target_plan_id=active_plan_id,
    )
    second_target_shell = await lifecycle.create_or_load_draft_shell(
        db,
        intake_item_id=intake_item_id,
        title="Attach to a different active plan",
        source_url="",
        deadline="2026-08-03",
        capacity_minutes=45,
        draft_kind="existing_plan_scheduled_work",
        target_plan_id=second_active_plan_id,
    )

    assert retry["id"] == shell["id"]
    assert second_target_shell["id"] != shell["id"]
    assert shell["draft_kind"] == "existing_plan_scheduled_work"
    assert shell["target_plan_id"] == active_plan_id
    assert second_target_shell["target_plan_id"] == second_active_plan_id
    with pytest.raises(ValueError, match="active study plan"):
        await lifecycle.create_or_load_draft_shell(
            db,
            intake_item_id=intake_item_id,
            title="Invalid target",
            source_url="",
            deadline="2026-08-01",
            capacity_minutes=30,
            draft_kind="existing_plan_phase",
            target_plan_id=archived_plan_id,
        )


@pytest.mark.asyncio
async def test_init_db_migrates_legacy_draft_storage_idempotently_without_touching_active_rows(
    tmp_path,
):
    from src.db.init import init_db
    from src.db.schema import SCHEMA_SQL

    db_path = tmp_path / "legacy-drafts.db"
    async with aiosqlite.connect(db_path) as conn:
        await conn.executescript(SCHEMA_SQL)
        await conn.executescript(
            """
            DROP TABLE study_project_draft_tasks;
            DROP TABLE study_project_drafts;

            CREATE TABLE study_project_drafts (
                id                    INTEGER PRIMARY KEY,
                title                 TEXT    NOT NULL,
                source_url            TEXT    NOT NULL,
                deadline              DATE    NOT NULL,
                status                TEXT    NOT NULL DEFAULT 'review',
                capacity_minutes      INTEGER NOT NULL,
                clarification_skipped INTEGER NOT NULL DEFAULT 0,
                metadata              TEXT,
                activated_resource_id INTEGER REFERENCES resources(id),
                created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE study_project_draft_tasks (
                id                INTEGER PRIMARY KEY,
                draft_id          INTEGER NOT NULL REFERENCES study_project_drafts(id),
                title             TEXT    NOT NULL,
                order_index       INTEGER NOT NULL,
                estimated_minutes INTEGER NOT NULL,
                scheduled_date    DATE    NOT NULL,
                target_minutes    INTEGER NOT NULL
            );
            """
        )
        resource = await conn.execute(
            """
            INSERT INTO resources (title, type, tracking_mode, status, total_units)
            VALUES ('Active Project', 'study_project', 'sequential', 'active', 1)
            """
        )
        resource_id = int(resource.lastrowid)
        unit = await conn.execute(
            """
            INSERT INTO units (resource_id, title, order_index, estimated_minutes, status)
            VALUES (?, 'Active Unit', 0, 25, 'pending')
            """,
            (resource_id,),
        )
        await conn.execute(
            """
            INSERT INTO tasks
                (unit_id, resource_id, title, task_kind, target_minutes,
                 scheduled_date, originally_scheduled_date)
            VALUES (?, ?, 'Active Task', 'time', 25, '2026-06-01', '2026-06-01')
            """,
            (int(unit.lastrowid), resource_id),
        )
        draft = await conn.execute(
            """
            INSERT INTO study_project_drafts
                (title, source_url, deadline, status, capacity_minutes,
                 clarification_skipped, metadata)
            VALUES ('Legacy Draft', 'https://example.com/legacy', '2026-06-30',
                    'review', 60, 0, '{}')
            """
        )
        await conn.execute(
            """
            INSERT INTO study_project_draft_tasks
                (draft_id, title, order_index, estimated_minutes, scheduled_date, target_minutes)
            VALUES (?, 'Legacy Draft Task', 0, 30, '2026-06-10', 30)
            """,
            (int(draft.lastrowid),),
        )
        await conn.commit()

    await init_db(str(db_path))
    await init_db(str(db_path))

    async with aiosqlite.connect(db_path) as conn:
        conn.row_factory = aiosqlite.Row
        draft_columns = {
            row["name"] for row in await _fetchall(conn, "PRAGMA table_info(study_project_drafts)")
        }
        task_columns = {
            row["name"] for row in await _fetchall(conn, "PRAGMA table_info(study_project_draft_tasks)")
        }
        legacy_draft = await _fetchone(
            conn,
            """
            SELECT title, status, intake_item_id, schema_version, draft_version,
                   latest_version, calibration_level, draft_kind, target_plan_id
            FROM study_project_drafts
            WHERE title = 'Legacy Draft'
            """,
        )
        legacy_task = await _fetchone(
            conn,
            """
            SELECT title, stable_task_id, phase_id, status, metadata, schedule_slices
            FROM study_project_draft_tasks
            WHERE title = 'Legacy Draft Task'
            """,
        )
        active_task = await _fetchone(
            conn,
            """
            SELECT r.title AS resource_title, t.title AS task_title, t.scheduled_date,
                   t.completed_at
            FROM resources r
            JOIN tasks t ON t.resource_id = r.id
            WHERE r.title = 'Active Project'
            """,
        )

    assert {
        "intake_item_id",
        "schema_version",
        "draft_version",
        "latest_version",
        "calibration_level",
        "draft_kind",
        "target_plan_id",
        "updated_at",
    }.issubset(draft_columns)
    assert {"stable_task_id", "phase_id", "status", "metadata", "schedule_slices"}.issubset(
        task_columns
    )
    assert legacy_draft == {
        "title": "Legacy Draft",
        "status": "review",
        "intake_item_id": None,
        "schema_version": 1,
        "draft_version": 1,
        "latest_version": 1,
        "calibration_level": "standard",
        "draft_kind": "new_plan",
        "target_plan_id": None,
    }
    assert legacy_task == {
        "title": "Legacy Draft Task",
        "stable_task_id": None,
        "phase_id": None,
        "status": "draft",
        "metadata": None,
        "schedule_slices": None,
    }
    assert active_task == {
        "resource_title": "Active Project",
        "task_title": "Active Task",
        "scheduled_date": "2026-06-01",
        "completed_at": None,
    }


@pytest.mark.asyncio
async def test_init_db_migrates_active_tasks_with_fallback_progress_columns_idempotently(
    tmp_path,
):
    from src.db.init import init_db
    from src.db.schema import SCHEMA_SQL

    db_path = tmp_path / "legacy-active-task-fallback.db"
    async with aiosqlite.connect(db_path) as conn:
        await conn.executescript(SCHEMA_SQL)
        await conn.executescript(
            """
            CREATE TABLE legacy_tasks AS SELECT * FROM tasks;
            DROP TABLE tasks;
            CREATE TABLE tasks (
                id                        INTEGER PRIMARY KEY,
                unit_id                   INTEGER REFERENCES units(id),
                resource_id               INTEGER REFERENCES resources(id),
                title                     TEXT    NOT NULL,
                task_kind                 TEXT    NOT NULL DEFAULT 'count',
                target_count              INTEGER,
                target_minutes            INTEGER,
                scheduled_date            DATE    NOT NULL,
                originally_scheduled_date DATE,
                reschedule_count          INTEGER DEFAULT 0,
                auto_roll_days            INTEGER DEFAULT 0,
                last_auto_rolled_at       DATE,
                user_adjusted_at          TIMESTAMP,
                priority                  INTEGER DEFAULT 0,
                completed_at              TIMESTAMP,
                actual_minutes            INTEGER,
                created_at                TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            DROP TABLE legacy_tasks;
            """
        )
        resource = await conn.execute(
            """
            INSERT INTO resources (title, type, tracking_mode, status, total_units)
            VALUES ('Active Fallback Project', 'study_project', 'sequential', 'active', 1)
            """
        )
        resource_id = int(resource.lastrowid)
        await conn.execute(
            """
            INSERT INTO tasks
                (resource_id, title, task_kind, target_minutes, scheduled_date,
                 completed_at, actual_minutes)
            VALUES (?, 'Existing Active Task', 'time', 25, '2026-06-01',
                    '2026-05-25T10:00:00+00:00', 27)
            """,
            (resource_id,),
        )
        await conn.commit()

    await init_db(str(db_path))
    await init_db(str(db_path))

    async with aiosqlite.connect(db_path) as conn:
        conn.row_factory = aiosqlite.Row
        task_columns = {row["name"] for row in await _fetchall(conn, "PRAGMA table_info(tasks)")}
        active_task = await _fetchone(
            conn,
            """
            SELECT completed_at, actual_minutes, fallback_completed_at,
                   fallback_actual_minutes, needs_followup
            FROM tasks
            WHERE title = 'Existing Active Task'
            """,
        )

    assert {"fallback_completed_at", "fallback_actual_minutes", "needs_followup"}.issubset(
        task_columns
    )
    assert active_task == {
        "completed_at": "2026-05-25T10:00:00+00:00",
        "actual_minutes": 27,
        "fallback_completed_at": None,
        "fallback_actual_minutes": None,
        "needs_followup": 0,
    }


@pytest.mark.asyncio
async def test_cancel_draft_study_project_discards_without_active_project_or_tasks(db):
    lifecycle = _lifecycle_module()
    draft = await lifecycle.create_draft_study_project(
        db,
        title="Learn Queueing Theory",
        source_url="https://example.com/queueing",
        deadline=date(2026, 7, 1),
        capacity_minutes=60,
        clarification_skipped=False,
        tasks=[
            {
                "title": "Review Little's Law",
                "estimated_minutes": 40,
                "scheduled_date": date(2026, 6, 20),
                "target_minutes": 40,
            }
        ],
    )

    cancelled = await lifecycle.cancel_draft_study_project(db, draft["id"])

    assert cancelled["status"] == "discarded"
    stored_draft = await _fetchone(
        db,
        "SELECT status FROM study_project_drafts WHERE id = ?",
        (draft["id"],),
    )
    assert stored_draft == {"status": "discarded"}
    assert await _fetchall(db, "SELECT id FROM resources WHERE status = 'active'") == []
    assert await _fetchall(db, "SELECT id FROM tasks") == []


@pytest.mark.asyncio
async def test_confirm_draft_study_project_activates_ordered_tasks_and_records_assumptions(db):
    lifecycle = _lifecycle_module()
    draft = await lifecycle.create_draft_study_project(
        db,
        title="Learn Query Optimization",
        source_url="https://example.com/query-optimization",
        deadline=date(2026, 6, 30),
        capacity_minutes=90,
        clarification_skipped=True,
        tasks=[
            {
                "title": "Map optimizer phases",
                "estimated_minutes": 45,
                "scheduled_date": date(2026, 6, 10),
                "target_minutes": 45,
            },
            {
                "title": "Practice index selection",
                "estimated_minutes": 60,
                "scheduled_date": date(2026, 6, 11),
                "target_minutes": 60,
            },
            {
                "title": "Summarize tradeoffs",
                "estimated_minutes": 30,
                "scheduled_date": date(2026, 6, 12),
                "target_minutes": 30,
            },
        ],
    )

    activated = await lifecycle.confirm_draft_study_project(db, draft["id"])

    assert activated["status"] == "active"
    assert activated["source_url"] == "https://example.com/query-optimization"
    assert activated["deadline"] == "2026-06-30"
    assert activated["capacity_minutes"] == 90
    assert activated["clarification_skipped"] is True

    resource = await _fetchone(
        db,
        """
        SELECT title, type, tracking_mode, url, status, total_units, deadline
        FROM resources
        WHERE id = ?
        """,
        (activated["resource_id"],),
    )
    assert resource == {
        "title": "Learn Query Optimization",
        "type": "study_project",
        "tracking_mode": "sequential",
        "url": "https://example.com/query-optimization",
        "status": "active",
        "total_units": 3,
        "deadline": "2026-06-30",
    }

    scheduled_tasks = await _fetchall(
        db,
        """
        SELECT u.order_index, u.title AS unit_title, u.estimated_minutes,
               t.title AS task_title, t.task_kind, t.target_minutes,
               t.scheduled_date, t.originally_scheduled_date
        FROM units u
        JOIN tasks t ON t.unit_id = u.id
        WHERE u.resource_id = ?
        ORDER BY u.order_index
        """,
        (activated["resource_id"],),
    )
    assert scheduled_tasks == [
        {
            "order_index": 0,
            "unit_title": "Map optimizer phases",
            "estimated_minutes": 45,
            "task_title": "Map optimizer phases",
            "task_kind": "time",
            "target_minutes": 45,
            "scheduled_date": "2026-06-10",
            "originally_scheduled_date": "2026-06-10",
        },
        {
            "order_index": 1,
            "unit_title": "Practice index selection",
            "estimated_minutes": 60,
            "task_title": "Practice index selection",
            "task_kind": "time",
            "target_minutes": 60,
            "scheduled_date": "2026-06-11",
            "originally_scheduled_date": "2026-06-11",
        },
        {
            "order_index": 2,
            "unit_title": "Summarize tradeoffs",
            "estimated_minutes": 30,
            "task_title": "Summarize tradeoffs",
            "task_kind": "time",
            "target_minutes": 30,
            "scheduled_date": "2026-06-12",
            "originally_scheduled_date": "2026-06-12",
        },
    ]

    stored_draft = await _fetchone(
        db,
        "SELECT status, activated_resource_id FROM study_project_drafts WHERE id = ?",
        (draft["id"],),
    )
    assert stored_draft == {"status": "active_plan", "activated_resource_id": activated["resource_id"]}

    event = await _fetchone(
        db,
        "SELECT payload FROM events WHERE event_type = 'study_project_activated'",
    )
    assert event is not None
    payload = json.loads(event["payload"])
    assert payload["resource_id"] == activated["resource_id"]
    assert payload["draft_id"] == draft["id"]
    assert payload["source_url"] == "https://example.com/query-optimization"
    assert payload["deadline"] == "2026-06-30"
    assert payload["capacity_minutes"] == 90
    assert payload["clarification_skipped"] is True
    assert payload["duration_estimates"] == [45, 60, 30]


@pytest.mark.asyncio
async def test_confirm_draft_study_project_rejects_duplicate_confirm_without_second_activation(db):
    lifecycle = _lifecycle_module()
    draft = await lifecycle.create_draft_study_project(
        db,
        title="Learn Idempotent Activation",
        source_url="https://example.com/idempotent",
        deadline=date(2026, 7, 15),
        capacity_minutes=45,
        clarification_skipped=False,
        tasks=[
            {
                "title": "Write single activation guard",
                "estimated_minutes": 35,
                "scheduled_date": date(2026, 7, 10),
                "target_minutes": 35,
            }
        ],
    )
    first_activation = await lifecycle.confirm_draft_study_project(db, draft["id"])

    with pytest.raises(ValueError):
        await lifecycle.confirm_draft_study_project(db, draft["id"])

    resources = await _fetchall(db, "SELECT id FROM resources WHERE type = 'study_project'")
    events = await _fetchall(db, "SELECT id FROM events WHERE event_type = 'study_project_activated'")
    tasks = await _fetchall(db, "SELECT id, resource_id FROM tasks")
    assert resources == [{"id": first_activation["resource_id"]}]
    assert events == [{"id": 1}]
    assert tasks == [{"id": 1, "resource_id": first_activation["resource_id"]}]


@pytest.mark.asyncio
async def test_confirm_package_draft_records_activation_event_with_versions_and_created_task_ids(db):
    lifecycle = _lifecycle_module()
    package = await _create_activation_ready_shell(
        db,
        lifecycle,
        client_request_id="req-package-activation-event",
    )

    activated = await lifecycle.confirm_draft_study_project(
        db,
        package["draft_id"],
        draft_version=package["draft_version"],
        actor="learner",
        source="confirm_endpoint",
    )

    assert activated["status"] == "active"
    assert activated["resource_id"] > 0
    active_tasks = await _fetchall(
        db,
        "SELECT id, title, scheduled_date, target_minutes FROM tasks ORDER BY id",
    )
    assert active_tasks == [
        {
            "id": 1,
            "title": "Read activation notes",
            "scheduled_date": "2026-08-10",
            "target_minutes": 40,
        }
    ]
    stored_draft = await _fetchone(
        db,
        "SELECT status, activated_resource_id FROM study_project_drafts WHERE id = ?",
        (package["draft_id"],),
    )
    assert stored_draft == {
        "status": "active_plan",
        "activated_resource_id": activated["resource_id"],
    }
    event = await _fetchone(
        db,
        "SELECT payload FROM events WHERE event_type = 'study_project_activated'",
    )
    payload = json.loads(event["payload"])
    assert payload["draft_id"] == package["draft_id"]
    assert payload["intake_item_id"] == package["intake_id"]
    assert payload["activated_draft_version"] == package["draft_version"]
    assert payload["schedule_version"] == "schedule-v1"
    assert payload["resource_id"] == activated["resource_id"]
    assert payload["target_plan_id"] is None
    assert payload["created_active_task_ids"] == [1]
    assert payload["assumptions"]["deadline"]["value"] == "2026-07-15"
    assert payload["actor"] == "learner"
    assert payload["source"] == "confirm_endpoint"
    assert payload["activated_at"]


@pytest.mark.asyncio
async def test_confirm_package_draft_rejects_stale_requested_version_without_active_rows(db):
    lifecycle = _lifecycle_module()
    first = await _create_activation_ready_shell(
        db,
        lifecycle,
        client_request_id="req-stale-activation",
    )
    await lifecycle.create_meaningful_draft_edit_version(
        db,
        draft_id=first["draft_id"],
        edit_kind="scope",
        package_updates={
            "summary": "Newer activation-ready draft",
            "tasks": _activation_ready_tasks(scheduled_date="2026-08-11"),
            "activation_eligibility": {
                "activation_ready": True,
                "schedule_version": "schedule-v2",
            },
        },
    )

    with pytest.raises(ValueError, match="stale"):
        await lifecycle.confirm_draft_study_project(
            db,
            first["draft_id"],
            draft_version=first["draft_version"],
        )

    assert await _fetchall(db, "SELECT id FROM resources") == []
    assert await _fetchall(db, "SELECT id FROM units") == []
    assert await _fetchall(db, "SELECT id FROM tasks") == []
    assert await _fetchall(db, "SELECT id FROM events WHERE event_type = 'study_project_activated'") == []
    assert await _fetchone(
        db,
        "SELECT status, latest_version FROM study_project_drafts WHERE id = ?",
        (first["draft_id"],),
    ) == {"status": "draft_review", "latest_version": 2}


@pytest.mark.asyncio
@pytest.mark.parametrize("blocked_status", ["needs_input", "compile_failed"])
async def test_confirm_package_draft_allows_latest_activatable_before_newer_blocked_version(
    db,
    blocked_status,
):
    lifecycle = _lifecycle_module()
    first = await _create_activation_ready_shell(
        db,
        lifecycle,
        client_request_id=f"req-latest-activatable-before-{blocked_status}",
    )
    await _force_package_version(
        db,
        draft_id=first["draft_id"],
        draft_version=2,
        intake_id=first["intake_id"],
        status=blocked_status,
        summary=f"Newer {blocked_status} package",
    )

    activated = await lifecycle.confirm_draft_study_project(
        db,
        first["draft_id"],
        draft_version=first["draft_version"],
    )

    assert activated["status"] == "active"
    assert await _fetchone(
        db,
        "SELECT status, draft_version, latest_version, activated_resource_id FROM study_project_drafts WHERE id = ?",
        (first["draft_id"],),
    ) == {
        "status": "active_plan",
        "draft_version": 2,
        "latest_version": 2,
        "activated_resource_id": activated["resource_id"],
    }
    assert await _fetchall(db, "SELECT id FROM events WHERE event_type = 'study_project_activated'") == [
        {"id": 1}
    ]


@pytest.mark.asyncio
async def test_confirm_infeasible_review_package_can_activate_when_activation_ready(db):
    lifecycle = _lifecycle_module()
    package = await _create_activation_ready_shell(
        db,
        lifecycle,
        client_request_id="req-infeasible-review-activation-ready",
        status="infeasible_review",
    )

    activated = await lifecycle.confirm_draft_study_project(
        db,
        package["draft_id"],
        draft_version=package["draft_version"],
    )

    assert activated["status"] == "active"
    assert await _fetchall(db, "SELECT title FROM tasks ORDER BY id") == [
        {"title": "Read activation notes"}
    ]


@pytest.mark.asyncio
async def test_confirm_package_draft_rejects_missing_activation_ready_schedule_slices(db):
    lifecycle = _lifecycle_module()
    package = await _create_activation_ready_shell(
        db,
        lifecycle,
        client_request_id="req-missing-slices",
        tasks=_activation_ready_tasks(include_slices=False),
    )

    with pytest.raises(ValueError, match="activation-ready"):
        await lifecycle.confirm_draft_study_project(db, package["draft_id"])

    assert await _fetchall(db, "SELECT id FROM resources") == []
    assert await _fetchall(db, "SELECT id FROM tasks") == []
    assert await _fetchone(
        db,
        "SELECT status FROM study_project_drafts WHERE id = ?",
        (package["draft_id"],),
    ) == {"status": "draft_review"}


@pytest.mark.asyncio
async def test_confirm_package_draft_rejects_missing_schedule_version_without_active_rows(db):
    lifecycle = _lifecycle_module()
    package = await _create_activation_ready_shell(
        db,
        lifecycle,
        client_request_id="req-missing-schedule-version",
        activation_eligibility={"activation_ready": True},
    )

    with pytest.raises(ValueError, match="schedule version"):
        await lifecycle.confirm_draft_study_project(db, package["draft_id"])

    assert await _fetchall(db, "SELECT id FROM resources") == []
    assert await _fetchall(db, "SELECT id FROM units") == []
    assert await _fetchall(db, "SELECT id FROM tasks") == []
    assert await _fetchall(db, "SELECT id FROM events WHERE event_type = 'study_project_activated'") == []
    assert await _fetchone(
        db,
        "SELECT status, activated_resource_id FROM study_project_drafts WHERE id = ?",
        (package["draft_id"],),
    ) == {"status": "draft_review", "activated_resource_id": None}


@pytest.mark.asyncio
@pytest.mark.parametrize("status", ["needs_input", "compile_failed"])
async def test_confirm_package_draft_rejects_non_activatable_states_without_active_rows(
    db,
    status,
):
    lifecycle = _lifecycle_module()
    package = await _create_activation_ready_shell(
        db,
        lifecycle,
        client_request_id=f"req-non-activatable-{status}",
        status=status,
        activation_eligibility={"activation_ready": False, "schedule_version": "schedule-v1"},
    )

    with pytest.raises(ValueError, match="not reviewable"):
        await lifecycle.confirm_draft_study_project(db, package["draft_id"])

    assert await _fetchall(db, "SELECT id FROM resources") == []
    assert await _fetchall(db, "SELECT id FROM units") == []
    assert await _fetchall(db, "SELECT id FROM tasks") == []
    assert await _fetchall(db, "SELECT id FROM events WHERE event_type = 'study_project_activated'") == []
    assert await _fetchone(
        db,
        "SELECT status, activated_resource_id FROM study_project_drafts WHERE id = ?",
        (package["draft_id"],),
    ) == {"status": status, "activated_resource_id": None}


@pytest.mark.asyncio
async def test_save_package_shell_rejects_invalid_anchor_to_draft_review_transition(db):
    lifecycle = _lifecycle_module()
    intake_item_id = await _create_intake(db, "req-invalid-anchor-to-draft-review")
    shell = await lifecycle.create_or_load_draft_shell(
        db,
        intake_item_id=intake_item_id,
        title="Invalid Transition",
        source_url="https://example.com/invalid-transition",
        deadline="2026-08-30",
        capacity_minutes=60,
        assumptions=_planning_assumptions(),
    )

    with pytest.raises(ValueError, match="transition"):
        await lifecycle.save_draft_compiler_package_shell(
            db,
            draft_id=shell["id"],
            status="draft_review",
            summary="Skipped compiling",
            assumptions=_planning_assumptions(),
            activation_eligibility={
                "activation_ready": True,
                "schedule_version": "schedule-v1",
            },
        )

    assert await _fetchone(
        db,
        "SELECT status, draft_version, latest_version, activated_resource_id FROM study_project_drafts WHERE id = ?",
        (shell["id"],),
    ) == {
        "status": "anchor_review",
        "draft_version": 1,
        "latest_version": 1,
        "activated_resource_id": None,
    }
    assert await _fetchall(
        db,
        "SELECT status FROM study_project_draft_versions WHERE draft_id = ?",
        (shell["id"],),
    ) == [{"status": "anchor_review"}]
    assert await _fetchall(db, "SELECT id FROM resources") == []
    assert await _fetchall(db, "SELECT id FROM events") == []


@pytest.mark.asyncio
async def test_meaningful_edit_rejects_invalid_draft_review_to_compiling_transition(db):
    lifecycle = _lifecycle_module()
    package = await _create_activation_ready_shell(
        db,
        lifecycle,
        client_request_id="req-invalid-draft-review-to-compiling",
    )

    with pytest.raises(ValueError, match="transition"):
        await lifecycle.create_meaningful_draft_edit_version(
            db,
            draft_id=package["draft_id"],
            edit_kind="scope",
            package_updates={"status": "compiling", "summary": "Invalid recompile"},
        )

    assert await _fetchone(
        db,
        "SELECT status, draft_version, latest_version FROM study_project_drafts WHERE id = ?",
        (package["draft_id"],),
    ) == {"status": "draft_review", "draft_version": 1, "latest_version": 1}
    assert await _fetchall(
        db,
        "SELECT draft_version, status FROM study_project_draft_versions WHERE draft_id = ? ORDER BY draft_version",
        (package["draft_id"],),
    ) == [{"draft_version": 1, "status": "draft_review"}]
    assert await _fetchall(db, "SELECT id FROM resources") == []
    assert await _fetchall(db, "SELECT id FROM events") == []


@pytest.mark.asyncio
async def test_confirm_package_draft_rolls_back_active_rows_and_status_when_event_insert_fails(db):
    lifecycle = _lifecycle_module()
    package = await _create_activation_ready_shell(
        db,
        lifecycle,
        client_request_id="req-event-rollback",
    )

    with pytest.raises(RuntimeError, match="event insert failure"):
        await lifecycle.confirm_draft_study_project(
            _FailingEventConnection(db),
            package["draft_id"],
        )

    assert await _fetchall(db, "SELECT id FROM resources") == []
    assert await _fetchall(db, "SELECT id FROM units") == []
    assert await _fetchall(db, "SELECT id FROM tasks") == []
    assert await _fetchall(db, "SELECT id FROM events") == []
    assert await _fetchone(
        db,
        "SELECT status, activated_resource_id FROM study_project_drafts WHERE id = ?",
        (package["draft_id"],),
    ) == {"status": "draft_review", "activated_resource_id": None}


@pytest.mark.asyncio
async def test_confirm_existing_plan_package_appends_under_target_without_new_resource(db):
    lifecycle = _lifecycle_module()
    cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Existing Active Plan', 'study_project', 'sequential', 'active', 1)
        """
    )
    target_plan_id = int(cursor.lastrowid)
    await db.commit()
    package = await _create_activation_ready_shell(
        db,
        lifecycle,
        client_request_id="req-target-plan-activation",
        draft_kind="existing_plan_scheduled_work",
        target_plan_id=target_plan_id,
    )

    activated = await lifecycle.confirm_draft_study_project(db, package["draft_id"])

    assert activated["resource_id"] == target_plan_id
    assert await _fetchall(db, "SELECT id, title FROM resources ORDER BY id") == [
        {"id": target_plan_id, "title": "Existing Active Plan"}
    ]
    assert await _fetchall(
        db,
        "SELECT resource_id, title, order_index FROM units ORDER BY id",
    ) == [
        {
            "resource_id": target_plan_id,
            "title": "Read activation notes",
            "order_index": 1,
        }
    ]
    event = await _fetchone(
        db,
        "SELECT payload FROM events WHERE event_type = 'study_project_activated'",
    )
    payload = json.loads(event["payload"])
    assert payload["resource_id"] == target_plan_id
    assert payload["target_plan_id"] == target_plan_id


@pytest.mark.asyncio
async def test_confirm_package_draft_rejects_duplicate_activation_without_second_active_write(db):
    lifecycle = _lifecycle_module()
    package = await _create_activation_ready_shell(
        db,
        lifecycle,
        client_request_id="req-package-duplicate-activation",
    )
    first_activation = await lifecycle.confirm_draft_study_project(db, package["draft_id"])

    with pytest.raises(ValueError, match="already_activated"):
        await lifecycle.confirm_draft_study_project(db, package["draft_id"])

    assert await _fetchall(db, "SELECT id FROM resources WHERE type = 'study_project'") == [
        {"id": first_activation["resource_id"]}
    ]
    assert await _fetchall(db, "SELECT id, resource_id FROM tasks") == [
        {"id": 1, "resource_id": first_activation["resource_id"]}
    ]
    assert await _fetchall(db, "SELECT id FROM events WHERE event_type = 'study_project_activated'") == [
        {"id": 1}
    ]


@pytest.mark.asyncio
async def test_cancel_after_activation_is_rejected_without_changing_active_rows(db):
    lifecycle = _lifecycle_module()
    package = await _create_activation_ready_shell(
        db,
        lifecycle,
        client_request_id="req-cancel-after-activation",
    )
    activated = await lifecycle.confirm_draft_study_project(db, package["draft_id"])

    with pytest.raises(ValueError, match="activated"):
        await lifecycle.cancel_draft_study_project(db, package["draft_id"])

    assert await _fetchone(
        db,
        "SELECT status, activated_resource_id FROM study_project_drafts WHERE id = ?",
        (package["draft_id"],),
    ) == {"status": "active_plan", "activated_resource_id": activated["resource_id"]}
    assert await _fetchall(
        db,
        "SELECT resource_id, title FROM tasks ORDER BY id",
    ) == [{"resource_id": activated["resource_id"], "title": "Read activation notes"}]


@pytest.mark.asyncio
async def test_confirm_draft_study_project_rechecks_review_state_inside_transaction(db):
    lifecycle = _lifecycle_module()
    draft = await lifecycle.create_draft_study_project(
        db,
        title="Learn Transactional Activation",
        source_url="https://example.com/transactional",
        deadline=date(2026, 7, 20),
        capacity_minutes=50,
        clarification_skipped=True,
        tasks=[
            {
                "title": "Guard activation transition",
                "estimated_minutes": 50,
                "scheduled_date": date(2026, 7, 18),
                "target_minutes": 50,
            }
        ],
    )

    async def cancel_before_transaction() -> None:
        await db.execute(
            "UPDATE study_project_drafts SET status = 'cancelled' WHERE id = ?",
            (draft["id"],),
        )
        await db.commit()

    racing_db = _BeforeBeginConnection(db, cancel_before_transaction)

    with pytest.raises(ValueError):
        await lifecycle.confirm_draft_study_project(racing_db, draft["id"])

    stored_draft = await _fetchone(
        db,
        "SELECT status, activated_resource_id FROM study_project_drafts WHERE id = ?",
        (draft["id"],),
    )
    assert stored_draft == {"status": "cancelled", "activated_resource_id": None}
    assert await _fetchall(db, "SELECT id FROM resources WHERE type = 'study_project'") == []
    assert await _fetchall(db, "SELECT id FROM tasks") == []
    assert await _fetchall(db, "SELECT id FROM events WHERE event_type = 'study_project_activated'") == []
