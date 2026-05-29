## Why

The draft review screen currently exposes controls that can imply edits will affect the activated plan, while some option buttons may apply without visibly collecting the required parameters.

This change makes draft review honest and option effects explicit, without changing the earlier Add / Initiate state boundary or language work.

## What Changes

- Decide and implement the draft item edit boundary: persist task title edits or remove/label them as non-persistent.
- Ensure estimate edits and other option effects create or request a new review state before activation.
- Add visible parameter collection or confirmation for options such as extend deadline, increase capacity, lower depth, rebalance, and edit estimates.
- Preserve compact-first draft review and expanded schedule/source details.
- Keep hard-deadline drafts from offering accept-late-finish.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `assistant-panel-ui`: Harden Add / Initiate draft review, item edit semantics, and infeasible option handling.

## Impact

- Should follow `fix-add-initiate-state-boundaries`.
- Affected Swift files: `AssistantPanelView.swift`, `LearningAssistantViewModel.swift`.
- Potential backend/API impact if persisted title edits are chosen instead of removing title editing.
- Affected tests: Swift Add / Initiate draft review tests; backend option-effect tests if API changes.
