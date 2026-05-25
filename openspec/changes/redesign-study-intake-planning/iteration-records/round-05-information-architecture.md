# Round 05 Review: Information Architecture

## Reviewer Lens

The design introduces many roles. Without a clear object model, implementation may collapse everything back into resources/tasks and recreate the original noise problem.

## Issues Found

1. `intake item`, `plan`, `phase`, `task`, `material`, `reference`, and `later resource` needed canonical relationships.
2. The old `resource` concept could leak into the new model and make every source look schedulable.
3. The data layer needed explicit constraints for Today eligibility.

## Modifications Made

- Added a canonical entity map to `design.md`.
- Added entity relationship constraints to `learning-data-layer` spec.
- Clarified that executable tasks are the only entities eligible for Today.

## Result

The information architecture now structurally protects the product goal: sources can support plans without becoming tasks.
