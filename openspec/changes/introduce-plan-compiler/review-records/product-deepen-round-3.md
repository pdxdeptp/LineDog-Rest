# Product Deepen Round 3: Real Fixtures And Sensitive Content

## Change Understanding

Rounds 1 and 2 made the compiler implementable as a bounded pipeline. Round 3 checks whether the child change is anchored to the user's real planning objects and whether LLM/source handling stays inside the first-version privacy and scope boundaries.

The remaining risk was that apply could pass abstract tests while failing the actual items this assistant is for: AgentGuide, easyagent, LeetCode, agent/backend interview prep, and resume/project packaging.

## Adjacent Changes Read

- Upstream: `persist-intake-plan-drafts` handoff, especially shallow source facts, assumptions, and package persistence.
- Downstream: `introduce-deadline-scheduler` scheduler inputs, risk reports, and end-to-end dry-run ownership.
- Mother design/background: real planning context and dry-run examples from `redesign-study-intake-planning`.

## Experience Loops

### Real-Context Compiler Fixture

- Goal: prove the compiler creates concrete, scheduleable task candidates for the user's real objects.
- Entry: fixture envelope for AgentGuide, easyagent, LeetCode, interview prep, or resume packaging.
- Main path: select archetype, build synopsis, generate phases/tasks, validate estimates and quality, return unscheduled compiler package.
- Success state: concrete outputs and evidence, no dates or schedule risk.
- Failure state: `needs_input`, `compile_failed`, or low calibration when source facts are too thin.
- Coverage after edits: complete.

### Sensitive Input Handling

- Goal: avoid turning Plan Compiler into broad local-context ingestion.
- Entry: resume text, interview notes, private project notes, private repo description, or Obsidian snippet.
- Main path: use selected/submitted content and shallow facts only; summarize/redact in traces and logs.
- Success state: bounded LLM prompt and safe trace.
- Failure state: `needs_input` or low calibration instead of over-reading.
- Coverage after edits: complete.

## Deep Issues

### P0: Real Fixtures Were Mentioned But Not Specified In This Child Change

- Problem: tasks named AgentGuide/easyagent/LeetCode/interview/resume dry runs, but design/spec did not define what each fixture must prove.
- Why it matters: apply could implement passing generic compiler tests while missing the actual use cases from the user's planning context.
- Action: added `Real-Context Compiler Fixtures` to design and fixture scenarios to the spec.
- Destination: design/spec/tasks.
- Scope impact: in scope; acceptance tests only, no scheduler ownership.

### P0: Compiler Fixtures Could Accidentally Include Scheduler Outputs

- Problem: the mother design has end-to-end capacity-math dry runs, but this child change must stop before scheduling.
- Why it matters: tests could pull capacity-gap math, buffer erosion, or `infeasible_review` into Plan Compiler.
- Action: added explicit fixture rule that compiler outputs are unscheduled and contain no final dates or scheduler risk.
- Destination: design/spec/tasks.
- Scope impact: narrows scope.

### P0: Sensitive Content Boundary Was Too Weak

- Problem: trace redaction existed, but the LLM/input boundary did not explicitly prevent broad Obsidian/repo reading or raw sensitive prompt logs.
- Why it matters: resume, interview prep, private project notes, and private repo descriptions are realistic inputs.
- Action: added sensitive-content boundary rules and tests for prompt, trace, validation error, and log redaction.
- Destination: design/spec/tasks.
- Scope impact: in scope; safety and privacy clarification.

## Scope Decisions

### In Scope

- Fixture acceptance for AgentGuide, easyagent, LeetCode, interview prep, and resume/project packaging.
- Proving compiler fixture outputs remain unscheduled.
- Sensitive-content boundaries for selected inputs, LLM prompts, trace, validation errors, and prompt logs.

### Out Of Scope

- End-to-end dated schedule dry runs and capacity math.
- Deep GitHub crawling, broad Obsidian vault sync, or automatic private repo source reading.
- UI display details for fixture outputs.

### Deferred Upstream Dependencies

- Rich material ingestion can later improve source facts. V1 compiler must still behave honestly with shallow facts.
- User may later authorize broader Obsidian/GitHub context, but this change must not assume that capability.

### Downstream Contracts Preserved

- Scheduler owns feasible/infeasible fit math and dated dry-run acceptance.
- UI owns how sensitive redaction and low-calibration explanations are displayed.
- Draft persistence only stores the compiler package and redacted trace facts; it does not need to parse fixture semantics.

## Product Model Review

- The compiler is now tied to the user's actual urgent tracks: agent learning, repo rebuilds, LeetCode cadence, interview prep, and resume packaging.
- The fixtures reinforce the core product framing: turn a chosen goal into executable task candidates without deciding whether the goal is worth doing.
- Privacy boundaries are explicit enough for implementation workers to avoid broad local-context collection.

## Recommended Next Actions

- Proceed to `scope_dependency_check` on the next heartbeat. It should verify all three records contain scope decisions and that scheduler/date responsibilities remain outside this change.
