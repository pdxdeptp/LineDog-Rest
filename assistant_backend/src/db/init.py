import aiosqlite
from .schema import SCHEMA_SQL, DEFAULT_SYSTEM_STATE


async def init_db(db_path: str) -> None:
    async with aiosqlite.connect(db_path) as db:
        await db.executescript(SCHEMA_SQL)
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
