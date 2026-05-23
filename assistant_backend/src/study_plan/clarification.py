"""Minimal D30 guided clarification helpers."""

from __future__ import annotations

from typing import Any


STRUCTURE_ORIENTED_TYPES = frozenset(
    {
        "article",
        "book",
        "course",
        "documentation",
        "docs",
        "pdf",
        "structured_course",
        "structure",
        "syllabus",
    }
)
OUTPUT_ORIENTED_TYPES = frozenset(
    {
        "build",
        "project",
        "project_output",
        "tutorial",
        "workshop",
        "output",
        "output_oriented",
    }
)


def _material_type(preview: dict[str, Any]) -> str:
    return str(preview.get("material_type") or "unknown").strip().lower()


def _matches_type(material_type: str, candidates: frozenset[str]) -> bool:
    return any(candidate in material_type for candidate in candidates)


def _recommended_option(label: str, value: str) -> dict[str, Any]:
    return {
        "id": "recommended",
        "label": label,
        "value": value,
        "recommended": True,
        "default": True,
    }


def _unsure_option(value: str) -> dict[str, Any]:
    return {
        "id": "unsure_recommended",
        "label": "Not sure / use recommended",
        "value": value,
        "uses_default": True,
    }


def _level_question(default_value: str) -> dict[str, Any]:
    return {
        "id": "level_familiarity",
        "prompt": "What is your current level or familiarity with this material?",
        "options": [
            _recommended_option("Use recommended familiarity", default_value),
            {"id": "new_to_topic", "label": "New to this", "value": "new_to_topic"},
            {
                "id": "some_familiarity",
                "label": "Some familiarity",
                "value": "some_familiarity",
            },
            _unsure_option(default_value),
        ],
    }


def _goal_question(default_value: str) -> dict[str, Any]:
    return {
        "id": "goal_depth",
        "prompt": "What learning goal and target depth should the plan aim for?",
        "options": [
            _recommended_option("Use recommended goal", default_value),
            {"id": "understand", "label": "Understand concepts", "value": "understand"},
            {"id": "apply", "label": "Apply or solve problems", "value": "apply"},
            {"id": "produce", "label": "Produce an output", "value": "produce"},
            {"id": "exam", "label": "Prepare for an exam", "value": "exam"},
            _unsure_option(default_value),
        ],
    }


def _focus_question(default_value: str) -> dict[str, Any]:
    return {
        "id": "focus_scope",
        "prompt": "What focus or skip scope should guide the draft plan?",
        "allows_custom_text": True,
        "options": [
            _recommended_option("Use recommended focus", default_value),
            {
                "id": "full_structure",
                "label": "Follow the full structure",
                "value": "full_structure",
            },
            {"id": "focus_core", "label": "Focus on core sections", "value": "focus_core"},
            {
                "id": "skip_known_sections",
                "label": "Skip familiar sections",
                "value": "skip_known_sections",
            },
            _unsure_option(default_value),
        ],
    }


def _target_output_question(default_value: str) -> dict[str, Any]:
    return {
        "id": "target_output",
        "prompt": "What target output should the plan help you produce?",
        "allows_custom_text": True,
        "options": [
            _recommended_option("Use recommended output", default_value),
            {
                "id": "working_project",
                "label": "Working project",
                "value": "working_project",
            },
            {
                "id": "portfolio_artifact",
                "label": "Portfolio artifact",
                "value": "portfolio_artifact",
            },
            {"id": "practice_result", "label": "Practice result", "value": "practice_result"},
            _unsure_option(default_value),
        ],
    }


def build_guided_clarification(preview: dict[str, Any]) -> dict[str, Any]:
    """Build the bounded D30 clarification surface from a URL preview."""

    material_type = _material_type(preview)
    level_default = "some_familiarity"
    goal_default = "understand_and_apply"

    questions = [
        _level_question(level_default),
        _goal_question(goal_default),
    ]
    defaults = {
        "level_familiarity": level_default,
        "goal_depth": goal_default,
    }

    if _matches_type(material_type, OUTPUT_ORIENTED_TYPES):
        output_default = str(preview.get("suggested_output") or "working_output")
        questions.append(_target_output_question(output_default))
        defaults["target_output"] = output_default
    else:
        focus_default = str(preview.get("suggested_focus") or "recommended_focus")
        questions.append(_focus_question(focus_default))
        defaults["focus_scope"] = focus_default

    return {
        "version": "d30-guided-clarification-v1",
        "material_type": material_type,
        "questions": questions[:3],
        "defaults": defaults,
        "skip_action": {
            "id": "generate_rough_draft",
            "label": "Generate rough draft",
            "uses_defaults": True,
        },
    }


def build_skip_clarification_response(clarification: dict[str, Any]) -> dict[str, Any]:
    """Return decomposition-ready defaults for the rough-draft skip path."""

    defaults = dict(clarification.get("defaults") or {})
    return {
        "answers": defaults,
        "defaults": defaults,
        "clarification_skipped": True,
        "low_calibration": True,
    }
