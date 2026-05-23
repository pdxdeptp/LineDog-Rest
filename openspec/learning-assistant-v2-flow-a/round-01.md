# Flow A Round 01

**Time:** 2026-05-23T14:45:27.779Z
**Mode:** opsx:explore
**Git baseline:** `dd325b4`
**Git status at start:** clean
**Input hash:** `e66ed24b352f030df85d8aefd3ef6314fbcafd2e`
**Output hash:** `d83fb77602961d4f3a9c3e17c307c6b499eb987b`

## Snapshot

The current v2 document had one active unresolved design area: OQ3, covering parse quality and the UX details of guided clarification before URL -> plan generation.

Active OpenSpec changes were inspected via `openspec list --json`. None directly blocked Flow A. The relevant next v2 slice remains `study-plan`.

## Role Review

### PM

OQ3 blocks `study-plan` because US-2 cannot be specified until the parse flow is clear. The product risk is not whether questions exist, but whether the first-run flow becomes a long interview. The best product shape is a single skippable calibration step with defaults.

### User Proxy

The user proxy approved a lightweight guided clarification card. The proxy rejected both extremes: no questions leaves the plan too guessed, while a full interview repeats the v1 feeling of the assistant becoming its own system.

### Engineer

The decision needs to be deterministic enough for tests. Material-type templates should provide the question skeleton, while LLM preview fills concrete options. Unknown material types can use a generic fallback. This supports TDD for prompt orchestration and UI state separately.

### QA

The key acceptance paths are: two-question simple content path, three-question complex content path, skip path, unknown type fallback, and low-calibration marker on skipped plans. Each can become a Scenario in `study-plan`.

## Decision Applied

OQ3 was closed by adding D30 and rewriting US-2 to include a guided clarification card before D29 decomposition.

## Consistency Audit

- Default mode still does not proactively talk; guided clarification is triggered only by user-submitted URL.
- LLM remains constrained to URL -> initial plan and user-initiated adjustment.
- The skip path preserves user control.
- The low-calibration marker is a status signal, not an automatic correction.
- D30 does not introduce auto-rescheduling, reminders, or autonomous agent behavior.

## Next Step

Flow A readiness is PASS. The controller state has moved to `flow-b`. The next heartbeat should begin Flow B by building the `study-plan` implementation item queue and entering the OpenSpec hard flow.
