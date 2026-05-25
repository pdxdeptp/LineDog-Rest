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

FORBIDDEN_DATE_FIELDS = frozenset(
    {
        "date",
        "scheduled_date",
        "start_date",
        "end_date",
        "due_date",
        "target_date",
        "calendar_date",
        "suggested_date",
        "calendar",
    }
)
TASK_CLASSIFICATIONS = frozenset({"essential", "optional", "stretch"})
ESTIMATE_CONFIDENCE = frozenset({"high", "medium", "low"})
VAGUE_ACTIONS = frozenset(
    {"learn langgraph", "understand agent memory", "work on resume", "study repo"}
)


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

    synopsis = build_source_goal_synopsis(normalized)
    phases = _default_phase_candidates(normalized, boundary, synopsis)
    tasks = _default_task_candidates(normalized, boundary, synopsis, phases)
    candidate_result = compile_structured_candidates(normalized, phases, tasks)
    low_calibration_reasons = list(
        candidate_result.get("trace", {}).get("low_calibration_reasons") or []
    )
    if _thin_source_reason(normalized, boundary):
        low_calibration_reasons.append("thin_source")

    result = CompilerResult(
        status="draft_review",
        summary="Compiler envelope, scope, and depth obligations are ready.",
        phases=candidate_result["phases"],
        tasks=candidate_result["tasks"],
        assumptions=normalized["missing_or_assumed_facts"],
        scope_boundary=boundary,
        depth_obligations=depth,
        low_calibration=boundary["selection_confidence"] == "low"
        or bool(low_calibration_reasons),
        trace={
            **_trace(normalized, boundary),
            "synopsis": synopsis,
            "validation": candidate_result.get("trace", {}).get("validation", {}),
            "repair_attempt_count": candidate_result.get("trace", {}).get(
                "repair_attempt_count", 0
            ),
            "low_calibration_reasons": low_calibration_reasons,
        },
    )
    return result.to_dict()


def build_source_goal_synopsis(envelope: dict[str, Any]) -> dict[str, Any]:
    """Build compact facts for narrow phase/task generation."""

    normalized = _ensure_envelope(envelope)
    source = normalized.get("source_context", {})
    facts = dict(source.get("source_facts") or {})
    target_output = str(normalized.get("target_output") or "selected outcome")
    target_depth = normalized.get("target_depth") or "unspecified depth"
    existing = normalized.get("existing_plan_context") or {}
    goal_summary = f"{target_output} at {target_depth} depth"
    if existing and _is_existing_plan(normalized):
        plan_title = existing.get("title") or f"plan {existing.get('plan_id')}"
        current = existing.get("current_phase") or existing.get("current_task_summary")
        goal_summary = f"{goal_summary} for existing plan {plan_title}"
        if current:
            goal_summary = f"{goal_summary}; current context: {current}"

    source_bits: list[str] = []
    source_type = source.get("source_type")
    if source_type:
        source_bits.append(str(source_type))
    for key in ("repo_name", "course_title", "note_title", "description"):
        if facts.get(key):
            source_bits.append(str(facts[key]))
    if facts.get("languages"):
        source_bits.append(f"languages: {', '.join(map(str, facts['languages']))}")
    if facts.get("module_headings"):
        source_bits.append(f"{len(facts['module_headings'])} module headings")
    if facts.get("snippet_count"):
        source_bits.append(f"{facts['snippet_count']} selected note snippets")
    if facts.get("snippet_summary"):
        source_bits.append(str(facts["snippet_summary"]))
    if source.get("source_url") and not facts:
        source_bits.append("URL only")

    unknowns = _synopsis_unknowns(normalized)
    return {
        "goal_summary": goal_summary,
        "source_summary": "; ".join(source_bits) or "No source facts beyond user target.",
        "source_roles": dict(source.get("source_roles") or {}),
        "unknowns": unknowns,
        "material_refs": _material_ref_ids(source.get("material_refs") or []),
        "estimate_facts": dict(normalized.get("known_effort_facts") or {}),
    }


def validate_phase_candidates(phases: list[dict[str, Any]]) -> dict[str, Any]:
    """Validate narrow phase schema and strip scheduler-owned date fields."""

    errors: list[dict[str, Any]] = []
    accepted: list[dict[str, Any]] = []
    if not phases:
        return {
            "accepted": [],
            "errors": [
                _validation_error("no_executable_output", "blocking", "phases")
            ],
        }
    required = {
        "id",
        "title",
        "purpose",
        "essential",
        "effort_range",
        "completion_evidence",
        "milestones",
        "assumptions",
    }
    for index, phase in enumerate(phases):
        sanitized = _strip_forbidden_dates(phase)
        missing = sorted(field for field in required if field not in sanitized)
        for field in ("id", "title", "purpose", "effort_range", "completion_evidence"):
            if field in sanitized and not _has_value(sanitized.get(field)):
                missing.append(field)
        for field in missing:
            errors.append(
                _validation_error("missing_phase_field", "blocking", field, index)
            )
        if not missing:
            accepted.append(sanitized)
    return {"accepted": accepted, "errors": errors}


def validate_task_candidates(
    tasks: list[dict[str, Any]],
    *,
    phases: list[dict[str, Any]],
    included_material_refs: list[str],
    target_depth: str | None,
) -> dict[str, Any]:
    """Validate task schema, executable quality, scope, dependencies, and dates."""

    errors: list[dict[str, Any]] = []
    accepted: list[dict[str, Any]] = []
    if not tasks:
        return {
            "accepted": [],
            "errors": [
                _validation_error("no_executable_output", "blocking", "tasks")
            ],
        }
    task_id_counts: dict[str, int] = {}
    for task in tasks:
        if task.get("id"):
            task_id = str(task["id"])
            task_id_counts[task_id] = task_id_counts.get(task_id, 0) + 1
    task_ids = set(task_id_counts)
    duplicate_ids = {task_id for task_id, count in task_id_counts.items() if count > 1}
    order_by_id = {
        str(task.get("id")): task.get("order")
        for task in tasks
        if task.get("id") and task_id_counts.get(str(task.get("id"))) == 1
    }
    phase_ids = {str(phase.get("id")) for phase in phases if phase.get("id")}
    included = set(included_material_refs)
    depth_evidence = set(
        target_depth_obligations(target_depth)["essential_evidence"]
        if _target_depth_state(_normalize_depth(target_depth)) == "supported"
        else []
    )

    for index, task in enumerate(tasks):
        date_fields = sorted(set(task) & FORBIDDEN_DATE_FIELDS)
        for field in date_fields:
            errors.append(
                _validation_error("forbidden_date_field", "repairable", field, index)
            )
        sanitized = _strip_forbidden_dates(task)
        task_errors: list[dict[str, Any]] = []
        task_id = str(sanitized.get("id")) if sanitized.get("id") else None
        if task_id in duplicate_ids:
            task_errors.append(
                _validation_error("duplicate_task_id", "blocking", "id", index)
            )

        required = {
            "id",
            "phase_id",
            "order",
            "work_type",
            "classification",
            "action_title",
            "concrete_output",
            "completion_criteria",
            "estimated_minutes",
            "estimate_confidence",
            "dependencies",
            "material_refs",
            "normal_mode",
            "fallback_mode",
            "split_points",
            "assumptions",
        }
        if not (
            _has_value(sanitized.get("depth_obligation"))
            or _has_value(sanitized.get("reducible_reason"))
        ):
            task_errors.append(
                _validation_error("missing_depth_obligation", "blocking", "depth", index)
            )
        for field in sorted(required):
            if field not in sanitized or (
                field
                in {
                    "id",
                    "phase_id",
                    "order",
                    "work_type",
                    "classification",
                    "action_title",
                    "concrete_output",
                    "completion_criteria",
                    "estimated_minutes",
                    "estimate_confidence",
                    "normal_mode",
                }
                and not _has_value(sanitized.get(field))
            ):
                code = (
                    "missing_completion_criteria"
                    if field == "completion_criteria"
                    else "missing_task_field"
                )
                task_errors.append(_validation_error(code, "blocking", field, index))

        if sanitized.get("phase_id") and str(sanitized["phase_id"]) not in phase_ids:
            task_errors.append(
                _validation_error("invalid_phase_id", "blocking", "phase_id", index)
            )
        if sanitized.get("classification") not in TASK_CLASSIFICATIONS:
            task_errors.append(
                _validation_error("invalid_classification", "blocking", "classification", index)
            )
        if sanitized.get("estimate_confidence") not in ESTIMATE_CONFIDENCE:
            task_errors.append(
                _validation_error(
                    "invalid_estimate_confidence",
                    "blocking",
                    "estimate_confidence",
                    index,
                )
            )
        if not _valid_estimate(sanitized.get("estimated_minutes")):
            task_errors.append(
                _validation_error("invalid_estimate", "blocking", "estimated_minutes", index)
            )
        if _is_vague_task(sanitized):
            task_errors.append(
                _validation_error("vague_task", "blocking", "action_title", index)
            )
        for dependency in sanitized.get("dependencies") or []:
            dependency_id = str(dependency)
            if task_id and dependency_id == task_id:
                task_errors.append(
                    _validation_error("self_dependency", "blocking", "dependencies", index)
                )
            if dependency_id not in task_ids:
                task_errors.append(
                    _validation_error("invalid_dependency", "blocking", "dependencies", index)
                )
            elif task_id and _dependency_order_inverted(
                sanitized.get("order"), order_by_id.get(dependency_id)
            ):
                task_errors.append(
                    _validation_error(
                        "dependency_order_inversion", "blocking", "dependencies", index
                    )
                )
        for ref in sanitized.get("material_refs") or []:
            if str(ref) == "submitted-item":
                continue
            if str(ref) not in included:
                task_errors.append(
                    _validation_error(
                        "out_of_scope_material_ref", "blocking", "material_refs", index
                    )
                )
        if (
            sanitized.get("classification") == "essential"
            and sanitized.get("depth_obligation")
            and sanitized["depth_obligation"] not in depth_evidence
        ):
            task_errors.append(
                _validation_error(
                    "depth_obligation_contradiction", "warning", "depth_obligation", index
                )
            )

        errors.extend(task_errors)
        if not any(error["severity"] == "blocking" for error in task_errors):
            accepted.append(sanitized)
    errors.extend(_cycle_errors(tasks, duplicate_ids))
    return {"accepted": accepted, "errors": errors}


def compile_structured_candidates(
    envelope: dict[str, Any],
    phases: list[dict[str, Any]],
    tasks: list[dict[str, Any]],
    repair_fn: Any | None = None,
) -> dict[str, Any]:
    """Validate candidates and run at most two scoped repair attempts."""

    normalized = _ensure_envelope(envelope)
    boundary = select_scope_boundary(normalized)
    included_refs = boundary.get("included_material_refs") or _material_ref_ids(
        normalized.get("source_context", {}).get("material_refs") or []
    )
    if not included_refs:
        included_refs = ["submitted-item"]
    preserved = _preserved_anchor_snapshot(normalized, boundary)
    package = {"phases": phases, "tasks": tasks}
    repair_attempt_count = 0
    all_errors: list[dict[str, Any]] = []
    prior_repair_errors: list[dict[str, Any]] = []

    for attempt in range(0, 3):
        phase_validation = validate_phase_candidates(package.get("phases") or [])
        task_validation = validate_task_candidates(
            package.get("tasks") or [],
            phases=phase_validation["accepted"],
            included_material_refs=included_refs,
            target_depth=normalized.get("target_depth"),
        )
        errors = prior_repair_errors + phase_validation["errors"] + task_validation["errors"]
        all_errors = errors
        blocking = [error for error in errors if error["severity"] == "blocking"]
        if not blocking:
            return CompilerResult(
                status="draft_review",
                phases=phase_validation["accepted"],
                tasks=task_validation["accepted"],
                low_calibration=any(error["severity"] == "warning" for error in errors),
                scope_boundary=boundary,
                depth_obligations=target_depth_obligations(normalized.get("target_depth")),
                validation_errors=errors,
                trace={
                    **_trace(normalized, boundary),
                    "validation": {"errors": errors},
                    "repair_attempt_count": repair_attempt_count,
                    "preserved_anchors": preserved,
                    "low_calibration_reasons": [
                        "validation_warning"
                        for error in errors
                        if error["severity"] == "warning"
                    ],
                },
            ).to_dict()
        if repair_fn is None or attempt == 2:
            break
        repair_attempt_count += 1
        repair_payload = _repair_payload(
            package=package,
            phase_validation=phase_validation,
            task_validation=task_validation,
            errors=errors,
            phase_errors=phase_validation["errors"],
            task_errors=task_validation["errors"],
        )
        repaired = repair_fn(repair_attempt_count, errors, repair_payload)
        anchor_errors = _repair_boundary_errors(repaired or {}, preserved, included_refs)
        all_errors = errors + anchor_errors
        if anchor_errors:
            if repair_attempt_count >= 2:
                break
            prior_repair_errors = anchor_errors
            continue
        prior_repair_errors = []
        merge_result = _merge_repaired_package(
            package,
            repaired or {},
            phase_validation["errors"],
            task_validation["errors"],
        )
        if merge_result["errors"]:
            all_errors = errors + merge_result["errors"]
            break
        package = {
            "phases": merge_result["phases"],
            "tasks": merge_result["tasks"],
        }

    return CompilerResult(
        status="compile_failed",
        validation_errors=all_errors,
        recovery_actions=["revise_task_candidates", "ask_for_more_source_facts"],
        scope_boundary=boundary,
        depth_obligations=target_depth_obligations(normalized.get("target_depth")),
        trace={
            **_trace(normalized, boundary),
            "validation": {"errors": all_errors},
            "repair_attempt_count": repair_attempt_count,
            "preserved_anchors": preserved,
        },
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


def _synopsis_unknowns(envelope: dict[str, Any]) -> list[str]:
    source = envelope.get("source_context", {})
    facts = source.get("source_facts") or {}
    unknowns = []
    if _is_github_source(envelope):
        if not any(facts.get(key) for key in ("readme_headings", "files", "entry_points")):
            unknowns.append("repo_structure")
        if not facts.get("quickstart"):
            unknowns.append("setup_path")
    if source.get("source_type") in {"course", "tutorial", "book"} and not facts.get(
        "module_headings"
    ):
        unknowns.append("material_structure")
    if not envelope.get("known_effort_facts"):
        unknowns.append("effort_counts")
    return unknowns


def _material_ref_ids(material_refs: list[dict[str, Any]]) -> list[str]:
    return [
        str(ref.get("id") or ref.get("ref_id") or f"material-{index + 1}")
        for index, ref in enumerate(material_refs)
        if ref.get("included", True)
    ]


def _thin_source_reason(
    envelope: dict[str, Any], boundary: dict[str, Any]
) -> str | None:
    primary = boundary.get("primary_archetype")
    depth = envelope.get("target_depth")
    if primary not in {"rebuild_or_clone", "finite_learning_project"} and depth != "source_understanding":
        return None
    facts = envelope.get("source_context", {}).get("source_facts") or {}
    useful_fact_count = sum(
        1
        for key in (
            "readme_headings",
            "files",
            "entry_points",
            "module_headings",
            "quickstart",
            "languages",
        )
        if facts.get(key)
    )
    if _is_github_source(envelope) and useful_fact_count < 2:
        return "thin_source"
    return None


def _default_phase_candidates(
    envelope: dict[str, Any],
    boundary: dict[str, Any],
    synopsis: dict[str, Any],
) -> list[dict[str, Any]]:
    archetype = boundary.get("primary_archetype") or "finite_learning_project"
    phase_shapes = {
        "rebuild_or_clone": [
            ("phase-1", "Inspect baseline", "Map the selected source and runnable path."),
            ("phase-2", "Rebuild minimal path", "Create a small verified reproduction."),
        ],
        "recurring_practice": [
            ("phase-1", "Diagnostic", "Find starting level and recurring cadence."),
            ("phase-2", "Practice loop", "Solve, tag misses, and schedule redos."),
        ],
        "topic_review_cycle": [
            ("phase-1", "Active recall inventory", "Turn topics into answerable prompts."),
            ("phase-2", "Mock explanation", "Explain with gaps and review evidence."),
        ],
        "project_packaging": [
            ("phase-1", "Evidence inventory", "Collect proof points for the story."),
            ("phase-2", "Rewrite and rehearse", "Produce revised bullets or narrative."),
        ],
        "existing_project_phase": [
            ("phase-1", "Attach bounded phase", "Fit the new work to the selected plan context."),
        ],
        "finite_learning_project": [
            ("phase-1", "Orient source", "Map useful material for the target output."),
            ("phase-2", "Produce usable output", "Build the requested evidence artifact."),
        ],
    }
    return [
        {
            "id": phase_id,
            "title": title,
            "purpose": purpose,
            "essential": True,
            "effort_range": {"min": 45, "max": 90},
            "completion_evidence": [synopsis["goal_summary"]],
            "milestones": [title],
            "assumptions": [],
        }
        for phase_id, title, purpose in phase_shapes.get(
            archetype, phase_shapes["finite_learning_project"]
        )
    ]


def _default_task_candidates(
    envelope: dict[str, Any],
    boundary: dict[str, Any],
    synopsis: dict[str, Any],
    phases: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    obligations = target_depth_obligations(envelope.get("target_depth"))
    refs = boundary.get("included_material_refs") or synopsis["material_refs"]
    if not refs:
        refs = ["submitted-item"]
    archetype = boundary.get("primary_archetype") or "finite_learning_project"
    outputs = _archetype_task_outputs(archetype, obligations["essential_evidence"])
    tasks = []
    for index, output in enumerate(outputs, start=1):
        evidence = output["depth_obligation"]
        phase = phases[min(index - 1, len(phases) - 1)]
        tasks.append(
            {
                "id": f"task-{index}",
                "phase_id": phase["id"],
                "order": index,
                "work_type": output.get("work_type") or _work_type_for_evidence(evidence),
                "classification": "essential",
                "action_title": output["action_title"],
                "concrete_output": output["concrete_output"],
                "completion_criteria": [output["completion_criteria"]],
                "estimated_minutes": 60,
                "estimate_confidence": "low"
                if "effort_counts" in synopsis["unknowns"]
                else "medium",
                "dependencies": [f"task-{index - 1}"] if index > 1 else [],
                "material_refs": refs[:1],
                "normal_mode": output.get("normal_mode") or f"produce {evidence}",
                "fallback_mode": output.get("fallback_mode")
                or f"write a smaller {evidence}",
                "split_points": [],
                "depth_obligation": evidence,
                "assumptions": [],
            }
        )
    return tasks


def _archetype_task_outputs(
    archetype: str, essential_evidence: list[str]
) -> list[dict[str, str]]:
    packaging_titles = [
        "Inventory project evidence",
        "Draft impact-first bullet variants",
        "Draft project story",
        "Revise packaging artifact",
    ]
    packaging_outputs = [
        "evidence inventory for selected project",
        "three impact-first resume bullet variants",
        "portfolio project story draft",
        "revised packaging artifact",
    ]
    if archetype == "project_packaging":
        return [
            {
                "depth_obligation": evidence,
                "action_title": packaging_titles[index],
                "concrete_output": packaging_outputs[index],
                "completion_criteria": f"{packaging_outputs[index]} exists",
                "work_type": "writeup" if index else "orientation",
                "normal_mode": f"create {packaging_outputs[index]}",
                "fallback_mode": f"draft a smaller {packaging_outputs[index]}",
            }
            for index, evidence in enumerate(essential_evidence)
        ]

    if archetype == "recurring_practice":
        titles = [
            "Run diagnostic practice set",
            "Complete focused practice block",
            "Tag mistakes and patterns",
            "Create redo checkpoint",
        ]
        return [
            {
                "depth_obligation": evidence,
                "action_title": titles[index] if index < len(titles) else f"Practice {evidence}",
                "concrete_output": f"{evidence} practice evidence",
                "completion_criteria": f"{evidence} practice evidence exists",
                "work_type": "practice",
            }
            for index, evidence in enumerate(essential_evidence)
        ]

    return [
        {
            "depth_obligation": evidence,
            "action_title": _action_title_for_evidence(evidence),
            "concrete_output": evidence,
            "completion_criteria": f"observable {evidence} exists",
            "work_type": _work_type_for_evidence(evidence),
        }
        for evidence in essential_evidence
    ]


def _work_type_for_evidence(evidence: str) -> str:
    if "trace" in evidence or "architecture" in evidence:
        return "source_trace"
    if "demo" in evidence or "integration" in evidence:
        return "build"
    if "recall" in evidence or "explanation" in evidence:
        return "active_recall"
    if "resume" in evidence or "writeup" in evidence:
        return "writeup"
    return "orientation"


def _action_title_for_evidence(evidence: str) -> str:
    verbs = {
        "source map": "Create source map",
        "architecture map": "Create architecture map",
        "key path trace": "Trace key path",
        "working example": "Run working example",
        "demo": "Build demo artifact",
        "recall sheet": "Draft recall sheet",
    }
    return verbs.get(evidence, f"Produce {evidence}")


def _strip_forbidden_dates(candidate: dict[str, Any]) -> dict[str, Any]:
    return {
        key: _strip_forbidden_value(value)
        for key, value in candidate.items()
        if key not in FORBIDDEN_DATE_FIELDS
    }


def _strip_forbidden_value(value: Any) -> Any:
    if isinstance(value, dict):
        return _strip_forbidden_dates(value)
    if isinstance(value, list):
        return [_strip_forbidden_value(item) for item in value]
    return value


def _validation_error(
    code: str, severity: str, field: str, index: int | None = None
) -> dict[str, Any]:
    error = {"code": code, "severity": severity, "field": field}
    if index is not None:
        error["index"] = index
    return error


def _has_value(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, (list, dict, tuple, set)):
        return bool(value)
    return True


def _valid_estimate(value: Any) -> bool:
    return isinstance(value, int) and 10 <= value <= 180


def _is_vague_task(task: dict[str, Any]) -> bool:
    title = str(task.get("action_title") or "").strip().lower()
    concrete_output = str(task.get("concrete_output") or "").strip()
    if not concrete_output:
        return True
    if title in VAGUE_ACTIONS:
        return True
    return any(
        re.match(pattern, title)
        for pattern in (
            r"^learn\b",
            r"^understand\b",
            r"^study( the)?\b",
            r"^work on\b",
        )
    )


def _dependency_order_inverted(order: Any, dependency_order: Any) -> bool:
    if not isinstance(order, int) or not isinstance(dependency_order, int):
        return False
    return dependency_order >= order


def _cycle_errors(
    tasks: list[dict[str, Any]], duplicate_ids: set[str]
) -> list[dict[str, Any]]:
    graph: dict[str, list[str]] = {}
    index_by_id: dict[str, int] = {}
    for index, task in enumerate(tasks):
        task_id = str(task.get("id")) if task.get("id") else None
        if not task_id or task_id in duplicate_ids:
            continue
        graph[task_id] = [str(dep) for dep in task.get("dependencies") or []]
        index_by_id[task_id] = index

    errors = []
    visiting: set[str] = set()
    visited: set[str] = set()
    cycle_nodes: set[str] = set()

    def visit(task_id: str, path: list[str]) -> None:
        if task_id in visiting:
            cycle_nodes.update(path[path.index(task_id) :] if task_id in path else [task_id])
            return
        if task_id in visited:
            return
        visiting.add(task_id)
        for dependency in graph.get(task_id, []):
            if dependency in graph:
                visit(dependency, [*path, dependency])
        visiting.remove(task_id)
        visited.add(task_id)

    for task_id in graph:
        visit(task_id, [task_id])

    for task_id in sorted(cycle_nodes):
        errors.append(
            _validation_error(
                "cyclic_dependency", "blocking", "dependencies", index_by_id[task_id]
            )
        )
    return errors


def _repair_payload(
    *,
    package: dict[str, Any],
    phase_validation: dict[str, Any],
    task_validation: dict[str, Any],
    errors: list[dict[str, Any]],
    phase_errors: list[dict[str, Any]],
    task_errors: list[dict[str, Any]],
) -> dict[str, Any]:
    phase_blocking = any(error.get("severity") == "blocking" for error in phase_errors)
    invalid_phase_indexes = sorted(
        {
            error["index"]
            for error in phase_errors
            if error.get("severity") == "blocking"
            and isinstance(error.get("index"), int)
            and error["index"] < len(package.get("phases") or [])
        }
    )
    invalid_task_indexes = sorted(
        {
            error["index"]
            for error in task_errors
            if error.get("severity") == "blocking"
            and not (phase_blocking and error.get("code") == "invalid_phase_id")
            and isinstance(error.get("index"), int)
            and error["index"] < len(package.get("tasks") or [])
        }
    )
    return {
        "phases": phase_validation["accepted"],
        "invalid_phases": [
            {**dict((package.get("phases") or [])[index]), "repair_token": f"phase:{index}"}
            for index in invalid_phase_indexes
        ],
        "invalid_tasks": [
            {**dict((package.get("tasks") or [])[index]), "repair_token": f"task:{index}"}
            for index in invalid_task_indexes
        ],
        "errors": [dict(error) for error in errors],
    }


def _merge_repaired_package(
    package: dict[str, Any],
    repaired: dict[str, Any],
    phase_errors: list[dict[str, Any]],
    task_errors: list[dict[str, Any]],
) -> dict[str, Any]:
    phase_merge = _merge_repaired_items(
        items=package.get("phases") or [],
        repaired_items=repaired.get("phases") or [],
        errors=phase_errors,
        token_prefix="phase",
    )
    task_merge = _merge_repaired_items(
        items=package.get("tasks") or [],
        repaired_items=repaired.get("tasks") or [],
        errors=task_errors,
        token_prefix="task",
    )
    return {
        "phases": phase_merge["items"],
        "tasks": task_merge["items"],
        "errors": phase_merge["errors"] + task_merge["errors"],
    }


def _merge_repaired_items(
    *,
    items: list[dict[str, Any]],
    repaired_items: list[dict[str, Any]],
    errors: list[dict[str, Any]],
    token_prefix: str,
) -> dict[str, Any]:
    current_items = [dict(item) for item in items]
    invalid_indexes = _invalid_indexes_from_errors(errors, len(current_items))
    merge_errors = []
    merged = list(current_items)
    for item in repaired_items:
        token = item.get("repair_token")
        if not isinstance(token, str) or not token.startswith(f"{token_prefix}:"):
            item_id = item.get("id")
            index = _index_for_repaired_id(item_id, current_items, invalid_indexes)
            if index is None:
                merge_errors.append(
                    _validation_error(
                        f"repair_modified_unfailed_{token_prefix}",
                        "blocking",
                        f"{token_prefix}s",
                    )
                )
                continue
        else:
            index = _repair_token_index(token, token_prefix)
            if index is None:
                merge_errors.append(
                    _validation_error(
                        "invalid_repair_token", "blocking", f"{token_prefix}s"
                    )
                )
                continue
            if index not in invalid_indexes:
                merge_errors.append(
                    _validation_error(
                        f"repair_modified_unfailed_{token_prefix}",
                        "blocking",
                        f"{token_prefix}s",
                    )
                )
                continue
        cleaned = dict(item)
        cleaned.pop("repair_token", None)
        merged[index] = cleaned
    return {"items": merged, "errors": merge_errors}


def _repair_token_index(token: str, token_prefix: str) -> int | None:
    prefix = f"{token_prefix}:"
    if not token.startswith(prefix):
        return None
    raw_index = token[len(prefix) :]
    if not raw_index.isdigit():
        return None
    return int(raw_index)


def _invalid_indexes_from_errors(errors: list[dict[str, Any]], item_count: int) -> set[int]:
    return {
        error["index"]
        for error in errors
        if error.get("severity") == "blocking"
        and isinstance(error.get("index"), int)
        and error["index"] < item_count
    }


def _index_for_repaired_id(
    item_id: Any, items: list[dict[str, Any]], invalid_indexes: set[int]
) -> int | None:
    if item_id is None:
        return None
    for index in invalid_indexes:
        if items[index].get("id") == item_id:
            return index
    return None


def _merge_repaired_tasks(
    package: dict[str, Any], repaired: dict[str, Any], errors: list[dict[str, Any]]
) -> dict[str, Any]:
    """Compatibility shim for any direct internal callers."""
    current_tasks = [dict(task) for task in package.get("tasks") or []]
    invalid_indexes = {
        error["index"]
        for error in errors
        if error.get("severity") == "blocking"
        and isinstance(error.get("index"), int)
        and error["index"] < len(current_tasks)
    }
    invalid_ids = {
        str(current_tasks[index].get("id"))
        for index in invalid_indexes
        if current_tasks[index].get("id")
    }
    index_by_id = {
        str(task.get("id")): index for index, task in enumerate(current_tasks) if task.get("id")
    }
    merge_errors = []
    merged = list(current_tasks)
    for task in repaired.get("tasks") or []:
        task_id = str(task.get("id")) if task.get("id") else None
        if task_id not in invalid_ids:
            merge_errors.append(
                _validation_error("repair_modified_unfailed_task", "blocking", "tasks")
            )
            continue
        merged[index_by_id[task_id]] = dict(task)
    return {"tasks": merged, "errors": merge_errors}


def _preserved_anchor_snapshot(
    envelope: dict[str, Any], boundary: dict[str, Any]
) -> dict[str, Any]:
    return {
        "target_depth": envelope.get("target_depth"),
        "deadline_type": envelope.get("deadline_type"),
        "source_roles": dict(envelope.get("source_context", {}).get("source_roles") or {}),
        "target_plan_id": envelope.get("target_plan_id"),
        "primary_archetype": boundary.get("primary_archetype"),
        "included_material_refs": list(boundary.get("included_material_refs") or []),
    }


def _repair_boundary_errors(
    repaired: dict[str, Any],
    preserved: dict[str, Any],
    included_refs: list[str],
) -> list[dict[str, Any]]:
    errors = []
    for field in ("target_depth", "deadline_type", "target_plan_id"):
        if field in repaired and repaired[field] != preserved.get(field):
            errors.append(_validation_error("repair_changed_anchor", "blocking", field))
    source_roles = repaired.get("source_roles")
    if source_roles is not None and source_roles != preserved.get("source_roles"):
        errors.append(_validation_error("repair_changed_anchor", "blocking", "source_roles"))
    allowed_refs = set(included_refs)
    for index, phase in enumerate(repaired.get("phases") or []):
        for field in _forbidden_paths(phase):
            errors.append(_validation_error("forbidden_date_field", "blocking", field, index))
    for index, task in enumerate(repaired.get("tasks") or []):
        for field in _forbidden_paths(task):
            errors.append(_validation_error("forbidden_date_field", "blocking", field, index))
        for ref in task.get("material_refs") or []:
            if allowed_refs and ref not in allowed_refs:
                errors.append(
                    _validation_error("repair_expanded_scope", "blocking", "material_refs", index)
                )
    return errors


def _forbidden_paths(value: Any, prefix: str = "") -> list[str]:
    if isinstance(value, dict):
        paths = []
        for key, nested in value.items():
            path = f"{prefix}.{key}" if prefix else str(key)
            if key in FORBIDDEN_DATE_FIELDS:
                paths.append(path)
            else:
                paths.extend(_forbidden_paths(nested, path))
        return paths
    if isinstance(value, list):
        paths = []
        for index, nested in enumerate(value):
            paths.extend(_forbidden_paths(nested, f"{prefix}[{index}]"))
        return paths
    return []


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
