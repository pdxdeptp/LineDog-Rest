## Context

The resource progress tab is currently a passive SwiftUI list backed by `GET /api/resources`. The backend already stores enough resource metadata to support lightweight management (`status`, `url`, task/resource relations, and events), but it exposes no resource management endpoints and the Swift resource model does not decode the source URL.

This desktop app favors direct manual QA from the current checkout. The implementation should keep the surface small, avoid destructive deletes, and preserve the existing local SQLite data model where possible.

## Goals / Non-Goals

**Goals:**

- Make each resource card actionable from the progress tab.
- Let users open a resource source link when one exists.
- Let users jump into plan adjustment with a resource-specific prompt/context.
- Let users mark a resource complete when they finished it outside the planned tasks.
- Let users remove a resource from the active plan without hard-deleting historical data.
- Keep today's dashboard and resource progress fresh after management actions.

**Non-Goals:**

- Editing imported unit structure or re-ingesting a resource.
- Building a full resource detail drill-down with per-unit editing.
- Hard-deleting resource history, completed tasks, or events.
- Rewriting the conversational planner.

## Decisions

1. **Use status transitions instead of hard delete.**
   - Decision: "Remove from plan" sets `resources.status='archived'` and removes future incomplete tasks for that resource from the active schedule.
   - Rationale: The existing schema has a resource `status` field and an active-resource query. Archiving keeps history and avoids accidental data loss.
   - Alternative considered: hard delete resource/units/tasks. Rejected because it would erase learning history and increase foreign-key/data consistency risk.

2. **Add explicit resource management routes.**
   - Decision: add backend endpoints such as `POST /api/resources/{id}/complete` and `POST /api/resources/{id}/archive`.
   - Rationale: These operations are deterministic data mutations and should not depend on a chat/LLM path.
   - Alternative considered: route all resource management through `POST /api/chat`. Rejected because simple state transitions need reliable, testable behavior.

3. **Preserve completed history while cleaning future work.**
   - Decision: completing a resource marks its units complete, marks incomplete tasks for that resource complete or removes future active work according to the operation; archiving removes only incomplete future scheduled tasks.
   - Rationale: The user asked to manage materials, not rewrite the entire plan. Completed historical records should stay visible to reviews and events.
   - Alternative considered: leave future tasks after archiving. Rejected because archived resources would still appear as active work in today's briefing.

4. **Resource adjustment uses existing chat UI with prefilled context.**
   - Decision: the progress card's "adjust plan" action switches to the adjust-plan tab and seeds a draft message referencing the resource title/id.
   - Rationale: The conversational planner already owns nuanced changes such as postponing, speeding up, or reducing load. Prefill removes friction without duplicating planner logic.
   - Alternative considered: build deadline/speed editors directly in the progress tab. Rejected for this iteration because it duplicates ingestion reschedule concepts and requires broader scheduling design.

5. **Expose resource URL to Swift.**
   - Decision: include/decode `url` as `resourceURL` on `AssistantResource` and show the open action only when a valid URL exists.
   - Rationale: The backend already returns `SELECT *` resource data, but the Swift model currently drops the URL.

## Risks / Trade-offs

- [Risk] Archiving by deleting future incomplete tasks can surprise users who expected an undo path. → Mitigation: label the UI as removing from the active plan, preserve the resource row as archived in the database, and write an event.
- [Risk] Completed resources are not returned by the active resource endpoint. → Mitigation: after completion, refresh resources and dashboard so the disappearance is intentional and immediate.
- [Risk] Prefilled chat context might become stale if the resource is archived before sending. → Mitigation: the prompt remains user-editable and the backend planner still validates current state before applying changes.
- [Risk] Existing tests may assume only active resources are returned. → Mitigation: keep `GET /api/resources` active-only and add dedicated tests for status transitions.

## Migration Plan

No schema migration is required. Existing rows with `status='active'` continue to work. New status value `archived` is written by user action only. Rollback is code-level: removing the new routes and UI leaves existing archived rows inert and excluded from active resources.
