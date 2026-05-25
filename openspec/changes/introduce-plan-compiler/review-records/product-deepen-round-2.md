# Product Deepen Round 2: Archetype, Synopsis, LLM, And Repair

## Change Understanding

Round 1 clarified the boundary contracts. Round 2 checks the actual compiler pipeline: how it chooses the shape of work, how it creates a source/goal synopsis without becoming a parser, and how LLM output is constrained by deterministic validation and repair.

Without this pass, apply could still implement a broad "generate plan" prompt with weak tests.

## Adjacent Changes Read

- Upstream: `persist-intake-plan-drafts` design/specs/tasks and Round 1 handoff constraints.
- Downstream: `introduce-deadline-scheduler` design/specs/tasks, especially scheduler inputs and scope/depth reduction expectations.

## Experience Loops

### Archetype Selection

- Goal: choose one daily-work shape before task generation.
- Entry: normalized envelope has source roles, target output/depth, and draft kind.
- Main path: apply deterministic matrix and tie-breakers.
- Success state: primary archetype, modifiers, included/excluded scope, confidence, and visible assumption.
- Failure state: `needs_input` with one archetype-focused question.
- Coverage after edits: complete.

### Thin Source Synopsis

- Goal: summarize enough source/goal facts to generate useful tasks without pretending to have parsed everything.
- Entry: source facts may be a URL, repo metadata, README headings, course modules, note snippets, or user description.
- Main path: produce goal summary, source summary, unknowns, material refs, and estimate facts.
- Success state: task generation has bounded context.
- Failure state: `needs_input` or low calibration when facts are too thin.
- Coverage after edits: complete.

### LLM Validation And Repair

- Goal: keep LLM useful but non-authoritative.
- Entry: phase/task schema output fails validation or quality gates.
- Main path: classify failure, run at most two targeted repair attempts, preserve user anchors, reject date/scope drift.
- Success state: repaired valid output or safe blocked compiler result.
- Failure state: `compile_failed` with validation errors and recovery actions.
- Coverage after edits: complete.

## Deep Issues

### P0: Archetype Selection Still Lacked Deterministic Tie-Breakers

- Problem: docs listed archetypes but did not say which signal wins in mixed cases.
- Why it matters: GitHub repos, interview prep, and project packaging often overlap; implementation could produce inconsistent plans.
- Action: added V1 selection matrix, tie-breakers, and required scope-boundary output.
- Destination: design/spec/tasks.
- Scope impact: in scope.

### P0: Source Synopsis Was Not Explicit Enough

- Problem: the compiler said it builds source/goal synopsis but not what facts it uses or how it behaves with thin inputs.
- Why it matters: a URL-only repo could trigger hallucinated file/module tasks.
- Action: added synopsis inputs/outputs and thin-source behavior.
- Destination: design/spec/tasks.
- Scope impact: in scope; does not implement parser behavior.

### P0: Repair Loop Could Mutate User Anchors

- Problem: bounded repair existed, but constraints on what repair may change were missing.
- Why it matters: repair could silently lower depth, change source role, broaden scope, or add dates.
- Action: added validation severities and repair-loop rules preserving anchors and rejecting date/scope drift.
- Destination: design/spec/tasks.
- Scope impact: in scope; narrows LLM authority.

### P0: Task Quality Gates Missed Scheduler-Critical Fields

- Problem: validation did not explicitly block missing work type/classification or out-of-scope material references.
- Why it matters: scheduler and later scope-reduction logic depend on these fields.
- Action: added blocking failures and spec scenarios for missing work type/classification and out-of-scope material.
- Destination: design/spec/tasks.
- Scope impact: in scope.

## Scope Decisions

### In Scope

- Archetype matrix and tie-breakers.
- Scope boundary output.
- Source/goal synopsis and thin-source handling.
- LLM phase/task/repair call boundaries.
- Validation severities and repair invariants.

### Out Of Scope

- Deep URL/repo/course parsing.
- Final date placement or capacity-gap math.
- UI wording for the one question.
- Existing active task movement.

### Deferred Upstream Dependencies

- Material ingestion may later provide richer source structure, but this compiler must work with shallow facts and mark calibration honestly.
- Draft persistence stores package shells; it does not guarantee clean, typed assumption values for legacy drafts.

### Downstream Contracts Preserved

- Scheduler receives no final dates from compiler.
- Scheduler can rely on `work_type`, task classification, dependency order, split points, and scope boundary metadata.
- Scheduler owns `reduce_scope`, `lower_depth` option math, and `infeasible_review`.

## Product Model Review

- The model now treats archetype as the first structural decision, not a label added after generation.
- Source synopsis is bounded: it helps generate tasks but does not become a parser or crawler.
- LLM repair is constrained enough for TDD workers to write failure-first tests.

## Recommended Next Actions

- Round 3 should verify real-context dry runs, fixture expectations, and whether tasks are grouped enough for apply without becoming too broad.
