## 1. Envelope And Scope

- [ ] 1.1 Implement normalized `PlanningEnvelope` creation from confirmed role, anchors, source summaries, existing plan context, source roles, and provenance.
- [ ] 1.2 Implement archetype selection matrix for finite learning, recurring practice, topic review, rebuild/clone, project packaging, and existing-project phase.
- [ ] 1.3 Implement secondary modifiers, included/excluded material scope boundary, confidence, and one-question ambiguity handling.
- [ ] 1.4 Implement target-depth semantics for skim, can-use, project-level, interview-ready, and source-understanding.

## 2. Phase And Task Generation

- [ ] 2.1 Implement source/goal synopsis generation from shallow source facts and confirmed target output.
- [ ] 2.2 Implement structured LLM phase generation with observable completion evidence.
- [ ] 2.3 Implement structured LLM task candidate generation with output, criteria, estimate, dependencies, fallback, split points, and assumptions.
- [ ] 2.4 Reject or ignore LLM-generated date placement.

## 3. Validation And Estimates

- [ ] 3.1 Implement schema validation and task quality gates.
- [ ] 3.2 Implement bounded repair loop with blocking, repairable, and warning severities.
- [ ] 3.3 Implement estimate normalization source priority and v1 work-type defaults.
- [ ] 3.4 Implement estimate outlier replacement, confidence assignment, oversized split requirements, and low-calibration threshold.
- [ ] 3.5 Implement compiler trace records for envelope, validation, repair, task gates, estimates, and calibration.

## 4. Tests

- [ ] 4.1 Add envelope normalization tests.
- [ ] 4.2 Add archetype-selection tests for mixed GitHub cases such as `easyagent` as rebuild target versus interview-learning source.
- [ ] 4.3 Add target-depth tests proving the same source produces different obligations.
- [ ] 4.4 Add LLM contract tests for phase/task schema validation and forbidden date fields.
- [ ] 4.5 Add bounded repair failure tests.
- [ ] 4.6 Add estimate-normalization tests for user estimates, source facts, defaults, LLM outliers, oversized tasks, and low calibration.
- [ ] 4.7 Add dry-run compiler tests for AgentGuide, easyagent, LeetCode, interview prep, and resume/project packaging before scheduling.
