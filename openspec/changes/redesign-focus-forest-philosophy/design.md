## Forest-aligned rules (MalDaze mapping)

| Forest | MalDaze |
|--------|---------|
| Tree grows to completion | `completed` session; accent timeline fill |
| Tree dies (give up) | `stoppedEarly` session; muted failed marker at start |
| Pause keeps tree alive | User pause keeps one work segment + countdown; no JSON write |
| Dead trees stay visible | Failed markers remain on grid; not counted in `N` / success minutes |
| Growing tree | In-progress accent fill while work timer runs (not while paused) |

## Pause vs abandon

- **Pause (`stopTimers`)**: persist chrono paused state; **do not** append focus session.
- **Resume (`resumeTimers`)**: restore same engines + same `workSegmentStartedAt`.
- **Abandon**: append `stoppedEarly` when switching mode away from manual work, or starting a new manual focus while a work segment exists.

## Timeline paint

- **Success fill**: only `completed` intervals + active in-progress overlap.
- **Failed marker**: one small muted mark at mapped `startedAt` for each `stoppedEarly` session (not proportional partial blue).

## Summary

- `N` = completed pomodoro count (unchanged filter).
- `X` = sum of completed session minutes only (exclude stoppedEarly and in-progress).
