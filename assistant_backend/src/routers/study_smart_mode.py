from datetime import date, timedelta
from typing import Literal

from fastapi import APIRouter
from pydantic import BaseModel

from ..db.connection import get_db
from ..db.queries import (
    get_study_calendar_load,
    get_study_project_overview,
    get_system_state,
    get_today_study_view_tasks,
    rollover_unfinished_study_tasks,
    upsert_system_state,
)

router = APIRouter()

SMART_MODE_KEY = "study_smart_mode_enabled"

class SmartModeSettingsUpdate(BaseModel):
    enabled: bool


class SmartModeProposalRequest(BaseModel):
    trigger: Literal["morning", "after_adjustment"]


def _empty_snapshot() -> dict:
    return {
        "today": {"tasks": []},
        "projects": {"active_projects": [], "completed_projects": []},
        "calendar": {"days": []},
    }


async def _is_smart_mode_enabled() -> bool:
    async with get_db() as db:
        raw = await get_system_state(db, SMART_MODE_KEY)
    return raw == "true"


def _empty_morning_briefing(today: date, enabled: bool = False) -> dict:
    return {
        "enabled": enabled,
        "date": today.isoformat(),
        "summary": "",
        "snapshot": _empty_snapshot(),
        "issues": [],
        "options": [],
        "trigger_eligible": False,
    }


def _build_fact_issues(snapshot: dict) -> list[dict]:
    issues: list[dict] = []

    for task in snapshot["today"]["tasks"]:
        if task["show_rolled_badge"]:
            issues.append(
                {
                    "type": "rolled_task_lag",
                    "task_id": task["id"],
                    "project_id": task["project_id"],
                    "rolled_day_count": task["rolled_day_count"],
                }
            )

    for project in snapshot["projects"]["active_projects"]:
        if project["expected_late"]:
            issues.append({"type": "expected_late_project", "project_id": project["id"]})

    for day in snapshot["calendar"]["days"]:
        if day["over_capacity"]:
            issues.append({"type": "over_capacity_day", "date": day["date"]})

    return issues


def _build_summary(snapshot: dict, issues: list[dict]) -> str:
    today_count = len(snapshot["today"]["tasks"])
    active_project_count = len(snapshot["projects"]["active_projects"])
    lag_count = sum(1 for issue in issues if issue["type"] == "rolled_task_lag")
    late_count = sum(1 for issue in issues if issue["type"] == "expected_late_project")
    over_capacity_count = sum(1 for issue in issues if issue["type"] == "over_capacity_day")
    today_label = "task" if today_count == 1 else "tasks"
    active_project_label = "project" if active_project_count == 1 else "projects"

    return (
        f"{today_count} {today_label} today across "
        f"{active_project_count} active {active_project_label}; "
        f"{lag_count} lagging task{'' if lag_count == 1 else 's'}; "
        f"{late_count} expected-late project{'' if late_count == 1 else 's'}; "
        f"{over_capacity_count} over-capacity day{'' if over_capacity_count == 1 else 's'}."
    )


async def _build_smart_snapshot(today: date) -> dict:
    async with get_db() as db:
        rollover = await rollover_unfinished_study_tasks(db, today)
        today_tasks = await get_today_study_view_tasks(db, today)
        projects = await get_study_project_overview(db)
        calendar = await get_study_calendar_load(db, today, today + timedelta(days=14))

    return {
        "today": {"tasks": today_tasks},
        "projects": projects,
        "calendar": calendar,
        "rollover": rollover,
    }


@router.get("/study-smart-mode/settings")
async def get_study_smart_mode_settings() -> dict:
    return {"enabled": await _is_smart_mode_enabled()}


@router.put("/study-smart-mode/settings")
async def update_study_smart_mode_settings(request: SmartModeSettingsUpdate) -> dict:
    async with get_db() as db:
        await upsert_system_state(
            db,
            SMART_MODE_KEY,
            "true" if request.enabled else "false",
        )
    return {"enabled": request.enabled}


@router.post("/study-smart-mode/proposals")
async def generate_study_smart_mode_proposals(request: SmartModeProposalRequest) -> dict:
    enabled = await _is_smart_mode_enabled()
    return {
        "enabled": enabled,
        "trigger": request.trigger,
        "options": [],
    }


@router.get("/study-smart-mode/morning-briefing")
async def get_study_smart_mode_morning_briefing() -> dict:
    today = date.today()
    enabled = await _is_smart_mode_enabled()
    if not enabled:
        return _empty_morning_briefing(today)

    snapshot = await _build_smart_snapshot(today)
    issues = _build_fact_issues(snapshot)
    return {
        "enabled": True,
        "date": today.isoformat(),
        "summary": _build_summary(snapshot, issues),
        "snapshot": snapshot,
        "issues": issues,
        "options": [],
        "trigger_eligible": bool(issues),
    }
