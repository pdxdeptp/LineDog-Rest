"""Study plan deterministic scheduling tests."""

import importlib
from datetime import date

import pytest


def _scheduling_module():
    try:
        return importlib.import_module("src.study_plan.scheduling")
    except ModuleNotFoundError as exc:
        pytest.fail(f"Expected study plan scheduling module to exist: {exc}")


def test_initial_schedule_is_deterministic_and_skips_default_saturday_rest_day():
    scheduling = _scheduling_module()
    tasks = [
        {"title": "Survey the syllabus", "estimated_minutes": 50},
        {"title": "Read chapter one", "estimated_minutes": 50},
        {"title": "Write retrieval notes", "estimated_minutes": 30},
    ]

    first = scheduling.plan_initial_draft_schedule(
        tasks,
        start_date=date(2026, 6, 5),
        deadline=date(2026, 6, 8),
        daily_capacity_minutes=60,
    )
    second = scheduling.plan_initial_draft_schedule(
        tasks,
        start_date=date(2026, 6, 5),
        deadline=date(2026, 6, 8),
        daily_capacity_minutes=60,
    )

    assert first == second
    assert [
        (task["title"], task["scheduled_date"], task["target_minutes"])
        for task in first["scheduled_tasks"]
    ] == [
        ("Survey the syllabus", date(2026, 6, 5), 50),
        ("Read chapter one", date(2026, 6, 7), 50),
        ("Write retrieval notes", date(2026, 6, 8), 30),
    ]
    assert all(task["scheduled_date"].weekday() != 5 for task in first["scheduled_tasks"])
    assert first["expected_late"] is False
    assert first["over_capacity_days"] == []
    assert first["status"] == "on_track"


def test_initial_schedule_spreads_tasks_across_available_days_when_window_has_room():
    scheduling = _scheduling_module()
    tasks = [
        {"title": "Read section one", "estimated_minutes": 60},
        {"title": "Read section two", "estimated_minutes": 60},
        {"title": "Practice examples", "estimated_minutes": 60},
        {"title": "Review notes", "estimated_minutes": 60},
    ]

    scheduled = scheduling.plan_initial_draft_schedule(
        tasks,
        start_date=date(2026, 6, 1),
        deadline=date(2026, 6, 4),
        daily_capacity_minutes=120,
    )

    assert [
        (task["title"], task["scheduled_date"])
        for task in scheduled["scheduled_tasks"]
    ] == [
        ("Read section one", date(2026, 6, 1)),
        ("Read section two", date(2026, 6, 2)),
        ("Practice examples", date(2026, 6, 3)),
        ("Review notes", date(2026, 6, 4)),
    ]
    assert scheduled["expected_late"] is False
    assert scheduled["over_capacity_days"] == []
    assert scheduled["status"] == "on_track"


def test_existing_daily_minutes_do_not_reshuffle_draft_but_mark_over_capacity_and_late():
    scheduling = _scheduling_module()
    tasks = [
        {"title": "Map topic structure", "estimated_minutes": 50},
        {"title": "Practice worked examples", "estimated_minutes": 50},
        {"title": "Summarize weak spots", "estimated_minutes": 50},
    ]

    unloaded = scheduling.plan_initial_draft_schedule(
        tasks,
        start_date=date(2026, 6, 1),
        deadline=date(2026, 6, 2),
        daily_capacity_minutes=60,
    )
    loaded = scheduling.plan_initial_draft_schedule(
        tasks,
        start_date=date(2026, 6, 1),
        deadline=date(2026, 6, 2),
        daily_capacity_minutes=60,
        existing_daily_minutes={
            date(2026, 6, 1): 20,
            date(2026, 6, 2): 20,
        },
    )

    assert [task["scheduled_date"] for task in loaded["scheduled_tasks"]] == [
        task["scheduled_date"] for task in unloaded["scheduled_tasks"]
    ]
    assert [task["scheduled_date"] for task in loaded["scheduled_tasks"]] == [
        date(2026, 6, 1),
        date(2026, 6, 2),
        date(2026, 6, 3),
    ]
    assert loaded["expected_late"] is True
    assert loaded["over_capacity_days"] == [
        {
            "date": date(2026, 6, 1),
            "scheduled_minutes": 50,
            "existing_minutes": 20,
            "capacity_minutes": 60,
            "over_by_minutes": 10,
        },
        {
            "date": date(2026, 6, 2),
            "scheduled_minutes": 50,
            "existing_minutes": 20,
            "capacity_minutes": 60,
            "over_by_minutes": 10,
        },
    ]
    assert loaded["status"] == "expected_late_over_capacity"
