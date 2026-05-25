# Apply Planning: introduce-plan-compiler

## Decision

GO. The scope dependency check passed, all OpenSpec artifacts are complete, and this change can enter implementation as a backend compiler module slice. Apply must not absorb deterministic scheduling, draft activation, Add / Initiate UI, broad Obsidian sync, or deep GitHub crawling.

## Mechanical Check

- `openspec validate introduce-plan-compiler --strict`: pass.
- `openspec status --change introduce-plan-compiler --json`: ready; proposal, design, specs, and tasks are complete.
- `openspec instructions apply --change introduce-plan-compiler --json`: apply context and 31 pending tasks are available.
- Scope dependency prerequisite: pass; `changes[2].scopeDependencyCheckCompleted=true`.
- Workspace: unrelated dirty files are protected and must not be edited or staged by this change.

## Blockers

No blockers.

## Strong Recommendations

- Keep the compiler as an unscheduled structure generator: no final dates, capacity-gap math, buffer erosion, overloaded dates, or compiler-owned `infeasible_review`.
- Prefer a pure `study_plan.compiler` module with deterministic helpers and injectable LLM contract functions so TDD can run without network calls.
- Keep draft persistence integration limited to compatibility with the existing compiler package shell; do not change activation or draft table internals unless a failing test proves a contract mismatch.
- Treat LLM output as untrusted data: schema validation, quality gates, bounded repair, and date rejection must be deterministic.
- Keep sensitive content bounded to submitted/selected content and shallow source facts; traces and logs must summarize or redact private text.

## Test And Acceptance Gaps

- Blocking: none.
- Strongly recommended: TDD must cover envelope normalization, compiler statuses, archetype/tie-breakers, target-depth obligations, source synopsis, LLM contract validation, repair invariants, estimate normalization, low-calibration thresholds, trace redaction, and real-context fixtures.
- Strongly recommended: fixture tests must prove compiler output contains no scheduled dates, capacity-gap math, buffer erosion, overloaded dates, or `infeasible_review`.

## Dispatch Recheck

Shared write targets:

- `assistant_backend/src/study_plan/compiler.py`
- `assistant_backend/src/study_plan/__init__.py`
- `assistant_backend/tests/test_study_plan_compiler.py`
- `assistant_backend/tests/test_study_plan_lifecycle.py`
- `openspec/changes/introduce-plan-compiler/tasks.md`

Parallelization decision: must run sequentially for this automation. The groups share the compiler module and test file, and later validation/fixture work depends on earlier envelope/status/archetype contracts.

Ownership rule:

- The envelope/archetype group owns core dataclasses/contracts, status semantics, depth obligations, and deterministic scope selection.
- The generation/validation group owns source synopsis, LLM phase/task contracts, no-date filtering, task quality gates, validation severities, and bounded repair.
- The estimates/trace/fixtures group owns estimate normalization, low-calibration thresholds, trace/redaction, real-context fixtures, and final OpenSpec task completion.

## Protected Unrelated Dirty Paths

- `docs/agent-workflow.md`
- `openspec/changes/harden-add-initiate-automation-control/design.md`
- `openspec/changes/harden-add-initiate-automation-control/proposal.md`
- `openspec/changes/harden-add-initiate-automation-control/tasks.md`
- `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
- `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
- `openspec/changes/redesign-study-intake-planning/split-decision.md`
- `openspec/changes/redesign-study-intake-planning/tasks.md`

## Next Step

Run `openspec-apply-change introduce-plan-compiler`, starting with the `envelope-archetype-and-depth-core` task group from `apply-task-groups.json`.
