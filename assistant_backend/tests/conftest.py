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
    """
    Async HTTPX test client that properly triggers FastAPI lifespan.

    httpx.ASGITransport does NOT send the ASGI lifespan scope, so routes
    registered inside the @asynccontextmanager lifespan would never be mounted
    with a plain ASGITransport.  This fixture manually fires the lifespan
    protocol (startup / shutdown) via anyio memory streams so that all
    include_router() calls execute before the first request is made.
    """
    import asyncio
    import math
    import sys

    import anyio
    import httpx

    os.environ["DB_PATH"] = str(tmp_path / "test.db")
    os.environ["PLAN_MD_PATH"] = str(tmp_path / "plan.md")

    # Clear cached module state so config re-reads env
    for mod in list(sys.modules.keys()):
        if mod.startswith("src."):
            del sys.modules[mod]

    from src.main import app

    test_to_app_send, test_to_app_recv = anyio.create_memory_object_stream(math.inf)
    app_to_test_send, app_to_test_recv = anyio.create_memory_object_stream(math.inf)

    scope = {"type": "lifespan", "asgi": {"version": "3.0"}, "state": {}}

    lifespan_task = asyncio.create_task(
        app(scope, test_to_app_recv.receive, app_to_test_send.send)
    )

    # Trigger startup
    await test_to_app_send.send({"type": "lifespan.startup"})
    await app_to_test_recv.receive()  # lifespan.startup.complete

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as http_client:
        yield http_client

    # Trigger shutdown
    await test_to_app_send.send({"type": "lifespan.shutdown"})
    await app_to_test_recv.receive()  # lifespan.shutdown.complete

    lifespan_task.cancel()
    try:
        await lifespan_task
    except (asyncio.CancelledError, Exception):
        pass
