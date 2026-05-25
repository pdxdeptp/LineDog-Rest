# Product Deepen Round 2: introduce-deadline-scheduler

- Automation: add-initiate-changes
- Checkpoint: introduce-deadline-scheduler:product_deepen_round_2
- Skill: opsx-product-deepen
- Result: P0 algorithm clarifications applied
- Completed at: 2026-05-25T10:59:11Z

## Change Understanding

Round 1 clarified the scheduler's review payload and status boundary. Round 2 challenged the deterministic algorithm itself: buffer math, load-shape tie-breakers, crunch versus overload, and low-energy fallback semantics.

The current boundary remains appropriate: scheduler decides dated fit and review facts; it does not activate or regenerate tasks.

## Adjacent Changes Read

- Upstream compiler contract: scheduler consumes estimates, classification, split points, fallback modes, dependencies, and reducible/depth-obligation metadata.
- Downstream UI contract: UI renders fallback and option effects, but scheduler must provide canonical facts and option ids without creating Today noise.

## Experience Loops

### Buffer Review Loop

- Goal: keep deadline plans realistic without pretending the whole window is executable time.
- Entry: date window with at least or fewer than three usable dates.
- Main path: reserve deterministic latest usable buffer days; place normal work first outside buffer.
- Success state: plan fits before buffer and returns `draft_review`.
- Failure state: essential work needs reserved buffer, so review shows buffer erosion and stays `infeasible_review`.
- Feedback: reserved buffer days, buffer erosion, no-buffer reason.
- Coverage after edits: complete.

### Low-Energy Fallback Loop

- Goal: show fallback without creating a second noisy todo or lying that full work is done.
- Entry: scheduled item has compiler-provided fallback mode.
- Main path: attach fallback minutes/output/risk effect to scheduled item.
- Success state: review can show reduced mode.
- Failure state: fallback is not counted as normal completion unless a later explicit adjustment converts the plan.
- Feedback: risk effect is `preserves_momentum`, `creates_follow_up`, or `changes_plan_risk`.
- Coverage after edits: complete.

## Deep Issues

### P0: Buffer Formula Was Too Loose

- Problem: "about 20%" and "1 usable day" left enough room for inconsistent buffer counts and unclear short-window behavior.
- Why it matters: dry-run fixtures and capacity-gap math would diverge across implementations.
- Fix applied: added deterministic buffer counts: zero below three usable days, latest one day for three to six usable days, latest ceil(20%) clamped one to five for seven or more days.
- Destination: design, spec delta, tasks.
- Scope impact: in scope.

### P0: Crunch And Overload Were Conflated

- Problem: `accept_crunch` and `accept_overload` both sounded like "do more", but they should have different capacity semantics.
- Why it matters: without this distinction, overload could silently exceed user capacity or crunch could hide overload.
- Fix applied: `accept_crunch` raises selected dates up to 100% usable capacity; `accept_overload` explicitly allows above usable capacity and keeps dates marked overloaded.
- Destination: design, spec delta, tasks.
- Scope impact: in scope.

### P0: Fallback Could Be Counted As Full Completion

- Problem: fallback mode was present but did not say whether it completes the original scheduled item.
- Why it matters: a low-energy fallback should reduce noise, not silently corrupt progress or schedule risk.
- Fix applied: fallback is review metadata with minutes/output/risk effect and does not count as full completion without a later explicit adjustment.
- Destination: design, spec delta, tasks.
- Scope impact: in scope; runtime adjustment remains downstream/future.

## Scope Decisions

### In Scope

- deterministic buffer reservation and buffer erosion;
- load-shape tie-breakers;
- crunch and overload acceptance semantics;
- fallback-mode review metadata;
- tests for the above.

### Out Of Scope

- runtime day-of adjustment after user actually chooses fallback;
- UI fallback rendering;
- auto-rebalancing existing active tasks;
- changing compiler estimates or task content.

### Deferred Upstream Dependencies

- Compiler fallback mode and split-point data must remain stable and scheduler-readable.
- Compiler-provided task identity must remain unchanged through split sessions.

### Downstream Contracts Preserved

- UI can render fallback as attached metadata, not separate tasks.
- UI can show crunch and overload as different choices with canonical ids.
- Draft persistence can store buffer erosion and overloaded-date facts for review versions.

## Product Model Review

The model now distinguishes:

- normal execution budget;
- reserved buffer;
- crunch within usable capacity;
- overload above usable capacity;
- fallback review metadata.

These distinctions reduce implementation guessing and match the first-version goal: honest, low-maintenance planning.

## Recommended Next Actions

- Must address before apply: none remaining from Round 2 after edits.
- Needs user scope decision: none.
- Future proposals: runtime fallback completion/adjustment semantics.
- Explicit non-goals: fallback usage tracking and day-of rescheduling.

