"""Plan compiler contract tests."""

import pytest

from src.study_plan.compiler import (
    CompilerResult,
    compile_plan,
    normalize_planning_envelope,
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
