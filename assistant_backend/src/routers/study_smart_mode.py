import hashlib
import json
from datetime import UTC, date, datetime, timedelta
from typing import Any, Literal

from fastapi import APIRouter
from pydantic import BaseModel

from ..db.connection import get_db
from ..db.queries import (
    get_study_calendar_load,
    get_study_project_overview,
    get_system_state,
    get_today_study_view_tasks,
    preview_over_capacity_impact,
    rollover_unfinished_study_tasks,
    upsert_system_state,
)

router = APIRouter()

SMART_MODE_KEY = "study_smart_mode_enabled"
SIGNATURE_VERSION = 1
SUPPORTED_APPLY_COMMANDS = {
    "extend_project_deadline",
    "make_room_after_lag",
    "move_task_from_over_capacity_day",
}


class SmartModeSettingsUpdate(BaseModel):
    enabled: bool


class SmartModeProposalRequest(BaseModel):
    trigger: Literal["morning", "after_adjustment"]
    previous_expected_late_project_ids: list[int] | None = None
    previous_over_capacity_dates: list[str] | None = None


class SmartModeProposalApplyRequest(BaseModel):
    proposal: dict[str, Any] | None = None
    selected_proposal: dict[str, Any] | None = None
    previous_expected_late_project_ids: list[int] | None = None
    previous_over_capacity_dates: list[str] | None = None


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


def _project_order_key(task: dict[str, Any]) -> tuple[int, int, str, int]:
    unit_order = task["unit_order_index"]
    if unit_order is not None:
        return (0, int(unit_order), task["scheduled_date"], int(task["id"]))
    return (1, 0, task["scheduled_date"], int(task["id"]))


def _reason_signature_payload(reason: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in reason.items() if key != "summary"}


def _option_signature_payload(option: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": option["id"],
        "trigger": option["trigger"],
        "reason": _reason_signature_payload(option["reason"]),
        "affected_project_ids": option["affected_project_ids"],
        "affected_task_ids": option["affected_task_ids"],
        "preview": option["preview"],
        "previewed_changes": option["previewed_changes"],
        "red_state_impact": option["red_state_impact"],
    }


def _with_signature(option: dict[str, Any]) -> dict[str, Any]:
    signature_payload = _option_signature_payload(option)
    signature_input = {
        "version": SIGNATURE_VERSION,
        "payload": signature_payload,
    }
    signature_text = json.dumps(signature_input, sort_keys=True, separators=(",", ":"))
    return {
        **option,
        "signature_version": SIGNATURE_VERSION,
        "signature_payload": signature_payload,
        "signature": hashlib.sha256(signature_text.encode("utf-8")).hexdigest(),
    }


def _signature_for_payload(payload: dict[str, Any]) -> str:
    signature_text = json.dumps(
        {"version": SIGNATURE_VERSION, "payload": payload},
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(signature_text.encode("utf-8")).hexdigest()


def _over_capacity_impact_with_resolved(base_impact: dict[str, list[str]]) -> dict[str, list[str]]:
    before_dates = base_impact["before_dates"]
    after_dates = base_impact["after_dates"]
    return {
        **base_impact,
        "resolved_over_capacity_dates": sorted(set(before_dates) - set(after_dates)),
    }


async def _get_unfinished_project_tasks(db: Any, project_id: int) -> list[dict[str, Any]]:
    async with db.execute(
        """
        SELECT
            t.id,
            t.resource_id,
            t.title,
            t.target_minutes,
            t.scheduled_date,
            t.priority,
            r.title AS project_title,
            r.deadline,
            u.order_index AS unit_order_index
        FROM tasks t
        JOIN resources r ON r.id = t.resource_id
        LEFT JOIN units u ON u.id = t.unit_id
        WHERE t.resource_id = ?
          AND r.type = 'study_project'
          AND r.status = 'active'
          AND t.completed_at IS NULL
        """,
        (project_id,),
    ) as cursor:
        rows = await cursor.fetchall()
        cols = [description[0] for description in cursor.description]

    return sorted([dict(zip(cols, row)) for row in rows], key=_project_order_key)


async def _get_day_unfinished_tasks(db: Any, day: str) -> list[dict[str, Any]]:
    async with db.execute(
        """
        SELECT
            t.id,
            t.resource_id,
            t.title,
            t.target_minutes,
            t.scheduled_date,
            t.priority,
            r.title AS project_title,
            r.deadline,
            u.order_index AS unit_order_index
        FROM tasks t
        JOIN resources r ON r.id = t.resource_id
        LEFT JOIN units u ON u.id = t.unit_id
        WHERE date(t.scheduled_date) = date(?)
          AND r.type = 'study_project'
          AND r.status = 'active'
          AND t.completed_at IS NULL
        ORDER BY t.id ASC
        """,
        (day,),
    ) as cursor:
        rows = await cursor.fetchall()
        cols = [description[0] for description in cursor.description]
        return [dict(zip(cols, row)) for row in rows]


async def _select_over_capacity_task(
    db: Any,
    overloaded_day: str,
) -> tuple[dict[str, Any], list[dict[str, Any]], int, list[dict[str, Any]]] | None:
    day_tasks = await _get_day_unfinished_tasks(db, overloaded_day)
    if not day_tasks:
        return None

    candidates = []
    project_tasks_by_id: dict[int, list[dict[str, Any]]] = {}
    for task in day_tasks:
        project_id = int(task["resource_id"])
        if project_id not in project_tasks_by_id:
            project_tasks_by_id[project_id] = await _get_unfinished_project_tasks(db, project_id)
        project_tasks = project_tasks_by_id[project_id]
        selected_index = next(
            (
                index
                for index, project_task in enumerate(project_tasks)
                if int(project_task["id"]) == int(task["id"])
            ),
            None,
        )
        if selected_index is None:
            continue
        cascading_affected_task_ids = [
            int(project_task["id"]) for project_task in project_tasks[selected_index:]
        ]
        candidates.append(
            {
                "task": task,
                "project_tasks": project_tasks,
                "selected_index": selected_index,
                "cascade_count": len(cascading_affected_task_ids),
                "priority": int(task["priority"] or 0),
                "evaluation": {
                    "task_id": int(task["id"]),
                    "priority": int(task["priority"] or 0),
                    "cascade_count": len(cascading_affected_task_ids),
                    "cascading_affected_task_ids": cascading_affected_task_ids,
                },
            }
        )

    if not candidates:
        return None

    selected = min(
        candidates,
        key=lambda candidate: (
            candidate["cascade_count"],
            candidate["priority"],
            int(candidate["task"]["id"]),
        ),
    )
    return (
        selected["task"],
        selected["project_tasks"],
        selected["selected_index"],
        [candidate["evaluation"] for candidate in candidates],
    )


def _shift_changes(tasks: list[dict[str, Any]], delta_days: int) -> list[dict[str, Any]]:
    changes = []
    for task in tasks:
        old_date = date.fromisoformat(task["scheduled_date"][:10])
        changes.append(
            {
                "task_id": int(task["id"]),
                "project_id": int(task["resource_id"]),
                "old_date": old_date.isoformat(),
                "new_date": (old_date + timedelta(days=delta_days)).isoformat(),
            }
        )
    return changes


async def _expected_late_impact(
    db: Any,
    project_ids: list[int],
    changes: list[dict[str, Any]],
    deadline_overrides: dict[int, str] | None = None,
) -> dict[str, Any]:
    changed_dates = {
        int(change["task_id"]): change["new_date"]
        for change in changes
        if "task_id" in change
    }
    overrides = deadline_overrides or {}
    before_project_ids = []
    after_project_ids = []

    for project_id in sorted(set(project_ids)):
        tasks = await _get_unfinished_project_tasks(db, project_id)
        if not tasks:
            continue
        deadline_text = overrides.get(project_id) or tasks[0]["deadline"]
        original_deadline_text = tasks[0]["deadline"]
        if original_deadline_text:
            original_deadline = date.fromisoformat(original_deadline_text[:10])
            if any(
                date.fromisoformat(task["scheduled_date"][:10]) > original_deadline
                for task in tasks
            ):
                before_project_ids.append(project_id)
        if deadline_text:
            deadline = date.fromisoformat(deadline_text[:10])
            if any(
                date.fromisoformat(changed_dates.get(int(task["id"]), task["scheduled_date"][:10]))
                > deadline
                for task in tasks
            ):
                after_project_ids.append(project_id)

    return {
        "before": bool(before_project_ids),
        "after": bool(after_project_ids),
        "before_project_ids": before_project_ids,
        "after_project_ids": after_project_ids,
    }


async def _over_capacity_impact(db: Any, changes: list[dict[str, Any]]) -> dict[str, list[str]]:
    task_date_changes = [change for change in changes if "task_id" in change]
    if not task_date_changes:
        return {
            "before_dates": [],
            "after_dates": [],
            "new_over_capacity_dates": [],
            "resolved_over_capacity_dates": [],
        }
    return _over_capacity_impact_with_resolved(
        await preview_over_capacity_impact(db, task_date_changes)
    )


def _trigger_slug(trigger: str) -> str:
    return trigger.replace("_", "-")


async def _build_rolled_lag_option(
    db: Any,
    issue: dict[str, Any],
    trigger: Literal["morning", "after_adjustment"] = "morning",
) -> dict[str, Any] | None:
    project_id = int(issue["project_id"])
    lag_task_id = int(issue["task_id"])
    project_tasks = await _get_unfinished_project_tasks(db, project_id)
    lag_index = next(
        (index for index, task in enumerate(project_tasks) if int(task["id"]) == lag_task_id),
        None,
    )
    if lag_index is None:
        return None

    shifted_tasks = project_tasks[lag_index + 1 :] or [project_tasks[lag_index]]
    changes = _shift_changes(shifted_tasks, 1)
    affected_task_ids = [lag_task_id] + [
        int(change["task_id"]) for change in changes if int(change["task_id"]) != lag_task_id
    ]
    red_state_impact = {
        "expected_late": await _expected_late_impact(db, [project_id], changes),
        "over_capacity": await _over_capacity_impact(db, changes),
    }

    option = {
        "id": f"smart-{_trigger_slug(trigger)}-rolled-task-lag-{lag_task_id}",
        "trigger": trigger,
        "reason": {
            "type": "rolled_task_lag",
            "task_id": lag_task_id,
            "project_id": project_id,
            "rolled_day_count": int(issue["rolled_day_count"]),
            "summary": f"Task {lag_task_id} has rolled {int(issue['rolled_day_count'])} days.",
        },
        "affected_project_ids": [project_id],
        "affected_task_ids": affected_task_ids,
        "preview": {
            "status": "preview",
            "source": "smart_mode_preview",
            "command": "make_room_after_lag",
            "trigger": trigger,
            "task_id": lag_task_id,
            "project_id": project_id,
            "delta_days": 1,
            "changes": changes,
            "mutates": False,
        },
        "previewed_changes": changes,
        "red_state_impact": red_state_impact,
        "summary": (
            f"Keep rolled task {lag_task_id} visible today and move "
            f"{len(changes)} follow-up task{'' if len(changes) == 1 else 's'} back one day."
        ),
        "tradeoff": "Protects today's catch-up focus while delaying later work in the same project.",
    }
    return _with_signature(option)


async def _build_expected_late_option(
    db: Any,
    issue: dict[str, Any],
    trigger: Literal["morning", "after_adjustment"] = "morning",
) -> dict[str, Any] | None:
    project_id = int(issue["project_id"])
    project_tasks = await _get_unfinished_project_tasks(db, project_id)
    if not project_tasks or not project_tasks[0]["deadline"]:
        return None

    old_deadline = date.fromisoformat(project_tasks[0]["deadline"][:10]).isoformat()
    latest_task_date = max(task["scheduled_date"][:10] for task in project_tasks)
    if date.fromisoformat(latest_task_date) <= date.fromisoformat(old_deadline):
        return None

    changes = [
        {
            "project_id": project_id,
            "field": "deadline",
            "old_deadline": old_deadline,
            "new_deadline": latest_task_date,
        }
    ]
    red_state_impact = {
        "expected_late": await _expected_late_impact(
            db,
            [project_id],
            [],
            deadline_overrides={project_id: latest_task_date},
        ),
        "over_capacity": await _over_capacity_impact(db, []),
    }

    option = {
        "id": f"smart-{_trigger_slug(trigger)}-expected-late-project-{project_id}",
        "trigger": trigger,
        "reason": {
            "type": "expected_late_project",
            "project_id": project_id,
            "deadline": old_deadline,
            "latest_task_date": latest_task_date,
            "summary": f"Project {project_id} has unfinished work after its deadline.",
        },
        "affected_project_ids": [project_id],
        "affected_task_ids": [int(task["id"]) for task in project_tasks],
        "preview": {
            "status": "preview",
            "source": "smart_mode_preview",
            "command": "extend_project_deadline",
            "trigger": trigger,
            "project_id": project_id,
            "old_deadline": old_deadline,
            "new_deadline": latest_task_date,
            "changes": changes,
            "mutates": False,
        },
        "previewed_changes": changes,
        "red_state_impact": red_state_impact,
        "summary": f"Extend project {project_id}'s deadline to {latest_task_date}.",
        "tradeoff": "Keeps task dates unchanged but moves the project commitment later.",
    }
    return _with_signature(option)


async def _build_over_capacity_option(
    db: Any,
    issue: dict[str, Any],
    trigger: Literal["morning", "after_adjustment"] = "morning",
) -> dict[str, Any] | None:
    overloaded_day = issue["date"]
    selection = await _select_over_capacity_task(db, overloaded_day)
    if selection is None:
        return None
    selected_task, project_tasks, selected_index, candidate_evaluations = selection
    project_id = int(selected_task["resource_id"])

    changes = _shift_changes(project_tasks[selected_index:], 1)
    affected_project_ids = sorted({int(change["project_id"]) for change in changes})
    affected_task_ids = [int(change["task_id"]) for change in changes]
    cascade_count = max(0, len(affected_task_ids) - 1)
    selection_policy = {
        "strategy": "minimize_same_project_cascade_before_priority",
        "candidate_task_ids": [
            candidate["task_id"] for candidate in candidate_evaluations
        ],
        "candidate_evaluations": candidate_evaluations,
        "selected_task_id": int(selected_task["id"]),
        "cascading_affected_task_ids": affected_task_ids,
        "selection_reason": (
            f"Selected task {int(selected_task['id'])} because it has the smallest "
            f"same-project cascade ({len(affected_task_ids)} tasks), before using "
            "priority as a tie-breaker."
        ),
    }
    red_state_impact = {
        "expected_late": await _expected_late_impact(db, affected_project_ids, changes),
        "over_capacity": await _over_capacity_impact(db, changes),
    }

    option = {
        "id": f"smart-{_trigger_slug(trigger)}-over-capacity-day-{overloaded_day}",
        "trigger": trigger,
        "reason": {
            "type": "over_capacity_day",
            "date": overloaded_day,
            "summary": f"{overloaded_day} is over capacity.",
        },
        "affected_project_ids": affected_project_ids,
        "affected_task_ids": affected_task_ids,
        "preview": {
            "status": "preview",
            "source": "smart_mode_preview",
            "command": "move_task_from_over_capacity_day",
            "trigger": trigger,
            "date": overloaded_day,
            "task_id": int(selected_task["id"]),
            "delta_days": 1,
            "selection_policy": selection_policy,
            "changes": changes,
            "mutates": False,
        },
        "previewed_changes": changes,
        "red_state_impact": red_state_impact,
        "summary": f"Move task {int(selected_task['id'])} off {overloaded_day}.",
        "tradeoff": (
            f"Reduces the overloaded day by pushing task {int(selected_task['id'])} "
            "one day later; chooses smaller same-project cascade before priority, "
            "so a higher-priority task may move when it affects fewer tasks; "
            f"cascades {cascade_count} later same-project task"
            f"{'' if cascade_count == 1 else 's'}."
        ),
    }
    return _with_signature(option)


async def _build_proposal_options(
    issues: list[dict],
    trigger: Literal["morning", "after_adjustment"],
) -> list[dict[str, Any]]:
    async with get_db() as db:
        return await _build_proposal_options_with_db(db, issues, trigger)


async def _build_proposal_options_with_db(
    db: Any,
    issues: list[dict],
    trigger: Literal["morning", "after_adjustment"],
) -> list[dict[str, Any]]:
    options = []
    for issue in issues:
        option = None
        if issue["type"] == "rolled_task_lag" and trigger == "morning":
            option = await _build_rolled_lag_option(db, issue, trigger)
        elif issue["type"] == "expected_late_project":
            option = await _build_expected_late_option(db, issue, trigger)
        elif issue["type"] == "over_capacity_day":
            option = await _build_over_capacity_option(db, issue, trigger)
        if option is not None:
            options.append(option)
    return options


async def _build_morning_proposal_options(issues: list[dict]) -> list[dict[str, Any]]:
    return await _build_proposal_options(issues, "morning")


def _normalized_date_values(values: list[str]) -> set[str]:
    normalized = set()
    for value in values:
        try:
            normalized.add(date.fromisoformat(str(value)[:10]).isoformat())
        except ValueError:
            normalized.add(str(value))
    return normalized


def _after_adjustment_new_red_issues(
    issues: list[dict],
    request: SmartModeProposalRequest,
) -> list[dict]:
    if (
        request.previous_expected_late_project_ids is None
        and request.previous_over_capacity_dates is None
    ):
        return []

    previous_expected_late_project_ids = {
        int(project_id) for project_id in (request.previous_expected_late_project_ids or [])
    }
    previous_over_capacity_dates = _normalized_date_values(request.previous_over_capacity_dates or [])
    new_red_issues = []

    for issue in issues:
        if (
            issue["type"] == "expected_late_project"
            and request.previous_expected_late_project_ids is not None
        ):
            project_id = int(issue["project_id"])
            if project_id not in previous_expected_late_project_ids:
                new_red_issues.append(issue)
        elif (
            issue["type"] == "over_capacity_day"
            and request.previous_over_capacity_dates is not None
        ):
            current_date = date.fromisoformat(issue["date"][:10]).isoformat()
            if current_date not in previous_over_capacity_dates:
                new_red_issues.append(issue)

    return new_red_issues


async def _build_after_adjustment_proposal_options(
    issues: list[dict],
    request: SmartModeProposalRequest,
) -> list[dict[str, Any]]:
    return await _build_proposal_options(
        _after_adjustment_new_red_issues(issues, request),
        "after_adjustment",
    )


def _selected_apply_proposal(request: SmartModeProposalApplyRequest) -> dict[str, Any] | None:
    return request.proposal or request.selected_proposal


def _submitted_apply_command(submitted: dict[str, Any]) -> str | None:
    preview = submitted.get("preview")
    if not isinstance(preview, dict):
        return None
    command = preview.get("command")
    return command if isinstance(command, str) else None


def _stale_apply_response() -> dict[str, Any]:
    return {
        "status": "stale_proposal",
        "mutates": False,
        "message": "submitted proposal does not match the current active plan",
    }


def _unsupported_apply_response(message: str = "submitted proposal is unsupported") -> dict[str, Any]:
    return {
        "status": "unsupported",
        "mutates": False,
        "message": message,
    }


def _disabled_apply_response() -> dict[str, Any]:
    return {
        "status": "disabled",
        "mutates": False,
        "message": "smart mode is disabled",
    }


def _validated_submitted_signature_payload(
    submitted: dict[str, Any],
) -> tuple[str, dict[str, Any]] | None:
    try:
        if int(submitted["signature_version"]) != SIGNATURE_VERSION:
            return None
        payload = _option_signature_payload(submitted)
        signature = str(submitted["signature"])
    except (KeyError, TypeError, ValueError):
        return None

    if submitted.get("signature_payload") != payload:
        return None
    if _signature_for_payload(payload) != signature:
        return None
    return signature, payload


async def _current_options_for_apply(
    db: Any,
    submitted: dict[str, Any],
    request: SmartModeProposalApplyRequest,
) -> list[dict[str, Any]] | None:
    trigger = submitted.get("trigger")
    if trigger not in {"morning", "after_adjustment"}:
        return None

    snapshot = await _build_read_only_smart_snapshot_with_db(db, date.today())
    issues = _build_fact_issues(snapshot)
    if trigger == "morning":
        return await _build_proposal_options_with_db(db, issues, "morning")

    proposal_request = SmartModeProposalRequest(
        trigger="after_adjustment",
        previous_expected_late_project_ids=request.previous_expected_late_project_ids,
        previous_over_capacity_dates=request.previous_over_capacity_dates,
    )
    return await _build_proposal_options_with_db(
        db,
        _after_adjustment_new_red_issues(issues, proposal_request),
        "after_adjustment",
    )


def _matching_current_option(
    submitted: dict[str, Any],
    current_options: list[dict[str, Any]],
) -> dict[str, Any] | None:
    validated = _validated_submitted_signature_payload(submitted)
    if validated is None:
        return None
    submitted_signature, submitted_payload = validated
    for option in current_options:
        if (
            option["signature"] == submitted_signature
            and option["signature_payload"] == submitted_payload
        ):
            return option
    return None


def _applied_response(option: dict[str, Any]) -> dict[str, Any]:
    command = option["preview"]["command"]
    return {
        "status": "applied",
        "source": "smart_mode_apply",
        "proposal_id": option["id"],
        "signature": option["signature"],
        "trigger": option["trigger"],
        "command": command,
        "affected_project_ids": option["affected_project_ids"],
        "affected_task_ids": option["affected_task_ids"],
        "applied_changes": option["previewed_changes"],
        "mutates": True,
        "refresh": {"today": True, "project_overview": True, "calendar": True},
    }


def _event_payload_for_option(option: dict[str, Any]) -> dict[str, Any]:
    response = _applied_response(option)
    return {
        "source": response["source"],
        "proposal_id": response["proposal_id"],
        "signature": response["signature"],
        "signature_payload": option["signature_payload"],
        "trigger": response["trigger"],
        "command": response["command"],
        "reason": option["reason"],
        "affected_project_ids": response["affected_project_ids"],
        "affected_task_ids": response["affected_task_ids"],
        "red_state_impact": option["red_state_impact"],
        "selected_preview": option["preview"],
        "applied_changes": response["applied_changes"],
    }


async def _apply_deadline_option(db: Any, option: dict[str, Any]) -> dict[str, Any]:
    for change in option["previewed_changes"]:
        if change.get("field") != "deadline":
            return _unsupported_apply_response()
        cursor = await db.execute(
            """
            UPDATE resources
            SET deadline = ?
            WHERE id = ?
              AND type = 'study_project'
              AND status = 'active'
              AND date(deadline) = date(?)
            """,
            (change["new_deadline"], change["project_id"], change["old_deadline"]),
        )
        if cursor.rowcount != 1:
            return _stale_apply_response()
    return _applied_response(option)


async def _apply_task_date_option(db: Any, option: dict[str, Any]) -> dict[str, Any]:
    now = datetime.now(UTC).isoformat()
    for change in option["previewed_changes"]:
        cursor = await db.execute(
            """
            UPDATE tasks
            SET scheduled_date = ?,
                auto_roll_days = 0,
                last_auto_rolled_at = NULL,
                user_adjusted_at = ?
            WHERE id = ?
              AND resource_id = ?
              AND completed_at IS NULL
              AND date(scheduled_date) = date(?)
            """,
            (
                change["new_date"],
                now,
                change["task_id"],
                change["project_id"],
                change["old_date"],
            ),
        )
        if cursor.rowcount != 1:
            return _stale_apply_response()
    return _applied_response(option)


async def _apply_current_option(db: Any, option: dict[str, Any]) -> dict[str, Any]:
    command = option["preview"]["command"]
    if command == "extend_project_deadline":
        return await _apply_deadline_option(db, option)
    if command in {"make_room_after_lag", "move_task_from_over_capacity_day"}:
        return await _apply_task_date_option(db, option)
    return _unsupported_apply_response()


async def _get_projected_rollover_tasks(db: Any, today: date) -> dict[str, Any]:
    today_iso = today.isoformat()
    async with db.execute(
        """
        SELECT
            t.id,
            t.title,
            t.target_minutes,
            t.completed_at,
            t.scheduled_date,
            COALESCE(t.auto_roll_days, 0) AS auto_roll_days,
            r.id AS project_id,
            r.title AS project_title,
            r.id AS resource_id,
            r.title AS resource_title,
            r.url AS resource_url,
            u.id AS unit_id,
            u.title AS unit_title,
            NULL AS unit_url
        FROM tasks t
        JOIN resources r ON r.id = t.resource_id
        LEFT JOIN units u ON u.id = t.unit_id
        WHERE r.type = 'study_project'
          AND r.status = 'active'
          AND t.completed_at IS NULL
          AND date(t.scheduled_date) < date(?)
          AND (
              t.last_auto_rolled_at IS NULL
              OR date(t.last_auto_rolled_at) < date(?)
          )
        ORDER BY date(t.scheduled_date), t.priority DESC, t.id ASC
        """,
        (today_iso, today_iso),
    ) as cursor:
        rows = await cursor.fetchall()
        cols = [description[0] for description in cursor.description]

    tasks = []
    rolled_tasks = []
    for row in rows:
        task = dict(zip(cols, row))
        original_date = date.fromisoformat(task["scheduled_date"][:10])
        rolled_days = (today - original_date).days
        if rolled_days <= 0:
            continue
        rolled_day_count = int(task["auto_roll_days"] or 0) + rolled_days
        tasks.append(
            {
                "id": int(task["id"]),
                "title": task["title"],
                "target_minutes": task["target_minutes"],
                "completed_at": task["completed_at"],
                "project_id": int(task["project_id"]),
                "project_title": task["project_title"],
                "resource_id": int(task["resource_id"]),
                "resource_title": task["resource_title"],
                "resource_url": task["resource_url"],
                "unit_id": task["unit_id"],
                "unit_title": task["unit_title"],
                "unit_url": task["unit_url"],
                "rolled_day_count": rolled_day_count,
                "show_rolled_badge": rolled_day_count >= 3,
            }
        )
        rolled_tasks.append(
            {
                "task_id": int(task["id"]),
                "project_id": int(task["project_id"]),
                "old_date": original_date.isoformat(),
                "new_date": today_iso,
                "rolled_days": rolled_days,
                "auto_roll_days": rolled_day_count,
            }
        )

    return {
        "tasks": tasks,
        "rollover": {
            "date": today_iso,
            "rolled_count": len(rolled_tasks),
            "rolled_tasks": rolled_tasks,
            "projected": True,
        },
    }


async def _build_read_only_smart_snapshot(today: date) -> dict:
    async with get_db() as db:
        return await _build_read_only_smart_snapshot_with_db(db, today)


async def _build_read_only_smart_snapshot_with_db(db: Any, today: date) -> dict:
    projected_rollover = await _get_projected_rollover_tasks(db, today)
    today_tasks = await get_today_study_view_tasks(db, today)
    projects = await get_study_project_overview(db)
    calendar = await get_study_calendar_load(db, today, today + timedelta(days=14))
    return {
        "today": {"tasks": [*projected_rollover["tasks"], *today_tasks]},
        "projects": projects,
        "calendar": calendar,
        "rollover": projected_rollover["rollover"],
    }


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
    options = []
    if enabled and request.trigger == "morning":
        snapshot = await _build_read_only_smart_snapshot(date.today())
        issues = _build_fact_issues(snapshot)
        options = await _build_morning_proposal_options(issues)
    elif enabled and request.trigger == "after_adjustment":
        snapshot = await _build_read_only_smart_snapshot(date.today())
        issues = _build_fact_issues(snapshot)
        options = await _build_after_adjustment_proposal_options(issues, request)

    return {
        "enabled": enabled,
        "trigger": request.trigger,
        "options": options,
    }


@router.post("/study-smart-mode/proposals/apply")
async def apply_study_smart_mode_proposal(request: SmartModeProposalApplyRequest) -> dict:
    async with get_db() as db:
        await db.execute("BEGIN IMMEDIATE")
        try:
            enabled = await get_system_state(db, SMART_MODE_KEY) == "true"
            if not enabled:
                await db.rollback()
                return _disabled_apply_response()

            submitted = _selected_apply_proposal(request)
            if submitted is None:
                await db.rollback()
                return _unsupported_apply_response("missing selected proposal")

            if _submitted_apply_command(submitted) not in SUPPORTED_APPLY_COMMANDS:
                await db.rollback()
                return _unsupported_apply_response()

            current_options = await _current_options_for_apply(db, submitted, request)
            if current_options is None:
                await db.rollback()
                return _unsupported_apply_response()

            current_option = _matching_current_option(submitted, current_options)
            if current_option is None:
                await db.rollback()
                return _stale_apply_response()

            response = await _apply_current_option(db, current_option)
            if response.get("status") != "applied":
                await db.rollback()
                return response

            await db.execute(
                "INSERT INTO events (event_type, payload) VALUES (?, ?)",
                (
                    "study_smart_mode_proposal_applied",
                    json.dumps(_event_payload_for_option(current_option)),
                ),
            )
            await db.commit()
            return response
        except Exception:
            await db.rollback()
            raise


@router.get("/study-smart-mode/morning-briefing")
async def get_study_smart_mode_morning_briefing() -> dict:
    today = date.today()
    enabled = await _is_smart_mode_enabled()
    if not enabled:
        return _empty_morning_briefing(today)

    snapshot = await _build_smart_snapshot(today)
    issues = _build_fact_issues(snapshot)
    options = await _build_morning_proposal_options(issues)
    return {
        "enabled": True,
        "date": today.isoformat(),
        "summary": _build_summary(snapshot, issues),
        "snapshot": snapshot,
        "issues": issues,
        "options": options,
        "trigger_eligible": bool(issues),
    }
