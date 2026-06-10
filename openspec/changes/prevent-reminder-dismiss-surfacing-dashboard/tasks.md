## 1. Regression Coverage

- [x] 1.1 Add a focused failing test proving the center bell reminder uses a non-activating panel style.
- [x] 1.2 Verify the focused test fails before implementation.
- [x] 1.3 Add a focused failing test proving the hydration reminder uses a non-activating panel style and does not activate MalDaze.
- [x] 1.4 Verify the hydration reminder test fails before implementation.

## 2. Implementation

- [x] 2.1 Update the center bell reminder overlay to use a non-activating panel without changing content or dismissal behavior.
- [x] 2.2 Update the hydration reminder overlay to use a non-activating panel without changing content, actions, or scheduling behavior.

## 3. Verification

- [x] 3.1 Run the focused reminder window test and confirm it passes.
- [x] 3.2 Run OpenSpec validation for `prevent-reminder-dismiss-surfacing-dashboard`.
- [x] 3.3 Run a patch hygiene check and report manual QA steps for the desktop interaction.
- [x] 3.4 Run focused hydration reminder window coverage and confirm it passes.
- [x] 3.5 Run OpenSpec validation for `prevent-reminder-dismiss-surfacing-dashboard`.
- [x] 3.6 Run build and patch hygiene checks.
