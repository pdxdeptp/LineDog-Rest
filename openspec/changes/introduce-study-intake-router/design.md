## Scope

This change implements the routing layer only. It decides what a submitted item is likely to become and prevents task noise before plan generation.

Included:

- intake item creation;
- supported input type detection;
- material/source preview for routing;
- role recommendation and confidence;
- one-question clarification;
- existing-plan attachment mode selection;
- non-plan storage outcomes;
- GitHub shallow metadata and canonical repo roles;
- no-fabrication rules for unavailable source facts.

Excluded:

- plan draft persistence beyond the intake item;
- phase/task generation;
- deadline scheduling;
- draft review UI;
- activation into active plans;
- full Obsidian vault sync;
- deep GitHub/source analysis.

## Routing Model

Every submitted item first becomes an `IntakeItem`. The router proposes exactly one machine role:

- `new_plan`: a goal that needs deadline-driven planning later.
- `attach_to_existing_plan`: the item belongs under an existing active or draft plan.
- `reference_material`: useful background that should not create work.
- `later_resource`: interesting but not active.
- `immediate_one_off`: small enough that long planning is unnecessary, but still not auto-added to Today.

Existing-plan support uses `attachmentMode`:

- `material_only`
- `draft_phase`
- `scheduled_work`

User-facing "supporting material" maps to `confirmedRole = attach_to_existing_plan` and `attachmentMode = material_only`.

## Router Inputs

The router may use:

- raw text and source type;
- URL or GitHub preview metadata;
- shallow source synopsis;
- known active plan titles, and draft plan titles only when a downstream draft-persistence surface already exists;
- user-provided wording such as "later", "reference", "rebuild", "for interview", or "add to current project";
- existing plan selection when the user explicitly chooses one.

The router must not treat source parsing as the product. Source preview is a signal for role choice, not proof that a plan should be generated.

## Confidence And Clarification

Router confidence:

- `high`: one role is strongly implied by user wording or explicit source role.
- `medium`: one role is likely, but alternatives should be visible.
- `low`: plan-generating versus non-plan outcome or existing-plan attachment is ambiguous.

If confidence is low and the ambiguity changes whether scheduled work may eventually be created, ask one concise routing question with a recommended default. The question should distinguish outcomes, not gather a full project brief.

Examples:

- "Is this a new plan, supporting material for an existing plan, or something to save for later?"
- "Should this repo be the thing to rebuild, reference material, or later reading?"

## Router Contracts

The router change must expose stable logical contracts even if endpoint names differ.

`IntakeSubmission`:

- `clientRequestId`: idempotency key for UI retry;
- `rawInput`: user text, URL, repo URL, or snippet reference;
- `sourceType`: text goal, standard URL, GitHub repo, note snippet, existing project, interview prep, resume/project material, or unknown;
- optional `userHint`: explicit wording such as later, reference, rebuild, interview, or attach to project;
- optional `existingPlanId` when the user already chose a target plan.

`IntakeRouteResult`:

- `intakeItemId`;
- `recommendedRole`;
- `confidence`;
- `reasonCodes`;
- optional `previewSummary`;
- optional `canonicalRepoRole`;
- optional `attachmentModeSuggestion`;
- optional `existingPlanCandidates`;
- optional `clarificationQuestion`;
- `nextAction`: `role_review`, `answer_routing_question`, `confirm_non_plan_storage`, `select_attachment_target`, or `handoff_to_anchor_review`;
- `createsActiveTasks`: always false.

`RoleConfirmation`:

- `intakeItemId`;
- `confirmedRole`;
- optional `attachmentMode`;
- optional `existingPlanId`;
- optional `materialRole`;
- optional `canonicalRepoRole`.

`RouterOutcome`:

- `stored_non_plan` for reference, later, one-off note, or material-only attachment;
- `awaiting_anchor_review` for `new_plan`, `draft_phase`, or `scheduled_work`;
- `needs_routing_input` when one question is required;
- `cancelled`.

The router must keep intake role and source/repo role separate. For example, a GitHub repo can have `confirmedRole = new_plan` and `canonicalRepoRole = clone_rebuild_target`, or `confirmedRole = attach_to_existing_plan` and `canonicalRepoRole = project_material`.

## Idempotency And Existing-Plan Resolution

Submitting the same `clientRequestId` again must return the existing intake item and route result instead of creating a second pending object. This protects retrying UI clients and repeated heartbeat/app calls from duplicating role confirmations.

If the router recommends `attach_to_existing_plan` but no existing plan target is explicit:

- with one strong candidate, return it as the recommended target and require confirmation;
- with multiple plausible candidates, return `select_attachment_target`;
- with no candidate, ask whether to store as reference/later or create a new plan instead.

The router should not proceed to scheduled-work handoff until both `existingPlanId` and `attachmentMode` are confirmed.

This router change must not implement draft-plan persistence or draft-plan discovery on its own. It may use active plans that already exist in the current system. Draft plan candidates are a downstream integration point owned by `persist-intake-plan-drafts`.

## GitHub Preview

GitHub preview may return:

- title;
- description;
- README outline when available;
- topics;
- coarse directory signals;
- fetch status;
- canonical repo role signal when available.

Canonical repo roles:

- `main_learning_object`
- `reference_source`
- `clone_rebuild_target`
- `project_material`
- `later_reading`

If README, topics, description, or directory signals are unavailable, the preview leaves those fields unknown. Add / Initiate preview must not generate learning units from only the repo name. Legacy URL ingestion may keep compatibility fallback units only if they are labeled synthetic or low-calibration and not treated as parsed repo facts.

## Outcomes

No router outcome creates active daily tasks.

- `new_plan`: store confirmed role and wait for the draft/persistence/compiler changes to collect anchors and generate a draft.
- `attach_to_existing_plan` + `material_only`: attach material/reference to the chosen plan without schedule changes.
- `attach_to_existing_plan` + `draft_phase` or `scheduled_work`: store the confirmed intent; later changes own plan draft creation.
- `reference_material`: store as reference outside Today and active workload.
- `later_resource`: store as later/backlog outside Today, deadline risk, and smart proposals.
- `immediate_one_off`: require explicit user action to create or schedule the one-off; do not add automatically.

## Compatibility

The legacy confirmed URL-ingestion path may continue to create schedulable resource structures. Add / Initiate preview must remain separate from that path until the user confirms a plan-generating role.
