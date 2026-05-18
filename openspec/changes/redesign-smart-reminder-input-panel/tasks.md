## 1. Tests and Source Assertions

- [x] 1.1 Add failing assertions that `SmartReminderInputPanelContent` uses a vertically wrapping text input rather than the old fixed single-line strip.
- [x] 1.2 Add failing assertions for bounded input panel sizing and removal of the old 400-point text field width assumption.
- [x] 1.3 Add failing assertions that the redesigned panel still exposes explicit cancel and submit actions.

## 2. Input Panel Redesign

- [x] 2.1 Redesign `SmartReminderInputPanelContent` as a compact capture card with a vertically wrapping input area.
- [x] 2.2 Add bounded line-height behavior so long text remains visible without turning the panel into a large window.
- [x] 2.3 Update input panel width, height, host frame, and SwiftUI layout constants to match the redesigned card.
- [x] 2.4 Preserve focus-on-open, Esc cancel, draft binding, and full-draft submit behavior.
- [x] 2.5 Clamp smart reminder input and toast panel positioning to the anchor screen visible frame so right-edge and right-side-Dock placements remain fully visible.

## 3. Verification

- [x] 3.1 Run the relevant Swift/Xcode tests for smart reminder UI and window-manager behavior.
- [ ] 3.2 Manually QA right-click open, global shortcut open, long Chinese text entry, outside-click draft preservation, Esc/cancel, submit success, and repeated open from the current project checkout.
- [ ] 3.3 Manually QA right-bottom pet placement with a right-side Dock and confirm the smart reminder panel stays inside the visible screen area.
