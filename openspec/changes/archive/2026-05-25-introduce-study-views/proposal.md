## Why

Learning Assistant v2 now has a foundation for confirmed study projects, but daily use is still shaped by v1 resource progress and morning-agent briefing surfaces. The next slice needs deterministic factual views so the user can see what to do today, inspect project progress, and understand upcoming load without the assistant inventing or proactively changing anything.

## What Changes

- Add the `study-views` v2 capability covering US-6, US-7, US-12, US-13, and US-14.
- Introduce deterministic study view APIs for today's tasks, project overview, completed history, and future calendar load.
- Make task completion update project progress and remove completed projects from active daily/project views while preserving completed records.
- Add Swift models, client methods, view-model state, and UI for Today, Project Overview, and Calendar views.
- Keep v1 morning briefing, conversational planner, and old learning specs as historical/parallel surfaces for now; this change does not retire them.

## Capabilities

### New Capabilities

- `study-views`: v2 factual daily, project, and calendar views for confirmed study projects, including task completion progress and completed project history.

### Modified Capabilities

- None. Existing v1 learning specs remain historical baseline and are not changed by this slice.

## Impact

- Affected design source: `openspec/learning-assistant-v2.md`.
- Affected prior change dependency: `openspec/changes/introduce-study-plan-foundation`, which provides confirmed study projects and active tasks.
- Affected backend areas expected during implementation:
  - `assistant_backend/src/db/queries.py`
  - `assistant_backend/src/routers/`
  - `assistant_backend/src/main.py`
  - study/task/resource aggregation tests.
- Affected Swift areas expected during implementation:
  - `MalDaze/LearningAssistant/AssistantAPIClient.swift`
  - `MalDaze/LearningAssistant/AssistantAPIClientProtocol.swift`
  - `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`
  - `MalDaze/LearningAssistant/AssistantPanelView.swift`
  - `MalDazeTests/LearningAssistantTests.swift`
- No worktree is allowed; implementation must stay in the current checkout and checkpoint before `opsx:apply`.
