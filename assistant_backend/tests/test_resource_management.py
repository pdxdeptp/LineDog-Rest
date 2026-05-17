"""Resource management API tests."""

import asyncio
import json
import os
from contextlib import asynccontextmanager
from datetime import date, timedelta

import aiosqlite
import pytest

from src.db.queries import (
    ResourceNotActiveError,
    archive_active_resource,
    mark_active_resource_complete,
)


@asynccontextmanager
async def _client_db():
    async with aiosqlite.connect(os.environ["DB_PATH"]) as conn:
        conn.row_factory = aiosqlite.Row
        yield conn


async def _fetchone(db: aiosqlite.Connection, sql: str, params: tuple = ()) -> dict | None:
    async with db.execute(sql, params) as cur:
        row = await cur.fetchone()
    return dict(row) if row else None


async def _fetchall(db: aiosqlite.Connection, sql: str, params: tuple = ()) -> list[dict]:
    async with db.execute(sql, params) as cur:
        rows = await cur.fetchall()
    return [dict(row) for row in rows]


class _TwoPartyBarrier:
    def __init__(self) -> None:
        self._count = 0
        self._event = asyncio.Event()

    async def wait(self) -> None:
        self._count += 1
        if self._count == 2:
            self._event.set()
        await asyncio.wait_for(self._event.wait(), timeout=2)

    @property
    def arrivals(self) -> int:
        return self._count


class _BarrierExecute:
    def __init__(self, operation, barrier: _TwoPartyBarrier) -> None:
        self._operation = operation
        self._barrier = barrier
        self._cursor = None

    async def _wait_after_execute(self):
        cursor = await self._operation
        await self._barrier.wait()
        return cursor

    def __await__(self):
        return self._wait_after_execute().__await__()

    async def __aenter__(self):
        self._cursor = await self._wait_after_execute()
        return self._cursor

    async def __aexit__(self, exc_type, exc, tb) -> None:
        if self._cursor is not None:
            await self._cursor.close()


class _BarrierBeforeExecute(_BarrierExecute):
    async def _wait_after_execute(self):
        await self._barrier.wait()
        return await self._operation


class _RaceAtTransactionStartConnection:
    def __init__(self, conn: aiosqlite.Connection, barrier: _TwoPartyBarrier) -> None:
        self._conn = conn
        self._barrier = barrier

    def execute(self, sql: str, params: tuple = ()):
        operation = self._conn.execute(sql, params)
        normalized = " ".join(sql.split()).lower()
        if normalized == "begin immediate":
            return _BarrierBeforeExecute(operation, self._barrier)
        return operation

    def __getattr__(self, name: str):
        return getattr(self._conn, name)


async def _insert_active_resource(
    db: aiosqlite.Connection,
    resource_id: int,
    title: str = "Backend Course",
    total_units: int = 3,
    completed_units: int = 1,
) -> None:
    await db.execute(
        """
        INSERT INTO resources
            (id, title, type, tracking_mode, status, total_units, completed_units)
        VALUES (?, ?, 'course', 'sequential', 'active', ?, ?)
        """,
        (resource_id, title, total_units, completed_units),
    )


@pytest.mark.asyncio
async def test_mark_active_resource_complete_marks_units_writes_event_and_excludes_resource(client):
    resource_id = 101
    async with _client_db() as db:
        await _insert_active_resource(db, resource_id)
        await db.executemany(
            """
            INSERT INTO units (resource_id, title, order_index, status, completed_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            [
                (resource_id, "Unit 1", 0, "completed", "2026-05-01T00:00:00"),
                (resource_id, "Unit 2", 1, "pending", None),
                (resource_id, "Unit 3", 2, "in_progress", None),
            ],
        )
        await db.commit()

    response = await client.post(f"/api/resources/{resource_id}/complete")

    assert response.status_code == 200, response.text
    assert response.json()["status"] == "completed"

    async with _client_db() as db:
        resource = await _fetchone(
            db,
            "SELECT status, total_units, completed_units FROM resources WHERE id = ?",
            (resource_id,),
        )
        assert resource == {"status": "completed", "total_units": 3, "completed_units": 3}

        units = await _fetchall(
            db,
            "SELECT status, completed_at FROM units WHERE resource_id = ? ORDER BY order_index",
            (resource_id,),
        )
        assert units[0] == {"status": "completed", "completed_at": "2026-05-01T00:00:00"}
        assert units[1]["status"] == "completed"
        assert units[1]["completed_at"] is not None
        assert units[2]["status"] == "completed"
        assert units[2]["completed_at"] is not None

        events = await _fetchall(
            db,
            "SELECT event_type, payload FROM events WHERE event_type = 'resource_completed'",
        )
        assert len(events) == 1
        payload = json.loads(events[0]["payload"])
        assert payload["resource_id"] == resource_id
        assert payload["source"] == "user_action"

    resources_response = await client.get("/api/resources")
    assert resources_response.status_code == 200
    assert resource_id not in [resource["id"] for resource in resources_response.json()]


@pytest.mark.asyncio
async def test_mark_active_resource_complete_marks_today_and_future_incomplete_tasks_completed(client):
    resource_id = 151
    other_resource_id = 152
    today = date.today()
    yesterday = today - timedelta(days=1)
    tomorrow = today + timedelta(days=1)
    prior_completion = "2026-05-01T00:00:00"

    async with _client_db() as db:
        await _insert_active_resource(db, resource_id, title="Complete Course", total_units=2)
        await _insert_active_resource(db, other_resource_id, title="Other Course", total_units=1, completed_units=0)
        await db.executemany(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, completed_at)
            VALUES (?, ?, ?, 'time', 30, ?, ?)
            """,
            [
                (9101, resource_id, "Past incomplete", yesterday.isoformat(), None),
                (9102, resource_id, "Today incomplete", today.isoformat(), None),
                (9103, resource_id, "Future incomplete", tomorrow.isoformat(), None),
                (9104, resource_id, "Future completed", tomorrow.isoformat(), prior_completion),
                (9105, other_resource_id, "Other resource future", tomorrow.isoformat(), None),
            ],
        )
        await db.commit()

    response = await client.post(f"/api/resources/{resource_id}/complete")

    assert response.status_code == 200, response.text

    async with _client_db() as db:
        tasks = await _fetchall(
            db,
            "SELECT id, completed_at FROM tasks ORDER BY id",
        )

    by_id = {task["id"]: task["completed_at"] for task in tasks}
    assert by_id[9101] is None
    assert by_id[9102] is not None
    assert by_id[9103] is not None
    assert by_id[9104] == prior_completion
    assert by_id[9105] is None


@pytest.mark.asyncio
async def test_archive_active_resource_removes_future_incomplete_tasks_and_preserves_history(client):
    resource_id = 201
    other_resource_id = 202
    today = date.today()
    yesterday = today - timedelta(days=1)
    tomorrow = today + timedelta(days=1)

    async with _client_db() as db:
        await _insert_active_resource(db, resource_id, title="Archive Course", total_units=2)
        await _insert_active_resource(db, other_resource_id, title="Other Course", total_units=1, completed_units=0)
        await db.executemany(
            "INSERT INTO units (resource_id, title, order_index, status) VALUES (?, ?, ?, ?)",
            [
                (resource_id, "Archive Unit 1", 0, "completed"),
                (resource_id, "Archive Unit 2", 1, "pending"),
            ],
        )
        await db.executemany(
            """
            INSERT INTO tasks
                (id, resource_id, title, task_kind, target_minutes, scheduled_date, completed_at)
            VALUES (?, ?, ?, 'time', 30, ?, ?)
            """,
            [
                (9001, resource_id, "Past incomplete", yesterday.isoformat(), None),
                (9002, resource_id, "Today incomplete", today.isoformat(), None),
                (9003, resource_id, "Future incomplete", tomorrow.isoformat(), None),
                (9004, resource_id, "Future completed", tomorrow.isoformat(), "2026-05-01T00:00:00"),
                (9005, other_resource_id, "Other resource future", tomorrow.isoformat(), None),
            ],
        )
        await db.execute(
            "INSERT INTO events (event_type, payload) VALUES ('resource_seen', ?)",
            (json.dumps({"resource_id": resource_id}),),
        )
        await db.commit()

    response = await client.post(f"/api/resources/{resource_id}/archive")

    assert response.status_code == 200, response.text
    assert response.json()["status"] == "archived"

    async with _client_db() as db:
        resource = await _fetchone(
            db,
            "SELECT status FROM resources WHERE id = ?",
            (resource_id,),
        )
        assert resource == {"status": "archived"}

        units = await _fetchall(
            db,
            "SELECT title, status FROM units WHERE resource_id = ? ORDER BY order_index",
            (resource_id,),
        )
        assert units == [
            {"title": "Archive Unit 1", "status": "completed"},
            {"title": "Archive Unit 2", "status": "pending"},
        ]

        remaining_tasks = await _fetchall(db, "SELECT id FROM tasks ORDER BY id")
        assert [task["id"] for task in remaining_tasks] == [9001, 9004, 9005]

        future_active_tasks = await _fetchall(
            db,
            """
            SELECT id FROM tasks
            WHERE resource_id = ?
              AND scheduled_date >= ?
              AND completed_at IS NULL
            """,
            (resource_id, today.isoformat()),
        )
        assert future_active_tasks == []

        events = await _fetchall(
            db,
            "SELECT event_type, payload FROM events ORDER BY id",
        )
        assert [event["event_type"] for event in events] == ["resource_seen", "resource_archived"]
        archived_payload = json.loads(events[-1]["payload"])
        assert archived_payload["resource_id"] == resource_id
        assert archived_payload["source"] == "user_action"

    resources_response = await client.get("/api/resources")
    assert resources_response.status_code == 200
    assert resource_id not in [resource["id"] for resource in resources_response.json()]


@pytest.mark.asyncio
@pytest.mark.parametrize("action", ["complete", "archive"])
async def test_resource_management_invalidates_today_briefing_cache(client, action):
    resource_id = 251
    today = date.today().isoformat()
    yesterday = (date.today() - timedelta(days=1)).isoformat()
    today_key = f"briefing_{today}"
    yesterday_key = f"briefing_{yesterday}"

    async with _client_db() as db:
        await _insert_active_resource(db, resource_id, title="Cached Course")
        await db.execute(
            "INSERT INTO system_state (key, value) VALUES (?, ?)",
            (today_key, json.dumps({"stale": True})),
        )
        await db.execute(
            "INSERT INTO system_state (key, value) VALUES (?, ?)",
            (yesterday_key, json.dumps({"keep": True})),
        )
        await db.commit()

    response = await client.post(f"/api/resources/{resource_id}/{action}")

    assert response.status_code == 200, response.text

    async with _client_db() as db:
        today_cache = await _fetchone(
            db,
            "SELECT value FROM system_state WHERE key = ?",
            (today_key,),
        )
        yesterday_cache = await _fetchone(
            db,
            "SELECT value FROM system_state WHERE key = ?",
            (yesterday_key,),
        )

    assert today_cache is None
    assert yesterday_cache == {"value": json.dumps({"keep": True})}


@pytest.mark.asyncio
@pytest.mark.parametrize("action,event_type", [
    ("complete", "resource_completed"),
    ("archive", "resource_archived"),
])
@pytest.mark.parametrize("resource_status", ["completed", "archived"])
async def test_resource_management_rejects_non_active_resources_without_event(
    client,
    action,
    event_type,
    resource_status,
):
    resource_id = 301
    async with _client_db() as db:
        await db.execute(
            """
            INSERT INTO resources
                (id, title, type, tracking_mode, status, total_units, completed_units)
            VALUES (?, 'Done Course', 'course', 'sequential', ?, 1, 1)
            """,
            (resource_id, resource_status),
        )
        await db.commit()

    response = await client.post(f"/api/resources/{resource_id}/{action}")

    assert response.status_code == 409, response.text

    async with _client_db() as db:
        event_count = await _fetchone(
            db,
            "SELECT COUNT(*) AS count FROM events WHERE event_type = ?",
            (event_type,),
        )
        assert event_count == {"count": 0}


@pytest.mark.asyncio
@pytest.mark.parametrize("operation,event_type", [
    (mark_active_resource_complete, "resource_completed"),
    (archive_active_resource, "resource_archived"),
])
async def test_concurrent_resource_management_allows_only_one_active_transition(
    client,
    operation,
    event_type,
):
    resource_id = 401
    async with _client_db() as db:
        await _insert_active_resource(db, resource_id)
        await db.commit()

    barrier = _TwoPartyBarrier()

    async def run_operation() -> str:
        async with aiosqlite.connect(os.environ["DB_PATH"]) as raw_db:
            raw_db.row_factory = aiosqlite.Row
            db = _RaceAtTransactionStartConnection(raw_db, barrier)
            try:
                await operation(db, resource_id)
                return "ok"
            except ResourceNotActiveError:
                return "inactive"

    results = await asyncio.gather(run_operation(), run_operation())

    assert barrier.arrivals == 2
    assert sorted(results) == ["inactive", "ok"]

    async with _client_db() as db:
        event_count = await _fetchone(
            db,
            "SELECT COUNT(*) AS count FROM events WHERE event_type = ?",
            (event_type,),
        )
        assert event_count == {"count": 1}


@pytest.mark.asyncio
@pytest.mark.parametrize("action,event_type", [
    ("complete", "resource_completed"),
    ("archive", "resource_archived"),
])
async def test_resource_management_rejects_unknown_resources_without_event(client, action, event_type):
    response = await client.post(f"/api/resources/999/{action}")

    assert response.status_code == 404, response.text
    assert response.json()["detail"] == "Resource not found"

    async with _client_db() as db:
        event_count = await _fetchone(
            db,
            "SELECT COUNT(*) AS count FROM events WHERE event_type = ?",
            (event_type,),
        )
        assert event_count == {"count": 0}
