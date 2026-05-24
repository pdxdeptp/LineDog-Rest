## 1. Proposal Readiness

- [x] 1.1 Record ITEM-004 v1/current-state observation and gap analysis under Flow B evidence.
- [x] 1.2 Confirm `introduce-study-smart-mode` proposal, design, specs, and tasks pass `openspec validate introduce-study-smart-mode --strict`.
- [x] 1.3 Run readiness review for scope, dependencies, split risk, v1 isolation, and consistency with Flow A decisions US-17~19 and D14-D19/D28.

## 2. Backend Smart Mode Setting

- [x] 2.1 Write failing backend tests for off-by-default smart-mode setting persistence and disabled smart-mode suppression.
- [x] 2.2 Implement minimal smart-mode setting storage and routes.

## 3. Backend Smart Snapshot And Morning Briefing

- [x] 3.1 Write failing backend tests for a fact-only smart snapshot built from v2 Today, Project Overview, Calendar, rollover, expected-late, and over-capacity facts.
- [x] 3.2 Implement smart snapshot and morning briefing service/route without calling the v1 Morning Agent.
- [x] 3.3 Write failing backend tests for quiet no-issue briefing and issue detection for lag, expected-late, and over-capacity.
- [x] 3.4 Implement deterministic smart briefing payloads and morning trigger eligibility.

## 4. Backend Proposal Generation

- [x] 4.1 Write failing backend tests for morning proposal options from rolled-task lag, expected-late projects, and over-capacity days.
- [x] 4.2 Implement structured smart proposal option generation with side-by-side candidate previews and red-state impact.
- [x] 4.3 Write failing backend tests for after-adjustment proposals triggering only on newly created expected-late or over-capacity red state.
- [x] 4.4 Implement after-adjustment proposal generation and ensure lag alone does not trigger this path.

## 5. Backend Proposal Apply

- [ ] 5.1 Write failing backend tests for applying exactly the selected current smart proposal and recording smart-mode event evidence.
- [ ] 5.2 Implement proposal apply with refreshed fact recomputation, stable signature comparison, mutation, and view refresh contract.
- [ ] 5.3 Write failing backend tests for stale, unsupported, and disabled smart-mode apply requests.
- [ ] 5.4 Implement stale/disabled proposal rejection without mutation.

## 6. Swift API And ViewModel

- [ ] 6.1 Write failing Swift model/client tests for smart-mode setting, briefing, proposal generation, and proposal apply endpoints.
- [ ] 6.2 Implement Swift API models, protocol methods, mock support, and concrete client calls.
- [ ] 6.3 Write failing ViewModel tests for default-mode silence, enabled smart briefing fetch, proposal ignore/apply state, and after-adjustment red-state trigger gating.
- [ ] 6.4 Implement ViewModel smart-mode state, refresh sequencing, stale proposal handling, and apply refresh behavior.

## 7. Swift UI

- [ ] 7.1 Write failing presentation/source tests for Settings smart-mode toggle, smart morning briefing surface, side-by-side proposal cards, per-option Apply, and Ignore.
- [ ] 7.2 Implement minimal smart-mode UI surfaces in Settings, Today/dashboard, and adjustment context.
- [ ] 7.3 Write failing source/ViewModel tests proving default-mode red states remain fact-only and smart mode does not use legacy chat state.
- [ ] 7.4 Implement UI guards so default mode does not show smart proposals and smart-mode UI does not set `chatMessages` or `currentProposal`.

## 8. Review And Verification

- [ ] 8.1 Run relevant backend and Swift tests and record RED/GREEN/REFACTOR evidence.
- [ ] 8.2 Run `openspec validate introduce-study-smart-mode --strict`.
- [ ] 8.3 Use Computer Use/App Use on the current checkout app path to verify smart-mode toggle, fact-only briefing, proposal display, ignore, selected Apply, default-mode silence, and v1 Morning Agent/chat isolation; save evidence under Flow B.
