## 1. Regression Coverage

- [x] 1.1 Add focused tests for disabled shortcut display, UI close actions, and Carbon registration guards.
- [x] 1.2 Verify the new focused tests fail before implementation.

## 2. Implementation

- [x] 2.1 Add disabled-state semantics to all shortcut models without changing first-launch defaults.
- [x] 2.2 Add per-row shortcut disable UI and make empty recording exits persist disabled shortcuts.
- [x] 2.3 Skip Carbon registration for disabled shortcuts while unregistering any previously installed hot key.

## 3. Verification

- [x] 3.1 Run focused shortcut tests and confirm they pass.
- [x] 3.2 Run OpenSpec validation for `disable-empty-shortcuts`.
- [x] 3.3 Provide manual QA steps for the settings UI.
