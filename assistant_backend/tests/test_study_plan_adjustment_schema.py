import json

import aiosqlite
import pytest


async def _table_columns(db: aiosqlite.Connection, table_name: str) -> dict[str, dict]:
    async with db.execute(f"PRAGMA table_info({table_name})") as cursor:
        rows = await cursor.fetchall()
    return {
        row[1]: {
            "type": row[2],
            "notnull": row[3],
            "default": row[4],
        }
        for row in rows
    }


@pytest.mark.asyncio
async def test_init_db_creates_adjustment_metadata_and_default_rest_day_settings(tmp_path):
    from src.db.init import init_db

    db_path = str(tmp_path / "new-adjustment.db")

    await init_db(db_path)

    async with aiosqlite.connect(db_path) as db:
        task_columns = await _table_columns(db, "tasks")
        async with db.execute(
            """
            SELECT key, value
            FROM system_state
            WHERE key IN ('study_rest_weekdays', 'study_rest_dates')
            ORDER BY key
            """
        ) as cursor:
            rest_state = dict(await cursor.fetchall())

    assert task_columns["auto_roll_days"]["default"] == "0"
    assert "last_auto_rolled_at" in task_columns
    assert "user_adjusted_at" in task_columns
    assert json.loads(rest_state["study_rest_weekdays"]) == [5]
    assert json.loads(rest_state["study_rest_dates"]) == []


@pytest.mark.asyncio
async def test_init_db_migrates_existing_tasks_and_rest_day_settings(tmp_path):
    from src.db.init import init_db

    db_path = str(tmp_path / "existing-adjustment.db")
    async with aiosqlite.connect(db_path) as db:
        await db.execute(
            """
            CREATE TABLE tasks (
                id                        INTEGER PRIMARY KEY,
                unit_id                   INTEGER,
                resource_id               INTEGER,
                title                     TEXT    NOT NULL,
                task_kind                 TEXT    NOT NULL DEFAULT 'count',
                target_count              INTEGER,
                target_minutes            INTEGER,
                scheduled_date            DATE    NOT NULL,
                originally_scheduled_date DATE,
                reschedule_count          INTEGER DEFAULT 0,
                priority                  INTEGER DEFAULT 0,
                completed_at              TIMESTAMP,
                actual_minutes            INTEGER,
                created_at                TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        await db.execute(
            """
            CREATE TABLE system_state (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        await db.execute(
            "INSERT INTO tasks (id, title, scheduled_date) VALUES (1, 'Legacy task', '2026-06-01')"
        )
        await db.commit()

    await init_db(db_path)

    async with aiosqlite.connect(db_path) as db:
        task_columns = await _table_columns(db, "tasks")
        async with db.execute(
            """
            SELECT auto_roll_days, last_auto_rolled_at, user_adjusted_at
            FROM tasks
            WHERE id = 1
            """
        ) as cursor:
            legacy_task = await cursor.fetchone()
        async with db.execute(
            """
            SELECT key, value
            FROM system_state
            WHERE key IN ('study_rest_weekdays', 'study_rest_dates')
            ORDER BY key
            """
        ) as cursor:
            rest_state = dict(await cursor.fetchall())

    assert {"auto_roll_days", "last_auto_rolled_at", "user_adjusted_at"} <= set(task_columns)
    assert legacy_task == (0, None, None)
    assert json.loads(rest_state["study_rest_weekdays"]) == [5]
    assert json.loads(rest_state["study_rest_dates"]) == []
