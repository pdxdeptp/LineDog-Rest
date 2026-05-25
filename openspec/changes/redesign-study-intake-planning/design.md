## Context

### Real problem

The user already has many things they genuinely want to learn, do, or push forward: agent development, LeetCode, agent/backend interview prep, resume project packaging, existing project rewrites, GitHub repos, tutorials, videos, and Obsidian plans. The urgent bottleneck is not philosophical prioritization. It is the planning labor required to turn a chosen item into something that can be finished by a deadline through daily execution.

The design can easily drift for three reasons:

1. **"Add" sounds like parsing.** Existing v1/v2 work already has URL ingestion, GitHub handlers, material parsing, and draft scheduling. If the feature starts from URL mechanics, it will optimize extraction quality instead of reducing planning effort.
2. **"Learning assistant" invites value judgment.** The assistant may try to decide whether an item matters or how deeply it should be learned. That is out of scope for v1; the user has usually already decided interest or urgency.
3. **"Task system" invites noise.** Turning every repo, note, article, or idea into a todo pollutes the plan. The assistant must distinguish executable work from supporting material, reference, inspiration, and later resources.

The first-version center should therefore be:

> When the user drops in a learning or project goal, the system produces a confirmable, adjustable, deadline-driven execution plan draft with phases, daily work, buffer, low-energy fallback, and clear risk/cost.

### Background constraints from the planning context

- Graduation is roughly two months away, and the most important near-term goal is preparing for mid-July internet autumn recruitment early batches, targeting agent development roles.
- Current high-priority tracks include LeetCode, agent project learning, existing project upgrades, agent interview prep, backend interview prep, and resume/project packaging.
- Agent development inputs include tutorial repos such as `adongwanai/AgentGuide`, `easyagent`, `learn claude code`, `superpowers`, `gsd`, `gstack`, `openspec`, agent memory/context resources, spec-driven materials, and potential lower-level runtime frameworks.
- LeetCode behaves more like a stable training cadence than material ingestion.
- Interview prep needs topic scheduling and review rhythm, not just resource storage.
- Resume/project packaging includes non-material work such as rewriting Meituan internship narrative and deciding how to present cooking assistant/LangGraph/context-awareness work.
- MalDaze / 学习助手 itself is an existing project being rebuilt one feature at a time with OpenSpec + Superpowers + review discipline. This feature must have strong design artifacts before implementation.
- Lower-priority life tracks like graduation design, meal prep, and fitness should not crowd first-version learning/project intake, but the model should not make future extension impossible.

### Current system baseline

Existing v2 design positions the assistant as "a study-plan calendar with LLM scheduling ability," with the user owning confirmation and adjustment. That direction is still correct. The gap is that the first intake slice remains too URL/material-shaped:

- `introduce-study-plan-foundation` starts from URL + required deadline.
- `material-ingestion` treats GitHub/Bilibili/PDF/Web pages as parsed resources that usually become scheduled units.
- `assistant-panel-ui` still names and frames the entry as adding material.
- `study-plan-adjustment` and `study-smart-mode` already contain useful downstream mechanics: red states, rollover, deadline edits, rest days, preview/apply, and proposal-only smart mode.

This change keeps the user-owned calendar model but replaces the narrow URL-first entry with an intake router and deadline-driven plan draft compiler.

## Goals / Non-Goals

**Goals:**

- Reduce planning effort for already-chosen learning/project goals.
- Route submitted items into the right role before creating work.
- Generate plan drafts from deadline, available time, target output, target depth, and known materials.
- Make GitHub repos first-class inputs without assuming every repo is the main project.
- Produce phases, daily schedule, buffers, low-energy fallback tasks, and dynamic adjustment rules.
- Show risk/cost honestly when the deadline or capacity is unrealistic.
- Keep confirmation low-cost and keep today's action list tied only to confirmed active plans.
- Preserve v2 discipline: user confirms, system does not silently optimize or mutate plans.

**Non-Goals:**

- AI does not independently decide whether a goal is worth pursuing.
- AI does not independently decide the target depth; it offers choices and the user confirms.
- No automatic broad Obsidian import or "turn all notes into tasks."
- No full GitHub code understanding, contribution planning, or repo-quality judgment in v1.
- No automatic today's action from a newly added item before plan confirmation.
- No life-goal alignment analysis, therapist flow, meal-prep assistant, fitness assistant, or general personal OS.
- No fully automatic rescheduling without preview/apply and user confirmation.

## First-Version Coverage

The first version must be verified against the user's real planning context, not generic sample data. It should support manual submission of these examples:

- `adongwanai/AgentGuide` as a main learning object with a deadline and target output.
- `easyagent` as a clone/rebuild target or project-level learning plan.
- LeetCode Hot 100 / 灵茶山基础精炼 as a recurring training plan rather than a parsed resource.
- Agent/backend interview prep as topic-based study and review cadence.
- Resume/project packaging, such as rewriting Meituan internship narrative or packaging cooking assistant agent features.
- MalDaze / 学习助手 feature work as an existing project item that may become a phase or supporting material.

Supported first-version input forms are text goal, URL, GitHub repo URL, pasted note snippet, existing project description, interview-prep item, and resume/project-material note. The system does not need automatic Obsidian vault sync, deep platform-specific scraping, or deep GitHub source analysis in v1. Unsupported inputs should fall back to manual title/description and low-calibration planning or storage.

## Product Framing Options

### Option A: Material Inbox + Parser

The user adds URLs, repos, notes, or videos. The system parses metadata, stores them, and optionally creates tasks.

**Pros:**
- Fits existing ingestion infrastructure.
- Easy to explain for URL and GitHub inputs.
- Useful when the source structure maps cleanly to learning units.

**Cons:**
- Repeats the known drift toward parser quality.
- Does not help with non-material goals like resume packaging, LeetCode cadence, existing project rewrites, or "learn agent memory well enough to use it in MalDaze."
- Encourages every input to become a resource or task.
- Does not directly answer "how do I finish this by the deadline?"

**Assessment:** Good helper layer, bad product center for this request.

### Option B: Project Charter Wizard

The system asks structured questions to produce a project brief: motivation, outcome, scope, resources, deadline, risks, and success criteria.

**Pros:**
- Forces clarity before scheduling.
- Works for non-URL goals and projects.
- Can capture target output and completion standards.

**Cons:**
- Risks becoming a heavy questionnaire.
- Adds planning overhead before the user sees a useful draft.
- Can drift into "why does this matter to your life?" and "is this worth it?"

**Assessment:** Useful as an internal structure and review view, but too heavy as the main first-version experience.

### Option C: Deadline-Driven Intake Router + Plan Draft Compiler

The user drops in an item. The system first routes its role, then only creates a plan draft when the item needs deadline-driven execution. The draft is generated from minimal inputs and assumptions, then shown for cheap confirmation.

**Pros:**
- Directly attacks planning labor: phases, daily schedule, buffer, risks, and fallback work.
- Handles goals, repos, notes, existing projects, interview prep, and materials under one model.
- Prevents task noise by routing support/reference/later items away from daily work.
- Allows assumptions when details are missing instead of forcing a long form.
- Fits existing v2 calendar, red-state, adjustment, and smart-mode boundaries.

**Cons:**
- Requires clearer data roles than current material/resource tables.
- Needs careful UX so routing does not feel like bureaucracy.
- Plan estimates may be wrong, so review must make cost/risk editable.

**Decision:** Choose Option C for v1. Use parser/material ingestion as a helper inside the router, and use a compact charter only inside the draft review.

## Decisions

### Decision 1: The first system action is routing, not parsing

Every submitted item becomes an `intake item` first. The router assigns one proposed role:

- `new_plan`: a goal that needs a deadline-driven plan.
- `attach_to_existing_plan`: an item that belongs under an existing active or draft plan.
- `reference_material`: useful background that should not create tasks.
- `later_resource`: interesting but not active.
- `immediate_one_off`: so small or immediate that long planning is unnecessary.

Existing-plan support is modeled as a role plus an attachment mode, not as a separate competing route. A user-visible "supporting material" choice maps to `confirmedRole = attach_to_existing_plan` with `attachmentMode = material_only`. Scheduled additions map to `attachmentMode = draft_phase` or `scheduled_work`.

The router may use URL metadata, repo metadata, note text, and existing active plans, but it must not treat parsing as the product. If confidence is low, it asks one routing question, not a full questionnaire.

Alternative considered: parse every input and let the user decide later. Rejected because it creates resource clutter before the system knows whether the item should produce work.

Canonical entity map:

```
IntakeItem
  ├─ may create PlanDraft
  │    └─ contains DraftPhase(s)
  │         └─ contains DraftTask(s)
  ├─ may attach Material to PlanDraft or ActivePlan
  ├─ may become ReferenceMaterial
  └─ may become LaterResource

ActivePlan
  ├─ has Phase(s)
  ├─ has ExecutableTask(s)  -> only these can appear in Today
  └─ has Material(s)       -> support/reference, not daily work by default
```

The old word "resource" should not imply "scheduled work." In this design, a source can be material, reference, later resource, or the main object of a plan. Only confirmed executable tasks enter Today.

### Decision 2: Plan generation is triggered only by a confirmed planning role

The system generates a deadline-driven draft only when the user accepts `new_plan`, or accepts `attach_to_existing_plan` with `attachmentMode = draft_phase` or `scheduled_work`. Material-only attachments, references, and later items are attached or stored without entering the schedule. `immediate_one_off` may be saved as a note or a small unscheduled action, but it does not enter today's list unless the user explicitly adds it to an active plan.

This preserves the invariant: today's actions come from confirmed active plans, not from add-time enthusiasm.

### Decision 3: The minimum plan brief has four anchors

A deadline-driven draft needs:

1. deadline,
2. available time or capacity,
3. target output,
4. target depth.

If one or two anchors are missing, the system should either ask the smallest possible question or create a draft with visible assumptions. It should not block with a long form unless the deadline or target output is impossible to infer.

Target depth is chosen by the user from options such as:

- skim / orientation,
- can use it,
- project-level output,
- interview-ready,
- source-understanding / contribution-ready.

The assistant may recommend a default only as an assumption, and the review screen must show that assumption before confirmation.

Target depth must change the plan obligations, not only the label:

| Target depth | Required completion evidence | Task-generation effect |
| --- | --- | --- |
| `skim_orientation` | source map, key idea notes, and explicit "not pursuing now" or "next action" decision | Emphasize orientation, summary, and triage; avoid build/rebuild/interview rehearsal unless user requests it. |
| `can_use_it` | a working example, solved representative problem, or usable workflow note | Include setup, first successful use, one applied exercise, and a short usage note. |
| `project_level_output` | a demo, integration, writeup, or concrete project artifact | Include baseline, build/apply phase, one meaningful modification or integration, and artifact polish. |
| `interview_ready` | recall sheet, project-linked answers, mock explanation, and redo/review evidence | Add active recall, spaced review, mock explanation, and project/example articulation tasks. |
| `source_understanding` | architecture map, key path trace, modification point, and explanation of tradeoffs | Add code/source reading, call-flow tracing, architecture notes, and one small modification or contribution-shaped exercise. |

Depth interaction rules:

- The target output is still the primary promise; depth decides how much evidence is required to believe the output is done.
- A plan may combine one primary depth with a modifier, such as `project_level_output` plus `interview_ready`, but the review must show the extra work created by the modifier.
- The compiler must not silently upgrade depth because a source looks important.
- Lowering depth must visibly change completion evidence and remove or mark unnecessary obligations as optional.
- If lowering depth would break the confirmed target output, the system should say the target output also needs to change instead of pretending the same output is still satisfied.

### Decision 4: Drafts are output-driven, not source-driven

For a repo/course/article, source structure informs the plan. It does not dictate the plan. The compiler should build phases around the target output:

- orient and scope,
- core learning / reproduction,
- application or project integration,
- interview/resume articulation if relevant,
- review and buffer.

The compiler should first choose a plan archetype:

- `finite_learning_project`: finish a course, repo guide, book, or tutorial by a deadline.
- `recurring_practice`: create a stable cadence for LeetCode or similar drills.
- `topic_review_cycle`: prepare agent/backend interview topics with spaced review.
- `rebuild_or_clone`: reproduce a repo or demo and understand its architecture.
- `project_packaging`: turn existing work into resume bullets, interview stories, demos, or writeups.
- `existing_project_phase`: add a bounded phase to an existing project plan.

Archetype selection shapes task generation. A recurring practice plan may schedule problem sets, review days, and redo loops; a project packaging plan may schedule inventory, rewrite, mock explanation, and revision; a rebuild plan may schedule environment setup, reproduction, architecture notes, and demo polish.

Examples:

- `AgentGuide` as main learning object: phases can follow tutorial structure and end in a usable mini-agent or notes.
- `easyagent` as rebuild target: phases emphasize reproduction, architecture notes, and a demo.
- `superpowers` as source-understanding target: phases emphasize concept map, code reading, adaptation idea, and interview explanation.
- LeetCode Hot 100: phases are cadence and review loops rather than URL units.
- Meituan internship resume rewrite: phases are inventory, narrative rewrite, project bullets, mock explanation, and review.

Archetype selection must be implemented as a deterministic classification step with an optional narrow LLM explanation, not as an unconstrained plan-generation prompt.

Selection inputs:

- confirmed intake role and attachment mode;
- canonical source roles, especially GitHub repo role;
- target output text;
- target depth;
- source type and shallow source synopsis;
- whether an existing plan is selected;
- user constraints such as interview relevance, rebuild goal, or resume packaging.

Selection matrix:

| Primary signal | Default archetype | Notes |
| --- | --- | --- |
| `attach_to_existing_plan` with `draft_phase` or `scheduled_work` | `existing_project_phase` | Preserve the parent plan; source may become phase material or scheduled work. |
| repo role `clone_rebuild_target`, or target output says rebuild/clone/reproduce/demo from repo | `rebuild_or_clone` | Use repo structure as reference, but tasks center on runnable reproduction and explanation. |
| problem list, drills, LeetCode, cadence, redo, pattern recall | `recurring_practice` | Does not require parsed chapters; cadence and review loops are first-class. |
| interview topic prep, question bank, active recall, mock explanation | `topic_review_cycle` | Project examples may be attached as material, not treated as source chapters. |
| resume bullets, project story, portfolio writeup, demo packaging | `project_packaging` | Existing work is evidence to package, not new learning material. |
| course/tutorial/book/guide/repo as main thing to finish by deadline | `finite_learning_project` | Source structure can inform phases, but target output controls scope. |

Ambiguity rules:

- If signals point to both a plan-generating and non-plan role, route clarification owns the question before the compiler runs.
- If signals point to multiple plan archetypes but one is tied to an explicit source role or target output, choose that archetype and record the others as modifiers.
- If multiple archetypes would produce materially different daily work and no signal clearly wins, ask one archetype question in `needs_input`.
- If the difference only changes wording or optional phases, choose the lower-maintenance archetype, mark the assumption, and allow override in draft review.

Scope boundary output:

- selected `primaryArchetype`;
- optional `secondaryModifiers`, such as `interview_notes`, `source_reading`, `demo_polish`, or `resume_articulation`;
- included source/material ids and the reason each is included;
- excluded or optional source/material ids and the reason they are excluded from scheduled work;
- confidence: `high`, `medium`, or `low`;
- one user-facing assumption sentence when confidence is not high.

Example: `easyagent` submitted as "rebuild a minimal Claude-Code-like loop" selects `rebuild_or_clone`; the same repo submitted as "learn enough for agent interviews" can select `finite_learning_project` with an `interview_notes` modifier unless the user explicitly asks to clone it. The goal is one primary daily-work shape, with modifiers, instead of a mixed plan that tries to do everything.

### Decision 5: Scheduling works backward from deadline with buffer

The scheduler computes a draft from:

- date window from start date through deadline,
- configured rest days and one-off unavailable days,
- daily available minutes,
- task estimates,
- buffer policy,
- known existing active-plan load.

When user capacity is missing, the scheduler should fall back to the learning preference default `daily_capacity_min = 60`. It must not fall back to the older data-layer default of 300 minutes.

First-version scheduling rule:

- Reserve buffer before the deadline by default. For short plans, reserve at least one buffer day when possible; for longer plans, reserve roughly 15-25% of available workdays, capped so the plan still has meaningful execution days.
- Use no more than a safe fraction of daily capacity for planned work when the user has not explicitly opted into a crunch plan.
- Spread essential work across non-rest days and mark overload rather than hiding it.
- Expose "required average daily minutes" and "capacity gap" when the draft cannot fit.
- Generate daily tasks for the plan horizon, but make the review UI emphasize the first week, milestones, and risk states so it does not become visually overwhelming.

Alternative considered: pack everything as early as possible. Rejected because it increases low-energy failure risk and hides schedule realism.

### Decision 6: Each scheduled day has a normal task and a fallback when useful

The plan draft may include:

- normal task: the intended daily work,
- low-energy fallback: the minimum viable action for days when the user is tired,
- optional stretch: extra work only if energy remains.

Fallbacks are not separate nagging todos. They are attached to the daily task as a reduced execution mode. Completing a fallback can mark partial progress and trigger later adjustment, but it should not pretend the full task was completed. The review must show the consequence in plain terms, such as "keeps momentum, but this task still needs follow-up," so fallback mode does not create invisible debt.

### Decision 7: GitHub repo role is explicit

When the input is a GitHub repo, the router must ask or infer role before planning:

- `main_learning_object`,
- `reference_source`,
- `clone_rebuild_target`,
- `project_material`,
- `later_reading`.

For v1, repo analysis is shallow: README/title/topics/directory outline are enough to support role and rough structure. Deep source understanding and code-quality judgment are future work.

### Decision 8: Confirmation is cheap and staged

The plan review should require only a few meaningful confirmations:

1. role: "new plan / attach / store",
2. anchors: deadline, capacity, target output, target depth,
3. draft: phases, daily load, buffer, risk,
4. activation: confirm into active plan.

The default review is summary-first:

- top line: "What this becomes" and whether it fits the deadline,
- compact anchors: deadline, time, output, depth,
- first-week schedule,
- buffer/risk summary,
- one primary action to accept the draft with visible assumptions.

The user can accept assumptions in one click. Advanced edits, full schedule, per-task duration edits, and source details remain available but are collapsed by default and are not required for a normal draft.

### Decision 9: Dynamic adjustment reuses v2 plan mechanics

After activation, this change should rely on the existing v2 adjustment principles:

- incomplete work can roll forward,
- user date moves cascade mechanically within the project,
- deadline edits reveal red states instead of silently repairing,
- smart suggestions, when enabled, remain proposal-only and user-applied.

The new intake-specific requirement is that each plan carries enough assumptions to make later adjustment understandable: original deadline, target output, target depth, capacity, buffer, and known material roles.

### Decision 10: Noise is controlled by role, state, and trigger

The system must avoid three noise paths:

- **Role noise:** supporting/reference/later items do not create tasks.
- **State noise:** draft plans do not affect Today until confirmed.
- **Trigger noise:** add-time does not generate today's action; smart suggestions are only triggered by confirmed plan facts and existing v2 red/lag conditions.

Noise budget:

- One submitted item should create at most one visible pending object: a role confirmation, a draft, or a stored item confirmation.
- Non-plan roles do not create Today badges, deadline-risk alerts, smart-mode proposal triggers, or reminder surfaces.
- If the user wants a one-off task, the UI must make that an explicit action, not a side effect of adding an item.
- Multiple supporting links for the same plan should be groupable as materials rather than separate tasks.

### Decision 11: Calibration and provenance are visible

Every generated draft should separate:

- user-provided facts,
- parsed or fetched source facts,
- AI assumptions,
- unknowns.

The review should show a calibration level such as high, medium, or low. Low calibration can still be useful, but it must be labeled so the user knows the plan is rough. The system must not fabricate repo structure, source content, deadlines, or target outputs. If it cannot fetch or infer something reliably, it should say so and continue with manual title/description or visible assumptions.

### Decision 12: Deadline semantics and feasibility are explicit

Each plan draft should label the deadline as:

- `hard`: must be done by this date, such as interview batch prep.
- `soft`: desired date, adjustable if scope/capacity does not fit.
- `assumed`: system/user accepted a provisional date for drafting.

Feasibility is computed from estimated work, available non-rest days, buffer, daily capacity, and existing active-plan load. If the plan fits only by consuming buffer or overloading days, the review must say so. If the plan does not fit, the system offers explicit user choices: reduce scope, extend deadline, increase daily time, accept a crunch/overload plan, or store for later. The system must not silently pick one of those options.

## Plan Compiler Pipeline

The plan compiler is the engine behind Add / Initiate. It is not one LLM prompt that returns a calendar. It is a staged pipeline:

> LLM proposes structure and task candidates; deterministic validators and schedulers decide whether the draft is shaped well and whether it fits.

### Compiler Inputs

The compiler receives a normalized `PlanningEnvelope`:

- confirmed intake role: `new_plan` or `attach_to_existing_plan`,
- attachment mode when the role is `attach_to_existing_plan`,
- plan archetype,
- deadline and deadline type,
- available time/capacity and rest-day facts,
- target output,
- target depth,
- existing active-plan load,
- source/material summaries with provenance,
- user-provided constraints, such as "must be useful for agent job interviews" or "do not spend more than 45 minutes/day."

The compiler must reject or pause if the envelope lacks a usable deadline/timebox or target output and no safe assumption is available.

### Compiler Output

The compiler returns a `PlanDraftPackage`:

- plan summary,
- assumptions and provenance,
- archetype,
- phases,
- milestones,
- ordered executable tasks,
- task estimates and confidence,
- low-energy fallback modes,
- deterministic schedule,
- buffer and capacity report,
- infeasibility options if needed,
- review summary for the UI.

Only the deterministic scheduler assigns dates. LLM-generated dates are ignored or treated as non-authoritative hints.

### Pipeline Stages

1. **Normalize envelope**
   - Convert the routed intake item, anchors, source previews, and existing plan context into a single structured input.
   - Mark each fact as user-provided, parsed, AI-assumed, or unknown.

2. **Select archetype and scope**
   - Choose one archetype and a scope boundary for this draft.
   - Confirm target output and target depth.
   - If target depth and deadline conflict, keep both visible and let feasibility handling decide.

3. **Build source synopsis**
   - For GitHub/course/web/video inputs, create a short source synopsis from shallow metadata or parsed structure.
   - For text goals, interview prep, LeetCode, resume packaging, or existing-project work, create a goal synopsis from user text and known context.
   - Do not expand into deep source analysis in v1.

4. **Generate phase and milestone draft**
   - LLM proposes phases and milestones as structured JSON.
   - Each phase must have a purpose, completion evidence, rough effort range, and whether it is essential or optional.
   - Milestones must be observable: demo runs, notes written, problem set completed, project bullet rewritten, mock explanation recorded, etc.

5. **Generate task candidates**
   - LLM proposes ordered tasks under each phase, but not scheduled dates.
   - Each task candidate must include:
     - action title,
     - concrete output,
     - completion criteria,
     - estimated minutes,
     - dependencies or predecessor,
     - source/material references when applicable,
     - normal mode,
     - low-energy fallback mode,
     - optional stretch mode,
     - confidence and assumptions.

6. **Run deterministic task quality gates**
   - Reject or repair tasks that are vague, too large, too tiny, missing outputs, missing completion criteria, or impossible to execute in one sitting.
   - The compiler may run a bounded LLM repair loop, but it must not keep asking indefinitely.
   - If repair leaves blocking validation errors, return `compile_failed` or `needs_input`; do not show an activatable draft.
   - If repair leaves only warning-level uncertainty, the draft may enter review as low-calibration with the unresolved assumptions visible.

7. **Normalize estimates**
   - Use source facts when available, such as video duration, repo tutorial module count, problem count, or known review cadence.
   - Use archetype defaults when source facts are absent.
   - Keep LLM estimates as suggestions, then clamp or flag outliers through deterministic rules.
   - Store estimate confidence so the review UI can say "rough estimate" instead of pretending precision.

8. **Schedule deterministically**
   - Take ordered tasks, estimates, capacity, existing load, rest days, unavailable dates, deadline type, and buffer policy.
   - Assign dates with a deterministic scheduler.
   - The scheduler may split tasks into continuation sessions only at approved split points or explicit multi-session boundaries; it must not invent new learning content.
   - It marks overload, expected-late, capacity gap, and buffer erosion instead of silently repairing them.

9. **Generate infeasibility options**
   - If the draft does not fit, generate structured choices:
     - `reduce_scope`,
     - `lower_depth`,
     - `extend_deadline`,
     - `increase_capacity`,
     - `accept_crunch`,
     - `accept_buffer_risk`,
     - `accept_overload`,
     - `accept_late_finish`,
     - `answer_one_question`,
     - `edit_estimates`,
     - `accept_rough_draft`,
     - `store_for_later`.
   - LLM may write the human-readable explanation, but the options and capacity math come from deterministic facts.

10. **Package review**
   - UI receives a summary-first package: what this becomes, first-week work, fit/risk, assumptions, and primary confirmation action.
   - Full phase/task/schedule detail remains available behind expansion.

### Archetype-Specific Decomposition Rules

- `finite_learning_project`: phases should move from orientation to core learning to applied output to review. Good for tutorials, courses, and structured repos.
- `rebuild_or_clone`: phases should include run original, reproduce minimal version, understand architecture, modify one point, and produce demo/explanation.
- `recurring_practice`: tasks should be cadence blocks, review blocks, redo blocks, and checkpoint tests. It should not pretend there is a source chapter list.
- `topic_review_cycle`: tasks should group topics, active recall, example explanation, spaced review, and mock interview prompts.
- `project_packaging`: tasks should inventory evidence, rewrite bullets, produce STAR/project narratives, rehearse explanation, and revise from feedback.
- `existing_project_phase`: tasks should attach to an existing plan and preserve that plan's active schedule unless the user confirms new scheduled work.

### Task Quality Gates

A task is acceptable only if it has:

- an action verb and a concrete object,
- a visible output or stopping condition,
- an estimate with confidence,
- a normal execution mode,
- a low-energy fallback when useful,
- a phase/milestone link,
- no hidden requirement that the user plan the work again.

Examples of bad tasks:

- "Learn LangGraph"
- "Understand agent memory"
- "Work on resume"
- "Study repo"

Examples of acceptable tasks:

- "Run `easyagent` quickstart locally and save setup errors/notes"
- "Read README architecture section and write 5 bullets on agent loop, tool call, memory, and config boundaries"
- "Solve 5 Hot 100 array problems and tag mistakes by pattern"
- "Rewrite Meituan internship bullet set into 3 impact-first variants"

Size rule for v1:

- default task target: 25-90 minutes,
- tasks over 120 minutes must be split or explicitly marked as a multi-session milestone,
- tasks under 10 minutes should usually be merged unless they are a checkpoint or low-energy fallback,
- fallback mode should normally fit within 15-30 minutes or under roughly 40% of the normal task.

### Estimate Normalization Rules

The compiler normalizes estimates before scheduling so the calendar is not driven by raw LLM guesses.

Source priority:

1. user-edited or user-provided estimate;
2. concrete source facts, such as video duration, problem count, module count, or known interview/review cadence;
3. user history or speed factor when available;
4. archetype defaults;
5. LLM estimate as a suggestion only.

V1 default estimate table:

| Work type | Default minutes | Confidence when no stronger source exists |
| --- | ---: | --- |
| orientation / source map / scope decision | 30-45 | medium |
| setup, quickstart, or first successful run | 45-90 | medium |
| source trace / architecture notes | 45-90 | medium |
| build, rebuild, integration, or meaningful modification | 60-120 | medium, with split points required near the high end |
| LeetCode/problem practice block | 45-75 | medium when problem count is known, low when only topic is known |
| redo / review / active recall block | 30-45 | medium |
| interview answer batch or mock explanation | 45-75 | medium |
| resume bullets, project story, or writeup draft | 45-75 | medium |
| polish, revision, or buffer review | 30-60 | medium |

Concrete source-fact defaults:

- video/course duration becomes active-work estimate, not passive watch time; use about 1.25x for orientation and about 1.5x when notes/exercises are required;
- problem-list estimates use problem count and the selected cadence block size rather than one task per problem by default;
- repo/module counts can inform number of orientation or source-trace tasks, but they do not force every module into scheduled work;
- user-provided estimates override defaults but remain subject to feasibility reporting.

Clamp and validation rules:

- missing estimates use the default table and become low or medium confidence depending on source facts;
- estimates below 10 minutes are merged unless the task is a checkpoint, review action, or fallback;
- estimates above 120 minutes require split points, an explicit multi-session milestone, or a blocking validation error;
- raw LLM estimates outside 15-180 minutes are treated as outliers and must be replaced by source facts or defaults before scheduling;
- if normalized confidence is low for more than roughly one third of essential work, mark the draft low-calibration;
- if total normalized estimate changes by more than about 25% after user edits or source refresh, the draft version must show an estimate-change note before activation.

Confidence rules:

- `high`: user estimate, known duration/count facts, or prior user history directly supports the task size;
- `medium`: archetype default plus matching source/target signals supports the task size;
- `low`: the task relies mostly on LLM wording, weak source synopsis, or unknown source size.

### Deterministic Scheduling Policy

The scheduler treats dates as a constraint problem, not an LLM writing exercise.

Inputs:

- ordered task list,
- task estimates,
- allowed start date,
- deadline,
- hard/soft/assumed deadline type,
- daily capacity,
- existing active load,
- rest days and one-off unavailable days,
- buffer policy,
- optional user preference such as balanced, front-loaded, or light-start.

If daily capacity is not explicitly supplied, use the learning preferences default of 60 minutes.

Default scheduling:

1. Compute non-rest workdays between start date and deadline.
2. Reserve buffer days when possible.
3. Compute remaining usable capacity after existing active load.
4. Place essential tasks in dependency order.
5. Prefer balanced daily load over early burnout.
6. Keep optional/stretch tasks unscheduled or mark them as optional when capacity is tight.
7. Mark, rather than hide, any overload, expected-late placement, or buffer erosion.

The scheduler can produce a draft that is "not feasible as written." That is a valid output, not a failure. The UI should then ask the user which constraint to change.

V1 deterministic defaults:

- default load shape: `balanced`;
- default new-plan daily budget cap: 80% of `usableCapacity(date)` unless user chooses crunch/overload;
- minimum buffer: 1 usable day when the window has at least 3 usable days;
- long-plan buffer target: 20% of usable days, clamped to 1-5 days before deadline;
- same-day tie-breaker: preserve dependency order, then phase order, then task order;
- optional/stretch work: never scheduled before all essential work has a feasible placement;
- rest days and one-off unavailable days: zero normal placement capacity, but can still show fallback/reading only if the user explicitly chooses that date.

### Structured LLM Contracts

The compiler may use several LLM calls, but each call has a narrow contract and schema validation. Broad "make me a plan" prompts are not allowed.

#### Phase generator

Input:

- `PlanningEnvelope`,
- selected archetype,
- source/goal synopsis,
- target output and target depth,
- known constraints.

Output shape:

```json
{
  "phases": [
    {
      "id": "phase-1",
      "title": "Orient and run baseline",
      "purpose": "Understand what the source/project is and get a runnable baseline",
      "essential": true,
      "effortRangeMinutes": [120, 240],
      "completionEvidence": ["demo runs locally", "notes contain 5 architecture bullets"],
      "milestones": [
        {
          "id": "m1",
          "title": "Baseline is runnable",
          "evidence": "screenshot/log/notes showing successful run"
        }
      ],
      "assumptions": ["repo README has a quickstart"]
    }
  ]
}
```

Rejected output:

- phases without observable completion evidence,
- phases that duplicate source headings without explaining the target output,
- phases that require value judgment outside the confirmed target depth.

#### Task candidate generator

Input:

- accepted phase list,
- source/goal synopsis,
- task size policy,
- target output,
- target depth.

Output shape:

```json
{
  "tasks": [
    {
      "id": "task-1",
      "phaseId": "phase-1",
      "order": 1,
      "title": "Run quickstart and record setup notes",
      "actionVerb": "run",
      "concreteObject": "repo quickstart",
      "output": "setup note with success/failure and next blockers",
      "completionCriteria": ["quickstart attempted", "errors or success recorded"],
      "estimatedMinutes": 60,
      "estimateConfidence": "medium",
      "dependencies": [],
      "materials": ["repo-url"],
      "normalMode": "Run quickstart and document setup result",
      "fallbackMode": "Read quickstart and write commands to try next",
      "fallbackMinutes": 20,
      "stretchMode": "Fix one setup issue if time remains",
      "splitPoints": [
        {
          "id": "split-1",
          "afterMinutes": 30,
          "continuationLabel": "Continue quickstart run and finish setup notes"
        }
      ],
      "assumptions": ["local environment can install dependencies"]
    }
  ]
}
```

Rejected output:

- dated tasks,
- tasks without output or completion criteria,
- tasks that require the user to decide what to do next,
- tasks that are only nouns or aspirations.

#### Repair loop

Validators return machine-readable errors such as:

- `missing_completion_criteria`,
- `too_vague`,
- `oversized_task`,
- `tiny_task_should_merge`,
- `missing_dependency`,
- `invalid_estimate`,
- `date_field_not_allowed`.

The LLM may repair invalid phase/task JSON at most two times. After that, the compiler classifies unresolved issues by severity instead of pretending all failures are reviewable.

Repair failure is not a single state:

- blocking failures, such as missing completion criteria, invalid dependencies, no executable output, or invalid estimates that cannot be normalized, cannot enter `draft_review`;
- repairable failures can run the bounded repair loop;
- warning-level uncertainty, such as rough estimates, weak source synopsis, or low confidence assumptions, can enter `draft_review` only as a low-calibration draft with visible warnings.

A low-calibration draft is still structurally valid. It may be rough, but it must not contain tasks that failed blocking quality gates.

### Scheduler Algorithm

The deterministic scheduler consumes only validated task candidates. It produces `ScheduledDraftTask` records and a `ScheduleRiskReport`.

Definitions:

- `rawCapacity(date)`: user's available minutes for that date.
- `existingLoad(date)`: minutes already occupied by confirmed active plans.
- `usableCapacity(date)`: `max(0, rawCapacity - existingLoad)`.
- `planningBudget(date)`: usable capacity available to the new draft. By default this is capped so a new plan does not consume every free minute unless the user chooses crunch mode.
- `essentialWork`: sum of essential task estimates.
- `optionalWork`: sum of optional/stretch task estimates.
- `bufferDays`: reserved non-rest days before deadline.
- `scheduledSession`: one dated slice of a task when the whole task cannot fit in a single available day.

Default algorithm:

1. Build the date window from start date through deadline.
2. Remove rest days and one-off unavailable days from normal placement.
3. Compute `usableCapacity` for each remaining date.
4. Reserve buffer days near the deadline:
   - if the plan has 3-5 usable days, reserve 1 day when possible;
   - if the plan has more than 5 usable days, reserve about 15-25% of usable days;
   - if reserving buffer makes essential work impossible, keep the buffer visible as eroded rather than hiding it.
5. Split or multi-session-mark tasks that exceed size policy before placement.
6. Place essential tasks in dependency order using the selected load shape:
   - `balanced` by default,
   - `front_loaded` only when user chooses a faster start,
   - `light_start` when user wants a gentle ramp.
7. Keep optional/stretch tasks unscheduled or attach them to low-load days only after essential work fits.
8. Preserve dependencies; if a dependency cannot fit before deadline, mark expected-late rather than reordering.
9. Compute risk report:
   - capacity gap,
   - overloaded dates,
   - expected-late tasks,
   - buffer erosion,
   - rough estimate confidence,
   - existing-load conflicts.
10. Return the schedule even if infeasible; infeasibility is a review state, not an exception.

Low daily capacity rule:

- If a task estimate is larger than a normal day's `planningBudget(date)`, the scheduler must split it across multiple dated sessions using the task's approved `splitPoints` or explicit continuation boundary.
- Each scheduled session must keep the parent task id, sequence number, estimated minutes, and a visible sub-output or continuation note.
- A task cannot be placed as a single ordinary daily task that exceeds `planningBudget(date)` unless the user explicitly chooses `accept_crunch` or `accept_overload`.
- If the task cannot be meaningfully split and cannot fit any available day, the scheduler marks it as `expected_late` or `overloaded_dates` and enters infeasible review.
- If even the fallback mode exceeds usable capacity on every available day, the draft must expose a capacity gap rather than pretending the fallback is viable.

The scheduler does not:

- lower target depth automatically,
- extend the deadline automatically,
- move existing active tasks to make the new draft fit,
- invent missing tasks,
- create today's action before activation.

### Infeasibility Decision Matrix

When the schedule is not feasible as written, the system should map facts to choices:

| Fact | User-facing meaning | Allowed choices |
| --- | --- | --- |
| `capacity_gap` | The work needs more minutes than available before the deadline. | `reduce_scope`, `lower_depth`, `extend_deadline`, `increase_capacity`, `accept_crunch` |
| `buffer_erosion` | The plan fits only by spending the safety margin. | `accept_buffer_risk`, `reduce_scope`, `extend_deadline`, `increase_capacity` |
| `overloaded_dates` | Some dates exceed available minutes. | `rebalance`, `increase_capacity`, `reduce_scope`, `accept_overload` |
| `expected_late` | Some required tasks land after the deadline. | `extend_deadline`, `reduce_scope`, `lower_depth`, `accept_late_finish` |
| `low_calibration` | The system is guessing because inputs or source facts are weak. | `answer_one_question`, `edit_estimates`, `accept_rough_draft`, `store_for_later` |

The assistant can explain these options in plain language, but it cannot choose for the user.

### Real-Context Dry Runs

These examples are not hard-coded templates. They are acceptance probes for the compiler design.

#### `AgentGuide` as main learning object

Envelope:

- archetype: `finite_learning_project`,
- target output: "finish the guide enough to build a small agent demo and write interview notes",
- depth: project-level / interview-ready,
- source: GitHub README outline when available.

Expected phases:

- orient repo and select relevant sections,
- run examples or reproduce guide steps,
- build a small agent demo,
- write architecture/interview notes,
- review and buffer.

Good task examples:

- "Skim README/module list and mark essential vs optional sections for the demo."
- "Run the first guide example and record setup commands/errors."
- "Implement one small tool-calling demo from the guide."
- "Write 6 bullets explaining agent loop, tools, memory/context, and failure modes."

Bad task examples:

- "Learn AgentGuide."
- "Understand agent."

#### `easyagent` as rebuild target

Envelope:

- archetype: `rebuild_or_clone`,
- target output: "rebuild a minimal Claude-Code-like agent loop and explain architecture",
- depth: project-level / source-understanding-lite.

Expected phases:

- run original or inspect baseline,
- reproduce minimal loop,
- add one meaningful modification,
- prepare demo and explanation.

Good task examples:

- "Trace the command loop and write the call sequence in 8-10 bullets."
- "Build a minimal agent loop with one tool and one model call."
- "Add one config or memory tweak and record before/after behavior."

#### LeetCode Hot 100 / 灵茶山基础精炼

Envelope:

- archetype: `recurring_practice`,
- target output: "build interview-ready pattern recall",
- depth: interview-ready,
- source: problem list, not a course structure.

Expected phases:

- baseline diagnostic,
- daily practice cadence,
- mistake tagging,
- spaced redo,
- checkpoint mock sets.

Good task examples:

- "Solve 5 array/hash problems and tag each mistake by pattern."
- "Redo 3 previously failed sliding-window problems without notes."
- "Write a 10-minute recall sheet for binary search templates."

#### Agent/backend interview prep

Envelope:

- archetype: `topic_review_cycle`,
- target output: "answer common agent/backend questions with examples from projects",
- depth: interview-ready.

Expected phases:

- topic inventory,
- active recall notes,
- project-linked examples,
- mock explanation,
- spaced review.

Good task examples:

- "Write answers for 4 agent memory/context questions using MalDaze or cooking assistant examples."
- "Explain one backend topic aloud and mark gaps in a review note."

#### Resume/project packaging

Envelope:

- archetype: `project_packaging`,
- target output: "resume bullets and interview story for Meituan/cooking assistant/MalDaze",
- depth: interview-ready / resume-ready.

Expected phases:

- inventory evidence,
- rewrite bullets,
- craft STAR/project narrative,
- rehearse explanation,
- revise.

Good task examples:

- "Rewrite Meituan internship into 3 impact-first bullet variants."
- "Draft a 90-second cooking assistant project story covering LangGraph, state tracking, and context awareness."

### End-To-End Dry Runs With Capacity Math

These dry runs are acceptance probes for the whole pipeline: routing, archetype selection, depth semantics, estimate normalization, scheduling, buffer, and infeasibility handling.

#### Feasible dry run: resume/project packaging before an interview screen

Input:

- item: "把 Meituan 实习和 cooking assistant 项目包装成简历 bullet 和 90 秒面试故事";
- role: `new_plan`;
- archetype: `project_packaging`;
- target depth: `interview_ready`;
- target output: resume bullet variants plus one rehearsable project story;
- deadline: end of Day 7, soft;
- capacity: 75 minutes/day, no existing active load;
- planning budget: 60 minutes/day by default cap;
- rest/unavailable: Day 4 unavailable;
- buffer: reserve Day 7.

Normalized task set:

| Task | Estimate | Evidence | Essential |
| --- | ---: | --- | --- |
| Inventory evidence for Meituan and cooking assistant | 60 | evidence list with metrics, tech choices, impact notes | yes |
| Rewrite Meituan into 3 impact-first bullet variants | 60 | 3 bullet variants | yes |
| Draft cooking assistant 90-second project story | 60 | STAR-style story draft | yes |
| Rehearse project story and mark gaps | 60 | rehearsal notes and gap list | yes |
| Revise bullets/story from gaps | 45 | final revised bullet/story note | yes |

Schedule:

| Day | Scheduled work | Minutes |
| --- | --- | ---: |
| Day 1 | Inventory evidence | 60 |
| Day 2 | Rewrite Meituan bullets | 60 |
| Day 3 | Draft cooking assistant story | 60 |
| Day 4 | Unavailable | 0 |
| Day 5 | Rehearse and mark gaps | 60 |
| Day 6 | Revise bullets/story | 45 |
| Day 7 | Buffer | 0 |

Risk report:

- essential work: 285 minutes;
- planned execution capacity before buffer: 300 minutes;
- capacity gap: 0;
- buffer reserved: 1 day;
- result: `draft_review`, activatable after explicit confirmation.

#### Infeasible dry run: easyagent rebuild with source-understanding target

Input:

- item: "`easyagent`，在很短时间内重建一个 minimal Claude-Code-like agent loop，并能讲清楚架构";
- role: `new_plan`;
- repo role: `clone_rebuild_target`;
- archetype: `rebuild_or_clone`;
- target depth: `source_understanding`;
- target output: runnable minimal agent loop plus architecture explanation;
- deadline: end of Day 6, hard;
- capacity: 75 minutes/day, no existing active load;
- planning budget: 60 minutes/day by default cap;
- buffer: reserve Day 6 when possible.

Normalized essential task set:

| Task | Estimate | Evidence | Essential |
| --- | ---: | --- | --- |
| Scope repo and identify minimal loop files | 45 | source map with chosen files | yes |
| Run or inspect quickstart baseline | 90 | setup notes or baseline behavior notes | yes |
| Trace command/model/tool loop | 90 | 8-10 bullet call-flow trace | yes |
| Build minimal loop with one tool and one model call | 120 | runnable minimal demo | yes |
| Add one config or memory tweak | 75 | before/after behavior note | yes |
| Prepare architecture explanation | 60 | 90-second explanation notes | yes |
| Final review and buffer check | 45 | final gap list | yes |

Fit math:

- essential work: 525 minutes;
- execution capacity before hard deadline with one buffer day: 5 days x 60 = 300 minutes;
- capacity gap: 225 minutes;
- buffer erosion: buffer cannot be preserved if the full scope is attempted;
- expected status: `infeasible_review`.

Allowed options:

- `lower_depth` to `can_use_it`: keep repo orientation, baseline run, and usage notes; remove source trace, modification, and deep architecture evidence;
- `reduce_scope`: unavailable as a standalone fix because all listed tasks are essential for the confirmed source-understanding output;
- `extend_deadline`: available only if the hard date itself changes;
- `increase_capacity` or `accept_crunch`: available with visible overload/crunch risk;
- `accept_late_finish`: not available because the deadline is hard;
- `store_for_later`: available with no active tasks.

## Pre-Split Core Model

This change is a mother design change. It SHOULD NOT be applied directly as one implementation change. The following core model must be stable before splitting into smaller implementation changes.

### Lifecycle State Machine

The user-visible Add / Initiate flow is stateful and async. Every implementation slice should preserve this lifecycle:

```
idle
  -> intake_submitted
  -> routing
  -> role_review
       -> stored_non_plan
       -> attach_review
            -> stored_non_plan
            -> anchor_review
       -> anchor_review
  -> compiling
       -> compile_failed
       -> needs_input
       -> infeasible_review
       -> draft_review
  -> draft_editing
       -> recompiling
       -> draft_review
  -> activating
       -> active_plan
       -> activation_failed
  -> cancelled_or_stored
```

State notes:

- `routing`: creates or updates an `IntakeItem`, no active tasks.
- `role_review`: user can accept or override the recommended role.
- `stored_non_plan`: reference/later/supporting material saved; it remains outside Today.
- `attach_review`: user confirms an existing plan attachment and whether it is material, phase, or scheduled work. `material_only` exits to `stored_non_plan`; `draft_phase` and `scheduled_work` continue to `anchor_review`.
- `anchor_review`: deadline/capacity/output/depth assumptions are shown before compiling.
- `compiling`: may run material preview, LLM phase/task generation, validation, estimate normalization, and deterministic scheduling.
- `needs_input`: compiler cannot safely assume a missing anchor or unresolved ambiguity; ask the minimum question.
- `compile_failed`: source/LLM/validation failure that cannot produce a reviewable draft; allow retry, manual simplification, or store for later.
- `infeasible_review`: valid draft that does not fit constraints; user picks an explicit option.
- `draft_review`: summary-first plan review; no active Today tasks yet.
- `draft_editing`: user edits assumptions, tasks, estimates, scope, deadline, or capacity.
- `activating`: writes active plan/tasks from the current draft version only.
- `activation_failed`: draft remains intact and retryable.

Cancellation:

- cancelling before `active_plan` never creates active tasks;
- the user can discard the intake item or store it as later/reference;
- cancelling after `active_plan` is not part of this intake flow and should use existing plan adjustment/archive behavior.

### Data Contracts

All compiler-facing contracts are versioned. Implementation changes can rename storage tables, but they must preserve these logical fields.

#### `PlanningEnvelope`

Required fields:

- `schemaVersion`;
- `intakeItemId`;
- `confirmedRole`;
- `planArchetype`;
- `deadline`: date plus `hard`, `soft`, or `assumed`;
- `capacity`: default daily minutes plus per-date overrides when available;
- `restDays` and `unavailableDates`;
- `targetOutput`;
- `targetDepth`;
- `sourceSummaries`;
- `sourceRoles`: the role of each attached or primary source, including repo roles such as `main_learning_object`, `reference_source`, `clone_rebuild_target`, `project_material`, or `later_reading`;
- `existingActiveLoad`;
- `provenance`: user-provided, parsed, AI-assumed, or unknown for each major fact.

Optional fields:

- `userConstraints`;
- `preferredLoadShape`;
- `existingPlanId` when role is `attach_to_existing_plan`;
- `attachmentMode`: `material_only`, `draft_phase`, or `scheduled_work` when role is `attach_to_existing_plan`;
- `materialRole` when the source is reference or later material.

#### `PlanDraftPackage`

Common required fields:

- `schemaVersion`;
- `draftId`;
- `draftVersion`;
- `intakeItemId`;
- `status`: `draft_review`, `infeasible_review`, `needs_input`, or `compile_failed`;
- `summary`;
- `assumptions`;
- `reviewSummary`;
- `activationEligibility`.

Status-specific fields:

- `draft_review`: requires phases, task candidates, scheduled tasks, risk report, and `activationEligibility = eligible`;
- `infeasible_review`: requires phases, task candidates, scheduled tasks when available, risk report, and canonical infeasibility options; activation remains blocked until the user chooses an option or explicitly accepts allowed risk;
- `needs_input`: requires missing or ambiguous facts, one user-facing question, and recovery actions; phases, tasks, and schedule may be absent;
- `compile_failed`: requires validation errors or failure reason plus retry, simplify, or store recovery actions; phases, tasks, and schedule may be absent or partial and are not activatable.

Rules:

- every draft edit that changes anchors, scope, task estimates, task list, or schedule creates a new `draftVersion`;
- activation must verify the user is activating the latest draft version;
- stale activation attempts fail safely and keep the draft reviewable.

#### `ValidationError`

Shape:

- `code`;
- `severity`: `blocking`, `repairable`, or `warning`;
- `target`: phase/task/schedule/envelope field;
- `messageForUser`;
- `repairHint` when available.

Blocking validation errors cannot enter `draft_review` or become activatable. Repairable errors can run the bounded repair loop. Warnings can enter review only when shown as assumptions or low-calibration notes. Low calibration is therefore a confidence state for structurally valid drafts, not a bypass around validation.

#### `ScheduleRiskReport`

Required facts:

- `fitsAsWritten`;
- `capacityGapMinutes`;
- `overloadedDates`;
- `expectedLateTasks`;
- `bufferDaysReserved`;
- `bufferErosion`;
- `estimateConfidenceSummary`;
- `existingLoadConflicts`;
- `infeasibilityOptions`.

### Draft Editing And Recompile Rules

Draft edits should not all trigger the same expensive pipeline.

Only reschedule:

- deadline date/type changes;
- daily capacity or one-off availability changes;
- rest-day changes;
- task estimate edits;
- load-shape preference changes;
- accepting or rejecting crunch/overload.

Regenerate task candidates and then reschedule:

- target output changes;
- target depth changes;
- archetype changes;
- scope reduction that removes or marks phases optional;
- user asks to split/merge/rewrite tasks beyond simple estimate edits.

No compile needed:

- editing display title/description;
- storing a non-plan item;
- attaching reference/supporting material without scheduled work.

All recompile/reschedule operations create a new draft version and keep the previous version recoverable until activation or discard.

### Infeasibility Option Effects

Each infeasibility option has a deterministic effect:

- `reduce_scope`: marks optional phases/tasks out of scope, then regenerates task candidates only if essential structure changes.
- `lower_depth`: changes `targetDepth`, regenerates phases/tasks, then reschedules.
- `extend_deadline`: updates deadline and runs scheduler only.
- `increase_capacity`: updates capacity assumptions and runs scheduler only.
- `accept_crunch`: raises or removes the new-plan daily budget cap for selected dates, then runs scheduler only.
- `accept_buffer_risk`: keeps the eroded buffer visible and allows activation only after explicit user confirmation.
- `rebalance`: reruns the scheduler with the same scope, deadline, depth, and capacity but a different distribution if a valid distribution exists.
- `accept_overload`: keeps overloaded dates visible and allows activation only after explicit user confirmation for those dates.
- `answer_one_question`: returns to `needs_input` with a single missing fact or ambiguity.
- `edit_estimates`: keeps task structure and lets the user adjust estimates before scheduler-only recomputation.
- `accept_rough_draft`: allows activation only when the draft has no blocking validation errors and all warning-level assumptions remain visible.
- `store_for_later`: exits active planning, stores the intake item as later/reference, and creates no active tasks.
- `accept_late_finish`: allowed only for soft/assumed deadlines; keeps schedule with expected-late status visible.

Hard deadlines must not expose `accept_late_finish` as an available option. They can show expected-late facts, but available choices must require changing scope, depth, deadline, capacity, overload/crunch, or storage.

The system may recommend which option preserves more of the target output, but the user must choose.

### Scope Reduction And Depth Lowering Rules

`reduce_scope` and `lower_depth` are not generic "make it smaller" commands. They must produce an auditable before/after draft.

Phase/task classification:

- `essential`: required to satisfy the confirmed target output at the confirmed target depth.
- `optional`: useful but not required for the confirmed target output/depth.
- `stretch`: opportunistic extra work; never scheduled before essential work fits.
- `support_only`: material or reference attached to the plan but not executable work.

`reduce_scope` keeps the same target output and target depth. It removes or unschedules work in this order:

1. stretch tasks;
2. optional polish or extra review tasks;
3. optional source sections not required by the target output;
4. secondary modifiers, such as extra interview notes on a project-level plan;
5. optional practice volume above the minimum cadence/checkpoint needed for the target.

`reduce_scope` must not remove the minimal evidence required by the confirmed target depth. If no removable optional/stretch work remains and the plan still does not fit, `reduce_scope` is not an available fix by itself; the system should offer `lower_depth`, `extend_deadline`, `increase_capacity`, `accept_crunch`, or `store_for_later`.

`lower_depth` changes completion obligations and therefore regenerates phases/tasks before rescheduling. By default, it offers adjacent lower-depth moves:

- `source_understanding` -> `project_level_output` or `interview_ready`, depending on target output;
- `interview_ready` -> `project_level_output` or `can_use_it`;
- `project_level_output` -> `can_use_it` only when the target output can still be satisfied without a project artifact;
- `can_use_it` -> `skim_orientation`;
- `skim_orientation` cannot be lowered further without changing the target output into storage/reference.

Before applying either option, the review must show:

- minutes removed or regenerated;
- phases/tasks removed, unscheduled, or changed;
- completion evidence lost;
- whether target output remains the same;
- whether target depth remains the same or changes;
- the new fit/risk result after recomputation.

If the user chooses a reduction that changes the target output, it should be modeled as an explicit target-output edit, not as `reduce_scope`.

### Existing Plan Attachment Semantics

When the role is `attach_to_existing_plan`, the user must confirm one of three attachment modes:

- `material_only`: attach source to existing plan without tasks;
- `draft_phase`: create a phase/task draft scoped to the existing plan, but do not activate it yet;
- `scheduled_work`: create scheduled tasks only after draft review and activation.

Activation rules:

- material-only attachment does not touch the existing plan schedule;
- draft phase activation adds new tasks using the same deterministic scheduler and shows combined load against the existing plan;
- activation must not silently move existing active tasks;
- if adding the phase creates overload/late states, the draft enters infeasible review before activation.

The router should not emit both `supporting_material` and `attach_to_existing_plan` as independent machine roles. "Supporting material" remains a user-facing label and persisted relationship type; the machine route is `attach_to_existing_plan` plus `attachmentMode = material_only`.

### Low-Energy Fallback Completion Semantics

Fallback mode is a reduced execution mode for a scheduled task, not a second task.

When the user completes fallback only:

- record `fallback_completed_at`;
- record actual minutes if provided;
- keep the full task incomplete;
- mark the task as `needs_followup`;
- include remaining normal work in later rollover/adjustment logic;
- avoid counting the full task as completed progress.

The UI should explain this as "momentum preserved; full task still needs follow-up" rather than as failure.

### Async Feedback, Retry, And Recovery

The Add / Initiate UI should show stage-level progress:

- analyzing input,
- routing item,
- previewing source,
- generating phases,
- generating tasks,
- validating tasks,
- scheduling,
- preparing review.

Failures should be recoverable:

- material preview failure: continue manually or retry preview;
- LLM generation failure: retry, simplify target, or store for later;
- validation failure after bounded repair: show low-calibration draft only when safe, otherwise ask one question or cancel;
- scheduler infeasibility: show reviewable infeasible draft, not a generic error;
- activation failure: keep current draft version and allow retry.

### Compiler Trace And Observability

The compiler should keep implementation-facing trace records for debugging and tests without turning the UI into a log viewer.

Trace records should include:

- envelope normalization inputs by fact type, with sensitive raw text redacted or summarized;
- selected archetype, scope boundary, and attachment mode when applicable;
- LLM schema validation results and bounded repair attempt count;
- task quality gate failures and whether each was blocking, repairable, or warning-level;
- estimate normalization source, clamp, and confidence changes;
- scheduler inputs, continuation-session splits, buffer reservation, and placement decisions;
- risk facts and canonical infeasibility option ids generated from those facts.

Trace records are for developer/operator diagnosis and contract tests. User-facing review should show only the relevant reason, assumption, or risk summary, not raw prompts or hidden chain-of-thought.

### Privacy And Provider Boundary

V1 should treat resume text, interview prep, project notes, and private repo descriptions as sensitive. The design does not introduce new provider configuration. Any implementation that sends content to an external LLM must reuse existing provider settings, show enough provenance for user trust, and avoid silently sending broader Obsidian vault contents.

### Split-Ready Implementation Boundaries

After this mother design is stable, split implementation into smaller changes:

1. `introduce-study-intake-router`
   - intake item creation, role routing, confidence bands, one-question clarification, non-plan storage.
2. `persist-intake-plan-drafts`
   - data contracts, draft/active separation, draft versioning, activation event.
3. `introduce-plan-compiler`
   - envelope creation, archetype selection, LLM phase/task contracts, validation, estimate normalization.
4. `introduce-deadline-scheduler`
   - deterministic scheduler, buffer/defaults, risk report, infeasibility options.
5. `redesign-add-initiate-ui`
   - UI state machine, role/anchor review, async progress, draft review, activation/cancel/retry flows.

Each implementation change should import only the relevant sections from this mother design and keep its own `tasks.md` small enough for TDD/subagent dispatch.

Recommended split dependency order:

1. `introduce-study-intake-router` can start first because it owns intake roles and non-plan outcomes.
2. `persist-intake-plan-drafts` should follow before compiler or UI activation work because drafts, versions, attachment modes, and activation events need durable contracts.
3. `introduce-plan-compiler` depends on router and draft persistence contracts, but can stub the scheduler while developing LLM contracts and validators.
4. `introduce-deadline-scheduler` depends on validated task contracts and should provide risk reports before full UI activation.
5. `redesign-add-initiate-ui` depends on the router, draft persistence, compiler, and scheduler surfaces. It may begin visual shell work earlier only if activation remains disabled behind mocks.

No child change should implement a different role enum, infeasibility option enum, draft version rule, or validation failure rule than the ones defined here.

## Core Flow

```
User drops item
      |
      v
Create intake item
      |
      v
Route role
  |-------------------|----------------------|----------------|
  v                   v                      v                v
new plan          attach to plan       reference/later    one-off
  |                   |                      |                |
  v                   v                      v                v
Collect anchors     Choose material-only,  Store without     Save note or
or assumptions      draft phase, or work   active tasks      explicit action
  |
  v
Generate draft plan
  |
  v
Review role + anchors + phases + daily schedule + buffer + risks
  |
  v
Confirm -> active plan -> Today/Calendar/Adjustment
```

## Failure States

- Missing deadline and no obvious timebox: ask for deadline or offer "store for later" instead of generating a fake plan.
- Missing target output: offer a small set of output templates and allow "use recommended assumption."
- Capacity too low for deadline: show capacity gap, propose options such as reduce scope, extend deadline, increase daily time, or store as later.
- Repo cannot be fetched: allow manual title/description and store URL; planning can continue as low-calibration if the user supplies target output.
- Ambiguous role: ask one routing question with recommended role first.
- Draft too large/noisy: collapse later days into phase summary in the UI while preserving daily schedule data.
- User cancels draft: keep intake item as draft or discard based on explicit choice; do not write active tasks.

## Risks / Trade-offs

- [Risk] Routing becomes another form to maintain. -> Mitigation: infer a recommended role and ask at most one routing question when ambiguous.
- [Risk] The plan compiler over-promises accuracy. -> Mitigation: show estimates, calibration level, assumptions, buffer, and capacity gap; make duration edits cheap.
- [Risk] GitHub handling drifts into deep repo analysis. -> Mitigation: v1 uses shallow repo metadata and explicit role; deep source comprehension is future work.
- [Risk] Daily schedules become visually overwhelming. -> Mitigation: show phases and first week prominently, keep full daily schedule inspectable.
- [Risk] Supporting materials still leak into tasks. -> Mitigation: make role a persisted field and require active-plan confirmation before Today eligibility.
- [Risk] Existing URL ingestion tests assume every URL creates a scheduled resource. -> Mitigation: route through compatibility paths only after the intake role is confirmed as plan-generating.

## Migration Plan

1. Add the `study-intake-planning` capability contract before implementation.
2. Replace the Add tab framing with Add / Initiate while keeping existing URL ingestion available as a helper.
3. Add persisted role and relationship fields so materials can attach to plans without becoming tasks.
4. Route URL/GitHub inputs through the intake item flow.
5. Generate plan drafts only for confirmed planning roles.
6. Preserve existing v2 active plan, Today, Calendar, adjustment, and smart-mode behavior after activation.

Rollback strategy: keep the old add-material flow callable until the new intake path is verified. If the new path is removed, existing confirmed plans and resources remain valid because role metadata is additive.

## Open Questions

None blocking the requirements. Implementation may later tune exact buffer percentages, UI density, and supported GitHub metadata depth through tests and manual QA, but the product boundary is closed for v1.
