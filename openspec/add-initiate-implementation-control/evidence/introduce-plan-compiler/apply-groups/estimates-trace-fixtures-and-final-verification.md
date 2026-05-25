# Apply Group Evidence: introduce-plan-compiler / estimates-trace-fixtures-and-final-verification

- Automation: add-initiate-changes
- Checkpoint: introduce-plan-compiler:apply:estimates-trace-fixtures-and-final-verification
- Result: completed
- Completed at: 2026-05-25T10:46:08Z
- Implementation commit: e320594ddb161d3c9b743777ab16c756694500a1
- Next checkpoint: introduce-plan-compiler:apply:cross-change-contract-to-introduce-deadline-scheduler

## Scope

Completed OpenSpec tasks:

- 3.4 estimate normalization source priority and v1 work-type defaults
- 3.5 estimate outlier replacement, confidence assignment, oversized split requirements, and low-calibration threshold
- 3.6 compiler trace records for envelope, validation, repair, task gates, estimates, and calibration
- 3.7 sensitive-content boundaries for LLM prompts, trace records, validation errors, and prompt logs
- 4.10 estimate-normalization tests for user estimates, source facts, defaults, LLM outliers, oversized tasks, and low calibration thresholds
- 4.11 dry-run compiler tests for AgentGuide, easyagent, LeetCode, interview prep, and resume/project packaging before scheduling
- 4.12 privacy/redaction tests proving private notes, resume text, repo descriptions, and prompt logs are bounded or summarized in trace
- 4.13 fixture tests proving real-context compiler outputs contain no scheduled dates, capacity-gap math, buffer erosion, overloaded dates, or compiler-owned `infeasible_review`

Out of scope and preserved downstream:

- deterministic date placement
- schedule capacity math and infeasibility option effects
- Add / Initiate UI
- activation and active-task writes
- deep GitHub crawling or broad Obsidian sync

## Implementation

- Added deterministic estimate normalization with priority user overrides, concrete source facts, user speed factor, work-type defaults, and bounded LLM suggestions.
- Added outlier handling for LLM estimates outside 15-180 minutes, minimum estimate handling, oversized-task split/multi-session validation, estimate source/confidence fields, and low-calibration thresholds.
- Added compiler trace facts for provenance, selected archetype/modifiers, scope boundary, validation, repair, task quality gates, estimate decisions, and calibration.
- Added trace redaction for sensitive source facts, prompt/provenance fields, goal summaries, validation errors, private notes, resume text, repo descriptions, and short sensitive target-output paths.
- Added real-context unscheduled compiler fixtures for AgentGuide, easyagent, LeetCode / 灵茶山, agent/backend interview prep, and resume/project packaging.
- Tightened real-context phase shapes so fixtures match the design-level minimum phases instead of broad generic phases.

## TDD Record

RED was run before implementation and again for review fixes. Failing behaviors included:

- estimate normalization, oversized split validation, low-calibration thresholds, trace decision fields, and AgentGuide fixture shape were missing;
- low-end LLM outliers were incorrectly raised to 10 instead of being replaced by source facts/defaults;
- `needs_input` trace leaked sensitive provenance;
- boolean estimates were treated as integers;
- real-context fixtures did not verify minimum phase shapes;
- short sensitive goal text could leak through trace synopsis.

Final GREEN verification:

- `cd assistant_backend && uv run pytest tests/test_study_plan_compiler.py -k 'fixture or scheduled_dates'`: 2 passed, 50 deselected
- `cd assistant_backend && uv run pytest tests/test_study_plan_compiler.py -k 'estimate or low_calibration or trace or redaction or fixture or scheduled_dates'`: 10 passed, 42 deselected
- `cd assistant_backend && uv run pytest tests/test_study_plan_compiler.py`: 52 passed
- `openspec validate introduce-plan-compiler --strict`: valid
- `openspec instructions apply --change introduce-plan-compiler --json`: 31/31 tasks complete, state all_done
- `git diff --check -- assistant_backend/src/study_plan/compiler.py assistant_backend/tests/test_study_plan_compiler.py openspec/changes/introduce-plan-compiler/tasks.md`: no whitespace errors

## Reviews

Spec compliance review:

- Initial review found low-end LLM outlier replacement, fixture phase-shape coverage, and goal-summary redaction gaps.
- Focused re-review found real-context fixture phases still merged some design-minimum phases.
- Final re-review passed after splitting easyagent, LeetCode, interview-prep, and resume-packaging phases to the design minimum.

Code quality review:

- Initial review found `needs_input` trace redaction gaps, boolean estimate coercion, plain `duration_minutes` source-fact fragility, over-broad conflict detection, and a weakened depth-obligation test.
- Focused re-review passed after redaction, estimate type, source-fact, conflict-detection, and test-coverage fixes.

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
