## 1. Tests and Source Assertions

- [x] 1.1 Update `ControlPanelPresentationTests` or equivalent source tests to reject `NSPopover()` in the desk pet dashboard path and require an `NSPanel` or `NSPanel` subclass.
- [x] 1.2 Add tests/assertions that desk pet left-click and the desk pet menu shortcut route through a dashboard panel helper/controller rather than `NSPopover.show(...)`.
- [x] 1.3 Add tests/assertions for dashboard panel lifecycle reuse: the panel/controller is retained after hide and reused on repeat open.
- [x] 1.4 Add tests/assertions for close behavior ownership: desk pet toggle, outside click monitor, Esc handling, and app deactivation are represented without popover transient behavior.
- [x] 1.5 Add learning assistant tests for cached dashboard startup: cached content remains visible with non-blocking refresh feedback when reconnecting or reopening.

## 2. Dashboard Panel Controller

- [x] 2.1 Introduce a dashboard panel controller/helper owned by `WindowManager` for creating, positioning, showing, hiding, and reusing the `NSPanel`.
- [x] 2.2 Configure the panel chrome: clear AppKit background, non-opaque window, shadow/material-compatible content, no popover arrow, and key-window support for text input.
- [x] 2.3 Implement screen-aware panel sizing and positioning near the desk pet while clamping to the active screen visible frame.
- [x] 2.4 Replace the desk pet `NSPopover` storage and show path with dashboard panel storage and show/hide calls.

## 3. Dashboard Root View

- [x] 3.1 Create or extract a dashboard-specific root view name for the desk pet control surface while preserving the existing three-column layout.
- [x] 3.2 Keep left reminders and right controls fixed-width and the learning assistant middle column adaptive.
- [x] 3.3 Move desk-pet dashboard construction behind a single helper so tests can assert one presentation path.
- [x] 3.4 Remove or update comments/names that describe the desk pet dashboard as a menu bar popover.

## 4. Long-Lived Dashboard State

- [x] 4.1 Move learning assistant/dashboard state ownership to a long-lived owner if needed so panel hide/show does not cold-create the state.
- [x] 4.2 Preserve selected learning assistant tab, task expansion state, drafts, and loaded dashboard data across panel hide/show.
- [x] 4.3 Trigger background refresh on panel open without clearing usable cached dashboard content.
- [x] 4.4 Keep first-open behavior intact when no cached content exists: backend starting, empty database, loaded dashboard, and offline states still render correctly.

## 5. Dismissal and Focus Behavior

- [x] 5.1 Implement desk pet toggle close behavior for an already-visible Dashboard Panel.
- [x] 5.2 Implement outside click dismissal with event monitor setup/teardown that does not conflict with the desk pet hit region.
- [x] 5.3 Implement Esc dismissal while respecting child surfaces that own Esc first.
- [x] 5.4 Implement app deactivation dismissal while preserving dashboard local state.
- [x] 5.5 Verify text input and focused controls work inside the `NSPanel`.

## 6. Cleanup and Verification

- [x] 6.1 Remove obsolete desk pet popover code paths, popover-specific comments, and popover-specific source tests.
- [x] 6.2 Run the relevant Swift/Xcode tests for control panel presentation and learning assistant state behavior.
- [ ] 6.3 Manually QA first open, repeat open, close/reopen, outside click, Esc, app deactivation, text input, backend starting, backend offline, and cached-content refresh from the desk pet entry.
- [x] 6.4 Record any intentional visual differences from the old `NSPopover` dashboard, especially absence of arrow and any material/shadow changes. Implemented as a borderless clear `NSPanel` with AppKit shadow and no popover arrow; SwiftUI dashboard content continues to draw the visible surface.
