"""Study plan guided clarification tests."""

import importlib

import pytest


def _clarification_module():
    try:
        return importlib.import_module("src.study_plan.clarification")
    except ModuleNotFoundError as exc:
        pytest.fail(f"Expected study plan clarification module to exist: {exc}")


def test_guided_clarification_has_at_most_three_ordered_questions_and_skip_action():
    clarification = _clarification_module().build_guided_clarification(
        {
            "title": "SQLite Query Planner Overview",
            "material_type": "documentation",
            "summary": "A structured reference about how SQLite plans queries.",
            "structure": ["Overview", "Indexes", "EXPLAIN QUERY PLAN"],
            "suggested_focus": "Indexes and EXPLAIN output",
        }
    )

    questions = clarification["questions"]
    assert len(questions) <= 3
    assert [question["id"] for question in questions] == [
        "level_familiarity",
        "goal_depth",
        "focus_scope",
    ]
    assert set(clarification["defaults"]) == {
        "level_familiarity",
        "goal_depth",
        "focus_scope",
    }
    assert clarification["skip_action"] == {
        "id": "generate_rough_draft",
        "label": "Generate rough draft",
        "uses_defaults": True,
    }


def test_each_question_offers_recommended_default_and_unsure_default_paths():
    clarification = _clarification_module().build_guided_clarification(
        {
            "title": "Queueing Theory Notes",
            "material_type": "article",
            "summary": "An article introducing Little's Law and common queue models.",
        }
    )

    for question in clarification["questions"]:
        default_value = clarification["defaults"][question["id"]]
        options = question["options"]

        assert any(
            option["id"] == "recommended"
            and option["value"] == default_value
            and option.get("recommended") is True
            and option.get("default") is True
            for option in options
        )
        assert any(
            option["id"] == "unsure_recommended"
            and option["value"] == default_value
            and option.get("uses_default") is True
            for option in options
        )


def test_material_type_shapes_final_question_for_scope_or_target_output():
    clarification = _clarification_module()

    structure_oriented = clarification.build_guided_clarification(
        {
            "title": "Operating Systems Course",
            "material_type": "structured_course",
            "structure": ["Processes", "Memory", "File systems"],
            "suggested_focus": "Processes and memory",
        }
    )
    structure_final = structure_oriented["questions"][-1]
    assert structure_final["id"] == "focus_scope"
    assert "focus" in structure_final["prompt"].lower()
    assert "skip" in structure_final["prompt"].lower()
    assert structure_final["allows_custom_text"] is True

    output_oriented = clarification.build_guided_clarification(
        {
            "title": "Build a CLI Todo App",
            "material_type": "project_output",
            "summary": "A tutorial that ends with a working command line application.",
            "suggested_output": "A tested CLI todo app",
        }
    )
    output_final = output_oriented["questions"][-1]
    assert output_final["id"] == "target_output"
    assert "target output" in output_final["prompt"].lower()
    assert output_final["allows_custom_text"] is True


def test_skip_response_uses_defaults_and_marks_low_calibration_draft():
    clarification = _clarification_module().build_guided_clarification(
        {
            "title": "Distributed Systems Primer",
            "material_type": "documentation",
            "summary": "A structured primer with chapters on clocks, consensus, and replication.",
            "suggested_focus": "Consensus and replication",
        }
    )

    response = _clarification_module().build_skip_clarification_response(clarification)

    assert response["answers"] == clarification["defaults"]
    assert response["defaults"] == clarification["defaults"]
    assert response["clarification_skipped"] is True
    assert response["low_calibration"] is True


def test_unknown_material_type_uses_ordered_default_questions_instead_of_failing():
    clarification = _clarification_module().build_guided_clarification(
        {
            "title": "Mystery Learning Material",
            "material_type": "unclassified_blob",
            "summary": "The preview was fetched but no specialized handler matched.",
        }
    )

    assert [question["id"] for question in clarification["questions"]] == [
        "level_familiarity",
        "goal_depth",
        "focus_scope",
    ]
    assert set(clarification["defaults"]) == {
        "level_familiarity",
        "goal_depth",
        "focus_scope",
    }
