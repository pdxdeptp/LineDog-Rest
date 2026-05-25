## Why

Break-run rest currently uses the same `PetRenderer` animation-intensity path as the idle desk pet, so lowering the idle dynamic-strength slider can make the break-running GIF appear slow or static even though the window movement speed is unchanged. This makes break-run feel inconsistent and obscures the intended "running across the screen" rest cue.

## What Changes

- Ensure break-run display uses full-motion pet GIF playback regardless of the persisted idle desk pet animation intensity.
- Keep `idlePetAnimationIntensity` behavior unchanged for normal idle, paused, thinking, and fullscreen-rest visuals unless those modes already explicitly refresh from the preference.
- Preserve the existing `BreakRunController` movement speed, bounce behavior, countdown, shield, and dismissal flows.
- Add regression coverage proving `.breakRunning` playback is not slowed or frozen by idle animation intensity.

## Affected Specs

- `pet-visuals`

## Capabilities

### New Capabilities

### Modified Capabilities

- `pet-visuals`: clarify that break-run visuals remain full-motion and are not governed by the idle desk pet dynamic-strength setting.

## Impact

- Affected code: `MalDaze/PetRenderer/PetRenderer.swift` and focused tests under `MalDazeTests/`.
- No API, dependency, backend, or persistence schema changes.
