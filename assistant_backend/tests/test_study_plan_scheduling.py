"""Study plan deterministic scheduling tests."""

from copy import deepcopy
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
        daily_capacity_min=40,
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
        daily_capacity_min=80,
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
    assert review["risk_report"]["capacity_gap_minutes"] == 42
    assert review["risk_report"]["expected_late_tasks"] == ["oversized"]


def test_scheduler_buffer_reservation_uses_planning_budget_and_blocks_erosion():
    scheduling = _scheduling_module()

    no_buffer = scheduling.schedule_draft_review(
        _compiler_package(
            tasks=[
                {
                    "id": "day-1",
                    "phase_id": "phase-1",
                    "title": "Short window work",
                    "estimated_minutes": 80,
                    "classification": "essential",
                }
            ]
        ),
        start_date="2026-06-01",
        deadline="2026-06-02",
        daily_capacity_min=100,
        rest_weekdays=[],
    )
    eroded = scheduling.schedule_draft_review(
        _compiler_package(
            tasks=[
                {
                    "id": f"essential-{index}",
                    "phase_id": "phase-1",
                    "title": f"Essential {index}",
                    "estimated_minutes": 80,
                    "classification": "essential",
                }
                for index in range(1, 4)
            ]
        ),
        start_date="2026-06-01",
        deadline="2026-06-03",
        daily_capacity_min=100,
        rest_weekdays=[],
    )
    accepted_buffer_risk = scheduling.schedule_draft_review(
        _compiler_package(
            tasks=[
                {
                    "id": f"essential-{index}",
                    "phase_id": "phase-1",
                    "title": f"Essential {index}",
                    "estimated_minutes": 80,
                    "classification": "essential",
                }
                for index in range(1, 4)
            ],
            accepted_risks=["buffer_erosion"],
        ),
        start_date="2026-06-01",
        deadline="2026-06-03",
        daily_capacity_min=100,
        rest_weekdays=[],
    )

    assert [day["planning_budget_min"] for day in no_buffer["scheduled_days"]] == [
        80,
        80,
    ]
    assert no_buffer["risk_report"]["buffer_days_reserved"] == []
    assert no_buffer["risk_report"]["fits_as_written"] is True
    assert [day["reserved_buffer"] for day in eroded["scheduled_days"]] == [
        False,
        False,
        True,
    ]
    assert eroded["scheduled_days"][2]["items"][0]["task_id"] == "essential-3"
    assert eroded["scheduled_days"][2]["load_state"] == "uses_buffer"
    assert eroded["status"] == "infeasible_review"
    assert eroded["risk_report"]["buffer_days_reserved"] == ["2026-06-03"]
    assert eroded["risk_report"]["buffer_erosion"] is True
    assert accepted_buffer_risk["status"] == "draft_review"
    assert accepted_buffer_risk["risk_report"]["buffer_erosion"] is True


def test_scheduler_load_shape_tie_breakers_change_distribution_only():
    scheduling = _scheduling_module()
    tasks = [
        {
            "id": f"task-{index}",
            "phase_id": "phase-1",
            "title": f"Task {index}",
            "estimated_minutes": 25,
            "classification": "essential",
        }
        for index in range(1, 5)
    ]

    balanced = scheduling.schedule_draft_review(
        _compiler_package(tasks=tasks, load_shape="balanced"),
        start_date="2026-06-01",
        deadline="2026-06-02",
        daily_capacity_min=100,
        rest_weekdays=[],
    )
    front_loaded = scheduling.schedule_draft_review(
        _compiler_package(tasks=tasks, load_shape="front_loaded"),
        start_date="2026-06-01",
        deadline="2026-06-02",
        daily_capacity_min=100,
        rest_weekdays=[],
    )
    light_start = scheduling.schedule_draft_review(
        _compiler_package(tasks=tasks, load_shape="light_start"),
        start_date="2026-06-01",
        deadline="2026-06-02",
        daily_capacity_min=100,
        rest_weekdays=[],
    )

    assert [day["planned_minutes"] for day in balanced["scheduled_days"]] == [50, 50]
    assert [day["planned_minutes"] for day in front_loaded["scheduled_days"]] == [75, 25]
    assert [day["planned_minutes"] for day in light_start["scheduled_days"]] == [25, 75]
    assert {
        item["task_id"]
        for review in (balanced, front_loaded, light_start)
        for day in review["scheduled_days"]
        for item in day["items"]
    } == {"task-1", "task-2", "task-3", "task-4"}


def test_scheduler_preserves_dependency_order_and_places_optional_last():
    scheduling = _scheduling_module()

    review = scheduling.schedule_draft_review(
        _compiler_package(
            tasks=[
                {
                    "id": "optional",
                    "phase_id": "phase-1",
                    "title": "Optional polish",
                    "estimated_minutes": 40,
                    "classification": "optional",
                },
                {
                    "id": "prep",
                    "phase_id": "phase-1",
                    "title": "Prepare core",
                    "estimated_minutes": 60,
                    "classification": "essential",
                },
                {
                    "id": "build",
                    "phase_id": "phase-1",
                    "title": "Build after prep",
                    "estimated_minutes": 60,
                    "classification": "essential",
                    "depends_on": ["prep"],
                },
            ]
        ),
        start_date="2026-06-01",
        deadline="2026-06-02",
        daily_capacity_min=80,
        rest_weekdays=[],
    )

    placements = {
        item["task_id"]: (day["date"], item["sequence_index"])
        for day in review["scheduled_days"]
        for item in day["items"]
    }
    assert placements["prep"] <= placements["build"]
    assert review["unscheduled_tasks"] == [
        {
            "task_id": "optional",
            "estimated_minutes": 40,
            "classification": "optional",
            "reason": "insufficient_capacity",
        }
    ]


def test_scheduler_reorders_ready_tasks_to_preserve_dependencies():
    scheduling = _scheduling_module()

    review = scheduling.schedule_draft_review(
        _compiler_package(
            tasks=[
                {
                    "id": "build",
                    "phase_id": "phase-1",
                    "title": "Build after prep",
                    "estimated_minutes": 60,
                    "classification": "essential",
                    "depends_on": ["prep"],
                },
                {
                    "id": "prep",
                    "phase_id": "phase-1",
                    "title": "Prepare core",
                    "estimated_minutes": 60,
                    "classification": "essential",
                },
            ]
        ),
        start_date="2026-06-01",
        deadline="2026-06-02",
        daily_capacity_min=80,
        rest_weekdays=[],
    )

    ordered_items = [
        item["task_id"]
        for day in review["scheduled_days"]
        for item in day["items"]
    ]
    assert review["status"] == "draft_review"
    assert ordered_items == ["prep", "build"]
    assert review["unscheduled_tasks"] == []


def test_scheduler_continuation_sessions_preserve_parent_identity_and_context():
    scheduling = _scheduling_module()

    review = scheduling.schedule_draft_review(
        _compiler_package(
            tasks=[
                {
                    "id": "essay",
                    "phase_id": "phase-1",
                    "title": "Write project essay",
                    "estimated_minutes": 160,
                    "classification": "essential",
                    "completion_criteria": ["draft", "revise"],
                    "source_refs": [{"id": "brief"}],
                    "split_points": [
                        {"id": "outline", "minutes": 80, "output": "outline"},
                        {"id": "draft", "minutes": 80, "output": "draft"},
                    ],
                }
            ]
        ),
        start_date="2026-06-01",
        deadline="2026-06-02",
        daily_capacity_min=100,
        rest_weekdays=[],
    )

    sessions = [
        (day, item)
        for day in review["scheduled_days"]
        for item in day["items"]
    ]
    assert [item["task_id"] for _, item in sessions] == ["essay", "essay"]
    assert [item["session_id"] for _, item in sessions] == [
        "essay:outline",
        "essay:draft",
    ]
    assert [day["date"] for day, _ in sessions] == [
        date(2026, 6, 1),
        date(2026, 6, 2),
    ]
    assert [day["planned_minutes"] for day in review["scheduled_days"]] == [80, 80]
    assert [item["parent_task_id"] for _, item in sessions] == ["essay", "essay"]
    assert [item["sequence_index"] for _, item in sessions] == [0, 1]
    assert [item["normal_mode"]["output"] for _, item in sessions] == [
        "outline",
        "draft",
    ]
    assert sessions[0][1]["classification"] == "essential"
    assert sessions[0][1]["completion_criteria"] == ["draft", "revise"]
    assert sessions[0][1]["source_refs"] == [{"id": "brief"}]


def test_scheduler_numeric_continuation_sessions_include_visible_note():
    scheduling = _scheduling_module()

    review = scheduling.schedule_draft_review(
        _compiler_package(
            tasks=[
                {
                    "id": "essay",
                    "phase_id": "phase-1",
                    "title": "Write project essay",
                    "estimated_minutes": 160,
                    "classification": "essential",
                    "multi_session_minutes": [80, 80],
                }
            ]
        ),
        start_date="2026-06-01",
        deadline="2026-06-02",
        daily_capacity_min=100,
        rest_weekdays=[],
    )

    assert [
        item["normal_mode"]["output"]
        for day in review["scheduled_days"]
        for item in day["items"]
    ] == ["Continuation 1", "Continuation 2"]


def test_scheduler_rejects_split_sessions_that_do_not_conserve_parent_estimate():
    scheduling = _scheduling_module()

    review = scheduling.schedule_draft_review(
        _compiler_package(
            tasks=[
                {
                    "id": "essay",
                    "phase_id": "phase-1",
                    "title": "Write project essay",
                    "estimated_minutes": 160,
                    "classification": "essential",
                    "split_points": [
                        {"id": "outline", "minutes": 80, "output": "outline"}
                    ],
                }
            ]
        ),
        start_date="2026-06-01",
        deadline="2026-06-02",
        daily_capacity_min=100,
        rest_weekdays=[],
    )

    assert review["status"] == "infeasible_review"
    assert review["scheduled_days"][0]["items"] == []
    assert review["unscheduled_tasks"] == [
        {
            "task_id": "essay",
            "estimated_minutes": 160,
            "classification": "essential",
            "reason": "split_estimate_mismatch",
        }
    ]
    assert review["risk_report"]["expected_late_tasks"] == ["essay"]


def test_scheduler_rolls_back_trial_buffer_erosion_when_split_task_cannot_fit():
    scheduling = _scheduling_module()

    review = scheduling.schedule_draft_review(
        _compiler_package(
            tasks=[
                {
                    "id": "too-big",
                    "phase_id": "phase-1",
                    "title": "Too much work",
                    "estimated_minutes": 320,
                    "classification": "essential",
                    "split_points": [
                        {"id": "one", "minutes": 80, "output": "one"},
                        {"id": "two", "minutes": 80, "output": "two"},
                        {"id": "three", "minutes": 80, "output": "three"},
                        {"id": "four", "minutes": 80, "output": "four"},
                    ],
                }
            ]
        ),
        start_date="2026-06-01",
        deadline="2026-06-03",
        daily_capacity_min=100,
        rest_weekdays=[],
    )

    assert review["status"] == "infeasible_review"
    assert all(day["items"] == [] for day in review["scheduled_days"])
    assert review["risk_report"]["buffer_erosion"] is False
    assert review["unscheduled_tasks"][0]["task_id"] == "too-big"


def test_scheduler_fallback_metadata_is_not_counted_as_active_task_completion():
    scheduling = _scheduling_module()
    compiler_package = _compiler_package(
        tasks=[
            {
                "id": "normal-work",
                "phase_id": "phase-1",
                "title": "Normal work",
                "estimated_minutes": 60,
                "classification": "essential",
                "fallback_mode": {
                    "fallback_minutes": 15,
                    "fallback_output": "skim notes",
                    "risk_effect": "preserves_momentum",
                },
            }
        ],
        today_actions=["must not be touched"],
    )
    before = deepcopy(compiler_package)

    review = scheduling.schedule_draft_review(
        compiler_package,
        start_date="2026-06-01",
        deadline="2026-06-01",
        daily_capacity_min=100,
        rest_weekdays=[],
    )

    item = review["scheduled_days"][0]["items"][0]
    assert compiler_package == before
    assert item["normal_mode"]["minutes"] == 60
    assert item["fallback_mode"] == {
        "fallback_minutes": 15,
        "fallback_output": "skim notes",
        "risk_effect": "preserves_momentum",
    }
    assert review["scheduled_days"][0]["planned_minutes"] == 60
    assert "today_actions" not in review
    assert "active_tasks" not in review
    item["fallback_mode"]["fallback_minutes"] = 1
    assert compiler_package["tasks"][0]["fallback_mode"]["fallback_minutes"] == 15


def test_scheduler_risk_report_includes_capacity_gap_rough_estimates_and_existing_load_conflicts():
    scheduling = _scheduling_module()

    review = scheduling.schedule_draft_review(
        _compiler_package(
            tasks=[
                {
                    "id": "fit",
                    "phase_id": "phase-1",
                    "title": "Fits with conflict",
                    "estimated_minutes": 60,
                    "classification": "essential",
                    "estimate_confidence": "low",
                },
                {
                    "id": "oversized",
                    "phase_id": "phase-1",
                    "title": "Too large",
                    "estimated_minutes": 120,
                    "classification": "essential",
                    "estimate_confidence": "rough",
                },
                {
                    "id": "stretch",
                    "phase_id": "phase-1",
                    "title": "Stretch",
                    "estimated_minutes": 60,
                    "classification": "stretch",
                    "estimate_confidence": "high",
                },
            ]
        ),
        start_date="2026-06-01",
        deadline="2026-06-01",
        daily_capacity_min=100,
        existing_active_load={"2026-06-01": 20},
        rest_weekdays=[],
    )

    assert review["status"] == "infeasible_review"
    assert review["risk_report"]["capacity_gap_minutes"] == 116
    assert review["risk_report"]["optional_unscheduled_minutes"] == 60
    assert review["risk_report"]["expected_late_tasks"] == ["oversized"]
    assert review["risk_report"]["estimate_confidence_summary"] == {
        "low": 1,
        "rough": 1,
        "high": 1,
    }
    assert review["risk_report"]["existing_load_conflicts"] == ["2026-06-01"]


def test_scheduler_reports_accepted_overloaded_dates_without_hiding_risk():
    scheduling = _scheduling_module()

    review = scheduling.schedule_draft_review(
        _compiler_package(
            tasks=[
                {
                    "id": "overload",
                    "phase_id": "phase-1",
                    "title": "Accepted heavy day",
                    "estimated_minutes": 90,
                    "classification": "essential",
                }
            ],
            accepted_risks=["accept_overload"],
            accepted_overload_dates=["2026-06-01"],
        ),
        start_date="2026-06-01",
        deadline="2026-06-01",
        daily_capacity_min=100,
        existing_active_load={"2026-06-01": 20},
        rest_weekdays=[],
    )

    assert review["status"] == "draft_review"
    assert review["scheduled_days"][0]["planned_minutes"] == 90
    assert review["scheduled_days"][0]["load_state"] == "over_capacity"
    assert review["risk_report"]["overloaded_dates"] == ["2026-06-01"]


def test_scheduler_accepts_overload_when_existing_load_consumes_all_usable_capacity():
    scheduling = _scheduling_module()

    review = scheduling.schedule_draft_review(
        _compiler_package(
            tasks=[
                {
                    "id": "overload-zero-usable",
                    "phase_id": "phase-1",
                    "title": "Accepted full-load day",
                    "estimated_minutes": 30,
                    "classification": "essential",
                }
            ],
            accepted_risks=["accept_overload"],
            accepted_overload_dates=["2026-06-01"],
        ),
        start_date="2026-06-01",
        deadline="2026-06-01",
        daily_capacity_min=60,
        existing_active_load={"2026-06-01": 60},
        rest_weekdays=[],
    )

    assert review["status"] == "draft_review"
    assert review["scheduled_days"][0]["usable_capacity_min"] == 0
    assert review["scheduled_days"][0]["planned_minutes"] == 30
    assert review["scheduled_days"][0]["load_state"] == "over_capacity"
    assert review["risk_report"]["overloaded_dates"] == ["2026-06-01"]


def test_scheduler_capacity_gap_excludes_unaccepted_reserved_buffer():
    scheduling = _scheduling_module()

    review = scheduling.schedule_draft_review(
        _compiler_package(
            tasks=[
                {
                    "id": f"essential-{index}",
                    "phase_id": "phase-1",
                    "title": f"Essential {index}",
                    "estimated_minutes": 80,
                    "classification": "essential",
                }
                for index in range(1, 4)
            ]
        ),
        start_date="2026-06-01",
        deadline="2026-06-03",
        daily_capacity_min=100,
        rest_weekdays=[],
    )

    assert review["status"] == "infeasible_review"
    assert review["risk_report"]["capacity_gap_minutes"] == 80
    assert review["risk_report"]["buffer_erosion"] is True


def test_scheduler_option_mapping_includes_canonical_choices_and_hard_deadline_guard():
    scheduling = _scheduling_module()

    review = scheduling.schedule_draft_review(
        _compiler_package(
            deadline_type="hard",
            tasks=[
                {
                    "id": "fit",
                    "phase_id": "phase-1",
                    "title": "Fits with conflict",
                    "estimated_minutes": 60,
                    "classification": "essential",
                    "estimate_confidence": "low",
                },
                {
                    "id": "oversized",
                    "phase_id": "phase-1",
                    "title": "Too large",
                    "estimated_minutes": 120,
                    "classification": "essential",
                    "estimate_confidence": "rough",
                },
                {
                    "id": "stretch",
                    "phase_id": "phase-1",
                    "title": "Stretch",
                    "estimated_minutes": 60,
                    "classification": "stretch",
                    "estimate_confidence": "high",
                },
            ],
        ),
        start_date="2026-06-01",
        deadline="2026-06-01",
        daily_capacity_min=100,
        existing_active_load={"2026-06-01": 20},
        rest_weekdays=[],
    )

    option_ids = review["risk_report"]["canonical_infeasibility_option_ids"]
    assert option_ids == [
        "reduce_scope",
        "lower_depth",
        "extend_deadline",
        "increase_capacity",
        "accept_crunch",
        "answer_one_question",
        "edit_estimates",
        "accept_rough_draft",
        "store_for_later",
    ]
    assert "accept_late_finish" not in option_ids
    assert [option["id"] for option in review["infeasibility_options"]] == option_ids
    option_facts = {
        fact
        for option in review["infeasibility_options"]
        for fact in option["facts"]
    }
    assert option_facts >= {
        "capacity_gap",
        "expected_late",
        "low_calibration",
    }


def test_scheduler_late_finish_option_is_only_available_for_soft_deadline():
    scheduling = _scheduling_module()
    package = _compiler_package(
        tasks=[
            {
                "id": "oversized",
                "phase_id": "phase-1",
                "title": "Too large",
                "estimated_minutes": 120,
                "classification": "essential",
            }
        ]
    )

    hard = scheduling.schedule_draft_review(
        _compiler_package(**package, deadline_type="hard"),
        start_date="2026-06-01",
        deadline="2026-06-01",
        daily_capacity_min=100,
        rest_weekdays=[],
    )
    soft = scheduling.schedule_draft_review(
        _compiler_package(**package, deadline_type="soft"),
        start_date="2026-06-01",
        deadline="2026-06-01",
        daily_capacity_min=100,
        rest_weekdays=[],
    )

    assert "accept_late_finish" not in hard["risk_report"]["canonical_infeasibility_option_ids"]
    assert "accept_late_finish" in soft["risk_report"]["canonical_infeasibility_option_ids"]


def test_scheduler_option_effects_return_review_or_storage_not_activation():
    scheduling = _scheduling_module()
    package = _compiler_package(
        start_date="2026-06-01",
        deadline="2026-06-01",
        daily_capacity_min=100,
        rest_weekdays=[],
        tasks=[
            {
                "id": "heavy",
                "phase_id": "phase-1",
                "title": "Heavy essential",
                "estimated_minutes": 90,
                "classification": "essential",
            }
        ],
    )

    increased = scheduling.apply_schedule_option(
        package,
        "increase_capacity",
        new_daily_capacity_min=120,
    )
    stored = scheduling.apply_schedule_option(package, "store_for_later")

    assert increased["status"] == "draft_review"
    assert increased["option_effect"]["id"] == "increase_capacity"
    assert increased["option_effect"]["effect_type"] == "review_recompute"
    assert "active_tasks" not in increased
    assert "today_actions" not in increased
    assert stored == {
        "schema_version": 1,
        "draft_id": 42,
        "status": "stored_for_later",
        "active_tasks": [],
        "today_actions": [],
        "option_effect": {
            "id": "store_for_later",
            "effect_type": "storage_state",
        },
    }


def test_scheduler_reduce_scope_option_reruns_without_optional_or_stretch_work():
    scheduling = _scheduling_module()
    package = _compiler_package(
        start_date="2026-06-01",
        deadline="2026-06-01",
        daily_capacity_min=100,
        rest_weekdays=[],
        tasks=[
            {
                "id": "essential",
                "phase_id": "phase-1",
                "title": "Essential",
                "estimated_minutes": 70,
                "classification": "essential",
                "depth_evidence": {"target_depth": "project"},
            },
            {
                "id": "optional",
                "phase_id": "phase-1",
                "title": "Optional",
                "estimated_minutes": 70,
                "classification": "optional",
            },
            {
                "id": "stretch",
                "phase_id": "phase-1",
                "title": "Stretch",
                "estimated_minutes": 30,
                "classification": "stretch",
            },
        ],
    )

    reduced = scheduling.apply_schedule_option(package, "reduce_scope")

    assert [item["task_id"] for day in reduced["scheduled_days"] for item in day["items"]] == [
        "essential"
    ]
    assert reduced["unscheduled_tasks"] == []
    assert reduced["option_effect"]["removed_task_ids"] == ["optional", "stretch"]
    assert reduced["option_effect"]["preserved_essential_task_ids"] == ["essential"]
    assert reduced["option_effect"]["before"]["optional_unscheduled_minutes"] == 100
    assert reduced["option_effect"]["after"]["optional_unscheduled_minutes"] == 0


def test_scheduler_lower_depth_and_answer_one_question_options_return_compiler_handoffs():
    scheduling = _scheduling_module()
    package = _compiler_package(
        start_date="2026-06-01",
        deadline="2026-06-01",
        daily_capacity_min=100,
        rest_weekdays=[],
        tasks=[
            {
                "id": "rough",
                "phase_id": "phase-1",
                "title": "Rough work",
                "estimated_minutes": 120,
                "classification": "essential",
                "estimate_confidence": "rough",
            }
        ],
    )

    lower_depth = scheduling.apply_schedule_option(
        package,
        "lower_depth",
        requested_depth="can_use",
    )
    answer_question = scheduling.apply_schedule_option(
        package,
        "answer_one_question",
        question_id="estimate_confidence",
    )

    assert lower_depth["status"] == "compiler_recompute_required"
    assert lower_depth["compiler_recompute_required"]["reason"] == "lower_depth"
    assert lower_depth["compiler_recompute_required"]["requested_target_depth"] == "can_use"
    assert lower_depth["compiler_recompute_required"]["current_fit_facts"]["capacity_gap_minutes"] == 40
    assert lower_depth["compiler_recompute_required"]["removed_evidence_preview"] == []
    assert answer_question["status"] == "compiler_recompute_required"
    assert answer_question["compiler_recompute_required"]["reason"] == "answer_one_question"
    assert answer_question["compiler_recompute_required"]["question_id"] == "estimate_confidence"


def test_scheduler_crunch_versus_overload_option_recompute_semantics():
    scheduling = _scheduling_module()
    package = _compiler_package(
        start_date="2026-06-01",
        deadline="2026-06-01",
        daily_capacity_min=100,
        rest_weekdays=[],
        tasks=[
            {
                "id": "heavy",
                "phase_id": "phase-1",
                "title": "Heavy essential",
                "estimated_minutes": 90,
                "classification": "essential",
            }
        ],
    )

    crunch = scheduling.apply_schedule_option(
        package,
        "accept_crunch",
        selected_dates=["2026-06-01"],
    )
    overload = scheduling.apply_schedule_option(
        {
            **package,
            "existing_active_load": {"2026-06-01": 20},
        },
        "accept_overload",
        selected_dates=["2026-06-01"],
    )

    assert crunch["status"] == "draft_review"
    assert crunch["scheduled_days"][0]["planned_minutes"] == 90
    assert crunch["scheduled_days"][0]["load_state"] == "over_budget"
    assert crunch["risk_report"]["overloaded_dates"] == []
    assert overload["status"] == "draft_review"
    assert overload["scheduled_days"][0]["planned_minutes"] == 90
    assert overload["scheduled_days"][0]["load_state"] == "over_capacity"
    assert overload["risk_report"]["overloaded_dates"] == ["2026-06-01"]


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
