## Scope

This change builds the Plan Compiler up to validated task candidates and normalized estimates.

Included:

- `PlanningEnvelope` creation;
- archetype and scope selection;
- target-depth semantics;
- source/goal synopsis;
- LLM phase and task contracts;
- validation and bounded repair;
- estimate normalization;
- low-calibration classification;
- compiler trace for compilation decisions.

Excluded:

- intake routing;
- draft persistence internals;
- deterministic date placement;
- infeasibility option effects that depend on schedule facts;
- Add / Initiate UI;
- activation.

## Pipeline

1. Normalize envelope.
2. Select archetype and scope.
3. Build source or goal synopsis.
4. Generate phase and milestone draft.
5. Generate executable task candidates.
6. Run deterministic task quality gates.
7. Normalize estimates and confidence.
8. Return a structurally valid compiler result or a blocked state.

The compiler may call an LLM for phases/tasks, but each call has a narrow schema. Broad prompts that directly return a calendar are not allowed.

## Archetype And Scope Selection

Selection inputs:

- confirmed intake role and attachment mode;
- canonical source roles, especially GitHub repo role;
- target output;
- target depth;
- source type and shallow source synopsis;
- existing plan selection;
- user constraints such as interview relevance, rebuild goal, or resume packaging.

Default archetypes:

- `finite_learning_project`
- `recurring_practice`
- `topic_review_cycle`
- `rebuild_or_clone`
- `project_packaging`
- `existing_project_phase`

The compiler selects one `primaryArchetype` and may record secondary modifiers such as `interview_notes`, `demo_polish`, or `resume_articulation`. If different archetypes would produce materially different daily work and no signal clearly wins, the compiler returns `needs_input` with one archetype-focused question.

## Target Depth Semantics

Depth changes completion obligations:

- `skim_orientation`: source map, key idea notes, and a next-action or not-pursuing decision.
- `can_use_it`: working example, representative problem, or usable workflow note.
- `project_level_output`: demo, integration, writeup, or project artifact.
- `interview_ready`: recall sheet, project-linked answers, mock explanation, and redo/review evidence.
- `source_understanding`: architecture map, key path trace, modification point, and tradeoff explanation.

The compiler must not silently upgrade depth. If a requested lower depth cannot satisfy the target output, it should return a visible assumption or `needs_input`.

## LLM Contracts

Phase output must include:

- id;
- title;
- purpose;
- essential status;
- effort range;
- completion evidence;
- milestones;
- assumptions.

Task output must include:

- id;
- phase id;
- order;
- action title;
- concrete output;
- completion criteria;
- estimated minutes;
- estimate confidence;
- dependencies;
- material/source references;
- normal mode;
- fallback mode when useful;
- split points when a task may span sessions;
- assumptions.

LLM-generated dates are rejected or ignored. The scheduler owns all final date placement.

## Validation And Repair

Blocking failures:

- no executable output;
- missing completion criteria;
- invalid dependency structure;
- invalid or unnormalizable estimates;
- vague task that cannot be repaired.

Repairable failures can run a bounded repair loop at most two times. Warning-level uncertainty can enter review only as low calibration if the draft remains structurally valid.

## Estimate Normalization

Estimate source priority:

1. user-provided estimate;
2. concrete source facts;
3. user history or speed factor when available;
4. archetype/work-type defaults;
5. LLM estimate as suggestion only.

V1 work-type defaults:

- orientation/source map: 30-45 minutes;
- setup/quickstart: 45-90 minutes;
- source trace/architecture notes: 45-90 minutes;
- build/rebuild/integration: 60-120 minutes;
- LeetCode/practice block: 45-75 minutes;
- redo/review/active recall: 30-45 minutes;
- interview answer batch/mock explanation: 45-75 minutes;
- resume/project story/writeup: 45-75 minutes;
- polish/revision: 30-60 minutes.

Estimates under 10 minutes are normally merged. Estimates above 120 minutes require split points, a multi-session milestone, or blocking validation. Raw LLM estimates outside 15-180 minutes are outliers and must be replaced by source facts or defaults before scheduling.

If low-confidence estimates cover a significant share of essential work, the compiler marks the result low-calibration.

## Trace

Compiler trace records should include:

- envelope fact provenance;
- selected archetype and modifiers;
- source/scope boundary;
- LLM schema validation results;
- repair attempt count;
- task quality gate failures;
- estimate source and confidence changes;
- low-calibration reasons.

Trace records must not expose raw sensitive content or hidden reasoning in user-facing UI.
