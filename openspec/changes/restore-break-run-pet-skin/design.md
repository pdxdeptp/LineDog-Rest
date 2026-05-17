## Context

Break-run rest mode is routed through `WindowManager.presentBreakRun`, which calls `PetStageView.beginBreakRunDisplay` before `BreakRunController` starts moving the existing pet window. The current implementation sets the renderer to `.runningBlack`; meanwhile `.breakRunning` exists as a display mode but has no dedicated GIF mapping in `PetRenderer`, so using it directly would currently fall back to the SF Symbol.

## Goals / Non-Goals

**Goals:**

- Make break-run rest start visibly switch the pet to the dedicated break-running GIF assets.
- Keep idle, fullscreen rest, thinking, and paused visuals unchanged.
- Add regression tests at the display-mode boundary so future routing or asset-map changes catch the issue.

**Non-Goals:**

- Redesign break-run movement, shield behavior, countdown panels, or click-to-end logic.
- Change menu bar icon semantics.
- Add new assets.

## Decisions

- Use `.breakRunning` as the state selected by `PetStageView.beginBreakRunDisplay`.
  - Rationale: `pet-visuals` already defines a distinct break-run display state, and this keeps state naming aligned with the mode being rendered.
  - Alternative considered: set `.restingRed` during break-run. That would reuse rest assets but blur fullscreen rest and break-run semantics.

- Give `.breakRunning` its own `LineDog/breakRunning` URL list in `PetRenderer`.
  - Rationale: it makes the dedicated skin explicit and prevents break-run from accidentally pulling idle GIFs.
  - Alternative considered: keep break-running GIFs mixed into `.restingRed`. That made the assets available only through the fullscreen-rest mode and left `.breakRunning` unusable.

- Expose minimal test-only inspection on renderer/stage objects.
  - Rationale: the bug sits at a state boundary that is otherwise visual; focused `@testable` accessors give deterministic regression coverage without broad UI automation.
  - Alternative considered: source-text tests. Existing tests use them, but behavior-level tests are a better fit here.

## Risks / Trade-offs

- [Risk] `.breakRunning` assets may be absent in an incorrectly packaged app → Mitigation: `PetRenderer` already falls back to the SF Symbol when no GIF URL is available.
- [Risk] Test-only accessors could leak implementation shape → Mitigation: keep them `internal` and scoped to `@testable` diagnostics only.
