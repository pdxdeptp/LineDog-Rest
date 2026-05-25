## 0. Add / Initiate Orchestration Contract

- [ ] 0.1 Add backend/API-client models for Add / Initiate session identity, route review, role confirmation, anchor confirmation, review states, option effects, activation result, and terminal storage states.
- [ ] 0.2 Add or wire the thin orchestration adapter that wraps completed router, draft persistence, compiler, scheduler, and activation helpers without adding new routing, compiler, scheduler, or activation logic.
- [ ] 0.3 Add progress-event/session tests proving stage names, session identity, draft id/version, stale-event rejection, and no active tasks before activation.
- [ ] 0.4 Preserve the legacy URL ingestion API as a compatibility path while ensuring Add / Initiate does not call it as the primary implementation path.

## 1. Add / Initiate Entry

- [ ] 1.1 Rename/restructure the Add tab into Add / Initiate while preserving bottom navigation behavior.
- [ ] 1.2 Build input UI for text goals, URLs, GitHub repos, existing project snippets, interview prep items, resume/project notes, and note snippets.
- [ ] 1.3 Start Add / Initiate sessions through the orchestration adapter and subscribe to or derive the shared progress-stage contract.

## 2. Review States

- [ ] 2.1 Build role confirmation UI with recommended role, reason, confidence, and role-switch controls.
- [ ] 2.2 Build existing-plan attach review with `material_only`, `draft_phase`, and `scheduled_work` paths.
- [ ] 2.3 Build anchor confirmation UI for deadline, available time, target output, target depth, and accepted assumptions.
- [ ] 2.4 Build a single Add / Initiate ViewModel state machine covering `idle_input`, `routing_progress`, `role_review`, `non_plan_terminal`, `anchor_review`, `planning_progress`, `needs_input`, `compile_failed`, `infeasible_review`, `draft_review`, `option_effect_progress`, `activation_progress`, `activation_failed`, `activated`, and `cancelled`.
- [ ] 2.5 Build `needs_input`, `compile_failed`, `infeasible_review`, `draft_review`, `activation_failed`, cancel, and storage states with one primary action per state.
- [ ] 2.6 Ensure stale session, stale draft-version, retry, option-effect, and activation responses cannot overwrite newer Add / Initiate state.

## 3. Draft Review And Activation

- [ ] 3.1 Build summary-first draft review with role, assumptions, first-week schedule, buffer, fallback, capacity risk, and deadline risk.
- [ ] 3.2 Render first-week summary from the first seven calendar days or shorter available window, including planned minutes, load state, fallback cues, buffer, and risk facts without showing every scheduled item by default.
- [ ] 3.3 Keep full schedule, source details, and per-task edits behind explicit expansion controls.
- [ ] 3.4 Ensure fallback mode is rendered as alternate execution metadata, not a separate Today task or normal completion.
- [ ] 3.5 Build infeasibility option UI using canonical option ids and localized labels.
- [ ] 3.6 Ensure hard deadlines do not show `accept_late_finish`.
- [ ] 3.7 Implement option-effect progress and result handling for new review packages, storage states, compiler-recompute handoffs, and focused needs-input states.
- [ ] 3.8 Implement activation, stale-draft, activation-failure, retry, edit, and cancel UI paths.

## 4. Noise Boundaries

- [ ] 4.1 Ensure unconfirmed drafts never appear in Today or active Calendar surfaces.
- [ ] 4.2 Ensure stored references, later resources, and material-only attachments do not create Today badges, deadline risk, smart-mode proposals, or reminders.
- [ ] 4.3 Ensure add-time processing states are not displayed as created tasks.
- [ ] 4.4 Ensure only activation success refreshes Home, Today, project overview, active Calendar facts, and smart-mode proposal context as active work.
- [ ] 4.5 Ensure storage, material attachment, cancellation, activation failure, and option-effect states preserve active-surface silence.

## 5. Tests And Manual QA

- [ ] 5.1 Add ViewModel/UI tests for role confirmation, anchor confirmation, needs-input recovery, compile-failed recovery, draft review, infeasible review, option effects, activation failure, stale draft/version, stale response rejection, and cancellation.
- [ ] 5.2 Add progress-event rendering tests for all Add / Initiate stages and terminal states.
- [ ] 5.3 Add or update fixtures/manual QA for AgentGuide, easyagent repo rebuild, LeetCode cadence, agent/backend interview prep, resume/project rewrite, and MalDaze existing-project material flows.
- [ ] 5.4 Manually verify non-plan storage, reference/later items, material-only attachment, cancellation, and activation failure create no Today, Calendar, deadline-risk, smart-mode, or reminder noise.
- [ ] 5.5 Manually verify the old URL-only ingestion path remains compatible but is not used as the primary Add / Initiate path.
