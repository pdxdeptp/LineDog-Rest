## Why

`资料进度` currently behaves as a read-only progress list: users can see a material but cannot open it, adjust its plan, mark it done, or remove it from the active learning plan. This makes the progress tab feel like a dead end, especially after materials have already been added.

## What Changes

- Turn the resource progress tab into an actionable management surface.
- Add per-resource actions for opening the source link when available, jumping into plan adjustment with resource context, marking a resource complete, and removing a resource from the active plan.
- Add safe backend resource management endpoints that update resource status and keep related future tasks from continuing to appear as active work.
- Refresh the dashboard/resources after each successful resource management action and show clear feedback on failures.
- Preserve completed historical data and event history; removal from the active plan is not a hard database delete.

## Affected Specs

- `assistant-panel-ui`
- `learning-data-layer`
- `progress-feedback`

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `assistant-panel-ui`: `资料进度` changes from a passive overview to an actionable resource management view.
- `learning-data-layer`: resources need explicit user-driven status transitions for complete and archived/removed-from-plan states, including related future task handling.
- `progress-feedback`: manually completing or removing a resource must immediately affect progress display and dashboard/resource refresh behavior.

## Impact

- SwiftUI learning assistant views: `AssistantPanelView`, `ResourceProgressView`, `ChatView`/ViewModel handoff, and related tests.
- Swift API client and protocol: resource URL decoding plus resource management calls.
- FastAPI backend: new resource management routes.
- SQLite query layer: resource status transitions, future task cleanup, and event writes.
- Tests: Swift ViewModel/source tests plus backend integration tests for resource management endpoints.
