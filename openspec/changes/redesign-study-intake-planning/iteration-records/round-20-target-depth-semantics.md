# Round 20 Review: Target Depth Semantics

## Reviewer Lens

Check whether target depth is implemented as an operational planning constraint rather than a user-facing label.

## Issue Found

P1: The mother design listed depth choices such as skim, can-use, project-level, interview-ready, and source-understanding, but did not define what each depth changes in phases, task families, or completion evidence. This would let implementation treat depth as display text while still generating similar plans.

## Modification Made

- Added a target-depth semantics table to `design.md`.
- Defined required completion evidence and task-generation effects for each depth.
- Added interaction rules for target output, modifiers, silent depth upgrades, lowering depth, and invalid lower-depth outcomes.
- Added spec and task coverage requiring depth to change obligations and tests.

## Result

The mother design now makes target depth an executable planning input that controls what "done" means.
