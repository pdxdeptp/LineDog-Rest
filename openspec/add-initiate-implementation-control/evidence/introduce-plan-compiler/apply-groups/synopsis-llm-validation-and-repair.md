# Apply Group Evidence: introduce-plan-compiler / synopsis-llm-validation-and-repair

- Automation: add-initiate-changes
- Checkpoint: introduce-plan-compiler:apply:synopsis-llm-validation-and-repair
- Result: completed
- Completed at: 2026-05-25T09:47:11Z heartbeat
- Implementation commit: c98dc6f023aab50bf5b009981090abc4aee81574
- Next checkpoint: introduce-plan-compiler:apply:estimates-trace-fixtures-and-final-verification

## Scope

Completed OpenSpec tasks:

- 2.1 source/goal synopsis from shallow source facts and confirmed target output
- 2.2 thin-source low-calibration behavior without invented source structure
- 2.3 structured phase generation contract with observable completion evidence
- 2.4 structured task candidate contract with output, criteria, work type, classification, estimate, dependencies, fallback, split points, depth obligation/reducible reason, and assumptions
- 2.5 date/calendar placement rejection
- 3.1 schema validation and task quality gates
- 3.2 blocking/repairable/warning severity classification
- 3.3 bounded repair preserving anchors, target depth, source roles, selected plan, scope, and no-date constraints
- 4.5 synopsis tests
- 4.7 LLM contract and forbidden date/calendar tests
- 4.8 repair anchor/scope tests
- 4.9 bounded repair failure tests

Out of scope and preserved for the next apply group:

- estimate normalization source priority and outlier replacement
- compiler trace redaction and sensitive-content boundaries
- real-context dry-run fixtures and final verification
- deterministic scheduling, capacity math, buffer/risk, calendar dates, and UI

## Implementation

- Added `build_source_goal_synopsis` with target output/depth, source roles, shallow source facts, unknowns, material refs, estimate facts, and existing-plan context.
- Added thin-source handling that marks low calibration for shallow GitHub/source-understanding inputs instead of inventing repo structure.
- Added deterministic phase/task candidate generation for the contract layer, including archetype-aware project-packaging defaults and all target-depth essential evidence.
- Added phase/task validation for required fields, executable outputs, completion criteria, estimates, classifications, dependencies, duplicate IDs, self dependencies, multi-node cycles, dependency order inversion, vague task wording, material scope, depth-obligation warnings, and no-date/no-calendar output.
- Added bounded repair payloads that expose only invalid phase/task fragments, merge by repair tokens, allow fixing missing/duplicate task IDs, reject malformed repair tokens, reject unfailed-fragment modification, reject scope expansion, reject anchor changes, and reject nested date/calendar repair output.

## TDD Record

RED was run repeatedly before implementation changes. The final RED runs failed for the expected missing behaviors:

- synopsis missing `source_roles`
- empty phase/task output accepted as `draft_review`
- default tasks dropping required target-depth evidence
- project-packaging modes leaking demo/integration semantics
- phase errors exposing task fragments to repair
- missing/duplicate task ID repair blocked by ID-only merge
- malformed `repair_token` raising `ValueError`
- nested date/calendar repair output being silently stripped
- dependency gates missing duplicate/self/cycle/order checks

Final GREEN verification:

- `cd assistant_backend && uv run pytest tests/test_study_plan_compiler.py -k 'synopsis or thin_source or llm_contract or validation or repair or forbidden_date'`: 22 passed, 23 deselected
- `cd assistant_backend && uv run pytest tests/test_study_plan_compiler.py -k 'envelope or status or archetype or tie_breaker or depth'`: 25 passed, 20 deselected
- `openspec validate introduce-plan-compiler --strict`: valid
- `openspec instructions apply --change introduce-plan-compiler --json`: 23/31 tasks complete, state ready
- `git diff --check -- assistant_backend/src/study_plan/compiler.py assistant_backend/tests/test_study_plan_compiler.py openspec/changes/introduce-plan-compiler/tasks.md`: no whitespace errors

## Reviews

Spec compliance review:

- Initial review found missing no-executable-output blocking, incomplete essential depth obligations, overly broad repair payloads, missing `source_roles` in synopsis, weak material scope fallback, and incomplete date/calendar coverage.
- Focused re-review found repair fragment boundary issues for phase errors, missing phase repair merge, and nested date/calendar repair rejection gaps.
- Final re-review passed.

Code quality review:

- Initial review found repair error accumulation, overly generic default task generation, weak dependency validation, a synopsis test false positive, and exact-match-only vague task detection.
- Focused re-review found project-packaging mode leakage, ID-only repair merge limitations, missing phase repair, missing repair-boundary feedback into the next attempt, and insufficient multi-node cycle coverage.
- Final re-review found malformed `repair_token` crash risk and requested duplicate-ID token repair coverage.
- Final re-review passed.

## Protected Unrelated Dirty Paths

These paths were present before this checkpoint and were not edited or staged:

- `docs/agent-workflow.md`
- `openspec/changes/harden-add-initiate-automation-control/design.md`
- `openspec/changes/harden-add-initiate-automation-control/proposal.md`
- `openspec/changes/harden-add-initiate-automation-control/tasks.md`
- `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
- `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
- `openspec/changes/redesign-study-intake-planning/split-decision.md`
- `openspec/changes/redesign-study-intake-planning/tasks.md`
