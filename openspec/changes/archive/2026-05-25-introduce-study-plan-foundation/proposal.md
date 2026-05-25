## Why

Learning assistant v1 is built around resource ingestion and autonomous agents, but v2 repositions the product as a user-controlled study-plan calendar with LLM help limited to initial URL decomposition and user-initiated adjustments. The foundation must be specified before code changes so implementation can replace the v1 ingestion-first behavior without reintroducing autonomous agent behavior.

## What Changes

- Add the `study-plan` v2 capability covering the first implementation slice: daily capacity, URL-based draft plan creation, guided clarification, decomposition, initial scheduling, review-state editing, and confirmation into active daily use.
- Introduce a skippable guided clarification step before URL decomposition, using D30 from the v2 design document.
- Replace v1 A/B ingestion-draft semantics for this slice with a single reviewable draft plan that remains inactive until user confirmation.
- Define deterministic initial scheduling for draft plans using D24: spread tasks across non-rest days from today through the required deadline, then surface over-capacity/late status without automatic repair.
- Keep old v1 learning specs as baseline documentation in this change; retirement of those specs is intentionally deferred.

## Capabilities

### New Capabilities

- `study-plan`: v2 study-plan foundation for user-owned learning projects, draft plan generation, guided URL clarification, deterministic initial scheduling, review edits, and activation.

### Modified Capabilities

- None. Existing v1 learning specs remain historical baseline for now and will be retired in a later dedicated change after v2 coverage exists.

## Impact

- Affected design source: `openspec/learning-assistant-v2.md`.
- Affected backend areas expected during implementation: learning assistant data model/storage, URL parse/decomposition orchestration, scheduling logic, and API endpoints currently under `assistant_backend/src/`.
- Affected Swift areas expected during implementation: `MalDaze/LearningAssistant/AssistantAPIClient.swift`, `LearningAssistantViewModel.swift`, `AssistantPanelView.swift`, and add-resource/review UI components.
- Affected tests expected during implementation: backend scheduling/decomposition tests, Swift API model/view-model tests, and panel presentation tests.
- No worktree is allowed; implementation must stay in the current checkout and checkpoint before `opsx:apply`.
