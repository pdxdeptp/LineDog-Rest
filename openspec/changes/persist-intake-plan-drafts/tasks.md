## 1. Draft Persistence

- [ ] 1.1 Add persisted draft plan state separate from active plan/task state.
- [ ] 1.2 Persist planning assumptions: deadline, capacity, target output, target depth, buffer policy, rest days, source roles, accepted assumptions, and provenance.
- [ ] 1.3 Add draft schema version and draft version semantics.
- [ ] 1.4 Preserve previous draft versions until activation or discard.

## 2. Activation Boundary

- [ ] 2.1 Add activation event recording linking intake item, assumptions, draft schedule version, and created active tasks.
- [ ] 2.2 Reject stale draft activation without creating active task rows.
- [ ] 2.3 Ensure draft cancellation/discard does not change active Today or Calendar facts.

## 3. Fallback And Defaults

- [ ] 3.1 Persist low-energy fallback completion separately from full task completion.
- [ ] 3.2 Mark fallback-only completion as `needs_followup`.
- [ ] 3.3 Normalize initialization defaults to `daily_capacity_min=60` and `reduced_capacity_min=60`.

## 4. Tests

- [ ] 4.1 Add data-layer tests for draft/active separation and Today exclusion.
- [ ] 4.2 Add tests for draft version increments after meaningful edits.
- [ ] 4.3 Add stale activation rejection tests.
- [ ] 4.4 Add activation event persistence tests.
- [ ] 4.5 Add fallback completion tests proving fallback progress does not mark the full task complete.
- [ ] 4.6 Add capacity-default regression tests proving no 300-minute fallback is used.
