## Context

Draft review already shows compact summaries, full schedule expansion, and item-level controls. The risk is not the presence of review; it is that editable controls and option buttons may overpromise what will be persisted or may apply stale/implicit parameters.

## Goals / Non-Goals

**Goals:**

- Make every visible edit either persisted into a new draft version or clearly local/non-persistent.
- Make option effects parameter-explicit before applying.
- Preserve draft review as summary-first.

**Non-Goals:**

- No route/draft needs-input split; that belongs to `fix-add-initiate-state-boundaries`.
- No broad wording rewrite; that belongs to `polish-add-initiate-language-input`.
- No scheduler algorithm changes.

## Decisions

1. **Pick one edit contract.** Prefer the smaller implementation: keep estimate edits and remove/label title edits unless product explicitly needs persisted title edits now.
2. **Option parameters are visible.** If an option uses deadline, capacity, depth, load shape, or estimate edits, the UI shows the parameter before applying.
3. **New review before activation.** Option effects should return a new review state, storage state, compiler-recompute handoff, or focused input state before activation is offered.
4. **Hard deadline guard remains local and backend-backed.** Do not show accept-late-finish for hard deadlines.

## Risks / Trade-offs

- Removing title editing is less powerful but safer than fake persistence.
- Adding parameter confirmation may add clicks, but prevents “nothing changed” confusion.

## Open Questions

- Should persisted task title editing become a later dedicated backend draft-edit capability?
