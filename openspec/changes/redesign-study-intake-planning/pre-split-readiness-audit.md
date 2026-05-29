# Pre-Split Readiness Audit

## Purpose

This audit checks whether the mother change is now stable enough to begin `opsx:scope-decision` splitting into focused implementation changes.

## Verification Evidence

- `openspec validate redesign-study-intake-planning --strict`: valid.
- `openspec status --change redesign-study-intake-planning`: 4/4 artifacts complete.
- Iteration records: 23 files under `iteration-records/`.
- Cross-module sections exist in `design.md`, `specs/**/spec.md`, and `tasks.md`.

## Product-Deepen Gap Resolution

| Gap | Priority | Resolution | Evidence |
| --- | --- | --- | --- |
| Mother change too broad to apply directly | P0 | Captured split-ready implementation boundaries and scope-split tasks. | `design.md` `Split-Ready Implementation Boundaries`; `tasks.md` `Scope Split Readiness`; `round-16-split-readiness-review.md` |
| Missing intake/draft/compiler lifecycle state machine | P0 | Added explicit lifecycle states, cancellation, activation failure, stale activation, and recovery paths. | `design.md` `Lifecycle State Machine`; `study-intake-planning/spec.md` `Intake And Draft Lifecycle State Machine`; `round-12-state-machine-review.md` |
| Missing compiler/API data contracts | P0 | Added versioned `PlanningEnvelope`, `PlanDraftPackage`, `ValidationError`, `ScheduleRiskReport`. | `design.md` `Data Contracts`; `study-intake-planning/spec.md` `Plan Compiler Data Contracts`; `round-13-data-contract-review.md` |
| Scheduler defaults too loose | P0 | Added v1 defaults for load shape, daily budget cap, buffer, tie-breakers, optional work, and rest-day placement. | `design.md` `Deterministic Scheduling Policy`; `design.md` `Scheduler Algorithm`; `round-14-infeasibility-recompile-review.md` |
| Infeasibility options lacked deterministic effects | P0 | Added option-effect mapping for reduce scope, lower depth, extend deadline, increase capacity, crunch, store later, and soft late finish. | `design.md` `Infeasibility Option Effects`; `study-intake-planning/spec.md` `Infeasibility Options`; `round-14-infeasibility-recompile-review.md` |
| Draft editing/recompile rules missing | P1 | Added rules distinguishing schedule-only edits, task-regeneration edits, and non-plan edits; every change creates a draft version. | `design.md` `Draft Editing And Recompile Rules`; `study-intake-planning/spec.md` `Draft Versioning And Recompile Rules`; `tasks.md` `3.11` |
| Role confidence/one-question clarification needed clearer model | P1 | Existing one-question routing remains; confidence is retained as UI/API field and lifecycle now clarifies role review. | `assistant-panel-ui/spec.md` role confirmation; `tasks.md` `5.3`; `design.md` lifecycle state `role_review` |
| Existing-plan phase semantics ambiguous | P1 | Added material-only, draft-phase, and scheduled-work attachment modes with activation rules. | `design.md` `Existing Plan Attachment Semantics`; `study-intake-planning/spec.md` `Existing Plan Attachment Semantics`; `round-15-existing-plan-fallback-ux-review.md` |
| Low-energy fallback follow-up unclear | P1 | Added fallback completion persistence and `needs_followup` semantics separate from full completion. | `design.md` `Low-Energy Fallback Completion Semantics`; `learning-data-layer/spec.md` `Fallback Progress Persistence`; `study-intake-planning/spec.md` fallback scenarios |
| UI loading/progress/retry missing | P1 | Added stage-level progress and recovery paths for preview, LLM, validation, scheduling, and activation failures. | `design.md` `Async Feedback, Retry, And Recovery`; `assistant-panel-ui/spec.md` progress/failure scenarios; `study-intake-planning/spec.md` async recovery |
| Dry-run examples should become fixtures | P2 | Added compiler dry-run acceptance requirements and explicit test tasks. | `design.md` `Real-Context Dry Runs`; `study-intake-planning/spec.md` `Compiler Dry-Run Acceptance Examples`; `tasks.md` `6.7` |
| Privacy/provider boundary needed | P2 | Added sensitive input and no broad-vault submission constraints. | `design.md` `Privacy And Provider Boundary`; `study-intake-planning/spec.md` `Sensitive Input Boundary` |
| Validation failure semantics ambiguous after bulk repair | P0 | Clarified that low-calibration drafts must be structurally valid; blocking validation failures return `compile_failed` or `needs_input` and cannot be activatable. | `design.md` `Repair loop`; `design.md` `ValidationError`; `study-intake-planning/spec.md` validation scenarios; `round-17-post-bulk-fix-quality-review.md` |
| Low daily capacity scheduling underspecified | P0 | Added continuation-session rules for tasks that exceed daily planning budget and infeasibility reporting for unsplittable tasks. | `design.md` `Scheduler Algorithm`; `study-intake-planning/spec.md` scheduler scenarios; `tasks.md` `3.14`; `round-17-post-bulk-fix-quality-review.md` |
| Existing-plan route and supporting-material mode overlapped | P1 | Reframed existing-plan handling as `attach_to_existing_plan` plus `material_only`, `draft_phase`, or `scheduled_work`. | `design.md` `Decision 1`; `design.md` `Existing Plan Attachment Semantics`; `learning-data-layer/spec.md`; `round-17-post-bulk-fix-quality-review.md` |
| Infeasibility option labels inconsistent | P1 | Added canonical option ids and deterministic effects for buffer risk, overload, rough draft, one-question input, and estimate edits. | `design.md` `Infeasibility Decision Matrix`; `design.md` `Infeasibility Option Effects`; `study-intake-planning/spec.md`; `tasks.md` `3.9`; `round-17-post-bulk-fix-quality-review.md` |
| Child change dependency order missing | P1 | Added recommended split order and explicit prohibition on divergent role/option/version/validation rules. | `design.md` `Split-Ready Implementation Boundaries`; `tasks.md` `7.3`; `round-17-post-bulk-fix-quality-review.md` |
| UI requirement name still implied material-first framing | P2 | Renamed "添加资料视图" to "添加/立项视图". | `assistant-panel-ui/spec.md`; `round-17-post-bulk-fix-quality-review.md` |
| Compiler trace missing | P2 | Added trace/observability requirements for validation, repair, estimates, scheduling, risk, and option generation without sensitive raw content. | `design.md` `Compiler Trace And Observability`; `study-intake-planning/spec.md`; `tasks.md` `3.15`, `6.12`; `round-17-post-bulk-fix-quality-review.md` |
| Existing GitHub ingestion fallback contradicted no-fabrication rule | P0 | Modified material-ingestion so Add / Initiate preview leaves unknown structure unknown and legacy placeholder units are labeled synthetic/low-calibration. | `material-ingestion/spec.md` `GitHub 结构提取`; `round-18-mother-template-challenge.md` |
| Add / Initiate async flow omitted ingestion-progress-sse | P0 | Added `ingestion-progress-sse` as affected spec and defined Add / Initiate progress events separate from the legacy URL sequence. | `proposal.md`; `ingestion-progress-sse/spec.md`; `round-18-mother-template-challenge.md` |
| `attach_review` had unclear exits | P0 | Added material-only exit to stored non-plan and draft/scheduled-work exit to anchor review. | `design.md` `Lifecycle State Machine`; `study-intake-planning/spec.md`; `round-18-mother-template-challenge.md` |
| Capacity fallback defaults conflicted | P0 | Unified fallback `daily_capacity_min` at 60 minutes across data initialization, preferences, ingestion fallback, and scheduler assumptions. | `learning-data-layer/spec.md`; `design.md`; `study-intake-planning/spec.md`; `tasks.md` `1.7`; `round-18-mother-template-challenge.md` |
| Source roles and split points were underspecified | P1 | Added canonical source/repo roles to the planning envelope and `splitPoints` to task candidate contract. | `design.md` `PlanningEnvelope`; `study-intake-planning/spec.md`; `round-18-mother-template-challenge.md` |
| Draft package fields ignored status differences | P1 | Clarified common versus status-specific fields for `draft_review`, `infeasible_review`, `needs_input`, and `compile_failed`. | `design.md` `PlanDraftPackage`; `study-intake-planning/spec.md`; `tasks.md` `3.16`; `round-18-mother-template-challenge.md` |
| Hard deadline late-finish option was under-guarded | P1 | Added requirements that hard deadlines do not expose `accept_late_finish`. | `design.md` `Infeasibility Option Effects`; `study-intake-planning/spec.md`; `assistant-panel-ui/spec.md`; `tasks.md` `3.17`; `round-18-mother-template-challenge.md` |
| Archetype selection remained too implicit | P1 | Added deterministic selection inputs, archetype matrix, ambiguity rules, scope boundary output, confidence, and secondary modifiers. | `design.md` `Decision 4`; `study-intake-planning/spec.md`; `tasks.md` `3.2a`; `round-19-archetype-scope-deepening.md` |
| Target depth was still mostly a label | P1 | Added operational semantics for skim, can-use, project-level, interview-ready, and source-understanding depths, including completion evidence and task-generation effects. | `design.md` `Decision 3`; `study-intake-planning/spec.md`; `tasks.md` `3.2b`; `round-20-target-depth-semantics.md` |
| Estimate normalization lacked concrete rules | P1 | Added estimate source priority, default estimate table, concrete source-fact defaults, outlier handling, confidence rules, and low-calibration threshold. | `design.md` `Estimate Normalization Rules`; `study-intake-planning/spec.md`; `tasks.md` `3.6a`; `round-21-estimate-normalization-deepening.md` |
| Scope/depth reduction could still become arbitrary pruning | P1 | Added essential/optional/stretch/support-only classification, reduce-scope removal order, adjacent depth transitions, and before/after audit facts. | `design.md` `Scope Reduction And Depth Lowering Rules`; `study-intake-planning/spec.md`; `tasks.md` `3.12a`; `round-22-scope-depth-reduction.md` |
| Real-context examples lacked end-to-end capacity math | P1 | Added one feasible and one infeasible dry run with deadline, capacity, normalized minutes, buffer, schedule, and option math. | `design.md` `End-To-End Dry Runs With Capacity Math`; `study-intake-planning/spec.md`; `tasks.md` `6.7c`; `round-23-end-to-end-dry-runs.md` |

## Remaining Non-Blocking Work

- Child changes have been created by `opsx:scope-decision`: `introduce-study-intake-router`, `persist-intake-plan-drafts`, `introduce-plan-compiler`, `introduce-deadline-scheduler`, and `redesign-add-initiate-ui`.
- Each child change still needs its own pre-apply planning before implementation.
- Implementation details such as physical table names, exact endpoint paths, and prompt text belong in child changes, not this mother design.

## Readiness Decision

Status: **SPLIT COMPLETE; CHILD CHANGES NEED PRE-APPLY PLANNING**

The mother document now resolves the cross-module P0/P1/P2 design gaps that would otherwise make child changes inconsistent. The next step is pre-apply planning on the first child change, `introduce-study-intake-router`.
