## Context

MalDaze currently contains a large embedded Learning Assistant surface: SwiftUI views and models under `MalDaze/LearningAssistant/`, a local FastAPI backend under `assistant_backend/`, study/ingestion OpenSpec capabilities, and acceptance/evidence docs. The retained product is the Mac desktop pet and menu bar app with rest timers, system Reminders integration, Smart Reminder reminder creation, hydration, seven-minute reminders, five-minute cat, and settings/shortcut controls.

The working tree also contains an unrelated untracked OpenSpec change at `openspec/changes/add-t7-eject-helper/`; this branch must not edit or stage that user work.

## Goals / Non-Goals

**Goals:**

- Remove Learning Assistant UI, local backend, APIs, tests, docs, specs, launch agents, and bundled runtime assumptions.
- Simplify the dashboard panel to retained reminders and desktop pet controls without an assistant middle column.
- Simplify settings so model/API-key controls are only for retained Smart Reminder behavior.
- Keep the app buildable and launchable after deletion.
- Keep retained reminder, pet, rest, shortcut, hydration, and Smart Reminder behavior intact.

**Non-Goals:**

- Redesign retained desktop pet controls beyond what is necessary to remove assistant references.
- Migrate existing local learning data to another product.
- Delete unrelated OpenSpec work such as `add-t7-eject-helper`.
- Remove Smart Reminder natural-language reminder creation or its provider/model/API-key settings.

## Decisions

1. Delete the embedded backend wholesale.

   `assistant_backend/` exists to support learning assistant chat, ingestion, study planning, morning/review agents, and study views. Keeping an inert backend would preserve dependencies and launch artifacts for a retired feature, so the branch removes the tracked backend directory, launch-agent scripts, tests, lockfile, and local database artifacts.

2. Replace the three-column dashboard with a two-column retained dashboard.

   `DeskPetDashboardView` currently owns a `LearningAssistantViewModel` and hosts `AssistantPanelView` between reminder and control columns. The deletion will remove that state object, delete the assistant column, and recalculate preferred sizing around the reminders sidebar plus controls. Internal click dismissal remains, but the bottom-navigation-specific scenario is removed.

3. Remove Learning Assistant settings while retaining Smart Reminder settings.

   Shared LLM settings were introduced for both Learning Assistant and Smart Input. After deletion, settings must keep provider/model/API-key controls only where Smart Reminder needs them. Learning assistant provider defaults, backend API keys, and lazy backend startup defaults should disappear from active UI and defaults.

4. Treat tests as deletion guards for retained behavior, not as post-hoc learning assistant validation.

   Tests that solely validate assistant models, backend endpoints, ingestion, study views, or source strings will be deleted. Tests that cover retained dashboard presentation, reminders, Smart Reminder, shortcuts, or window behavior will be updated when they reference assistant sizing or navigation.

## Risks / Trade-offs

- [Risk] Removing backend references can leave stale launch/startup calls or bundle resource assumptions. → Mitigation: search for `LearningAssistant`, `assistant_backend`, `BackendProcessManager`, `/api/study`, `/api/ingest`, and backend default keys after deletion.
- [Risk] Dashboard layout tests may encode the old three-column sizing. → Mitigation: update retained layout tests to assert two-column sizing and absence of assistant middle column.
- [Risk] Settings code may share helper types between retired Learning Assistant and retained Smart Reminder. → Mitigation: keep reusable helpers only when they are still referenced by Smart Reminder; delete assistant-specific provider/default keys.
- [Risk] OpenSpec cleanup can accidentally touch unrelated active work. → Mitigation: avoid editing `openspec/changes/add-t7-eject-helper/` and verify git status before staging.
- [Risk] This removal is intentionally breaking for users with local learning data. → Mitigation: document that the branch retires local learning data rather than migrating it.
