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
        await db.commit()
