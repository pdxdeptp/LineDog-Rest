import json

from fastapi import APIRouter, HTTPException

from ..agents.morning_agent import run_morning_agent
from ..db.connection import get_db
from ..db.queries import get_system_state

router = APIRouter()


@router.post("/morning-briefing")
async def trigger_morning_briefing() -> dict:
    """Triggered by macOS LaunchAgent on login. Idempotent within same calendar day."""
    briefing = await run_morning_agent()
    return briefing


@router.get("/today-briefing")
async def get_today_briefing() -> dict:
    """Return today's briefing (cached if already generated, trigger if not)."""
    from datetime import date
    today = date.today().isoformat()

    async with get_db() as db:
        cached = await get_system_state(db, f"briefing_{today}")

    if cached:
        try:
            return json.loads(cached)
        except Exception:
            pass

    briefing = await run_morning_agent()
    return briefing


@router.get("/resources")
async def list_resources() -> list[dict]:
    """Return all active resources with progress info."""
    from ..db.queries import get_all_active_resources
    async with get_db() as db:
        resources = await get_all_active_resources(db)
    return resources
