# Add / Initiate Implementation Automation Progress

## Current Status

- Phase: active
- Current change: introduce-study-intake-router
- Current step: apply
- Current checkpoint: introduce-study-intake-router:apply:routing-contracts-and-confirmation
- Required product-deepen rounds before apply: 3
- Required checkpoint after product deepening: scope_dependency_check
- Product-deepen scope guard: every round must read adjacent changes and record scope decisions
- Lock file: `openspec/add-initiate-implementation-control/run.lock`
- Runbook: `openspec/add-initiate-implementation-control/runbook.md`
- Evidence root: `openspec/add-initiate-implementation-control/evidence`
- Stale lock recovery: automatic quarantine to `recovered-locks/` after 90 minutes
- Evidence manifest: `openspec/add-initiate-implementation-control/evidence/manifest.json`
- Failure log: `openspec/add-initiate-implementation-control/evidence/failures/failure-log.jsonl`
- Apply recovery: `state.json.applyCursor` plus per-change apply task groups

## Run Log

## Run 2026-05-25T03:43:28Z

- Automation: add-initiate-changes
- Checkpoint: introduce-study-intake-router:product_deepen_round_1
- Result: completed
- Actions:
  - Ran first product-deepen review for `introduce-study-intake-router`.
  - Added `review-records/product-deepen-round-1.md`.
  - Clarified router contracts, idempotent submission, existing-plan target selection, and separation between intake role and repo/source role.
  - Updated design, study-intake-planning spec, learning-data-layer spec, and tasks.
- Verification:
  - `openspec validate introduce-study-intake-router --strict`: valid.
- Next checkpoint: introduce-study-intake-router:product_deepen_round_2

## Run 2026-05-25T03:47:18Z

- Automation: add-initiate-changes
- Checkpoint: introduce-study-intake-router:product_deepen_round_2
- Result: completed
- Actions:
  - Ran second product-deepen review for `introduce-study-intake-router`.
  - Added `review-records/product-deepen-round-2.md`.
  - Confirmed Round 1 fixes are coherent: router contracts, idempotency, existing-plan target resolution, and repo/source role separation are ready for apply planning.
  - No new P0 issues found; no additional spec changes required in this round.
- Verification:
  - `openspec validate introduce-study-intake-router --strict`: valid.
  - `openspec status --change introduce-study-intake-router`: 4/4 artifacts complete.
- Next checkpoint: introduce-study-intake-router:product_deepen_round_3

## Migration 2026-05-25T03:56:29Z

- Automation: add-initiate-changes
- Migration: require-three-product-deepen-rounds
- Result: completed
- Actions:
  - Updated the control state machine from two product-deepen rounds to three.
  - Preserved completed round 1 and round 2 evidence for `introduce-study-intake-router`.
  - Moved the current checkpoint back from the former pre-apply gate to `product_deepen_round_3`.
- Next checkpoint: introduce-study-intake-router:product_deepen_round_3

## Hardening 2026-05-25T04:04:43Z

- Automation: add-initiate-changes
- Result: completed
- Actions:
  - P1-5: Added automatic stale lock recovery by quarantining stale `run.lock` directories under `recovered-locks/` with lock-recovery evidence.
  - P1-6: Updated the heartbeat interval from 5 minutes to 10 minutes.
  - P1-7: Added structured failure logging via `evidence/failures/failure-log.jsonl` and `state.json.lastFailure`.
  - P1-8: Added machine-readable checkpoint recovery evidence via `evidence/manifest.json`.
  - P1-9: Added pre-apply checkpoint commit policy and commit evidence requirements.
  - P1-10: Added cross-change contract checks before advancing between Add / Initiate child changes.
- Next checkpoint: introduce-study-intake-router:product_deepen_round_3

## Control Update 2026-05-25T04:13:17Z

- Automation: add-initiate-changes
- Update: add-scope-dependency-check
- Result: completed
- Actions:
  - Added `scope_dependency_check` after `product_deepen_round_3` and before `apply`.
  - Added per-change `scopeDependencyCheckCompleted` state flags.
  - Added scope/dependency evidence schema and manifest support.
- Next checkpoint: introduce-study-intake-router:product_deepen_round_3

## Control Update 2026-05-25T04:15:36Z

- Automation: add-initiate-changes
- Update: make-product-deepening-scope-aware
- Result: completed
- Actions:
  - Required each product-deepen round to read adjacent upstream/downstream changes.
  - Required each round record to include in-scope, out-of-scope, deferred dependency, and downstream contract decisions.
  - Reframed `scope_dependency_check` as a final audit that verifies the three rounds stayed within scope.
- Next checkpoint: introduce-study-intake-router:product_deepen_round_3

## Run 2026-05-25T04:19:16Z

- Automation: add-initiate-changes
- Checkpoint: introduce-study-intake-router:product_deepen_round_3
- Result: completed
- Actions:
  - Ran third scope-aware product-deepen review for `introduce-study-intake-router`.
  - Added `review-records/product-deepen-round-3.md`.
  - Read downstream `persist-intake-plan-drafts` and tightened router wording so this child change does not implement draft-plan persistence or draft-plan discovery.
  - Renamed the broad data-layer requirement to `Role-Based Intake Relationships` and clarified active-plan versus downstream draft-plan surfaces.
- Verification:
  - `openspec validate introduce-study-intake-router --strict`: valid.
  - `openspec status --change introduce-study-intake-router`: 4/4 artifacts complete.
- Manifest:
  - Added `introduce-study-intake-router-product-deepen-round-3`.
- Next checkpoint: introduce-study-intake-router:scope_dependency_check

## Run 2026-05-25T04:22:26Z

- Automation: add-initiate-changes
- Checkpoint: introduce-study-intake-router:scope_dependency_check
- Result: completed
- Actions:
  - Read `introduce-study-intake-router` proposal, design, specs, tasks, and all three product-deepen records.
  - Read downstream `persist-intake-plan-drafts` proposal, design, specs, and tasks.
  - Added explicit scope-decision addenda to Round 1 and Round 2 records because those reviews predated the scope-aware automation rule.
  - Wrote scope dependency evidence at `openspec/add-initiate-implementation-control/evidence/scope-dependency/introduce-study-intake-router.md`.
  - Confirmed router owns intake routing and non-plan safety, while draft persistence, compilation, scheduling, and UI remain downstream.
- Verification:
  - `openspec validate introduce-study-intake-router --strict`: valid.
  - `openspec validate persist-intake-plan-drafts --strict`: valid.
  - `openspec status --change introduce-study-intake-router`: 4/4 artifacts complete.
- Manifest:
  - Added `introduce-study-intake-router-scope-dependency-check`.
  - Updated Round 1 and Round 2 artifact hashes after scope-decision addenda.
- Next checkpoint: introduce-study-intake-router:apply

## Run 2026-05-25T04:28:10Z

- Automation: add-initiate-changes
- Checkpoint: introduce-study-intake-router:apply:planning
- Result: completed
- Actions:
  - Ran apply planning for `introduce-study-intake-router`.
  - Wrote `openspec/add-initiate-implementation-control/evidence/introduce-study-intake-router/apply-planning.md`.
  - Wrote `openspec/add-initiate-implementation-control/evidence/introduce-study-intake-router/apply-task-groups.json`.
  - Initialized `state.json.applyCursor` for this change.
  - Planned sequential apply groups: `intake-data-and-idempotency`, `source-preview-and-github-roles`, `routing-contracts-and-confirmation`.
- Decision:
  - GO. No blockers found.
- Verification:
  - `openspec validate introduce-study-intake-router --strict`: valid.
  - `openspec status --change introduce-study-intake-router --json`: ready.
  - `jq empty openspec/add-initiate-implementation-control/evidence/introduce-study-intake-router/apply-task-groups.json`: valid JSON.
- Manifest:
  - Added `introduce-study-intake-router-apply-planning`.
- Next checkpoint: introduce-study-intake-router:apply:intake-data-and-idempotency

## Control Update 2026-05-25T04:35:14Z

- Automation: add-initiate-changes
- Update: remove-standalone-pre-apply-checkpoint
- Result: completed
- Actions:
  - Removed the standalone pre-apply checkpoint from the control-file state machine.
  - Moved task-group planning into the `apply` stage preflight.
  - Renamed the generated planning evidence to `openspec/add-initiate-implementation-control/evidence/introduce-study-intake-router/apply-planning.md`.
  - Updated state, runbook, manifest, progress, schema notes, and historical planning references to point directly from `scope_dependency_check` into `apply`.
- Next checkpoint: introduce-study-intake-router:apply:intake-data-and-idempotency

## Run 2026-05-25T04:38:40Z

- Automation: add-initiate-changes
- Checkpoint: introduce-study-intake-router:apply:intake-data-and-idempotency
- Result: blocked
- Stop rule:
  - `overlapping_user_changes`
- Actions:
  - Acquired `run.lock`.
  - Ran `git status --porcelain=v1`.
  - Stopped before invoking apply or writing implementation code because `docs/agent-workflow.md` is dirty and not covered by `workspace-baseline.json`.
  - Wrote structured failure evidence at `openspec/add-initiate-implementation-control/evidence/failures/2026-05-25T043840Z-overlapping-user-changes.md`.
  - Appended the failure to `openspec/add-initiate-implementation-control/evidence/failures/failure-log.jsonl`.
- Next safe action:
  - Reconcile or intentionally baseline `docs/agent-workflow.md`, then resume from the same checkpoint.

## Control Update 2026-05-25T04:38:40Z

- Automation: add-initiate-changes
- Update: narrow-dirty-workspace-blocking-rule
- Result: completed
- Reason:
  - The previous stop was too broad. An unrelated dirty file should be protected, not treated as overlapping current apply work.
- Actions:
  - Updated `runbook.md` to classify dirty paths as `owned_current_checkpoint`, `current_apply_targets`, `protected_unrelated_dirty`, or `blocking_overlap`.
  - Added policy evidence at `openspec/add-initiate-implementation-control/evidence/policy-updates/2026-05-25T043840Z-dirty-workspace-policy.md`.
  - Reclassified `docs/agent-workflow.md` as `protected_unrelated_dirty` for this apply group.
  - Cleared `state.json.blockedReason` and restored phase to `active`.
- Next checkpoint: introduce-study-intake-router:apply:intake-data-and-idempotency

## Run 2026-05-25T04:44:45Z

- Automation: add-initiate-changes
- Checkpoint: introduce-study-intake-router:apply:intake-data-and-idempotency
- Status: in progress
- Actions:
  - Acquired `run.lock`.
  - Classified dirty workspace paths by current apply target overlap.
  - Protected unrelated dirty files without staging them.
  - Created pre-apply checkpoint commit `4a5f6d43bdcc79ca9efea62d29dca707a103bdbb`.
  - Wrote commit evidence at `openspec/add-initiate-implementation-control/evidence/commits/introduce-study-intake-router-pre-apply.md`.
  - Set `state.json.applyCursor.currentGroupId` to `intake-data-and-idempotency`.
- Protected unrelated dirty paths:
  - `docs/agent-workflow.md`
  - `openspec/changes/harden-add-initiate-automation-control/design.md`
  - `openspec/changes/harden-add-initiate-automation-control/proposal.md`
  - `openspec/changes/harden-add-initiate-automation-control/tasks.md`
  - `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
  - `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
  - `openspec/changes/redesign-study-intake-planning/split-decision.md`
  - `openspec/changes/redesign-study-intake-planning/tasks.md`
- Next action:
  - Continue the `intake-data-and-idempotency` apply group with TDD.

## Run 2026-05-25T05:03:10Z

- Automation: add-initiate-changes
- Checkpoint: introduce-study-intake-router:apply:source-preview-and-github-roles
- Result: completed
- Actions:
  - Acquired `run.lock`.
  - Classified dirty workspace paths by current apply target overlap.
  - Protected unrelated dirty files without editing or staging them.
  - Set `state.json.applyCursor.currentGroupId` to `source-preview-and-github-roles`.
  - Ran `openspec-apply-change` with subagent-driven development and per-task TDD.
  - Added Add / Initiate-safe GitHub preview helpers and models.
  - Added shallow GitHub preview for title, description, README outline, topics, coarse directory signals, fetch status, calibration, and canonical repo role.
  - Kept preview separate from legacy `fetch()` and LLM fallback paths.
  - Marked legacy fallback GitHub units as synthetic and low-calibration.
  - Added tests for success, failure, no fabricated structure, partial fetch, no LLM calls, legacy synthetic fallback, user-hint precedence, and all five canonical repo roles.
  - Fixed review issues found by spec compliance and code quality reviewers.
  - Marked tasks 2.1-2.4 and 4.4 complete.
  - Created functional commit `4bff7cf5847dd9de6d6965dc9612e04f5831b410`.
  - Wrote apply-group evidence at `openspec/add-initiate-implementation-control/evidence/introduce-study-intake-router/apply-groups/source-preview-and-github-roles.md`.
- Verification:
  - `cd assistant_backend && uv run pytest tests/test_study_intake_router.py`: 17 passed.
  - `cd assistant_backend && uv run pytest tests/test_study_plan_router.py tests/test_study_views_today.py`: 12 passed, 2 warnings.
  - `cd assistant_backend && uv run pytest tests/test_integration.py -q`: 16 passed, 2 warnings.
  - `openspec validate introduce-study-intake-router --strict`: valid.
  - `openspec instructions apply --change introduce-study-intake-router --json`: 11/21 tasks complete.
- Review:
  - Spec compliance re-review: APPROVED.
  - Code quality re-review: APPROVED.
- Manifest:
  - Added `introduce-study-intake-router-apply-group-source-preview-and-github-roles`.
- Next checkpoint: introduce-study-intake-router:apply:routing-contracts-and-confirmation

## Run 2026-05-25T04:44:45Z Apply Group Completed

- Automation: add-initiate-changes
- Checkpoint: introduce-study-intake-router:apply:intake-data-and-idempotency
- Result: completed
- Implementation commit:
  - `08104306ceb192cb60fab92e91d9f4a650d4951a`
- Actions:
  - Implemented intake item persistence separate from active tasks.
  - Added idempotent `client_request_id` intake creation.
  - Added reference/later non-plan persistence.
  - Added material-only active-plan attachment persistence.
  - Added Today-exclusion and idempotency tests.
  - Fixed code-quality P1 around broad `INSERT OR IGNORE` by using targeted conflict handling plus explicit transactions.
  - Marked tasks `1.1`, `3.1`, `3.2`, `3.3`, `4.5`, and `4.6` complete.
- Verification:
  - `cd assistant_backend && uv run pytest tests/test_study_intake_router.py`: 6 passed.
  - `cd assistant_backend && uv run pytest tests/test_study_plan_router.py tests/test_study_views_today.py`: 12 passed, 2 warnings.
  - `openspec validate introduce-study-intake-router --strict`: valid.
  - Spec compliance review: approved.
  - Code quality review: approved after P1 fix and re-review.
- Evidence:
  - `openspec/add-initiate-implementation-control/evidence/introduce-study-intake-router/apply-groups/intake-data-and-idempotency.md`
- Next checkpoint: introduce-study-intake-router:apply:source-preview-and-github-roles
