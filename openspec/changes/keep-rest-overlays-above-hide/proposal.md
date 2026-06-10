## Why

Break-run rest already keeps the desk pet itself in a high-level always-present window, but its delayed shield and fixed countdown are separate `NSPanel` windows. Those helper panels can still behave like ordinary app panels during application hide/deactivation, which makes the rest interruption easier to hide than the desk pet.

## What Changes

- Keep the break-run shield panel visible when MalDaze is hidden or deactivated.
- Keep the break-run fixed countdown panel visible when MalDaze is hidden or deactivated.
- Preserve the existing stacking order: desk pet above countdown, countdown above shield, shield above normal app windows.
- Do not change Dashboard behavior or the fullscreen rest visual layout.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `break-interruption`: Clarify that break-run shield and fixed countdown panels must opt out of app-hide/deactivation hiding like the desk pet window.

## Impact

- `MalDaze/WindowManager/WindowManager.swift`
- Focused source-level regression tests for break-run panel window configuration
