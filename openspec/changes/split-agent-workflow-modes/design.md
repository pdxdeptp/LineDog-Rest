## Context

`AGENTS.md` is already intended to be compact, but it still encodes one heavy pipeline as the normal path. The result is high-quality but slow execution for small fixes. The new structure should reduce token load by making `AGENTS.md` a router and moving each workflow mode into a separate file that is read only when selected.

## Goals / Non-Goals

**Goals:**

- Default agents to a fast path for small, clear fixes.
- Preserve full OpenSpec, TDD, and review rigor for high-risk or explicitly delegated end-to-end work.
- Avoid a large mode matrix inside `AGENTS.md`.
- Make Computer Use opt-in or risk-triggered.

**Non-Goals:**

- Remove OpenSpec from the project.
- Change Hermes SSOT/read-only UI rules.
- Change application code.
- Define every possible edge case in `AGENTS.md`.

## Decisions

- `AGENTS.md` becomes the router and invariant list.
  - Rationale: agents always read it, so it must stay small and bias toward the lightest safe path.

- Add `docs/agent-modes/fast-path.md`, `standard-path.md`, `full-delivery.md`, and `high-risk.md`.
  - Rationale: only the chosen mode needs detailed steps. This avoids reading a full manual for every small task.

- Keep `docs/agent-workflow.md` as the expanded reference.
  - Rationale: detailed rationale, examples, and legacy gates remain available without bloating entry context.

- Manual QA instructions are the default for UI changes; Computer Use is reserved for explicit end-to-end validation, vibe coding, or when UI evidence cannot be obtained otherwise.
  - Rationale: most desktop UI checks are faster and more trustworthy when the user performs them directly.

## Risks / Trade-offs

- [Risk] Agents may under-escalate a risky task. -> Mitigate with explicit escalation triggers in `AGENTS.md` and each mode file.
- [Risk] Mode files drift from the reference document. -> Mitigate by keeping mode files short and linking the expanded reference for detail.
- [Risk] Existing active agents may remember the old pipeline. -> Mitigate by putting the default-light routing rule near the top of `AGENTS.md`.
