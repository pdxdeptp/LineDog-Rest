import aiosqlite
from .schema import SCHEMA_SQL, DEFAULT_SYSTEM_STATE


TASK_ADJUSTMENT_COLUMNS = {
    "auto_roll_days": "INTEGER DEFAULT 0",
    "last_auto_rolled_at": "DATE",
    "user_adjusted_at": "TIMESTAMP",
}

TASK_FALLBACK_COLUMNS = {
    "fallback_completed_at": "TIMESTAMP",
    "fallback_actual_minutes": "INTEGER",
    "needs_followup": "INTEGER DEFAULT 0",
}

DRAFT_HEADER_COLUMNS = {
    "intake_item_id": "INTEGER REFERENCES study_intake_items(id)",
    "schema_version": "INTEGER NOT NULL DEFAULT 1",
    "draft_version": "INTEGER NOT NULL DEFAULT 1",
    "latest_version": "INTEGER NOT NULL DEFAULT 1",
    "calibration_level": "TEXT NOT NULL DEFAULT 'standard'",
    "draft_kind": "TEXT NOT NULL DEFAULT 'new_plan'",
    "target_plan_id": "INTEGER REFERENCES resources(id)",
    "updated_at": "TIMESTAMP",
}

DRAFT_TASK_COLUMNS = {
    "stable_task_id": "TEXT",
    "phase_id": "TEXT",
    "status": "TEXT NOT NULL DEFAULT 'draft'",
    "metadata": "TEXT",
    "schedule_slices": "TEXT",
}


async def _existing_columns(db: aiosqlite.Connection, table_name: str) -> set[str]:
    async with db.execute(f"PRAGMA table_info({table_name})") as cursor:
        return {row[1] for row in await cursor.fetchall()}


async def _ensure_columns(
    db: aiosqlite.Connection,
    table_name: str,
    columns: dict[str, str],
) -> None:
    existing_columns = await _existing_columns(db, table_name)
    for column_name, column_definition in columns.items():
        if column_name not in existing_columns:
            await db.execute(
                f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_definition}"
            )


async def _ensure_task_adjustment_columns(db: aiosqlite.Connection) -> None:
    await _ensure_columns(db, "tasks", TASK_ADJUSTMENT_COLUMNS)


async def _ensure_task_fallback_columns(db: aiosqlite.Connection) -> None:
    await _ensure_columns(db, "tasks", TASK_FALLBACK_COLUMNS)


async def _ensure_draft_storage_columns(db: aiosqlite.Connection) -> None:
    await _ensure_columns(db, "study_project_drafts", DRAFT_HEADER_COLUMNS)
    await _ensure_columns(db, "study_project_draft_tasks", DRAFT_TASK_COLUMNS)

    await db.execute(
        """
        UPDATE study_project_drafts
        SET updated_at = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP)
        WHERE updated_at IS NULL
        """
    )
    await db.execute(
        "UPDATE study_project_draft_tasks SET status = 'draft' WHERE status IS NULL"
    )
    await db.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_study_project_drafts_intake_kind
        ON study_project_drafts(intake_item_id, draft_kind)
        """
    )


async def init_db(db_path: str) -> None:
    async with aiosqlite.connect(db_path) as db:
        await db.executescript(SCHEMA_SQL)
        await _ensure_task_adjustment_columns(db)
        await _ensure_task_fallback_columns(db)
        await _ensure_draft_storage_columns(db)
        for key, value in DEFAULT_SYSTEM_STATE.items():
            await db.execute(
                "INSERT OR IGNORE INTO system_state (key, value) VALUES (?, ?)",
                (key, value),
            )
        for key in ("daily_capacity_min", "reduced_capacity_min"):
            await db.execute(
                "UPDATE system_state SET value = '60' WHERE key = ? AND value = '300'",
                (key,),
            )
        await db.commit()
