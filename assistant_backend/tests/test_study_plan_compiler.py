"""Plan compiler contract tests."""

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
            source_type="github_repo",
            source_roles={"github_repo": "clone_rebuild_target"},
            source_facts={
                "repo_name": "easyagent",
                "languages": ["Python"],
                "entry_points": ["main.py"],
            },
            target_output="rebuild easyagent and explain the call flow",
            target_depth="source_understanding",
            material_refs=[{"id": "repo", "kind": "github_repo"}],
        )
    )

    obligations = result["depth_obligations"]["essential_evidence"]
    assert [task["depth_obligation"] for task in result["tasks"]] == obligations
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
