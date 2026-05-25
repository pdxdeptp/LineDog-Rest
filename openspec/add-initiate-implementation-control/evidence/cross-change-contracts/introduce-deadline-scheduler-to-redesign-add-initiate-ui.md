# Cross-Change Contract: introduce-deadline-scheduler -> redesign-add-initiate-ui

- Automation: add-initiate-changes
- Checkpoint: introduce-deadline-scheduler:apply:cross-change-contract-to-redesign-add-initiate-ui
- Result: passed
- Completed at: 2026-05-25T12:38:42Z
- From change: introduce-deadline-scheduler
- To change: redesign-add-initiate-ui

## Evidence Read

Completed scheduler change:

- `openspec/changes/introduce-deadline-scheduler/proposal.md`
- `openspec/changes/introduce-deadline-scheduler/design.md`
- `openspec/changes/introduce-deadline-scheduler/specs/study-intake-planning/spec.md`
- `openspec/changes/introduce-deadline-scheduler/tasks.md`
- `openspec/add-initiate-implementation-control/evidence/introduce-deadline-scheduler/apply-task-groups.json`
- `openspec/add-initiate-implementation-control/evidence/introduce-deadline-scheduler/apply-groups/scheduler-contract-preflight-and-capacity.md`
- `openspec/add-initiate-implementation-control/evidence/introduce-deadline-scheduler/apply-groups/placement-buffer-splitting-fallback-and-risk.md`
- `openspec/add-initiate-implementation-control/evidence/introduce-deadline-scheduler/apply-groups/infeasibility-options-and-recompute-effects.md`
- `openspec/add-initiate-implementation-control/evidence/introduce-deadline-scheduler/apply-groups/scheduler-dry-runs-final-verification.md`

Downstream UI change:

- `openspec/changes/redesign-add-initiate-ui/proposal.md`
- `openspec/changes/redesign-add-initiate-ui/design.md`
- `openspec/changes/redesign-add-initiate-ui/specs/assistant-panel-ui/spec.md`
- `openspec/changes/redesign-add-initiate-ui/specs/ingestion-progress-sse/spec.md`
- `openspec/changes/redesign-add-initiate-ui/specs/study-intake-planning/spec.md`
- `openspec/changes/redesign-add-initiate-ui/tasks.md`

## Scheduler Handoff Payload

The completed scheduler provides the UI with review-only schedule output:

- pass-through non-scheduled compiler states: `needs_input` and `compile_failed`;
- review statuses: `draft_review`, `infeasible_review`, and `needs_input`;
- `ScheduledDraftReview` package identity fields such as `schema_version`, `draft_id`, and `compiler_package_version`;
- `scheduled_days` with date, raw capacity, existing load, usable capacity, planning budget, reserved buffer, planned minutes, load state, and scheduled items;
- scheduled item fields including task id, phase id, session id, parent task id, sequence index, scheduled minutes, classification, completion criteria, source refs, normal mode, and optional fallback mode;
- `unscheduled_tasks` for optional/stretch work or work that cannot fit;
- `risk_report` fields for deadline fit, essential work minutes, available execution capacity, capacity gap, optional unscheduled minutes, overloaded dates, expected late tasks, buffer reservation, buffer erosion, estimate-confidence summary, existing-load conflicts, date-window risk, and canonical option ids;
- `infeasibility_options` objects with canonical `id`, user-facing fact/facts, `effect_type`, and optional unavailable reason;
- visible assumptions and scheduler trace facts for review/debugging.

## UI-Owned Rendering And Actions

The downstream UI change owns:

- translating scheduler statuses into Add / Initiate review states;
- showing summary-first draft review with role, assumptions, deadline fit, first-week daily schedule, buffer, fallback, capacity risk, and deadline risk;
- keeping full schedule, source structure, and per-task edits behind explicit expansion controls;
- rendering infeasible review facts before choices;
- localizing canonical option ids into low-cost user choices;
- hiding `accept_late_finish` for hard deadlines;
- preserving drafts on activation failure or stale-draft rejection;
- keeping unconfirmed draft tasks out of Today and active Calendar surfaces;
- keeping stored references, later resources, and material-only attachments out of Today badges, deadline-risk prompts, smart-mode proposals, and reminders.

## Boundary Decisions

- Scheduler output is review material. It is not an activation command and must not create Today actions by itself.
- UI may display scheduled days and first-week schedule from `scheduled_days`, but activation remains a separate explicit user action against the latest draft version.
- UI must treat `fallback_mode` as review metadata for low-energy fallback, not as proof that the normal scheduled item is complete.
- UI must use scheduler `canonical_infeasibility_option_ids` and `infeasibility_options` as the source of available choices. It must not invent unavailable options.
- UI must not show `accept_late_finish` for hard deadlines even if labels or localization tables contain that option.
- UI can request option effects or recomputation, but scheduler/ compiler own the deterministic recompute result. UI does not lower depth, extend deadlines, rebalance work, or rewrite schedule math locally.
- UI can show accepted overload or accepted buffer risk as reviewable draft states, but must keep overloaded dates and buffer erosion visible.
- UI can store a draft or non-plan item for later/reference, but storage must not mark the plan active or trigger Today/Calendar/smart-mode surfaces.

## Downstream Scope Preserved

The scheduler deliberately did not implement:

- Add / Initiate tab UI;
- progress stream rendering;
- role/anchor confirmation controls;
- localized option labels;
- activation, retry, edit, cancel, or stale-draft UI paths;
- Today, Home, Calendar, or project-overview refresh behavior;
- frontend/ViewModel tests.

Those remain in scope for `redesign-add-initiate-ui`.

## Cross-Change Verification

Commands run:

- `openspec validate introduce-deadline-scheduler --strict`: valid.
- `openspec validate redesign-add-initiate-ui --strict`: valid.
- `openspec instructions apply --change introduce-deadline-scheduler --json`: 36/36 tasks complete, state `all_done`.
- `openspec status --change redesign-add-initiate-ui --json`: proposal, design, specs, and tasks all present.

## Result

Contract passed. `introduce-deadline-scheduler` can be marked completed, and automation can advance to `redesign-add-initiate-ui:product_deepen_round_1` on the next heartbeat.
