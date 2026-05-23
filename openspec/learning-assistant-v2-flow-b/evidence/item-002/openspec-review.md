# ITEM-002 OpenSpec Readiness Review

## Scope Review

- Change: `introduce-study-views`
- New spec id: `study-views`
- Source stories: US-6, US-7, US-12, US-13, US-14
- Dependency: ITEM-001 `study-plan-foundation`

## Affected Specs

- New capability:
  - `study-views`
- Context-only existing/active specs:
  - `study-plan` from `introduce-study-plan-foundation` supplies confirmed project/task data.
  - v1 specs are not modified in this change and remain historical/parallel surfaces.

## Readiness Checks

- PASS: Proposal, design, spec, and tasks exist.
- PASS: `openspec validate introduce-study-views --strict` passes.
- PASS: `openspec status --change introduce-study-views --json` reports all required artifacts done.
- PASS: `openspec instructions apply --change introduce-study-views --json` reports state `ready`.
- PASS: Tasks are split into backend, Swift API/ViewModel, Swift UI, and App verification groups.
- PASS: Scope excludes rolling, drag/date adjustment, add/delete tasks, conversation adjustment, and smart mode.
- PASS: The spec preserves v2 boundaries: factual views only, no proactive assistant, no automatic plan repair, no LLM/morning-agent source of truth.

## Review Notes

- The proposal intentionally creates a dedicated deterministic v2 study-view API rather than extending `/api/today-briefing`.
- Automatic project "archive" is specified as a completed non-active project visible in history, avoiding confusion with user-initiated manual archive/removal.
- Calendar is read-only in this slice. Any drag/drop reschedule affordance must wait for ITEM-003.
- Implementation will touch learning assistant Swift files already touched by ITEM-001; those dirty changes are automation-owned. Before `opsx:apply`, the automation must create a checkpoint commit if no unrelated user changes are present.

## Result

- Readiness: PASS
- Next step: create a checkpoint commit, then enter `opsx:apply` for `introduce-study-views`.
