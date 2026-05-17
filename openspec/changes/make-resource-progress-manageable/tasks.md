## 1. Backend Resource Management

- [ ] 1.1 Add failing backend tests for marking an active resource complete, including resource status, units, event write, and active resource exclusion.
- [ ] 1.2 Add failing backend tests for archiving an active resource, including future incomplete task removal, historical data preservation, event write, and active resource exclusion.
- [ ] 1.3 Implement resource management query functions and FastAPI routes for complete/archive.
- [ ] 1.4 Run backend tests that cover resource management and existing learning assistant integration behavior.

## 2. Swift API and ViewModel

- [ ] 2.1 Add failing Swift tests for `AssistantResource` URL decoding and resource management API protocol calls.
- [ ] 2.2 Add failing Swift ViewModel tests for successful resource completion/archive refresh, failure feedback, and resource-specific adjust-plan draft text.
- [ ] 2.3 Implement Swift API client/protocol resource management methods and `AssistantResource.resourceURL`.
- [ ] 2.4 Implement ViewModel state/actions for completing, archiving, clearing management errors, and seeding adjust-plan text.

## 3. SwiftUI Resource Progress Actions

- [ ] 3.1 Add failing Swift source/UI tests asserting resource progress cards expose open, adjust, complete, and remove-from-plan actions.
- [ ] 3.2 Update `ResourceProgressView`, `AssistantPanelView`, and `ChatView` to render and wire the management actions.
- [ ] 3.3 Verify the progress tab refreshes after successful actions and preserves visible data on failures.

## 4. Verification and QA Handoff

- [ ] 4.1 Run targeted Swift and backend automated checks.
- [ ] 4.2 Review implementation against all delta specs in `openspec/changes/make-resource-progress-manageable/specs/`.
- [ ] 4.3 Document manual desktop-app QA steps for opening a resource, adjusting a plan, marking complete, and removing from the active plan.
