## ADDED Requirements

### Requirement: Add Initiate State Boundaries
学习助手中栏 SHALL distinguish route clarification, draft clarification, non-plan confirmation, material attachment, activation failure, and activation success so each state has one clear next action.

#### Scenario: Route clarification does not require draft
- **WHEN** Add / Initiate needs input before a draft exists
- **THEN** the UI shows one focused routing question and role or storage choices
- **AND** it does not call draft anchor confirmation
- **AND** it does not show a missing-draft error as the next user action

#### Scenario: Draft clarification keeps draft context
- **WHEN** Add / Initiate needs input after a draft exists
- **THEN** the UI preserves submitted input, confirmed role, draft id, draft version, anchors, assumptions, and prior review facts
- **AND** answering the question resumes planning for the same current draft

#### Scenario: Non-plan recommendation requires confirmation
- **WHEN** routing recommends reference material, later resource, or one-off action
- **THEN** the UI asks the user to confirm how to store or handle the item
- **AND** it does not show a stored-success terminal state from the initial route response alone

#### Scenario: Material-only attachment is quiet
- **WHEN** the user confirms material-only attachment to an existing plan
- **THEN** the UI shows material-attached success after confirmation succeeds
- **AND** it does not refresh Today, Calendar, Project Overview, or smart-mode proposal context as if new active work exists

#### Scenario: Activation success is explicit
- **WHEN** draft activation succeeds
- **THEN** the UI shows a terminal success state that says the plan has been created
- **AND** it offers next actions for Today, Project Overview, Calendar, or continuing Add / Initiate

#### Scenario: Only activation success refreshes active surfaces
- **WHEN** the session is in route review, anchor review, progress, needs input, compile failed, infeasible review, draft review, storage, material attachment, cancellation, or activation failure
- **THEN** the UI does not refresh active learning surfaces as if new work exists
- **AND** after activation succeeds with active tasks, it refreshes Home, Today, Project Overview, Calendar, and smart-mode context
