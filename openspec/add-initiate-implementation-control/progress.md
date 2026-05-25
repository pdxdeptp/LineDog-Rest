# Add / Initiate Implementation Automation Progress

## Current Status

- Phase: active
- Current change: introduce-study-intake-router
- Current step: apply
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
