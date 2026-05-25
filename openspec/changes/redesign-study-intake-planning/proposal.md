## Why

The current learning assistant intake is still too easy to frame as "add a URL/material and parse it." The user's real bottleneck is not deciding whether something is worth learning, but turning already-chosen learning and project goals into deadline-driven plans with phases, daily work, buffers, and adjustment paths.

This change redesigns the Add / Initiate experience as a low-maintenance project intake and planning entry point. A GitHub repo, course, note, project idea, interview prep item, or resume-polish task may be a primary project, a phase inside an existing plan, supporting material, reference material, or a later resource; the system must route it without turning every input into a todo or today's action.

## What Changes

- Reframe the entry from "add material" to "initiate or attach a learning/project item."
- Add intake triage that classifies user-submitted items into:
  - new deadline-driven plan draft,
  - attachment to an existing plan as material-only, draft phase, or scheduled work,
  - reference or inspiration,
  - later/backlog resource,
  - immediate one-off action that does not need long planning.
- Generate deadline-driven plan drafts from confirmed goals using deadline, available time, target output, target depth chosen by the user, and known materials.
- Require the draft to expose phases, daily schedule, capacity assumptions, buffer, risk/overload states, low-energy fallback tasks, and dynamic adjustment rules.
- Support GitHub repositories as first-class inputs with explicit canonical roles such as `main_learning_object`, `reference_source`, `clone_rebuild_target`, `project_material`, or `later_reading`.
- Keep confirmation cheap: the user should approve or adjust the plan at a small number of decision points, not maintain a complex planning database by hand.
- Keep "today's actions" downstream of confirmed active plans only; adding an item does not automatically create today's task.
- Keep value judgment and target-depth judgment user-owned in v1. The assistant may show cost/risk and offer target-depth options, but it must not independently decide whether the item is worth pursuing or how deeply it should be learned.

## Capabilities

### Affected Specs

- `assistant-panel-ui`
- `ingestion-progress-sse`
- `learning-data-layer`
- `material-ingestion`
- new `study-intake-planning`

### New Capabilities

- `study-intake-planning`: Intake routing and deadline-driven draft planning for learning and project goals, including goal/material role separation, plan confirmation, buffers, low-energy fallbacks, and first-version boundaries.

### Modified Capabilities

- `assistant-panel-ui`: The Add tab changes from a URL/material-focused entry into an Add / Initiate entry that supports goal text, GitHub repos, notes, existing projects, interview prep items, and resources without creating active tasks until a plan is confirmed.
- `ingestion-progress-sse`: Progress events need to support Add / Initiate stages such as routing, source preview, phase/task generation, validation, scheduling, needs-input, compile-failed, infeasible-review, and draft-ready states instead of assuming only the old URL ingestion phase sequence.
- `learning-data-layer`: Stored learning entities need to distinguish planned projects, project phases, executable tasks, supporting materials, references, and later resources rather than treating every source as active scheduled work.
- `material-ingestion`: URL and repository parsing becomes a helper for intake, not the product center. Ingested materials may attach to plans or be stored as references instead of always creating scheduled units/tasks.

## Impact

- Future UI: Add / Initiate panel, plan draft review, role-selection and confirmation controls, GitHub-role handling, low-energy and buffer display.
- Future backend/API: intake classification, plan-draft generation, schedule generation, material attachment, draft confirmation, and safe no-op/storage flows.
- Future data model: explicit item role, project/phase/material relationships, planning assumptions, calibration level, buffer days, fallback tasks, and confirmed vs draft state.
- Existing v2 plan, views, adjustment, and smart-mode designs remain relevant, but this change supersedes the narrow URL-only interpretation of initial project intake.
