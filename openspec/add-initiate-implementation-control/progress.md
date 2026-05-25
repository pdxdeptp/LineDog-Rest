# Add / Initiate Implementation Automation Progress

## Current Status

- Phase: active
- Current change: persist-intake-plan-drafts
- Current step: apply
- Current checkpoint: persist-intake-plan-drafts:apply:fallback-progress-and-final-verification
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

Completed apply groups for current change:

- `draft-schema-migration-and-defaults`
- `draft-package-versioning-and-entrypoints`
- `activation-boundary-and-events`

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

## Run 2026-05-25T05:56:51Z

- Automation: add-initiate-changes
- Checkpoint: introduce-study-intake-router:apply:routing-contracts-and-confirmation
- Result: completed
- Implementation commit:
  - `5955c594c1da37fc090d185d0f5e20771b2af429`
- Actions:
  - Ran `openspec-apply-change` with subagent-driven development and per-task TDD.
  - Added `/api/study-intake/route` and `/api/study-intake/confirm`.
  - Registered the study intake router under the existing API prefix.
  - Implemented deterministic first-version routing for `new_plan`, `attach_to_existing_plan`, `reference_material`, `later_resource`, and `immediate_one_off`.
  - Implemented route confidence, reason codes, one-question clarification, next-action contracts, and `createsActiveTasks=false` payloads.
  - Implemented active `study_project` target selection for existing-plan attachments.
  - Validated any new `existingPlanId` before intake creation, across attach and non-attach route outcomes.
  - Preserved idempotent stored-item replay before retry-body validation so duplicate `clientRequestId` retries stay stable.
  - Kept `canonicalRepoRole` separate from intake `recommendedRole` and filtered internal reason codes.
  - Returned handoff states for `new_plan`, `draft_phase`, and `scheduled_work` without implementing downstream draft persistence, plan compilation, scheduling, or UI.
  - Marked tasks `1.2`-`1.7`, `4.1`-`4.3`, and `4.7` complete.
  - Wrote apply-group evidence at `openspec/add-initiate-implementation-control/evidence/introduce-study-intake-router/apply-groups/routing-contracts-and-confirmation.md`.
- Verification:
  - `cd assistant_backend && uv run pytest tests/test_study_intake_router.py`: 51 passed, 2 warnings.
  - `cd assistant_backend && uv run pytest tests/test_study_plan_router.py tests/test_study_views_today.py`: 12 passed, 2 warnings.
  - `cd assistant_backend && uv run pytest tests/test_integration.py -q`: 16 passed, 2 warnings.
  - `openspec validate introduce-study-intake-router --strict`: valid.
  - `openspec instructions apply --change introduce-study-intake-router --json`: 21/21 tasks complete.
- Review:
  - Initial re-review: CHANGES_REQUIRED for non-attach stale `existingPlanId` validation.
  - Final re-review after TDD fix: APPROVED.
- Manifest:
  - Added `introduce-study-intake-router-apply-group-routing-contracts-and-confirmation`.
- Protected unrelated dirty paths:
  - `docs/agent-workflow.md`
  - `openspec/changes/harden-add-initiate-automation-control/design.md`
  - `openspec/changes/harden-add-initiate-automation-control/proposal.md`
  - `openspec/changes/harden-add-initiate-automation-control/tasks.md`
  - `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
  - `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
  - `openspec/changes/redesign-study-intake-planning/split-decision.md`
  - `openspec/changes/redesign-study-intake-planning/tasks.md`
- Next checkpoint: introduce-study-intake-router:apply:cross-change-contract-to-persist-intake-plan-drafts

## Run 2026-05-25T06:00:40Z

- Automation: add-initiate-changes
- Checkpoint: introduce-study-intake-router:apply:cross-change-contract-to-persist-intake-plan-drafts
- Result: completed
- Actions:
  - Acquired `run.lock`.
  - Read `state.json`, `runbook.md`, `progress.md`, `evidence/manifest.json`, and `workspace-baseline.json`.
  - Ran `git status --porcelain=v1`.
  - Protected unrelated dirty files without editing or staging them.
  - Read completed `introduce-study-intake-router` proposal, design, specs, tasks, and apply evidence.
  - Read downstream `persist-intake-plan-drafts` proposal, design, specs, and tasks.
  - Checked handoff payloads, persisted entities, enum/state contracts, active-task boundaries, and downstream responsibility boundaries.
  - Wrote cross-change contract evidence at `openspec/add-initiate-implementation-control/evidence/cross-change-contracts/introduce-study-intake-router-to-persist-intake-plan-drafts.md`.
  - Marked `introduce-study-intake-router` completed and advanced to `persist-intake-plan-drafts`.
- Verification:
  - `openspec validate introduce-study-intake-router --strict`: valid.
  - `openspec validate persist-intake-plan-drafts --strict`: valid.
  - `openspec instructions apply --change introduce-study-intake-router --json`: 21/21 tasks complete.
  - `openspec status --change persist-intake-plan-drafts --json`: artifacts present.
- Contract result:
  - Passed. Router provides durable intake anchors, `awaiting_anchor_review` handoff, active-task exclusion, role/attachment enums, and non-plan storage.
  - Draft persistence remains responsible for draft versions, assumptions, stale activation guards, activation events, fallback completion, and capacity-default regression.
- Protected unrelated dirty paths:
  - `docs/agent-workflow.md`
  - `openspec/changes/harden-add-initiate-automation-control/design.md`
  - `openspec/changes/harden-add-initiate-automation-control/proposal.md`
  - `openspec/changes/harden-add-initiate-automation-control/tasks.md`
  - `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
  - `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
  - `openspec/changes/redesign-study-intake-planning/split-decision.md`
  - `openspec/changes/redesign-study-intake-planning/tasks.md`
- Manifest:
  - Added `introduce-study-intake-router-to-persist-intake-plan-drafts-cross-change-contract`.
- Next checkpoint: persist-intake-plan-drafts:product_deepen_round_1

## Run 2026-05-25T06:10:40Z Product Deepen Round 1

- Automation: add-initiate-changes
- Checkpoint: persist-intake-plan-drafts:product_deepen_round_1
- Result: completed
- Actions:
  - Acquired `run.lock`.
  - Ran `git status --porcelain=v1` and protected unrelated dirty files.
  - Triggered `opsx-product-deepen`.
  - Read current `persist-intake-plan-drafts` proposal, design, specs, and tasks.
  - Read upstream `introduce-study-intake-router` and downstream `introduce-plan-compiler` artifacts.
  - Added Round 1 review evidence at `openspec/changes/persist-intake-plan-drafts/review-records/product-deepen-round-1.md`.
  - Clarified the concrete draft storage contract, intake linkage, snapshot versioning, assumption provenance, activation transaction boundary, and fallback completion boundary.
  - Updated `design.md`, `learning-data-layer/spec.md`, `study-intake-planning/spec.md`, and `tasks.md`.
- Scope decisions:
  - In scope: draft headers linked to intake items, lifecycle status, assumptions/provenance, snapshot versions, activation guard/event, fallback progress, capacity default.
  - Out of scope: intake routing, LLM task generation, deterministic scheduling, UI, smart-mode/adjustment behavior.
  - Upstream dependency: router handoff is satisfied.
  - Downstream contracts preserved: compiler owns phase/task generation and estimate normalization; scheduler owns final date placement.
- Verification:
  - `openspec validate persist-intake-plan-drafts --strict`: valid.
- Manifest:
  - Added `persist-intake-plan-drafts-product-deepen-round-1`.
- Next checkpoint: persist-intake-plan-drafts:product_deepen_round_2

## Run 2026-05-25T06:10:40Z Product Deepen Round 2

- Automation: add-initiate-changes
- Checkpoint: persist-intake-plan-drafts:product_deepen_round_2
- Result: completed
- Actions:
  - Triggered `opsx-product-deepen`.
  - Re-read current `persist-intake-plan-drafts` design and existing backend draft schema.
  - Read upstream router and downstream compiler boundaries.
  - Added Round 2 review evidence at `openspec/changes/persist-intake-plan-drafts/review-records/product-deepen-round-2.md`.
  - Clarified idempotent migration/compatibility for existing `study_project_drafts` and `study_project_draft_tasks`.
  - Added required data-layer entry points for draft shell creation, package saving, versioned edits, metadata updates, latest fetch, discard, activation, and fallback progress.
  - Added allowed lifecycle transitions and invalid-transition failure behavior.
  - Updated specs and tasks for migration, lifecycle transition, and storage-helper test coverage.
- Scope decisions:
  - In scope: migration/compatibility, helper entry points, allowed transitions, invalid-transition rejection.
  - Out of scope: compiler generation, scheduler placement, UI, router changes.
  - Upstream dependency: none blocking.
  - Downstream contracts preserved: compiler writes packages through helpers; scheduler owns final placement.
- Verification:
  - `openspec validate persist-intake-plan-drafts --strict`: valid.
- Manifest:
  - Added `persist-intake-plan-drafts-product-deepen-round-2`.
- Next checkpoint: persist-intake-plan-drafts:product_deepen_round_3

## Run 2026-05-25T06:10:40Z Product Deepen Round 3

- Automation: add-initiate-changes
- Checkpoint: persist-intake-plan-drafts:product_deepen_round_3
- Result: completed
- Actions:
  - Triggered `opsx-product-deepen`.
  - Re-read current `persist-intake-plan-drafts` artifacts plus upstream router and downstream compiler/scheduler boundaries.
  - Added Round 3 review evidence at `openspec/changes/persist-intake-plan-drafts/review-records/product-deepen-round-3.md`.
  - Clarified `draft_kind` and `target_plan_id` for new-plan versus existing-plan phase/scheduled-work handoffs.
  - Clarified existing-plan activation behavior, duplicate activation idempotency, and discard-after-activation rejection.
  - Updated design, data-layer spec, and tasks for target-plan, duplicate-activation, and post-activation discard coverage.
- Scope decisions:
  - In scope: draft kind/target plan persistence, existing-plan activation target semantics, duplicate activation safety, post-activation discard rejection.
  - Out of scope: UI target picking, router classification changes, compiler generation, scheduler placement, active-plan adjustment.
  - Upstream dependency: router handoff facts are sufficient.
  - Downstream contracts preserved: compiler/scheduler consume stable draft identity and schedule-ready data without owning active-resource semantics.
- Verification:
  - `openspec validate persist-intake-plan-drafts --strict`: valid.
- Manifest:
  - Added `persist-intake-plan-drafts-product-deepen-round-3`.
- Next checkpoint: persist-intake-plan-drafts:scope_dependency_check

## Run 2026-05-25T06:24:10Z

- Automation: add-initiate-changes
- Checkpoint: persist-intake-plan-drafts:scope_dependency_check
- Result: completed
- Actions:
  - Acquired `run.lock`.
  - Read `state.json`, `runbook.md`, `progress.md`, `evidence/manifest.json`, and `workspace-baseline.json`.
  - Ran `git status --porcelain=v1` and protected unrelated dirty files.
  - Triggered `opsx-scope-decision`.
  - Read current `persist-intake-plan-drafts` proposal, design, specs, tasks, and all three product-deepen records.
  - Read upstream `introduce-study-intake-router` artifacts and the router-to-draft cross-change contract evidence.
  - Read downstream `introduce-plan-compiler` artifacts and scheduler boundary notes.
  - Wrote scope dependency evidence at `openspec/add-initiate-implementation-control/evidence/scope-dependency/persist-intake-plan-drafts.md`.
- Scope result:
  - Passed. The change remains a coherent data-layer draft persistence boundary.
  - In scope: draft state, versioning, assumptions/provenance, migration, entry points, activation safety, fallback progress, and 60-minute capacity default.
  - Out of scope: intake routing, compiler generation, deterministic scheduling, UI, and active-plan adjustment.
  - Upstream contracts: router handoff facts are satisfied.
  - Downstream contracts: compiler and scheduler dependencies are named without being prematurely implemented.
- Verification:
  - `openspec validate persist-intake-plan-drafts --strict`: valid.
  - `openspec validate introduce-plan-compiler --strict`: valid.
  - `openspec status --change persist-intake-plan-drafts`: 4/4 artifacts complete.
- Manifest:
  - Added `persist-intake-plan-drafts-scope-dependency-check`.
- Next checkpoint: persist-intake-plan-drafts:apply

## Run 2026-05-25T06:34:10Z Apply Planning

- Automation: add-initiate-changes
- Checkpoint: persist-intake-plan-drafts:apply:planning
- Result: completed
- Actions:
  - Acquired `run.lock`.
  - Read `state.json`, `runbook.md`, `progress.md`, `evidence/manifest.json`, and `workspace-baseline.json`.
  - Ran `git status --porcelain=v1` and protected unrelated dirty files.
  - Read apply schemas and the previous router apply-planning evidence.
  - Read `persist-intake-plan-drafts` proposal, design, specs, and tasks.
  - Ran `openspec status --change persist-intake-plan-drafts --json`.
  - Ran `openspec instructions apply --change persist-intake-plan-drafts --json`; 35 tasks pending.
  - Wrote apply planning evidence at `openspec/add-initiate-implementation-control/evidence/persist-intake-plan-drafts/apply-planning.md`.
  - Wrote task-group recovery source at `openspec/add-initiate-implementation-control/evidence/persist-intake-plan-drafts/apply-task-groups.json`.
  - Initialized `state.json.applyCursor` for this change.
  - Planned sequential apply groups: `draft-schema-migration-and-defaults`, `draft-package-versioning-and-entrypoints`, `activation-boundary-and-events`, and `fallback-progress-and-final-verification`.
- Decision:
  - GO. No blockers found.
- Protected unrelated dirty paths:
  - `docs/agent-workflow.md`
  - `openspec/changes/harden-add-initiate-automation-control/design.md`
  - `openspec/changes/harden-add-initiate-automation-control/proposal.md`
  - `openspec/changes/harden-add-initiate-automation-control/tasks.md`
  - `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
  - `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
  - `openspec/changes/redesign-study-intake-planning/split-decision.md`
  - `openspec/changes/redesign-study-intake-planning/tasks.md`
- Verification:
  - `jq empty openspec/add-initiate-implementation-control/evidence/persist-intake-plan-drafts/apply-task-groups.json`: valid.
  - `openspec validate persist-intake-plan-drafts --strict`: valid.
- Manifest:
  - Added `persist-intake-plan-drafts-apply-planning`.
- Pre-apply checkpoint:
  - Created safe checkpoint commit `c33c1653476c50e0a10766fbc37873bc940635a4`.
  - Wrote commit evidence at `openspec/add-initiate-implementation-control/evidence/commits/persist-intake-plan-drafts-pre-apply.md`.
- Next checkpoint: persist-intake-plan-drafts:apply:draft-schema-migration-and-defaults

## Run 2026-05-25T06:44:10Z Apply Group draft-schema-migration-and-defaults

- Automation: add-initiate-changes
- Checkpoint: persist-intake-plan-drafts:apply:draft-schema-migration-and-defaults
- Result: completed
- Actions:
  - Acquired `run.lock`.
  - Read `state.json`, `runbook.md`, `progress.md`, `evidence/manifest.json`, `workspace-baseline.json`, apply planning, and current task-group evidence source.
  - Ran `git status --porcelain=v1` and protected unrelated dirty files.
  - Triggered `openspec-apply-change`, `superpowers:subagent-driven-development`, and `superpowers:test-driven-development`.
  - Delegated implementation to a worker subagent with a bounded write set for this apply group.
  - Added RED tests for intake-linked draft shells, legacy draft migration/idempotency, router default draft columns, and both 60-minute capacity defaults.
  - Implemented additive draft header/task schema columns, idempotent startup migration, intake-linked draft shell reuse, and `reduced_capacity_min` legacy migration.
  - Wrote apply group evidence at `openspec/add-initiate-implementation-control/evidence/persist-intake-plan-drafts/apply-groups/draft-schema-migration-and-defaults.md`.
  - Marked OpenSpec tasks `1.1`, `1.2`, `1.7`, `3.4`, `4.1`, `4.8`, and `4.10` complete.
  - Created implementation commit `d521f5440a84274e3ef90dfa4e0e38b708be2e9f`.
- Verification:
  - `cd assistant_backend && uv run pytest tests/test_study_plan_lifecycle.py -k 'draft or migration or active_daily_tasks'`: 7 passed.
  - `cd assistant_backend && uv run pytest tests/test_integration.py -k 'daily_capacity_min'`: 1 passed.
  - `cd assistant_backend && uv run pytest tests/test_study_plan_router.py -k 'start_endpoint or clarification_without_active_resources'`: 1 passed, 2 third-party warnings.
  - `openspec validate persist-intake-plan-drafts --strict`: valid.
  - `openspec instructions apply --change persist-intake-plan-drafts --json`: 7/35 tasks complete.
  - `git diff --check`: passed for the apply-group file set.
- Protected unrelated dirty paths:
  - `docs/agent-workflow.md`
  - `openspec/changes/harden-add-initiate-automation-control/design.md`
  - `openspec/changes/harden-add-initiate-automation-control/proposal.md`
  - `openspec/changes/harden-add-initiate-automation-control/tasks.md`
  - `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
  - `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
  - `openspec/changes/redesign-study-intake-planning/split-decision.md`
  - `openspec/changes/redesign-study-intake-planning/tasks.md`
- Manifest:
  - Added `persist-intake-plan-drafts-apply-group-draft-schema-migration-and-defaults`.
- Next checkpoint: persist-intake-plan-drafts:apply:draft-package-versioning-and-entrypoints

## Run 2026-05-25T06:59:40Z Apply Group draft-package-versioning-and-entrypoints

- Automation: add-initiate-changes
- Checkpoint: persist-intake-plan-drafts:apply:draft-package-versioning-and-entrypoints
- Result: completed
- Actions:
  - Acquired `run.lock`.
  - Read `state.json`, `runbook.md`, `progress.md`, `evidence/manifest.json`, `workspace-baseline.json`, apply planning, and current task-group source.
  - Ran `git status --porcelain=v1` and protected unrelated dirty files.
  - Triggered `openspec-apply-change`, `superpowers:subagent-driven-development`, `superpowers:test-driven-development`, and `superpowers:receiving-code-review`.
  - Delegated TDD implementation to a worker subagent with a bounded write set.
  - Added package/versioning storage helpers, draft version snapshot storage, intake handoff draft shell creation, and package status/closed-state guards.
  - Ran spec compliance and code quality reviews; both initially required changes.
  - Fixed review findings for task `1.8` scope, legacy package recovery, transaction cleanup, stale latest-version reads, target-plan idempotency, unknown deadline provenance, package status validation, and closed-draft reopening.
  - Wrote apply group evidence at `openspec/add-initiate-implementation-control/evidence/persist-intake-plan-drafts/apply-groups/draft-package-versioning-and-entrypoints.md`.
  - Marked OpenSpec tasks `1.3`, `1.4`, `1.5`, `1.6`, `1.8`, `1.9`, `4.2`, `4.3`, and `4.11` complete.
  - Created implementation commit `dd01c193c6690dd70b47f85df332100fac825425`.
- Verification:
  - `cd assistant_backend && uv run pytest tests/test_study_plan_lifecycle.py -k 'version or package or assumptions or target_plan or draft_kind'`: 13 passed.
  - `cd assistant_backend && uv run pytest tests/test_study_intake_router.py -k 'handoff or scheduled_work or draft_phase'`: 8 passed.
  - `cd assistant_backend && uv run pytest tests/test_study_plan_lifecycle.py tests/test_study_intake_router.py`: 83 passed, 2 third-party warnings.
  - `cd assistant_backend && uv run pytest tests/test_study_plan_router.py -k 'start_endpoint or clarification_without_active_resources'`: 1 passed, 2 third-party warnings.
  - `openspec validate persist-intake-plan-drafts --strict`: valid.
  - `openspec instructions apply --change persist-intake-plan-drafts --json`: 16/35 tasks complete.
  - `git diff --check`: passed for the apply-group file set.
- Review:
  - Final spec/code review verdict: approved.
  - P0/P1 findings remaining: none.
  - P2 note: task `4.11` wording still says activation targets, but current task `1.8` explicitly leaves activation behavior to later 2.* tasks; current group covers storage linkage only.
- Protected unrelated dirty paths:
  - `docs/agent-workflow.md`
  - `openspec/changes/harden-add-initiate-automation-control/design.md`
  - `openspec/changes/harden-add-initiate-automation-control/proposal.md`
  - `openspec/changes/harden-add-initiate-automation-control/tasks.md`
  - `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
  - `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
  - `openspec/changes/redesign-study-intake-planning/split-decision.md`
  - `openspec/changes/redesign-study-intake-planning/tasks.md`
- Manifest:
  - Added `persist-intake-plan-drafts-apply-group-draft-package-versioning-and-entrypoints`.
- Next checkpoint: persist-intake-plan-drafts:apply:activation-boundary-and-events

## Run 2026-05-25T07:46:40Z Apply Group activation-boundary-and-events

- Automation: add-initiate-changes
- Checkpoint: persist-intake-plan-drafts:apply:activation-boundary-and-events
- Result: completed
- Actions:
  - Acquired `run.lock`.
  - Read `state.json`, `runbook.md`, `progress.md`, `evidence/manifest.json`, `workspace-baseline.json`, and the current apply task group.
  - Ran `git status --porcelain=v1` and protected unrelated dirty files.
  - Triggered `openspec-apply-change`, `superpowers:subagent-driven-development`, `superpowers:test-driven-development`, `superpowers:receiving-code-review`, and `superpowers:verification-before-completion`.
  - Delegated TDD implementation to a worker subagent with a bounded write set.
  - Implemented transactional draft activation, activation event payloads, stale/latest-activatable version guards, activation-ready task/schedule guards, existing-plan activation, duplicate activation safety, post-activation discard rejection, and package lifecycle transition validation.
  - Ran spec compliance review three times; fixed router stale selection, required schedule version, latest activatable semantics, and package transition validation before final approval.
  - Ran code quality review; no P0/P1 findings remained.
  - Wrote apply group evidence at `openspec/add-initiate-implementation-control/evidence/persist-intake-plan-drafts/apply-groups/activation-boundary-and-events.md`.
  - Marked OpenSpec tasks `2.1`-`2.9`, `4.4`-`4.7`, `4.12`, and `4.13` complete.
  - Created implementation commit `ab1587b60b1fed5c13c9185f7473ebdb52a371eb`.
- Verification:
  - `cd assistant_backend && uv run pytest tests/test_study_plan_lifecycle.py -k 'confirm or activation or stale or transaction or duplicate or discard or transition or target_plan or package'`: 38 passed, 4 deselected.
  - `cd assistant_backend && uv run pytest tests/test_study_plan_router.py -k 'confirm_endpoint or cancel_endpoint or stale'`: 7 passed, 5 deselected, 2 third-party warnings.
  - `cd assistant_backend && uv run pytest tests/test_study_views_today.py`: 4 passed, 2 third-party warnings.
  - `cd assistant_backend && uv run pytest tests/test_study_plan_lifecycle.py tests/test_study_plan_router.py tests/test_study_views_today.py`: 58 passed, 2 third-party warnings.
  - `openspec validate persist-intake-plan-drafts --strict`: valid.
  - `openspec instructions apply --change persist-intake-plan-drafts --json`: 31/35 tasks complete.
  - `git diff --check`: passed for implementation and task files.
- Review:
  - Final spec compliance verdict: approved; no remaining P0/P1/P2 findings.
  - Final code quality verdict: approved; no remaining P0/P1 findings.
  - P2 notes retained in evidence for future hardening: malformed package JSON error semantics, historical `total_units` mismatch, package activation event duration estimates, and `cancelled`/`discarded` compatibility.
- Protected unrelated dirty paths:
  - `docs/agent-workflow.md`
  - `openspec/changes/harden-add-initiate-automation-control/design.md`
  - `openspec/changes/harden-add-initiate-automation-control/proposal.md`
  - `openspec/changes/harden-add-initiate-automation-control/tasks.md`
  - `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
  - `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
  - `openspec/changes/redesign-study-intake-planning/split-decision.md`
  - `openspec/changes/redesign-study-intake-planning/tasks.md`
- Manifest:
  - Added `persist-intake-plan-drafts-apply-group-activation-boundary-and-events`.
- Next checkpoint: persist-intake-plan-drafts:apply:fallback-progress-and-final-verification
