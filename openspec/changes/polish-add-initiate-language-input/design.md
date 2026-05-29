## Context

The current UI shows labels like `text_goal`, `new_plan`, `planning_language`, and default depth `apply`. These are stable implementation values, but they are not good product language.

## Goals / Non-Goals

**Goals:**

- Make Add / Initiate understandable from the first screen.
- Keep machine values stable internally.
- Let users review title, deadline, capacity, target output, target depth, and assumptions before generation.

**Non-Goals:**

- No backend routing rewrite.
- No state-boundary fixes beyond relying on the prior split.
- No draft task editing or option-effect work.

## Decisions

1. **UI label mapping over contract changes.** Keep raw values in API models; map them to localized labels in Swift.
2. **Source type becomes helper.** Users can still select or correct a type, but the UI should not present raw values as required knowledge.
3. **Depth is a segmented/menu choice.** User-facing labels map to current depth tokens.
4. **Title is reviewed before handoff.** The visible title should not silently inherit a long pasted body.

## Risks / Trade-offs

- Hiding raw reason codes may reduce debugging visibility → keep them in tests/logs or debug-only help.
- Depth labels may not perfectly match backend semantics → document mapping in one place and cover it with tests.

## Open Questions

- Should source type be hidden by default behind an advanced disclosure, or remain visible with friendlier labels?
