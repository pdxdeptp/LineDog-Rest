## 1. Mode Documents

- [x] 1.1 Create `docs/agent-modes/fast-path.md` for small fixes with focused verification and manual QA instructions.
- [x] 1.2 Create `docs/agent-modes/standard-path.md`, `full-delivery.md`, and `high-risk.md` for escalating rigor only when needed.

## 2. Entry Router

- [x] 2.1 Update `AGENTS.md` to route to mode files and keep mandatory invariants concise.
- [x] 2.2 Update `docs/agent-workflow.md` to explain the mode-router architecture and point to the split files.

## 3. Verification

- [x] 3.1 Run `openspec validate split-agent-workflow-modes --strict`.
- [x] 3.2 Verify the entry contract and mode files are concise and do not duplicate the full workflow inline.
