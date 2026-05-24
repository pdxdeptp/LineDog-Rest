## 1. Bottom Navigation Responsiveness

- [ ] 1.1 Add a failing Swift regression test proving assistant bottom-navigation items expose a full rectangular hit target and immediate selected-state styling.
- [ ] 1.2 Update `AssistantPanelView` bottom-navigation button construction so each item switches `selectedPanelTab` immediately, has a stable equal-width frame, and uses an explicit rectangular content shape.
- [ ] 1.3 Run the focused learning-assistant Swift tests and confirm the new bottom-navigation regression passes.

## 2. Dashboard Panel Internal Click Stability

- [ ] 2.1 Add a failing Swift regression test proving Dashboard Panel dismissal logic distinguishes inside-panel clicks from outside clicks during click-away/focus handling.
- [ ] 2.2 Update `WindowManager` Dashboard Panel dismissal helpers so clicks inside the panel remain internal and do not close the panel, while outside click, Esc, app-deactivation, and desk-pet toggle behavior remain intact.
- [ ] 2.3 Run the focused control-panel Swift tests and confirm existing outside-click dismissal coverage still passes.

## 3. Verification

- [ ] 3.1 Run the relevant Swift test targets covering learning assistant and Dashboard Panel presentation.
- [ ] 3.2 Manually verify in the running app that opening the Dashboard Panel and clicking each bottom tab once keeps the panel visible and changes selection immediately.
- [ ] 3.3 Record implementation evidence and any residual QA notes in this change directory.
