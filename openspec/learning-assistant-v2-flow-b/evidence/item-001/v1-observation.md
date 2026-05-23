# ITEM-001 V1 Observation

## Static Code Evidence

### Swift Frontend

- `MalDaze/LearningAssistant/AssistantPanelView.swift`
  - Renders the learning assistant middle column.
  - Default ready view is a dashboard with bottom navigation.
  - Add-resource entry is `IngestionView(vm:)`.

- `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`
  - Maintains today tasks, resources, chat messages, ingestion draft, selected option, deadline, speed factor, and daily capacity.
  - Starts ingestion through `api.startIngestion(url:deadline:speedFactor:)`.
  - Subscribes to ingestion SSE and stores `IngestionDraftDetail` when `draft_ready`.
  - Confirms ingestion directly to backend, then refreshes dashboard.

- `MalDaze/LearningAssistant/AssistantAPIClient.swift`
  - Calls `POST /api/ingest/start`, `GET /api/ingest/progress/{thread_id}`, `POST /api/ingest/reschedule`, and `POST /api/ingest/confirm`.
  - Models ingestion draft as title/type/hours/unit count plus `option_a` and `option_b`.
  - Does not model guided clarification, review-state plan drafts, draft task duration edits, or explicit plan activation.

### Python Backend

- `assistant_backend/src/routers/ingest.py`
  - `StartRequest` currently requires `url`, `deadline`, and `speed_factor`.
  - Start immediately creates a LangGraph ingestion thread.
  - Reschedule recomputes A/B schedule options for a paused thread.
  - Confirm resumes the graph and writes selected option to database.

- `assistant_backend/src/agents/ingestion_agent.py`
  - Graph shape: dispatch handler -> fetch structure -> estimate time -> check capacity -> present draft -> write to DB.
  - Supports URL validation, progress events, and schedule option generation.
  - This resembles D29 partially, but lacks D30 guided clarification and v2 draft-review semantics.

- `assistant_backend/src/db/schema.py`
  - Tables: resources, units, tasks, plan_versions, events, system_state.
  - Useful baseline for v2 persistence, but not yet modeled around projects/draft plans/review state.

## App Use Evidence

Computer Use found multiple installed/debug MalDaze apps sharing bundle id `com.maldaze.MalDaze`. Targeting the current checkout app path succeeded:

`/Users/cpt/Public/MalDaze/DerivedData/Build/Products/Debug/MalDaze.app`

The returned app state showed a running menu-bar-like app with no meaningful learning assistant content visible in the current window snapshot. This is sufficient to record a UI verification risk; full visual verification should be repeated after implementation with a known way to open the dashboard panel.

## Gap Against v2

- V2 requires a study-plan calendar foundation, not a resource-ingestion agent surface.
- V2 US-2 requires guided clarification before decomposition; v1 starts ingestion immediately.
- V2 D29 requires an explicit five-step decomposition pipeline; v1 graph is close but not specified/tested as the v2 contract.
- V2 D24 requires deterministic average spread over non-rest days; v1 uses option A/B scheduling with different semantics.
- V2 US-3 through US-5 require a review-state draft where users can edit durations and confirm into daily use; v1 confirms selected A/B option and writes resources/tasks directly.
- V2 uses new spec id `study-plan`; old v1 specs remain historical baseline until a later retirement change.
