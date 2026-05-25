"""Plan compiler contract tests."""

import json

import pytest

from src.study_plan.compiler import (
    CompilerResult,
    build_source_goal_synopsis,
    compile_plan,
    compile_structured_candidates,
    normalize_planning_envelope,
    validate_phase_candidates,
    validate_task_candidates,
)


def _envelope(**overrides):
    payload = {
        "draft_id": 42,
        "draft_version": 3,
        "intake_id": 9,
        "draft_kind": "new_plan",
        "target_plan_id": None,
        "confirmed_role": "new_plan",
        "attachment_mode": "material_only",
        "target_output": "working demo",
        "target_depth": "project_level_output",
        "deadline": "2026-07-15",
        "deadline_type": "fixed",
        "daily_capacity_min": 75,
        "rest_weekdays": [5, 6],
        "unavailable_dates": ["2026-07-04"],
        "buffer_policy": "leave_20_percent",
        "source_type": "github_repo",
        "source_url": "https://github.com/example/easyagent",
        "raw_input_summary": "Rebuild easyagent as a small demo.",
        "source_roles": {"github_repo": "clone_rebuild_target"},
        "source_facts": {"repo_name": "easyagent", "languages": ["Python"]},
        "material_refs": [{"id": "repo", "kind": "github_repo"}],
        "existing_plan_context": {"plan_id": 7, "title": "Agent Portfolio"},
        "user_estimate_overrides": {"setup": 45},
        "known_effort_facts": {"files": 12},
        "provenance": {"target_output": "user_provided", "source_roles": "parsed"},
        "missing_or_assumed_facts": [
            {"field": "buffer_policy", "assumption": "leave_20_percent"}
        ],
    }
    payload.update(overrides)
    return normalize_planning_envelope(payload)


def test_envelope_normalizes_core_identity_anchors_context_and_provenance():
    envelope = _envelope()

    assert envelope["schema_version"] == 1
    assert envelope["draft_id"] == 42
    assert envelope["draft_version"] == 3
    assert envelope["intake_id"] == 9
    assert envelope["draft_kind"] == "new_plan"
    assert envelope["target_plan_id"] is None
    assert envelope["confirmed_role"] == "new_plan"
    assert envelope["attachment_mode"] == "material_only"
    assert envelope["target_output"] == "working demo"
    assert envelope["target_depth"] == "project_level_output"
    assert envelope["deadline"] == "2026-07-15"
    assert envelope["deadline_type"] == "fixed"
    assert envelope["daily_capacity_min"] == 75
    assert envelope["rest_weekdays"] == [5, 6]
    assert envelope["unavailable_dates"] == ["2026-07-04"]
    assert envelope["buffer_policy"] == "leave_20_percent"
    assert envelope["source_context"] == {
        "source_type": "github_repo",
        "source_url": "https://github.com/example/easyagent",
        "raw_input_summary": "Rebuild easyagent as a small demo.",
        "source_roles": {"github_repo": "clone_rebuild_target"},
        "source_facts": {"repo_name": "easyagent", "languages": ["Python"]},
        "material_refs": [{"id": "repo", "kind": "github_repo"}],
    }
    assert envelope["existing_plan_context"] == {"plan_id": 7, "title": "Agent Portfolio"}
    assert envelope["user_estimate_overrides"] == {"setup": 45}
    assert envelope["known_effort_facts"] == {"files": 12}
    assert envelope["provenance"] == {
        "target_output": "user_provided",
        "source_roles": "parsed",
    }
    assert envelope["missing_or_assumed_facts"] == [
        {"field": "buffer_policy", "assumption": "leave_20_percent"}
    ]


def test_status_contract_allows_only_compiler_statuses_and_flag_low_calibration():
    result = CompilerResult(status="needs_input", questions=["What daily shape do you want?"])

    assert result.to_dict()["status"] == "needs_input"
    assert result.to_dict()["phases"] == []
    assert result.to_dict()["tasks"] == []
    assert result.to_dict()["low_calibration"] is False

    failed = CompilerResult(
        status="compile_failed",
        validation_errors=[{"field": "tasks", "message": "missing criteria"}],
        low_calibration=True,
    )
    assert failed.to_dict()["status"] == "compile_failed"
    assert failed.to_dict()["low_calibration"] is True

    with pytest.raises(ValueError, match="infeasible_review"):
        CompilerResult(status="infeasible_review")


@pytest.mark.parametrize(
    ("name", "overrides", "expected"),
    [
        (
            "course_archetype",
            {
                "source_type": "course",
                "target_output": "finish the SQL course and build notes",
                "raw_input_summary": "course modules",
                "source_roles": {"course": "main_learning_object"},
            },
            "finite_learning_project",
        ),
        (
            "practice_archetype",
            {
                "source_type": "problem_set",
                "target_output": "LeetCode Hot 100 practice cadence",
                "raw_input_summary": "repeat daily drills and redo misses",
            },
            "recurring_practice",
        ),
        (
            "review_archetype",
            {
                "source_type": "notes",
                "target_output": "backend interview topic review",
                "target_depth": "interview_ready",
                "raw_input_summary": "refresh concepts and mock explain",
            },
            "topic_review_cycle",
        ),
        (
            "rebuild_archetype",
            {
                "source_type": "github_repo",
                "target_output": "rebuild easyagent and modify one behavior",
                "source_roles": {"github_repo": "clone_rebuild_target"},
                "raw_input_summary": "https://github.com/example/easyagent",
            },
            "rebuild_or_clone",
        ),
        (
            "packaging_archetype",
            {
                "source_type": "text_goal",
                "target_output": "resume bullets and portfolio project story",
                "raw_input_summary": "package recent work for resume",
            },
            "project_packaging",
        ),
        (
            "existing_phase_archetype",
            {
                "draft_kind": "existing_plan_phase",
                "attachment_mode": "draft_phase",
                "target_plan_id": 77,
                "existing_plan_context": {"plan_id": 77, "title": "Current Plan"},
                "target_output": "add scheduled implementation phase",
            },
            "existing_project_phase",
        ),
    ],
)
def test_archetype_selection_matrix(name, overrides, expected):
    result = compile_plan(_envelope(**overrides))

    assert result["status"] == "draft_review", name
    assert result["scope_boundary"]["primary_archetype"] == expected


def test_tie_breaker_target_output_beats_source_type_for_resume_packaging():
    result = compile_plan(
        _envelope(
            source_type="course",
            target_output="turn this into resume bullets and a demo story",
            raw_input_summary="course about agents",
        )
    )

    assert result["scope_boundary"]["primary_archetype"] == "project_packaging"
    assert "target_output" in result["scope_boundary"]["selection_rationale"]


@pytest.mark.parametrize(
    "target_output",
    [
        "resume Python course",
        "build notebook examples",
        "read discourse plugin docs",
    ],
)
def test_archetype_keyword_matching_does_not_use_bare_substrings(target_output):
    result = compile_plan(
        _envelope(
            source_type="text_goal",
            source_url=None,
            source_roles={},
            target_output=target_output,
            raw_input_summary=target_output,
        )
    )

    assert result["status"] == "draft_review"
    assert result["scope_boundary"]["primary_archetype"] == "finite_learning_project"
    if target_output != "resume Python course":
        assert (
            "source type finite material signal"
            not in result["scope_boundary"]["selection_rationale"]
        )


@pytest.mark.parametrize(
    "target_output",
    [
        "resume bullets",
        "portfolio project story",
    ],
)
def test_archetype_keyword_matching_preserves_packaging_phrases(target_output):
    result = compile_plan(
        _envelope(
            source_type="text_goal",
            source_url=None,
            source_roles={},
            target_output=target_output,
            raw_input_summary=target_output,
        )
    )

    assert result["scope_boundary"]["primary_archetype"] == "project_packaging"


def test_tie_breaker_depth_beats_generic_learning_wording_for_interview_ready():
    result = compile_plan(
        _envelope(
            source_type="text_goal",
            target_output="learn agent memory",
            target_depth="interview_ready",
            raw_input_summary="generic learning wording",
        )
    )

    assert result["scope_boundary"]["primary_archetype"] == "topic_review_cycle"
    assert "target_depth" in result["scope_boundary"]["selection_rationale"]


def test_tie_breaker_confirmed_rebuild_repo_role_beats_interview_ready_depth():
    result = compile_plan(
        _envelope(
            source_type="github_repo",
            source_url="https://github.com/example/easyagent",
            source_roles={"github_repo": "clone_rebuild_target"},
            target_output="rebuild easyagent and prepare interview talking points",
            target_depth="interview_ready",
            raw_input_summary="easyagent repo for rebuild and interview prep",
        )
    )

    assert result["status"] == "draft_review"
    assert result["scope_boundary"]["primary_archetype"] == "rebuild_or_clone"
    assert "interview_notes" in result["scope_boundary"]["secondary_modifiers"]
    assert "recall sheet" in result["depth_obligations"]["essential_evidence"]
    assert "source_role" in result["scope_boundary"]["selection_rationale"]


def test_tie_breaker_confirmed_source_role_beats_github_url_shape():
    result = compile_plan(
        _envelope(
            source_type="url",
            source_url="https://github.com/example/easyagent",
            source_roles={"github_repo": "main_learning_object"},
            target_output="learn the guide and produce a working demo",
            raw_input_summary="github url",
        )
    )

    assert result["scope_boundary"]["primary_archetype"] == "finite_learning_project"
    assert "source_role" in result["scope_boundary"]["selection_rationale"]


def test_tie_breaker_existing_plan_draft_kind_beats_new_plan_archetypes():
    result = compile_plan(
        _envelope(
            draft_kind="existing_plan_scheduled_work",
            attachment_mode="scheduled_work",
            target_plan_id=7,
            existing_plan_context={"plan_id": 7, "title": "Agent Portfolio"},
            source_type="github_repo",
            target_output="rebuild clone demo",
            source_roles={"github_repo": "clone_rebuild_target"},
        )
    )

    assert result["scope_boundary"]["primary_archetype"] == "existing_project_phase"
    assert "existing_plan" in result["scope_boundary"]["selection_rationale"]


def test_tie_breaker_ambiguous_materially_different_daily_work_returns_one_question():
    result = compile_plan(
        _envelope(
            source_type="text_goal",
            target_output="practice LeetCode and package resume story",
            raw_input_summary="I need daily drills but also a portfolio narrative",
            source_roles={},
        )
    )

    assert result["status"] == "needs_input"
    assert len(result["questions"]) == 1
    assert "daily work" in result["questions"][0].lower()
    assert result["recovery_actions"] == ["choose_plan_archetype"]
    assert result["scope_boundary"]["primary_archetype"] is None


def test_missing_target_depth_returns_choose_depth_recovery():
    result = compile_plan(_envelope(target_depth=None))

    assert result["status"] == "needs_input"
    assert len(result["questions"]) == 1
    assert result["recovery_actions"] == ["choose_target_depth"]
    assert "missing target depth" in result["summary"].lower()
    assert result["trace"]["target_depth_state"] == "missing"


def test_archetype_scope_records_secondary_modifiers_material_boundary_and_assumption():
    result = compile_plan(
        _envelope(
            source_type="text_goal",
            source_url=None,
            source_roles={},
            target_output="build a demo and prepare interview notes",
            target_depth="interview_ready",
            material_refs=[
                {"id": "repo-readme", "included": True},
                {"id": "old-notes", "included": False},
            ],
            missing_or_assumed_facts=[
                {"field": "source_facts", "assumption": "README only"}
            ],
        )
    )

    boundary = result["scope_boundary"]
    assert boundary["primary_archetype"] == "topic_review_cycle"
    assert "interview_notes" in boundary["secondary_modifiers"]
    assert boundary["included_material_refs"] == ["repo-readme"]
    assert boundary["excluded_material_refs"] == ["old-notes"]
    assert boundary["selection_confidence"] == "medium"
    assert boundary["visible_assumption"] == "README only"


def test_depth_obligations_same_source_changes_completion_evidence():
    source = _envelope(source_type="github_repo", source_roles={"github_repo": "main_learning_object"})

    skim = compile_plan(dict(source, target_depth="skim_orientation"))
    usable = compile_plan(dict(source, target_depth="can_use_it"))
    project = compile_plan(dict(source, target_depth="project_level_output"))
    interview = compile_plan(dict(source, target_depth="interview_ready"))
    understanding = compile_plan(dict(source, target_depth="source_understanding"))

    assert "source map" in skim["depth_obligations"]["essential_evidence"]
    assert "working example" in usable["depth_obligations"]["essential_evidence"]
    assert "demo" in project["depth_obligations"]["essential_evidence"]
    assert "recall sheet" in interview["depth_obligations"]["essential_evidence"]
    assert "architecture map" in understanding["depth_obligations"]["essential_evidence"]
    assert len(
        {
            tuple(result["depth_obligations"]["task_families"])
            for result in [skim, usable, project, interview, understanding]
        }
    ) == 5


def test_unknown_target_depth_returns_needs_input_recovery_without_exception():
    result = compile_plan(_envelope(target_depth="mastery_forever"))

    assert result["status"] == "needs_input"
    assert result["phases"] == []
    assert result["tasks"] == []
    assert len(result["questions"]) == 1
    assert "target depth" in result["questions"][0].lower()
    assert result["recovery_actions"] == ["choose_supported_target_depth"]
    assert "unsupported target depth" in result["summary"].lower()
    assert result["trace"]["target_depth_state"] == "unsupported"
    assert result["trace"]["target_depth_value"] == "mastery_forever"


def test_synopsis_summarizes_thin_github_url_without_inventing_repo_structure():
    synopsis = build_source_goal_synopsis(
        _envelope(
            source_type="github_repo",
            source_url="https://github.com/example/thin-repo",
            source_roles={"github_repo": "clone_rebuild_target"},
            source_facts={"repo_name": "thin-repo"},
            material_refs=[{"id": "repo-url", "kind": "github_repo"}],
            known_effort_facts={},
            target_output="rebuild a minimal loop",
            target_depth="source_understanding",
        )
    )

    assert synopsis["goal_summary"] == "rebuild a minimal loop at source_understanding depth"
    assert "thin-repo" in synopsis["source_summary"]
    assert "repo_structure" in synopsis["unknowns"]
    assert synopsis["material_refs"] == ["repo-url"]
    assert synopsis["estimate_facts"] == {}
    assert "phase" not in synopsis["source_summary"].lower()
    assert synopsis["source_roles"] == {"github_repo": "clone_rebuild_target"}


def test_synopsis_uses_course_module_facts_without_mirroring_each_module_as_tasks():
    synopsis = build_source_goal_synopsis(
        _envelope(
            source_type="course",
            source_roles={"course": "main_learning_object"},
            source_facts={
                "course_title": "LangGraph Basics",
                "module_headings": ["Graphs", "Memory", "Tools", "Deployment"],
            },
            known_effort_facts={"modules": 4},
            target_output="build a working workflow note",
            target_depth="can_use_it",
        )
    )

    assert "LangGraph Basics" in synopsis["source_summary"]
    assert "4 module headings" in synopsis["source_summary"]
    assert synopsis["estimate_facts"] == {"modules": 4}
    assert "Graphs" not in synopsis["source_summary"]


def test_synopsis_summarizes_obsidian_snippets_and_existing_plan_context():
    synopsis = build_source_goal_synopsis(
        _envelope(
            draft_kind="existing_plan_phase",
            target_plan_id=7,
            attachment_mode="draft_phase",
            source_type="obsidian_note",
            source_roles={"note": "supporting_material"},
            source_facts={
                "note_title": "Agent memory notes",
                "snippet_count": 3,
                "snippet_summary": "cache invalidation and recall gaps",
            },
            material_refs=[{"id": "note-agent-memory", "kind": "obsidian_note"}],
            existing_plan_context={
                "plan_id": 7,
                "title": "Agent Portfolio",
                "current_phase": "demo hardening",
                "active_tasks": ["wire tool trace"],
            },
            known_effort_facts={"snippets": 3},
            target_output="add a review phase to the active plan",
            target_depth="interview_ready",
        )
    )

    assert "Agent memory notes" in synopsis["source_summary"]
    assert "Agent Portfolio" in synopsis["goal_summary"]
    assert "demo hardening" in synopsis["goal_summary"]
    assert synopsis["material_refs"] == ["note-agent-memory"]
    assert synopsis["estimate_facts"] == {"snippets": 3}


def test_validation_rejects_empty_phase_task_and_compile_outputs():
    phase_validation = validate_phase_candidates([])
    task_validation = validate_task_candidates(
        [],
        phases=[{"id": "phase-1"}],
        included_material_refs=["repo"],
        target_depth="source_understanding",
    )
    result = compile_structured_candidates(_envelope(), [], [])

    assert phase_validation["errors"] == [
        {"code": "no_executable_output", "severity": "blocking", "field": "phases"}
    ]
    assert task_validation["errors"] == [
        {"code": "no_executable_output", "severity": "blocking", "field": "tasks"}
    ]
    assert result["status"] == "compile_failed"
    assert "no_executable_output" in {
        error["code"] for error in result["validation_errors"]
    }


def test_validation_default_tasks_cover_all_depth_obligations_without_scheduled_dates():
    result = compile_plan(
        _envelope(
            source_type="documentation",
            source_roles={"documentation": "main_learning_object"},
            source_facts={
                "course_title": "Agent architecture notes",
                "module_headings": ["map", "trace", "modify", "explain"],
            },
            target_output="understand the selected source architecture",
            target_depth="source_understanding",
            source_url=None,
            raw_input_summary="selected source architecture notes",
            material_refs=[{"id": "source-docs", "kind": "documentation"}],
        )
    )

    obligations = result["depth_obligations"]["essential_evidence"]
    task_obligations = [task["depth_obligation"] for task in result["tasks"]]
    assert task_obligations == obligations
    assert len(task_obligations) == len(set(task_obligations))
    assert all("date" not in key for task in result["tasks"] for key in task)


def test_validation_project_packaging_default_tasks_follow_archetype_not_depth_pollution():
    result = compile_plan(
        _envelope(
            source_type="text_goal",
            source_url=None,
            source_roles={},
            target_output="resume bullets and portfolio project story",
            target_depth="project_level_output",
            raw_input_summary="package recent work for resume",
            material_refs=[{"id": "resume-note", "kind": "note"}],
        )
    )

    titles = [task["action_title"] for task in result["tasks"]]
    assert result["scope_boundary"]["primary_archetype"] == "project_packaging"
    assert titles == [
        "Inventory project evidence",
        "Draft impact-first bullet variants",
        "Draft project story",
        "Find rehearsal gaps",
        "Revise packaging artifact",
    ]
    assert "Build demo artifact" not in titles
    assert all("integration" not in task["concrete_output"].lower() for task in result["tasks"])
    assert all("demo" not in task["normal_mode"].lower() for task in result["tasks"])
    assert all("integration" not in task["fallback_mode"].lower() for task in result["tasks"])


def test_thin_source_compile_marks_low_calibration_instead_of_inventing_structure():
    result = compile_plan(
        _envelope(
            source_type="github_repo",
            source_url="https://github.com/example/easyagent",
            source_roles={"github_repo": "clone_rebuild_target"},
            source_facts={"repo_name": "easyagent"},
            target_output="rebuild easyagent and explain the call flow",
            target_depth="source_understanding",
        )
    )

    assert result["status"] == "draft_review"
    assert result["low_calibration"] is True
    assert "thin_source" in result["trace"]["low_calibration_reasons"]
    assert len(result["questions"]) <= 1
    assert all("easyagent/" not in task["action_title"] for task in result["tasks"])


def test_llm_contract_requires_phase_schema_and_ignores_forbidden_dates():
    phases = [
        {
            "id": "phase-1",
            "title": "Inspect baseline",
            "purpose": "Map the selected source before rebuilding.",
            "essential": True,
            "effort_range": {"min": 45, "max": 90},
            "completion_evidence": ["source map note"],
            "milestones": ["baseline runs"],
            "assumptions": [{"note": "No calendar placement", "calendar": "week 1"}],
            "suggested_date": "2026-06-01",
        }
    ]

    validation = validate_phase_candidates(phases)

    assert validation["accepted"][0]["id"] == "phase-1"
    assert "suggested_date" not in validation["accepted"][0]
    assert validation["accepted"][0]["assumptions"] == [{"note": "No calendar placement"}]
    assert validation["errors"] == []


def test_llm_contract_requires_task_schema_and_rejects_quality_failures():
    phases = [{"id": "phase-1"}]
    tasks = [
        {
            "id": "task-1",
            "phase_id": "phase-1",
            "order": 1,
            "work_type": "source_trace",
            "classification": "essential",
            "action_title": "Trace the minimal agent loop",
            "concrete_output": "8 bullet call-flow note",
            "completion_criteria": ["note names entry point and one handoff"],
            "estimated_minutes": 60,
            "estimate_confidence": "medium",
            "dependencies": [],
            "material_refs": ["repo"],
            "normal_mode": "read and trace",
            "fallback_mode": "trace README example only",
            "split_points": [{"label": "after trace", "date": "2026-06-03"}],
            "depth_obligation": "key path trace",
            "assumptions": [{"note": "scheduler decides later", "calendar": "week 1"}],
            "scheduled_date": "2026-06-02",
        },
        {
            "id": "task-2",
            "phase_id": "phase-1",
            "order": 2,
            "work_type": "study",
            "classification": "essential",
            "action_title": "learn LangGraph",
            "concrete_output": "",
            "completion_criteria": [],
            "estimated_minutes": 60,
            "estimate_confidence": "medium",
            "dependencies": ["missing-task"],
            "material_refs": ["outside"],
            "normal_mode": "study",
            "fallback_mode": "",
            "split_points": [],
            "depth_obligation": "demo",
            "assumptions": [],
        },
    ]

    validation = validate_task_candidates(
        tasks,
        phases=phases,
        included_material_refs=["repo"],
        target_depth="source_understanding",
    )

    assert "scheduled_date" not in validation["accepted"][0]
    assert validation["accepted"][0]["split_points"] == [{"label": "after trace"}]
    assert validation["accepted"][0]["assumptions"] == [{"note": "scheduler decides later"}]
    severities = {error["code"]: error["severity"] for error in validation["errors"]}
    assert severities["forbidden_date_field"] == "repairable"
    assert severities["vague_task"] == "blocking"
    assert severities["missing_completion_criteria"] == "blocking"
    assert severities["invalid_dependency"] == "blocking"
    assert severities["out_of_scope_material_ref"] == "blocking"
    assert severities["depth_obligation_contradiction"] == "warning"


def test_validation_rejects_duplicate_self_cyclic_and_order_inverted_dependencies():
    phases = [{"id": "phase-1"}]
    valid_fields = {
        "phase_id": "phase-1",
        "work_type": "source_trace",
        "classification": "essential",
        "concrete_output": "trace note",
        "completion_criteria": ["note has stopping condition"],
        "estimated_minutes": 45,
        "estimate_confidence": "medium",
        "material_refs": ["repo"],
        "normal_mode": "trace",
        "fallback_mode": "",
        "split_points": [],
        "depth_obligation": "key path trace",
        "assumptions": [],
    }
    tasks = [
        {"id": "task-1", "order": 1, "action_title": "Trace path A", "dependencies": ["task-2"], **valid_fields},
        {"id": "task-2", "order": 2, "action_title": "Trace path B", "dependencies": ["task-1"], **valid_fields},
        {"id": "task-2", "order": 3, "action_title": "Trace path C", "dependencies": [], **valid_fields},
        {"id": "task-4", "order": 4, "action_title": "Trace path D", "dependencies": ["task-4"], **valid_fields},
    ]

    validation = validate_task_candidates(
        tasks,
        phases=phases,
        included_material_refs=["repo"],
        target_depth="source_understanding",
    )

    codes = {error["code"] for error in validation["errors"]}
    assert "duplicate_task_id" in codes
    assert "self_dependency" in codes
    assert "cyclic_dependency" in codes
    assert "dependency_order_inversion" in codes


def test_validation_rejects_multinode_dependency_cycle_without_self_dependency():
    phases = [{"id": "phase-1"}]
    base = {
        "phase_id": "phase-1",
        "work_type": "source_trace",
        "classification": "essential",
        "concrete_output": "trace note",
        "completion_criteria": ["note has stopping condition"],
        "estimated_minutes": 45,
        "estimate_confidence": "medium",
        "material_refs": ["repo"],
        "normal_mode": "trace",
        "fallback_mode": "",
        "split_points": [],
        "depth_obligation": "key path trace",
        "assumptions": [],
    }
    tasks = [
        {"id": "task-1", "order": 1, "action_title": "Trace path A", "dependencies": ["task-3"], **base},
        {"id": "task-2", "order": 2, "action_title": "Trace path B", "dependencies": ["task-1"], **base},
        {"id": "task-3", "order": 3, "action_title": "Trace path C", "dependencies": ["task-2"], **base},
    ]

    validation = validate_task_candidates(
        tasks,
        phases=phases,
        included_material_refs=["repo"],
        target_depth="source_understanding",
    )

    codes = {error["code"] for error in validation["errors"]}
    assert "cyclic_dependency" in codes
    assert "self_dependency" not in codes


def test_validation_rejects_unknown_material_ref_even_when_scope_refs_empty():
    phases = [{"id": "phase-1"}]
    task = {
        "id": "task-1",
        "phase_id": "phase-1",
        "order": 1,
        "work_type": "source_trace",
        "classification": "essential",
        "action_title": "Trace selected source",
        "concrete_output": "trace note",
        "completion_criteria": ["note has stopping condition"],
        "estimated_minutes": 45,
        "estimate_confidence": "medium",
        "dependencies": [],
        "material_refs": ["unknown-ref"],
        "normal_mode": "trace",
        "fallback_mode": "",
        "split_points": [],
        "depth_obligation": "key path trace",
        "assumptions": [],
    }

    validation = validate_task_candidates(
        [task],
        phases=phases,
        included_material_refs=[],
        target_depth="source_understanding",
    )

    assert "out_of_scope_material_ref" in {
        error["code"] for error in validation["errors"]
    }


def test_validation_rejects_vague_prefixes_but_allows_concrete_output_tasks():
    phases = [{"id": "phase-1"}]
    base = {
        "phase_id": "phase-1",
        "work_type": "source_trace",
        "classification": "essential",
        "completion_criteria": ["artifact has a stopping condition"],
        "estimated_minutes": 45,
        "estimate_confidence": "medium",
        "dependencies": [],
        "material_refs": ["repo"],
        "normal_mode": "trace",
        "fallback_mode": "",
        "split_points": [],
        "depth_obligation": "key path trace",
        "assumptions": [],
    }
    tasks = [
        {
            "id": "task-1",
            "order": 1,
            "action_title": "learn LangGraph basics",
            "concrete_output": "notes",
            **base,
        },
        {
            "id": "task-2",
            "order": 2,
            "action_title": "study the repo",
            "concrete_output": "notes",
            **base,
        },
        {
            "id": "task-3",
            "order": 3,
            "action_title": "Write LangGraph setup note",
            "concrete_output": "setup note with runnable command and observed output",
            **base,
        },
    ]

    validation = validate_task_candidates(
        tasks,
        phases=phases,
        included_material_refs=["repo"],
        target_depth="source_understanding",
    )

    vague_indexes = {
        error["index"]
        for error in validation["errors"]
        if error["code"] == "vague_task"
    }
    assert vague_indexes == {0, 1}
    assert [task["id"] for task in validation["accepted"]] == ["task-3"]


def test_repair_preserves_user_anchors_scope_and_no_date_constraints():
    envelope = _envelope(
        target_depth="source_understanding",
        deadline_type="fixed",
        source_roles={"github_repo": "clone_rebuild_target"},
        material_refs=[{"id": "repo", "kind": "github_repo"}],
    )
    phases = [
        {
            "id": "phase-1",
            "title": "Trace baseline",
            "purpose": "Trace selected source.",
            "essential": True,
            "effort_range": {"min": 45, "max": 90},
            "completion_evidence": ["call-flow note"],
            "milestones": [],
            "assumptions": [],
        }
    ]
    invalid_tasks = [
        {
            "id": "task-1",
            "phase_id": "phase-1",
            "order": 1,
            "work_type": "study",
            "classification": "essential",
            "action_title": "study repo",
            "concrete_output": "",
            "completion_criteria": [],
            "estimated_minutes": 60,
            "estimate_confidence": "medium",
            "dependencies": [],
            "material_refs": ["repo"],
            "normal_mode": "study",
            "fallback_mode": "",
            "split_points": [],
            "depth_obligation": "key path trace",
            "assumptions": [],
        }
    ]

    def repair(_attempt, _errors, payload):
        assert "tasks" not in payload
        repaired = dict(payload["invalid_tasks"][0])
        repaired.update(
            {
                "work_type": "source_trace",
                "action_title": "Trace selected repo entry point",
                "concrete_output": "8 bullet source trace note",
                "completion_criteria": ["note includes entry point and one handoff"],
                "normal_mode": "trace the selected repo facts",
            }
        )
        return {"tasks": [repaired]}

    result = compile_structured_candidates(envelope, phases, invalid_tasks, repair_fn=repair)

    assert result["status"] == "draft_review"
    assert result["trace"]["repair_attempt_count"] == 1
    assert result["tasks"][0]["material_refs"] == ["repo"]
    assert result["trace"]["preserved_anchors"]["target_depth"] == "source_understanding"
    assert result["trace"]["preserved_anchors"]["deadline_type"] == "fixed"
    assert all("date" not in key for task in result["tasks"] for key in task)


def test_repair_payload_keeps_phase_and_task_invalid_indexes_separate():
    envelope = _envelope(
        target_depth="source_understanding",
        source_roles={"github_repo": "clone_rebuild_target"},
        material_refs=[{"id": "repo", "kind": "github_repo"}],
    )
    phases = [
        {
            "id": "phase-1",
            "title": "",
            "purpose": "Trace selected source.",
            "essential": True,
            "effort_range": {"min": 45, "max": 90},
            "completion_evidence": ["call-flow note"],
            "milestones": [],
            "assumptions": [],
        }
    ]
    tasks = [
        {
            "id": "task-1",
            "phase_id": "phase-1",
            "order": 1,
            "work_type": "source_trace",
            "classification": "essential",
            "action_title": "Trace selected source path",
            "concrete_output": "8 bullet trace note",
            "completion_criteria": ["note includes entry point and handoff"],
            "estimated_minutes": 60,
            "estimate_confidence": "medium",
            "dependencies": [],
            "material_refs": ["repo"],
            "normal_mode": "trace",
            "fallback_mode": "",
            "split_points": [],
            "depth_obligation": "key path trace",
            "assumptions": [],
        }
    ]

    def repair(_attempt, _errors, payload):
        assert payload["invalid_tasks"] == []
        assert payload["invalid_phases"][0]["repair_token"] == "phase:0"
        repaired_phase = dict(payload["invalid_phases"][0])
        repaired_phase["title"] = "Trace baseline"
        return {"phases": [repaired_phase]}

    result = compile_structured_candidates(envelope, phases, tasks, repair_fn=repair)

    assert result["status"] == "draft_review"
    assert result["phases"][0]["title"] == "Trace baseline"


def test_repair_can_fix_missing_task_id_with_repair_token_identity():
    envelope = _envelope(
        target_depth="source_understanding",
        source_roles={"github_repo": "clone_rebuild_target"},
        material_refs=[{"id": "repo", "kind": "github_repo"}],
    )
    phases = [
        {
            "id": "phase-1",
            "title": "Trace baseline",
            "purpose": "Trace selected source.",
            "essential": True,
            "effort_range": {"min": 45, "max": 90},
            "completion_evidence": ["call-flow note"],
            "milestones": [],
            "assumptions": [],
        }
    ]
    task = {
        "phase_id": "phase-1",
        "order": 1,
        "work_type": "source_trace",
        "classification": "essential",
        "action_title": "Trace selected source path",
        "concrete_output": "8 bullet trace note",
        "completion_criteria": ["note includes entry point and handoff"],
        "estimated_minutes": 60,
        "estimate_confidence": "medium",
        "dependencies": [],
        "material_refs": ["repo"],
        "normal_mode": "trace",
        "fallback_mode": "",
        "split_points": [],
        "depth_obligation": "key path trace",
        "assumptions": [],
    }

    def repair(_attempt, _errors, payload):
        repaired = dict(payload["invalid_tasks"][0])
        assert repaired["repair_token"] == "task:0"
        repaired["id"] = "task-1"
        return {"tasks": [repaired]}

    result = compile_structured_candidates(envelope, phases, [task], repair_fn=repair)

    assert result["status"] == "draft_review"
    assert result["tasks"][0]["id"] == "task-1"


def test_repair_malformed_token_returns_compile_failed_instead_of_crashing():
    envelope = _envelope(
        target_depth="source_understanding",
        source_roles={"github_repo": "clone_rebuild_target"},
        material_refs=[{"id": "repo", "kind": "github_repo"}],
    )
    phases = [
        {
            "id": "phase-1",
            "title": "Trace baseline",
            "purpose": "Trace selected source.",
            "essential": True,
            "effort_range": {"min": 45, "max": 90},
            "completion_evidence": ["call-flow note"],
            "milestones": [],
            "assumptions": [],
        }
    ]
    invalid_task = {
        "id": "task-1",
        "phase_id": "phase-1",
        "order": 1,
        "work_type": "study",
        "classification": "essential",
        "action_title": "study repo",
        "concrete_output": "",
        "completion_criteria": [],
        "estimated_minutes": 60,
        "estimate_confidence": "medium",
        "dependencies": [],
        "material_refs": ["repo"],
        "normal_mode": "study",
        "fallback_mode": "",
        "split_points": [],
        "depth_obligation": "key path trace",
        "assumptions": [],
    }

    def repair(_attempt, _errors, payload):
        repaired = dict(payload["invalid_tasks"][0])
        repaired.update(
            {
                "repair_token": "task:abc",
                "work_type": "source_trace",
                "action_title": "Trace selected source path",
                "concrete_output": "8 bullet trace note",
                "completion_criteria": ["note includes entry point"],
            }
        )
        return {"tasks": [repaired]}

    result = compile_structured_candidates(envelope, phases, [invalid_task], repair_fn=repair)

    assert result["status"] == "compile_failed"
    assert "invalid_repair_token" in {
        error["code"] for error in result["validation_errors"]
    }


def test_repair_duplicate_task_ids_can_be_fixed_by_distinct_repair_tokens():
    envelope = _envelope(
        target_depth="source_understanding",
        source_roles={"github_repo": "clone_rebuild_target"},
        material_refs=[{"id": "repo", "kind": "github_repo"}],
    )
    phases = [
        {
            "id": "phase-1",
            "title": "Trace baseline",
            "purpose": "Trace selected source.",
            "essential": True,
            "effort_range": {"min": 45, "max": 90},
            "completion_evidence": ["call-flow note"],
            "milestones": [],
            "assumptions": [],
        }
    ]
    base = {
        "id": "dup",
        "phase_id": "phase-1",
        "work_type": "source_trace",
        "classification": "essential",
        "concrete_output": "trace note",
        "completion_criteria": ["note includes stopping condition"],
        "estimated_minutes": 60,
        "estimate_confidence": "medium",
        "dependencies": [],
        "material_refs": ["repo"],
        "normal_mode": "trace",
        "fallback_mode": "",
        "split_points": [],
        "depth_obligation": "key path trace",
        "assumptions": [],
    }
    tasks = [
        {**base, "order": 1, "action_title": "Trace source path A"},
        {**base, "order": 2, "action_title": "Trace source path B"},
    ]

    def repair(_attempt, _errors, payload):
        first = dict(payload["invalid_tasks"][0])
        second = dict(payload["invalid_tasks"][1])
        assert first["repair_token"] == "task:0"
        assert second["repair_token"] == "task:1"
        first["id"] = "task-1"
        second["id"] = "task-2"
        return {"tasks": [first, second]}

    result = compile_structured_candidates(envelope, phases, tasks, repair_fn=repair)

    assert result["status"] == "draft_review"
    assert [task["id"] for task in result["tasks"]] == ["task-1", "task-2"]


def test_repair_rejects_anchor_changes_scope_expansion_and_stops_after_two_attempts():
    envelope = _envelope(
        target_depth="source_understanding",
        source_roles={"github_repo": "clone_rebuild_target"},
        material_refs=[{"id": "repo", "kind": "github_repo"}],
    )
    phases = [
        {
            "id": "phase-1",
            "title": "Trace baseline",
            "purpose": "Trace selected source.",
            "essential": True,
            "effort_range": {"min": 45, "max": 90},
            "completion_evidence": ["call-flow note"],
            "milestones": [],
            "assumptions": [],
        }
    ]
    invalid_tasks = [
        {
            "id": "task-1",
            "phase_id": "phase-1",
            "order": 1,
            "work_type": "study",
            "classification": "essential",
            "action_title": "work on resume",
            "concrete_output": "",
            "completion_criteria": [],
            "estimated_minutes": 0,
            "estimate_confidence": "low",
            "dependencies": [],
            "material_refs": ["repo"],
            "normal_mode": "study",
            "fallback_mode": "",
            "split_points": [],
            "depth_obligation": "key path trace",
            "assumptions": [],
        }
    ]
    attempts = []

    def bad_repair(attempt, errors, payload):
        attempts.append(attempt)
        if attempt == 2:
            assert "repair_changed_anchor" in {error["code"] for error in errors}
            assert "repair_expanded_scope" in {error["code"] for error in payload["errors"]}
        widened = dict(payload["invalid_tasks"][0])
        widened.update(
            {
                "action_title": "Trace repo and extra blog",
                "completion_criteria": ["done"],
                "concrete_output": "note",
                "material_refs": ["repo", "extra-blog"],
                "scheduled_date": "2026-06-02",
            }
        )
        return {
            "target_depth": "project_level_output",
            "tasks": [widened],
        }

    result = compile_structured_candidates(envelope, phases, invalid_tasks, repair_fn=bad_repair)

    assert result["status"] == "compile_failed"
    assert attempts == [1, 2]
    assert result["trace"]["repair_attempt_count"] == 2
    codes = {error["code"] for error in result["validation_errors"]}
    assert "repair_changed_anchor" in codes
    assert "repair_expanded_scope" in codes
    assert "forbidden_date_field" in codes
    assert result["recovery_actions"] == ["revise_task_candidates", "ask_for_more_source_facts"]


def test_repair_rejects_nested_date_calendar_fields_before_validation_strip():
    envelope = _envelope(
        target_depth="source_understanding",
        source_roles={"github_repo": "clone_rebuild_target"},
        material_refs=[{"id": "repo", "kind": "github_repo"}],
    )
    phases = [
        {
            "id": "phase-1",
            "title": "Trace baseline",
            "purpose": "Trace selected source.",
            "essential": True,
            "effort_range": {"min": 45, "max": 90},
            "completion_evidence": ["call-flow note"],
            "milestones": [],
            "assumptions": [],
        }
    ]
    invalid_task = {
        "id": "task-1",
        "phase_id": "phase-1",
        "order": 1,
        "work_type": "study",
        "classification": "essential",
        "action_title": "study repo",
        "concrete_output": "",
        "completion_criteria": [],
        "estimated_minutes": 60,
        "estimate_confidence": "medium",
        "dependencies": [],
        "material_refs": ["repo"],
        "normal_mode": "study",
        "fallback_mode": "",
        "split_points": [],
        "depth_obligation": "key path trace",
        "assumptions": [],
    }

    def repair(_attempt, _errors, payload):
        repaired = dict(payload["invalid_tasks"][0])
        repaired.update(
            {
                "work_type": "source_trace",
                "action_title": "Trace selected source path",
                "concrete_output": "8 bullet trace note",
                "completion_criteria": ["note includes entry point"],
                "split_points": [{"label": "stop", "date": "2026-06-03"}],
                "assumptions": [{"calendar": "week 1"}],
            }
        )
        return {"tasks": [repaired]}

    result = compile_structured_candidates(envelope, phases, [invalid_task], repair_fn=repair)

    assert result["status"] == "compile_failed"
    assert "forbidden_date_field" in {
        error["code"] for error in result["validation_errors"]
    }


def test_repair_anchor_errors_are_recomputed_per_attempt():
    envelope = _envelope(
        target_depth="source_understanding",
        deadline_type="fixed",
        source_roles={"github_repo": "clone_rebuild_target"},
        material_refs=[{"id": "repo", "kind": "github_repo"}],
    )
    phases = [
        {
            "id": "phase-1",
            "title": "Trace baseline",
            "purpose": "Trace selected source.",
            "essential": True,
            "effort_range": {"min": 45, "max": 90},
            "completion_evidence": ["call-flow note"],
            "milestones": [],
            "assumptions": [],
        }
    ]
    invalid_task = {
        "id": "task-1",
        "phase_id": "phase-1",
        "order": 1,
        "work_type": "study",
        "classification": "essential",
        "action_title": "study repo",
        "concrete_output": "",
        "completion_criteria": [],
        "estimated_minutes": 60,
        "estimate_confidence": "medium",
        "dependencies": [],
        "material_refs": ["repo"],
        "normal_mode": "study",
        "fallback_mode": "",
        "split_points": [],
        "depth_obligation": "key path trace",
        "assumptions": [],
    }

    def repair(attempt, _errors, payload):
        repaired = dict(payload["invalid_tasks"][0])
        repaired.update(
            {
                "work_type": "source_trace",
                "action_title": "Trace selected repo entry point",
                "concrete_output": "8 bullet source trace note",
                "completion_criteria": ["note includes entry point and one handoff"],
                "normal_mode": "trace selected facts",
            }
        )
        if attempt == 1:
            return {"target_depth": "project_level_output", "tasks": [repaired]}
        return {"tasks": [repaired]}

    result = compile_structured_candidates(envelope, phases, [invalid_task], repair_fn=repair)

    assert result["status"] == "draft_review"
    assert result["trace"]["repair_attempt_count"] == 2
    assert "repair_changed_anchor" not in {
        error["code"] for error in result["validation_errors"]
    }


def test_repair_payload_cannot_modify_unfailed_tasks():
    envelope = _envelope(
        target_depth="source_understanding",
        source_roles={"github_repo": "clone_rebuild_target"},
        material_refs=[{"id": "repo", "kind": "github_repo"}],
    )
    phases = [
        {
            "id": "phase-1",
            "title": "Trace baseline",
            "purpose": "Trace selected source.",
            "essential": True,
            "effort_range": {"min": 45, "max": 90},
            "completion_evidence": ["call-flow note"],
            "milestones": [],
            "assumptions": [],
        }
    ]
    valid_task = {
        "id": "task-1",
        "phase_id": "phase-1",
        "order": 1,
        "work_type": "source_trace",
        "classification": "essential",
        "action_title": "Trace selected source path",
        "concrete_output": "8 bullet trace note",
        "completion_criteria": ["note includes entry point and handoff"],
        "estimated_minutes": 60,
        "estimate_confidence": "medium",
        "dependencies": [],
        "material_refs": ["repo"],
        "normal_mode": "trace",
        "fallback_mode": "",
        "split_points": [],
        "depth_obligation": "key path trace",
        "assumptions": [],
    }
    invalid_task = {
        **valid_task,
        "id": "task-2",
        "order": 2,
        "dependencies": ["task-1"],
        "action_title": "study repo",
        "concrete_output": "",
        "completion_criteria": [],
        "depth_obligation": "architecture map",
    }

    def repair(_attempt, _errors, payload):
        assert [task["id"] for task in payload["invalid_tasks"]] == ["task-2"]
        repaired = dict(payload["invalid_tasks"][0])
        repaired.update(
            {
                "action_title": "Create architecture map",
                "concrete_output": "architecture map note",
                "completion_criteria": ["note names two components"],
            }
        )
        changed_valid = dict(valid_task, action_title="Tampered valid task")
        return {"tasks": [changed_valid, repaired]}

    result = compile_structured_candidates(
        envelope, phases, [valid_task, invalid_task], repair_fn=repair
    )

    assert result["status"] == "compile_failed"
    assert "repair_modified_unfailed_task" in {
        error["code"] for error in result["validation_errors"]
    }


def _valid_phase():
    return {
        "id": "phase-1",
        "title": "Estimate phase",
        "purpose": "Normalize task estimates.",
        "essential": True,
        "effort_range": {"min": 45, "max": 120},
        "completion_evidence": ["normalized estimates"],
        "milestones": ["estimates checked"],
        "assumptions": [],
    }


def _estimated_task(task_id, work_type, minutes, *, order=1, split_points=None):
    return {
        "id": task_id,
        "phase_id": "phase-1",
        "order": order,
        "work_type": work_type,
        "classification": "essential",
        "action_title": f"Produce {task_id} artifact",
        "concrete_output": f"{task_id} artifact",
        "completion_criteria": [f"{task_id} artifact exists"],
        "estimated_minutes": minutes,
        "estimate_confidence": "low",
        "dependencies": [],
        "material_refs": ["repo"],
        "normal_mode": "produce the artifact",
        "fallback_mode": "write a smaller artifact",
        "split_points": split_points or [],
        "depth_obligation": "demo",
        "assumptions": [],
    }


def test_estimate_normalization_prioritizes_user_source_history_defaults_and_llm_outliers():
    envelope = _envelope(
        material_refs=[{"id": "repo", "kind": "github_repo"}],
        user_estimate_overrides={"task-user": 35, "setup": 40},
        known_effort_facts={
            "task_estimates": {"task-source": 75},
            "user_speed_factor": 0.5,
        },
        source_facts={"repo_name": "easyagent", "languages": ["Python"], "files": 8},
    )
    tasks = [
        _estimated_task("task-user", "setup", 170, order=1),
        _estimated_task("task-source", "source_trace", 400, order=2),
        _estimated_task("task-history", "build", 100, order=3),
        _estimated_task("task-default", "practice", None, order=4),
        _estimated_task("task-llm", "custom_research", 95, order=5),
    ]

    result = compile_structured_candidates(envelope, [_valid_phase()], tasks)

    assert result["status"] == "draft_review"
    assert [
        (task["id"], task["estimated_minutes"], task["estimate_source"], task["estimate_confidence"])
        for task in result["tasks"]
    ] == [
        ("task-user", 35, "user_override", "high"),
        ("task-source", 75, "source_fact", "high"),
        ("task-history", 50, "user_history", "medium"),
        ("task-default", 60, "default", "medium"),
        ("task-llm", 48, "user_history", "medium"),
    ]
    decisions = {
        decision["task_id"]: decision for decision in result["trace"]["estimate_decisions"]
    }
    assert decisions["task-source"]["raw_minutes"] == 400
    assert "llm_outlier_replaced" in decisions["task-source"]["reasons"]
    assert decisions["task-default"]["default_range"] == [45, 75]

    llm_only = compile_structured_candidates(
        _envelope(
            material_refs=[{"id": "repo", "kind": "github_repo"}],
            user_estimate_overrides={},
            known_effort_facts={},
            source_facts={"repo_name": "easyagent", "languages": ["Python"], "files": 8},
        ),
        [_valid_phase()],
        [_estimated_task("task-llm-only", "custom_research", 95)],
    )
    assert llm_only["tasks"][0]["estimate_source"] == "llm_suggestion"
    assert llm_only["tasks"][0]["estimated_minutes"] == 95


def test_estimate_validation_raises_tiny_estimates_and_blocks_oversized_tasks_without_split_points():
    envelope = _envelope(material_refs=[{"id": "repo", "kind": "github_repo"}])
    tiny = _estimated_task("task-tiny", "custom_research", 5, order=1)
    oversized = _estimated_task("task-big", "custom_research", 150, order=2)
    split = _estimated_task(
        "task-split",
        "custom_research",
        150,
        order=3,
        split_points=[{"label": "after baseline"}],
    )

    result = compile_structured_candidates(envelope, [_valid_phase()], [tiny, oversized, split])

    assert result["status"] == "compile_failed"
    assert "oversized_task_missing_split" in {
        error["code"] for error in result["validation_errors"]
    }
    decisions = {
        decision["task_id"]: decision for decision in result["trace"]["estimate_decisions"]
    }
    assert decisions["task-tiny"]["normalized_minutes"] == 45
    assert decisions["task-tiny"]["selected_source"] == "default"
    assert "llm_outlier_replaced" in decisions["task-tiny"]["reasons"]
    assert decisions["task-split"]["normalized_minutes"] == 150
    assert "oversized_with_split" in decisions["task-split"]["reasons"]


def test_estimate_normalization_ignores_bool_estimates_and_uses_plain_source_duration():
    result = compile_structured_candidates(
        _envelope(
            material_refs=[{"id": "repo", "kind": "github_repo"}],
            user_estimate_overrides={"task-user-bool": True},
            source_facts={
                "repo_name": "easyagent",
                "languages": ["Python"],
                "duration_minutes": 80,
                "task_estimates": {"task-source-bool": False},
            },
            known_effort_facts={},
        ),
        [_valid_phase()],
        [
            _estimated_task("task-raw-bool", "setup", True, order=1),
            _estimated_task("task-user-bool", "source_trace", 50, order=2),
            _estimated_task("task-source-bool", "source_trace", 55, order=3),
            _estimated_task("task-plain-duration", "custom_research", None, order=4),
        ],
    )

    assert result["status"] == "draft_review"
    decisions = {
        decision["task_id"]: decision for decision in result["trace"]["estimate_decisions"]
    }
    assert decisions["task-raw-bool"]["selected_source"] == "default"
    assert decisions["task-raw-bool"]["normalized_minutes"] == 68
    assert "invalid_bool_estimate_ignored" in decisions["task-raw-bool"]["reasons"]
    assert decisions["task-user-bool"]["selected_source"] == "default"
    assert decisions["task-source-bool"]["selected_source"] == "default"
    assert decisions["task-plain-duration"]["selected_source"] == "source_fact"
    assert decisions["task-plain-duration"]["normalized_minutes"] == 80


def test_low_calibration_thresholds_include_low_minutes_default_only_thin_source_and_conflicts():
    low_minutes_result = compile_structured_candidates(
        _envelope(material_refs=[{"id": "repo", "kind": "github_repo"}], source_facts={}),
        [_valid_phase()],
        [
            _estimated_task("task-low", "custom_research", 95, order=1),
            _estimated_task("task-high", "setup", None, order=2),
        ],
    )
    assert low_minutes_result["low_calibration"] is True
    assert "low_confidence_essential_minutes" in low_minutes_result["trace"]["low_calibration_reasons"]

    default_only_result = compile_structured_candidates(
        _envelope(
            material_refs=[{"id": "repo", "kind": "github_repo"}],
            source_facts={},
            user_estimate_overrides={},
        ),
        [_valid_phase()],
        [
            _estimated_task("task-1", "orientation", None, order=1),
            _estimated_task("task-2", "setup", None, order=2),
            _estimated_task("task-3", "practice", None, order=3),
        ],
    )
    assert "essential_default_only_count" in default_only_result["trace"]["low_calibration_reasons"]

    compile_result = compile_plan(
        _envelope(
            source_type="github_repo",
            source_roles={"github_repo": "clone_rebuild_target"},
            source_facts={"repo_name": "easyagent"},
            target_output="rebuild easyagent",
            target_depth="source_understanding",
            missing_or_assumed_facts=[
                {"field": "deadline_conflict", "assumption": "Use rough scope only"}
            ],
        )
    )
    assert compile_result["low_calibration"] is True
    assert "thin_source" in compile_result["trace"]["low_calibration_reasons"]
    assert "conflicting_anchor_assumption" in compile_result["trace"]["low_calibration_reasons"]

    non_conflicting = compile_plan(
        _envelope(
            source_type="github_repo",
            source_roles={"github_repo": "clone_rebuild_target"},
            source_facts={"repo_name": "easyagent", "languages": ["Python"]},
            target_output="rebuild easyagent",
            target_depth="source_understanding",
            missing_or_assumed_facts=[
                {"field": "note_anchor", "assumption": "Anchor examples to README wording"}
            ],
        )
    )
    assert "conflicting_anchor_assumption" not in non_conflicting["trace"]["low_calibration_reasons"]


def test_needs_input_trace_redacts_sensitive_provenance_and_goal_text():
    secret_goal = "resume bullets for SECRET_PROJECT_ALPHA"
    result = compile_plan(
        _envelope(
            target_depth=None,
            target_output=secret_goal,
            provenance={
                "prompt_log": "SECRET_PROMPT_FOR_NEEDS_INPUT",
                "validation_error": "SECRET_VALIDATION_ERROR",
            },
        )
    )

    trace_blob = json.dumps(result["trace"], ensure_ascii=False)
    assert result["status"] == "needs_input"
    assert "SECRET_PROMPT_FOR_NEEDS_INPUT" not in trace_blob
    assert "SECRET_VALIDATION_ERROR" not in trace_blob
    assert "SECRET_PROJECT_ALPHA" not in trace_blob


def test_trace_records_scope_validation_task_gates_estimates_and_redacts_sensitive_content():
    secret_resume = "SECRET_RESUME_TEXT_SHOULD_NOT_LEAK"
    secret_repo = "SECRET_PRIVATE_REPO_DESCRIPTION_SHOULD_NOT_LEAK"
    secret_note = "SECRET_OBSIDIAN_SNIPPET_SHOULD_NOT_LEAK"
    secret_prompt = "SECRET_PROMPT_LOG_SHOULD_NOT_LEAK"
    result = compile_plan(
        _envelope(
            source_type="obsidian_note",
            source_url=None,
            source_roles={"note": "supporting_material"},
            source_facts={
                "note_title": "Private prep notes",
                "resume_text": secret_resume,
                "description": secret_repo,
                "snippet_summary": secret_note,
            },
            raw_input_summary="private interview prep",
            target_output="resume bullets and project story for SECRET_PROJECT_BETA",
            target_depth="project_level_output",
            provenance={
                "target_output": "user_provided",
                "prompt_log": secret_prompt,
                "validation_error": "raw error with " + secret_note,
            },
            material_refs=[
                {"id": "selected-note", "kind": "obsidian_note", "included": True},
                {"id": "unselected-note", "kind": "obsidian_note", "included": False},
            ],
        )
    )

    trace = result["trace"]
    assert trace["selected_archetype"] == "project_packaging"
    assert "resume_articulation" in trace["selected_modifiers"]
    assert trace["source_scope_boundary"]["included_material_refs"] == ["selected-note"]
    assert trace["source_scope_boundary"]["excluded_material_refs"] == ["unselected-note"]
    assert trace["source_scope_boundary"]["external_context_used"] is False
    assert trace["validation"]["status"] == "passed"
    assert trace["task_quality_gates"]["accepted_task_ids"]
    assert trace["estimate_decisions"]
    assert trace["calibration"]["low_calibration"] == result["low_calibration"]
    trace_blob = json.dumps(trace, ensure_ascii=False)
    for secret in [
        secret_resume,
        secret_repo,
        secret_note,
        secret_prompt,
        "SECRET_PROJECT_BETA",
    ]:
        assert secret not in trace_blob


def test_real_context_fixtures_compile_expected_unscheduled_task_shapes():
    fixtures = [
        (
            _envelope(
                source_type="documentation",
                source_url="https://example.com/AgentGuide",
                source_roles={"documentation": "main_learning_object"},
                source_facts={"course_title": "AgentGuide", "module_headings": ["tools", "memory"]},
                target_output="AgentGuide working tool-calling demo and interview notes",
                target_depth="interview_ready",
                material_refs=[{"id": "agentguide", "kind": "docs"}],
            ),
            "finite_learning_project",
            {
                "tasks": [
                    "Map AgentGuide orientation",
                    "Run AgentGuide example",
                    "Build small tool-calling demo",
                    "Draft 6-bullet agent-loop explanation",
                ],
                "phases": [
                    ("AgentGuide orientation", "source map", "setup notes"),
                    ("Guided reproduction", "run the guide example", "runnable guide example"),
                    ("Small tool-calling demo", "build a small demo", "tool-calling demo"),
                    ("Interview notes review", "explain the agent loop", "6-bullet"),
                ],
            },
        ),
        (
            _envelope(
                source_type="github_repo",
                source_url="https://github.com/example/easyagent",
                source_roles={"github_repo": "clone_rebuild_target"},
                source_facts={"repo_name": "easyagent", "languages": ["Python"]},
                target_output="easyagent rebuild with source-understanding notes",
                target_depth="source_understanding",
                material_refs=[{"id": "easyagent-repo", "kind": "github_repo"}],
            ),
            "rebuild_or_clone",
            {
                "tasks": [
                    "Create source map",
                    "Capture quickstart baseline notes",
                    "Trace call flow",
                    "Build runnable minimal loop",
                    "Modify one behavior",
                    "Explain architecture tradeoffs",
                ],
                "phases": [
                    ("Inspect and run baseline", "inspect the selected source", "baseline notes"),
                    ("Trace minimal loop", "trace the minimal loop", "call-flow trace"),
                    ("Rebuild minimal loop", "rebuild the minimal loop", "runnable minimal loop"),
                    ("Add one modification", "add one modification", "modification evidence"),
                    ("Prepare explanation", "prepare the architecture explanation", "tradeoff explanation"),
                ],
            },
        ),
        (
            _envelope(
                source_type="problem_set",
                source_url=None,
                source_roles={},
                source_facts={"problem_set": "LeetCode Hot 100"},
                target_output="LeetCode Hot 100 and 灵茶山 recurring practice",
                target_depth="interview_ready",
                material_refs=[{"id": "leetcode-hot-100", "kind": "problem_set"}],
            ),
            "recurring_practice",
            {
                "tasks": [
                    "Run diagnostic practice set",
                    "Complete focused practice block",
                    "Tag mistakes and patterns",
                    "Create spaced redo checkpoint",
                    "Run checkpoint mock set",
                    "Draft recall sheet",
                ],
                "phases": [
                    ("Diagnostic", "find starting level", "diagnostic"),
                    ("Daily practice cadence", "solve focused blocks", "practice cadence"),
                    ("Mistake tagging", "tag mistakes", "mistake tags"),
                    ("Spaced redo", "redo missed problems", "redo checkpoint"),
                    ("Checkpoint mock set", "run mock sets", "mock set"),
                ],
            },
        ),
        (
            _envelope(
                source_type="notes",
                source_url=None,
                source_roles={"notes": "main_learning_object"},
                source_facts={"note_title": "agent/backend interview prep", "snippet_count": 4},
                target_output="agent and backend interview prep",
                target_depth="interview_ready",
                material_refs=[{"id": "interview-notes", "kind": "notes"}],
            ),
            "topic_review_cycle",
            {
                "tasks": [
                    "Draft answer batch",
                    "Attach project-linked examples",
                    "Run mock explanation",
                    "Write gap notes",
                    "Schedule spaced review prompts",
                ],
                "phases": [
                    ("Topic inventory", "turn topics into answer prompts", "topic inventory"),
                    ("Active recall notes", "write active recall notes", "active recall notes"),
                    ("Project-linked examples", "connect answers to project evidence", "project-linked examples"),
                    ("Mock explanation", "explain aloud and capture gaps", "mock explanation"),
                    ("Spaced review", "review gaps later", "spaced review"),
                ],
            },
        ),
        (
            _envelope(
                source_type="text_goal",
                source_url=None,
                source_roles={},
                source_facts={"project_name": "assistant backend"},
                target_output="resume bullets and project packaging",
                target_depth="project_level_output",
                material_refs=[{"id": "resume-project", "kind": "project_note"}],
            ),
            "project_packaging",
            {
                "tasks": [
                    "Inventory project evidence",
                    "Draft impact-first bullet variants",
                    "Draft project story",
                    "Find rehearsal gaps",
                    "Revise packaging artifact",
                ],
                "phases": [
                    ("Evidence inventory", "collect proof points", "evidence inventory"),
                    ("Bullet rewrite", "rewrite resume bullets", "bullet variants"),
                    ("Project story", "draft project story", "project story"),
                    ("Rehearsal", "rehearse and find gaps", "gap notes"),
                    ("Revision", "revise packaging", "revised artifact"),
                ],
            },
        ),
    ]

    for envelope, archetype, expected in fixtures:
        result = compile_plan(envelope)

        assert result["status"] == "draft_review"
        assert result["scope_boundary"]["primary_archetype"] == archetype
        assert [task["action_title"] for task in result["tasks"]] == expected["tasks"]
        assert [phase["title"] for phase in result["phases"]] == [
            title for title, _purpose, _evidence in expected["phases"]
        ]
        for phase, (_title, purpose_text, evidence_text) in zip(
            result["phases"], expected["phases"]
        ):
            assert purpose_text in phase["purpose"].lower()
            assert any(
                evidence_text in str(evidence).lower()
                for evidence in phase["completion_evidence"]
            )
        _assert_no_scheduler_owned_output(result)


def _assert_no_scheduler_owned_output(result):
    forbidden_keys = {
        "scheduled_date",
        "final_dates",
        "capacity_gap_minutes",
        "capacity_gap",
        "buffer_erosion",
        "overloaded_dates",
        "overloaded_date",
    }
    forbidden_values = {"infeasible_review"}

    def walk(value):
        if isinstance(value, dict):
            for key, nested in value.items():
                assert key not in forbidden_keys
                walk(nested)
        elif isinstance(value, list):
            for nested in value:
                walk(nested)
        else:
            assert value not in forbidden_values

    walk(result)
