# Round 13 Review: Data Contracts And Versioning

## Reviewer Lens

The compiler, scheduler, UI, and persistence layer need stable contracts. Examples are not enough; the design needs versioning, stale activation rules, and validation error structure.

## Issues Found

1. `PlanningEnvelope` and `PlanDraftPackage` existed as concepts but not as required logical contracts.
2. Draft edits had no versioning model.
3. Validation errors were not contractually shaped for UI and repair handling.

## Modifications Made

- Added `Data Contracts` to `design.md`.
- Added `Plan Compiler Data Contracts` and `Draft Versioning And Recompile Rules` requirements.
- Updated `learning-data-layer/spec.md` with schema version, draft version, stale activation rejection, and version persistence.

## Result

The design now gives split changes a stable contract surface: router produces envelope facts, compiler returns draft packages, scheduler returns risk reports, and activation checks draft versions.
