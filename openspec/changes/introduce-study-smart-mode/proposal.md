## Why

Learning Assistant v2 now has a user-owned study plan, factual views, and deterministic adjustment primitives. The remaining smart-mode slice must add helpful proposals without reviving the v1 autonomous Morning Agent or broad conversational planner behavior.

## What Changes

- Add an off-by-default smart-mode setting for the learning assistant.
- Add a fact-only smart morning briefing that summarizes Today, project lag, expected-late, and over-capacity facts without autonomous mutation.
- Add smart proposal generation for two triggers:
  - morning briefing when lag, expected-late, or over-capacity facts exist;
  - after a manual adjustment creates expected-late or over-capacity red state.
- Show multiple candidate proposal options side by side, each with impact preview and its own Apply action.
- Apply only the selected proposal after revalidating it against current plan facts.
- Keep default mode silent and keep ITEM-003 mechanical adjustment semantics unchanged.
- Do not retire, delete, or repurpose v1 learning specs/endpoints in this change.

## Capabilities

### New Capabilities

- `study-smart-mode`: Opt-in smart-mode briefing, proposal generation, proposal display, and user-confirmed proposal application for v2 study plans.

### Modified Capabilities

- None. Completed v2 capabilities remain active changes until archive, and old v1 specs remain unchanged for historical behavior.

## Impact

- Backend: new smart-mode setting, factual snapshot/briefing/proposal service, smart-mode routes, and tests that forbid v1 Morning Agent mutation paths.
- Swift: API models/client methods, ViewModel smart-mode state, Settings toggle, smart briefing/proposal UI, and after-adjustment trigger wiring.
- OpenSpec: new `study-smart-mode` spec delta under this change.
- Safety: no worktree, no autonomous plan mutation, no new credentials, and no implementation without `opsx:apply` plus TDD gates.
