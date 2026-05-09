"""
Review router

POST /api/weekly-review/trigger
    Manually trigger a new weekly review run.
    Returns: {thread_id: str, status: "running" | "interrupted"}

POST /api/weekly-review/confirm
    Resume graph execution after the user reviews the draft.
    Body: {thread_id, confirmed, user_edits?, selected_reduced?}
    Returns: {status: "completed" | "cancelled"}

GET  /api/weekly-review/draft/{thread_id}
    Retrieve the current draft (from graph interrupt state).
    Returns: {thread_id, draft, suggest_reduced_load, status}
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from ..agents.weekly_review_agent import (
    memory_saver,
    start_review,
    weekly_review_graph,
)

logger = logging.getLogger(__name__)
router = APIRouter()


# ---------------------------------------------------------------------------
# Request / Response schemas
# ---------------------------------------------------------------------------

class TriggerResponse(BaseModel):
    thread_id: str
    status: str  # "interrupted" once the graph reaches present_draft, or "completed"


class ConfirmRequest(BaseModel):
    thread_id: str
    confirmed: bool
    user_edits: list[dict] | None = None  # overrides draft task_updates if provided
    selected_reduced: bool = False


class ConfirmResponse(BaseModel):
    status: str  # "completed" | "cancelled"


class DraftResponse(BaseModel):
    thread_id: str
    draft: dict
    suggest_reduced_load: bool
    status: str  # "interrupted" | "completed" | "not_found"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_config(thread_id: str) -> dict:
    return {"configurable": {"thread_id": thread_id}}


def _get_graph_state(thread_id: str) -> Any | None:
    """Synchronously fetch graph checkpoint state (MemorySaver is sync-based)."""
    config = _make_config(thread_id)
    try:
        return weekly_review_graph.get_state(config)
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post("/weekly-review/trigger", response_model=TriggerResponse)
async def trigger_weekly_review() -> TriggerResponse:
    """
    Manually trigger a new weekly review.

    Starts the LangGraph graph, which runs through aggregate_data → assess_load
    → generate_draft → present_draft.  The graph suspends at present_draft
    (interrupt) and we return the thread_id so the client can poll /draft and
    later call /confirm.
    """
    thread_id = await start_review(triggered_by="manual")

    # Inspect state to determine whether the graph paused or finished early
    state = _get_graph_state(thread_id)
    if state is None:
        raise HTTPException(status_code=500, detail="Graph state not found after trigger")

    status = "interrupted" if state.next else "completed"
    return TriggerResponse(thread_id=thread_id, status=status)


@router.get("/weekly-review/draft/{thread_id}", response_model=DraftResponse)
async def get_draft(thread_id: str) -> DraftResponse:
    """Return the current draft from a paused weekly-review graph."""
    state = _get_graph_state(thread_id)
    if state is None:
        raise HTTPException(status_code=404, detail=f"Thread '{thread_id}' not found")

    values = state.values if state.values else {}
    draft = values.get("draft", {})
    suggest_reduced = values.get("suggest_reduced_load", False)

    # Determine status
    if not state.next:
        status = "completed"
    else:
        status = "interrupted"

    return DraftResponse(
        thread_id=thread_id,
        draft=draft,
        suggest_reduced_load=suggest_reduced,
        status=status,
    )


@router.post("/weekly-review/confirm", response_model=ConfirmResponse)
async def confirm_review(body: ConfirmRequest) -> ConfirmResponse:
    """
    Resume a paused weekly-review graph with the user's decision.

    The confirm payload is injected into the graph state as:
      - user_confirmed = body.confirmed
      - user_edits     = {task_updates: body.user_edits, selected_reduced: body.selected_reduced}

    LangGraph resumes from the present_draft node, which returns the injected
    value from interrupt() and continues to write_results → END.
    """
    config = _make_config(body.thread_id)

    # Verify thread exists and is paused
    state = _get_graph_state(body.thread_id)
    if state is None:
        raise HTTPException(status_code=404, detail=f"Thread '{body.thread_id}' not found")

    if not state.next:
        raise HTTPException(
            status_code=409,
            detail="This weekly review has already been completed or cancelled.",
        )

    # Inject user decision into state
    user_edits: dict | None = None
    if body.user_edits is not None or body.selected_reduced:
        user_edits = {
            "task_updates": body.user_edits or [],
            "selected_reduced": body.selected_reduced,
        }

    try:
        await weekly_review_graph.aupdate_state(
            config,
            {
                "user_confirmed": body.confirmed,
                "user_edits": user_edits,
            },
            as_node="present_draft",
        )
    except Exception as exc:
        logger.exception("Failed to update graph state for thread %s", body.thread_id)
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    # Resume graph execution (runs write_results → END)
    try:
        async for _chunk in weekly_review_graph.astream(None, config=config):
            pass  # consume; write_results persists changes
    except Exception as exc:
        logger.exception("Graph execution failed for thread %s", body.thread_id)
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    status = "cancelled" if not body.confirmed else "completed"
    return ConfirmResponse(status=status)
