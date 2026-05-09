"""
Ingestion Agent — LangGraph graph that ingests a learning resource URL.

Graph
-----
START
  → dispatch_handler      (identify URL type, set handler class)
  → fetch_structure       (call handler.fetch() → ResourceStructure)
  → estimate_time         (LLM-fill null estimated_minutes)
  → check_capacity        (generate Option A / Option B schedules)
  → present_draft         (interrupt — wait for user confirm/cancel)
  → write_to_db           (transactional write of resources + units + tasks)
END
"""
from __future__ import annotations

import json
import re
from datetime import date, timedelta
from typing import Any, Literal

from langchain_google_genai import ChatGoogleGenerativeAI
from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import END, START, StateGraph
from langgraph.types import interrupt

from ..config import GEMINI_API_KEY, GEMINI_MODEL
from ..db.connection import get_db
from ..db.queries import check_capacity, insert_event
from ..handlers.dispatcher import dispatch
from ..handlers.models import ResourceStructure, UnitDraft

# ---------------------------------------------------------------------------
# State schema
# ---------------------------------------------------------------------------

from typing import TypedDict


class IngestionState(TypedDict, total=False):
    # Input
    url: str
    deadline: str          # ISO date string  "2026-06-01"
    speed_factor: float    # default 1.0

    # Populated during graph execution
    handler_class: Any
    resource: ResourceStructure | None

    # Capacity analysis
    option_a: list[dict]   # schedule slot assignments
    option_b: list[dict]

    # User decision
    selected_option: str   # "A" | "B"
    confirmed: bool

    # Final DB ids
    resource_id: int | None
    error: str | None


# ---------------------------------------------------------------------------
# LLM helper: batch-estimate null durations
# ---------------------------------------------------------------------------

async def _batch_estimate(units: list[UnitDraft], resource_title: str) -> list[UnitDraft]:
    """Fill estimated_minutes=None entries via one Gemini call."""
    null_indices = [i for i, u in enumerate(units) if u.estimated_minutes is None]
    if not null_indices:
        return units

    llm = ChatGoogleGenerativeAI(
        model=GEMINI_MODEL,
        google_api_key=GEMINI_API_KEY,
        temperature=0,
    )
    unit_list = "\n".join(
        f"{idx}. {units[idx].title}" for idx in null_indices
    )
    prompt = (
        f"For the learning resource '{resource_title}', estimate how many minutes "
        "each of the following units will take to study. "
        "Return a JSON array of integers in the same order as the input list.\n\n"
        f"Units:\n{unit_list}\n\n"
        "Respond ONLY with a JSON array of integers."
    )
    response = await llm.ainvoke(prompt)
    raw = response.content.strip()
    raw = re.sub(r"^```[a-z]*\n?", "", raw)
    raw = re.sub(r"\n?```$", "", raw)
    estimates: list[int] = json.loads(raw)

    updated = list(units)
    for rank, idx in enumerate(null_indices):
        if rank < len(estimates):
            updated[idx] = UnitDraft(
                title=updated[idx].title,
                order_index=updated[idx].order_index,
                estimated_minutes=max(1, int(estimates[rank])),
            )
    return updated


# ---------------------------------------------------------------------------
# Scheduling helpers
# ---------------------------------------------------------------------------

def _total_minutes(units: list[UnitDraft]) -> int:
    return sum(u.estimated_minutes or 30 for u in units)


def _schedule_option_a(
    units: list[UnitDraft],
    deadline: date,
    daily_free: dict[str, int],
    speed_factor: float,
) -> list[dict]:
    """Fill free slots in chronological order (greedy)."""
    slots = sorted(daily_free.items())
    schedule: list[dict] = []
    unit_queue = list(units)
    for day_str, free_min in slots:
        if not unit_queue:
            break
        day = date.fromisoformat(day_str)
        if day > deadline:
            break
        remaining_today = int(free_min)
        while unit_queue and remaining_today > 0:
            unit = unit_queue[0]
            needed = int((unit.estimated_minutes or 30) * speed_factor)
            if needed <= remaining_today:
                schedule.append({
                    "unit_title": unit.title,
                    "unit_order": unit.order_index,
                    "date": day_str,
                    "target_minutes": needed,
                })
                unit_queue.pop(0)
                remaining_today -= needed
            else:
                break  # can't fit — skip remainder of day
    return schedule


def _schedule_option_b(
    units: list[UnitDraft],
    deadline: date,
    start: date,
    speed_factor: float,
    daily_capacity: int = 60,
) -> list[dict]:
    """Spread units evenly across available days ignoring existing tasks (global re-sort)."""
    days_available = max(1, (deadline - start).days + 1)
    schedule: list[dict] = []
    day = start
    for i, unit in enumerate(units):
        if day > deadline:
            break
        schedule.append({
            "unit_title": unit.title,
            "unit_order": unit.order_index,
            "date": day.isoformat(),
            "target_minutes": int((unit.estimated_minutes or 30) * speed_factor),
        })
        day += timedelta(days=1)
    return schedule


# ---------------------------------------------------------------------------
# Graph nodes
# ---------------------------------------------------------------------------

async def dispatch_handler(state: IngestionState) -> IngestionState:
    url = state["url"]
    handler_cls = dispatch(url)
    return {**state, "handler_class": handler_cls}


async def fetch_structure(state: IngestionState) -> IngestionState:
    handler_cls = state["handler_class"]
    url = state["url"]
    try:
        handler = handler_cls(url)
        resource = await handler.fetch()
    except Exception as exc:
        return {**state, "resource": None, "error": str(exc)}
    return {**state, "resource": resource, "error": None}


async def estimate_time(state: IngestionState) -> IngestionState:
    resource: ResourceStructure | None = state.get("resource")
    if resource is None:
        return state
    try:
        updated_units = await _batch_estimate(resource.units, resource.title)
    except Exception:
        updated_units = resource.units

    total_min = _total_minutes(updated_units)
    resource.units = updated_units
    resource.total_estimated_hours = round(total_min / 60, 2)
    return {**state, "resource": resource}


async def check_capacity_node(state: IngestionState) -> IngestionState:
    resource: ResourceStructure | None = state.get("resource")
    if resource is None:
        return state

    deadline_str = state.get("deadline", (date.today() + timedelta(days=30)).isoformat())
    deadline = date.fromisoformat(deadline_str)
    today = date.today()
    speed = float(state.get("speed_factor", 1.0))

    async with get_db() as db:
        daily_state = await db.execute("SELECT value FROM system_state WHERE key='daily_capacity_min'")
        row = await daily_state.fetchone()
        daily_cap = int(row[0]) if row else 60
        free_map = await check_capacity(db, today, deadline, daily_cap)

    option_a = _schedule_option_a(resource.units, deadline, free_map, speed)
    option_b = _schedule_option_b(resource.units, deadline, today, speed, daily_cap)

    return {**state, "option_a": option_a, "option_b": option_b}


async def present_draft(state: IngestionState) -> IngestionState:
    """
    Interrupt here — the graph pauses and returns to the API caller.

    LangGraph re-executes this node when resumed via Command(resume=...).
    The return value of interrupt() is whatever was passed as resume.
    """
    resource: ResourceStructure | None = state.get("resource")
    draft_summary = {
        "resource_title": resource.title if resource else None,
        "resource_type": resource.type if resource else None,
        "total_estimated_hours": resource.total_estimated_hours if resource else 0,
        "unit_count": len(resource.units) if resource else 0,
        "option_a": state.get("option_a", []),
        "option_b": state.get("option_b", []),
    }
    # interrupt() raises GraphInterrupt on first call (pausing the graph).
    # On resume, returns the value provided via Command(resume=...).
    user_response = interrupt(draft_summary)

    # When resumed, user_response contains {"confirmed": bool, "selected_option": "A"|"B"}
    if isinstance(user_response, dict):
        confirmed = bool(user_response.get("confirmed", False))
        selected = str(user_response.get("selected_option", "A"))
    else:
        confirmed = False
        selected = "A"
    return {**state, "confirmed": confirmed, "selected_option": selected}


async def write_to_db(state: IngestionState) -> IngestionState:
    if not state.get("confirmed", False):
        return {**state, "resource_id": None}

    resource: ResourceStructure | None = state.get("resource")
    if resource is None:
        return {**state, "resource_id": None, "error": "No resource to write"}

    selected = state.get("selected_option", "A")
    schedule = state.get("option_a") if selected == "A" else state.get("option_b")
    schedule = schedule or []

    deadline_str = state.get("deadline")
    speed = float(state.get("speed_factor", 1.0))

    async with get_db() as db:
        # Insert resource
        cursor = await db.execute(
            """
            INSERT INTO resources
                (title, type, tracking_mode, url, total_units, estimated_hours, deadline, speed_factor)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                resource.title,
                resource.type,
                resource.tracking_mode,
                resource.url,
                len(resource.units),
                resource.total_estimated_hours,
                deadline_str,
                speed,
            ),
        )
        resource_id = cursor.lastrowid

        # Insert units and build order→unit_id map
        unit_id_map: dict[int, int] = {}
        for unit in resource.units:
            ucursor = await db.execute(
                """
                INSERT INTO units (resource_id, title, order_index, estimated_minutes)
                VALUES (?, ?, ?, ?)
                """,
                (resource_id, unit.title, unit.order_index, unit.estimated_minutes),
            )
            unit_id_map[unit.order_index] = ucursor.lastrowid

        # Insert tasks from schedule
        for slot in schedule:
            unit_id = unit_id_map.get(slot["unit_order"])
            await db.execute(
                """
                INSERT INTO tasks
                    (unit_id, resource_id, title, task_kind, target_minutes,
                     scheduled_date, originally_scheduled_date, priority)
                VALUES (?, ?, ?, 'time', ?, ?, ?, 0)
                """,
                (
                    unit_id,
                    resource_id,
                    slot["unit_title"],
                    slot["target_minutes"],
                    slot["date"],
                    slot["date"],
                ),
            )

        await db.commit()
        await insert_event(db, "resource_added", {"resource_id": resource_id, "title": resource.title})

    return {**state, "resource_id": resource_id}


# ---------------------------------------------------------------------------
# Build the graph
# ---------------------------------------------------------------------------

def _build_graph() -> StateGraph:
    builder = StateGraph(IngestionState)
    builder.add_node("dispatch_handler", dispatch_handler)
    builder.add_node("fetch_structure", fetch_structure)
    builder.add_node("estimate_time", estimate_time)
    builder.add_node("check_capacity", check_capacity_node)
    builder.add_node("present_draft", present_draft)
    builder.add_node("write_to_db", write_to_db)

    builder.add_edge(START, "dispatch_handler")
    builder.add_edge("dispatch_handler", "fetch_structure")
    builder.add_edge("fetch_structure", "estimate_time")
    builder.add_edge("estimate_time", "check_capacity")
    builder.add_edge("check_capacity", "present_draft")
    builder.add_edge("present_draft", "write_to_db")
    builder.add_edge("write_to_db", END)

    return builder


# Singleton compiled graph + checkpointer (used by router).
# The graph uses interrupt() inside present_draft, so no interrupt_before needed.
_checkpointer = MemorySaver()
ingestion_graph = _build_graph().compile(checkpointer=_checkpointer)
