# Migration: Require Three Product-Deepen Rounds

- Timestamp: 2026-05-25T03:56:29Z
- Automation: add-initiate-changes
- Migration id: require-three-product-deepen-rounds
- Previous checkpoint: introduce-study-intake-router:former_pre_apply_gate
- New checkpoint: introduce-study-intake-router:product_deepen_round_3

## Reason

The automation prompt now requires three product-deepen rounds before apply. The local control files are authoritative during automation runs, so `state.json`, `runbook.md`, and `progress.md` must match that rule.

## Decision

Round 1 and round 2 evidence remain valid. The next required checkpoint is round 3 for `introduce-study-intake-router`; apply must wait until round 3 has independent review evidence and strict OpenSpec validation.
