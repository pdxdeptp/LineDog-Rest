"""Minimal D29 study plan decomposition pipeline orchestration."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from datetime import date
from typing import Any

from .scheduling import plan_initial_draft_schedule

DEFAULT_ESTIMATED_MINUTES = 45
STAGE_IDS = (
    "extract_structure",
    "estimate_difficulty",
    "estimate_durations",
    "merge_tasks",
    "schedule_draft",
)
STRUCTURED_MATERIAL_TYPES = frozenset(
    {
        "article",
        "bilibili_series",
        "book",
        "course",
        "documentation",
        "docs",
        "github_repo",
        "pdf",
        "structured_course",
        "syllabus",
        "web_article",
    }
)


def _get_value(source: Any, key: str, default: Any = None) -> Any:
    if isinstance(source, Mapping):
        return source.get(key, default)
    return getattr(source, key, default)


def _material_type(source: Any) -> str:
    value = _get_value(source, "material_type", None)
    if value is None:
        value = _get_value(source, "type", "unknown")
    return str(value or "unknown").strip().lower() or "unknown"


def _handler_for(material_type: str) -> str:
    if any(candidate in material_type for candidate in STRUCTURED_MATERIAL_TYPES):
        return "structured"
    return "generic_fallback"


def _stage_result(statuses: Mapping[str, str] | None = None) -> list[dict[str, str]]:
    return [
        {"id": stage_id, "status": (statuses or {}).get(stage_id, "completed")}
        for stage_id in STAGE_IDS
    ]


def _raw_units_from(source: Any) -> Sequence[Any]:
    units = _get_value(source, "units", None)
    if units:
        return units

    structure = _get_value(source, "structure", None)
    if structure:
        return structure

    return []


def _unit_value(unit: Any, key: str, default: Any = None) -> Any:
    if isinstance(unit, Mapping):
        return unit.get(key, default)
    return getattr(unit, key, default)


def _unit_title(unit: Any) -> str:
    if isinstance(unit, str):
        return unit.strip()

    for key in ("title", "name", "heading"):
        value = _unit_value(unit, key, None)
        if value:
            return str(value).strip()
    return ""


def _unit_order_index(unit: Any, fallback: int) -> int:
    value = _unit_value(unit, "order_index", fallback)
    try:
        return int(value)
    except (TypeError, ValueError):
        return fallback


def _extract_ordered_units(source: Any) -> list[dict[str, Any]]:
    units = []
    for fallback_index, unit in enumerate(_raw_units_from(source)):
        title = _unit_title(unit)
        if not title:
            continue
        units.append(
            {
                "title": title,
                "source_order_index": _unit_order_index(unit, fallback_index),
                "estimated_minutes": _unit_value(unit, "estimated_minutes", None),
                "_input_index": fallback_index,
            }
        )

    units.sort(key=lambda unit: (unit["source_order_index"], unit["_input_index"]))
    return units


def _estimate_difficulty(clarification: Mapping[str, Any]) -> str:
    answers = clarification.get("answers") or clarification.get("defaults") or {}
    answer_values = {str(value).lower() for value in answers.values()}

    if "new_to_topic" in answer_values:
        return "introductory"
    if {"exam", "produce", "portfolio_artifact"} & answer_values:
        return "advanced"
    return "standard"


def _coerce_positive_minutes(value: Any) -> int | None:
    try:
        minutes = int(value)
    except (TypeError, ValueError):
        return None
    if minutes <= 0:
        return None
    return minutes


def _default_minutes_for(_difficulty: str) -> int:
    return DEFAULT_ESTIMATED_MINUTES


def _merge_draft_tasks(units: list[dict[str, Any]], difficulty: str) -> list[dict[str, Any]]:
    tasks = []
    for order_index, unit in enumerate(units):
        estimated_minutes = (
            _coerce_positive_minutes(unit["estimated_minutes"])
            or _default_minutes_for(difficulty)
        )
        tasks.append(
            {
                "title": unit["title"],
                "order_index": order_index,
                "estimated_minutes": estimated_minutes,
            }
        )
    return tasks


def _failure_response(
    *,
    handler: str,
    material_type: str,
    clarification: Mapping[str, Any],
    message: str,
) -> dict[str, Any]:
    return {
        "status": "needs_user_visible_failure",
        "handler": handler,
        "material_type": material_type,
        "stages": _stage_result(
            {
                "extract_structure": "failed",
                "estimate_difficulty": "skipped",
                "estimate_durations": "skipped",
                "merge_tasks": "skipped",
                "schedule_draft": "skipped",
            }
        ),
        "draft_tasks": [],
        "schedule_status": "not_scheduled",
        "expected_late": False,
        "over_capacity_days": [],
        "clarification_skipped": bool(clarification.get("clarification_skipped", False)),
        "low_calibration": bool(clarification.get("low_calibration", False)),
        "message": message,
    }


def build_decomposition_pipeline(
    source: dict[str, Any],
    clarification: dict[str, Any],
    *,
    start_date: date | str,
    deadline: date | str,
    daily_capacity_minutes: int,
    rest_weekdays: set[int] | frozenset[int] | None = None,
    existing_daily_minutes: Mapping[date | str, int] | None = None,
) -> dict[str, Any]:
    """Build ordered draft tasks from source units, then schedule them with D24."""

    clarification_payload = clarification or {}
    material_type = _material_type(source)
    handler = _handler_for(material_type)
    ordered_units = _extract_ordered_units(source)

    if not ordered_units:
        return _failure_response(
            handler=handler,
            material_type=material_type,
            clarification=clarification_payload,
            message=(
                "Could not identify study units from this material. "
                "Please add structure or try another source."
            ),
        )

    difficulty = _estimate_difficulty(clarification_payload)
    draft_tasks = _merge_draft_tasks(ordered_units, difficulty)
    schedule = plan_initial_draft_schedule(
        draft_tasks,
        start_date=start_date,
        deadline=deadline,
        daily_capacity_minutes=daily_capacity_minutes,
        rest_weekdays=rest_weekdays,
        existing_daily_minutes=existing_daily_minutes,
    )

    return {
        "status": "draft_ready",
        "handler": handler,
        "material_type": material_type,
        "stages": _stage_result(),
        "difficulty": difficulty,
        "draft_tasks": schedule["scheduled_tasks"],
        "schedule_status": schedule["status"],
        "expected_late": schedule["expected_late"],
        "over_capacity_days": schedule["over_capacity_days"],
        "clarification_skipped": bool(
            clarification_payload.get("clarification_skipped", False)
        ),
        "low_calibration": bool(clarification_payload.get("low_calibration", False)),
    }
