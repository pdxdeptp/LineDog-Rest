## Context

Break-run rest mode keeps the desk pet as a small floating window while `BreakRunController` moves it inside the visible frame of the screen containing the pet window. After 60 seconds, `WindowManager.showBreakRunShield()` creates a dimming panel using `NSScreen.main`, which can track the current focus or pointer screen in this menu-bar app. This makes the shield appear on a different display than the running pet.

The desired behavior is screen ownership by the pet window, not by focus, mouse location, or the menu-bar display.

## Goals / Non-Goals

**Goals:**

- Resolve the shield target screen from the current desk pet window frame.
- Keep the shield on the same physical display where the break-run pet is moving when the shield is shown.
- Add regression coverage so `NSScreen.main` is not used for the delayed break-run shield path.

**Non-Goals:**

- Do not change break-run movement, velocity, bounce behavior, or duration.
- Do not move the fixed countdown panel in this change.
- Do not change fullscreen rest behavior.

## Decisions

- Use the pet window frame center as the shield screen anchor.
  - Rationale: `BreakRunController` already treats the window center as the screen selection point for movement, so the shield and movement use the same source of truth.
  - Alternative considered: use `MenuBarNSScreen.screen`. That would fix focus drift but still fails if a persisted pet position places the pet on another display.

- Add a small helper for resolving the break-run shield screen.
  - Rationale: it makes the policy testable and keeps `showBreakRunShield()` focused on panel creation.
  - Alternative considered: inline the `NSScreen.screens.first(where:)` lookup in `showBreakRunShield()`. That is shorter but easier to regress back to `NSScreen.main`.

## Risks / Trade-offs

- [Risk] The pet window frame may not intersect any current screen after display changes.
  - Mitigation: fall back to the menu-bar screen, then the first available screen, preserving existing best-effort behavior.

- [Risk] A pet crossing a display boundary exactly when the shield appears could resolve to either adjacent display.
  - Mitigation: using the window center matches the movement controller's existing screen-boundary policy.
