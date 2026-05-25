## Context

The current `AGENTS.md` is 182 lines and includes both strict instructions and explanatory process detail. Agents read this file as entry context, so the most important rules should be easy to find while longer rationale remains available.

## Goals / Non-Goals

**Goals:**
- Keep `AGENTS.md` below the informal 60-line target.
- Preserve the current workflow contract and project-specific overrides.
- Move detailed rules to a stable document path that agents can read when needed.
- Make the split obvious enough that future edits do not re-expand `AGENTS.md`.

**Non-Goals:**
- Change app behavior, tests, Swift code, or OpenSpec CLI behavior.
- Relax the existing project gates.
- Rewrite unrelated project docs.

## Decisions

- Keep `AGENTS.md` as the authoritative quick contract, with only hard gates and pointers.
  - Alternative considered: deleting repeated sections without a replacement. Rejected because it would lose useful process detail.
- Store the expanded manual at `docs/agent-workflow.md`.
  - Alternative considered: `.agents/workflow.md`. Rejected because `docs/` is already the repository's established place for human-readable process and QA documents.
- Preserve the language policy and hotfix exception in `AGENTS.md`.
  - Alternative considered: moving them only to the detailed doc. Rejected because they affect every response and should remain in the entry context.

## Risks / Trade-offs

- Agents might ignore the detailed document if only the short file is loaded.
  - Mitigation: Keep all non-negotiable gates in `AGENTS.md`; the detailed document explains rather than replaces them.
- Future contributors might duplicate details back into `AGENTS.md`.
  - Mitigation: Add an explicit line-limit maintenance rule and link to the detailed workflow.
