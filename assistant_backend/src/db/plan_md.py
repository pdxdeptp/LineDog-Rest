import asyncio
import os

import aiofiles
import aiosqlite

_lock = asyncio.Lock()


async def read_plan_md(plan_path: str) -> str:
    if not os.path.exists(plan_path):
        return ""
    async with aiofiles.open(plan_path, "r", encoding="utf-8") as f:
        return await f.read()


async def write_plan_md(plan_path: str, content: str) -> None:
    async with _lock:
        async with aiofiles.open(plan_path, "w", encoding="utf-8") as f:
            await f.write(content)


async def snapshot_to_db(db: aiosqlite.Connection, content: str, triggered_by: str, change_summary: str | None = None) -> None:
    await db.execute(
        "INSERT INTO plan_versions (content, change_summary, triggered_by) VALUES (?, ?, ?)",
        (content, change_summary, triggered_by),
    )
    await db.commit()
