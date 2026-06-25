# AGENTS.md

Compact project contract. Expanded detail lives in `docs/agent-workflow.md`; mode-specific operating rules live in `docs/agent-modes/`.

## Always
- Cross-repo Hermes coupling (canonical, maintain here only): `docs/integrations/hermes.md`. Hermes side is pointer-only: `~/.hermes/docs/integrations/maldaze.md`.
- **Hermes contract boundaries (MalDaze)**: Hermes JSON/contract remains the source of truth. MalDaze may perform explicitly contracted write actions through Hermes commands, but never add client-side suppression, optimistic hiding, shadow lists, or local filters to mask backend recalculation.
- **SSOT, no shadow copies**: Prefer one authoritative store per fact; derive or read from it instead of caching the same field in profile/defaults/a second JSON.
- Output in Chinese; reason in English unless code or technical terms require English.
- Protect user work: never reset, revert, overwrite, merge, rebase, or discard user changes without explicit permission.
- Choose the lightest workflow that protects user work and gives verifiable evidence.

## Workflow Router
- **Default: Fast Path** for small, clear fixes, polish, docs/config/copy changes, and known-root-cause bugs. Read `docs/agent-modes/fast-path.md`.
- **Standard Path** for moderate user-visible behavior, several-file changes, or small features. Read `docs/agent-modes/standard-path.md`.
- **Full Delivery** only when the user asks for end-to-end completion, full QA, "you verify it", or vibe coding. Read `docs/agent-modes/full-delivery.md`.
- **High Risk** for Hermes contracts, SSOT/persistence, data loss risk, window lifecycle, unclear root cause, cross-module architecture, concurrency, or app startup. Read `docs/agent-modes/high-risk.md`.
- Do not read every mode file by default; load only the selected mode and escalate when its trigger appears.

## Git Safety
- Before implementation, run `git status --short --branch`.
- Work in the current checkout by default because this desktop app often needs local manual QA.
- Avoid overlapping existing user changes unless the user approves.
- Use checkpoint commits or worktrees only when the selected mode calls for them; never include unrelated user changes without approval.

## OpenSpec And Tests
- Fast Path may skip OpenSpec when it restores existing behavior or only changes docs/config/copy; still run focused verification.
- Standard and High Risk paths use OpenSpec when product behavior, requirements, contracts, or architecture change.
- Prefer RED -> GREEN -> REFACTOR for behavior changes when a meaningful failing test can be written.
- Documentation-only changes may use `openspec validate`, link checks, source inspection, or `git diff --check` instead of TDD.

## UI Verification
- Default to giving concise manual QA steps for UI/UX changes.
- Use Computer Use/Browser only when the selected mode calls for agent-side UI verification, the user asks for it, or manual QA would miss critical evidence.

## Completion
- Before saying done, run fresh relevant checks and report exact results.
- For UI/UX changes, state whether agent-side UI verification was performed or provide manual QA steps.
- Present commit/PR/keep-uncommitted options only when useful or requested.
