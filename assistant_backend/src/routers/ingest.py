"""
Ingest Router

POST /api/ingest/start        — enqueue ingestion, return thread_id immediately
GET  /api/ingest/progress/{id} — SSE stream of phase events
POST /api/ingest/reschedule   — recompute schedule for a paused thread (no state mutation)
POST /api/ingest/confirm      — resume graph after user decision
"""
from __future__ import annotations

import asyncio
import json
import uuid
from datetime import date

from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from ..agents.ingestion_agent import (
    _run_ingestion_with_progress,
    _schedule_option_a,
    _schedule_option_b,
    ingestion_graph,
    progress_store,
    ThreadProgress,
)
from ..db.connection import get_db
from ..db.queries import check_capacity

router = APIRouter()


# ---------------------------------------------------------------------------
# Request / Response models
# ---------------------------------------------------------------------------

class StartRequest(BaseModel):
    url: str
    deadline: str               # ISO date "2026-06-30"
    speed_factor: float = 1.0


class RescheduleRequest(BaseModel):
    thread_id: str
    deadline: str
    speed_factor: float = 1.0


class ConfirmRequest(BaseModel):
    thread_id: str
    confirmed: bool
    selected_option: str = "B"       # "A" | "B"
    deadline: str | None = None
    speed_factor: float | None = None


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_interrupt_value(thread_id: str) -> dict | None:
    """
    Return the interrupted state payload for a thread.

    When interrupt() fires inside a node, LangGraph stores the interrupt value
    in state_snapshot.tasks[*].interrupts[0].value.
    """
    config = {"configurable": {"thread_id": thread_id}}
    state_snapshot = ingestion_graph.get_state(config)
    if state_snapshot is None:
        return None
    for task in (state_snapshot.tasks or []):
        interrupts = getattr(task, "interrupts", None) or []
        if interrupts:
            return interrupts[0].value if hasattr(interrupts[0], "value") else interrupts[0]
    return None


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post("/ingest/start")
async def start_ingest(req: StartRequest) -> dict:
    """
    Enqueue ingestion in a background task and return thread_id immediately.
    """
    thread_id = str(uuid.uuid4())
    config = {"configurable": {"thread_id": thread_id}}

    initial_state = {
        "url": req.url,
        "deadline": req.deadline,
        "speed_factor": req.speed_factor,
    }

    progress_store[thread_id] = ThreadProgress()
    asyncio.create_task(_run_ingestion_with_progress(thread_id, initial_state, config))

    return {"thread_id": thread_id}


@router.get("/ingest/progress/{thread_id}")
async def ingest_progress(thread_id: str):
    """SSE endpoint: stream phase events for a running ingestion thread."""
    if thread_id not in progress_store:
        raise HTTPException(status_code=404, detail="Thread not found")

    prog = progress_store[thread_id]

    async def generate():
        cursor = 0
        while True:
            # Send all buffered events (supports reconnection)
            while cursor < len(prog.events):
                event = prog.events[cursor]
                cursor += 1
                yield f"event: phase\ndata: {json.dumps(event, ensure_ascii=False)}\n\n"
                if event.get("done"):
                    return

            if prog.is_done:
                return

            # Wait for next event signal
            try:
                await asyncio.wait_for(prog._queue.get(), timeout=300)
            except asyncio.TimeoutError:
                return

    return StreamingResponse(generate(), media_type="text/event-stream")


@router.post("/ingest/reschedule")
async def reschedule_ingest(req: RescheduleRequest) -> dict:
    """
    Recompute scheduling options for a paused ingestion thread.
    Does NOT modify LangGraph state.
    """
    config = {"configurable": {"thread_id": req.thread_id}}
    state_snapshot = ingestion_graph.get_state(config)

    if state_snapshot is None or not state_snapshot.values or not state_snapshot.values.get("resource"):
        raise HTTPException(status_code=404, detail={"error": "thread_not_found"})

    resource = state_snapshot.values["resource"]
    deadline = date.fromisoformat(req.deadline)
    today = date.today()
    speed = req.speed_factor

    async with get_db() as db:
        row = await db.execute("SELECT value FROM system_state WHERE key='daily_capacity_min'")
        row_val = await row.fetchone()
        daily_cap = int(row_val[0]) if row_val else 60
        free_map = await check_capacity(db, today, deadline, daily_cap)

    option_a = _schedule_option_a(resource.units, deadline, free_map, speed)
    option_b = _schedule_option_b(resource.units, deadline, today, speed, daily_cap)

    return {
        "resource_title": resource.title,
        "resource_type": resource.type,
        "total_estimated_hours": resource.total_estimated_hours,
        "unit_count": len(resource.units),
        "option_a": option_a,
        "option_b": option_b,
    }


@router.post("/ingest/confirm")
async def confirm_ingest(req: ConfirmRequest) -> dict:
    """
    Resume the graph after the user has reviewed the draft.

    The graph will write to the database if confirmed=True.
    """
    from langgraph.types import Command

    config = {"configurable": {"thread_id": req.thread_id}}

    # Check the graph is actually waiting
    state_snapshot = ingestion_graph.get_state(config)
    if state_snapshot is None:
        raise HTTPException(status_code=404, detail={"error": "thread_not_found"})

    if not req.confirmed:
        return {"status": "cancelled"}

    # Resume with the user's choice using Command(resume=...)
    user_response: dict = {
        "confirmed": req.confirmed,
        "selected_option": req.selected_option,
    }
    if req.deadline is not None:
        user_response["deadline"] = req.deadline
    if req.speed_factor is not None:
        user_response["speed_factor"] = req.speed_factor

    await ingestion_graph.ainvoke(
        Command(resume=user_response),
        config,
    )

    # Get final state
    final_snapshot = ingestion_graph.get_state(config)
    final_values = final_snapshot.values if final_snapshot else {}

    resource_id = final_values.get("resource_id")
    if resource_id is None:
        error = final_values.get("error")
        raise HTTPException(status_code=500, detail=error or "Write failed")

    return {
        "status": "written",
        "resource_id": resource_id,
    }
