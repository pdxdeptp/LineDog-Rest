# Scope Split Decision

## Decision

Split `redesign-study-intake-planning` into focused implementation changes. The mother change remains the product/design source of truth and SHOULD NOT be applied directly as one implementation change.

## Child Changes

1. `introduce-study-intake-router`
   - Owns intake item creation, role routing, confidence, one-question clarification, non-plan storage, source preview, and GitHub role handling.
   - Affected specs: `study-intake-planning`, `material-ingestion`, `learning-data-layer`.

2. `persist-intake-plan-drafts`
   - Owns draft/active separation, draft assumptions, draft versioning, stale activation rejection, activation events, fallback progress, and capacity defaults.
   - Affected specs: `study-intake-planning`, `learning-data-layer`.

3. `introduce-plan-compiler`
   - Owns planning envelope creation, archetype/scope selection, target-depth semantics, LLM phase/task contracts, validation, bounded repair, estimate normalization, and compiler trace.
   - Affected specs: `study-intake-planning`.

4. `introduce-deadline-scheduler`
   - Owns deterministic scheduling, usable capacity, buffer, continuation sessions, risk report, infeasibility options, scope/depth reduction fit math, and hard-deadline guardrails.
   - Affected specs: `study-intake-planning`.

5. `redesign-add-initiate-ui`
   - Owns Add / Initiate UI, role/anchor review, progress states, draft review, infeasible review, activation/cancel/retry flows, and UI noise boundaries.
   - Affected specs: `assistant-panel-ui`, `ingestion-progress-sse`, `study-intake-planning`.

## Dependency Order

1. `introduce-study-intake-router`
2. `persist-intake-plan-drafts`
3. `introduce-plan-compiler`
4. `introduce-deadline-scheduler`
5. `redesign-add-initiate-ui`

The UI change may begin visual shell work earlier only if activation remains disabled behind mocks, but implementation should not enable real activation before router, draft persistence, compiler, and scheduler surfaces exist.

## Scope Guardrails

- No child change should redefine role enums, canonical repo roles, draft version rules, validation severity rules, or infeasibility option ids differently from the mother design.
- Child changes should import only the relevant requirements from the mother design.
- Each child change needs its own `opsx:apply-readiness` before implementation.
- If implementation reveals spec drift, update the relevant child change spec before continuing.
