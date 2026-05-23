# ITEM-001 Gap Analysis

## Source

- `openspec/learning-assistant-v2.md`
- US-1, US-2, US-3, US-4, US-5
- D24, D29, D30

## Reusable V1 Pieces

- Existing local backend process and HTTP client pattern.
- Existing SQLite storage for resources, units, tasks, events, and daily capacity.
- Existing URL handler dispatch and progress streaming concepts.
- Existing Swift dashboard shell and add-resource entry point.
- Existing tests for model decoding and ingestion URL validation.

## Required V2 Changes

- Introduce `study-plan` as the v2 capability contract.
- Replace "start ingestion immediately" with "URL preview -> guided clarification -> decomposition pipeline".
- Model draft plan review explicitly before activation.
- Allow user edits to task duration estimates during review.
- Make confirmation the only transition from draft/review to active daily use.
- Specify D24 deterministic initial schedule and D30 low-calibration skip path.

## Out Of Scope For This Item

- Daily today view rollout and project overview/calendar views.
- Missed-task rolling behavior, drag cascade, deadline edits, add/delete task semantics, and conversation adjustment.
- Smart mode morning briefing and multi-option proposals.
- Retiring old v1 specs.

## OpenSpec Direction

Create `introduce-study-plan-foundation` with new capability `study-plan`. Do not modify old v1 spec ids in this change; use them only as baseline context.
