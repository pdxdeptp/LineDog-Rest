## 1. Proposal Readiness

- [ ] 1.1 Add RED validation tests or strict OpenSpec validation checks for the new `study-plan` requirements.
- [ ] 1.2 Confirm the `study-plan` proposal, design, spec, and tasks pass `openspec validate introduce-study-plan-foundation --strict`.

## 2. Data Model And Scheduling

- [ ] 2.1 Write failing backend tests for draft study project lifecycle: created in review state, cancelled without active tasks, confirmed into active project.
- [ ] 2.2 Implement minimal draft study project persistence and activation path to pass lifecycle tests.
- [ ] 2.3 Write failing backend tests for D24 deterministic scheduling over non-rest days and over-capacity/late status.
- [ ] 2.4 Implement D24 scheduling helper and status calculation while keeping unrelated projects untouched.

## 3. Guided Clarification And Decomposition

- [ ] 3.1 Write failing backend tests for D30 guided clarification generation: max three questions, defaults, skip path, and low-calibration marker.
- [ ] 3.2 Implement the guided clarification request/response surface and fallback behavior.
- [ ] 3.3 Write failing backend tests for D29 decomposition pipeline stages and unknown-material fallback.
- [ ] 3.4 Implement the minimal pipeline orchestration needed for ordered draft tasks.

## 4. Swift API And View Model

- [ ] 4.1 Write failing Swift decoding/API-client tests for study-plan draft, clarification, duration edit, cancel, and confirm models.
- [ ] 4.2 Implement Swift API models and client methods for the study-plan draft flow.
- [ ] 4.3 Write failing view-model tests for URL intake, clarification skip/answer flow, review-state draft edits, and explicit confirmation.
- [ ] 4.4 Implement view-model state transitions for the study-plan draft flow.

## 5. Review UI And Verification

- [ ] 5.1 Write failing Swift presentation tests for the guided clarification card and draft review controls.
- [ ] 5.2 Implement the minimal add-project/review UI needed for US-1 through US-5.
- [ ] 5.3 Run relevant backend and Swift tests and record RED/GREEN/REFACTOR evidence.
- [ ] 5.4 Use Computer Use/App Use on the current checkout app path to verify URL intake, clarification, draft review, duration edit, cancel, and confirm behavior; save evidence under Flow B.
