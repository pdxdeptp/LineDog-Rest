## 1. Intake Item And Routing

- [x] 1.1 Add idempotent intake item creation for text goals, URLs, GitHub repos, pasted notes, existing project descriptions, interview prep items, and resume/project material using a client request id.
- [x] 1.2 Implement role recommendation for `new_plan`, `attach_to_existing_plan`, `reference_material`, `later_resource`, and `immediate_one_off`.
- [x] 1.3 Implement router confidence levels and reason strings.
- [x] 1.4 Implement one-question clarification for low-confidence routing.
- [x] 1.5 Implement existing-plan attachment mode handling: `material_only`, `draft_phase`, and `scheduled_work`.
- [x] 1.6 Implement route result contracts with next actions: `role_review`, `answer_routing_question`, `confirm_non_plan_storage`, `select_attachment_target`, and `handoff_to_anchor_review`.
- [x] 1.7 Keep intake machine role separate from canonical source/repo role in route and confirmation payloads.

## 2. Source Preview

- [x] 2.1 Refactor material preview so Add / Initiate preview does not write active resources, units, or tasks.
- [x] 2.2 Add shallow GitHub preview with title, description, README outline, topics, coarse directory signals, and fetch-failure fallback.
- [x] 2.3 Add canonical repo role signals: `main_learning_object`, `reference_source`, `clone_rebuild_target`, `project_material`, and `later_reading`.
- [x] 2.4 Ensure unavailable repo/source facts remain unknown and do not become fabricated units.

## 3. Non-Plan Outcomes

- [x] 3.1 Persist confirmed reference and later resources outside active scheduling.
- [x] 3.2 Persist material-only attachments without altering existing plan schedules.
- [x] 3.3 Ensure `immediate_one_off` requires explicit user action before any task is created.

## 4. Tests

- [x] 4.1 Add router tests for all supported first-version input types.
- [x] 4.2 Add role tests for new plan, existing-plan attachment, reference, later, and one-off outcomes.
- [x] 4.3 Add one-question clarification tests for ambiguous role cases.
- [x] 4.4 Add GitHub preview tests for successful metadata, fetch failure, and no fabricated structure.
- [x] 4.5 Add Today-exclusion tests proving intake items and non-plan outcomes do not create active tasks.
- [x] 4.6 Add idempotency tests proving repeated client request ids do not duplicate pending objects.
- [x] 4.7 Add existing-plan target-selection tests proving scheduled-work handoff requires target plan and attachment mode confirmation.
