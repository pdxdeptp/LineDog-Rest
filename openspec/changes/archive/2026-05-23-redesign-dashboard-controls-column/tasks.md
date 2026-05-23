## 1. Design Review

- [x] 1.1 Review `dashboard-controls-preview.html` and settle the right-column hierarchy before production implementation.
- [x] 1.2 Map the preview zones to existing `DashboardRootView` state and actions.
- [x] 1.3 Confirm the state-aware interaction matrix in `design.md` before applying production SwiftUI changes.

## 2. Tests

- [x] 2.1 Add or update focused Dashboard tests that verify right-column controls remain available after restructuring.
- [x] 2.2 Add coverage for important disabled or alternate states such as manual-only focus start, running countdown cancel, and active cat companion cancel.

## 3. SwiftUI Implementation

- [x] 3.1 Refactor the right column into status, quick actions, settings groups, and utility footer.
- [x] 3.2 Introduce small local SwiftUI helpers for action rows, disclosure sections, compact setting rows, and footer utility actions.
- [x] 3.3 Preserve existing bindings, AppStorage keys, view-model calls, keyboard shortcuts, and help text.
- [x] 3.4 Keep icon labels based on SF Symbols and provide accessibility labels for icon-only buttons.
- [x] 3.5 Implement quick-action labels, disabled states, and alternate actions from the state matrix.

## 4. Verification

- [x] 4.1 Run relevant Swift tests for Dashboard and control behavior.
- [x] 4.2 Manually open the desktop Dashboard panel and verify layout, scrolling, disabled states, and settings reachability.
- [x] 4.3 Run a visual pass for text clipping, spacing, contrast, and accidental overlap in the 300 pt right column.
