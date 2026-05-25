## 1. Draft Persistence

- [ ] 1.1 Add persisted draft plan state separate from active plan/task state.
- [ ] 1.2 Link draft headers to router-created intake items and persist draft lifecycle status.
- [ ] 1.3 Persist planning assumptions: deadline, capacity, target output, target depth, buffer policy, rest days, source roles, accepted assumptions, and provenance.
- [ ] 1.4 Add draft schema version, draft version, latest-version, and snapshot semantics.
- [ ] 1.5 Preserve previous draft versions until activation or discard.
- [ ] 1.6 Persist compiler package shells for missing-input, failed, infeasible, and draft-review states without requiring complete schedules.
- [ ] 1.7 Add idempotent migration/compatibility handling for existing `study_project_drafts` and `study_project_draft_tasks` storage.
- [ ] 1.8 Add storage entry points for create/load draft shell, save compiler package shell, edit version, metadata update, fetch latest, discard, activate, and fallback progress.
- [ ] 1.9 Persist draft kind and target plan linkage for new-plan versus existing-plan phase/scheduled-work handoffs.

## 2. Activation Boundary

- [ ] 2.1 Add activation event recording linking intake item, assumptions, draft schedule version, and created active tasks.
- [ ] 2.2 Reject stale draft activation without creating active task rows.
- [ ] 2.3 Reject activation when the requested draft version lacks activation-ready task data and schedule slices.
- [ ] 2.4 Ensure activation is transactional: no partial active resource/unit/task/event rows remain after failure.
- [ ] 2.5 Ensure draft cancellation/discard does not change active Today or Calendar facts.
- [ ] 2.6 Reject invalid lifecycle transitions without changing prior state or active tasks.
- [ ] 2.7 Ensure existing-plan draft activation appends units/tasks under the target plan without creating a new top-level resource.
- [ ] 2.8 Make duplicate activation idempotency-safe without duplicate active rows.
- [ ] 2.9 Reject discard/cancel after activation without mutating active plan rows.

## 3. Fallback And Defaults

- [ ] 3.1 Persist low-energy fallback completion separately from full task completion.
- [ ] 3.2 Mark fallback-only completion as `needs_followup`.
- [ ] 3.3 Ensure fallback-only completion never sets full `completed_at` unless the full task is separately completed.
- [ ] 3.4 Normalize initialization defaults to `daily_capacity_min=60` and `reduced_capacity_min=60`.

## 4. Tests

- [ ] 4.1 Add data-layer tests for draft/active separation and Today exclusion.
- [ ] 4.2 Add tests for draft version increments after meaningful edits.
- [ ] 4.3 Add tests for non-meaningful edits that must not create new draft versions.
- [ ] 4.4 Add stale activation rejection tests.
- [ ] 4.5 Add activation event persistence and transaction rollback tests.
- [ ] 4.6 Add activation rejection tests for drafts without activation-ready schedule/task data.
- [ ] 4.7 Add invalid lifecycle transition tests.
- [ ] 4.8 Add legacy draft migration/idempotency tests.
- [ ] 4.9 Add fallback completion tests proving fallback progress does not mark the full task complete.
- [ ] 4.10 Add capacity-default regression tests proving no 300-minute fallback is used.
- [ ] 4.11 Add draft-kind/target-plan tests for new-plan versus existing-plan activation targets.
- [ ] 4.12 Add duplicate activation idempotency tests.
- [ ] 4.13 Add discard-after-activation rejection tests.
