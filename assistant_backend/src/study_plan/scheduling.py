"""Deterministic study plan draft scheduling."""

from __future__ import annotations

from collections.abc import Mapping
from copy import deepcopy
from datetime import date, timedelta
from math import ceil
from typing import Any

DEFAULT_REST_WEEKDAYS = frozenset({5})
DEFAULT_DAILY_CAPACITY_MIN = 60
DEFAULT_BUFFER_POLICY = "standard_reservation"
DEFAULT_LOAD_SHAPE = "balanced"
ACCEPT_BUFFER_RISK = "accept_buffer_risk"
ACCEPT_OVERLOAD = "accept_overload"
ACCEPT_CRUNCH = "accept_crunch"


def _coerce_date(value: date | str) -> date:
    if isinstance(value, date):
        return value
    if isinstance(value, str):
        return date.fromisoformat(value)
    raise TypeError(f"Expected date or ISO date string, got {type(value).__name__}")


def _try_coerce_date(value: date | str | None) -> date | None:
    if value is None:
        return None
    try:
        return _coerce_date(value)
    except (TypeError, ValueError):
        return None


def _date_window(start: date, deadline: date) -> list[date]:
    days = []
    current = start
    while current <= deadline:
        days.append(current)
        current += timedelta(days=1)
    return days


def _assumption(field: str, value: Any, reason: str) -> dict[str, Any]:
    return {"field": field, "assumption": value, "reason": reason}


def _task_id(task: Mapping[str, Any], index: int) -> str:
    return str(task.get("id") or task.get("task_id") or f"task-{index + 1}")


def _task_minutes(task: Mapping[str, Any]) -> int:
    return int(task.get("estimated_minutes") or task.get("target_minutes") or 0)


def _task_classification(task: Mapping[str, Any]) -> str:
    return str(task.get("classification") or "essential")


def _is_essential(task: Mapping[str, Any]) -> bool:
    return _task_classification(task) == "essential"


def _task_dependencies(task: Mapping[str, Any]) -> list[str]:
    dependencies = (
        task.get("depends_on")
        or task.get("dependencies")
        or task.get("predecessors")
        or []
    )
    return [str(dependency) for dependency in dependencies]


def _try_int(value: Any) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _base_review(
    compiler_package: Mapping[str, Any],
    *,
    status: str,
    assumptions: list[dict[str, Any]] | None = None,
    questions: list[str] | None = None,
    scheduler_trace: dict[str, Any] | None = None,
) -> dict[str, Any]:
    merged_assumptions = list(compiler_package.get("assumptions") or [])
    merged_assumptions.extend(assumptions or [])
    review = {
        "schema_version": int(compiler_package.get("schema_version") or 1),
        "draft_id": compiler_package.get("draft_id"),
        "compiler_package_version": compiler_package.get("compiler_package_version"),
        "status": status,
        "scheduled_days": [],
        "unscheduled_tasks": [],
        "risk_report": {},
        "infeasibility_options": [],
        "assumptions": merged_assumptions,
        "scheduler_trace": scheduler_trace or {},
    }
    if questions is not None:
        review["questions"] = questions
    if compiler_package.get("validation_errors"):
        review["validation_errors"] = list(compiler_package["validation_errors"])
    if compiler_package.get("recovery_actions"):
        review["recovery_actions"] = list(compiler_package["recovery_actions"])
    return review


def _needs_input_review(
    compiler_package: Mapping[str, Any],
    *,
    question: str,
    reason: str,
    assumptions: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    return _base_review(
        compiler_package,
        status="needs_input",
        assumptions=assumptions,
        questions=[question],
        scheduler_trace={"preflight": reason},
    )


def _risk_report(
    *,
    fits: bool,
    capacity_gap_minutes: int = 0,
    optional_unscheduled_minutes: int = 0,
    overloaded_dates: list[str] | None = None,
    expected_late_tasks: list[str] | None = None,
    buffer_days_reserved: list[str] | None = None,
    buffer_erosion: bool = False,
    estimate_confidence_summary: dict[str, int] | None = None,
    existing_load_conflicts: list[str] | None = None,
    canonical_infeasibility_option_ids: list[str] | None = None,
    date_window_risk: str | None = None,
) -> dict[str, Any]:
    report = {
        "fits_as_written": fits,
        "capacity_gap_minutes": capacity_gap_minutes,
        "optional_unscheduled_minutes": optional_unscheduled_minutes,
        "overloaded_dates": list(overloaded_dates or []),
        "expected_late_tasks": list(expected_late_tasks or []),
        "buffer_days_reserved": list(buffer_days_reserved or []),
        "buffer_erosion": buffer_erosion,
        "estimate_confidence_summary": dict(estimate_confidence_summary or {}),
        "existing_load_conflicts": list(existing_load_conflicts or []),
        "canonical_infeasibility_option_ids": list(canonical_infeasibility_option_ids or []),
    }
    if date_window_risk:
        report["date_window_risk"] = date_window_risk
    return report


def _scheduled_item(
    task: Mapping[str, Any],
    *,
    index: int,
    minutes: int,
    session_id: str | None = None,
    parent_task_id: str | None = None,
    sequence_index: int | None = None,
    normal_output: str | None = None,
) -> dict[str, Any]:
    task_id = _task_id(task, index)
    normal_mode = {
        "minutes": minutes,
        "title": task.get("title") or task.get("name") or task_id,
    }
    if normal_output is not None:
        normal_mode["output"] = normal_output
    return {
        "task_id": task_id,
        "phase_id": task.get("phase_id"),
        "session_id": session_id or task_id,
        "parent_task_id": parent_task_id,
        "sequence_index": index if sequence_index is None else sequence_index,
        "scheduled_minutes": minutes,
        "classification": task.get("classification", "essential"),
        "completion_criteria": list(task.get("completion_criteria") or []),
        "source_refs": list(task.get("source_refs") or []),
        "normal_mode": normal_mode,
        "fallback_mode": deepcopy(task.get("fallback_mode")),
    }


def _load_state(planned: int, planning_budget: int, usable: int) -> str:
    if planned <= planning_budget:
        return "within_budget"
    if planned <= usable:
        return "over_budget"
    return "over_capacity"


def _planning_budget(usable_capacity: int) -> int:
    return int(usable_capacity * 0.8)


def _buffer_dates(
    scheduled_days: list[dict[str, Any]],
    *,
    policy: str,
) -> set[date]:
    if policy in {"none", "no_buffer", "no_buffer_reservation"}:
        return set()
    usable_dates = [
        day["date"]
        for day in scheduled_days
        if day["planning_budget_min"] > 0
    ]
    usable_count = len(usable_dates)
    if usable_count < 3:
        return set()
    if usable_count <= 6:
        reserve_count = 1
    else:
        reserve_count = min(max(ceil(usable_count * 0.2), 1), 5)
    return set(usable_dates[-reserve_count:])


def _estimate_confidence_summary(tasks: list[Mapping[str, Any]]) -> dict[str, int]:
    summary: dict[str, int] = {}
    for task in tasks:
        confidence = task.get("estimate_confidence")
        if confidence:
            key = str(confidence)
            summary[key] = summary.get(key, 0) + 1
    return summary


def _has_optional_or_stretch(tasks: list[Mapping[str, Any]]) -> bool:
    return any(_task_classification(task) in {"optional", "stretch"} for task in tasks)


def _essential_task_ids(tasks: list[Mapping[str, Any]]) -> list[str]:
    return [
        _task_id(task, index)
        for index, task in enumerate(tasks)
        if _is_essential(task)
    ]


def _option(
    option_id: str,
    *,
    fact: str,
    effect_type: str,
    unavailable_reason: str | None = None,
) -> dict[str, Any]:
    option = {
        "id": option_id,
        "fact": fact,
        "facts": [fact],
        "effect_type": effect_type,
    }
    if unavailable_reason:
        option["unavailable_reason"] = unavailable_reason
    return option


def _append_option(
    options: list[dict[str, Any]],
    option_ids: set[str],
    option_id: str,
    *,
    fact: str,
    effect_type: str,
    unavailable_reason: str | None = None,
) -> None:
    if option_id in option_ids:
        existing = next(option for option in options if option["id"] == option_id)
        if fact not in existing["facts"]:
            existing["facts"].append(fact)
        return
    option_ids.add(option_id)
    options.append(
        _option(
            option_id,
            fact=fact,
            effect_type=effect_type,
            unavailable_reason=unavailable_reason,
        )
    )


def _build_infeasibility_options(
    risk_report: Mapping[str, Any],
    *,
    tasks: list[Mapping[str, Any]],
    deadline_type: str,
) -> list[dict[str, Any]]:
    options: list[dict[str, Any]] = []
    seen: set[str] = set()
    can_reduce_scope = _has_optional_or_stretch(tasks)
    normalized_deadline_type = deadline_type.lower()

    if risk_report.get("capacity_gap_minutes", 0) > 0:
        if can_reduce_scope:
            _append_option(
                options,
                seen,
                "reduce_scope",
                fact="capacity_gap",
                effect_type="review_recompute",
            )
        _append_option(
            options,
            seen,
            "lower_depth",
            fact="capacity_gap",
            effect_type="compiler_recompute_required",
        )
        _append_option(
            options,
            seen,
            "extend_deadline",
            fact="capacity_gap",
            effect_type="review_recompute",
        )
        _append_option(
            options,
            seen,
            "increase_capacity",
            fact="capacity_gap",
            effect_type="review_recompute",
        )
        _append_option(
            options,
            seen,
            "accept_crunch",
            fact="capacity_gap",
            effect_type="review_recompute",
        )

    if risk_report.get("buffer_erosion"):
        _append_option(
            options,
            seen,
            "accept_buffer_risk",
            fact="buffer_erosion",
            effect_type="review_recompute",
        )
        if can_reduce_scope:
            _append_option(
                options,
                seen,
                "reduce_scope",
                fact="buffer_erosion",
                effect_type="review_recompute",
            )
        _append_option(
            options,
            seen,
            "extend_deadline",
            fact="buffer_erosion",
            effect_type="review_recompute",
        )
        _append_option(
            options,
            seen,
            "increase_capacity",
            fact="buffer_erosion",
            effect_type="review_recompute",
        )

    if risk_report.get("overloaded_dates"):
        _append_option(
            options,
            seen,
            "rebalance",
            fact="overloaded_dates",
            effect_type="review_recompute",
        )
        _append_option(
            options,
            seen,
            "increase_capacity",
            fact="overloaded_dates",
            effect_type="review_recompute",
        )
        if can_reduce_scope:
            _append_option(
                options,
                seen,
                "reduce_scope",
                fact="overloaded_dates",
                effect_type="review_recompute",
            )
        _append_option(
            options,
            seen,
            "accept_overload",
            fact="overloaded_dates",
            effect_type="review_recompute",
        )

    if risk_report.get("expected_late_tasks"):
        _append_option(
            options,
            seen,
            "extend_deadline",
            fact="expected_late",
            effect_type="review_recompute",
        )
        if can_reduce_scope:
            _append_option(
                options,
                seen,
                "reduce_scope",
                fact="expected_late",
                effect_type="review_recompute",
            )
        _append_option(
            options,
            seen,
            "lower_depth",
            fact="expected_late",
            effect_type="compiler_recompute_required",
        )
        if normalized_deadline_type != "hard":
            _append_option(
                options,
                seen,
                "accept_late_finish",
                fact="expected_late",
                effect_type="review_recompute",
            )

    confidence = risk_report.get("estimate_confidence_summary") or {}
    if confidence.get("low", 0) > 0 or confidence.get("rough", 0) > 0:
        _append_option(
            options,
            seen,
            "answer_one_question",
            fact="low_calibration",
            effect_type="compiler_recompute_required",
        )
        _append_option(
            options,
            seen,
            "edit_estimates",
            fact="low_calibration",
            effect_type="review_recompute",
        )
        _append_option(
            options,
            seen,
            "accept_rough_draft",
            fact="low_calibration",
            effect_type="review_recompute",
        )
        _append_option(
            options,
            seen,
            "store_for_later",
            fact="low_calibration",
            effect_type="storage_state",
        )

    return options


def _with_option_effect(
    review: dict[str, Any],
    option_id: str,
    *,
    effect_type: str = "review_recompute",
    extra: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    review["option_effect"] = {
        "id": option_id,
        "effect_type": effect_type,
        **dict(extra or {}),
    }
    return review


def _package_with(
    compiler_package: Mapping[str, Any],
    **updates: Any,
) -> dict[str, Any]:
    package = deepcopy(dict(compiler_package))
    for key, value in updates.items():
        if value is not None:
            package[key] = value
    return package


def _selected_date_strings(values: list[date | str] | set[date | str] | None) -> list[str]:
    dates = []
    for value in values or []:
        parsed = _try_coerce_date(value)
        if parsed is not None:
            dates.append(parsed.isoformat())
    return dates


def _review_fit_facts(review: Mapping[str, Any]) -> dict[str, Any]:
    risk_report = review.get("risk_report") or {}
    return {
        "fits_as_written": risk_report.get("fits_as_written", False),
        "capacity_gap_minutes": risk_report.get("capacity_gap_minutes", 0),
        "optional_unscheduled_minutes": risk_report.get(
            "optional_unscheduled_minutes", 0
        ),
        "expected_late_tasks": list(risk_report.get("expected_late_tasks") or []),
        "overloaded_dates": list(risk_report.get("overloaded_dates") or []),
        "buffer_erosion": bool(risk_report.get("buffer_erosion", False)),
    }


def _normal_session(
    task: Mapping[str, Any],
    *,
    task_id: str,
    minutes: int,
    index: int,
) -> dict[str, Any]:
    return {
        "task": task,
        "task_id": task_id,
        "minutes": minutes,
        "session_id": task_id,
        "parent_task_id": None,
        "sequence_index": index,
        "output": None,
    }


def _raw_split_points(task: Mapping[str, Any]) -> Any:
    return (
        task.get("split_points")
        or task.get("splitPoints")
        or task.get("multi_session_minutes")
        or task.get("multiSessionMinutes")
        or task.get("sessions")
    )


def _split_minutes(task: Mapping[str, Any]) -> list[int] | None:
    raw_split_points = _raw_split_points(task)
    if not raw_split_points:
        return None
    minutes: list[int] = []
    for raw_session in raw_split_points:
        if isinstance(raw_session, Mapping):
            session_minutes = _try_int(raw_session.get("minutes"))
        else:
            session_minutes = _try_int(raw_session)
        if session_minutes is None or session_minutes <= 0:
            return None
        minutes.append(session_minutes)
    return minutes


def _split_estimate_mismatch(task: Mapping[str, Any]) -> bool:
    minutes = _split_minutes(task)
    return minutes is not None and sum(minutes) != _task_minutes(task)


def _split_sessions(
    task: Mapping[str, Any],
    *,
    task_id: str,
    index: int,
    max_planning_budget: int,
) -> list[dict[str, Any]] | None:
    minutes = _task_minutes(task)
    if minutes <= max_planning_budget:
        return [
            _normal_session(
                task,
                task_id=task_id,
                minutes=minutes,
                index=index,
            )
        ]

    raw_split_points = _raw_split_points(task)
    if not raw_split_points:
        return None

    sessions: list[dict[str, Any]] = []
    for session_index, raw_session in enumerate(raw_split_points):
        if isinstance(raw_session, Mapping):
            session_minutes = _try_int(raw_session.get("minutes"))
            session_key = str(raw_session.get("id") or session_index + 1)
            output = (
                raw_session.get("output")
                or raw_session.get("title")
                or f"Continuation {session_index + 1}"
            )
        else:
            session_minutes = _try_int(raw_session)
            session_key = str(session_index + 1)
            output = f"Continuation {session_index + 1}"
        if session_minutes is None or session_minutes <= 0:
            return None
        if session_minutes > max_planning_budget:
            return None
        sessions.append(
            {
                "task": task,
                "task_id": task_id,
                "minutes": session_minutes,
                "session_id": f"{task_id}:{session_key}",
                "parent_task_id": task_id,
                "sequence_index": session_index,
                "output": None if output is None else str(output),
            }
        )
    if sum(session["minutes"] for session in sessions) != minutes:
        return None
    return sessions


def schedule_draft_review(
    compiler_package: Mapping[str, Any],
    *,
    today: date | str | None = None,
    start_date: date | str | None = None,
    deadline: date | str | None = None,
    deadline_type: str | None = None,
    daily_capacity_min: int | None = None,
    rest_weekdays: list[int] | set[int] | frozenset[int] | None = None,
    unavailable_dates: list[date | str] | set[date | str] | None = None,
    existing_active_load: Mapping[date | str, int] | None = None,
    buffer_policy: str | None = None,
    load_shape: str | None = None,
    accepted_risk_ids: list[str] | set[str] | frozenset[str] | None = None,
    accepted_overload_dates: list[date | str] | set[date | str] | None = None,
    accepted_crunch_dates: list[date | str] | set[date | str] | None = None,
) -> dict[str, Any]:
    """Return a pure scheduled review package for compiler-ready task candidates."""

    package_status = str(compiler_package.get("status") or "")
    if package_status != "draft_review":
        return dict(compiler_package)

    assumptions: list[dict[str, Any]] = []
    current_today = _try_coerce_date(today) or date.today()
    raw_start_date = start_date if start_date is not None else compiler_package.get("start_date")
    raw_deadline_type = (
        deadline_type if deadline_type is not None else compiler_package.get("deadline_type")
    )
    raw_capacity = (
        daily_capacity_min
        if daily_capacity_min is not None
        else compiler_package.get("daily_capacity_min")
    )
    raw_existing_load = (
        existing_active_load
        if existing_active_load is not None
        else compiler_package.get("existing_active_load")
    )
    raw_rest_weekdays = (
        rest_weekdays
        if rest_weekdays is not None
        else compiler_package.get("rest_weekdays")
    )
    raw_unavailable_dates = (
        unavailable_dates
        if unavailable_dates is not None
        else compiler_package.get("unavailable_dates")
    )
    raw_buffer_policy = (
        buffer_policy if buffer_policy is not None else compiler_package.get("buffer_policy")
    )
    raw_load_shape = load_shape if load_shape is not None else compiler_package.get("load_shape")
    raw_accepted_risk_ids = (
        accepted_risk_ids
        if accepted_risk_ids is not None
        else compiler_package.get("accepted_risk_ids")
        or compiler_package.get("accepted_risks")
        or compiler_package.get("acceptedRisks")
        or []
    )
    raw_accepted_overload_dates = (
        accepted_overload_dates
        if accepted_overload_dates is not None
        else compiler_package.get("accepted_overload_dates")
        or compiler_package.get("acceptedOverloadDates")
        or []
    )
    raw_accepted_crunch_dates = (
        accepted_crunch_dates
        if accepted_crunch_dates is not None
        else compiler_package.get("accepted_crunch_dates")
        or compiler_package.get("acceptedCrunchDates")
        or []
    )
    raw_deadline = deadline if deadline is not None else compiler_package.get("deadline")

    def _complete_default_assumptions(
        partial_assumptions: list[dict[str, Any]],
        *,
        exclude: set[str] | None = None,
    ) -> list[dict[str, Any]]:
        excluded = exclude or set()
        completed = list(partial_assumptions)
        fields = {assumption["field"] for assumption in completed}

        def add(field: str, value: Any, reason: str) -> None:
            if field not in fields and field not in excluded:
                completed.append(_assumption(field, value, reason))
                fields.add(field)

        if raw_start_date is None:
            add("start_date", current_today.isoformat(), "defaulted_to_today")
        if raw_deadline_type is None:
            add("deadline_type", "assumed", "defaulted_to_assumed")
        if raw_capacity is None:
            add(
                "daily_capacity_min",
                DEFAULT_DAILY_CAPACITY_MIN,
                "defaulted_to_learning_preference",
            )
        if raw_existing_load is None:
            add("existing_active_load", {}, "defaulted_to_empty")
        if raw_rest_weekdays is None:
            add("rest_weekdays", [], "defaulted_to_empty")
        if raw_unavailable_dates is None:
            add("unavailable_dates", [], "defaulted_to_empty")
        if raw_buffer_policy is None:
            add("buffer_policy", DEFAULT_BUFFER_POLICY, "defaulted_to_standard")
        return completed

    def needs_input(
        *,
        question: str,
        reason: str,
        exclude_assumption_fields: set[str] | None = None,
    ) -> dict[str, Any]:
        return _needs_input_review(
            compiler_package,
            question=question,
            reason=reason,
            assumptions=_complete_default_assumptions(
                assumptions,
                exclude=exclude_assumption_fields,
            ),
        )

    if raw_start_date is None:
        start = current_today
        assumptions.append(
            _assumption("start_date", start.isoformat(), "defaulted_to_today")
        )
    else:
        start = _try_coerce_date(raw_start_date)
        if start is None:
            return needs_input(
                question="What valid start date should this plan use?",
                reason="invalid_start_date",
                exclude_assumption_fields={"start_date"},
            )

    resolved_deadline_type = str(raw_deadline_type or "assumed")
    if raw_deadline_type is None:
        assumptions.append(
            _assumption("deadline_type", resolved_deadline_type, "defaulted_to_assumed")
        )

    if raw_capacity is None:
        resolved_capacity = DEFAULT_DAILY_CAPACITY_MIN
        assumptions.append(
            _assumption(
                "daily_capacity_min",
                resolved_capacity,
                "defaulted_to_learning_preference",
            )
        )
    else:
        resolved_capacity = _try_int(raw_capacity)
    if resolved_capacity is None or resolved_capacity <= 0:
        return needs_input(
            question="How many minutes per available day should this plan use?",
            reason="invalid_daily_capacity",
            exclude_assumption_fields={"daily_capacity_min"},
        )

    if raw_existing_load is None:
        existing_by_day: dict[date, int] = {}
        assumptions.append(
            _assumption("existing_active_load", {}, "defaulted_to_empty")
        )
    else:
        try:
            existing_by_day = _existing_minutes_by_day(raw_existing_load)
        except (AttributeError, TypeError, ValueError):
            return needs_input(
                question="Which existing-load date should be corrected?",
                reason="invalid_existing_active_load_date",
                exclude_assumption_fields={"existing_active_load"},
            )

    if raw_rest_weekdays is None:
        rest_days: set[int] = set()
        assumptions.append(_assumption("rest_weekdays", [], "defaulted_to_empty"))
    else:
        rest_days = set()
        try:
            rest_weekday_iter = iter(raw_rest_weekdays)
        except TypeError:
            return needs_input(
                question="Which rest weekday should be corrected?",
                reason="invalid_rest_weekday",
                exclude_assumption_fields={"rest_weekdays"},
            )
        for raw_day in rest_weekday_iter:
            weekday = _try_int(raw_day)
            if weekday is None or weekday < 0 or weekday > 6:
                return needs_input(
                    question="Which rest weekday should be corrected?",
                    reason="invalid_rest_weekday",
                    exclude_assumption_fields={"rest_weekdays"},
                )
            rest_days.add(weekday)

    if raw_unavailable_dates is None:
        unavailable: set[date] = set()
        assumptions.append(_assumption("unavailable_dates", [], "defaulted_to_empty"))
    else:
        unavailable = set()
        try:
            unavailable_iter = iter(raw_unavailable_dates)
        except TypeError:
            return needs_input(
                question="Which unavailable date should be corrected?",
                reason="invalid_unavailable_date",
                exclude_assumption_fields={"unavailable_dates"},
            )
        for raw_day in unavailable_iter:
            unavailable_day = _try_coerce_date(raw_day)
            if unavailable_day is None:
                return needs_input(
                    question="Which unavailable date should be corrected?",
                    reason="invalid_unavailable_date",
                    exclude_assumption_fields={"unavailable_dates"},
                )
            unavailable.add(unavailable_day)

    resolved_buffer_policy = str(raw_buffer_policy or DEFAULT_BUFFER_POLICY)
    if raw_buffer_policy is None:
        assumptions.append(
            _assumption("buffer_policy", resolved_buffer_policy, "defaulted_to_standard")
        )
    resolved_load_shape = str(raw_load_shape or DEFAULT_LOAD_SHAPE)
    accepted_risks = {str(risk_id) for risk_id in raw_accepted_risk_ids}
    accepted_buffer_erosion = bool(
        accepted_risks.intersection({ACCEPT_BUFFER_RISK, "buffer_erosion"})
    )
    accepted_overload = ACCEPT_OVERLOAD in accepted_risks
    accepted_crunch = ACCEPT_CRUNCH in accepted_risks

    if raw_deadline is None:
        return needs_input(
            question="What deadline or timebox should this plan use?",
            reason="missing_deadline",
        )
    due = _try_coerce_date(raw_deadline)
    if due is None:
        return needs_input(
            question="What valid deadline or timebox should this plan use?",
            reason="invalid_deadline",
        )

    accepted_overload_date_set: set[date] = set()
    try:
        accepted_overload_iter = iter(raw_accepted_overload_dates)
    except TypeError:
        accepted_overload_iter = iter(())
    for raw_overload_day in accepted_overload_iter:
        overload_day = _try_coerce_date(raw_overload_day)
        if overload_day is not None:
            accepted_overload_date_set.add(overload_day)

    accepted_crunch_date_set: set[date] = set()
    try:
        accepted_crunch_iter = iter(raw_accepted_crunch_dates)
    except TypeError:
        accepted_crunch_iter = iter(())
    for raw_crunch_day in accepted_crunch_iter:
        crunch_day = _try_coerce_date(raw_crunch_day)
        if crunch_day is not None:
            accepted_crunch_date_set.add(crunch_day)

    tasks = list(compiler_package.get("tasks") or [])
    if not tasks:
        return needs_input(
            question="Which validated task candidate should be scheduled?",
            reason="empty_schedulable_task_set",
        )

    if due < start:
        essential_task_ids = [
            _task_id(task, index)
            for index, task in enumerate(tasks)
            if task.get("classification", "essential") == "essential"
        ]
        essential_minutes = sum(
            _task_minutes(task)
            for task in tasks
            if task.get("classification", "essential") == "essential"
        )
        optional_unscheduled_minutes = sum(
            _task_minutes(task)
            for task in tasks
            if task.get("classification", "essential") != "essential"
        )
        return {
            **_base_review(
                compiler_package,
                status="infeasible_review",
                assumptions=assumptions,
                scheduler_trace={
                    "date_window": [],
                    "deadline_type": resolved_deadline_type,
                    "buffer_policy": resolved_buffer_policy,
                },
            ),
            "risk_report": _risk_report(
                fits=False,
                capacity_gap_minutes=essential_minutes,
                optional_unscheduled_minutes=optional_unscheduled_minutes,
                expected_late_tasks=essential_task_ids,
                date_window_risk="deadline_before_start",
            ),
        }

    scheduled_days = []
    for day in _date_window(start, due):
        is_unavailable = day.weekday() in rest_days or day in unavailable
        raw_capacity = 0 if is_unavailable else resolved_capacity
        existing_minutes = existing_by_day.get(day, 0)
        usable_capacity = max(0, raw_capacity - existing_minutes)
        scheduled_days.append(
            {
                "date": day,
                "raw_capacity_min": raw_capacity,
                "existing_load_min": existing_minutes,
                "usable_capacity_min": usable_capacity,
                "planning_budget_min": _planning_budget(usable_capacity),
                "reserved_buffer": False,
                "planned_minutes": 0,
                "load_state": "within_budget",
                "items": [],
            }
        )

    reserved_buffer_dates = _buffer_dates(
        scheduled_days,
        policy=resolved_buffer_policy,
    )
    for day_review in scheduled_days:
        day_review["reserved_buffer"] = day_review["date"] in reserved_buffer_dates

    unscheduled_tasks = []
    buffer_erosion = False
    task_entries = list(enumerate(tasks))
    classification_order = {"essential": 0, "optional": 1, "stretch": 2}

    def task_sort_key(entry: tuple[int, Mapping[str, Any]]) -> tuple[int, int]:
        return (
            classification_order.get(_task_classification(entry[1]), 0),
            entry[0],
        )

    def dependency_ordered_entries(
        entries: list[tuple[int, Mapping[str, Any]]],
    ) -> list[tuple[int, Mapping[str, Any]]]:
        pending = sorted(entries, key=task_sort_key)
        all_task_ids = {_task_id(task, index) for index, task in pending}
        ordered: list[tuple[int, Mapping[str, Any]]] = []
        resolved: set[str] = set()
        while pending:
            ready_index = next(
                (
                    index
                    for index, (_, task) in enumerate(pending)
                    if all(
                        dependency in resolved
                        for dependency in _task_dependencies(task)
                        if dependency in all_task_ids
                    )
                ),
                None,
            )
            if ready_index is None:
                ordered.extend(pending)
                break
            entry = pending.pop(ready_index)
            ordered.append(entry)
            resolved.add(_task_id(entry[1], entry[0]))
        return ordered

    ordered_task_entries = dependency_ordered_entries(task_entries)

    def schedulable_budget(day_review: Mapping[str, Any]) -> int:
        if accepted_crunch and day_review["date"] in accepted_crunch_date_set:
            return int(day_review["usable_capacity_min"])
        return int(day_review["planning_budget_min"])

    max_planning_budget = max(
        [schedulable_budget(day) for day in scheduled_days]
        or [0]
    )
    placed_task_dates: dict[str, date] = {}

    def effective_budget(day_review: Mapping[str, Any]) -> int:
        budget = schedulable_budget(day_review)
        if (
            resolved_load_shape == "light_start"
            and day_review["date"] == next(
                (
                    day["date"]
                    for day in scheduled_days
                    if day["planning_budget_min"] > 0
                    and not day["reserved_buffer"]
                ),
                None,
            )
        ):
            return budget // 2
        return budget

    def day_can_accept(
        day_review: Mapping[str, Any],
        *,
        minutes: int,
        earliest_date: date | None,
        allow_buffer: bool,
        allow_overload: bool,
        trial_planned: Mapping[date, int] | None = None,
    ) -> bool:
        if earliest_date is not None and day_review["date"] < earliest_date:
            return False
        if day_review["reserved_buffer"] and not allow_buffer:
            return False
        if allow_overload:
            return (
                accepted_overload
                and day_review["date"] in accepted_overload_date_set
                and day_review["raw_capacity_min"] > 0
            )
        if effective_budget(day_review) <= 0:
            return False
        provisional_minutes = (trial_planned or {}).get(day_review["date"], 0)
        return (
            minutes
            <= effective_budget(day_review) - day_review["planned_minutes"] - provisional_minutes
        )

    def choose_day(
        *,
        minutes: int,
        earliest_date: date | None,
        allow_buffer: bool,
        allow_overload: bool = False,
        trial_planned: Mapping[date, int] | None = None,
    ) -> dict[str, Any] | None:
        candidates = [
            day
            for day in scheduled_days
            if day_can_accept(
                day,
                minutes=minutes,
                earliest_date=earliest_date,
                allow_buffer=allow_buffer,
                allow_overload=allow_overload,
                trial_planned=trial_planned,
            )
        ]
        if not candidates:
            return None
        if resolved_load_shape == "front_loaded":
            return min(candidates, key=lambda day: day["date"])
        return min(
            candidates,
            key=lambda day: (
                (
                    day["planned_minutes"]
                    + (trial_planned or {}).get(day["date"], 0)
                )
                / max(effective_budget(day), 1),
                day["date"],
            ),
        )

    for index, task in ordered_task_entries:
        task_id = _task_id(task, index)
        if not _is_essential(task) and any(
            unscheduled["classification"] == "essential"
            for unscheduled in unscheduled_tasks
        ):
            unscheduled_tasks.append(
                {
                    "task_id": task_id,
                    "estimated_minutes": _task_minutes(task),
                    "classification": _task_classification(task),
                    "reason": "essential_not_feasible",
                }
            )
            continue

        dependencies = _task_dependencies(task)
        missing_dependency = next(
            (
                dependency
                for dependency in dependencies
                if dependency not in placed_task_dates
            ),
            None,
        )
        if missing_dependency is not None:
            unscheduled_tasks.append(
                {
                    "task_id": task_id,
                    "estimated_minutes": _task_minutes(task),
                    "classification": _task_classification(task),
                    "reason": "missing_dependency",
                }
            )
            continue

        sessions = _split_sessions(
            task,
            task_id=task_id,
            index=index,
            max_planning_budget=max_planning_budget,
        )
        split_mismatch = _split_estimate_mismatch(task)
        if sessions is None and accepted_overload and not split_mismatch:
            sessions = [
                _normal_session(
                    task,
                    task_id=task_id,
                    minutes=_task_minutes(task),
                    index=index,
                )
            ]
        if sessions is None:
            reason = (
                "split_estimate_mismatch"
                if split_mismatch
                else "insufficient_capacity"
            )
            unscheduled_tasks.append(
                {
                    "task_id": task_id,
                    "estimated_minutes": _task_minutes(task),
                    "classification": _task_classification(task),
                    "reason": reason,
                }
            )
            continue

        placed_sessions: list[tuple[dict[str, Any], dict[str, Any]]] = []
        trial_planned_by_date: dict[date, int] = {}
        task_used_buffer = False
        earliest_date = max(
            (placed_task_dates[dependency] for dependency in dependencies),
            default=None,
        )
        minutes = _task_minutes(task)
        for session in sessions:
            chosen_day = choose_day(
                minutes=session["minutes"],
                earliest_date=earliest_date,
                allow_buffer=False,
                allow_overload=False,
                trial_planned=trial_planned_by_date,
            )
            if chosen_day is None and _is_essential(task):
                chosen_day = choose_day(
                    minutes=session["minutes"],
                    earliest_date=earliest_date,
                    allow_buffer=True,
                    allow_overload=False,
                    trial_planned=trial_planned_by_date,
                )
                if chosen_day is not None and chosen_day["reserved_buffer"]:
                    task_used_buffer = True
            if chosen_day is None and accepted_overload:
                chosen_day = choose_day(
                    minutes=session["minutes"],
                    earliest_date=earliest_date,
                    allow_buffer=False,
                    allow_overload=True,
                    trial_planned=trial_planned_by_date,
                )
            if chosen_day is None:
                placed_sessions = []
                break
            placed_sessions.append((session, chosen_day))
            trial_planned_by_date[chosen_day["date"]] = (
                trial_planned_by_date.get(chosen_day["date"], 0)
                + session["minutes"]
            )
            earliest_date = chosen_day["date"]

        if not placed_sessions:
            unscheduled_tasks.append(
                {
                    "task_id": task_id,
                    "estimated_minutes": minutes,
                    "classification": _task_classification(task),
                    "reason": "insufficient_capacity",
                }
            )
            continue

        for session, day_review in placed_sessions:
            day_review["items"].append(
                _scheduled_item(
                    session["task"],
                    index=index,
                    minutes=session["minutes"],
                    session_id=session["session_id"],
                    parent_task_id=session["parent_task_id"],
                    sequence_index=session["sequence_index"],
                    normal_output=session["output"],
                )
            )
            day_review["planned_minutes"] += session["minutes"]
            if day_review["reserved_buffer"] and day_review["planned_minutes"] > 0:
                day_review["load_state"] = "uses_buffer"
            else:
                day_review["load_state"] = _load_state(
                    day_review["planned_minutes"],
                    day_review["planning_budget_min"],
                    day_review["usable_capacity_min"],
                )
            placed_task_dates[task_id] = day_review["date"]
        if task_used_buffer:
            buffer_erosion = True

    essential_minutes = sum(
        _task_minutes(task)
        for _, task in task_entries
        if _is_essential(task)
    )
    available_minutes = sum(
        schedulable_budget(day)
        for day in scheduled_days
        if accepted_buffer_erosion or not day["reserved_buffer"]
    )
    if accepted_overload:
        available_minutes += sum(
            max(0, day["planned_minutes"] - day["planning_budget_min"])
            for day in scheduled_days
            if day["date"] in accepted_overload_date_set
        )
    essential_gap = max(0, essential_minutes - available_minutes)
    optional_unscheduled_minutes = sum(
        task["estimated_minutes"]
        for task in unscheduled_tasks
        if task["classification"] != "essential"
    )
    expected_late_tasks = [
        task["task_id"]
        for task in unscheduled_tasks
        if task["classification"] == "essential"
    ]
    existing_load_conflicts = [
        day["date"].isoformat()
        for day in scheduled_days
        if day["existing_load_min"] > 0 and day["planned_minutes"] > 0
    ]
    overloaded_dates = [
        day["date"].isoformat()
        for day in scheduled_days
        if day["planned_minutes"] > day["usable_capacity_min"]
    ]
    buffer_days_reserved = sorted(day.isoformat() for day in reserved_buffer_dates)
    status = (
        "infeasible_review"
        if expected_late_tasks
        or (buffer_erosion and not accepted_buffer_erosion)
        or (overloaded_dates and not accepted_overload)
        else "draft_review"
    )
    review = _base_review(
        compiler_package,
        status=status,
        assumptions=assumptions,
        scheduler_trace={
            "date_window": [day.isoformat() for day in _date_window(start, due)],
            "deadline_type": resolved_deadline_type,
            "buffer_policy": resolved_buffer_policy,
            "load_shape": resolved_load_shape,
        },
    )
    review["scheduled_days"] = scheduled_days
    review["unscheduled_tasks"] = unscheduled_tasks
    risk_report = _risk_report(
        fits=status == "draft_review",
        capacity_gap_minutes=essential_gap,
        optional_unscheduled_minutes=optional_unscheduled_minutes,
        overloaded_dates=overloaded_dates,
        expected_late_tasks=expected_late_tasks,
        buffer_days_reserved=buffer_days_reserved,
        buffer_erosion=buffer_erosion,
        estimate_confidence_summary=_estimate_confidence_summary(tasks),
        existing_load_conflicts=existing_load_conflicts,
    )
    infeasibility_options = _build_infeasibility_options(
        risk_report,
        tasks=tasks,
        deadline_type=resolved_deadline_type,
    )
    risk_report["canonical_infeasibility_option_ids"] = [
        option["id"] for option in infeasibility_options
    ]
    review["risk_report"] = risk_report
    review["infeasibility_options"] = infeasibility_options
    return review


def apply_schedule_option(
    compiler_package: Mapping[str, Any],
    option_id: str,
    *,
    today: date | str | None = None,
    new_deadline: date | str | None = None,
    new_daily_capacity_min: int | None = None,
    selected_dates: list[date | str] | set[date | str] | None = None,
    requested_depth: str | None = None,
    question_id: str | None = None,
    estimate_edits: Mapping[str, int] | None = None,
    load_shape: str | None = None,
) -> dict[str, Any]:
    """Apply a scheduler option as a deterministic review/storage/recompute result."""

    package = deepcopy(dict(compiler_package))
    selected_date_strings = _selected_date_strings(selected_dates)

    def current_review() -> dict[str, Any]:
        return schedule_draft_review(package, today=today)

    def rerun(
        *,
        updated_package: Mapping[str, Any] | None = None,
        effect_extra: Mapping[str, Any] | None = None,
    ) -> dict[str, Any]:
        rerun_package = dict(updated_package or package)
        review = schedule_draft_review(rerun_package, today=today)
        return _with_option_effect(review, option_id, extra=effect_extra)

    if option_id == "store_for_later":
        return {
            "schema_version": int(package.get("schema_version") or 1),
            "draft_id": package.get("draft_id"),
            "status": "stored_for_later",
            "active_tasks": [],
            "today_actions": [],
            "option_effect": {
                "id": "store_for_later",
                "effect_type": "storage_state",
            },
        }

    if option_id == "extend_deadline":
        return rerun(
            updated_package=_package_with(package, deadline=new_deadline),
            effect_extra={"new_deadline": new_deadline},
        )

    if option_id == "increase_capacity":
        return rerun(
            updated_package=_package_with(
                package,
                daily_capacity_min=new_daily_capacity_min,
            ),
            effect_extra={"new_daily_capacity_min": new_daily_capacity_min},
        )

    if option_id == "accept_crunch":
        accepted_risks = {
            str(risk_id)
            for risk_id in package.get("accepted_risk_ids")
            or package.get("accepted_risks")
            or []
        }
        accepted_risks.add(ACCEPT_CRUNCH)
        return rerun(
            updated_package=_package_with(
                package,
                accepted_risk_ids=sorted(accepted_risks),
                accepted_crunch_dates=selected_date_strings,
            ),
            effect_extra={"selected_dates": selected_date_strings},
        )

    if option_id == "accept_overload":
        accepted_risks = {
            str(risk_id)
            for risk_id in package.get("accepted_risk_ids")
            or package.get("accepted_risks")
            or []
        }
        accepted_risks.add(ACCEPT_OVERLOAD)
        return rerun(
            updated_package=_package_with(
                package,
                accepted_risk_ids=sorted(accepted_risks),
                accepted_overload_dates=selected_date_strings,
            ),
            effect_extra={"selected_dates": selected_date_strings},
        )

    if option_id == "accept_buffer_risk":
        accepted_risks = {
            str(risk_id)
            for risk_id in package.get("accepted_risk_ids")
            or package.get("accepted_risks")
            or []
        }
        accepted_risks.add(ACCEPT_BUFFER_RISK)
        return rerun(
            updated_package=_package_with(
                package,
                accepted_risk_ids=sorted(accepted_risks),
            )
        )

    if option_id == "rebalance":
        return rerun(
            updated_package=_package_with(
                package,
                load_shape=load_shape or "front_loaded",
            )
        )

    if option_id == "edit_estimates":
        edited_tasks = []
        estimate_edits = estimate_edits or {}
        for index, task in enumerate(package.get("tasks") or []):
            task_copy = deepcopy(dict(task))
            task_id = _task_id(task_copy, index)
            if task_id in estimate_edits:
                task_copy["estimated_minutes"] = int(estimate_edits[task_id])
            edited_tasks.append(task_copy)
        return rerun(updated_package=_package_with(package, tasks=edited_tasks))

    if option_id == "reduce_scope":
        before = current_review()
        kept_tasks = []
        removed_task_ids = []
        for index, task in enumerate(package.get("tasks") or []):
            task_copy = deepcopy(dict(task))
            task_id = _task_id(task_copy, index)
            if _task_classification(task_copy) in {"optional", "stretch"}:
                removed_task_ids.append(task_id)
            else:
                kept_tasks.append(task_copy)
        reduced_review = rerun(
            updated_package=_package_with(package, tasks=kept_tasks),
            effect_extra={
                "removed_task_ids": removed_task_ids,
                "preserved_essential_task_ids": _essential_task_ids(kept_tasks),
                "before": _review_fit_facts(before),
            },
        )
        reduced_review["option_effect"]["after"] = _review_fit_facts(reduced_review)
        return reduced_review

    if option_id in {"lower_depth", "answer_one_question"}:
        review = current_review()
        handoff: dict[str, Any] = {
            "reason": option_id,
            "current_fit_facts": _review_fit_facts(review),
            "removed_evidence_preview": [],
        }
        if option_id == "lower_depth":
            handoff["requested_target_depth"] = requested_depth
        else:
            handoff["question_id"] = question_id
        return {
            "schema_version": int(package.get("schema_version") or 1),
            "draft_id": package.get("draft_id"),
            "status": "compiler_recompute_required",
            "compiler_recompute_required": handoff,
            "option_effect": {
                "id": option_id,
                "effect_type": "compiler_recompute_required",
            },
        }

    if option_id == "accept_rough_draft":
        return rerun(effect_extra={"activation_allowed_after_confirmation": True})

    if option_id == "accept_late_finish":
        review = current_review()
        if str(package.get("deadline_type") or "").lower() == "hard":
            return {
                "schema_version": int(package.get("schema_version") or 1),
                "draft_id": package.get("draft_id"),
                "status": "option_unavailable",
                "option_effect": {
                    "id": "accept_late_finish",
                    "effect_type": "unavailable",
                    "reason": "hard_deadline",
                },
            }
        return _with_option_effect(
            review,
            option_id,
            extra={"accepted_late_finish": True},
        )

    return {
        "schema_version": int(package.get("schema_version") or 1),
        "draft_id": package.get("draft_id"),
        "status": "option_unavailable",
        "option_effect": {
            "id": option_id,
            "effect_type": "unavailable",
            "reason": "unknown_option",
        },
    }


def _next_non_rest_day(day: date, rest_weekdays: set[int]) -> date:
    if len(rest_weekdays) >= 7:
        raise ValueError("At least one weekday must be available for scheduling")

    current = day
    while current.weekday() in rest_weekdays:
        current += timedelta(days=1)
    return current


def _non_rest_days_between(start: date, deadline: date, rest_weekdays: set[int]) -> list[date]:
    if start > deadline:
        return []

    days = []
    current = start
    while current <= deadline:
        if current.weekday() not in rest_weekdays:
            days.append(current)
        current += timedelta(days=1)
    return days


def _ordered_tasks(tasks: Mapping[Any, Mapping[str, Any]] | list[Mapping[str, Any]]):
    source = tasks.values() if isinstance(tasks, Mapping) else tasks
    for index, task in enumerate(source):
        minutes = int(task["estimated_minutes"])
        if minutes < 0:
            raise ValueError("Task estimated_minutes must be non-negative")
        yield index, task, minutes


def _existing_minutes_by_day(
    existing_daily_minutes: Mapping[date | str, int] | None,
) -> dict[date, int]:
    if not existing_daily_minutes:
        return {}
    return {
        _coerce_date(day): int(minutes)
        for day, minutes in existing_daily_minutes.items()
    }


def _status(expected_late: bool, has_over_capacity_days: bool) -> str:
    if expected_late and has_over_capacity_days:
        return "expected_late_over_capacity"
    if expected_late:
        return "expected_late"
    if has_over_capacity_days:
        return "over_capacity"
    return "on_track"


def _spread_day_for_index(index: int, task_count: int, available_days: list[date]) -> date | None:
    if not available_days:
        return None
    return available_days[(index * len(available_days)) // task_count]


def _find_capacity_day(
    day: date,
    *,
    minutes: int,
    daily_capacity_minutes: int,
    rest_weekdays: set[int],
    scheduled_minutes_by_day: dict[date, int],
) -> tuple[date, int]:
    current_day = _next_non_rest_day(day, rest_weekdays)
    while True:
        current_minutes = scheduled_minutes_by_day.get(current_day, 0)
        if not current_minutes or current_minutes + minutes <= daily_capacity_minutes:
            return current_day, current_minutes
        current_day = _next_non_rest_day(current_day + timedelta(days=1), rest_weekdays)


def plan_initial_draft_schedule(
    tasks: Mapping[Any, Mapping[str, Any]] | list[Mapping[str, Any]],
    *,
    start_date: date | str,
    deadline: date | str,
    daily_capacity_minutes: int,
    rest_weekdays: set[int] | frozenset[int] | None = None,
    existing_daily_minutes: Mapping[date | str, int] | None = None,
) -> dict[str, Any]:
    """Place draft tasks deterministically without using existing load to reshuffle them."""

    if daily_capacity_minutes <= 0:
        raise ValueError("daily_capacity_minutes must be positive")

    start = _coerce_date(start_date)
    due = _coerce_date(deadline)
    rest_days = set(DEFAULT_REST_WEEKDAYS if rest_weekdays is None else rest_weekdays)
    available_days = _non_rest_days_between(start, due, rest_days)
    ordered_tasks = list(_ordered_tasks(tasks))
    scheduled_minutes_by_day: dict[date, int] = {}
    scheduled_tasks: list[dict[str, Any]] = []
    last_scheduled_day: date | None = None

    for index, task, minutes in ordered_tasks:
        candidate_day = _spread_day_for_index(index, len(ordered_tasks), available_days)
        if candidate_day is None:
            candidate_day = _next_non_rest_day(start, rest_days)
        if last_scheduled_day is not None and candidate_day < last_scheduled_day:
            candidate_day = last_scheduled_day

        scheduled_day, current_minutes = _find_capacity_day(
            candidate_day,
            minutes=minutes,
            daily_capacity_minutes=daily_capacity_minutes,
            rest_weekdays=rest_days,
            scheduled_minutes_by_day=scheduled_minutes_by_day,
        )

        scheduled_task = dict(task)
        scheduled_task["order_index"] = index
        scheduled_task["scheduled_date"] = scheduled_day
        scheduled_task["target_minutes"] = minutes
        scheduled_tasks.append(scheduled_task)
        scheduled_minutes_by_day[scheduled_day] = current_minutes + minutes
        last_scheduled_day = scheduled_day

    existing_by_day = _existing_minutes_by_day(existing_daily_minutes)
    over_capacity_days = []
    for scheduled_day in sorted(scheduled_minutes_by_day):
        scheduled_minutes = scheduled_minutes_by_day[scheduled_day]
        existing_minutes = existing_by_day.get(scheduled_day, 0)
        total_minutes = scheduled_minutes + existing_minutes
        if total_minutes > daily_capacity_minutes:
            over_capacity_days.append(
                {
                    "date": scheduled_day,
                    "scheduled_minutes": scheduled_minutes,
                    "existing_minutes": existing_minutes,
                    "capacity_minutes": daily_capacity_minutes,
                    "over_by_minutes": total_minutes - daily_capacity_minutes,
                }
            )

    expected_late = any(task["scheduled_date"] > due for task in scheduled_tasks)
    return {
        "scheduled_tasks": scheduled_tasks,
        "over_capacity_days": over_capacity_days,
        "expected_late": expected_late,
        "status": _status(expected_late, bool(over_capacity_days)),
    }
