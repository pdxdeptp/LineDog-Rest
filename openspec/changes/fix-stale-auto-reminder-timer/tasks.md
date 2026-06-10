## 1. Regression Tests

- [x] 1.1 Add a RED `AutoTimerEngine` test that simulates a one-shot anchor timer firing materially late after the expected `:00` / `:30` anchor and verifies the engine emits `.autoWatching(nextAnchor:)` instead of `.resting`.
- [x] 1.2 Add a RED `AutoTimerEngine` test that simulates an on-time anchor callback within the stale-grace window and verifies scheduled rest still begins with the configured duration.
- [x] 1.3 Add RED `AppViewModel` lifecycle tests or equivalent focused coverage for wake / become-active realignment when automatic timing is active.
- [x] 1.4 Add RED coverage that wake / become-active does not restart automatic timing when the user has stopped the timer and the session is awaiting resume.

## 2. Auto Timer Engine

- [x] 2.1 Add deterministic clock support for `AutoTimerEngine` tests while defaulting production behavior to `Date()`.
- [x] 2.2 Track the active waiting anchor and make the one-shot timer callback validate the expected anchor before entering rest.
- [x] 2.3 When the callback is stale, premature, or no longer matches the active waiting anchor, realign to the next valid half-hour anchor without emitting `.resting`.
- [x] 2.4 Keep the waiting phase on one-shot timers and preserve whole-second scheduled-rest countdown behavior.

## 3. Lifecycle Realignment

- [x] 3.1 Add wake and app-reactivation observer ownership to `AppViewModel`, following the existing observer token cleanup pattern.
- [x] 3.2 Realign the automatic timer only when mode is `.auto`, the timer session is active, the session is not user-suspended, and the automatic engine is not already in scheduled rest.
- [x] 3.3 Ensure realignment refreshes the published “下次休息 HH:mm” status through the existing `TimeState.autoWatching` flow.

## 4. Review And Verification

- [x] 4.1 Run focused timer/view-model tests covering the stale-anchor and wake-realignment scenarios.
- [x] 4.2 Run `openspec validate fix-stale-auto-reminder-timer --strict` or the project-equivalent OpenSpec validation.
- [x] 4.3 Review the implementation against the `break-interruption` spec delta and document any remaining manual QA steps.
