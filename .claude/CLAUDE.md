# AI Agent Workflow Rules: OpenSpec + Superpowers Integration

## Core Directive
This project strictly enforces a Separation of Concerns between Design (OpenSpec) and Execution (Superpowers). You are explicitly equipped with `superpowers:dispatching-parallel-agents` to accelerate execution.

## Execution Trigger (The Bridge)
When I command you to run `/opsx:apply` or ask you to implement an active specification, you MUST NOT write the implementation code directly in a purely sequential manner. Instead, you MUST intercept the execution, analyze for parallelization opportunities, and hand it over to the Superpowers methodology.

### Phase 1: Task Triage & Parallel Dispatch
Before writing any code, analyze the current OpenSpec task for parallelization:
1. **Analyze Dependencies:** Can this task be split into decoupled, independent components (e.g., separate UI components, independent API endpoints, frontend vs. backend)?
2. **Dispatch Sub-agents:** If independent components exist, you MUST explicitly invoke the `superpowers:dispatching-parallel-agents` skill to spawn sub-agents.
3. **Context Injection:** Assign each sub-agent a specific, isolated component and inject the relevant OpenSpec context. Command each sub-agent to strictly follow the "Standard Implementation Loop".

### Phase 2: The Standard Implementation Loop (Per Agent)
Whether executing sequentially (main agent) or in parallel (sub-agents), the following sequence MUST be strictly enforced for every isolated task:
1. **write-tests**: Force a Test-Driven Development (TDD) approach. Write failing unit tests for the assigned component first.
2. **implement**: Write the minimal code required to pass the test.
3. **run-tests**: Verify the implementation. If it fails, iterate.
4. **requesting-code-review**: Analyze the code for security, performance, and adherence to the OpenSpec `spec.md`.

### Phase 3: Integration & Consolidation
Once all dispatched parallel agents report completion, the main agent must:
1. Verify that all components integrate correctly.
2. Run the global test suite to ensure no regressions were introduced by parallel merges.

## Constraints
- **Parallelism Safety:** Do not dispatch parallel agents for tasks that share overlapping file modifications or have strict sequential dependencies.
- **Strict TDD:** Never skip the TDD phase. Tests must exist before implementation.
- **Spec Sync:** Keep the `spec.md` updated if technical realities force a design change during the `implement` phase.

## Language & Reasoning Strategy (Mixed Strategy)
- **Reasoning Language**: For all internal chain-of-thought, technical analysis, and architecture design, you SHOULD prioritize using **English**. This ensures the highest logical precision and alignment with technical documentation.
- **Output Language**: Your final response to the user and all human-facing comments MUST be in **Chinese (Standard Mandarin)** unless English is specifically requested for a code snippet or technical term.
- **Implicit Translation**: Think in English, output in Chinese.