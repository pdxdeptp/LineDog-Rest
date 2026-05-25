# Round 19 Review: Archetype And Scope Deepening

## Reviewer Lens

Check whether the mother design says enough about how the Plan Compiler chooses a plan archetype before task generation.

## Issue Found

P1: The design listed archetypes and said the compiler should choose one, but did not define the selection inputs, tie-breakers, ambiguity behavior, or the scope boundary output. This could make child implementation guess how to handle mixed cases such as a GitHub repo that is both a learning source, rebuild target, and interview material.

## Modification Made

- Added an archetype selection matrix to `design.md`.
- Added selection inputs based on confirmed role, source roles, target output, target depth, source type, existing plan, and user constraints.
- Added ambiguity rules for route ambiguity, multi-archetype plan ambiguity, and low-impact wording ambiguity.
- Added required scope boundary output: primary archetype, secondary modifiers, included/excluded materials, confidence, and visible assumption.
- Added spec and task coverage for archetype selection tests.

## Result

The mother design now gives child changes a concrete model for choosing one primary daily-work shape without losing secondary intent.
