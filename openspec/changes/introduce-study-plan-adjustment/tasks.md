## 1. Proposal Readiness

- [x] 1.1 Record ITEM-003 v1/current-state observation and gap analysis under Flow B evidence.
- [x] 1.2 Confirm `introduce-study-plan-adjustment` proposal, design, specs, and tasks pass `openspec validate introduce-study-plan-adjustment --strict`.
- [x] 1.3 Run readiness review for scope, dependencies, split risk, and consistency with Flow A decisions D20-D28.

## 2. Backend Schema And Fact Helpers

- [x] 2.1 Write failing backend tests for schema/init support of task auto-roll metadata and rest-day settings.
- [x] 2.2 Implement minimal schema/init support for auto-roll metadata and rest-day settings.
- [x] 2.3 Write failing backend tests for expected-late project status and over-capacity facts after adjustment mutations.
- [x] 2.4 Implement red-state helper queries without mutating task dates.

## 3. Rollover

- [x] 3.1 Write failing backend tests for idempotent unfinished-task rollover into the current local day without same-project cascade.
- [x] 3.2 Implement rollover service and route, including auto-roll counters and event persistence.
- [x] 3.3 Write failing backend tests that Today exposes rolled-day count and threshold badge facts.
- [x] 3.4 Implement rolled-day payloads for Today view and completion reset behavior.

## 4. Manual Move And Deadline Editing

- [x] 4.1 Write failing backend tests for active unfinished task date move with same-project later-task cascade and no cross-project movement.
- [x] 4.2 Implement task move service/route with delta cascade, past-date rejection, event persistence, and rollover reset.
- [x] 4.3 Write failing backend tests for active project deadline edit that recalculates expected-late state without moving tasks.
- [x] 4.4 Implement project deadline edit service/route.

## 5. Task Add/Delete

- [ ] 5.1 Write failing backend tests for inserting an active project task on a selected date with no cascade and red-state recalculation.
- [ ] 5.2 Implement task insertion service/route.
- [ ] 5.3 Write failing backend tests for deleting a single unfinished task with no cascade and completed-project transition when no unfinished tasks remain.
- [ ] 5.4 Implement task deletion service/route and completed-history preservation.

## 6. Rest Days

- [ ] 6.1 Write failing backend tests for weekly and one-off rest-day settings, including add/remove semantics.
- [ ] 6.2 Implement rest-day settings service/route.
- [ ] 6.3 Write failing backend tests for D27 +1 day cascade when new rest days are added.
- [ ] 6.4 Implement rest-day cascade in chronological order with event evidence and rollover reset for affected tasks.

## 7. Dialogue Preview And Apply

- [ ] 7.1 Write failing backend tests for supported dialogue adjustment preview without mutation.
- [ ] 7.2 Implement bounded dialogue preview for project-level date shifts.
- [ ] 7.3 Write failing backend tests for applying exactly the previewed changes and rejecting unsupported/ambiguous instructions safely.
- [ ] 7.4 Implement dialogue apply route, event persistence, and view refresh contract.

## 8. Swift API And ViewModel

- [ ] 8.1 Write failing Swift model/client tests for adjustment endpoints and enriched study-view payloads.
- [ ] 8.2 Implement Swift API models, protocol methods, and concrete client calls.
- [ ] 8.3 Write failing ViewModel tests for rollover refresh, manual move cascade refresh, deadline edit, add/delete task, rest-day changes, and dialogue preview/apply state.
- [ ] 8.4 Implement ViewModel adjustment state and refresh sequencing.

## 9. Swift UI

- [ ] 9.1 Write failing presentation/source tests for rolled badges, red project/day states, move/date edit controls, task add/delete controls, rest-day settings, and dialogue preview/apply.
- [ ] 9.2 Implement minimal UI controls in Today, Project Overview, Calendar, Settings, and Adjust Plan surfaces.
- [ ] 9.3 Verify default mode stays silent: no smart suggestion card appears after red-state-producing manual adjustments.

## 10. Review And Verification

- [ ] 10.1 Run relevant backend and Swift tests and record RED/GREEN/REFACTOR evidence.
- [ ] 10.2 Run `openspec validate introduce-study-plan-adjustment --strict`.
- [ ] 10.3 Use Computer Use/App Use on the current checkout app path to verify rollover facts, manual move cascade, deadline red state, add/delete, rest-day behavior, and dialogue preview/apply; save evidence under Flow B.
