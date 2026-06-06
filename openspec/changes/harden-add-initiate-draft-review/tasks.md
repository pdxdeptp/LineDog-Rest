## 1. Draft Edit Tests

- [x] 1.1 Add tests proving title editing is either persisted into a new draft version or not shown as a saved edit.
- [x] 1.2 Add tests proving estimate edits send explicit estimate parameters.
- [x] 1.3 Add tests proving activation is blocked or redirected until edits produce a current review state.

## 2. Option Parameter Tests

- [x] 2.1 Add tests for extend-deadline parameter visibility and request payload.
- [x] 2.2 Add tests for increase-capacity parameter visibility and request payload.
- [x] 2.3 Add tests for lower-depth parameter visibility and request payload.
- [x] 2.4 Add tests proving hard-deadline drafts hide accept-late-finish.

## 3. Draft Review Implementation

- [x] 3.1 Choose the task title edit contract and update UI accordingly.
- [x] 3.2 Ensure estimate edits are applied through option effect or a current draft-edit path.
- [x] 3.3 Add parameter confirmation UI for deadline, capacity, depth, rebalance, and estimate options.
- [x] 3.4 Preserve compact-first review and expansion controls.
- [x] 3.5 Preserve stale-draft activation guards after option effects.

## 4. Verification

- [x] 4.1 Run focused Swift tests for draft review edits and infeasible options.
- [x] 4.2 Run backend option-effect tests if API payloads or persisted edits changed.
- [x] 4.3 Run `openspec validate harden-add-initiate-draft-review --strict`.
- [ ] 4.4 Manually verify draft review, estimate edits, option effects, hard deadline behavior, and activation guard in the desktop app.
