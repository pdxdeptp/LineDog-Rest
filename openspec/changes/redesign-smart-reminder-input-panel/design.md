## Context

The smart reminder input is opened from the desk pet right-click path and the global smart reminder shortcut. Its current SwiftUI content is a fixed-width `TextField` inside a small borderless `NSPanel`, which makes longer Chinese natural-language plans disappear horizontally while typing.

The surrounding lifecycle is already useful: the panel can become key, focuses the field on open, preserves drafts when dismissed, and submits through `AppViewModel` into `SmartReminderOrchestrator`. This change should improve the capture surface without changing reminder parsing or EventKit write behavior.

## Goals / Non-Goals

**Goals:**

- Make long natural-language reminder text visible by wrapping vertically.
- Keep the panel compact and desk-pet-adjacent rather than turning it into a full dashboard.
- Preserve right-click and global shortcut entry points.
- Preserve draft retention on cancel/outside click/Esc and success-clear behavior after a successful write.
- Keep keyboard and focus behavior reliable in the borderless `NSPanel`.

**Non-Goals:**

- No LLM prompt, reminder parsing, recurrence, alarm, or EventKit mutation changes.
- No redesign of the desk-pet dashboard panel.
- No persistent standalone reminder editor window.
- No new dependencies.

## Decisions

### D1: Use a vertically wrapping input control

Use SwiftUI's vertical text-entry affordance for the main draft field, such as `TextField(_:text:axis: .vertical)` with a bounded `lineLimit`. This keeps the existing submit/focus model closer to the current single-line field while allowing long text to wrap and grow.

Alternative considered: switch to `TextEditor`. Rejected for this iteration because it adds more custom placeholder and submit-key handling than the current problem requires.

### D2: Replace the narrow strip with a small capture card

The input panel should become a slightly larger capture card with an input area, a compact action row, and enough padding for text to breathe. The panel should have a stable width and a taller minimum height than the current 428x96 strip, while still fitting near the pet on typical screens.

The input area should grow up to a maximum line count. Beyond that, the control should remain bounded so the panel does not become a large modal surface.

### D3: Keep actions explicit and low-friction

The redesigned content should keep cancellation obvious and add an explicit primary submit action. Keyboard focus should land in the input field on open. Esc continues to cancel through existing panel handling. The submit path should still pass the entire draft string to the existing `onSubmit` closure.

### D4: Keep WindowManager ownership unchanged unless sizing requires a small adjustment

`WindowManager` should continue to create, position, dismiss, and preserve the smart reminder draft. Implementation should avoid moving smart reminder lifecycle state out of `WindowManager` unless the redesigned panel size needs a small positioning clamp or sizing constant update.

## Risks / Trade-offs

- [Risk] A taller panel may overlap the pet or nearby desktop content more often. -> Mitigation: keep dimensions bounded and reuse the current top-center anchor positioning.
- [Risk] `TextField(axis: .vertical)` behavior can differ across macOS versions. -> Mitigation: add source assertions for the intended SwiftUI API and manually QA long text entry.
- [Risk] Adding explicit submit UI could make the panel feel heavier. -> Mitigation: keep the action row compact and avoid extra explanatory copy.

## Migration Plan

1. Add tests/source assertions for a vertical input field, bounded line count, no old fixed 400-point text field strip, and explicit submit/cancel actions.
2. Redesign `SmartReminderInputPanelContent` with a vertically wrapping input area and compact action row.
3. Update input panel sizing constants and host frame to match the new capture card.
4. Run relevant Swift tests.
5. Manually QA right-click open, shortcut open, long text, Esc/cancel, outside-click draft preservation, submit success, and repeated open.

Rollback: revert `SmartReminderUIPanels.swift` to the previous single-line content and panel size. No data migration is needed.

## Open Questions

- Should a future iteration support richer parsing previews before writing reminders, or should this remain a fast capture-only surface?
