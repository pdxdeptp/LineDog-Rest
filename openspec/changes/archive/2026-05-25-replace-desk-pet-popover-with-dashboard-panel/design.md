## Context

The desk pet entry currently opens a wide `NSPopover` that hosts the same control surface previously used by the menu bar. That was reasonable while the menu bar and desk pet had to share the same appearance, but the menu bar is now being treated as a compact settings launcher. The desk pet entry is free to become a dedicated dashboard surface rather than a popover-shaped menu.

The current dashboard already behaves more like a small workbench than a contextual popover: it has a wide three-column layout, a learning assistant home, resource progress, ingestion, chat/adjust-plan flows, reminders, and timer/pet controls. `NSPopover` gives native chrome, but it also imposes popover timing, arrow placement, internal cooldown behavior, and first-frame rendering constraints that are awkward for a rich dashboard.

This change assumes the menu bar split is complete or lands before implementation. It does not design or modify the menu bar settings launcher.

## Goals / Non-Goals

**Goals:**

- Replace the desk pet `NSPopover` with a dedicated `NSPanel` dashboard.
- Keep the dashboard visually lightweight, desk-pet-adjacent, and easy to dismiss.
- Preserve the wide three-column dashboard structure: reminders, learning assistant, and controls.
- Improve first-open and repeat-open responsiveness by reusing the panel, SwiftUI host, and dashboard state.
- Avoid repeated gray startup flashes when cached dashboard content is available.
- Keep keyboard input, buttons, and focus behavior reliable inside the dashboard.
- Make closing behavior explicit: desk pet toggle, outside click, Esc, and app deactivation are owned by the panel controller.

**Non-Goals:**

- No menu bar entry redesign in this change.
- No backend API redesign.
- No major learning assistant information architecture redesign beyond cached startup and panel hosting expectations.
- No persistent user-resizable dashboard window unless a follow-up change asks for it.
- No replacement of the main desk pet stage window.

## Decisions

### D1: Use a dedicated `NSPanel`, not `NSPopover`

The desk pet dashboard should be hosted by an `NSPanel` (or a tiny `NSPanel` subclass) managed by `WindowManager` or a dedicated controller. The panel should use a clear AppKit window background and a SwiftUI dashboard root that draws its own material, rounded corners, and shadow.

Recommended panel traits:

- `NSPanel` with borderless or utility-like styling.
- `backgroundColor = .clear` and `isOpaque = false`.
- `hasShadow = true` or equivalent custom shadow.
- Can become key window so SwiftUI `TextField`, buttons, and keyboard shortcuts behave normally.
- Not a non-activating panel if that would break text input or focused controls.
- No popover arrow.

Alternative considered: keep `NSPopover` and optimize prewarming. Rejected because the dashboard is no longer a menu-like surface and `NSPopover.show(...)` still controls the critical first display timing.

Alternative considered: use a full `NSWindow`. Rejected for this iteration because the desired interaction is still a desk-pet-adjacent floating dashboard, not a full app workspace.

### D2: Introduce a long-lived dashboard panel controller

The implementation should avoid cold-creating the entire SwiftUI tree on every desk pet click. A dashboard controller should own:

- The `NSPanel`.
- The `NSHostingController`.
- A dashboard root view or existing dashboard content adapted for panel hosting.
- Long-lived dashboard state, especially the learning assistant view model or coordinator.

Closing the dashboard should normally hide/order out the panel rather than destroy the controller. This keeps repeat opens fast and preserves local UI state such as selected learning tab, chat draft, ingestion draft, expanded tasks, and loaded dashboard data.

Alternative considered: recreate everything on every open. Rejected because it repeats SwiftUI layout, view model initialization, backend fetches, and visible startup placeholders.

### D3: Reframe the root view as a dashboard, not a menu

The current `MenuBarContentView` can be reused as an implementation source, but the desk pet root should be named and treated as a dashboard surface. The clean end state is a `DashboardRootView` or equivalent with reusable child components for reminders, learning assistant, and controls.

Implementation can migrate incrementally:

1. Keep existing child controls and layout logic.
2. Move desk-pet-only root composition behind a dashboard-specific type or helper.
3. Stop asserting that the desk pet dashboard is a menu bar popover.

Alternative considered: simply place `MenuBarContentView` inside an `NSPanel` and leave all naming/specs intact. Rejected because it preserves the old menu/popover mental model and makes later dashboard work harder.

### D4: Show cached content first, refresh in the background

When dashboard data has been loaded before, reopening the panel should show the last available content immediately and start a background refresh with a small loading indicator. The dashboard should only show the whole-column backend-starting state when there is no useful cached dashboard content yet.

This preserves the current offline model for true service failure: if refresh fails and the app determines the assistant service is unavailable, the learning assistant column may enter the existing offline state. The change is only about avoiding unnecessary startup placeholders on repeat opens.

Alternative considered: always clear and refetch on panel open. Rejected because it makes every open feel like a cold start even when the app already has useful data.

### D5: Explicit close and focus behavior

The panel controller should own dismissal rules rather than inheriting popover behavior:

- Desk pet left-click while open toggles the dashboard closed.
- Click outside the panel closes it.
- Esc closes the dashboard unless a child surface such as smart input explicitly owns Esc first.
- App deactivation closes it by default, preserving the current transient-panel feel.
- Hiding the panel does not clear drafts or cached dashboard state.

The controller should install and tear down event monitors carefully so they do not swallow clicks or conflict with the desk pet hit region.

Alternative considered: keep AppKit popover transient behavior. Rejected because previous investigations showed transient/cooldown interactions can hide real behavior and make first-click failures harder to reason about.

### D6: Screen-aware sizing and positioning remain

The dashboard should keep the current wide layout intent:

- Width near the active screen visible width with a safe margin.
- Left and right columns fixed.
- Learning assistant middle column adaptive.
- Clamp to visible screen bounds.
- Position near the desk pet when possible, but prefer staying fully visible over preserving a strict anchor.

The dashboard does not need an arrow. Its relationship to the desk pet can be communicated by opening from the pet location and by placement, not by popover chrome.

## Risks / Trade-offs

- [Risk] `NSPanel` may visually drift from native popover styling. -> Mitigation: use a single SwiftUI dashboard chrome with system materials, rounded corners, and shadow; verify in light/dark mode.
- [Risk] A key-capable panel may affect app activation/focus more than `NSPopover`. -> Mitigation: test text input, outside click, app deactivation, and return-to-previous-app behavior explicitly.
- [Risk] Long-lived view models can keep stale data. -> Mitigation: show cached content only as the initial frame and always trigger a refresh when opening.
- [Risk] Long-lived panel state can retain too much work while hidden. -> Mitigation: pause hidden-only timers, avoid polling while hidden, and keep backend refresh event-driven or user-triggered.
- [Risk] Existing source tests assert `NSPopover`. -> Mitigation: replace those assertions with `NSPanel` dashboard lifecycle and dismiss behavior tests.
- [Risk] Menu bar split and dashboard panel changes touch nearby files. -> Mitigation: implement after the menu bar split is landed or rebase the spec before apply.

## Migration Plan

1. Confirm the menu bar settings-only entry has landed or is merged before implementation starts.
2. Add failing tests that reject `NSPopover()` for the desk pet dashboard path and require an `NSPanel`-backed dashboard controller.
3. Introduce the dashboard panel/controller and keep the old popover path until the tests drive replacement.
4. Move or wrap the current wide control panel content into a dashboard-specific root.
5. Move learning assistant/dashboard state ownership to a long-lived owner if needed for cached repeat opens.
6. Replace popover show/close/event monitor code with panel positioning, show, hide, and dismissal monitors.
7. Run Swift tests and perform manual desktop QA for first open, repeat open, outside click, Esc, app deactivation, text input, and backend startup/offline states.

Rollback: keep the old popover implementation recoverable in version control during the change. If `NSPanel` introduces unacceptable focus or activation regressions, revert the WindowManager presentation path and keep the dashboard naming/state changes only after updating the spec.

## Open Questions

- Should app deactivation always close the dashboard, or should a future mode allow it to remain as a persistent workbench?
- Should the dashboard panel become user-draggable or resizable in a later iteration?
- Should panel position be purely desk-pet anchored, or should it remember a user-adjusted dashboard location later?
