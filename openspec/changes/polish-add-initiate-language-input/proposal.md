## Why

After Add / Initiate state boundaries are correct, users still face implementation-heavy language: raw source types, raw roles, reason codes, target-depth tokens, and a title that defaults to the pasted body.

This change makes the same flow understandable without changing compiler, scheduler, or activation semantics.

## What Changes

- Replace raw source-type, role, reason, and depth labels with user-facing Chinese copy.
- Make source type an editable helper rather than a taxonomy decision users must understand first.
- Add title review/edit before creating or attaching a plan draft.
- Add local deadline validation.
- Replace free-text target-depth token entry with meaningful choices that map to existing backend tokens.
- Show assumptions in a reviewable form before draft generation.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `assistant-panel-ui`: Improve Add / Initiate user-facing language and planning-anchor input controls.

## Impact

- Depends on or should follow `fix-add-initiate-state-boundaries` for clean state branching.
- Affected Swift files: `AssistantPanelView.swift`, `LearningAssistantViewModel.swift`.
- No backend changes expected unless target-depth mapping needs shared constants.
