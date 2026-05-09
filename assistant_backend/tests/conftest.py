"""Shared test fixtures."""

import os
import tempfile

import pytest
import pytest_asyncio

os.environ.setdefault("DB_PATH", ":memory:")
os.environ.setdefault("PLAN_MD_PATH", "/tmp/test_plan.md")
os.environ.setdefault("GEMINI_API_KEY", "test-key")


@pytest_asyncio.fixture
async def db():
    """In-memory SQLite DB with schema initialized."""
    import aiosqlite
    from src.db.schema import SCHEMA_SQL, DEFAULT_SYSTEM_STATE

    async with aiosqlite.connect(":memory:") as conn:
        conn.row_factory = aiosqlite.Row
        await conn.executescript(SCHEMA_SQL)
        for key, value in DEFAULT_SYSTEM_STATE.items():
            await conn.execute(
                "INSERT OR IGNORE INTO system_state (key, value) VALUES (?, ?)",
                (key, value),
            )
        await conn.commit()
        yield conn


@pytest_asyncio.fixture
async def client(tmp_path):
    """HTTPX async test client against the FastAPI app."""
    import importlib
    import sys

    os.environ["DB_PATH"] = str(tmp_path / "test.db")
    os.environ["PLAN_MD_PATH"] = str(tmp_path / "plan.md")

    # Clear cached module state so config re-reads env
    for mod in list(sys.modules.keys()):
        if mod.startswith("src."):
            del sys.modules[mod]

    import httpx
    from src.main import app

    async with httpx.AsyncClient(app=app, base_url="http://test") as client:
        yield client
