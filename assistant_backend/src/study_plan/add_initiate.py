"""Thin Add / Initiate session adapter.

This module owns the user-facing session contract only. It delegates routing,
draft persistence, scheduling, option effects, and activation to existing study
plan helpers.
"""

from __future__ import annotations

from collections import defaultdict, deque
from collections.abc import Callable, Mapping
from typing import Any

import aiosqlite

from .compiler import compile_plan
from .intake import confirm_intake_route, route_intake_submission
from .lifecycle import (
    confirm_draft_study_project,
    create_meaningful_draft_edit_version,
    fetch_latest_draft_package,
    save_draft_compiler_package_shell,
)
from .scheduling import apply_schedule_option, schedule_draft_review

ADD_INITIATE_PROGRESS_STAGES = (
    "analyzing_input",
    "routing_item",
    "previewing_source",
    "role_review",
    "anchor_review",
    "generating_phases",
    "generating_tasks",
    "validating_tasks",
    "scheduling",
    "preparing_review",
)

ADD_INITIATE_REVIEW_STATES = (
    "stored_non_plan",
    "material_attached",
    "needs_input",
    "compile_failed",
    "infeasible_review",
    "draft_review",
    "activation_failed",
    "activated",
    "cancelled",
    "error",
)


def session_id_for_intake(intake_item_id: int) -> str:
    return f"add-initiate-{intake_item_id}"


def _event(
    *,
    session_id: str,
    stage: str,
    client_request_id: str | None = None,
    intake_item_id: int | None = None,
    draft_id: int | None = None,
    draft_version: int | None = None,
    review_state: str | None = None,
    creates_active_tasks: bool = False,
    done: bool = False,
    payload: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    event: dict[str, Any] = {
        "sessionId": session_id,
        "stage": stage,
        "createsActiveTasks": creates_active_tasks,
        "done": done,
    }
    if client_request_id is not None:
        event["clientRequestId"] = client_request_id
    if intake_item_id is not None:
        event["intakeItemId"] = intake_item_id
    if draft_id is not None:
        event["draftId"] = draft_id
    if draft_version is not None:
        event["draftVersion"] = draft_version
    if review_state is not None:
        event["reviewState"] = review_state
    if payload:
        event["payload"] = dict(payload)
    return event


class AddInitiateProgressBuffer:
    """Small in-memory progress buffer for reconnect and stale-event tests."""

    def __init__(self, max_events_per_session: int = 50):
        self._events: dict[str, deque[dict[str, Any]]] = defaultdict(
            lambda: deque(maxlen=max_events_per_session)
        )

    def record(
        self,
        session_id: str,
        stage: str,
        *,
        client_request_id: str | None = None,
        intake_item_id: int | None = None,
        draft_id: int | None = None,
        draft_version: int | None = None,
        review_state: str | None = None,
        creates_active_tasks: bool = False,
        done: bool = False,
        payload: Mapping[str, Any] | None = None,
    ) -> dict[str, Any]:
        event = _event(
            session_id=session_id,
            stage=stage,
            client_request_id=client_request_id,
            intake_item_id=intake_item_id,
            draft_id=draft_id,
            draft_version=draft_version,
            review_state=review_state,
            creates_active_tasks=creates_active_tasks,
            done=done,
            payload=payload,
        )
        self._events[session_id].append(event)
        return event

    def record_if_current(
        self,
        *,
        current_session_id: str,
        current_draft_id: int | None,
        current_draft_version: int | None,
        event: Mapping[str, Any],
    ) -> bool:
        if event.get("sessionId") != current_session_id:
            return False
        event_draft_id = event.get("draftId")
        if current_draft_id is not None and event_draft_id != current_draft_id:
            return False
        event_version = event.get("draftVersion")
        if current_draft_version is not None and event_version != current_draft_version:
            return False
        self._events[current_session_id].append(dict(event))
        return True

    def events_for(self, session_id: str) -> list[dict[str, Any]]:
        return list(self._events.get(session_id, ()))


def _maybe_record(
    progress: AddInitiateProgressBuffer | None,
    session_id: str,
    stage: str,
    **kwargs: Any,
) -> None:
    if progress is not None:
        progress.record(session_id, stage, **kwargs)


def _ensure_session_matches_intake(session_id: str, intake_item_id: int | None) -> None:
    if intake_item_id is None or session_id != session_id_for_intake(int(intake_item_id)):
        raise ValueError("session mismatch")


async def _latest_package_for_session(
    db: aiosqlite.Connection,
    *,
    session_id: str,
    draft_id: int,
) -> dict[str, Any]:
    package = await fetch_latest_draft_package(db, draft_id)
    _ensure_session_matches_intake(session_id, package.get("intake_id"))
    return package


def _status_to_review_state(status: str) -> str:
    if status in ADD_INITIATE_REVIEW_STATES:
        return status
    if status == "stored_for_later":
        return "stored_non_plan"
    if status == "compiler_recompute_required":
        return "needs_input"
    if status == "option_unavailable":
        return "infeasible_review"
    return "draft_review"


def _option_persistence_updates(
    current_package: Mapping[str, Any],
    option_result: Mapping[str, Any],
    review_state: str,
) -> dict[str, Any]:
    """Normalize option-effect results into lifecycle-supported package updates."""

    result_status = str(option_result.get("status") or "")
    current_status = str(current_package.get("status") or "draft_review")
    if result_status in {"draft_review", "infeasible_review"}:
        persisted_status = result_status
    elif current_status in {"draft_review", "infeasible_review"}:
        persisted_status = current_status
    else:
        persisted_status = "draft_review"

    updates = dict(option_result)
    updates["status"] = persisted_status
    updates.setdefault("summary", current_package.get("summary"))

    if result_status == "stored_for_later":
        storage_state = dict(option_result)
        review_summary = dict(current_package.get("review_summary") or {})
        review_summary["storage_state"] = {
            "status": "stored_for_later",
            "option_effect": dict(option_result.get("option_effect") or {}),
        }
        updates["storage_state"] = storage_state
        updates["review_summary"] = review_summary
        updates["activation_eligibility"] = {
            "activation_ready": False,
            "blocked_reason": "stored_for_later",
        }
    elif review_state in {"needs_input", "error"} or result_status in {
        "compiler_recompute_required",
        "option_unavailable",
    }:
        review_summary = dict(current_package.get("review_summary") or {})
        if option_result.get("option_effect"):
            review_summary["option_effect"] = dict(option_result["option_effect"])
        updates["review_summary"] = review_summary
        updates["activation_eligibility"] = {
            "activation_ready": False,
            "blocked_reason": result_status or review_state,
        }

    return updates


async def start_add_initiate_session(
    db: aiosqlite.Connection,
    *,
    client_request_id: str,
    raw_input: str,
    source_type: str,
    user_hint: str | None = None,
    existing_plan_id: int | None = None,
    progress: AddInitiateProgressBuffer | None = None,
) -> dict[str, Any]:
    placeholder_session_id = f"add-initiate-pending-{client_request_id}"
    _maybe_record(
        progress,
        placeholder_session_id,
        "analyzing_input",
        client_request_id=client_request_id,
    )
    route = await route_intake_submission(
        db,
        client_request_id=client_request_id,
        raw_input=raw_input,
        source_type=source_type,
        user_hint=user_hint,
        existing_plan_id=existing_plan_id,
    )
    session_id = session_id_for_intake(int(route["intakeItemId"]))
    if progress is not None:
        progress._events[session_id].extend(progress._events.pop(placeholder_session_id, ()))
        progress._events[session_id][0]["sessionId"] = session_id
        progress.record(
            session_id,
            "routing_item",
            client_request_id=client_request_id,
            intake_item_id=route["intakeItemId"],
        )
    next_action = route["nextAction"]
    review_state = "role_review"
    if next_action == "confirm_non_plan_storage":
        review_state = "stored_non_plan"
    elif next_action == "answer_routing_question":
        review_state = "needs_input"
    stage = review_state
    _maybe_record(
        progress,
        session_id,
        stage,
        client_request_id=client_request_id,
        intake_item_id=route["intakeItemId"],
        review_state=review_state,
    )
    return {
        "sessionId": session_id,
        "clientRequestId": client_request_id,
        "stage": stage,
        "reviewState": review_state,
        **route,
    }


async def confirm_add_initiate_role(
    db: aiosqlite.Connection,
    *,
    session_id: str,
    intake_item_id: int,
    confirmed_role: str,
    title: str,
    url: str | None = None,
    existing_plan_id: int | None = None,
    attachment_mode: str | None = None,
    canonical_repo_role: str | None = None,
    metadata: dict[str, Any] | None = None,
    progress: AddInitiateProgressBuffer | None = None,
) -> dict[str, Any]:
    _ensure_session_matches_intake(session_id, intake_item_id)
    _maybe_record(
        progress,
        session_id,
        "anchor_review" if confirmed_role == "new_plan" else "role_review",
        intake_item_id=intake_item_id,
    )
    result = await confirm_intake_route(
        db,
        intake_item_id=intake_item_id,
        confirmed_role=confirmed_role,
        title=title,
        url=url,
        existing_plan_id=existing_plan_id,
        attachment_mode=attachment_mode,
        canonical_repo_role=canonical_repo_role,
        metadata=metadata,
    )
    review_state = "anchor_review"
    if result["outcome"] == "stored_non_plan":
        review_state = "stored_non_plan"
    elif result["outcome"] == "stored_plan_attachment":
        review_state = "material_attached"
    elif result["outcome"] == "needs_attachment_target":
        review_state = "needs_input"
    draft_id = result.get("draftId")
    draft_version = result.get("draftVersion")
    _maybe_record(
        progress,
        session_id,
        review_state,
        intake_item_id=intake_item_id,
        draft_id=draft_id,
        draft_version=draft_version,
        review_state=review_state,
    )
    return {
        "sessionId": session_id,
        "stage": review_state,
        "reviewState": review_state,
        **result,
    }


def _compiler_envelope(anchor_request: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "source_context": {
            "source_type": "add_initiate",
            "source_facts": {
                "description": anchor_request.get("target_output") or "Add / Initiate item"
            },
        },
        "target_output": anchor_request.get("target_output"),
        "target_depth": anchor_request.get("target_depth"),
        "deadline": anchor_request.get("deadline"),
        "deadline_type": anchor_request.get("deadline_type"),
        "daily_capacity_min": anchor_request.get("capacity_minutes"),
        "rest_weekdays": anchor_request.get("rest_weekdays") or [],
        "unavailable_dates": anchor_request.get("unavailable_dates") or [],
        "buffer_policy": anchor_request.get("buffer_policy"),
        "load_shape": anchor_request.get("load_shape"),
        "missing_or_assumed_facts": [anchor_request.get("assumptions") or {}],
    }


async def confirm_add_initiate_anchors(
    db: aiosqlite.Connection,
    *,
    session_id: str,
    draft_id: int,
    deadline: str,
    deadline_type: str,
    capacity_minutes: int,
    target_output: str,
    target_depth: str,
    intake_item_id: int | None = None,
    assumptions: dict[str, Any] | None = None,
    rest_weekdays: list[int] | None = None,
    unavailable_dates: list[str] | None = None,
    buffer_policy: str | None = None,
    load_shape: str | None = None,
    compiler: Callable[[dict[str, Any]], dict[str, Any]] | None = None,
    scheduler: Callable[..., dict[str, Any]] | None = None,
    progress: AddInitiateProgressBuffer | None = None,
) -> dict[str, Any]:
    await _latest_package_for_session(db, session_id=session_id, draft_id=draft_id)
    anchor_request = {
        "session_id": session_id,
        "draft_id": draft_id,
        "intake_item_id": intake_item_id,
        "deadline": deadline,
        "deadline_type": deadline_type,
        "capacity_minutes": capacity_minutes,
        "target_output": target_output,
        "target_depth": target_depth,
        "assumptions": assumptions or {},
        "rest_weekdays": rest_weekdays or [],
        "unavailable_dates": unavailable_dates or [],
        "buffer_policy": buffer_policy,
        "load_shape": load_shape,
    }
    _maybe_record(progress, session_id, "generating_phases", draft_id=draft_id)
    compiler_result = (
        compiler(anchor_request)
        if compiler is not None
        else compile_plan(_compiler_envelope(anchor_request))
    )
    await save_draft_compiler_package_shell(
        db,
        draft_id=draft_id,
        status="compiling",
        summary=compiler_result.get("summary"),
        assumptions=compiler_result.get("assumptions") or {},
        phases=compiler_result.get("phases") or [],
        tasks=compiler_result.get("tasks") or [],
    )
    if compiler_result.get("status") == "draft_review":
        _maybe_record(progress, session_id, "generating_tasks", draft_id=draft_id)
        _maybe_record(progress, session_id, "validating_tasks", draft_id=draft_id)
        _maybe_record(progress, session_id, "scheduling", draft_id=draft_id)
        scheduler_result = (scheduler or schedule_draft_review)(
            compiler_result,
            deadline=deadline,
            deadline_type=deadline_type,
            daily_capacity_min=capacity_minutes,
            rest_weekdays=rest_weekdays,
            unavailable_dates=unavailable_dates,
            buffer_policy=buffer_policy,
            load_shape=load_shape,
        )
    else:
        scheduler_result = compiler_result
    review_state = _status_to_review_state(str(scheduler_result.get("status")))
    _maybe_record(progress, session_id, "preparing_review", draft_id=draft_id)
    package = await save_draft_compiler_package_shell(
        db,
        draft_id=draft_id,
        status=review_state,
        summary=scheduler_result.get("summary"),
        assumptions=scheduler_result.get("assumptions") or {},
        phases=scheduler_result.get("phases") or [],
        tasks=scheduler_result.get("tasks") or [],
        review_summary=scheduler_result.get("review_summary") or {},
        activation_eligibility=scheduler_result.get("activation_eligibility") or {},
        missing_input=scheduler_result.get("missing_input"),
        validation_errors=scheduler_result.get("validation_errors"),
        risk_report=scheduler_result.get("risk_report"),
    )
    _maybe_record(
        progress,
        session_id,
        review_state,
        intake_item_id=package.get("intake_id"),
        draft_id=draft_id,
        draft_version=package.get("draft_version"),
        review_state=review_state,
    )
    return {
        "sessionId": session_id,
        "intakeItemId": package.get("intake_id"),
        "draftId": draft_id,
        "draftVersion": package.get("draft_version"),
        "stage": review_state,
        "reviewState": review_state,
        "createsActiveTasks": False,
        "reviewPackage": package,
    }


async def apply_add_initiate_option_effect(
    db: aiosqlite.Connection,
    *,
    session_id: str,
    draft_id: int,
    draft_version: int,
    option_id: str,
    parameters: dict[str, Any] | None = None,
    progress: AddInitiateProgressBuffer | None = None,
) -> dict[str, Any]:
    _maybe_record(
        progress,
        session_id,
        "preparing_review",
        draft_id=draft_id,
        draft_version=draft_version,
    )
    package = await _latest_package_for_session(
        db,
        session_id=session_id,
        draft_id=draft_id,
    )
    if int(package["draft_version"]) != int(draft_version):
        raise ValueError("stale draft option requested")
    result = apply_schedule_option(package, option_id, **(parameters or {}))
    review_state = _status_to_review_state(str(result.get("status")))
    persisted = await create_meaningful_draft_edit_version(
        db,
        draft_id=draft_id,
        edit_kind=f"option_effect:{option_id}",
        expected_latest_version=draft_version,
        package_updates=_option_persistence_updates(package, result, review_state),
    )
    _maybe_record(
        progress,
        session_id,
        review_state,
        draft_id=draft_id,
        draft_version=persisted["draft_version"],
        review_state=review_state,
    )
    return {
        "sessionId": session_id,
        "draftId": draft_id,
        "draftVersion": persisted["draft_version"],
        "stage": review_state,
        "reviewState": review_state,
        "createsActiveTasks": False,
        "reviewPackage": persisted,
    }


async def activate_add_initiate_draft(
    db: aiosqlite.Connection,
    *,
    session_id: str,
    draft_id: int,
    draft_version: int,
    progress: AddInitiateProgressBuffer | None = None,
) -> dict[str, Any]:
    await _latest_package_for_session(db, session_id=session_id, draft_id=draft_id)
    try:
        result = await confirm_draft_study_project(
            db,
            draft_id,
            draft_version=draft_version,
            source="add_initiate_adapter",
        )
    except ValueError as exc:
        if "stale draft" in str(exc).lower():
            raise
        _maybe_record(
            progress,
            session_id,
            "activation_failed",
            draft_id=draft_id,
            draft_version=draft_version,
            review_state="activation_failed",
        )
        return {
            "sessionId": session_id,
            "draftId": draft_id,
            "draftVersion": draft_version,
            "stage": "activation_failed",
            "reviewState": "activation_failed",
            "createsActiveTasks": False,
            "error": str(exc),
        }
    _maybe_record(
        progress,
        session_id,
        "activated",
        draft_id=draft_id,
        draft_version=draft_version,
        review_state="activated",
        creates_active_tasks=True,
        done=True,
    )
    return {
        "sessionId": session_id,
        "draftId": draft_id,
        "draftVersion": draft_version,
        "stage": "activated",
        "reviewState": "activated",
        "createsActiveTasks": True,
        "resourceId": result.get("resource_id"),
        "activationResult": result,
    }
