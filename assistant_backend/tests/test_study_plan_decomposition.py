"""Study plan D29 decomposition pipeline tests."""

import importlib
from datetime import date

import pytest


def _decomposition_module():
    try:
        return importlib.import_module("src.study_plan.decomposition")
    except ModuleNotFoundError as exc:
        pytest.fail(f"Expected study plan decomposition module to exist: {exc}")


def test_structured_source_runs_ordered_pipeline_and_schedules_draft_tasks():
    decomposition = _decomposition_module()

    result = decomposition.build_decomposition_pipeline(
        {
            "title": "SQLite Query Planner",
            "url": "https://example.com/sqlite-query-planner",
            "material_type": "documentation",
            "units": [
                {"title": "Planner overview", "order_index": 0, "estimated_minutes": 30},
                {"title": "Index selection", "order_index": 1, "estimated_minutes": 45},
                {"title": "EXPLAIN practice", "order_index": 2, "estimated_minutes": 30},
            ],
        },
        {"answers": {"goal_depth": "understand_and_apply"}},
        start_date=date(2026, 6, 1),
        deadline=date(2026, 6, 3),
        daily_capacity_minutes=60,
        rest_weekdays=set(),
    )

    assert result["status"] == "draft_ready"
    assert result["handler"] == "structured"
    assert [stage["id"] for stage in result["stages"]] == [
        "extract_structure",
        "estimate_difficulty",
        "estimate_durations",
        "merge_tasks",
        "schedule_draft",
    ]
    assert [
        (
            task["title"],
            task["order_index"],
            task["estimated_minutes"],
            task["scheduled_date"],
            task["target_minutes"],
        )
        for task in result["draft_tasks"]
    ] == [
        ("Planner overview", 0, 30, date(2026, 6, 1), 30),
        ("Index selection", 1, 45, date(2026, 6, 2), 45),
        ("EXPLAIN practice", 2, 30, date(2026, 6, 3), 30),
    ]
    assert result["schedule_status"] == "on_track"
    assert result["expected_late"] is False
    assert result["over_capacity_days"] == []


def test_skipped_clarification_low_calibration_marker_is_preserved_for_review():
    decomposition = _decomposition_module()

    result = decomposition.build_decomposition_pipeline(
        {
            "title": "Distributed Systems Primer",
            "material_type": "article",
            "units": [{"title": "Consensus basics", "order_index": 0}],
        },
        {
            "answers": {"focus_scope": "recommended_focus"},
            "clarification_skipped": True,
            "low_calibration": True,
        },
        start_date=date(2026, 6, 1),
        deadline=date(2026, 6, 5),
        daily_capacity_minutes=45,
    )

    assert result["status"] == "draft_ready"
    assert result["clarification_skipped"] is True
    assert result["low_calibration"] is True


def test_unknown_material_with_units_uses_generic_fallback_and_keeps_order():
    decomposition = _decomposition_module()

    result = decomposition.build_decomposition_pipeline(
        {
            "title": "Mystery Learning Material",
            "material_type": "unclassified_blob",
            "units": [
                {"title": "First discovered section", "order_index": 0, "estimated_minutes": 35},
                {"title": "Second discovered section", "order_index": 1, "estimated_minutes": 40},
            ],
        },
        {"answers": {}},
        start_date=date(2026, 6, 1),
        deadline=date(2026, 6, 4),
        daily_capacity_minutes=60,
    )

    assert result["status"] == "draft_ready"
    assert result["handler"] == "generic_fallback"
    assert [task["title"] for task in result["draft_tasks"]] == [
        "First discovered section",
        "Second discovered section",
    ]
    assert [task["order_index"] for task in result["draft_tasks"]] == [0, 1]


def test_unknown_empty_material_returns_user_visible_failure_without_draft_tasks():
    decomposition = _decomposition_module()

    result = decomposition.build_decomposition_pipeline(
        {
            "title": "Empty Mystery Material",
            "material_type": "unclassified_blob",
            "units": [],
        },
        {"answers": {}},
        start_date=date(2026, 6, 1),
        deadline=date(2026, 6, 4),
        daily_capacity_minutes=60,
    )

    assert result["status"] == "needs_user_visible_failure"
    assert result["handler"] == "generic_fallback"
    assert result["draft_tasks"] == []
    assert result["message"]
    assert "could not identify" in result["message"].lower()


def test_duration_estimation_preserves_known_minutes_and_uses_deterministic_default():
    decomposition = _decomposition_module()

    result = decomposition.build_decomposition_pipeline(
        {
            "title": "Queueing Theory Notes",
            "material_type": "article",
            "units": [
                {"title": "Little's Law", "order_index": 0, "estimated_minutes": 70},
                {"title": "M/M/1 queues", "order_index": 1},
            ],
        },
        {"answers": {"level_familiarity": "new_to_topic"}},
        start_date=date(2026, 6, 1),
        deadline=date(2026, 6, 5),
        daily_capacity_minutes=90,
    )

    assert result["status"] == "draft_ready"
    assert [
        (task["title"], task["estimated_minutes"])
        for task in result["draft_tasks"]
    ] == [
        ("Little's Law", 70),
        ("M/M/1 queues", 45),
    ]
