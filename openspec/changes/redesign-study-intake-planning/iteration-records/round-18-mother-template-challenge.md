# Round 18 Review: Mother Template Challenge

## Reviewer Lens

Challenge the mother design after the post-bulk-fix repair. The goal was not to expand product scope, but to find contradictions between the mother design and existing active specs that would make child changes inherit conflicting requirements.

## Issues Found

1. P0: Existing `material-ingestion` required GitHub fallback units generated from only the repo name, while the mother design required unknown repo facts to remain unknown and not fabricated.
2. P0: `ingestion-progress-sse` was affected by the new Add / Initiate async flow but was not listed or updated. The old progress model assumed only URL ingestion stages.
3. P0: `attach_review` had no explicit state exits for material-only versus scheduled existing-plan attachments.
4. P0: Capacity fallback defaults conflicted across active specs: the data layer initialized `daily_capacity_min=300`, while learning preferences and material ingestion used 60.
5. P1: `splitPoints` existed in the task JSON example and scheduler logic but was missing from the executable task candidate spec.
6. P1: GitHub repo role was first-class in product language but lacked canonical field treatment in the planning envelope and spec scenarios.
7. P1: `PlanDraftPackage` required fields did not distinguish reviewable drafts from `needs_input` or `compile_failed` packages.
8. P1: `accept_late_finish` was restricted to soft/assumed deadlines in design but not in spec/UI acceptance scenarios.
9. P2: Proposal wording still used the older supporting-material route phrasing rather than the canonical `attach_to_existing_plan` plus attachment-mode model.

## Modifications Made

- Added `ingestion-progress-sse` to affected specs and created an Add / Initiate progress-events delta.
- Modified material ingestion requirements so Add / Initiate preview does not require complete units and does not fabricate GitHub units from only the repo name.
- Kept legacy URL ingestion compatibility possible, but any fallback placeholder unit must be labeled synthetic or low-calibration and cannot become parsed repo fact for the Plan Compiler.
- Modified learning data layer initialization so the fallback `daily_capacity_min` is 60 minutes, matching learning preferences and ingestion fallback behavior.
- Clarified `attach_review` exits: `material_only` stores without compile; `draft_phase` and `scheduled_work` continue to anchor review.
- Added source roles and canonical repo roles to the planning envelope.
- Added `splitPoints` to task candidate contract and retained continuation-session scheduling rules.
- Made `PlanDraftPackage` status-specific so blocked packages do not require complete phases/tasks/schedule/risk report.
- Added hard-deadline acceptance rules excluding `accept_late_finish`.
- Updated tasks and verification items for progress events, GitHub no-fabrication, capacity fallback, package status fields, and hard-deadline options.

## Result

The mother design is now better aligned with existing active specs and safer to split. The remaining child changes should inherit one consistent model for intake preview, async progress, capacity fallback, existing-plan attachments, source roles, and draft package states.
