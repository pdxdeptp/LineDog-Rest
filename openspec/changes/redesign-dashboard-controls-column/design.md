## Context

`DashboardRootView` renders a fixed-width 300 pt right controls column inside the wide desktop Dashboard panel. The current column contains all control groups as similar `GroupBox` sections: timer mode, durations, rest behavior, pet appearance, break style, countdown, hydration, cat companion, test actions, hint text, and quit.

The behavior is useful, but the visual model is flat. Primary actions and rare settings compete for attention, explanatory text consumes the same level as controls, and destructive or testing utilities sit too close to everyday controls. This redesign keeps the current product scope while changing the information architecture and visual rhythm.

## Goals / Non-Goals

**Goals:**

- Make the right column feel like a polished macOS control surface, not a raw form dump.
- Put the live rest/timer state and the most common actions in the first screen.
- Use progressive disclosure for lower-frequency settings so the user can scan the panel quickly.
- Preserve all existing user-facing capabilities and state bindings.
- Keep the layout feasible within the existing 300 pt right column and 664 pt panel height.
- Provide a static HTML preview before production SwiftUI implementation.

**Non-Goals:**

- No changes to timer engines, hydration scheduling, countdown behavior, cat companion behavior, shortcut registration, or persistence keys.
- No new external dependency or custom icon package.
- No redesign of the left reminders column or middle learning assistant column.
- No production SwiftUI implementation in this design-preview step.

## Decisions

### 1. Use a four-zone column hierarchy

The redesigned column is divided into:

1. Header and status: title, settings icon, live status pill, mode segmented control.
2. Quick actions: common start/stop/resume, countdown, hydration, and cat actions as consistent icon-led controls.
3. Settings groups: focus timing, rest behavior, pet appearance, and hydration quiet hours as compact disclosure sections.
4. Utility footer: reset/test actions, quit, and short safety hint.

Alternative considered: keep all existing `GroupBox` sections but restyle them. That would improve surface polish but not fix the deeper hierarchy problem.

### 2. Favor rows and disclosure over nested cards

The design uses un-nested row groups with 8 px radius, stable heights, and thin separators. Dense controls such as toggles, sliders, and date pickers stay in row form. Settings that users rarely touch are moved behind disclosure headers.

Alternative considered: a grid of large action cards. The right column is only 300 pt wide, so large cards would either crowd the view or force too much vertical scrolling.

### 3. Keep native macOS affordances visible

SwiftUI implementation should still use native `Button`, `Toggle`, `Picker`, `Stepper`, `Slider`, and `DatePicker` where possible, styled through small local wrappers. Icon labels should use SF Symbols. Hit targets should remain at least 36 pt visual height with enough content shape to approach 44 pt interaction comfort.

Alternative considered: fully custom painted controls. That would raise maintenance cost and risk accessibility regressions.

### 4. Separate primary, secondary, test, and destructive intent

Primary actions use accent fill. Secondary actions use quiet bordered or tonal treatment. Test actions are visually marked as utility actions. Quit remains isolated in the footer and is never grouped with timer controls.

Alternative considered: one shared button style with tint differences. The current problem is partly caused by equal visual weight, so intent needs clearer structure.

### 5. Prototype first, implement later

The HTML preview at `dashboard-controls-preview.html` is a design artifact. It models spacing, hierarchy, labels, and interaction states, but it is not a production implementation and does not replace TDD requirements for the eventual SwiftUI change.

### 6. Define explicit control states before implementation

Every visible action in the redesigned right column maps to an existing view-model action or local disclosure state:

| Control | State | Interaction |
| --- | --- | --- |
| Settings gear | Always available | Opens the existing MalDaze settings window via `openMalDazeSettingsWindow()`. |
| Mode segmented control | Always available | Calls `viewModel.setMode(_:)`; existing behavior stops the current engine, closes rest UI, and refreshes status/pet state. |
| Timer primary action | Manual mode, no active/suspended session | Shows start-focused copy and calls `viewModel.startManualFocus()`. |
| Timer primary action | Active timer session | Shows stop copy and calls `viewModel.stopTimers()` when `canStopChronoButton` is true. |
| Timer primary action | Suspended timer session | Shows resume copy and calls `viewModel.resumeTimers()` when `showResumeChronoButton` is true. |
| Timer primary action | Non-manual idle state | Shows automatic-mode context and is disabled rather than starting a manual focus session. |
| Countdown quick action | Countdown not running | Starts `viewModel.startSevenMinuteReminder()` using `sevenMinuteMinutesResolved`. |
| Countdown quick action | Countdown running | Changes to cancel state and calls `viewModel.cancelSevenMinuteReminder()`. |
| Hydration quick action | Hydration disabled | Enables reminders via `viewModel.setHydrationReminderEnabled(true)`. |
| Hydration quick action | Hydration enabled | Disables reminders via `viewModel.setHydrationReminderEnabled(false)`; interval and quiet-hour settings stay in the hydration settings group. |
| Cat quick action | Cat inactive | Calls `viewModel.startFiveMinuteCatCompanion()`. |
| Cat quick action | Cat active | Changes to close state and calls `viewModel.cancelFiveMinuteCatCompanion()`. |
| Disclosure headers | Any state | Expand/collapse local UI only; they do not mutate app settings. |
| Focus/rest duration rows | Timer settings group | Preserve existing `@AppStorage` writes and `viewModel.syncPomodoroDurationsFromDefaults()`. |
| Rest style row | Timer settings group | Calls `viewModel.setBreakInterruptStyle(_:)`. |
| Rest behavior toggles | Behavior settings group | Call `viewModel.setRestBlocksClicksDuringRest(_:)` and `viewModel.setRestDoubleClickEndsRest(_:)`. |
| Pet size slider | Pet appearance group | Quantizes on commit, writes `idlePetIconSideStored`, and posts `idlePetIconSidePointsChanged`. |
| Pet motion slider | Pet appearance group | Writes `idlePetAnimationIntensityStored` and posts `idlePetAnimationIntensityChanged` on commit. |
| Hydration interval row | Hydration settings group | Writes the interval and calls `viewModel.setHydrationReminderInterval(_:)` on commit. |
| Hydration quiet-hours toggle and time rows | Hydration settings group | Preserve existing `@AppStorage` values; time rows are disabled when hydration or quiet hours are off. |
| Reset pet utility | Footer utility | Calls `viewModel.resetIdlePetPositionFromUserAction()`. |
| Test rest utility | Footer utility | Calls `viewModel.startTestRestNow()`. |
| Test hydration utility | Footer utility | Calls `viewModel.testFireHydrationReminder()`. |
| Quit action | Footer destructive/escape action | Calls `viewModel.quitApp()` and keeps the existing Command-Q shortcut. |

## Risks / Trade-offs

- Reduced always-visible settings → Mitigation: use clear disclosure labels and keep the most operational controls visible.
- More custom styling could drift from macOS conventions → Mitigation: base implementation on native SwiftUI controls and SF Symbols.
- Existing tests may depend on labels or view structure → Mitigation: keep core labels semantically equivalent and update only structure-sensitive tests.
- Static HTML may not perfectly map to SwiftUI metrics → Mitigation: treat it as visual direction, then verify with the real app during apply.

## Migration Plan

1. Review the HTML preview and adjust the visual direction before production work.
2. During apply, add focused tests for controls remaining available and key disabled states.
3. Implement local SwiftUI view helpers inside `DashboardRootView.swift` or a tightly scoped sibling file.
4. Verify the Dashboard manually from the desktop app and run relevant tests.

## Open Questions

- Should test actions stay in the right column long term, or move into settings/debug surfaces later?
