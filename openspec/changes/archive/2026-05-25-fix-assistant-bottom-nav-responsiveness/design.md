## Context

The learning assistant bottom navigation lives inside a long-lived floating Dashboard Panel. The button action itself is cheap (`selectedPanelTab = tab`), but several tab destinations start async refresh work on entry, and the Dashboard Panel owns custom click-away/app-deactivation dismissal monitors. During investigation, local backend GET endpoints responded in milliseconds, while UI automation reproduced a case where a bottom-navigation click changed the selected tab but the Dashboard Panel hid immediately, making the click feel delayed or ignored.

The current implementation also uses plain SwiftUI buttons whose visual frame is larger than the text/icon glyphs. Without an explicit content shape and a stable selected-state control surface, users can perceive misses or late feedback.

## Goals / Non-Goals

**Goals:**

- Make every bottom-navigation click show selection feedback immediately.
- Make the full bottom-navigation item area a reliable hit target.
- Prevent Dashboard Panel dismiss monitors from treating clicks inside the panel as outside clicks, including focus-transition races.
- Keep destination refresh work asynchronous and visibly separate from tab selection.
- Cover the behavior with focused source/unit regression tests and manual panel QA.

**Non-Goals:**

- Redesign the learning assistant information architecture.
- Change backend API contracts, database schema, or learning-plan business logic.
- Remove the intended behavior that outside clicks, Esc, app deactivation, and desk-pet toggles can close the Dashboard Panel.
- Introduce a new UI framework or dependency.

## Decisions

1. **Treat tab selection as a local UI state transition.**
   - The bottom-navigation action should only update selection and return immediately.
   - Destination views may continue to fetch data through existing `.task` or refresh paths, but those loads must not be prerequisites for changing the selected tab.
   - Alternative considered: eagerly refresh all tab data before switching. Rejected because it directly couples navigation responsiveness to backend and SwiftUI diff work.

2. **Make bottom-navigation hit targets explicit.**
   - Add a rectangular content shape and stable item frame so the full visible segment is clickable.
   - Preserve the compact icon + label layout instead of introducing a large redesign.
   - Alternative considered: replace custom HStack with `TabView`. Rejected because the assistant column already owns custom states, fixed bottom positioning, and macOS panel layout constraints.

3. **Harden Dashboard Panel click-inside detection.**
   - Centralize the "is this mouse event inside the dashboard panel?" decision so local/global dismiss monitors and tests share one intended rule.
   - Use the panel frame as the primary screen-space check and account for focus-transition timing without closing on an internal click.
   - Alternative considered: remove app-deactivation dismissal. Rejected because the existing spec expects the panel to close when the app loses active state.

4. **Keep implementation narrow and TDD-driven.**
   - Tests should first fail on missing explicit nav hit target / feedback behavior and missing panel internal-click guard.
   - Implementation should be limited to `AssistantPanelView.swift`, `WindowManager.swift`, and existing tests unless investigation proves another file is the root cause.

## Risks / Trade-offs

- [Risk] A broader hit target may overlap neighboring bottom-navigation items. -> Mitigation: keep seven equal-width segments and use `contentShape(Rectangle())` only inside each segment's own frame.
- [Risk] Deferring or avoiding refresh work could leave stale tab data visible briefly. -> Mitigation: preserve existing `.task` refreshes and show existing loading indicators; only decouple selection feedback from refresh completion.
- [Risk] Panel dismissal logic may become too permissive and fail to close on genuine outside clicks. -> Mitigation: add tests that retain outside-click behavior while adding inside-click protection.
- [Risk] Accessibility/UI automation may differ from physical clicks. -> Mitigation: verify with both source/unit tests and a manual Dashboard Panel click sequence in the running app.

## Migration Plan

1. Add regression tests for bottom-navigation hit target/selection behavior and Dashboard Panel internal-click protection.
2. Implement the smallest UI and dismissal changes to satisfy tests.
3. Run focused Swift tests.
4. Launch or use the running app to manually verify: open Dashboard Panel, click each bottom tab once, confirm the panel stays open and selection changes immediately, then verify outside click and Esc still close it.
5. Roll back by reverting the UI/dismissal changes if panel close behavior regresses.

## Open Questions

None for this change.
