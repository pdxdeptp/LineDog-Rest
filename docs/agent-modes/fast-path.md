# Fast Path

Use for small, clear fixes, polish, docs/config/copy changes, and bug fixes with a known or quickly confirmed root cause.

## Steps

1. Run `git status --short --branch`.
2. Inspect only the relevant files.
3. Make scoped edits; use TDD or a regression test when it is practical and meaningful.
4. Run focused verification such as one test, `openspec validate`, lint, build, or `git diff --check`.
5. Report the result and give manual QA steps for UI behavior.

## Defaults

- Do not create OpenSpec artifacts.
- Do not spawn subagents.
- Do not create checkpoint commits.
- Do not use Computer Use or Browser automation.
- Do not run broad test suites unless the focused check exposes risk.

## Escalate When

- Root cause is unclear after a short inspection.
- More than two production files become involved.
- The task touches persistence, Hermes contracts, data loss risk, window lifecycle, cross-module architecture, or app startup.
- The user asks for end-to-end completion, full QA, or vibe coding.
