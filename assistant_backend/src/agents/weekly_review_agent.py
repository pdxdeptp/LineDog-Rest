"""
Weekly Review Agent

LangGraph graph: START → aggregate_data → assess_load → generate_draft
                      → present_draft → [interrupt] → write_results → END

Exposed top-level coroutines:
  trigger_weekly_review_scheduled()  – APScheduler entry point (Sunday 20:00)
  run_weekly_review_for_morning_agent(db)  – Morning Agent entry point (automated)
"""

from __future__ import annotations

import json
import logging
import uuid
from datetime import date, timedelta
from typing import Any

import aiosqlite
from langchain_core.messages import HumanMessage, SystemMessage
from langchain_google_genai import ChatGoogleGenerativeAI
from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import END, START, StateGraph
from langgraph.types import interrupt
from typing_extensions import TypedDict

from ..config import GEMINI_API_KEY, GEMINI_MODEL, PLAN_MD_PATH
from ..db.connection import get_db
from ..db.plan_md import read_plan_md, snapshot_to_db, write_plan_md
from ..db.queries import (
    get_all_active_resources,
    get_system_state,
    get_task_stats,
    insert_event,
    upsert_system_state,
)

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Shared in-memory checkpointer (single-process; persists across HTTP calls)
# ---------------------------------------------------------------------------
memory_saver = MemorySaver()


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

class WeeklyReviewState(TypedDict):
    week_stats: dict            # aggregated weekly task data
    resource_risks: list        # list of dicts describing overdue risks
    suggest_reduced_load: bool
    draft: dict                 # {summary, task_updates, suggest_reduced}
    user_confirmed: bool | None
    user_edits: dict | None     # optional override: {task_updates: [...], selected_reduced: bool}
    triggered_by: str           # "scheduled" | "morning_agent" | "manual"


# ---------------------------------------------------------------------------
# Nodes
# ---------------------------------------------------------------------------

async def aggregate_data(state: WeeklyReviewState) -> dict:
    """Query DB and assemble week_stats + resource_risks."""
    async with get_db() as db:
        # 1. This-week task completion stats
        week_stats = await get_task_stats(db, "this_week")

        # 2. All active resources – reschedule_count sum + deadline risk
        resources = await get_all_active_resources(db)

        # 3. Daily capacity from system_state
        raw_cap = await get_system_state(db, "daily_capacity_min")
        daily_capacity_min = int(raw_cap) if raw_cap else 300

        total_reschedule = 0
        resource_risks: list[dict] = []

        today = date.today()

        for res in resources:
            # Accumulate reschedule_count from tasks belonging to this resource
            async with db.execute(
                "SELECT COALESCE(SUM(reschedule_count), 0) FROM tasks WHERE resource_id = ?",
                (res["id"],),
            ) as cur:
                row = await cur.fetchone()
                res_reschedule = int(row[0]) if row else 0
            total_reschedule += res_reschedule

            # Deadline feasibility
            risk_entry: dict[str, Any] = {
                "resource_id": res["id"],
                "title": res["title"],
                "reschedule_count": res_reschedule,
                "deadline": res["deadline"],
                "at_risk": False,
            }

            if res["deadline"] and res["total_units"] and res["completed_units"] is not None:
                remaining_units = res["total_units"] - res["completed_units"]

                # avg estimated minutes per unit
                async with db.execute(
                    "SELECT AVG(estimated_minutes) FROM units WHERE resource_id = ? AND status != 'completed'",
                    (res["id"],),
                ) as cur:
                    row = await cur.fetchone()
                    avg_est_min = float(row[0]) if row and row[0] else 30.0

                remaining_work_min = remaining_units * avg_est_min

                try:
                    deadline_date = date.fromisoformat(res["deadline"])
                    days_left = (deadline_date - today).days
                except ValueError:
                    days_left = 0

                available_min = max(0, days_left) * daily_capacity_min

                if available_min < remaining_work_min:
                    risk_entry["at_risk"] = True
                    risk_entry["remaining_work_min"] = remaining_work_min
                    risk_entry["available_min"] = available_min
                    risk_entry["days_left"] = days_left

            resource_risks.append(risk_entry)

        week_stats["total_reschedule_count"] = total_reschedule

        # Speed factor adjustments this week (task 8.3)
        monday = today - timedelta(days=today.weekday())
        async with db.execute(
            "SELECT payload FROM events WHERE event_type = 'speed_factor_changed' AND created_at >= ?",
            (monday.isoformat(),),
        ) as cur:
            sf_rows = await cur.fetchall()
        speed_factor_adjustments = []
        for row in sf_rows:
            try:
                speed_factor_adjustments.append(json.loads(row[0]))
            except Exception:
                pass
        week_stats["speed_factor_adjustments"] = speed_factor_adjustments

    return {
        "week_stats": week_stats,
        "resource_risks": resource_risks,
    }


def assess_load(state: WeeklyReviewState) -> dict:
    """Determine whether a reduced-load week should be suggested."""
    stats = state["week_stats"]
    total_reschedule = stats.get("total_reschedule_count", 0)
    completion_rate = stats.get("completion_rate", 1.0)

    suggest = completion_rate < 0.6 or total_reschedule > 5

    return {"suggest_reduced_load": suggest}


async def generate_draft(state: WeeklyReviewState) -> dict:
    """Call Gemini to produce the weekly review draft."""
    plan_content = await read_plan_md(PLAN_MD_PATH)

    at_risk_resources = [r for r in state["resource_risks"] if r.get("at_risk")]
    high_reschedule = [r for r in state["resource_risks"] if r.get("reschedule_count", 0) > 2]

    system_prompt = (
        "You are a thoughtful weekly review assistant. "
        "Your job is to analyze the user's learning progress and propose a concrete plan for next week. "
        "Output ONLY a single valid JSON object with exactly these keys:\n"
        "  summary (string): 2-4 sentence narrative of this week's progress and key insights\n"
        "  task_updates (array): list of task update objects, each with:\n"
        "    task_id (integer), new_scheduled_date (ISO date string, next week Mon-Sun), new_priority (integer 0-10)\n"
        "  suggest_reduced (boolean): whether a reduced-load week is warranted\n"
        "  reduced_load_plan (object|null): if suggest_reduced is true, provide an alternative plan with:\n"
        "    description (string), task_updates (array, same format but lighter schedule)\n"
        "Do NOT invent new tasks. Only UPDATE existing tasks (change scheduled_date or priority). "
        "Do NOT include markdown fences or any text outside the JSON."
    )

    speed_adj = state["week_stats"].get("speed_factor_adjustments", [])
    speed_adj_section = ""
    if speed_adj:
        lines = []
        for adj in speed_adj:
            rid = adj.get("resource_id")
            res_title = next((r["title"] for r in state["resource_risks"] if r["resource_id"] == rid), str(rid))
            direction = "偏慢" if adj.get("new_factor", 1) < adj.get("old_factor", 1) else "偏快"
            lines.append(
                f"- {res_title}: 实际速度{direction}，速度系数 {adj.get('old_factor')} → {adj.get('new_factor')}"
            )
        speed_adj_section = "## Speed Factor Adjustments This Week\n" + "\n".join(lines) + "\n\n"

    user_content = (
        f"## This Week Stats\n{json.dumps(state['week_stats'], indent=2, ensure_ascii=False)}\n\n"
        f"## Overdue / At-Risk Resources\n{json.dumps(at_risk_resources, indent=2, ensure_ascii=False)}\n\n"
        f"## High-Reschedule Resources\n{json.dumps(high_reschedule, indent=2, ensure_ascii=False)}\n\n"
        f"## Reduced Load Assessment\nSuggest reduced load: {state['suggest_reduced_load']}\n\n"
        + speed_adj_section
        + f"## Current Plan (plan.md)\n{plan_content or '(empty)'}\n\n"
        "Based on the above, produce the next-week plan JSON. "
        + ("If speed_factor_adjustments are present, mention them briefly in the summary field. " if speed_adj else "")
        + "Output only valid JSON."
    )

    llm = ChatGoogleGenerativeAI(
        model=GEMINI_MODEL,
        google_api_key=GEMINI_API_KEY,
        temperature=0.3,
    )

    response = await llm.ainvoke(
        [SystemMessage(content=system_prompt), HumanMessage(content=user_content)]
    )

    raw_text = response.content.strip()

    # Strip markdown fences if the model adds them anyway
    if raw_text.startswith("```"):
        lines = raw_text.splitlines()
        raw_text = "\n".join(
            line for line in lines if not line.startswith("```")
        ).strip()

    try:
        draft = json.loads(raw_text)
    except json.JSONDecodeError:
        logger.warning("Gemini returned non-JSON; wrapping as plain summary.")
        draft = {
            "summary": raw_text,
            "task_updates": [],
            "suggest_reduced": state["suggest_reduced_load"],
            "reduced_load_plan": None,
        }

    # Normalise keys
    if "task_updates" not in draft:
        draft["task_updates"] = []
    if "suggest_reduced" not in draft:
        draft["suggest_reduced"] = state["suggest_reduced_load"]

    return {"draft": draft}


def present_draft(state: WeeklyReviewState) -> dict:
    """Pause execution and hand the draft to the caller (frontend / HTTP layer)."""
    # interrupt() raises a special exception caught by LangGraph, which
    # serialises the value into the checkpoint and suspends the graph.
    # Execution resumes when the caller calls aupdate_state(...) + astream(None, …)
    interrupt(state["draft"])

    # This line is only reached on resume (after user_confirmed is injected).
    return {}


async def write_results(state: WeeklyReviewState) -> dict:
    """Persist confirmed changes to DB and plan.md."""
    if not state.get("user_confirmed"):
        # User declined; do nothing.
        return {}

    user_edits = state.get("user_edits") or {}
    selected_reduced = user_edits.get("selected_reduced", False)

    # Determine which task_updates to apply
    if "task_updates" in user_edits and user_edits["task_updates"]:
        task_updates = user_edits["task_updates"]
    elif selected_reduced and state["draft"].get("reduced_load_plan"):
        task_updates = state["draft"]["reduced_load_plan"].get("task_updates", [])
    else:
        task_updates = state["draft"].get("task_updates", [])

    async with get_db() as db:
        # Apply task updates (UPDATE only, no INSERT)
        for upd in task_updates:
            task_id = upd.get("task_id")
            new_date = upd.get("new_scheduled_date")
            new_priority = upd.get("new_priority")
            if not task_id:
                continue

            # Build UPDATE dynamically for non-null fields
            fields, params = [], []
            if new_date:
                fields.append("scheduled_date = ?")
                params.append(new_date)
            if new_priority is not None:
                fields.append("priority = ?")
                params.append(new_priority)

            if fields:
                params.append(task_id)
                await db.execute(
                    f"UPDATE tasks SET {', '.join(fields)} WHERE id = ?",
                    params,
                )

        await db.commit()

        # Reduced-load mode
        if selected_reduced:
            await upsert_system_state(db, "load_mode", "reduced")

        # Rewrite plan.md via LLM
        new_plan = await _rewrite_plan_md(state)
        await write_plan_md(PLAN_MD_PATH, new_plan)
        await snapshot_to_db(db, new_plan, triggered_by="weekly_review")

        # Record event
        today = date.today()
        monday = today - timedelta(days=today.weekday())
        sunday = monday + timedelta(days=6)
        await insert_event(
            db,
            "weekly_review_done",
            {
                "week": f"{monday.isoformat()}/{sunday.isoformat()}",
                "triggered_by": state.get("triggered_by", "manual"),
                "task_updates_applied": len(task_updates),
                "reduced_load": selected_reduced,
            },
        )

    return {}


async def _rewrite_plan_md(state: WeeklyReviewState) -> str:
    """Ask Gemini to rewrite plan.md to reflect the approved next-week plan."""
    current_plan = await read_plan_md(PLAN_MD_PATH)
    draft = state["draft"]

    system_prompt = (
        "You are a planning assistant. Rewrite the plan.md document to reflect "
        "the approved weekly review decisions. Keep the document concise, structured, "
        "and in Markdown. Preserve existing resource entries but update scheduled dates "
        "and priorities as decided in the review. Output only the Markdown content."
    )

    user_content = (
        f"## Current plan.md\n{current_plan or '(empty)'}\n\n"
        f"## Approved Review Summary\n{draft.get('summary', '')}\n\n"
        f"## Task Updates Applied\n{json.dumps(draft.get('task_updates', []), indent=2, ensure_ascii=False)}"
    )

    llm = ChatGoogleGenerativeAI(
        model=GEMINI_MODEL,
        google_api_key=GEMINI_API_KEY,
        temperature=0.2,
    )

    response = await llm.ainvoke(
        [SystemMessage(content=system_prompt), HumanMessage(content=user_content)]
    )

    new_content = response.content.strip()
    # Remove markdown fences if present
    if new_content.startswith("```"):
        lines = new_content.splitlines()
        new_content = "\n".join(
            line for line in lines if not line.startswith("```")
        ).strip()

    return new_content


# ---------------------------------------------------------------------------
# Graph construction
# ---------------------------------------------------------------------------

def _build_graph() -> Any:
    builder = StateGraph(WeeklyReviewState)

    builder.add_node("aggregate_data", aggregate_data)
    builder.add_node("assess_load", assess_load)
    builder.add_node("generate_draft", generate_draft)
    builder.add_node("present_draft", present_draft)
    builder.add_node("write_results", write_results)

    builder.add_edge(START, "aggregate_data")
    builder.add_edge("aggregate_data", "assess_load")
    builder.add_edge("assess_load", "generate_draft")
    builder.add_edge("generate_draft", "present_draft")
    builder.add_edge("present_draft", "write_results")
    builder.add_edge("write_results", END)

    return builder.compile(checkpointer=memory_saver)


# Module-level compiled graph (created once)
weekly_review_graph = _build_graph()


# ---------------------------------------------------------------------------
# Public helper: start a new review thread
# ---------------------------------------------------------------------------

async def start_review(triggered_by: str) -> str:
    """
    Launch a new weekly-review run.

    Returns the thread_id that the HTTP layer can give back to the client
    so that /confirm can resume the graph later.
    """
    thread_id = str(uuid.uuid4())
    config = {"configurable": {"thread_id": thread_id}}

    initial_state: WeeklyReviewState = {
        "week_stats": {},
        "resource_risks": [],
        "suggest_reduced_load": False,
        "draft": {},
        "user_confirmed": None,
        "user_edits": None,
        "triggered_by": triggered_by,
    }

    # Stream until the interrupt (present_draft node) fires.
    # After the interrupt, the graph suspends and we return the thread_id.
    async for _chunk in weekly_review_graph.astream(initial_state, config=config):
        pass  # consume stream; interrupt suspends internally

    return thread_id


# ---------------------------------------------------------------------------
# Top-level entry points
# ---------------------------------------------------------------------------

async def trigger_weekly_review_scheduled() -> None:
    """
    APScheduler entry point – called every Sunday at 20:00.

    Starts the graph up to the interrupt point.  The frontend must call
    POST /api/weekly-review/confirm (with the returned thread_id) to complete
    the review.  If the frontend is not connected at this time, the draft
    persists in memory_saver until the user opens the app.
    """
    try:
        thread_id = await start_review(triggered_by="scheduled")
        logger.info("Weekly review graph started (scheduled); thread_id=%s", thread_id)
    except Exception:
        logger.exception("Failed to start scheduled weekly review")


async def run_weekly_review_for_morning_agent(db: aiosqlite.Connection) -> None:
    """
    Morning Agent entry point.

    The Morning Agent has already determined that last week's weekly_review_done
    event is missing.  We start a new review thread here, but since this is an
    automated flow (no frontend interaction expected immediately), we just kick
    off the graph and log the thread_id.  The Morning Agent's summary will
    include a notification prompting the user to confirm via the app.
    """
    try:
        thread_id = await start_review(triggered_by="morning_agent")
        logger.info(
            "Weekly review graph started (morning_agent catch-up); thread_id=%s", thread_id
        )
    except Exception:
        logger.exception("Failed to start morning-agent weekly review")
