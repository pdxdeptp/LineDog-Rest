"""Deterministic study plan draft scheduling."""

from __future__ import annotations

from collections.abc import Mapping
from datetime import date, timedelta
from typing import Any

DEFAULT_REST_WEEKDAYS = frozenset({5})


def _coerce_date(value: date | str) -> date:
    if isinstance(value, date):
        return value
    if isinstance(value, str):
        return date.fromisoformat(value)
    raise TypeError(f"Expected date or ISO date string, got {type(value).__name__}")


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
