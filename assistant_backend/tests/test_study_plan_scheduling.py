"""Study plan deterministic scheduling tests."""

import importlib
from datetime import date

import pytest


def _scheduling_module():
    try:
        return importlib.import_module("src.study_plan.scheduling")
    except ModuleNotFoundError as exc:
        pytest.fail(f"Expected study plan scheduling module to exist: {exc}")


def _compiler_package(**overrides):
    package = {
        "status": "draft_review",
        "draft_id": 42,
        "compiler_package_version": 3,
        "tasks": [
            {
                "id": "task-1",
                "phase_id": "phase-1",
                "title": "Map the source",
                "estimated_minutes": 30,
                "classification": "essential",
                "completion_criteria": ["source map"],
                "source_refs": [{"id": "repo"}],
            }
        ],
    }
    package.update(overrides)
    return package


def test_scheduler_input_gate_passes_through_non_draft_compiler_statuses():
    scheduling = _scheduling_module()
    needs_input_package = _compiler_package(
        status="needs_input", questions=["Pick a target depth."]
    )
    compile_failed_package = _compiler_package(
        status="compile_failed",
        validation_errors=[{"field": "tasks", "message": "missing estimate"}],
    )

    needs_input = scheduling.schedule_draft_review(
        needs_input_package,
        deadline="2026-06-03",
        today=date(2026, 6, 1),
    )
    compile_failed = scheduling.schedule_draft_review(
        compile_failed_package,
        deadline="2026-06-03",
        today=date(2026, 6, 1),
    )

    assert needs_input == needs_input_package
    assert "scheduled_days" not in needs_input
    assert compile_failed == compile_failed_package
    assert "scheduler_trace" not in compile_failed


def test_scheduler_output_shape_defaults_and_draft_review_status():
    scheduling = _scheduling_module()

    review = scheduling.schedule_draft_review(
        _compiler_package(),
        deadline="2026-06-03",
        today=date(2026, 6, 1),
    )

    assert review["schema_version"] == 1
    assert review["draft_id"] == 42
    assert review["compiler_package_version"] == 3
    assert review["status"] == "draft_review"
    assert [day["date"] for day in review["scheduled_days"]] == [
        date(2026, 6, 1),
        date(2026, 6, 2),
        date(2026, 6, 3),
    ]
    first_day = review["scheduled_days"][0]
    assert first_day["raw_capacity_min"] == 60
    assert first_day["existing_load_min"] == 0
    assert first_day["usable_capacity_min"] == 60
    assert first_day["load_state"] == "within_budget"
    assert first_day["items"] == [
        {
            "task_id": "task-1",
            "phase_id": "phase-1",
            "session_id": "task-1",
            "parent_task_id": None,
            "sequence_index": 0,
            "scheduled_minutes": 30,
            "classification": "essential",
            "completion_criteria": ["source map"],
            "source_refs": [{"id": "repo"}],
            "normal_mode": {"minutes": 30, "title": "Map the source"},
            "fallback_mode": None,
        }
    ]
    assert review["unscheduled_tasks"] == []
    assert review["risk_report"]["fits_as_written"] is True
    assert review["risk_report"]["capacity_gap_minutes"] == 0
    assert review["infeasibility_options"] == []
    assert {assumption["field"] for assumption in review["assumptions"]} >= {
        "start_date",
        "deadline_type",
        "daily_capacity_min",
        "existing_active_load",
        "rest_weekdays",
        "unavailable_dates",
        "buffer_policy",
    }
    assert review["scheduler_trace"]["date_window"] == [
        "2026-06-01",
        "2026-06-02",
        "2026-06-03",
    ]


def test_scheduler_uses_package_anchors_and_preserves_compiler_assumptions():
    scheduling = _scheduling_module()

    review = scheduling.schedule_draft_review(
        _compiler_package(
            deadline="2026-06-03",
            daily_capacity_min=45,
            rest_weekdays=[0],
            unavailable_dates=["2026-06-03"],
            assumptions=[{"field": "source_summary", "assumption": "thin repo facts"}],
        ),
        today=date(2026, 6, 1),
    )

    assert [day["raw_capacity_min"] for day in review["scheduled_days"]] == [0, 45, 0]
    assert review["scheduled_days"][1]["items"][0]["task_id"] == "task-1"
    assert {assumption["field"] for assumption in review["assumptions"]} >= {
        "source_summary",
        "start_date",
        "deadline_type",
        "existing_active_load",
        "buffer_policy",
    }


def test_scheduler_preflight_needs_input_for_missing_invalid_or_empty_anchors():
    scheduling = _scheduling_module()

    missing_deadline = scheduling.schedule_draft_review(
        _compiler_package(),
        today=date(2026, 6, 1),
    )
    invalid_deadline = scheduling.schedule_draft_review(
        _compiler_package(),
        deadline="not-a-date",
        today=date(2026, 6, 1),
    )
    empty_tasks = scheduling.schedule_draft_review(
        _compiler_package(tasks=[]),
        deadline="2026-06-03",
        today=date(2026, 6, 1),
    )

    assert missing_deadline["status"] == "needs_input"
    assert missing_deadline["questions"] == [
        "What deadline or timebox should this plan use?"
    ]
    assert missing_deadline["scheduled_days"] == []
    assert {assumption["field"] for assumption in missing_deadline["assumptions"]} >= {
        "start_date",
        "deadline_type",
        "daily_capacity_min",
        "existing_active_load",
        "rest_weekdays",
        "unavailable_dates",
        "buffer_policy",
    }
    assert invalid_deadline["status"] == "needs_input"
    assert invalid_deadline["questions"] == [
        "What valid deadline or timebox should this plan use?"
    ]
    assert invalid_deadline["scheduled_days"] == []
    assert empty_tasks["status"] == "needs_input"
    assert empty_tasks["questions"] == [
        "Which validated task candidate should be scheduled?"
    ]
    assert empty_tasks["scheduled_days"] == []


def test_scheduler_preflight_needs_input_for_invalid_non_deadline_dates():
    scheduling = _scheduling_module()

    invalid_start = scheduling.schedule_draft_review(
        _compiler_package(),
        start_date="not-a-date",
        deadline="2026-06-03",
        today=date(2026, 6, 1),
    )
    invalid_unavailable = scheduling.schedule_draft_review(
        _compiler_package(),
        deadline="2026-06-03",
        today=date(2026, 6, 1),
        unavailable_dates=["not-a-date"],
    )
    invalid_existing_load = scheduling.schedule_draft_review(
        _compiler_package(),
        deadline="2026-06-03",
        today=date(2026, 6, 1),
        existing_active_load={"not-a-date": 30},
    )

    assert invalid_start["status"] == "needs_input"
    assert invalid_start["questions"] == [
        "What valid start date should this plan use?"
    ]
    assert {assumption["field"] for assumption in invalid_start["assumptions"]} >= {
        "deadline_type",
        "daily_capacity_min",
        "existing_active_load",
        "rest_weekdays",
        "unavailable_dates",
        "buffer_policy",
    }
    assert invalid_unavailable["status"] == "needs_input"
    assert invalid_unavailable["questions"] == [
        "Which unavailable date should be corrected?"
    ]
    assert invalid_unavailable["scheduled_days"] == []
    assert {assumption["field"] for assumption in invalid_unavailable["assumptions"]} >= {
        "start_date",
        "deadline_type",
        "daily_capacity_min",
        "existing_active_load",
        "rest_weekdays",
        "buffer_policy",
    }
    assert invalid_existing_load["status"] == "needs_input"
    assert invalid_existing_load["questions"] == [
        "Which existing-load date should be corrected?"
    ]
    assert invalid_existing_load["scheduled_days"] == []
    assert {assumption["field"] for assumption in invalid_existing_load["assumptions"]} >= {
        "start_date",
        "deadline_type",
        "daily_capacity_min",
        "rest_weekdays",
        "unavailable_dates",
        "buffer_policy",
    }


def test_scheduler_preflight_needs_input_for_invalid_capacity_or_rest_days():
    scheduling = _scheduling_module()

    invalid_capacity = scheduling.schedule_draft_review(
        _compiler_package(),
        deadline="2026-06-03",
        today=date(2026, 6, 1),
        daily_capacity_min="not-minutes",
    )
    invalid_rest_day = scheduling.schedule_draft_review(
        _compiler_package(),
        deadline="2026-06-03",
        today=date(2026, 6, 1),
        rest_weekdays=["not-a-weekday"],
    )
    invalid_rest_container = scheduling.schedule_draft_review(
        _compiler_package(),
        deadline="2026-06-03",
        today=date(2026, 6, 1),
        rest_weekdays=3,
    )
    invalid_unavailable_container = scheduling.schedule_draft_review(
        _compiler_package(),
        deadline="2026-06-03",
        today=date(2026, 6, 1),
        unavailable_dates=3,
    )
    invalid_existing_load_container = scheduling.schedule_draft_review(
        _compiler_package(),
        deadline="2026-06-03",
        today=date(2026, 6, 1),
        existing_active_load=[("2026-06-01", 30)],
    )

    assert invalid_capacity["status"] == "needs_input"
    assert invalid_capacity["questions"] == [
        "How many minutes per available day should this plan use?"
    ]
    assert invalid_rest_day["status"] == "needs_input"
    assert invalid_rest_day["questions"] == [
        "Which rest weekday should be corrected?"
    ]
    assert invalid_rest_container["status"] == "needs_input"
    assert invalid_rest_container["questions"] == [
        "Which rest weekday should be corrected?"
    ]
    assert invalid_unavailable_container["status"] == "needs_input"
    assert invalid_unavailable_container["questions"] == [
        "Which unavailable date should be corrected?"
    ]
    assert invalid_existing_load_container["status"] == "needs_input"
    assert invalid_existing_load_container["questions"] == [
        "Which existing-load date should be corrected?"
    ]


def test_scheduler_uses_inclusive_window_and_deadline_before_start_is_infeasible():
    scheduling = _scheduling_module()

    review = scheduling.schedule_draft_review(
        _compiler_package(),
        start_date="2026-06-01",
        deadline="2026-06-03",
        rest_weekdays=[],
    )
    infeasible = scheduling.schedule_draft_review(
        _compiler_package(
            tasks=[
                {
                    "id": "task-1",
                    "phase_id": "phase-1",
                    "title": "Essential work",
                    "estimated_minutes": 30,
                    "classification": "essential",
                },
                {
                    "id": "optional",
                    "phase_id": "phase-1",
                    "title": "Optional stretch",
                    "estimated_minutes": 20,
                    "classification": "optional",
                },
            ]
        ),
        start_date="2026-06-04",
        deadline="2026-06-03",
        rest_weekdays=[],
    )

    assert [day["date"] for day in review["scheduled_days"]] == [
        date(2026, 6, 1),
        date(2026, 6, 2),
        date(2026, 6, 3),
    ]
    assert infeasible["status"] == "infeasible_review"
    assert infeasible["scheduled_days"] == []
    assert infeasible["risk_report"]["date_window_risk"] == "deadline_before_start"
    assert infeasible["risk_report"]["expected_late_tasks"] == ["task-1"]
    assert infeasible["risk_report"]["capacity_gap_minutes"] == 30
    assert infeasible["risk_report"]["optional_unscheduled_minutes"] == 20


def test_scheduler_computes_capacity_with_existing_load_rest_unavailable_and_default_capacity():
    scheduling = _scheduling_module()

    review = scheduling.schedule_draft_review(
        _compiler_package(),
        start_date="2026-06-01",
        deadline="2026-06-03",
        rest_weekdays=[1],
        unavailable_dates=["2026-06-03"],
        existing_active_load={"2026-06-01": 20},
    )

    assert [
        (
            day["date"],
            day["raw_capacity_min"],
            day["existing_load_min"],
            day["usable_capacity_min"],
            day["load_state"],
        )
        for day in review["scheduled_days"]
    ] == [
        (date(2026, 6, 1), 60, 20, 40, "within_budget"),
        (date(2026, 6, 2), 0, 0, 0, "within_budget"),
        (date(2026, 6, 3), 0, 0, 0, "within_budget"),
    ]
    assert review["scheduled_days"][0]["planned_minutes"] == 30


def test_scheduler_reports_optional_unscheduled_minutes_without_blocking_draft_review():
    scheduling = _scheduling_module()

    review = scheduling.schedule_draft_review(
        _compiler_package(
            tasks=[
                {
                    "id": "essential",
                    "phase_id": "phase-1",
                    "title": "Essential work",
                    "estimated_minutes": 30,
                    "classification": "essential",
                },
                {
                    "id": "optional",
                    "phase_id": "phase-1",
                    "title": "Optional stretch",
                    "estimated_minutes": 45,
                    "classification": "optional",
                },
            ]
        ),
        start_date="2026-06-01",
        deadline="2026-06-01",
        daily_capacity_min=30,
        rest_weekdays=[],
    )

    assert review["status"] == "draft_review"
    assert review["risk_report"]["capacity_gap_minutes"] == 0
    assert review["risk_report"]["optional_unscheduled_minutes"] == 45
    assert review["unscheduled_tasks"] == [
        {
            "task_id": "optional",
            "estimated_minutes": 45,
            "classification": "optional",
            "reason": "insufficient_capacity",
        }
    ]


def test_scheduler_places_essential_work_before_optional_when_capacity_is_tight():
    scheduling = _scheduling_module()

    review = scheduling.schedule_draft_review(
        _compiler_package(
            tasks=[
                {
                    "id": "optional",
                    "phase_id": "phase-1",
                    "title": "Optional stretch",
                    "estimated_minutes": 60,
                    "classification": "optional",
                },
                {
                    "id": "essential",
                    "phase_id": "phase-1",
                    "title": "Essential work",
                    "estimated_minutes": 60,
                    "classification": "essential",
                },
            ]
        ),
        start_date="2026-06-01",
        deadline="2026-06-01",
        daily_capacity_min=60,
        rest_weekdays=[],
    )

    assert review["status"] == "draft_review"
    assert review["scheduled_days"][0]["items"][0]["task_id"] == "essential"
    assert review["unscheduled_tasks"][0]["task_id"] == "optional"


def test_scheduler_capacity_gap_reports_missing_minutes_not_whole_task_estimate():
    scheduling = _scheduling_module()

    review = scheduling.schedule_draft_review(
        _compiler_package(
            tasks=[
                {
                    "id": "oversized",
                    "phase_id": "phase-1",
                    "title": "Oversized essential",
                    "estimated_minutes": 90,
                    "classification": "essential",
                }
            ]
        ),
        start_date="2026-06-01",
        deadline="2026-06-01",
        daily_capacity_min=60,
        rest_weekdays=[],
    )

    assert review["status"] == "infeasible_review"
    assert review["risk_report"]["capacity_gap_minutes"] == 30
    assert review["risk_report"]["expected_late_tasks"] == ["oversized"]


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
