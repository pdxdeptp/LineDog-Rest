## 1. Add / Initiate Entry

- [ ] 1.1 Rename/restructure the Add tab into Add / Initiate while preserving bottom navigation behavior.
- [ ] 1.2 Build input UI for text goals, URLs, GitHub repos, existing project snippets, interview prep items, resume/project notes, and note snippets.
- [ ] 1.3 Start Add / Initiate intake sessions asynchronously and subscribe to progress.

## 2. Review States

- [ ] 2.1 Build role confirmation UI with recommended role, reason, confidence, and role-switch controls.
- [ ] 2.2 Build existing-plan attach review with `material_only`, `draft_phase`, and `scheduled_work` paths.
- [ ] 2.3 Build anchor confirmation UI for deadline, available time, target output, target depth, and accepted assumptions.
- [ ] 2.4 Build `needs_input`, `compile_failed`, `infeasible_review`, `draft_review`, `activation_failed`, cancel, and storage states.

## 3. Draft Review And Activation

- [ ] 3.1 Build summary-first draft review with role, assumptions, first-week schedule, buffer, fallback, capacity risk, and deadline risk.
- [ ] 3.2 Keep full schedule, source details, and per-task edits behind explicit expansion controls.
- [ ] 3.3 Build infeasibility option UI using canonical option ids and localized labels.
- [ ] 3.4 Ensure hard deadlines do not show `accept_late_finish`.
- [ ] 3.5 Implement activation, stale-draft, activation-failure, retry, edit, and cancel UI paths.

## 4. Noise Boundaries

- [ ] 4.1 Ensure unconfirmed drafts never appear in Today or active Calendar surfaces.
- [ ] 4.2 Ensure stored references, later resources, and material-only attachments do not create Today badges, deadline risk, smart-mode proposals, or reminders.
- [ ] 4.3 Ensure add-time processing states are not displayed as created tasks.

## 5. Tests And Manual QA

- [ ] 5.1 Add ViewModel/UI tests for role confirmation, anchor confirmation, draft review, infeasible review, activation failure, stale draft, and cancellation.
- [ ] 5.2 Add progress-event rendering tests for all Add / Initiate stages and terminal states.
- [ ] 5.3 Manually verify AgentGuide, easyagent, LeetCode cadence, agent/backend interview prep, resume rewrite, and MalDaze project work flows.
- [ ] 5.4 Manually verify non-plan storage and material-only attachment create no Today noise.
