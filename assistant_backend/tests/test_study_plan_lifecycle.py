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
