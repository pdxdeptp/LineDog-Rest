# Apply Group Evidence: envelope-archetype-and-depth-core

- Automation: add-initiate-changes
- Change: introduce-plan-compiler
- Checkpoint: introduce-plan-compiler:apply:envelope-archetype-and-depth-core
- Completed at: 2026-05-25T09:44:22Z
- Result: completed
- Implementation commit: b6f94fc525902a68eee3d9ed97afa805fad6fc66

## Scope

Implemented the first Plan Compiler slice:

- `PlanningEnvelope` normalization for draft identity, confirmed role, anchors, source context, existing plan context, estimates, provenance, and visible missing/assumed facts.
- Compiler result status contract for `draft_review`, `needs_input`, and `compile_failed`; `low_calibration` remains a flag and compiler output rejects scheduler-owned `infeasible_review`.
- Deterministic archetype selection and tie-breakers for finite learning, recurring practice, topic review, rebuild/clone, project packaging, and existing-project phase.
- Scope boundary output with modifiers, included/excluded material refs, confidence, visible assumption, one-question ambiguity handling, and recovery actions.
- Target-depth obligations for skim, can-use, project-level, interview-ready, and source-understanding.

Out of scope for this group:

- source/goal synopsis generation;
- LLM phase/task contracts;
- validation/repair loops;
- estimate normalization;
- compiler trace expansion;
- deterministic scheduling/date placement.

## TDD Record

Initial RED:

- Command: `cd assistant_backend && uv run pytest tests/test_study_plan_compiler.py -k 'envelope or status or archetype or tie_breaker or depth'`
- Result: failed with `ModuleNotFoundError: No module named 'src.study_plan.compiler'`.

Spec-review RED fixes:

- Command: `cd assistant_backend && uv run pytest tests/test_study_plan_compiler.py -k 'confirmed_rebuild_repo_role_beats_interview_ready_depth'`
- Result before fix: failed because `interview_ready` selected `topic_review_cycle` before confirmed `clone_rebuild_target`.
- Command: `cd assistant_backend && uv run pytest tests/test_study_plan_compiler.py -k 'unknown_target_depth_returns_needs_input_recovery_without_exception'`
- Result before fix: failed because unknown depth raised `ValueError` instead of returning `needs_input`.

Code-quality RED fixes:

- Command: `cd assistant_backend && uv run pytest tests/test_study_plan_compiler.py -k 'keyword_matching or recovery'`
- Result before fix: failed because bare substring matching misclassified `resume Python course`, `notebook`, and `discourse`; recovery semantics also did not distinguish missing versus unsupported depth.

Final GREEN:

- `cd assistant_backend && uv run pytest tests/test_study_plan_compiler.py -k 'envelope or status or archetype or tie_breaker or depth'`: 23 passed.
- `cd assistant_backend && uv run pytest tests/test_study_plan_lifecycle.py -k 'needs_input or compile_failed or package'`: 31 passed, 12 deselected.
- `openspec validate introduce-plan-compiler --strict`: valid.
- `openspec instructions apply --change introduce-plan-compiler --json`: 11/31 complete, 20 remaining.
- `git diff --check -- assistant_backend/src/study_plan/compiler.py assistant_backend/src/study_plan/__init__.py assistant_backend/tests/test_study_plan_compiler.py openspec/changes/introduce-plan-compiler/tasks.md`: no whitespace errors.

## Review Record

Spec compliance review:

- Initial result: blocked by two P1 findings.
- Fixes:
  - Confirmed `clone_rebuild_target` beats `interview_ready` for primary archetype while preserving interview modifier/depth obligations.
  - Missing or unsupported target depth now returns `needs_input` with one focused question and recovery details.
- Re-review result: APPROVED. No P0/P1/P2 blockers.

Code quality review:

- Initial result: blocked by two P1 findings.
- Fixes:
  - Replaced bare substring matching with token/phrase-boundary matching.
  - Added negative coverage for `resume Python course`, `notebook`, and `discourse`.
  - Added explicit recovery actions for ambiguous archetype and distinct missing/unsupported depth states.
- Re-review result: APPROVED.
- Deferred non-blocking P2:
  - Future groups should consider replacing nested `dict[str, Any]` result shapes with `TypedDict` or constants as compiler output grows.
  - Some tests still inspect rationale tokens; behavior negative tests now cover the critical classification risk.

## Files Changed

- `assistant_backend/src/study_plan/compiler.py`
- `assistant_backend/src/study_plan/__init__.py`
- `assistant_backend/tests/test_study_plan_compiler.py`
- `openspec/changes/introduce-plan-compiler/tasks.md`

## Git Safety

Protected unrelated dirty files were present and not touched or staged:

- `docs/agent-workflow.md`
- `openspec/changes/harden-add-initiate-automation-control/design.md`
- `openspec/changes/harden-add-initiate-automation-control/proposal.md`
- `openspec/changes/harden-add-initiate-automation-control/tasks.md`
- `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
- `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
- `openspec/changes/redesign-study-intake-planning/split-decision.md`
- `openspec/changes/redesign-study-intake-planning/tasks.md`

The run lock was not staged.

## Next Checkpoint

introduce-plan-compiler:apply:synopsis-llm-validation-and-repair
