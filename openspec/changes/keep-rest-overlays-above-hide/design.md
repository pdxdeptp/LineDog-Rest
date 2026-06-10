## Context

`WindowManager` uses one `PetStageWindow` for the idle desk pet and fullscreen rest. That window already sets `hidesOnDeactivate = false` and `canHide = false`, so it remains visible when the MalDaze app is hidden.

Break-run rest has two helper windows:

- `breakRunShieldWindow`: a delayed translucent `NSPanel` that blocks clicks after long break-run sessions.
- `breakRunCountdownPanel`: a fixed countdown `NSPanel` shown near the lower-left of the menu-bar screen.

Those helper panels are separate from the desk pet window and currently do not opt out of application hide/deactivation behavior.

## Goals / Non-Goals

**Goals:**

- Keep break-run shield and fixed countdown panels visible alongside the desk pet during app hide/deactivation.
- Preserve current screen-saver-level stacking and all click-to-end behavior.
- Add focused regression coverage for the panel configuration.

**Non-Goals:**

- Move fullscreen rest dimming/countdown out of `PetStageView`.
- Change Dashboard visibility, activation, or Mission Control behavior.
- Change break-run movement, shield timing, or countdown placement.

## Decisions

1. Configure both break-run helper panels like persistent desk-pet UI.

   Set `hidesOnDeactivate = false` and `canHide = false` on both `NSPanel` instances. This matches the existing intent of the desk pet window without introducing a new window type.

2. Keep the existing levels.

   The shield remains below countdown, the countdown remains below the desk pet, and all three remain above normal app windows. Changing levels is unnecessary because the reported failure is hiding behavior, not z-order.

3. Test by source-level regression.

   Existing tests in this project already use source inspection for AppKit window configuration. A focused test can reject future regressions without needing to drive macOS app hide behavior in CI.

## Risks / Trade-offs

- [Risk] `NSPanel` defaults can vary subtly across macOS releases. Mitigation: set both `hidesOnDeactivate` and `canHide` explicitly on each helper panel.
- [Risk] Source-level tests do not prove runtime window-server behavior. Mitigation: pair them with manual QA steps for hiding/deactivation during break-run.
