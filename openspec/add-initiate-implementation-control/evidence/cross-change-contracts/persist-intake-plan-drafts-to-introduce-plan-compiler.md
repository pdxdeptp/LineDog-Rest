# Cross-Change Contract: persist-intake-plan-drafts -> introduce-plan-compiler

## Timestamp

2026-05-25T08:44:41Z

## From Change

`persist-intake-plan-drafts`

## To Change

`introduce-plan-compiler`

## Specs Read

From `persist-intake-plan-drafts`:

- `openspec/changes/persist-intake-plan-drafts/specs/learning-data-layer/spec.md`
- `openspec/changes/persist-intake-plan-drafts/specs/study-intake-planning/spec.md`

To `introduce-plan-compiler`:

- `openspec/changes/introduce-plan-compiler/specs/study-intake-planning/spec.md`

## Tasks Read

- `openspec/changes/persist-intake-plan-drafts/tasks.md`
- `openspec/changes/introduce-plan-compiler/tasks.md`

## Evidence Read

- `openspec/add-initiate-implementation-control/evidence/persist-intake-plan-drafts/apply-groups/draft-schema-migration-and-defaults.md`
- `openspec/add-initiate-implementation-control/evidence/persist-intake-plan-drafts/apply-groups/draft-package-versioning-and-entrypoints.md`
- `openspec/add-initiate-implementation-control/evidence/persist-intake-plan-drafts/apply-groups/activation-boundary-and-events.md`
- `openspec/add-initiate-implementation-control/evidence/persist-intake-plan-drafts/apply-groups/fallback-progress-and-final-verification.md`

## Contract Surfaces Checked

### Draft Shell And Intake Handoff

Passed.

- Plan-generating confirmations create or reuse a draft shell and return `draftId` plus `draftKind`.
- Existing-plan `draft_phase` and `scheduled_work` handoffs persist `target_plan_id` and map to `existing_plan_phase` / `existing_plan_scheduled_work`.
- Draft headers preserve intake id, title, source URL, deadline, capacity, calibration level, draft kind, target plan, latest version, and metadata.
- Non-plan and material-only paths remain outside compiler scope and do not create plan draft compilation work.

### Assumptions And Provenance

Passed.

- Draft shells and compiler package shells persist assumptions as JSON with provenance-compatible fields.
- Missing deadline or legacy facts can be represented as unknown or `needs_input` assumptions rather than being silently invented.
- Capacity defaults are normalized to 60 minutes, giving compiler envelope creation a stable default when user capacity is absent.

### Compiler Package Persistence

Passed.

- `save_draft_compiler_package_shell` can persist `anchor_review`, `compiling`, `needs_input`, `compile_failed`, `infeasible_review`, and `draft_review` package shells.
- Package rows are versioned by `draft_id` and `draft_version`.
- Package payloads include schema version, draft id, draft version, intake id, status, summary, assumptions, phases, tasks, review summary, and activation eligibility.
- Missing-input and compile-failed packages do not require phases, tasks, schedule, or risk reports.
- Meaningful edits create a new draft version, while display-only metadata can update without creating a new version.

### Activation Boundary

Passed.

- Activation requires latest activatable draft version, activation-ready task data, schedule slices, and schedule version.
- Duplicate activation is non-destructive.
- Activation writes immutable `study_project_activated` event payload with intake id, draft id, activated version, schedule version, assumptions, draft kind, target plan, resource id, and created task ids.
- Downstream compiler remains responsible for producing valid phases/tasks and activation eligibility; activation itself does not generate phases, estimates, or dates.

### Fallback Progress Boundary

Passed.

- Fallback-only completion is persisted on active tasks separately from full task completion.
- It does not mark full `completed_at`, update resource/unit completion counts, or emit full completion events.
- Full completion clears `needs_followup`; already completed tasks cannot be turned back into fallback-only follow-up state.
- This supports compiler-generated fallback modes later without requiring the compiler change to implement active task completion semantics.

### Downstream Responsibilities Preserved

Passed.

`persist-intake-plan-drafts` intentionally did not implement:

- normalized `PlanningEnvelope` construction;
- archetype and scope selection;
- source or goal synopsis generation;
- LLM phase/task generation;
- phase/task schema validation and bounded repair;
- estimate normalization and low-calibration classification;
- compiler trace records;
- deterministic date placement.

These remain in scope for `introduce-plan-compiler` and later scheduler changes.

## Handoff Risks And Deferred Contracts

- Source summaries are not precomputed by draft persistence. The compiler must build source/goal synopsis from intake raw input, source URL, metadata, source roles, and shallow source facts as part of its own task `2.1`.
- Draft assumptions are JSON-shaped and flexible. The compiler should validate/normalize them into a typed envelope instead of assuming every optional fact exists.
- Existing legacy drafts may recover unknown provenance and incomplete assumptions. The compiler must treat those as low-calibration or `needs_input`, not as confident anchors.
- Schedule slices and final dates are intentionally absent until the scheduler. Compiler package tasks may include task candidates, fallback modes, split points, and estimates, but final date placement remains downstream.
- Positive-minute request validation for fallback completion is deferred; it does not block compiler contracts because compiler fallback modes describe task alternatives, not completion API validation.

## Validation Commands And Results

- `openspec validate persist-intake-plan-drafts --strict`: valid.
- `openspec validate introduce-plan-compiler --strict`: valid.
- `openspec instructions apply --change persist-intake-plan-drafts --json`: 35/35 tasks complete, state `all_done`.
- `openspec status --change introduce-plan-compiler --json`: proposal/design/specs/tasks artifacts present.

## Result

Passed. `persist-intake-plan-drafts` can be marked completed, and automation can advance to `introduce-plan-compiler:product_deepen_round_1`.

## Next Checkpoint

`introduce-plan-compiler:product_deepen_round_1`
