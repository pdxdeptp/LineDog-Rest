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

    assert cancelled["status"] == "cancelled"
    stored_draft = await _fetchone(
        db,
        "SELECT status FROM study_project_drafts WHERE id = ?",
        (draft["id"],),
    )
    assert stored_draft == {"status": "cancelled"}
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
    assert stored_draft == {"status": "confirmed", "activated_resource_id": activated["resource_id"]}

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
