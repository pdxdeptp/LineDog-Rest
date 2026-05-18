## Context

`idlePetAnimationIntensity` was introduced as the normal desk-pet dynamic-strength preference. `PetRenderer` currently applies that scalar to every `PetDisplayMode`, including `.breakRunning`, so a low idle setting can make the break-run GIF freeze on its first frame or play through the manual slow-frame path. `BreakRunController` itself already keeps movement speed independent by using a fixed speed range and elapsed-time displacement.

## Goals / Non-Goals

**Goals:**

- Keep the break-run pet visually running at full GIF speed regardless of idle animation intensity.
- Preserve the existing persisted preference and its behavior for normal idle modes.
- Avoid changing break-run movement speed, shielding, countdown, dismissal, or display routing.
- Add a focused regression test at the renderer boundary.

**Non-Goals:**

- Redesign the dynamic-strength slider or relabel the control.
- Add a separate break-run speed preference.
- Change the 30 Hz time-based movement policy in `BreakRunController`.
- Change fullscreen-rest animation behavior.

## Decisions

- Treat `.breakRunning` as a display-mode-level full-motion override inside `PetRenderer`.
  - Rationale: the renderer already owns the mapping from mode plus intensity to GIF playback strategy, and this keeps the persisted idle preference untouched.
  - Alternative considered: have `PetStageView.beginBreakRunDisplay` temporarily call `setAnimationIntensity(1)`. That would require careful restoration on every exit path and risks leaving the idle pet at full speed after break-run ends.

- Keep variant rotation disabled for `.breakRunning`.
  - Rationale: break-run has dedicated running assets but is not a long-lived idle/thinking continuous state; the existing no-rotation behavior avoids extra timers and visual jumps.
  - Alternative considered: rotate between break-run GIF variants during the run. That would be a separate visual-design change and is not needed to fix the perceived slowdown.

- Test this as renderer behavior, not movement behavior.
  - Rationale: static analysis shows `BreakRunController` does not read animation intensity; the regression risk is the renderer choosing static/manual playback for `.breakRunning`.
  - Alternative considered: add UI/window integration tests. They would be slower and less deterministic while providing less direct proof of the failure mode.

## Risks / Trade-offs

- [Risk] Users who intentionally set idle animation to zero may still see motion during break-run.
  - Mitigation: break-run is an active rest cue, not the normal idle pet; this change leaves idle visuals static outside that mode.

- [Risk] Future display modes might need different intensity semantics.
  - Mitigation: keep the override explicit to `.breakRunning`, with test coverage naming the intended exception.
