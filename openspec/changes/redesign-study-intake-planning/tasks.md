## 1. Data Model And Persistence

- [ ] 1.1 Add persisted intake item state with raw input, source type, recommended role, confirmed role, calibration level, and lifecycle state.
- [ ] 1.2 Add role-based relationships for plan, phase, executable task, supporting material, reference material, and later resource, with existing-plan support represented as `attach_to_existing_plan` plus attachment mode.
- [ ] 1.3 Add draft-plan persistence that stores anchors, assumptions, source roles, buffer policy, low-energy fallback metadata, and draft schedule separately from active tasks.
- [ ] 1.4 Add activation event recording that links the intake item, assumptions, draft schedule version, and created active tasks.
- [ ] 1.5 Add draft schema version and draft version semantics, including stale activation rejection.
- [ ] 1.6 Add fallback completion persistence separate from full task completion.
- [ ] 1.7 Normalize learning capacity defaults so draft scheduling, preferences, material ingestion fallback, and data-layer initialization use 60 minutes when no user value exists.

## 2. Intake Routing And Material Preview

- [ ] 2.1 Implement intake routing for goal text, URL, GitHub repo, existing project, interview prep item, resume material, and note snippet inputs.
- [ ] 2.2 Implement one-question clarification when the router cannot distinguish planning, attaching, storing, or one-off action.
- [ ] 2.3 Refactor URL/material preview so parsing returns role signals and structure without writing active resources or tasks.
- [ ] 2.4 Add shallow GitHub preview with repo title, description, README outline, topics, and fetch-failure fallback.
- [ ] 2.5 Remove intake-preview reliance on fabricated GitHub units; unknown repo structure must remain unknown or low-calibration, while legacy placeholder units are labeled synthetic.
- [ ] 2.6 Add Add / Initiate progress events for routing, source preview, phase/task generation, validation, scheduling, needs-input, compile-failed, infeasible-review, and draft-ready states.

## 3. Plan Draft Compiler

- [ ] 3.1 Implement normalized planning envelope creation from confirmed role, anchors, source summaries, existing load, rest days, and provenance.
- [ ] 3.1a Include source roles and canonical repo roles in the planning envelope.
- [ ] 3.2 Implement archetype selection for finite learning project, recurring practice, topic review, rebuild/clone, project packaging, and existing-project phase.
- [ ] 3.2a Implement archetype selection matrix, confidence, secondary modifiers, included/excluded material scope boundary, and one-question ambiguity handling.
- [ ] 3.2b Implement target-depth semantics so skim, can-use, project-level, interview-ready, and source-understanding depths change completion evidence and task families.
- [ ] 3.3 Implement phase and milestone generation with observable completion evidence and essential/optional status.
- [ ] 3.4 Implement executable task candidate generation with action title, concrete output, completion criteria, estimate, dependency, phase link, normal mode, fallback mode, confidence, and assumptions.
- [ ] 3.5 Implement deterministic task quality gates for vague tasks, oversized tasks, tiny tasks, missing completion criteria, and bounded repair failure, distinguishing blocking failures from warning-level low calibration.
- [ ] 3.6 Implement estimate normalization from source facts, archetype defaults, LLM suggestions, confidence, clamps, and low-calibration flags.
- [ ] 3.6a Implement estimate source priority, v1 default estimate table, outlier replacement, confidence assignment, and low-calibration threshold for rough essential work.
- [ ] 3.7 Implement deterministic draft scheduler that assigns dates from validated tasks using capacity, existing load, rest days, unavailable dates, buffer policy, deadline, and deadline type.
- [ ] 3.8 Implement buffer reservation, buffer-erosion detection, capacity-gap reporting, expected-late reporting, and overload reporting.
- [ ] 3.9 Implement canonical infeasibility option generation for reduce scope, lower target depth, extend deadline, increase capacity, accept crunch, accept buffer risk, accept overload, accept late finish, accept rough draft, answer one question, edit estimates, or store for later.
- [ ] 3.10 Attach low-energy fallback and optional stretch metadata to scheduled draft tasks without creating separate noisy todos.
- [ ] 3.11 Implement draft edit classification so schedule-only edits rerun only the scheduler while scope/depth/archetype edits regenerate tasks.
- [ ] 3.12 Implement deterministic effects for infeasibility options and write new draft versions for each chosen option.
- [ ] 3.12a Implement auditable reduce-scope and lower-depth rules, including essential/optional/stretch classification, before/after minutes, lost evidence, and unavailable reduction states.
- [ ] 3.13 Implement existing-plan attachment modes: material-only, draft phase, and scheduled work, with supporting-material UI mapped to `material_only`.
- [ ] 3.14 Implement low-daily-capacity session splitting so over-budget tasks become dated continuation sessions only at approved split points or explicit multi-session boundaries.
- [ ] 3.15 Implement compiler trace records for envelope normalization, LLM schema validation, bounded repair attempts, estimate normalization, scheduling decisions, risk facts, and infeasibility option generation.
- [ ] 3.16 Implement status-specific `PlanDraftPackage` fields so `needs_input` and `compile_failed` do not require complete phases, tasks, schedules, or risk reports.
- [ ] 3.17 Ensure hard-deadline infeasibility never exposes `accept_late_finish`.

## 4. Activation And Role-Specific Outcomes

- [ ] 4.1 Activate reviewed drafts into confirmed active plans and active scheduled tasks only after explicit user confirmation.
- [ ] 4.2 Store supporting materials against existing plans without adding scheduled tasks by default.
- [ ] 4.3 Store reference and later resources outside active scheduling, deadline risk, Today, and Calendar facts.
- [ ] 4.4 Preserve existing v2 Today, Calendar, adjustment, and smart-mode behavior for activated plans.

## 5. Add / Initiate UI

- [ ] 5.1 Rename and restructure the Add tab into Add / Initiate while preserving bottom navigation behavior.
- [ ] 5.2 Build input UI for text goals, URLs, GitHub repos, existing project snippets, interview prep items, resume material, and note snippets.
- [ ] 5.3 Build role confirmation UI with recommended role, reason, confidence, and role-switch controls.
- [ ] 5.4 Build anchor confirmation UI for deadline, available time, target output, target depth, and accepted assumptions.
- [ ] 5.5 Build draft review UI showing phases, first-week daily schedule, full schedule entry, buffer, low-energy fallback, and risk/capacity facts.
- [ ] 5.6 Ensure unconfirmed drafts and non-plan roles never appear in Today or trigger add-time recommendations.
- [ ] 5.7 Build Add / Initiate state-machine UI for routing, role review, anchor review, compiling, needs input, compile failed, infeasible review, draft review, activating, activation failed, and cancellation/storage.
- [ ] 5.8 Build stage-level progress feedback for analysis, routing, source preview, phase generation, task generation, validation, scheduling, and review preparation.
- [ ] 5.9 Build stale-draft and activation-failure recovery states.
- [ ] 5.10 Build existing-plan `attach_review` exits so material-only attachments store without compile while draft phase and scheduled-work attachments continue to anchor review.

## 6. Tests And Verification

- [ ] 6.1 Add backend tests for role routing, non-plan storage, draft/active state separation, and role-based Today exclusion.
- [ ] 6.2 Add backend tests for GitHub role handling, preview failure fallback, and material preview without active writes.
- [ ] 6.3 Add backend tests for deadline-driven scheduling, buffer reservation, capacity gap, overload, and low-energy fallback metadata.
- [ ] 6.4 Add Swift/ViewModel tests for role confirmation, anchor confirmation, draft activation, cancellation, and Add / Initiate navigation.
- [ ] 6.5 Manually verify the UI with examples from the planning context: AgentGuide, easyagent, LeetCode cadence, agent/backend interview prep, resume rewrite, and MalDaze project work.
- [ ] 6.6 Add compiler contract tests for LLM phase/task schema validation, forbidden date fields, and bounded repair failure.
- [ ] 6.7 Add compiler dry-run tests for AgentGuide, easyagent, LeetCode, agent/backend interview prep, and resume/project packaging examples.
- [ ] 6.7a Add archetype-selection tests for mixed GitHub cases such as easyagent as rebuild target versus interview-learning source.
- [ ] 6.7b Add target-depth tests proving the same source produces different obligations for skim, project-level, interview-ready, and source-understanding drafts.
- [ ] 6.7c Add end-to-end dry-run tests with deadline, capacity, normalized minutes, buffer, schedule, and infeasibility option math for one feasible and one infeasible real-context case.
- [ ] 6.8 Add scheduler tests for usable capacity, existing active load, load shapes, low-daily-capacity continuation sessions, essential-vs-optional placement, and infeasibility fact-to-option mapping.
- [ ] 6.8a Add estimate-normalization tests for user estimates, concrete source facts, archetype defaults, LLM outliers, oversized split requirements, and low-calibration drafts.
- [ ] 6.9 Add lifecycle state-machine tests for cancel, retry, needs-input, compile failure, infeasible review, activation failure, and stale draft activation.
- [ ] 6.10 Add draft editing/recompile tests for schedule-only edits, scope edits, target-depth edits, canonical infeasibility option ids, and infeasibility option effects.
- [ ] 6.10a Add reduce-scope/lower-depth tests proving essential evidence is preserved, optional/stretch work is removed first, and impossible reductions are not offered.
- [ ] 6.11 Add fallback completion tests proving fallback progress does not mark the full task complete.
- [ ] 6.12 Add compiler trace tests proving rejected/low-calibration drafts expose validation and scheduling reasons without leaking sensitive raw content.
- [ ] 6.13 Add regression tests for GitHub preview with no README/directory structure proving intake preview does not fabricate units or source facts.
- [ ] 6.14 Add progress-event tests for Add / Initiate stages and terminal states separate from the legacy URL ingestion SSE sequence.
- [ ] 6.15 Add tests for consistent 60-minute capacity fallback and hard-deadline exclusion of `accept_late_finish`.

## 7. Scope Split Readiness

- [x] 7.1 Run scope decision and split this mother design into intake-router, draft-persistence, plan-compiler, deadline-scheduler, and add-initiate-ui implementation changes.
- [x] 7.2 For each split change, copy only the relevant requirements and keep implementation tasks small enough for TDD/subagent dispatch.
- [x] 7.3 Preserve the documented split dependency order: router, draft persistence, plan compiler, deadline scheduler, then Add / Initiate UI.
- [ ] 7.4 Re-run pre-apply planning on each split change before implementation.
