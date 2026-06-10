## Context

Dashboard currently has three AppKit-backed resize handles: left column, right column, and the plan/nutrition row separator. A recent unification made column and row handles share one `NSViewRepresentable`, but the drag coordinate changed from `NSEvent.locationInWindow` to `convert(event.locationInWindow, from: nil)`.

That local-coordinate conversion is unstable for resize handles because the handle itself moves as SwiftUI relayouts after every live size update. The next drag event is then measured in a different local coordinate space, creating alternating deltas that look like flicker.

## Goals / Non-Goals

**Goals:**

- Make column and row separator drags use a coordinate system that does not move with the handle.
- Preserve existing cursor, hit testing, tracking area, and live resize behavior.
- Add a regression test focused on the coordinate-system contract.

**Non-Goals:**

- Redesign Dashboard layout.
- Change persisted column widths or plan/nutrition fraction keys.
- Change nutrition, reminder, or learning panel data behavior.
- Add throttling or debouncing unless the stable-coordinate fix proves insufficient.

## Decisions

- Use `event.locationInWindow.x/y` as the resize drag coordinate, selected by axis.
  - Rationale: window coordinates remain stable while SwiftUI moves the handle during layout.
  - Alternative considered: keep local coordinates and compensate by tracking handle frame movement. This is more fragile and unnecessary.

- Keep live `@State` updates during drag.
  - Rationale: the regression is caused by coordinate feedback, not by preference writes. Current implementation already defers `@AppStorage` writes until mouse up.
  - Alternative considered: update only on mouse up. This would avoid flicker but would remove expected live resizing feedback.

- Add source-level regression coverage in the existing presentation test file.
  - Rationale: the project already uses source inspections for Dashboard AppKit/SwitchUI integration contracts, and direct construction of private AppKit event flow is disproportionate for this narrow regression.

## Risks / Trade-offs

- [Risk] A separate redraw cost in `NutritionTodayPanelView` could still make the row handle feel heavy after coordinate stability is restored. → Mitigate with manual QA after the fix; only add throttling if smooth deltas still flicker.
- [Risk] Source-level tests do not simulate AppKit mouse events. → Mitigate by asserting the specific coordinate contract and running focused presentation tests.
