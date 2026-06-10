## Context

`AutoTimerEngine` currently computes the next `:00` or `:30` anchor, schedules a one-shot main-run-loop `Timer`, and enters scheduled rest whenever that timer fires. This keeps waiting low-wakeup, but it treats timer delivery as proof that the wall clock is still at the expected anchor.

On macOS, timers may be delivered late after sleep, display sleep, app suspension, or wake. A timer scheduled for 10:00 can therefore fire when the machine becomes active at 10:19. In that case the timer is stale; the correct behavior is to realign to the next `:00` / `:30`, not to start a rest window.

## Goals / Non-Goals

**Goals:**

- Make `AutoTimerEngine` reject stale anchor timer callbacks before entering scheduled rest.
- Preserve the low-wakeup one-shot timer design while waiting for the next anchor.
- Add app lifecycle realignment after wake / become-active so the displayed “下次休息” status and pending timer recover promptly.
- Cover the stale callback and lifecycle realignment behavior with focused regression tests.

**Non-Goals:**

- Do not change manual Pomodoro behavior.
- Do not change rest duration settings, persistence keys, Hermes contracts, or reminder JSON contracts.
- Do not reintroduce continuous polling while waiting for an automatic rest anchor.
- Do not alter the visual design of fullscreen or break-run rest surfaces.

## Decisions

### Timer callbacks must validate their expected anchor

`AutoTimerEngine` should treat the expected half-hour anchor as the source of truth and the `Timer` callback as a wake-up opportunity. The waiting timer should capture or otherwise identify the anchor it was scheduled for. When the callback runs, the engine compares `now` with that expected anchor:

- If the callback is within a small stale-grace window after the anchor, enter scheduled rest.
- If the callback is materially late, do not enter rest; schedule the next valid half-hour anchor from the current time and emit `.autoWatching(nextAnchor:)`.
- If a callback is premature or no longer matches the active waiting anchor, ignore or realign rather than entering rest.

Rationale: this fixes the root invariant in the component that owns automatic scheduling. A wake observer alone would be weaker because wake notifications and overdue timer callbacks can race.

Alternative considered: rely only on `NSWorkspace.didWakeNotification` to restart the engine. This improves user-facing recovery but does not guarantee correctness if the overdue timer fires before or after the wake handler in an unexpected order.

### Inject a clock only as needed for tests

The implementation may introduce a small internal clock dependency, defaulting to `Date()`, so tests can simulate a stale callback without sleeping the test process or depending on real wall-clock timing.

Rationale: a deterministic clock keeps the RED test focused and avoids brittle tests that wait across real half-hour anchors.

Alternative considered: manually mutate private timer fire dates through reflection. That would couple tests to implementation details without modeling the business condition clearly.

### AppViewModel owns lifecycle realignment

`AppViewModel` should observe `NSWorkspace.didWakeNotification` and `NSApplication.didBecomeActiveNotification` and ask the automatic engine to realign only when automatic timing is active and not user-suspended. This keeps `AutoTimerEngine` Foundation-only and keeps app lifecycle wiring with the existing app coordinator.

The lifecycle realignment is an optimization and recovery path, not the sole correctness mechanism. The stale callback guard still protects against races.

Alternative considered: make `AutoTimerEngine` observe workspace notifications directly. That would mix AppKit lifecycle concerns into the engine and make unit testing harder.

## Risks / Trade-offs

- Normal timer jitter could be rejected if the stale-grace window is too small -> Use a bounded grace window large enough for ordinary run-loop delay but well below a minute.
- Wake / become-active realignment could restart a user-paused automatic timer -> Gate realignment on active automatic timing state and leave suspended snapshots untouched.
- Existing tests that manually call `Timer.fire()` before the anchor may need adjustment -> Update tests to exercise the new invariant through deterministic time or a helper rather than relying on premature fire behavior.
- App lifecycle observers could leak or duplicate callbacks -> Store observer tokens and remove them in `deinit`, matching existing observer patterns in `AppViewModel`.
