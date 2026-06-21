## Why

MalDaze focus sessions currently mix time-log semantics (pause slices `stoppedEarly`, partial minutes paint as accent fill) with pomodoro counting. Users want **Forest-style pomodoro philosophy**: one indivisible focus block, pause suspends the same block, abandon/fail is visible but not counted as success, and the timeline celebrates completed blocks—not partial minutes.

## What Changes

- **Pause** no longer finalizes a focus session; resume continues the same work segment and countdown.
- **Abandon** (mode switch, starting a new focus while one is active/paused) writes `stoppedEarly` as a failed attempt only.
- **Complete** remains work→rest natural completion (`completed`).
- **Summary** `N 个 · X 分钟`: `N` and `X` count **completed** sessions/minutes only.
- **Timeline**: accent fill for `completed` + growing in-progress; **failed markers** (muted) for `stoppedEarly` at attempt start—no proportional success fill for partial minutes.
- **Popover**: completed sessions editable; failed attempts delete-only; in-progress read-only until finished.

## Capabilities

### Modified Capabilities

- `learning-desk-panel`: Forest-style focus grid semantics.
- `desk-pet-controls`: pause/resume pomodoro continuity rules.
