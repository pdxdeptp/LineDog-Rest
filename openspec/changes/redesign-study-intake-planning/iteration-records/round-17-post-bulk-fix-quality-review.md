# Round 17 Review: Post Bulk-Fix Quality Review

## Reviewer Lens

The previous repair pass fixed many cross-module issues at once. This review checks whether that bulk repair left hidden contradictions or implementation ambiguity before scope splitting.

## Issues Found

1. P0: Validation failure semantics were contradictory. Some text implied unresolved repair failures could become low-calibration drafts, while the data contract said blocking validation errors cannot enter draft review.
2. P0: Low daily capacity behavior was under-specified. The design did not say how to schedule a 60-90 minute task when the user has only 30-45 minutes on available days.
3. P1: Existing-plan roles overlapped. `existing_plan_phase` and `supporting_material` blurred machine routing with attachment behavior.
4. P1: Infeasibility choices used inconsistent labels such as accept risk, accept overload, accept crunch, and accept late finish without canonical option ids.
5. P1: Split boundaries existed but child-change dependency order was not explicit.
6. P2: The UI spec still used the old "添加资料视图" requirement name.
7. P2: Compiler trace/observability was missing for debugging validation, scheduling, low calibration, and infeasibility behavior.

## Modifications Made

- Clarified that low-calibration drafts must still be structurally valid. Blocking validation failures now return `compile_failed` or `needs_input`; they cannot enter activatable draft review.
- Added low-daily-capacity scheduling rules using dated continuation sessions with parent task ids, sequence order, estimates, and visible sub-output or continuation notes.
- Reframed existing-plan handling as `attach_to_existing_plan` plus attachment modes: `material_only`, `draft_phase`, and `scheduled_work`.
- Added canonical infeasibility option ids and deterministic effects for buffer risk, overload, rough draft acceptance, one-question input, and estimate edits.
- Added recommended split dependency order: router, draft persistence, plan compiler, deadline scheduler, Add / Initiate UI.
- Renamed the UI requirement from "添加资料视图" to "添加/立项视图".
- Added compiler trace and observability requirements that avoid sensitive raw content and hidden reasoning.
- Updated tasks and tests to cover the new validation, scheduling, enum, attachment, trace, and split-order rules.

## Result

The mother design now resolves the quality concerns from the post-bulk-fix review. It is more precise about what can be reviewed, what must fail safely, how daily execution is split under real capacity limits, and which concepts child changes must preserve.
