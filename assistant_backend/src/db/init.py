import aiosqlite
from .schema import SCHEMA_SQL, DEFAULT_SYSTEM_STATE


TASK_ADJUSTMENT_COLUMNS = {
    "auto_roll_days": "INTEGER DEFAULT 0",
    "last_auto_rolled_at": "DATE",
    "user_adjusted_at": "TIMESTAMP",
}


async def _ensure_task_adjustment_columns(db: aiosqlite.Connection) -> None:
    async with db.execute("PRAGMA table_info(tasks)") as cursor:
        existing_columns = {row[1] for row in await cursor.fetchall()}

    for column_name, column_definition in TASK_ADJUSTMENT_COLUMNS.items():
        if column_name not in existing_columns:
            await db.execute(f"ALTER TABLE tasks ADD COLUMN {column_name} {column_definition}")


async def init_db(db_path: str) -> None:
    async with aiosqlite.connect(db_path) as db:
        await db.executescript(SCHEMA_SQL)
        await _ensure_task_adjustment_columns(db)
        for key, value in DEFAULT_SYSTEM_STATE.items():
            await db.execute(
                "INSERT OR IGNORE INTO system_state (key, value) VALUES (?, ?)",
                (key, value),
            )
        # One-time migration: if daily_capacity_min is still the old default "300", update to "60"
        await db.execute(
            "UPDATE system_state SET value = '60' WHERE key = 'daily_capacity_min' AND value = '300'"
        )
        await db.commit()
