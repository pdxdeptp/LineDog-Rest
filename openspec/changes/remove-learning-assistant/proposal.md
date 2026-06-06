## Why

The project is moving away from the embedded Learning Assistant product surface, including its Swift UI and local FastAPI backend. Removing it reduces maintenance load and returns MalDaze to the core desktop pet, rest, reminders, Smart Reminder, and hydration scope.

## What Changes

- **BREAKING** Remove the Learning Assistant dashboard column, bottom navigation, study planning flows, material ingestion flows, learning preferences, progress/resource views, and embedded backend startup.
- **BREAKING** Remove the local `assistant_backend` service and its study/ingestion/chat/morning/review APIs from the app distribution.
- **BREAKING** Remove Learning Assistant requirements, OpenSpec active changes, implementation evidence, and docs that only describe the retired learning assistant.
- Update the desk pet dashboard and settings surfaces so they no longer expose Learning Assistant entry points, credentials, model selection, lazy backend startup, or study-related controls.
- Preserve non-learning features: desktop pet, menu bar controls, rest/break flows, manual and auto timers, system Reminders integration, Smart Reminder natural-language reminder creation, hydration reminder, seven-minute reminder, five-minute cat, and app/window management.

## Capabilities

### New Capabilities

- `learning-assistant-removal`: Defines the retired Learning Assistant surface and the expected absence of its UI, backend, docs, specs, and launch artifacts.

### Modified Capabilities

- `desk-pet-controls`: Remove Learning Assistant dashboard/settings entry requirements and keep the control panel focused on retained desktop pet and reminder controls.
- `assistant-panel-ui`: Retire the embedded Learning Assistant panel UI requirements.
- `learning-data-layer`: Retire local learning database/data-layer requirements.
- `material-ingestion`: Retire study material ingestion requirements.
- `ingestion-progress-sse`: Retire ingestion progress streaming requirements.
- `learning-preferences`: Retire learning preference APIs and settings requirements.
- `progress-feedback`: Retire learning progress feedback requirements.
- `conversational-planner`: Retire local conversational planning agent requirements.
- `daily-morning-agent`: Retire morning learning agent requirements while preserving normal app shutdown behavior outside that backend.
- `weekly-review-agent`: Retire weekly review agent requirements.
- `study-plan`: Retire study plan intake, decomposition, scheduling, review, and activation requirements.
- `study-plan-adjustment`: Retire study plan adjustment requirements.
- `study-views`: Retire study today/project/calendar view requirements.

## Impact

- Swift app files under `MalDaze/LearningAssistant/` will be deleted, and callers in `DashboardRootView`, `WindowManager`, `AppViewModel`, defaults, and settings will be simplified.
- `assistant_backend/` code, tests, launch agent scripts, databases, and dependency files will be removed from the tracked project.
- Learning Assistant tests and source-level assertions will be removed or rewritten so the remaining test suite validates retained functionality only.
- OpenSpec specs, active changes, evidence, and docs dedicated to learning assistant/study planning/material ingestion will be removed or archived by this branch.
- README/PRD and related docs will be updated to stop advertising the Learning Assistant.
