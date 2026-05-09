"""
Ingest Router

POST /api/ingest          — start ingestion graph, return draft for user review
POST /api/ingest/confirm  — resume graph after user decision
"""
from __future__ import annotations

import uuid
from typing import Literal

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from ..agents.ingestion_agent import ingestion_graph

router = APIRouter()


# ---------------------------------------------------------------------------
# Request / Response models
# ---------------------------------------------------------------------------

class IngestRequest(BaseModel):
    url: str
    deadline: str                    # ISO date "2026-06-30"
    speed_factor: float = 1.0


class ConfirmRequest(BaseModel):
    thread_id: str
    confirmed: bool
    selected_option: str = "A"       # "A" | "B"


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

@router.post("/ingest")
async def start_ingest(req: IngestRequest) -> dict:
    """
    Start the ingestion graph.

    Returns the draft (option_a, option_b, resource summary) once the graph
    reaches the interrupt point.
    """
    thread_id = str(uuid.uuid4())
    config = {"configurable": {"thread_id": thread_id}}

    initial_state = {
        "url": req.url,
        "deadline": req.deadline,
        "speed_factor": req.speed_factor,
    }

    # Run until the interrupt
    try:
        await ingestion_graph.ainvoke(initial_state, config)
    except Exception as exc:
        # If the graph raised for any other reason, surface it
        raise HTTPException(status_code=500, detail=str(exc))

    # Retrieve the interrupt value (draft summary)
    draft = _get_interrupt_value(thread_id)
    if draft is None:
        # Graph completed without interrupting — shouldn't normally happen
        state_snapshot = ingestion_graph.get_state(config)
        final = state_snapshot.values if state_snapshot else {}
        return {
            "thread_id": thread_id,
            "status": "completed",
            "resource_id": final.get("resource_id"),
        }

    return {
        "thread_id": thread_id,
        "status": "pending_confirmation",
        "draft": draft,
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
        raise HTTPException(status_code=404, detail="Thread not found")

    if not req.confirmed:
        return {"status": "cancelled"}

    # Resume with the user's choice using Command(resume=...)
    user_response = {
        "confirmed": req.confirmed,
        "selected_option": req.selected_option,
    }

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
