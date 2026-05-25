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

## Boundary Contracts

The Plan Compiler starts after draft persistence has an intake-linked draft shell and planning anchors. It returns a compiler package that draft persistence can store, and the deterministic scheduler can consume later.

Upstream draft persistence provides:

- `draft_id`, `draft_version`, `intake_id`, `draft_kind`, optional `target_plan_id`, and current draft status;
- confirmed role and attachment mode from intake routing;
- accepted or assumed anchors: deadline, deadline type, capacity, target output, target depth, buffer policy, rest/unavailable days, source roles, and provenance;
- source facts available from shallow intake or material parsing, such as URL, repo metadata, README summary, course/module hints, note snippets, or user-written description;
- existing-plan context when the draft targets an existing plan: plan title, active status, current phase/task summary, and attachment purpose.

The compiler treats deadline, capacity, rest days, unavailable dates, and active-load summaries as planning facts that shape scope and estimate confidence. It must not place final dates, compute per-day fit, or return schedule risk. Those facts pass through for downstream scheduling.

`PlanningEnvelope` V1 contains:

- `schema_version`;
- draft identity: `draft_id`, `draft_version`, `intake_id`, `draft_kind`, `target_plan_id`;
- confirmed intent: `confirmed_role`, `attachment_mode`, `target_output`, `target_depth`;
- scheduling anchors for pass-through and rough sizing: `deadline`, `deadline_type`, `daily_capacity_min`, `rest_weekdays`, `unavailable_dates`, `buffer_policy`;
- source context: `source_type`, `source_url`, `raw_input_summary`, `source_roles`, `source_facts`, `material_refs`;
- existing-plan context when applicable;
- user estimate overrides and known effort facts;
- fact provenance per major field;
- missing or assumed facts that must remain visible in the result.

The compiler returns exactly one `CompilerResult` status:

- `draft_review`: phases and task candidates are structurally valid and ready for scheduler placement;
- `needs_input`: compilation cannot safely proceed without one or more missing/ambiguous anchors; result includes at most one focused question plus recoverable assumptions;
- `compile_failed`: schema/quality/repair failed after bounded attempts; result includes validation errors and recovery actions.

`low_calibration` is a review flag, not a terminal status. `infeasible_review` is produced by the scheduler, not by this change.

A `draft_review` compiler package includes:

- summary and visible assumptions;
- selected archetype, modifiers, included/excluded scope, and confidence;
- ordered phases with completion evidence;
- ordered task candidates with task contracts described below;
- estimate summary and calibration flags;
- compiler trace.

`needs_input` and `compile_failed` packages do not require complete phases or tasks, but they must include enough missing-input or validation-error detail for draft persistence and UI to show a recovery path.

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

V1 selection matrix:

| Signal | Primary archetype | Notes |
| --- | --- | --- |
| Course/tutorial/book with finite target output | `finite_learning_project` | Use source structure as material, but derive phases from target output and depth. |
| LeetCode, drills, repeated interview practice, or cadence wording | `recurring_practice` | Output is practice cadence/checkpoints, not course completion. |
| Interview topic review, concept refresh, or note consolidation | `topic_review_cycle` | Bias toward active recall, explanation, and spaced review artifacts. |
| GitHub repo with clone/rebuild/modify/demo wording | `rebuild_or_clone` | Use repo facts for setup, trace, rebuild, modification, and demo tasks. |
| Resume, portfolio, case study, demo polish, or project story wording | `project_packaging` | Output is presentation evidence, narrative, bullets, or demo readiness. |
| Existing active plan selected with phase/scheduled-work attachment | `existing_project_phase` | Scope is bounded by selected target plan and attachment purpose. |

Tie-breakers:

1. explicit user target output beats source type;
2. target depth beats generic learning wording;
3. confirmed repo/source role beats URL shape alone;
4. existing-plan draft kind beats new-plan archetypes;
5. if two archetypes imply materially different daily work and neither wins, return `needs_input`;
6. if a secondary archetype only changes optional polish/review tasks, keep one primary archetype and record a modifier.

Scope boundary output includes:

- `primary_archetype`;
- `secondary_modifiers`;
- `included_material_refs`;
- `excluded_material_refs`;
- `essential_evidence`;
- `optional_or_stretch_evidence`;
- `selection_confidence`;
- `visible_assumption` when confidence is below high.

## Source And Goal Synopsis

The compiler builds a compact synopsis before LLM phase/task calls. The synopsis is not a parser replacement and must not overfit to every URL or note detail.

Synopsis inputs:

- user target output and depth;
- source role and source type;
- shallow source facts such as repo name, README headings, detected languages, course/module headings, note title, or user description;
- existing-plan context when applicable;
- known effort facts such as number of problems, modules, chapters, files, or expected deliverables.

Synopsis output includes:

- `goal_summary`: what the user wants to be able to show or do;
- `source_summary`: the useful facts about the material;
- `unknowns`: missing facts that affect decomposition or estimates;
- `material_refs`: stable references that tasks can point to without copying sensitive text;
- `estimate_facts`: counts or duration hints usable by estimate normalization.

If source facts are too thin for the selected archetype, the compiler either returns `needs_input` with one question or creates a structurally valid low-calibration package when a rough draft is still useful.

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
- work type;
- essential, optional, or stretch classification;
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
- reason why the task is required for the selected depth or marked reducible;
- assumptions.

LLM-generated dates are rejected or ignored. The scheduler owns all final date placement.

The implementation may use one or more LLM calls, but each call has a narrow job:

- phase call: turn `PlanningEnvelope`, archetype boundary, and synopsis into ordered phases;
- task call: turn one or more phases and synopsis references into executable task candidates;
- repair call: fix only cited schema or quality failures, without changing user anchors or adding dates.

LLM input must include the selected archetype, target depth obligations, included/excluded scope, and explicit instruction that final dates are forbidden. LLM output is accepted only after deterministic validation.

## Validation And Repair

Blocking failures:

- no executable output;
- missing completion criteria;
- missing work type or essential/optional/stretch classification;
- invalid dependency structure;
- invalid or unnormalizable estimates;
- task essentiality contradicts selected target depth;
- task references material outside the included scope;
- vague task that cannot be repaired.

Repairable failures can run a bounded repair loop at most two times. Warning-level uncertainty can enter review only as low calibration if the draft remains structurally valid.

Validation severities:

- `blocking`: cannot produce `draft_review`; must repair or return `compile_failed`/`needs_input`.
- `repairable`: can be sent to a repair call with the exact failed fields and constraints.
- `warning`: can enter `draft_review` only with visible assumption or low-calibration reason.

Repair loop rules:

- at most two repair attempts per compiler run;
- repair prompt receives only the invalid fragments, failed constraints, and required schemas;
- repair may not change user-provided anchors, target depth, deadline type, source role, or selected existing plan;
- if repair introduces dates, invalid dependencies, or broader scope, reject that repair result;
- after the final failed attempt, return `compile_failed` with validation errors and recovery actions.

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

V1 marks `low_calibration=true` when any of the following is true:

- low-confidence estimates cover at least 30% of essential estimated minutes;
- three or more essential tasks use default-only estimates;
- source-understanding or rebuild/clone output depends on a repo/source synopsis with insufficient shallow source facts;
- user-provided anchors conflict with generated task scope and the compiler can only proceed by visible assumption.

Low calibration can enter `draft_review` only if schema validation and task quality gates pass. Blocking validation failures return `needs_input` or `compile_failed`.

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

## Sensitive Content Boundary

The compiler may process private project notes, resume material, interview prep notes, and private repo descriptions. V1 does not introduce broad vault sync, deep GitHub crawling, or new provider configuration.

Rules:

- use only the submitted item, confirmed anchors, selected material refs, and upstream shallow source facts;
- do not silently read unrelated Obsidian vault content or unrelated repo files;
- send only the minimal synopsis and relevant snippets needed for the narrow LLM call;
- redact or summarize sensitive raw text in trace records, validation errors, and prompt logs;
- never expose hidden reasoning or raw prompts in user-facing UI;
- if source facts are too thin because deep reading is out of scope, return `needs_input` or low calibration rather than over-collecting.

## Real-Context Compiler Fixtures

These fixtures verify the compiler output before scheduling. They intentionally stop at phases, task candidates, estimates, calibration, and trace. Capacity math and dated schedules belong to `introduce-deadline-scheduler`.

### AgentGuide As Main Learning Object

- Expected primary archetype: `finite_learning_project`.
- Expected modifiers: optional `interview_notes` when target depth includes interview readiness.
- Minimum phases: orientation/source map, guided reproduction, small agent demo, interview notes/review.
- Required task evidence examples: setup notes, one runnable guide example, small tool-calling demo, 6-bullet agent-loop explanation.
- Rejected task shape: generic "learn AgentGuide" or "understand agent".

### easyagent As Rebuild Target

- Expected primary archetype: `rebuild_or_clone`.
- Expected depth behavior: `source_understanding` requires architecture map, key path trace, modification point, and tradeoff explanation.
- Minimum phases: inspect/run baseline, trace minimal loop, rebuild minimal loop, add one modification, prepare explanation.
- Required task evidence examples: chosen-file source map, quickstart/setup note, 8-10 bullet call-flow trace, runnable minimal demo, before/after tweak note.
- Low-calibration trigger: repo facts are too thin for source-understanding tasks.

### LeetCode Or 灵茶山 Practice

- Expected primary archetype: `recurring_practice`.
- Expected phases: diagnostic, daily practice cadence, mistake tagging, spaced redo, checkpoint mock set.
- Required task evidence examples: solved problem set, pattern tags, mistake log, redo list, recall sheet.
- Rejected task shape: treating a problem list as course chapters.

### Agent Or Backend Interview Prep

- Expected primary archetype: `topic_review_cycle`.
- Expected phases: topic inventory, active recall notes, project-linked examples, mock explanation, spaced review.
- Required task evidence examples: answer batch, project-linked example note, mock explanation gap list.
- Rejected task shape: generic "review backend" or "study agent memory".

### Resume And Project Packaging

- Expected primary archetype: `project_packaging`.
- Expected phases: evidence inventory, bullet rewrite, project story, rehearsal, revision.
- Required task evidence examples: 3 impact-first bullet variants, 90-second project story, rehearsal gap list, revised final note.
- Rejected task shape: generic "work on resume".
