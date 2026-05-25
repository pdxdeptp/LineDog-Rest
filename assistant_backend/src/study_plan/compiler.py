"""Deterministic core contracts for study plan compilation."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any

COMPILER_STATUSES = frozenset({"draft_review", "needs_input", "compile_failed"})
EXISTING_PLAN_DRAFT_KINDS = frozenset(
    {"existing_plan_phase", "existing_plan_scheduled_work"}
)

DEPTH_OBLIGATIONS: dict[str, dict[str, list[str]]] = {
    "skim_orientation": {
        "essential_evidence": ["source map", "key idea notes", "next-action decision"],
        "task_families": ["map_source", "capture_key_ideas", "decide_next_action"],
    },
    "can_use_it": {
        "essential_evidence": ["working example", "representative problem", "usable workflow note"],
        "task_families": ["run_example", "solve_representative_problem", "write_workflow_note"],
    },
    "project_level_output": {
        "essential_evidence": ["demo", "integration", "writeup", "project artifact"],
        "task_families": ["build_demo", "integrate_output", "write_project_notes"],
    },
    "interview_ready": {
        "essential_evidence": [
            "recall sheet",
            "project-linked answers",
            "mock explanation",
            "redo/review evidence",
        ],
        "task_families": ["answer_batch", "project_examples", "mock_explanation", "spaced_review"],
    },
    "source_understanding": {
        "essential_evidence": [
            "architecture map",
            "key path trace",
            "modification point",
            "tradeoff explanation",
        ],
        "task_families": ["map_architecture", "trace_key_path", "make_modification", "explain_tradeoffs"],
    },
}


@dataclass
class CompilerResult:
    """Package-shaped compiler result before deterministic scheduling."""

    status: str
    summary: str = ""
    phases: list[dict[str, Any]] = field(default_factory=list)
    tasks: list[dict[str, Any]] = field(default_factory=list)
    low_calibration: bool = False
    questions: list[str] = field(default_factory=list)
    validation_errors: list[dict[str, Any]] = field(default_factory=list)
    recovery_actions: list[str] = field(default_factory=list)
    assumptions: list[dict[str, Any]] = field(default_factory=list)
    scope_boundary: dict[str, Any] | None = None
    depth_obligations: dict[str, Any] | None = None
    trace: dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if self.status not in COMPILER_STATUSES:
            raise ValueError(f"unsupported compiler status: {self.status}")

    def to_dict(self) -> dict[str, Any]:
        return {
            "status": self.status,
            "summary": self.summary,
            "phases": self.phases,
            "tasks": self.tasks,
            "low_calibration": self.low_calibration,
            "questions": self.questions,
            "validation_errors": self.validation_errors,
            "recovery_actions": self.recovery_actions,
            "assumptions": self.assumptions,
            "scope_boundary": self.scope_boundary or _empty_scope_boundary(),
            "depth_obligations": self.depth_obligations or {},
            "trace": self.trace,
        }


def normalize_planning_envelope(payload: dict[str, Any]) -> dict[str, Any]:
    """Normalize upstream draft and anchor facts into the compiler envelope."""

    source_context = {
        "source_type": payload.get("source_type"),
        "source_url": payload.get("source_url"),
        "raw_input_summary": payload.get("raw_input_summary"),
        "source_roles": dict(payload.get("source_roles") or {}),
        "source_facts": dict(payload.get("source_facts") or {}),
        "material_refs": list(payload.get("material_refs") or []),
    }
    return {
        "schema_version": int(payload.get("schema_version") or 1),
        "draft_id": payload.get("draft_id"),
        "draft_version": payload.get("draft_version"),
        "intake_id": payload.get("intake_id"),
        "draft_kind": payload.get("draft_kind", "new_plan"),
        "target_plan_id": payload.get("target_plan_id"),
        "confirmed_role": payload.get("confirmed_role"),
        "attachment_mode": payload.get("attachment_mode"),
        "target_output": payload.get("target_output"),
        "target_depth": _normalize_depth(payload.get("target_depth")),
        "deadline": payload.get("deadline"),
        "deadline_type": payload.get("deadline_type"),
        "daily_capacity_min": payload.get("daily_capacity_min"),
        "rest_weekdays": list(payload.get("rest_weekdays") or []),
        "unavailable_dates": list(payload.get("unavailable_dates") or []),
        "buffer_policy": payload.get("buffer_policy"),
        "source_context": source_context,
        "existing_plan_context": payload.get("existing_plan_context"),
        "user_estimate_overrides": dict(payload.get("user_estimate_overrides") or {}),
        "known_effort_facts": dict(payload.get("known_effort_facts") or {}),
        "provenance": dict(payload.get("provenance") or {}),
        "missing_or_assumed_facts": list(payload.get("missing_or_assumed_facts") or []),
    }


def compile_plan(envelope: dict[str, Any]) -> dict[str, Any]:
    """Compile deterministic envelope, archetype, and depth metadata."""

    normalized = _ensure_envelope(envelope)
    depth_state = _target_depth_state(normalized.get("target_depth"))
    if depth_state != "supported":
        return _target_depth_needs_input(normalized, depth_state)
    depth = target_depth_obligations(normalized.get("target_depth"))
    boundary = select_scope_boundary(normalized)

    if boundary.get("needs_input_question"):
        return CompilerResult(
            status="needs_input",
            summary="Need one archetype decision before compiling daily work.",
            questions=[boundary["needs_input_question"]],
            recovery_actions=["choose_plan_archetype"],
            assumptions=normalized["missing_or_assumed_facts"],
            scope_boundary=boundary,
            depth_obligations=depth,
            trace=_trace(normalized, boundary),
        ).to_dict()

    return CompilerResult(
        status="draft_review",
        summary="Compiler envelope, scope, and depth obligations are ready.",
        assumptions=normalized["missing_or_assumed_facts"],
        scope_boundary=boundary,
        depth_obligations=depth,
        low_calibration=boundary["selection_confidence"] == "low",
        trace=_trace(normalized, boundary),
    ).to_dict()


def select_scope_boundary(envelope: dict[str, Any]) -> dict[str, Any]:
    """Select primary archetype and material boundary using deterministic signals."""

    candidates, rationale = _candidate_archetypes(envelope)
    if _is_existing_plan(envelope):
        primary = "existing_project_phase"
        rationale.append("existing_plan")
        rationale.append("existing_plan draft kind beats new-plan archetypes")
    else:
        primary = _choose_primary(candidates, envelope, rationale)

    boundary = _scope_from_material_refs(envelope.get("source_context", {}).get("material_refs", []))
    boundary.update(
        {
            "primary_archetype": primary,
            "secondary_modifiers": _secondary_modifiers(envelope),
            "essential_evidence": [],
            "optional_or_stretch_evidence": [],
            "selection_confidence": _selection_confidence(envelope, primary),
            "visible_assumption": _visible_assumption(envelope),
            "selection_rationale": rationale,
        }
    )

    if primary is None:
        boundary["needs_input_question"] = (
            "Which daily work shape should this plan use: recurring practice, "
            "topic review, rebuild/demo work, or packaging work?"
        )
    else:
        obligations = target_depth_obligations(envelope.get("target_depth"))
        boundary["essential_evidence"] = obligations["essential_evidence"]
        boundary["optional_or_stretch_evidence"] = _optional_evidence(boundary)

    return boundary


def target_depth_obligations(depth: str | None) -> dict[str, Any]:
    normalized = _normalize_depth(depth)
    if normalized not in DEPTH_OBLIGATIONS:
        raise ValueError(f"unsupported target_depth: {depth}")
    obligations = DEPTH_OBLIGATIONS[normalized]
    return {
        "target_depth": normalized,
        "essential_evidence": list(obligations["essential_evidence"]),
        "task_families": list(obligations["task_families"]),
    }


def _ensure_envelope(value: dict[str, Any]) -> dict[str, Any]:
    if "source_context" in value:
        normalized = dict(value)
        normalized["target_depth"] = _normalize_depth(normalized.get("target_depth"))
        normalized["source_context"] = dict(normalized.get("source_context") or {})
        normalized["missing_or_assumed_facts"] = list(
            normalized.get("missing_or_assumed_facts") or []
        )
        return normalized
    return normalize_planning_envelope(value)


def _normalize_depth(depth: Any) -> str | None:
    aliases = {
        "skim": "skim_orientation",
        "orientation": "skim_orientation",
        "can_use": "can_use_it",
        "project": "project_level_output",
        "interview": "interview_ready",
        "understand_source": "source_understanding",
    }
    if depth is None:
        return None
    normalized = str(depth).strip().lower().replace("-", "_").replace("/", "_")
    return aliases.get(normalized, normalized)


def _candidate_archetypes(envelope: dict[str, Any]) -> tuple[set[str], list[str]]:
    text = _text(envelope)
    source_type = str(envelope.get("source_context", {}).get("source_type") or "").lower()
    source_roles = envelope.get("source_context", {}).get("source_roles") or {}
    repo_role = source_roles.get("github_repo") if _is_github_source(envelope) else None
    depth = envelope.get("target_depth")
    candidates: set[str] = set()
    rationale: list[str] = []

    if _has_any(
        text,
        "resume bullets",
        "resume bullet",
        "portfolio",
        "case study",
        "project story",
        "demo polish",
    ):
        candidates.add("project_packaging")
        rationale.append("target_output packaging signal")

    if _has_any(text, "leetcode", "drill", "practice cadence", "daily drills", "redo"):
        candidates.add("recurring_practice")
        rationale.append("practice cadence signal")

    if depth == "interview_ready" or _has_any(
        text, "interview", "concept refresh", "topic review", "mock explain"
    ):
        candidates.add("topic_review_cycle")
        rationale.append("target_depth interview/topic review signal")

    if repo_role == "clone_rebuild_target" or _has_any(
        text, "clone", "rebuild", "modify", "modification"
    ):
        candidates.add("rebuild_or_clone")
        rationale.append("source_role clone/rebuild signal")

    if repo_role == "main_learning_object":
        candidates.add("finite_learning_project")
        rationale.append("source_role main learning object signal")

    if source_type in {"course", "book", "tutorial", "documentation", "docs"} or _has_any(
        text, "course", "tutorial", "book", "finish"
    ):
        candidates.add("finite_learning_project")
        rationale.append("source type finite material signal")

    if not candidates:
        candidates.add("finite_learning_project")
        rationale.append("default finite learning project")

    return candidates, rationale


def _choose_primary(
    candidates: set[str], envelope: dict[str, Any], rationale: list[str]
) -> str | None:
    target_output = str(envelope.get("target_output") or "").lower()
    depth = envelope.get("target_depth")
    repo_role = (
        (envelope.get("source_context", {}).get("source_roles") or {}).get("github_repo")
        if _is_github_source(envelope)
        else None
    )

    if {"recurring_practice", "project_packaging"} <= candidates:
        if not _has_any(target_output, "interview notes", "demo polish"):
            rationale.append("ambiguous materially different daily work")
            return None

    if _has_any(
        target_output,
        "resume bullets",
        "resume bullet",
        "portfolio",
        "case study",
        "project story",
    ):
        rationale.append("target_output")
        rationale.append("target_output beats source type")
        return "project_packaging"

    if _has_any(target_output, "leetcode", "practice cadence", "daily drills", "drill"):
        rationale.append("target_output")
        rationale.append("target_output practice cadence signal")
        return "recurring_practice"

    if repo_role == "clone_rebuild_target":
        rationale.append("source_role")
        rationale.append("source_role beats URL shape and interview-ready depth")
        return "rebuild_or_clone"

    if repo_role == "main_learning_object":
        rationale.append("source_role")
        rationale.append("source_role beats URL shape")
        return "finite_learning_project"

    if depth == "interview_ready":
        rationale.append("target_depth")
        rationale.append("target_depth beats generic learning wording")
        return "topic_review_cycle"

    for archetype in (
        "recurring_practice",
        "topic_review_cycle",
        "rebuild_or_clone",
        "project_packaging",
        "finite_learning_project",
    ):
        if archetype in candidates:
            return archetype
    return None


def _scope_from_material_refs(material_refs: list[dict[str, Any]]) -> dict[str, Any]:
    included = []
    excluded = []
    for index, ref in enumerate(material_refs):
        ref_id = ref.get("id") or ref.get("ref_id") or f"material-{index + 1}"
        if ref.get("included", True):
            included.append(ref_id)
        else:
            excluded.append(ref_id)
    return {
        "included_material_refs": included,
        "excluded_material_refs": excluded,
    }


def _selection_confidence(envelope: dict[str, Any], primary: str | None) -> str:
    if primary is None:
        return "low"
    if envelope.get("missing_or_assumed_facts"):
        return "medium"
    if envelope.get("source_context", {}).get("source_facts") or _is_existing_plan(envelope):
        return "high"
    return "medium"


def _visible_assumption(envelope: dict[str, Any]) -> str | None:
    for fact in envelope.get("missing_or_assumed_facts", []):
        assumption = fact.get("assumption") if isinstance(fact, dict) else None
        if assumption:
            return str(assumption)
    return None


def _secondary_modifiers(envelope: dict[str, Any]) -> list[str]:
    text = _text(envelope)
    modifiers = []
    if _has_any(text, "interview", "mock explain", "interview notes"):
        modifiers.append("interview_notes")
    if _has_any(text, "demo polish", "polish demo"):
        modifiers.append("demo_polish")
    if _has_any(text, "resume bullets", "resume bullet", "portfolio", "bullet"):
        modifiers.append("resume_articulation")
    return modifiers


def _optional_evidence(boundary: dict[str, Any]) -> list[str]:
    evidence = []
    if "interview_notes" in boundary["secondary_modifiers"]:
        evidence.append("interview notes")
    if "demo_polish" in boundary["secondary_modifiers"]:
        evidence.append("polished demo")
    if "resume_articulation" in boundary["secondary_modifiers"]:
        evidence.append("resume articulation")
    return evidence


def _is_existing_plan(envelope: dict[str, Any]) -> bool:
    return bool(
        envelope.get("draft_kind") in EXISTING_PLAN_DRAFT_KINDS
        or envelope.get("target_plan_id")
        or envelope.get("existing_plan_context")
        and envelope.get("attachment_mode") in {"draft_phase", "scheduled_work"}
    )


def _empty_scope_boundary() -> dict[str, Any]:
    return {
        "primary_archetype": None,
        "secondary_modifiers": [],
        "included_material_refs": [],
        "excluded_material_refs": [],
        "essential_evidence": [],
        "optional_or_stretch_evidence": [],
        "selection_confidence": "low",
        "visible_assumption": None,
        "selection_rationale": [],
    }


def _trace(envelope: dict[str, Any], boundary: dict[str, Any]) -> dict[str, Any]:
    return {
        "envelope_provenance": dict(envelope.get("provenance") or {}),
        "selected_archetype": boundary.get("primary_archetype"),
        "selection_rationale": list(boundary.get("selection_rationale") or []),
    }


def _text(envelope: dict[str, Any]) -> str:
    source = envelope.get("source_context", {})
    parts = [
        envelope.get("target_output"),
        envelope.get("target_depth"),
        source.get("source_type"),
        source.get("source_url"),
        source.get("raw_input_summary"),
    ]
    return " ".join(str(part) for part in parts if part).lower()


def _is_github_source(envelope: dict[str, Any]) -> bool:
    source = envelope.get("source_context", {})
    source_type = str(source.get("source_type") or "").lower()
    source_url = str(source.get("source_url") or "").lower()
    return source_type == "github_repo" or (
        source_type == "url" and "github.com" in source_url
    )


def _target_depth_state(depth: str | None) -> str:
    if depth is None:
        return "missing"
    if depth not in DEPTH_OBLIGATIONS:
        return "unsupported"
    return "supported"


def _target_depth_needs_input(envelope: dict[str, Any], state: str) -> dict[str, Any]:
    unsupported = state == "unsupported"
    summary = (
        f"Unsupported target depth: {envelope.get('target_depth')}"
        if unsupported
        else "Missing target depth before compiling completion obligations."
    )
    recovery_action = (
        "choose_supported_target_depth" if unsupported else "choose_target_depth"
    )
    return CompilerResult(
        status="needs_input",
        summary=summary,
        questions=[
            "What target depth should this plan use: skim orientation, can use it, project output, interview ready, or source understanding?"
        ],
        recovery_actions=[recovery_action],
        assumptions=envelope["missing_or_assumed_facts"],
        trace={
            "envelope_provenance": dict(envelope.get("provenance") or {}),
            "target_depth_state": state,
            "target_depth_value": envelope.get("target_depth"),
        },
    ).to_dict()


def _has_any(text: str, *needles: str) -> bool:
    return any(_has_phrase(text, needle) for needle in needles)


def _has_phrase(text: str, phrase: str) -> bool:
    escaped = r"\s+".join(re.escape(part) for part in phrase.lower().split())
    pattern = rf"(?<![a-z0-9]){escaped}(?![a-z0-9])"
    return re.search(pattern, text.lower()) is not None
