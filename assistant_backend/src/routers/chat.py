"""
Chat router — Conversational Planner HTTP endpoints.

POST /api/chat         Start or continue a planning conversation.
POST /api/chat/confirm Confirm or cancel a pending change proposal.
"""
from __future__ import annotations

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from ..agents.conversational_agent import confirm_proposal, start_conversation

router = APIRouter()


# ---------------------------------------------------------------------------
# Request / Response models
# ---------------------------------------------------------------------------

class ChatRequest(BaseModel):
    message: str
    thread_id: str | None = None


class ChatResponse(BaseModel):
    thread_id: str
    response: str | None = None
    proposal: dict | None = None


class ConfirmRequest(BaseModel):
    thread_id: str
    confirmed: bool


class ConfirmResponse(BaseModel):
    status: str                     # "applied" | "cancelled"
    thread_id: str
    changes_applied: int | None = None


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post("/chat", response_model=ChatResponse)
async def chat(body: ChatRequest) -> ChatResponse:
    """Start or continue a conversation with the conversational planner.

    If the planner reaches a proposal that needs user confirmation, the
    response will include a ``proposal`` field and a ``thread_id`` to be
    passed to ``POST /api/chat/confirm``.
    """
    try:
        result = await start_conversation(
            user_input=body.message,
            thread_id=body.thread_id,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    return ChatResponse(
        thread_id=result["thread_id"],
        response=result.get("response"),
        proposal=result.get("proposal"),
    )


@router.post("/chat/confirm", response_model=ConfirmResponse)
async def chat_confirm(body: ConfirmRequest) -> ConfirmResponse:
    """Confirm or cancel a pending change proposal.

    Pass ``confirmed=true`` to apply the changes, or ``confirmed=false``
    to cancel them.  Either way the graph thread is closed after this call.
    """
    try:
        result = await confirm_proposal(
            thread_id=body.thread_id,
            confirmed=body.confirmed,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    return ConfirmResponse(
        status=result["status"],
        thread_id=result["thread_id"],
        changes_applied=result.get("changes_applied"),
    )
