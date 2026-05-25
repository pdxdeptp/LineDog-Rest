# Cross-Change Contract: introduce-plan-compiler -> introduce-deadline-scheduler

- Automation: add-initiate-changes
- Checkpoint: introduce-plan-compiler:apply:cross-change-contract-to-introduce-deadline-scheduler
- Result: passed
- Completed at: 2026-05-25T10:49:11Z
- From change: introduce-plan-compiler
- To change: introduce-deadline-scheduler

## Evidence Read

Completed compiler change:

- `openspec/changes/introduce-plan-compiler/proposal.md`
- `openspec/changes/introduce-plan-compiler/design.md`
- `openspec/changes/introduce-plan-compiler/specs/study-intake-planning/spec.md`
- `openspec/changes/introduce-plan-compiler/tasks.md`
- `openspec/add-initiate-implementation-control/evidence/introduce-plan-compiler/apply-task-groups.json`
- `openspec/add-initiate-implementation-control/evidence/introduce-plan-compiler/apply-groups/envelope-archetype-and-depth-core.md`
- `openspec/add-initiate-implementation-control/evidence/introduce-plan-compiler/apply-groups/synopsis-llm-validation-and-repair.md`
- `openspec/add-initiate-implementation-control/evidence/introduce-plan-compiler/apply-groups/estimates-trace-fixtures-and-final-verification.md`

Downstream scheduler change:

- `openspec/changes/introduce-deadline-scheduler/proposal.md`
- `openspec/changes/introduce-deadline-scheduler/design.md`
- `openspec/changes/introduce-deadline-scheduler/specs/study-intake-planning/spec.md`
- `openspec/changes/introduce-deadline-scheduler/tasks.md`

## Handoff Payload

The completed compiler provides scheduler-ready, unscheduled planning structure:

- normalized `PlanningEnvelope` fields, including draft identity, confirmed role, attachment mode, target output, target depth, deadline, deadline type, capacity, rest/unavailable dates, buffer policy, source roles, source facts, material refs, existing-plan context, provenance, and visible assumptions;
- exactly one compiler status: `draft_review`, `needs_input`, or `compile_failed`;
- `low_calibration` and low-calibration reasons as review flags, not terminal scheduler statuses;
- selected archetype, secondary modifiers, included/excluded scope, target-depth obligations, and confidence;
- ordered phases with observable completion evidence;
- ordered executable task candidates with work type, essential/optional/stretch classification, estimates, estimate confidence/source, dependencies, material refs, normal mode, fallback mode, split points, reducible/depth-obligation reason, and assumptions;
- compiler trace facts for envelope provenance, selected boundary, validation, repair, task gates, estimate decisions, and calibration, with sensitive raw content redacted or summarized.

## Scheduler-Owned Output

The compiler intentionally does not provide or own:

- final scheduled dates;
- date-window construction;
- usable capacity or active-load math;
- planning-budget caps;
- buffer reservation or buffer erosion;
- overloaded dates;
- expected-late facts;
- capacity-gap facts;
- `infeasible_review`;
- option-effect application for `reduce_scope`, `lower_depth`, `extend_deadline`, `increase_capacity`, `accept_crunch`, `accept_buffer_risk`, `accept_overload`, `accept_late_finish`, or `store_for_later`;
- Today actions or activation writes.

The scheduler change owns those outputs and effects.

## Boundary Decisions

- The scheduler must consume compiler task candidates and estimates as its input contract. It must not recompile the source, invent missing learning content, or ask a broad LLM to return a calendar.
- The scheduler may use compiler `low_calibration` facts when mapping review options, especially `answer_one_question`, `edit_estimates`, `accept_rough_draft`, or `store_for_later`.
- The scheduler must preserve task dependency order and essential-before-optional placement using compiler task metadata.
- The scheduler may split tasks only at compiler-approved `splitPoints` or explicit multi-session boundaries. Unsplittable oversized tasks become risk facts, overload, expected-late, or capacity-gap outputs.
- `reduce_scope` may use compiler essential/optional/stretch and reducible-reason metadata, but it must preserve target output and target depth. If no optional/stretch work remains, scheduler must not present `reduce_scope` as a standalone fix.
- `lower_depth` requires a compiler cooperation/regeneration handoff because it changes target-depth obligations. The scheduler owns before/after fit math and option availability, not the new task decomposition itself.
- Hard deadlines must never expose `accept_late_finish`.
- Scheduler output must stay a review draft until the user explicitly confirms an infeasibility option or activation path.

## Cross-Change Verification

Commands run:

- `openspec validate introduce-plan-compiler --strict`: valid.
- `openspec validate introduce-deadline-scheduler --strict`: valid.
- `openspec instructions apply --change introduce-plan-compiler --json`: 31/31 tasks complete, state `all_done`.
- `openspec status --change introduce-deadline-scheduler --json`: proposal, design, specs, and tasks all present.

## Result

Contract passed. `introduce-plan-compiler` can be marked completed, and automation can advance to `introduce-deadline-scheduler:product_deepen_round_1`.

