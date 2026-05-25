"""Deterministic study plan draft scheduling."""

from __future__ import annotations

from collections.abc import Mapping
from datetime import date, timedelta
from typing import Any

DEFAULT_REST_WEEKDAYS = frozenset({5})
DEFAULT_DAILY_CAPACITY_MIN = 60
DEFAULT_BUFFER_POLICY = "standard_reservation"


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
    expected_late_tasks: list[str] | None = None,
    date_window_risk: str | None = None,
) -> dict[str, Any]:
    report = {
        "fits_as_written": fits,
        "capacity_gap_minutes": capacity_gap_minutes,
        "optional_unscheduled_minutes": optional_unscheduled_minutes,
        "overloaded_dates": [],
        "expected_late_tasks": list(expected_late_tasks or []),
        "buffer_days_reserved": [],
        "buffer_erosion": False,
        "estimate_confidence_summary": {},
        "existing_load_conflicts": [],
        "canonical_infeasibility_option_ids": [],
    }
    if date_window_risk:
        report["date_window_risk"] = date_window_risk
    return report


def _scheduled_item(task: Mapping[str, Any], *, index: int, minutes: int) -> dict[str, Any]:
    task_id = _task_id(task, index)
    return {
        "task_id": task_id,
        "phase_id": task.get("phase_id"),
        "session_id": task_id,
        "parent_task_id": None,
        "sequence_index": index,
        "scheduled_minutes": minutes,
        "classification": task.get("classification", "essential"),
        "completion_criteria": list(task.get("completion_criteria") or []),
        "source_refs": list(task.get("source_refs") or []),
        "normal_mode": {
            "minutes": minutes,
            "title": task.get("title") or task.get("name") or task_id,
        },
        "fallback_mode": task.get("fallback_mode"),
    }


def _load_state(planned: int, planning_budget: int, usable: int) -> str:
    if planned <= planning_budget:
        return "within_budget"
    if planned <= usable:
        return "over_budget"
    return "over_capacity"


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
                "planning_budget_min": usable_capacity,
                "planned_minutes": 0,
                "load_state": "within_budget",
                "items": [],
            }
        )

    unscheduled_tasks = []
    task_entries = list(enumerate(tasks))
    classification_order = {"essential": 0, "optional": 1, "stretch": 2}
    ordered_task_entries = sorted(
        task_entries,
        key=lambda entry: (
            classification_order.get(entry[1].get("classification", "essential"), 0),
            entry[0],
        ),
    )
    for index, task in ordered_task_entries:
        minutes = _task_minutes(task)
        placed = False
        for day_review in scheduled_days:
            remaining = day_review["usable_capacity_min"] - day_review["planned_minutes"]
            if minutes <= remaining:
                day_review["items"].append(
                    _scheduled_item(task, index=index, minutes=minutes)
                )
                day_review["planned_minutes"] += minutes
                day_review["load_state"] = _load_state(
                    day_review["planned_minutes"],
                    day_review["planning_budget_min"],
                    day_review["usable_capacity_min"],
                )
                placed = True
                break
        if not placed:
            unscheduled_tasks.append(
                {
                    "task_id": _task_id(task, index),
                    "estimated_minutes": minutes,
                    "classification": task.get("classification", "essential"),
                    "reason": "insufficient_capacity",
                }
            )

    essential_minutes = sum(
        _task_minutes(task)
        for _, task in task_entries
        if task.get("classification", "essential") == "essential"
    )
    available_minutes = sum(day["usable_capacity_min"] for day in scheduled_days)
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
    status = "infeasible_review" if expected_late_tasks else "draft_review"
    review = _base_review(
        compiler_package,
        status=status,
        assumptions=assumptions,
        scheduler_trace={
            "date_window": [day.isoformat() for day in _date_window(start, due)],
            "deadline_type": resolved_deadline_type,
            "buffer_policy": resolved_buffer_policy,
        },
    )
    review["scheduled_days"] = scheduled_days
    review["unscheduled_tasks"] = unscheduled_tasks
    review["risk_report"] = _risk_report(
        fits=status == "draft_review",
        capacity_gap_minutes=essential_gap,
        optional_unscheduled_minutes=optional_unscheduled_minutes,
        expected_late_tasks=expected_late_tasks,
    )
    return review


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
