## 1. Envelope And Scope

- [x] 1.1 Implement normalized `PlanningEnvelope` creation from confirmed role, anchors, source summaries, existing plan context, source roles, and provenance.
- [x] 1.2 Implement compiler result statuses `draft_review`, `needs_input`, and `compile_failed`, with `low_calibration` as a review flag and no scheduler-owned `infeasible_review`.
- [x] 1.3 Implement archetype selection matrix for finite learning, recurring practice, topic review, rebuild/clone, project packaging, and existing-project phase.
- [x] 1.4 Implement deterministic archetype tie-breakers for mixed signals and `needs_input` behavior when daily-work shape remains ambiguous.
- [x] 1.5 Implement secondary modifiers, included/excluded material scope boundary, confidence, and one-question ambiguity handling.
- [x] 1.6 Implement target-depth semantics for skim, can-use, project-level, interview-ready, and source-understanding.

## 2. Phase And Task Generation

- [x] 2.1 Implement source/goal synopsis generation from shallow source facts and confirmed target output.
- [x] 2.2 Implement thin-source handling that returns one `needs_input` question or low-calibration output instead of inventing precise source structure.
- [x] 2.3 Implement structured LLM phase generation with observable completion evidence.
- [x] 2.4 Implement structured LLM task candidate generation with output, criteria, work type, essential/optional/stretch classification, estimate, dependencies, fallback, split points, depth-obligation or reducible reason, and assumptions.
- [x] 2.5 Reject or ignore LLM-generated date placement.

## 3. Validation And Estimates

- [x] 3.1 Implement schema validation and task quality gates.
- [x] 3.2 Implement validation severity classification for blocking, repairable, and warning failures.
- [x] 3.3 Implement bounded repair loop that fixes only cited failures and preserves user anchors, target depth, source role, selected plan, and no-date constraints.
- [ ] 3.4 Implement estimate normalization source priority and v1 work-type defaults.
- [ ] 3.5 Implement estimate outlier replacement, confidence assignment, oversized split requirements, and low-calibration threshold.
- [ ] 3.6 Implement compiler trace records for envelope, validation, repair, task gates, estimates, and calibration.
- [ ] 3.7 Implement sensitive-content boundaries for LLM prompts, trace records, validation errors, and prompt logs.

## 4. Tests

- [x] 4.1 Add envelope normalization tests.
- [x] 4.2 Add compiler status tests proving `needs_input` and `compile_failed` can persist without complete phases/tasks and compiler never returns scheduler-owned `infeasible_review`.
- [x] 4.3 Add archetype-selection tests for mixed GitHub cases such as `easyagent` as rebuild target versus interview-learning source.
- [x] 4.4 Add archetype tie-breaker tests proving target output, target depth, source role, and existing-plan draft kind precedence.
- [x] 4.5 Add source/goal synopsis tests for thin GitHub URL, course/module facts, Obsidian note snippets, and existing-plan context.
- [x] 4.6 Add target-depth tests proving the same source produces different obligations.
- [x] 4.7 Add LLM contract tests for phase/task schema validation and forbidden date fields.
- [x] 4.8 Add repair tests proving repair cannot change user anchors or expand scope.
- [x] 4.9 Add bounded repair failure tests.
- [ ] 4.10 Add estimate-normalization tests for user estimates, source facts, defaults, LLM outliers, oversized tasks, and low calibration thresholds.
- [ ] 4.11 Add dry-run compiler tests for AgentGuide, easyagent, LeetCode, interview prep, and resume/project packaging before scheduling.
- [ ] 4.12 Add privacy/redaction tests proving private notes, resume text, repo descriptions, and prompt logs are bounded or summarized in trace.
- [ ] 4.13 Add fixture tests proving real-context compiler outputs contain no scheduled dates, capacity-gap math, buffer erosion, overloaded dates, or compiler-owned `infeasible_review`.
