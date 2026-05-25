## Context

The current learning assistant has useful plumbing but the wrong product center of gravity. V1 imports learning materials through a LangGraph ingestion agent, presents A/B schedule options, writes resources/units/tasks after confirmation, and then relies on morning/conversational/weekly agents around that data. V2 needs a stricter foundation: a study-plan calendar where the user owns the plan, LLM work is bounded, and confirmation is explicit.

This change introduces the first v2 slice, `study-plan`, from US-1 through US-5. Later slices will build today views, plan adjustment, and smart mode on top of it.

## Goals / Non-Goals

**Goals:**

- Establish the v2 `study-plan` capability contract.
- Define daily capacity as a first-class input to scheduling.
- Define URL -> guided clarification -> decomposition pipeline -> draft plan.
- Define deterministic initial scheduling and review-state activation.
- Preserve user control: draft plans do not affect daily use until confirmed.

**Non-Goals:**

- Daily today view, project overview, and calendar UI beyond what is needed to review the draft.
- Rolling unfinished tasks, drag cascade, deadline edits after activation, add/delete task behavior, and conversation adjustment.
- Smart mode, morning briefing, and multi-option suggestions.
- Retiring old v1 learning specs.
- Full replacement of every v1 backend table in one step.

## Decisions

### Decision 1: Introduce `study-plan` as a new v2 spec

V2 is a product/architecture reset, not a patch to the v1 agent specs. The new spec makes the desired behavior legible without forcing `material-ingestion`, `daily-morning-agent`, or `conversational-planner` to carry incompatible semantics.

Alternative considered: modify `material-ingestion` directly. Rejected because it preserves the v1 framing and makes future retirement harder.

### Decision 2: Keep one active draft plan before confirmation

The first slice should support a draft/review/active lifecycle. Generated tasks are inspectable and editable, but they do not enter daily use until confirmation.

This maps directly to US-3 through US-5 and prevents the v1 failure mode where agent output becomes operational before the user has shaped it.

### Decision 3: Guided clarification is a pre-parse card, not a chat

D30 is implemented as a bounded form step after URL preview. It asks at most three questions and has a skip path. This avoids turning add-project into an open-ended conversation while still reducing one-shot parse errors.

### Decision 4: D24 scheduling is deterministic and honest

The initial scheduler spreads task minutes across non-rest days in the date window. It does not inspect other projects to avoid red states and does not auto-repair overload. Status flags are facts for review, not commands to mutate the plan.

### Decision 5: Reuse v1 infrastructure cautiously

The existing backend can provide URL fetching, handler dispatch, duration estimation, SQLite persistence, and Swift API patterns. Implementation should avoid entangling new v2 behavior with autonomous agent entry points. Shared helpers are acceptable; v1 agent behaviors should not become hidden dependencies of v2.

## Risks / Trade-offs

- **Risk: Scope expands into all v2 learning behavior.** -> Keep this change limited to US-1 through US-5 and explicitly defer views/adjustments/smart mode.
- **Risk: Existing v1 tables cannot express draft/review state cleanly.** -> Add minimal draft/project state needed by `study-plan`; avoid destructive migrations until tests prove the shape.
- **Risk: Guided clarification UI slows down adding a project.** -> Keep it skippable with recommended defaults and mark skipped plans as low-calibration drafts.
- **Risk: D24 creates red/overloaded days.** -> This is intended v2 behavior; review UI should show facts rather than silently rescheduling.
- **Risk: App verification is hard because multiple MalDaze builds share a bundle id.** -> Target the current checkout app path for Computer Use verification and record screenshots/evidence after implementation.

## Migration Plan

1. Add v2 models and scheduling/decomposition surfaces alongside existing v1 code.
2. Route the add-project flow for `study-plan` through draft/review semantics.
3. Keep v1 agent endpoints available until later v2 slices replace their user-facing entry points.
4. Checkpoint before implementation and avoid worktrees per automation constraint.

Rollback strategy: because this change is additive at the spec stage and implementation will be TDD-scoped, rollback can revert the v2 study-plan files/API additions without deleting v1 learning assistant behavior.

## Open Questions

None for this slice. Future slices may refine active daily views, adjustment behavior, and smart mode.
