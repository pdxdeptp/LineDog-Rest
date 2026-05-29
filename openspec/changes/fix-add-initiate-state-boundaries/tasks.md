## 1. State Tests

- [ ] 1.1 Add a ViewModel test for route-level `needs_input` without `draftId`, proving it does not call anchor confirmation.
- [ ] 1.2 Add a ViewModel test for draft-level `needs_input` with `draftId`, proving the focused answer resumes planning for the same draft.
- [ ] 1.3 Add tests proving reference/later/one-off recommendations require explicit confirmation before terminal success.
- [ ] 1.4 Add tests proving activation success enters an explicit success state and refreshes active surfaces exactly once.
- [ ] 1.5 Add tests proving non-active states do not refresh active learning surfaces.

## 2. State Model

- [ ] 2.1 Add derived state for route clarification vs draft clarification.
- [ ] 2.2 Preserve existing stale-response guards for route, anchor, option, and activation responses.
- [ ] 2.3 Add a minimal response discriminator only if existing fields are not enough for stable branching.

## 3. UI Flow

- [ ] 3.1 Render route clarification separately from planning anchors.
- [ ] 3.2 Add explicit confirmation UI for non-plan storage and one-off handling.
- [ ] 3.3 Ensure material-only attachment reaches a quiet success terminal state only after confirmation.
- [ ] 3.4 Add activation-success card and next actions.
- [ ] 3.5 Keep activation-failure recovery unchanged and visible.

## 4. Verification

- [ ] 4.1 Run focused Swift tests for Add / Initiate state boundaries.
- [ ] 4.2 Run backend contract tests if API response fields changed.
- [ ] 4.3 Run `openspec validate fix-add-initiate-state-boundaries --strict`.
- [ ] 4.4 Manually verify route clarification, non-plan confirmation, material attachment, activation success, and activation failure in the desktop app.
