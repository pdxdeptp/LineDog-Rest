# Round 06 Review: Anti-Task-Noise

## Reviewer Lens

The user explicitly does not want a louder system. Even if non-plan items are excluded from Today, they could still create badges, reminders, counters, or confirmation clutter.

## Issues Found

1. The design needed a stronger "one submitted item should not explode into many UI objects" rule.
2. Non-plan items needed exclusion from risk and reminder surfaces, not only Today.
3. Immediate one-off handling needed explicit user action before creating a task.

## Modifications Made

- Added a noise budget to `design.md`.
- Added scenarios to `study-intake-planning` for one-input/one-pending-object behavior and explicit one-off action creation.
- Added UI requirement that non-plan items do not create Today badges or plan-risk alerts.

## Result

The design now actively prevents add-time enthusiasm from becoming maintenance debt.
