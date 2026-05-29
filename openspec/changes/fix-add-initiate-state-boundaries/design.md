## Context

The existing frontend state machine exposes a single `.needsInput` UI path even though Add / Initiate can need input before a draft exists or after a draft exists. It also has terminal UI for stored/material-attached states but no terminal UI for activation success.

## Goals / Non-Goals

**Goals:**

- Prevent route clarification from calling draft anchor confirmation.
- Require explicit confirmation before showing non-plan storage success.
- Show activation success clearly.
- Preserve no-active-task noise boundaries until activation succeeds.

**Non-Goals:**

- No broad copy rewrite.
- No target-depth control redesign.
- No task edit or infeasible-option redesign.
- No scheduler/compiler changes.

## Decisions

1. **Derived substate first.** Use existing fields such as `draftId`, `nextAction`, `reviewState`, and `clarificationQuestion` to derive route clarification vs draft clarification. Add a minimal API field only if this is unstable.
2. **Confirmation before storage terminal.** Route recommendations for reference/later/one-off are recommendations, not storage success.
3. **Activation success is terminal.** `.activated` gets its own success card and next actions.
4. **Refresh only after active creation.** Continue refreshing active surfaces only when activation succeeds with `createsActiveTasks=true`.

## Risks / Trade-offs

- Existing backend states may be ambiguous → add focused tests first, then introduce a minimal discriminator only if needed.
- More states may make UI branching larger → keep helpers small and derived from current session identity.

## Open Questions

- Should route clarification use an existing `nextAction=answer_routing_question`, or should the API expose a clearer `questionScope=route`?
