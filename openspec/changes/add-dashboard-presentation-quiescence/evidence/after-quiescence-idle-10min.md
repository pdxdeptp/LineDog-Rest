# After quiescence idle verification

Fill after Change 1 + 2 applied.

## Repro

1. Release build.
2. autoWatching mode.
3. Open Dashboard → Learning → Today.
4. Close Dashboard (Esc / toggle / Cmd+W).
5. Background idle 10 minutes.

## Expected

- [ ] Activity Monitor: energy impact not sustained "High"
- [ ] No new `cpu_resource.diag` at ~50% avg CPU
- [ ] Cumulative CPU time slope much lower than ~41 min / 10 h baseline
- [ ] Instruments (optional): no `FocusTimelinePresenter.liveTick` stack

## Functional regression

- [ ] Reopen Dashboard: tab/state preserved
- [ ] Manual focus + visible timeline: in-progress updates ≤1 Hz
- [ ] Learning refresh / nutrition panel still work after reopen

## Notes

<!-- date, build, machine, actual CPU readings -->
