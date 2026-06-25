# CPU diag baseline (before fix)

## Summary

macOS generated `cpu_resource.diag` on:

| Date | Duration | Avg CPU |
|------|----------|---------|
| 2026-06-16 | 171 s | ~53% |
| 2026-06-21 | 178 s | ~51% |
| 2026-06-22 | 179 s | ~50% |

Later two events: app in background, user idle. Process ~10 h runtime, ~41 min cumulative CPU.

## Repro (logical)

1. Timer mode: **autoWatching** (not manual focus).
2. Open Dashboard → Learning → **Today** tab (focus timeline row appears).
3. Close Dashboard (`orderOut`).
4. Leave app background idle.

## Stack (representative)

- `FocusTimelinePresenter.liveTick`
- `FocusTimelinePresenter.displayModel` setter / `@Published`
- SwiftUI `AttributeGraph`
- AppKit window layout
- Today Todo text measurement (collateral invalidation)

## Root cause (this change scope)

- `setVisible(true)` starts 4 Hz timer regardless of manual work.
- `syncLiveOverlay` periodic path calls `publishDisplayModel(overlay: nil)` every second when not manual active.
- Violates `refactor-focus-timeline-presenter` design D3.

## Out of scope (follow-up changes)

- Dashboard `orderOut` without quiescence SSOT → `add-dashboard-presentation-quiescence`
- GIF baseline, intervention 3s poll, ManualTimerEngine 4 Hz

## After fix (fill on completion)

- [ ] Same repro, Release build, 10 min idle CPU note
- [ ] Instruments: no `liveTick` in stack when autoWatching
