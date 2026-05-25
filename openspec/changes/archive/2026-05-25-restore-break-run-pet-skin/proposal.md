## Why

跑屏休息开始时，桌宠现在仍显示常态皮肤，用户看不到休息模式已经切入专门的跑屏视觉。这个回归削弱了休息提示的可感知性，也与现有 `pet-visuals` / `break-interruption` 规格不一致。

## What Changes

- Restore the break-run entry path so `PetStageView.beginBreakRunDisplay` selects the dedicated break-run pet display mode.
- Map `.breakRunning` to the `LineDog/breakRunning` GIF assets instead of falling back to idle visuals or a symbol.
- Add regression coverage proving break-run display uses the dedicated mode and assets, and returns to the non-rest mode afterward.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `pet-visuals`: clarify that `.breakRunning` resolves to dedicated `LineDog/breakRunning` GIF resources.
- `break-interruption`: clarify that starting break-run display switches the desk pet to `.breakRunning`.

## Affected Specs

- `pet-visuals`
- `break-interruption`

## Impact

- Affected code: `MalDaze/WindowManager/PetStageView.swift`, `MalDaze/PetRenderer/PetRenderer.swift`, and focused tests under `MalDazeTests/`.
- No external APIs, dependencies, persistence, or data migrations.
